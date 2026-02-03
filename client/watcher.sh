#!/bin/bash
# NOTE: Do NOT use `set -e` here. On these BusyBox-based firmwares,
# small differences in tool output (stat/find/awk) can cause transient
# non-zero exit codes. We want the watcher to keep running and log errors
# rather than exiting.
set -u
set -o pipefail

# RetroSync polling watcher daemon (BusyBox-friendly)
#
# Watches common save directories for changes to *.sav/*.srm and uploads changed
# files to the RetroSync API using the stored device api key.
#
# Notes:
# - Designed for firmwares without systemd/inotifywait (polling fallback).
# - Uses mtime+size to detect changes; only uploads when changed.
# - Debounces writes and backs off when idle to reduce CPU/I/O.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GAMEDIR="$(cd "$SCRIPT_DIR" && pwd)"

# Use passed DATA_DIR (must match LÖVE getSaveDirectory(): saves/love/retrosync when XDG_DATA_HOME=GAMEDIR/saves).
if [[ -n "${2:-}" ]]; then
  DATA_DIR="$2"
else
  DATA_DIR="$GAMEDIR/saves/love/retrosync"
fi
mkdir -p "$DATA_DIR"

# All logs go in logs/; watcher runtime (pid, state, temp files) in watcher/.
LOGS_DIR="${DATA_DIR}/logs"
WATCHER_DIR="${DATA_DIR}/watcher"
mkdir -p "$LOGS_DIR"
mkdir -p "$WATCHER_DIR"

PIDFILE="$WATCHER_DIR/watcher.pid"
STATEFILE="$WATCHER_DIR/watcher_state.tsv"
LOGFILE="$LOGS_DIR/watcher.log"

# App config (shared with LÖVE app; single config.json)
CONFIG_JSON="$DATA_DIR/config.json"
DEFAULT_SERVER_URL="https://retrosync.vercel.app"

log() {
  # shellcheck disable=SC2059
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE"
}

num_or_zero() {
  # Ensure numeric output for arithmetic contexts
  local v="${1:-}"
  if [[ "$v" =~ ^[0-9]+$ ]]; then
    printf '%s' "$v"
  else
    printf '0'
  fi
}

# Timestamps outside this range are considered invalid/corrupted (e.g., CRC values).
# Range: Jan 2015 to Jan 2035 (should cover any reasonable save file modification time)
MIN_VALID_TIMESTAMP=1420070400    # 2015-01-01 00:00:00 UTC
MAX_VALID_TIMESTAMP=2051222400    # 2035-01-01 00:00:00 UTC

is_valid_timestamp() {
  local ts="${1:-0}"
  ts="$(num_or_zero "$ts")"
  [[ "$ts" -ge "$MIN_VALID_TIMESTAMP" && "$ts" -le "$MAX_VALID_TIMESTAMP" ]]
}

# Portable file stat utility: tries multiple methods.
# Returns "method raw_output" where method is one of: gnu, bsd, busybox, fallback, none.
# Output format: "method mtime_seconds size_bytes"
get_raw_stat() {
  local file="$1"
  local out=""
  local method="none"

  # Prefer GNU/coreutils stat format if available
  if out="$(stat -c '%Y %s' "$file" 2>/dev/null)"; then
    method="gnu"
  # macOS/BSD stat fallback (dev mode)
  elif out="$(stat -f '%m %z' "$file" 2>/dev/null)"; then
    method="bsd"
  else
    # BusyBox stat fallback
    out="$(busybox stat -c '%Y %s' "$file" 2>/dev/null || true)"
    if [[ -n "$out" ]]; then
      method="busybox"
    fi
  fi

  # Try date -r (works on SpruceOS/BusyBox where stat is unavailable)
  if [[ -z "$out" ]]; then
    local mtime_dr size_dr
    mtime_dr="$(date -r "$file" +%s 2>/dev/null || true)"
    if [[ -n "$mtime_dr" && "$mtime_dr" =~ ^[0-9]+$ ]]; then
      size_dr="$(wc -c < "$file" 2>/dev/null | tr -d ' ' || echo 0)"
      out="$mtime_dr $size_dr"
      method="date-r"
    fi
  fi

  # If all methods failed, use 0 as mtime + file size from wc.
  # Using 0 (invalid timestamp) ensures comparison logic only checks SIZE.
  # DO NOT use current time - it changes every poll, causing infinite re-uploads.
  if [[ -z "$out" ]]; then
    local size_bytes
    size_bytes="$(wc -c < "$file" 2>/dev/null | tr -d ' ' || echo 0)"
    if [[ -n "$size_bytes" ]]; then
      out="0 $size_bytes"
      method="fallback"
    fi
  fi

  printf '%s %s' "$method" "$out"
}

