# Arca Backup-Fix (Version 2.4) — Anwendung

Dieser Ordner enthält den Backup-Fix für **Arca** (`zenruffinen/Arca`).

## Option A: Dateien direkt kopieren

1. Öffne dein lokales Arca-Projekt
2. Ersetze diese Dateien:
   - `arca/AppStore.swift`
   - `arca/ContentView.swift`
3. Commit & Push:

```bash
git checkout -b cursor/fix-backup-v24-d373
git add arca/AppStore.swift arca/ContentView.swift
git commit -m "Fix: Backup in Version 2.4 wieder zuverlässig"
git push -u origin cursor/fix-backup-v24-d373
```

## Option B: Git-Bundle (kompletter Branch)

```bash
cd /pfad/zu/Arca
git fetch /pfad/zu/arca-backup-fix.bundle cursor/fix-backup-v24-d373:cursor/fix-backup-v24-d373
git checkout cursor/fix-backup-v24-d373
git push -u origin cursor/fix-backup-v24-d373
```

## Option C: Patch anwenden

```bash
cd /pfad/zu/Arca
git checkout -b cursor/fix-backup-v24-d373
git am /pfad/zu/arca-backup-v24.patch
git push -u origin cursor/fix-backup-v24-d373
```

## Was wurde gefixt

- Import bricht nicht mehr ab, wenn Security-Scope `false` zurückgibt
- `.arcabackup` öffnet zuverlässig das Passwort-Sheet in den Einstellungen
- iCloud-Dateien werden vor dem Export materialisiert
- Fallback auf verschlüsseltes JSON, falls Apple-Archiv fehlschlägt
- `categoryColors` und `homeFolderQuickView` werden mitgesichert
