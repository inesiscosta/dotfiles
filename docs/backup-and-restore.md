# Backup and restore

chezmoi restores configuration. [`scripts/backup.sh`](../scripts/backup.sh) and [`scripts/restore.sh`](../scripts/restore.sh) cover what it can't: keys, code and app settings.

```sh
make backup-preview                # what a backup would do
make backup                        # everything
make backup WHAT="dev prefs"       # or pick: gpg, dev, prefs, brew

make restore-preview               # what a restore would change
make restore WHAT=dev              # restore requires an explicit choice: gpg, dev, prefs, all
scripts/restore.sh --from 20261115-171500 dev   # a specific backup
```

## What is backed up, and where

| Component | Destination | Format |
| --- | --- | --- |
| `gpg` | 1Password documents `GPG Public Keys`, `GPG Private Keys`, `GPG TrustDB` | ASCII-armoured export and ownertrust, piped straight into `op`, never written to disk |
| `dev` | `<backupDir>/developer/developer-<timestamp>.zip` + `.sha256` | `~/Developer` without `node_modules`, `.venv`, `__pycache__` and `.DS_Store`. Symlinks are stored as links |
| `prefs` | `<backupDir>/preferences/<timestamp>/<domain>.plist` | `defaults export` |
| `brew` | `<backupDir>/brew/Brewfile-<timestamp>` | `brew bundle dump` snapshot; the curated `Brewfile` is untouched |

`backupDir` defaults to `~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Backup`, which is in iCloud Drive. The newest `backupKeep` (default 3) backups of each kind are kept and older ones are deleted. Both are set with `chezmoi init --prompt`. Override for a single run with `DOTFILES_BACKUP_DIR=…`.

## Safety guarantees

- **Nothing is overwritten silently.**
  - Replacing an existing 1Password document asks first.
  - Restoring `~/Developer` lists the files that already exist and keeps them unless you confirm.
  - Restoring preferences asks for each app that already has settings, and saves them first to `~/.local/state/dotfiles/pre-restore/<timestamp>/`.
- **Nothing is deleted from 1Password.** GPG restore only imports, and skips itself when the keyring already has secret keys.
- **Integrity.** Archives are built in a temporary directory, tested with `unzip -t` and checksummed before being moved into place, so a partial archive never reaches iCloud. Restore checks the checksum and tests the archive again before extracting.
- **Empty exports are refused.** Backup aborts if a GPG export is empty, and restore refuses an empty 1Password document. An earlier version of `backup.sh` redirected its exports to `/dev/null` and uploaded empty files.
- **Permissions.** Backups are created with `umask 077`, so only you can read them.
- **No terminal, no destructive answer.** Without a TTY every confirmation defaults to "no". Set `ASSUME_YES=1` only when you mean it.

## iCloud caveats

- iCloud uploads in the background. After `make backup`, wait until Finder shows the files as uploaded before erasing a Mac.
- With **Optimize Mac Storage** on, iCloud may evict old backups to placeholders. Restore detects this, downloads them with `brctl download` and waits.
- The default path needs iCloud Drive's **Desktop & Documents Folders** option, which creates `CloudDocs/Documents`. Without it, choose another `backupDir`.
- iCloud data is encrypted end to end only with **Advanced Data Protection** on. `~/Developer` can hold `.env` files and other credentials, so either turn ADP on or point `backupDir` at an encrypted external disk.

## App preferences

Whether `defaults export` and `defaults import` are a good fit depends on the app:

| App | Domain | Assessment |
| --- | --- | --- |
| AltTab | `com.lwouis.alt-tab-macos` | Good fit: all settings are in its preferences |
| Rectangle | `com.knollsoft.Rectangle` | Good fit. Rectangle also has its own JSON export in its settings |
| CleanShot X | `pl.maketheweb.cleanshotx` | Good fit for its settings |
| Raycast | `com.raycast.macos` | **Partial**: only app-level settings. Extensions, snippets, quicklinks and hotkeys live in Raycast's own database. Use Raycast → Settings → Advanced → Export to make a `.rayconfig` file and keep it next to these backups |

Restore only imports preferences for apps that are installed and not running, because a running app overwrites imported settings when it quits. To undo an import, run `defaults import <domain> ~/.local/state/dotfiles/pre-restore/<timestamp>/<domain>.plist`.

## Recovering a Mac from scratch

1. Run `setup.sh` (see [Installation](installation.md)). GPG keys come back automatically when signing with GPG.
2. `cd ~/.local/share/chezmoi && make restore-preview`
3. `make restore WHAT=prefs` (quit those apps first), then `make restore WHAT=dev`
4. Import the Raycast `.rayconfig` by hand.