json_escape() {
  # Minimal JSON string escape: backslash, quote, newline, tab, carriage return
  # (paths on these devices should be simple, but we still harden a bit)
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

read_server_url() {
  if [[ -f "$CONFIG_JSON" ]]; then
    local url
    if command -v jq >/dev/null 2>&1; then
      url="$(jq -r '.serverUrl // empty' "$CONFIG_JSON" 2>/dev/null)"
    else
      url="$(tr -d '\n\r' < "$CONFIG_JSON" 2>/dev/null | grep -oE '"serverUrl"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -nE 's/.*:[[:space:]]*"([^"]*)"$/\1/p' | head -n 1)"
    fi
    if [[ -n "$url" ]]; then
      url="${url%/}"
      printf '%s' "$url"
      return
    fi
  fi
  printf '%s' "$DEFAULT_SERVER_URL"
}

read_api_key() {
  if [[ ! -f "$CONFIG_JSON" ]]; then
    return 1
  fi
  local key
  # Prefer jq; fallback to grep/sed for BusyBox/macOS without jq
  if command -v jq >/dev/null 2>&1; then
    key="$(jq -r '.apiKey // empty' "$CONFIG_JSON" 2>/dev/null)"
  else
    key="$(tr -d '\n\r' < "$CONFIG_JSON" 2>/dev/null | grep -oE '"apiKey"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -nE 's/.*:[[:space:]]*"([^"]*)"$/\1/p' | head -n 1)"
  fi
  if [[ -n "$key" ]]; then
    printf '%s' "$key"
    return 0
  fi
  return 1
}

stat_mtime_size() {
  # outputs: "<mtime_sec>\t<size_bytes>"
  local file="$1"

  # Reuse the shared helper so behavior is consistent across platforms
  local method out
  # shellcheck disable=SC2155
  method_and_raw="$(get_raw_stat "$file")"
  method="$(printf '%s' "$method_and_raw" | awk '{print $1}')"
  out="$(printf '%s' "$method_and_raw" | cut -d' ' -f2-)"

  log "stat_mtime_size: file=$(printf '%q' "$file") method=$method raw='${out}'"

  # Normalize to tab-separated, numeric-safe output
  local mtime size
  mtime="$(printf '%s' "$out" | awk '{print $1}')"
  size="$(printf '%s' "$out" | awk '{print $2}')"
  mtime="$(num_or_zero "$mtime")"
  size="$(num_or_zero "$size")"

  if [[ "$mtime" == "0" && "$size" == "0" ]]; then
    log "stat_mtime_size: ZERO stats after parsing for $(printf '%q' "$file")"
  fi

  printf '%s\t%s' "$mtime" "$size"
}

base64_file() {
  # single-line base64 without wrapping
  # busybox base64 doesn't always support -w, so we strip newlines.
  base64 < "$1" | tr -d '\n'
}

upload_file() {
  local server_url="$1"
  local api_key="$2"
  local path="$3"
  local mtime_sec="$4"
  local size_bytes="$5"
  mtime_sec="$(num_or_zero "$mtime_sec")"
  size_bytes="$(num_or_zero "$size_bytes")"
  
  # Sanitize timestamp: if outside valid range, use current time
  # This handles corrupted FS mtimes (e.g., CRC values stored as mtime on FAT32)
  if ! is_valid_timestamp "$mtime_sec"; then
    local old_mtime="$mtime_sec"
    mtime_sec="$(date +%s 2>/dev/null || echo "$MIN_VALID_TIMESTAMP")"
    log "upload: sanitizing invalid mtime ${old_mtime} -> ${mtime_sec} for $(printf '%q' "$path")"
  fi

  # Debounce: if file is still changing (e.g. being written), wait briefly.
  # Two quick samples 1s apart; if SIZE differs, skip this tick.
  # NOTE: We only compare SIZE, not mtime, because when stat fails and we use
  # fallback mode, "mtime" is just current timestamp which always changes.
  local s1 s2 size1 size2
  s1="$(stat_mtime_size "$path" || true)"
  sleep 1
  s2="$(stat_mtime_size "$path" || true)"
  # Extract just the size (second tab-separated field)
  size1="$(printf '%s' "$s1" | awk -F'\t' '{print $2}')"
  size2="$(printf '%s' "$s2" | awk -F'\t' '{print $2}')"
  if [[ "$size1" != "$size2" ]]; then
    log "debounce: skipping (still writing) $(printf '%q' "$path") (size1='$size1' size2='$size2')"
    return 2
  fi

  log "upload: attempting $(printf '%q' "$path") (mtime=${mtime_sec}s size=${size_bytes}B)"

  local file_b64
  if ! file_b64="$(base64_file "$path" 2>/dev/null)"; then
    log "upload: failed to base64 $(printf '%q' "$path")"
    return 1
  fi

  # Match the main client: use basename for filePath/saveKey, full path as localPath.
  local filename
  filename="$(basename "$path")"
  local filePath_json
  filePath_json="$(json_escape "$filename")"
  local saveKey_json
  saveKey_json="$filePath_json"  # saveKey should match filePath (basename)
  local localPath_json
  localPath_json="$(json_escape "$path")"
  local local_ms
  local_ms="$((mtime_sec * 1000))"

  local payload
  payload="$(printf '{"filePath":"%s","saveKey":"%s","fileSize":%s,"action":"upload","fileContent":"%s","localPath":"%s","localModifiedAt":%s}' \
    "$filePath_json" \
    "$saveKey_json" \
    "$size_bytes" \
    "$file_b64" \
    "$localPath_json" \
    "$local_ms")"

  # Write JSON payload to a temp file so we don't hit shell ARG_MAX limits with large saves.
  local tmp_payload="$WATCHER_DIR/watcher_payload.$$.json"
  local tmp_resp="$WATCHER_DIR/watcher_http_resp.$$.txt"
  local tmp_err="$WATCHER_DIR/watcher_http_err.$$.txt"
  rm -f "$tmp_payload" "$tmp_resp" "$tmp_err"
  printf '%s' "$payload" > "$tmp_payload" || {
    log "upload: failed to write payload for $(printf '%q' "$path")"
    rm -f "$tmp_payload" "$tmp_resp" "$tmp_err"
    return 1
  }

  if curl -sS --connect-timeout 10 --max-time 60 \
    -H "Content-Type: application/json" \
    -H "x-api-key: $api_key" \
    --data-binary "@$tmp_payload" \
    "$server_url/api/sync/files" >"$tmp_resp" 2>"$tmp_err"; then
    # Best-effort: treat success when response contains '"success":true'
    if grep -q '"success"[[:space:]]*:[[:space:]]*true' "$tmp_resp" 2>/dev/null; then
      log "upload: success $(printf '%q' "$path")"
      rm -f "$tmp_payload" "$tmp_resp" "$tmp_err"
      return 0
    fi
    if grep -q '"skipped"[[:space:]]*:[[:space:]]*true' "$tmp_resp" 2>/dev/null; then
      log "upload: skipped (unchanged/disabled) $(printf '%q' "$path")"
      rm -f "$tmp_payload" "$tmp_resp" "$tmp_err"
      return 0
    fi
    log "upload: server rejected $(printf '%q' "$path"); resp=$(head -c 200 "$tmp_resp" 2>/dev/null || true)"
    rm -f "$tmp_payload" "$tmp_resp" "$tmp_err"
    return 1
  else
    log "upload: curl failed $(printf '%q' "$path"); err=$(head -c 200 "$tmp_err" 2>/dev/null || true)"
    rm -f "$tmp_payload" "$tmp_resp" "$tmp_err"
    return 1
  fi
}

discover_files() {
  # Output lines: path<TAB>mtime<TAB>size
  # Roots: config.json .scanPaths (via jq), else defaults.
  local -a locations=()
  if [[ -f "$CONFIG_JSON" ]] && command -v jq >/dev/null 2>&1; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [[ -z "$line" ]] && continue
      [[ "$line" == *"/" ]] && line="${line%/}"
      locations+=( "$line" )
    done < <(jq -r '.scanPaths[]?.path // empty' "$CONFIG_JSON" 2>/dev/null || true)
  fi
  if [[ ${#locations[@]} -eq 0 ]]; then
    locations=(
      "/mnt/sdcard/Saves/saves"
      "/mnt/mmc/MUOS/save/file"
    )
    if [[ -n "${HOME:-}" ]]; then
      locations+=( "$HOME/Library/Application Support/OpenEmu" )
    fi
  fi

  local loc
  for loc in "${locations[@]}"; do
    [[ -d "$loc" ]] || continue
    log "discover_files: scanning root $(printf '%q' "$loc")"
    # -print0 to survive spaces; read in bash loop.
    while IFS= read -r -d '' f; do
      [[ -f "$f" ]] || continue
      local st
      st="$(stat_mtime_size "$f" || true)"
      local mtime size
      mtime="$(printf '%s' "$st" | awk -F'\t' '{print $1}')"
      size="$(printf '%s' "$st" | awk -F'\t' '{print $2}')"
      mtime="$(num_or_zero "$mtime")"
      size="$(num_or_zero "$size")"
      if [[ "$mtime" == "0" && "$size" == "0" ]]; then
        log "discover_files: ZERO stats for $(printf '%q' "$f") st='${st}'"
      fi
      printf '%s\t%s\t%s\n' "$f" "$mtime" "$size"
    done < <(find "$loc" -type f \( -name '*.sav' -o -name '*.srm' \) ! -name '*.bak' -print0 2>/dev/null || true)
  done
}

already_running() {
  if [[ -f "$PIDFILE" ]]; then
    local pid
    pid="$(cat "$PIDFILE" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

write_pid() {
  echo "$$" > "$PIDFILE"
}

cleanup_pid() {
  rm -f "$PIDFILE"
}

trap 'log "watcher: exiting"; cleanup_pid' EXIT INT TERM

if already_running; then
  exit 0
fi

write_pid
log "watcher: started (pid=$$, gamedir=$GAMEDIR)"

# Main loop config (can be overridden by watcher.conf)
MIN_INTERVAL_SEC=10
MAX_INTERVAL_SEC=60
IDLE_BACKOFF_FACTOR=2

CONF="$WATCHER_DIR/watcher.conf"
if [[ -f "$CONF" ]]; then
  # shellcheck disable=SC1090
  source "$CONF" || true
fi

interval="$MIN_INTERVAL_SEC"
touch "$STATEFILE" 2>/dev/null || true

while true; do
  if ! api_key="$(read_api_key)"; then
    # Not paired yet; sleep and retry.
    sleep 5
    continue
  fi
  server_url="$(read_server_url)"

  new_tmp="$WATCHER_DIR/watcher_state.new.$$"
  old_tmp="$WATCHER_DIR/watcher_state.old.$$"
  cp -f "$STATEFILE" "$old_tmp" 2>/dev/null || : > "$old_tmp"

  # Build new snapshot
  discover_files | sort > "$new_tmp"

  # Log snapshot sizes for debugging
  old_count="$(wc -l < "$old_tmp" 2>/dev/null | tr -d ' ' || echo 0)"
  new_count="$(wc -l < "$new_tmp" 2>/dev/null | tr -d ' ' || echo 0)"
  log "watcher: snapshot sizes old=${old_count} new=${new_count}"

  # Safety check: if discover_files returned nothing, skip this cycle
  # This prevents clearing the state file due to transient issues (SD card, etc.)
  if [[ "${new_count:-0}" -eq 0 ]]; then
    log "watcher: WARNING - discover_files returned 0 files, skipping cycle to preserve state"
    rm -f "$new_tmp" "$old_tmp" 2>/dev/null || true
    sleep "$interval"
    continue
  fi

  # Compute changed set (new file or mtime/size changed)
  changed_tmp="$WATCHER_DIR/watcher_changed.$$"
  
  # FIX: When old_tmp is empty, all files in new_tmp are "new" and should be uploaded.
  # The standard NR==FNR awk idiom fails when the first file is empty because
  # NR==FNR is always true for the second file (both counters start at 1).
  if [[ "${old_count:-0}" -eq 0 ]]; then
    # All files are new - copy new_tmp to changed_tmp (with empty 4th column for old stats)
    log "watcher: old state empty, treating all ${new_count} files as new"
    awk -F'\t' '{print $0"\t"}' "$new_tmp" > "$changed_tmp" || true
  else
    # Normal case: compare old vs new
    # IMPORTANT: If either old or new timestamp is INVALID (outside valid range),
    # we can only trust SIZE comparison. Timestamps may be corrupted CRC values
    # from older watcher versions, or fallback timestamps (current time).
    awk -F'\t' -v minTs="$MIN_VALID_TIMESTAMP" -v maxTs="$MAX_VALID_TIMESTAMP" '
      function validTs(ts) {
        return (ts+0 >= minTs && ts+0 <= maxTs)
      }
      NR==FNR {
        old_mtime[$1] = $2
        old_size[$1] = $3
        next
      }
      {
        path = $1
        new_mtime = $2
        new_size = $3
        
        if (!(path in old_mtime)) {
          # New file - upload
          print path "\t" new_mtime "\t" new_size "\t"
        } else {
          om = old_mtime[path]
          os = old_size[path]
          
          # If either timestamp is invalid, ONLY compare sizes
          if (!validTs(om) || !validTs(new_mtime)) {
            # Timestamp unreliable - only upload if size changed
            if (os != new_size) {
              print path "\t" new_mtime "\t" new_size "\t" om "\t" os
            }
          } else {
            # Both timestamps valid - compare mtime AND size as before
            if (om != new_mtime || os != new_size) {
              print path "\t" new_mtime "\t" new_size "\t" om "\t" os
            }
          }
        }
      }
    ' "$old_tmp" "$new_tmp" > "$changed_tmp" || true
  fi

  # changed_tmp now has: path \t new_mtime \t new_size \t old_mtime_size
  changed_count="$(wc -l < "$changed_tmp" 2>/dev/null | tr -d ' ' || echo 0)"
  any_error=0
  if [[ "${changed_count:-0}" -gt 0 ]]; then
    log "watcher: detected $changed_count changed file(s)"
    # Log each changed entry with before/after stats
    while IFS=$'\t' read -r path mtime size old_pair; do
      [[ -n "${path:-}" ]] || continue
      log "watcher: changed $(printf '%q' "$path") old='${old_pair:-none}' new='${mtime}\t${size}'"
    done < "$changed_tmp"

    # Now upload each changed file (ignore the 4th column)
    while IFS=$'\t' read -r path mtime size _old_pair; do
      [[ -n "${path:-}" ]] || continue
      upload_file "$server_url" "$api_key" "$path" "${mtime:-0}" "${size:-0}"
      # Return codes: 0=success, 1=error, 2=debounce (still writing)
      # Only treat actual errors (ret=1) as failures. Debounce (ret=2) is not an error.
      # Note: capture $? immediately, don't use 'local' which can reset it on some shells
      case $? in
        1) any_error=1 ;;
      esac
    done < "$changed_tmp"

    # Reset backoff after activity
    interval="$MIN_INTERVAL_SEC"
  else
    # Backoff when idle to reduce load
    if [[ "$interval" -lt "$MAX_INTERVAL_SEC" ]]; then
      interval=$((interval * IDLE_BACKOFF_FACTOR))
      if [[ "$interval" -gt "$MAX_INTERVAL_SEC" ]]; then interval="$MAX_INTERVAL_SEC"; fi
    fi
  fi

  if [[ "$any_error" -eq 0 ]]; then
    mv -f "$new_tmp" "$STATEFILE" 2>/dev/null || true
  else
    log "watcher: errors during upload; keeping previous watcher_state.tsv so failed files will retry"
    rm -f "$new_tmp" 2>/dev/null || true
  fi
  rm -f "$old_tmp" "$changed_tmp" 2>/dev/null || true

  sleep "$interval"
done
