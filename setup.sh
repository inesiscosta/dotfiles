#!/bin/bash

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi
brew install --cask 1password 1password-cli

echo "Sign in to 1Password desktop and the App Store before proceeding."
read -p "Press Enter to continue."

chezmoi init --apply inesiscosta

