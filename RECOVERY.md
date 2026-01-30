# Recovery from pre–.env-removal state

After removing `.env` and other secrets from git history, the **old commits are still in your repo** as unreachable objects. You can recover them.

## Recovery branch

A branch **`recovery/pre-rewrite`** points at the last commit **before** the second filter-branch (the one that removed `dashboard/.env`, `client/data/api_key`, etc.):

- **Commit:** `ce971be` — “feat: Enhance macOS client functionality…”
- **Contains:** Full tree at that moment (including the removed sensitive files). Use it only to **inspect or copy** content, not to push.

```bash
git checkout recovery/pre-rewrite   # look at old state
git checkout main                   # back to current
git diff recovery/pre-rewrite main  # see what changed (ignore .env / api_key)
```

## Unreachable commits (still in repo)

`git fsck --unreachable --no-reflogs` lists commits that are no longer on any branch. Those are the **pre-rewrite** commits. Do **not** run `git gc --prune` if you want to keep them until you’ve recovered what you need.

To list and inspect:

```bash
git fsck --unreachable --no-reflogs 2>/dev/null | grep "commit "
git show <commit-hash> --name-only   # see files in that commit
git show <commit-hash>:path/to/file  # dump a file from that commit
```

## What was never in git

From the initial project state, these were **untracked** (never committed), so they are **not** in any commit:

- `dashboard/src/app/client/` (client page)
- `dashboard/src/components/client/`
- `dashboard/src/components/ui/ConfirmScreen.tsx`

A new **`dashboard/src/app/client/page.tsx`** has been recreated (pairing instructions + `DevicePairForm`). If your original client page or ConfirmScreen did something different, you’ll need to recreate that logic from memory or backups.

## If you have another clone or backup

If you have another clone from **before** the force-push, or a backup of the repo:

1. Copy the files you need from that clone/backup into this repo.
2. Or add that clone as a remote and diff/cherry-pick:

   ```bash
   git remote add backup /path/to/old/clone
   git fetch backup
   git log backup/main --oneline -20
   git diff backup/main -- dashboard/
   ```

## Summary

- **`recovery/pre-rewrite`** = last “full” state before the second history rewrite.
- **Unreachable commits** = rest of the old history; use `git show <hash>:` to pull out files.
- **Client page** = recreated as `dashboard/src/app/client/page.tsx`; adjust as needed.
- **ConfirmScreen / components/client** = were never committed; recreate from memory or backup if you need them.
