# Customization

This repository is built around my Mac and my 1Password vault. To use it as a starting point, fork it and work through the list below. Run `make check` as you go; it needs no secrets.

## 1. Make it yours

| File | Change |
| --- | --- |
| [`setup.sh`](../setup.sh) | `GITHUB_USER` (or run it with `GITHUB_USER=you`) |
| [`home/.chezmoi.toml.tmpl`](../home/.chezmoi.toml.tmpl) | Default Git name and email. Everything else is asked on `chezmoi init` |
| [`Brewfile`](../Brewfile) | Your packages, apps and VS Code extensions |
| [`scripts/dock.sh`](../scripts/dock.sh) | `DOCK_APPS`. Print your current Dock in the right format with `scripts/dock.sh --print` |
| [`scripts/macos-defaults.sh`](../scripts/macos-defaults.sh) | Your preferences, especially language and region. Preview with `make macos-preview` |
| [`scripts/lib.sh`](../scripts/lib.sh) | `APP_PREFS`: which app preferences to back up |
| `home/Library/LaunchAgents/…plist.tmpl` | Rename the label from `io.github.inesiscosta…` (also in `run_onchange_after_60-brew-autoupdate.sh.tmpl`) |

## 2. Secrets

Templates read secrets with chezmoi's `onepasswordRead`. You can:

- **Keep 1Password** and change the `op://` references in [`home/dot_gitconfig.tmpl`](../home/dot_gitconfig.tmpl) to match your vault, or
- **Use another password manager.** chezmoi supports [most of them](https://www.chezmoi.io/user-guide/password-managers/). Replace the template functions, and the `op` calls in `scripts/backup.sh` and `scripts/restore.sh` if you use GPG backups.

SSH signing through 1Password is the simplest option: there is nothing to back up. See [Configuration](configuration.md#commit-signing).

## 3. Remove what you don't use

Every step is independent:

- **No macOS defaults or Dock management**: delete `home/.chezmoiscripts/run_onchange_after_40-macos-defaults.sh.tmpl` or `…50-dock.sh.tmpl`.
- **No Homebrew auto-update**: delete `…60-brew-autoupdate.sh.tmpl` and the LaunchAgent template.
- **No GPG**: choose `ssh` signing; the GPG step then does nothing. You can also delete `private_dot_gnupg/` and `…30-gpg-keys.sh.tmpl`.
- **No backups**: ignore `scripts/backup.sh` and `scripts/restore.sh`. Nothing runs them automatically.

## Terminal

Alacritty's settings are in `home/dot_config/alacritty/alacritty.toml`, and its colours (Material Darker) in `home/dot_config/alacritty/theme.toml`.

## Machine-only additions

Some settings shouldn't be committed. They go in files chezmoi doesn't manage:

- `~/.ssh/config.local`: extra SSH hosts, included from the managed `~/.ssh/config`.
- `chezmoi edit-config`: per-machine values.
