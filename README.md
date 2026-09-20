# dotfiles

My macOS development environment, managed with [chezmoi](https://www.chezmoi.io). One command takes a freshly erased Apple Silicon Mac to my working setup: apps, shell, terminal, Git signing and system preferences.

> [!WARNING]
> This is my personal setup, not a framework. It sets my macOS preferences, installs my apps and reads secrets from **my** 1Password vault, so running it unmodified will fail or change your Mac in ways you didn't ask for. Fork it and read [Customization](docs/customization.md) first.

## Quick start

On a fresh Mac running macOS 26 or later, with a 1Password account that holds the expected items:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/inesiscosta/dotfiles/main/setup.sh)"
```

The script pauses so you can sign in to 1Password and the App Store, then asks a few questions (computer name, signing method, backup location). Restart afterwards so every preference takes effect. Full walkthrough: [Installation](docs/installation.md).

On a Mac that's already set up:

```sh
cd ~/.local/share/chezmoi
make diff      # what would change in ~
make apply     # apply it
make doctor    # check that everything is healthy
```

## Commands

| Command | What it does |
| --- | --- |
| `make doctor` | Read-only health check of the whole setup |
| `make diff` / `make apply` | Preview or apply dotfile changes |
| `make macos-preview` / `make macos` | Preview or apply macOS defaults |
| `make dock-preview` / `make dock` | Preview or apply the Dock layout |
| `make backup-preview` / `make backup` | Preview or run a backup |
| `make restore-preview` / `make restore WHAT=…` | Preview or run a restore; you must say what to restore |
| `make check` | Lint and validate the repository, as CI does |

## Documentation

- [Installation](docs/installation.md): prerequisites, 1Password setup and what happens step by step
- [Configuration](docs/configuration.md): how the repository is organised, plus commit signing
- [macOS defaults](docs/macos-defaults.md): every customised setting and why
- [Backup and restore](docs/backup-and-restore.md): what's backed up, where, and how to recover
- [Customization](docs/customization.md): adapting this repository for yourself
- [Troubleshooting](docs/troubleshooting.md)

## Acknowledgements

macOS defaults research builds on [Mathias Bynens' dotfiles](https://github.com/mathiasbynens/dotfiles) and [Kevin Suttle's macOS defaults](https://github.com/kevinSuttle/macOS-Defaults). The prompt is based on the `oh-my-zsh` robbyrussell theme.
