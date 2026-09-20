# Troubleshooting

Start with `make doctor`. It's read-only and checks most of what's below.

## Installation

**`brew: command not found` right after installing Homebrew.**
On Apple Silicon, Homebrew lives in `/opt/homebrew`, which isn't on `PATH` until a new login shell starts. Run `eval "$(/opt/homebrew/bin/brew shellenv)"` or open a new terminal. `setup.sh` and the chezmoi scripts already do this.

**`error calling onepasswordRead` during `chezmoi apply`.**
The 1Password CLI can't reach the app. Check that 1Password is unlocked and that **Settings → Developer → Integrate with 1Password CLI** is on, then run `op whoami`. Also check that the item exists: `op read "op://Private/GPG/GitSigningKey"`.

**`map has no entry for key "gitSigning"` (or another key).**
Your chezmoi config predates a new question. Run `chezmoi init` to answer it; existing answers are kept.

**`brew bundle` reports failed entries.**
Usually a Mac App Store app (sign in to the App Store), a cask that needs your password, or a renamed package. Setup continues anyway. Fix the cause and run `brew bundle --file=~/.local/share/chezmoi/Brewfile`. To see what's missing, run `brew bundle check --file=… --verbose`.

**A setup step didn't run again after I changed something.**
`run_onchange_` scripts re-run only when their rendered content changes; each embeds a hash of the file it calls. To make chezmoi forget which scripts have run, clear `entryState` (for `run_onchange_`) or `scriptState` (for `run_once_`) with `chezmoi state delete-bucket --bucket=<name>`, then run `chezmoi apply`. To run one step directly, use `make macos`, `make dock` and so on.

## Git and SSH

**Commits fail with `gpg failed to sign the data`.**

- Check that the key is in the keyring: `gpg --list-secret-keys`. If not, run `scripts/restore.sh gpg`.
- `GPG_TTY` must be set, which `.zshrc` does. In GUI apps such as VS Code, the curses `pinentry` can't prompt; commit from a terminal, or switch to [SSH signing](configuration.md#commit-signing).
- After editing `gpg-agent.conf`, run `gpgconf --kill gpg-agent`.

**`scripts/restore.sh gpg` says a 1Password document is empty.**
Old versions of `backup.sh` uploaded empty GPG exports. Open the document in 1Password and check its item history for an earlier, non-empty version. If none exists and the keys are still on another Mac, run `make backup WHAT=gpg` there.

**SSH asks for a password or reports `Permission denied (publickey)`.**
Turn on **Settings → Developer → Use the SSH agent** in 1Password and check `ssh-add -l` with `SSH_AUTH_SOCK` pointing to the agent socket (doctor does this). Hosts in `~/.ssh/config.local` take precedence over the managed defaults.

## macOS settings

**Settings didn't apply.**
Locale and trackpad settings need a logout. If one keeps showing up in `make macos-preview` after that, macOS may have changed the key. Check the current value with `defaults read <domain> <key>` and update [`scripts/macos-defaults.sh`](../scripts/macos-defaults.sh) and [the docs](macos-defaults.md).

**The Dock is missing an app.**
`scripts/dock.sh` skips apps that aren't installed, with a warning. Install the app, then run `make dock`.

## Shell

**The first prompt is red.**
Something at the end of `.zshrc` returned an error. Run `zsh -x -i -c exit 2>&1 | tail` to find it.

**`zoxide: detected a possible configuration issue`.**
zoxide must be initialised last in `.zshrc`. Make sure nothing was added after it.

## Backups

**`backup location … does not exist`.**
Turn on iCloud Drive with **Desktop & Documents Folders**, or set `backupDir` with `chezmoi init --prompt`.

**Restore says the checksum doesn't match.**
iCloud may still be syncing the archive. Wait for it to finish downloading in Finder, then try again. If it keeps failing, restore an older backup with `--from <timestamp>`.
