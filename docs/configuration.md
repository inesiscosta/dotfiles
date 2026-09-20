# Configuration

## Layout

The repository root holds tooling. The chezmoi source directory is [`home/`](../home), selected by [`.chezmoiroot`](../.chezmoiroot), so the README, docs and scripts are never copied into `~`.

| Source (in `home/`) | Target | Notes |
| --- | --- | --- |
| `dot_zshrc`, `dot_zprofile` | `~/.zshrc`, `~/.zprofile` | zsh |
| `dot_gitconfig.tmpl` | `~/.gitconfig` | Template: author and signing key |
| `dot_config/git/allowed_signers.tmpl` | `~/.config/git/allowed_signers` | Only when signing with SSH |
| `dot_config/alacritty/*.toml` | `~/.config/alacritty/` | |
| `private_dot_ssh/config` | `~/.ssh/config` | `private_` sets mode `0600` and the directory to `0700` |
| `private_dot_gnupg/gpg-agent.conf` | `~/.gnupg/gpg-agent.conf` | |
| `empty_dot_hushlogin` | `~/.hushlogin` | Hides "Last login" in new terminals |
| `Library/LaunchAgents/*.plist.tmpl` | `~/Library/LaunchAgents/` | Homebrew auto-update |
| `.chezmoiscripts/` | *(not written)* | Provisioning scripts; see [Installation](installation.md#what-chezmoi-init---apply-does) |

Run-script names follow chezmoi's conventions. `run_once_` scripts run once per machine. `run_onchange_` scripts run again when their rendered content changes. Each one embeds a hash of the file it calls, such as the `Brewfile` or `scripts/macos-defaults.sh`, so editing that file is enough to make it re-run. The scripts themselves stay thin and call into [`scripts/`](../scripts), which you can also run directly.

## Machine-specific values

Everything that varies between Macs is asked once by [`home/.chezmoi.toml.tmpl`](../home/.chezmoi.toml.tmpl) and stored in `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
    computerName = "My MacBook Air"
    localHostName = "my-macbook-air"
    gitName = "Inês Costa"
    gitEmail = "94355111+inesiscosta@users.noreply.github.com"
    gitSigning = "gpg"            # or "ssh"
    gitSigningSSHKey = ""         # op:// reference, only for "ssh"
    backupDir = "~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Backup"
    backupKeep = 3
```

Change an answer with `chezmoi init --prompt`, or edit the file and run `chezmoi apply`. The scripts in `scripts/` read the same values through `chezmoi execute-template`. Environment variables override them, for example `DOTFILES_BACKUP_DIR=/Volumes/External/Backup make backup`.

Personal preferences that are the same on every Mac, such as the Dock apps, macOS defaults and Brewfile, live in the files themselves.

## Shell

- **Prompt**: `➜` (green, or red after a failed command), the current directory, then `git:(branch)` with `✗` when tracked files have uncommitted changes. It shows the short commit hash on a detached HEAD.
- **Completion**: case-insensitive with a selectable menu. `compinit`'s full check runs at most once a day; other shells reuse the cached dump.
- **History**: 10,000 entries shared across sessions, with no duplicates and timestamps.
- **Tools**, each loaded only if installed:
  - zsh-autosuggestions
  - fzf: `Ctrl-R` history, `Ctrl-T` files with `bat` previews, `Alt-C` directories
  - fnm: Node versions from `.nvmrc`
  - pyenv
  - zoxide, as `cd`
- `ls` gets colour from `CLICOLOR=1`, the BSD equivalent of `--color=auto`. `ls --color` on macOS means `--color=always`, which leaks escape codes into pipes.

## Commit signing

Every commit is signed (`commit.gpgSign = true`). Two methods are supported, chosen with the `gitSigning` answer.

### GPG (current default)

`user.signingkey` comes from `op://Private/GPG/GitSigningKey`. On a fresh Mac the keys are imported from the three 1Password documents. gpg-agent caches the passphrase for 8 hours after last use, and for at most 24 hours in total.

### SSH through 1Password (recommended)

Git signs with an SSH key held in 1Password: `gpg.format = ssh`, with `op-ssh-sign` as the signing program. The private key never leaves 1Password, every signature needs Touch ID or the app to be unlocked, and there's no keyring to back up or restore. I recommend migrating. Until the new setup is verified, keep the GPG key in 1Password and on GitHub, so commits that were already signed stay **Verified**.

To switch:

1. In 1Password, pick or create an SSH Key item and copy its **public key** field reference, for example `op://Private/GitHub SSH Key/public key`.
2. On GitHub, go to Settings → SSH and GPG keys → New SSH key and add the same public key with **Key type: Signing Key**.
3. Run `chezmoi init --prompt`, choose `ssh` and paste the reference.
4. Run `chezmoi diff` to review the new `~/.gitconfig` and `~/.config/git/allowed_signers`, then `chezmoi apply`.
5. Verify: `git commit --allow-empty -m "test signing"` should show a 1Password prompt. `git log --show-signature -1` should show `Good "git" signature`, and the pushed commit should be **Verified** on GitHub.

To go back, run `chezmoi init --prompt`, choose `gpg` and apply. Nothing on the GPG side is deleted by switching.

## Homebrew

[`Brewfile`](../Brewfile) is curated by hand. `make backup` saves a full `brew bundle dump` snapshot to the backup directory and prints the drift between what's installed and the Brewfile. It never rewrites the Brewfile. `make doctor` reports Brewfile entries that aren't installed.

Auto-update runs from `~/Library/LaunchAgents/io.github.inesiscosta.brew-upgrade.plist` and logs to `~/Library/Logs/brew-upgrade.log`. Unlike cron, launchd catches up on a run missed while the Mac was asleep.
