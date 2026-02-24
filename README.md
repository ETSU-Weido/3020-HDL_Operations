# 3020-HDL Operations: 
                 Expanded HTML README/HELP File: 
                 
*****************  https://3020-hdl.netlify.app/ *****************
                      

**CSCI 3020 · SQLite Database Project**

---

## 📁 Repo Layout

```
sql/00_schema.sql     ← ★ SOURCE OF TRUTH (all schema changes go here)
erd/erd.png           ← update after every schema change
scripts/rebuild.ps1   ← builds the DB from schema
db/                   ← your local .db lives here (never committed)
```

---

## ⚠️ Golden Rules

> Break these and things get messy fast.

1. **Never commit `.db` files** — they're binary and don't merge.
2. **Schema changes go in `sql/00_schema.sql`** — edit the file, rebuild, commit. Don't edit the DB directly.
3. **Update the ERD after any schema change** — export from DB Browser / dbdiagram.io → `erd/erd.png` → commit it with the schema.

---

## 🛠 One-Time Setup (Windows)

**1. Git**
```powershell
git --version   # confirm it's installed
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

**2. SQLite CLI**
```powershell
winget install SQLite.SQLite
sqlite3 --version   # confirm
```

**3. DB Browser for SQLite** — download from [sqlitebrowser.org](https://sqlitebrowser.org) and install normally.

---

## 🚀 First-Time Project Setup

```powershell
# 1. Clone
cd $HOME\Documents
git clone <REPO_URL>
cd 3020-HDL_Operations

# 2. Build local DB
.\scripts\rebuild.ps1

# 3. Open in DB Browser for SQLite
#    File → Open Database
#    Navigate to: 3020-HDL_Operations\db\csci3020_lab2.db
#    Tables appear in the "Database Structure" tab
```

---

## 🔁 Normal Workflow

**Every session — pull first:**
```powershell
git pull
.\scripts\rebuild.ps1   # only needed if schema changed
```

### Changed the schema?
```powershell
# 1. Edit sql/00_schema.sql
# 2. Rebuild
.\scripts\rebuild.ps1
# 3. Verify tables in DB Browser (File → Open Database → check Database Structure tab)
# 4. Export ERD → erd/erd.png  (DB Browser doesn't generate ERDs natively —
#    use draw.io, dbdiagram.io, or similar and export to erd/erd.png)
# 5. Commit
git add sql/00_schema.sql erd/erd.png
git commit -m "Describe what you changed"
git push
```

### Docs / notes only?
```powershell
git add <files>
git commit -m "Short message"
git push
```

---

## 🌿 Branching (recommended for schema changes)

```powershell
git checkout -b feature/<short-name>
# ... make changes, commit ...
git push -u origin feature/<short-name>
# Then open a Pull Request on GitHub → merge into main
```

> One person editing schema at a time avoids conflicts.

---

## ⌨️ Commands Cheat Sheet

| Task | Command |
|------|---------|
| Check status | `git status` |
| Pull latest | `git pull` |
| Rebuild DB | `.\scripts\rebuild.ps1` |
| Stage file | `git add <file>` |
| Commit | `git commit -m "Message"` |
| Push | `git push` |
| New branch | `git checkout -b feature/name` |
| Unstage file | `git restore --staged <file>` |
| Discard changes | `git checkout -- <file>` |
| Update branch w/ main | `git checkout main && git pull && git checkout feature/name && git merge main` |

---

## 🔴 Common Gotchas

**Accidentally staged a `.db` file**
```powershell
git restore --staged db\csci3020_lab2.db
```
Make sure `.gitignore` includes `*.db`, `*.db-wal`, `*.db-shm`.

**DB Browser shows no tables / stale tables after rebuild**
→ Close and re-open the `.db` file: **File → Close Database**, then **File → Open Database** again.

**Pulled and DB looks wrong**
→ Run `.\scripts\rebuild.ps1`, then re-open the `.db` file in DB Browser.

**Merge conflict in `00_schema.sql`**
→ Talk to your team, agree on the correct schema, resolve manually, then rebuild.

**Good commit messages**
- ❌ `fix`, `update`, `changes`
- ✅ `Add RentalContract foreign keys`, `Add indexes on FK columns`

---

## 📬 What We Submit

- `sql/00_schema.sql`
- `erd/erd.png` (or `.pdf`)
- If instructor wants a `.db`: generate it locally and submit directly — **do not commit it**.
