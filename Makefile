# Everyday commands for this repository. Run `make` to list them.
# Targets that change your system say so; every one has a *-preview twin.

SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help check fmt diff apply doctor macos macos-preview dock dock-preview \
	backup backup-preview restore restore-preview

help: ## List available commands
	@awk 'BEGIN { FS = ":.*## " } /^[a-z-]+:.*## / { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

check: ## Lint and validate the repository (no secrets needed)
	@scripts/check.sh

fmt: ## Format shell scripts with shfmt
	@shfmt --indent 2 --write setup.sh scripts/*.sh

diff: ## Preview what `chezmoi apply` would change in your home directory
	@chezmoi diff

apply: ## Apply dotfiles and run any setup scripts whose inputs changed (changes system)
	@chezmoi apply --verbose

doctor: ## Check installation health (read-only)
	@scripts/doctor.sh

macos-preview: ## Show which macOS settings would change
	@scripts/macos-defaults.sh --dry-run

macos: ## Apply macOS settings (changes system, asks for sudo)
	@scripts/macos-defaults.sh

dock-preview: ## Show how the Dock would change
	@scripts/dock.sh --dry-run

dock: ## Set the Dock's apps (changes system)
	@scripts/dock.sh

backup-preview: ## Show what a backup would do (WHAT="gpg dev prefs brew", default all)
	@scripts/backup.sh --dry-run $(or $(WHAT),all)

backup: ## Back up GPG keys, ~/Developer, app preferences, Homebrew snapshot
	@scripts/backup.sh $(or $(WHAT),all)

restore-preview: ## Show what a restore would change (WHAT="gpg dev prefs" or all)
	@scripts/restore.sh --dry-run $(or $(WHAT),all)

restore: ## Restore backups; pick explicitly, e.g. make restore WHAT=dev (changes files)
	@if [[ -z "$(WHAT)" ]]; then \
		echo "Choose what to restore: make restore WHAT=\"gpg dev prefs\" (or WHAT=all)"; \
		echo "Preview first with: make restore-preview"; exit 1; \
	fi
	@scripts/restore.sh $(WHAT)
