# Installation

## Prerequisites

- An Apple Silicon Mac running macOS 26 Tahoe or later.
- An administrator account (some settings need `sudo`).
- A 1Password account containing:

  | Item | Field | Used for |
  | --- | --- | --- |
  | `GPG` (vault `Private`) | `GitSigningKey` | `user.signingkey` when signing with GPG |
  | Document `GPG Public Keys` | file | GPG restore |
  | Document `GPG Private Keys` | file | GPG restore |
  | Document `GPG TrustDB` | file | GPG restore |
  | An SSH Key item | `public key` | Only when signing with SSH; see [Configuration](configuration.md#commit-signing) |
  | SSH keys | | Served to `ssh` and `git` by the 1Password SSH agent |

- An Apple Account signed in to the App Store, for the `mas` apps in the Brewfile.

## Install

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/inesiscosta/dotfiles/main/setup.sh)"
```

`setup.sh` is safe to re-run: each step skips itself if it's already done. It:

1. Installs the Xcode Command Line Tools (a macOS dialog) and waits for them.
2. Installs Homebrew and loads it into the current shell. On Apple Silicon the installer doesn't do that itself.
3. Installs `chezmoi`, the 1Password app and the 1Password CLI.
4. Pauses while you:
   - sign in to 1Password,
   - turn on **Settings → Developer → Use the SSH agent** and **Integrate with 1Password CLI**,
   - sign in to the App Store.
5. Runs `chezmoi init --apply inesiscosta`.

### What `chezmoi init --apply` does

First it asks a few questions and saves the answers to `~/.config/chezmoi/chezmoi.toml`:

| Question | Default |
| --- | --- |
| Computer name | The Mac's current name |
| Local host name | The Mac's current Bonjour name |
| Git author name and email | Mine |
| Commit signing method | `gpg` |
| Backup directory | `~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Backup` |
| Backups to keep of each kind | `3` |

Then it runs the scripts in [`home/.chezmoiscripts`](../home/.chezmoiscripts) in this order:

| Step | When it runs | What it does |
| --- | --- | --- |
| `10-homebrew` | once | Installs Homebrew if `setup.sh` was skipped |
| `20-brew-bundle` | whenever the `Brewfile` changes | `brew bundle`. Failures, such as an App Store app when you're signed out, are reported but don't stop the setup |
| *dotfiles* | every apply | Writes `~/.zshrc`, `~/.gitconfig`, Alacritty, SSH and GPG agent config |
| `30-gpg-keys` | when the signing method changes | Imports GPG keys from 1Password if the keyring has no secret keys. Never deletes the 1Password documents |
| `40-macos-defaults` | when the defaults script or computer name changes | Applies [macOS defaults](macos-defaults.md) and asks for `sudo` |
| `50-dock` | when the Dock list changes | Sets the Dock's apps with `dockutil` |
| `60-brew-autoupdate` | when the LaunchAgent changes | Loads the LaunchAgent that runs `brew update && brew upgrade && brew cleanup` on the 1st and 15th of each month |

Backups are **not** restored automatically. When the setup finishes:

```sh
cd ~/.local/share/chezmoi
make doctor            # check everything
make restore-preview   # see what a restore would do
make restore WHAT=dev  # then restore what you want: gpg, dev, prefs or all
```

## Manual steps

These can't be automated safely or reliably:

- **Restart** the Mac. Locale, trackpad and some Dock settings only apply after logging in again.
- **Menu bar and Control Center items**: choose them in System Settings → Menu Bar. Their preference keys changed in macOS 26 and aren't scriptable reliably.
- **Raycast**: import your `.rayconfig` export (Raycast → Settings → Advanced → Import). See [Backup and restore](backup-and-restore.md#app-preferences).
- **Permissions** that macOS asks for at first launch (Accessibility for Rectangle and AltTab, Screen Recording for CleanShot X, and so on).

## Manual testing checklist

These parts can't be checked in CI, so test them once on a real Mac after big changes:

- [ ] `setup.sh` on a freshly erased Mac completes without errors.
- [ ] `git commit -S` works and GitHub shows the commit as **Verified**.
- [ ] `ssh -T git@github.com` authenticates through the 1Password agent.
- [ ] `make macos-preview` shows nothing left to change after `make macos` and a logout.
- [ ] `make dock-preview` reports "Dock already matches".
- [ ] `make backup`, then `make restore-preview` on another Mac, finds the backups.
- [ ] `make doctor` reports no problems.
