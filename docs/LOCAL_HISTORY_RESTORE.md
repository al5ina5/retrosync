# Restoring files from Cursor/VS Code Local History

Local History keeps **per-file** snapshots (saves, undos). There is **no “restore all”** for a folder—you restore one file at a time. Here’s how to get back as many files as you can.

---

## 1. Restore a single file (Timeline)

1. In the **Explorer** sidebar, right‑click the file (or its parent folder if the file is missing).
2. Click **Open Local History** (or **Timeline** at the bottom of the Explorer).
3. In the list, pick the entry you want (e.g. “File Saved January 30, 2026 at 3:31 AM”).
4. Use **Restore** / **Restore Contents** to bring that version back.

For a **deleted** file: open Local History from the **folder** that used to contain it (e.g. `client/src/ui/`). You should see entries for files that were in that folder; pick the file and restore.

---

## 2. Search across all Local History (restore any file)

1. **Command Palette:** `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux).
2. Run: **“Local History: Find Entry to Restore”**  
   (command id: `workbench.action.localHistory.restoreViaPicker`)
3. A list of **all** Local History entries opens. Use the search box to filter by path or date.
4. Pick an entry and restore it. You can repeat this for every missing file.

This is the closest to “restore all”: run the command, then go through the list and restore each file you care about.

---

## 3. Restore from a folder (file by file)

1. In Explorer, right‑click the folder (e.g. `client/src/ui` or `dashboard/src/app/client`).
2. **Open Local History** (if available for the folder).
3. Restore **each file** you need from the history entries shown.

If “Open Local History” is only on files, use **“Local History: Find Entry to Restore”** and search for paths under that folder (e.g. `client/src/ui`, `dashboard/src/app/client`).

---

## 4. Files you may want to restore

Use the steps above and look for history entries for:

**Lua client (if you had more UI modules):**

- `client/src/ui/palette.lua` (you already restored this)
- `client/src/ui/design.lua`
- `client/src/ui/loading.lua`
- Any other files under `client/src/`

**Dashboard:**

- `dashboard/src/app/client/page.tsx` (we recreated a new one; you can replace it with your old version from Local History if you find it)
- `dashboard/src/components/client/*`
- `dashboard/src/components/ui/ConfirmScreen.tsx`

---

## 5. Where Local History is stored

On Mac, Cursor/VS Code usually keeps it under:

- **Cursor:** `~/Library/Application Support/Cursor/User/History/`
- **VS Code:** `~/Library/Application Support/Code/User/History/`

Entries are in hashed folders; the **“Local History: Find Entry to Restore”** command is the easiest way to use them rather than browsing that folder by hand.

---

## Summary

| Goal                         | How |
|-----------------------------|-----|
| Restore one file            | Right‑click file (or folder) → Open Local History → pick entry → Restore. |
| Restore as many files as possible | `Cmd+Shift+P` → **“Local History: Find Entry to Restore”** → search and restore each file. |
| Restore a deleted file      | Open Local History from the **folder** that contained it, or use “Find Entry to Restore” and search by path/name. |

There is no single “restore all files” action; use **“Find Entry to Restore”** and go through the list to restore everything you need.
