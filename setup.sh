#!/bin/bash
#
# Bootstrap a fresh Mac:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/inesiscosta/dotfiles/main/setup.sh)"
#

set -euo pipefail

GITHUB_USER="${GITHUB_USER:-inesiscosta}"

log() { printf '\033[34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
die() {
  printf '\033[31merror:\033[0m %s\n' "$*" >&2
  exit 1
}
trap 'die "setup failed on line $LINENO. Fix the problem above and re-run; finished steps are skipped."' ERR

[[ "$(uname -s)" == Darwin ]] || die "this setup only supports macOS"
[[ "$(uname -m)" == arm64 ]] || printf 'warning: tested on Apple Silicon only; continuing on %s\n' "$(uname -m)" >&2

# Command Line Tools: needed by Homebrew and git. The installer is a GUI dialog.
if ! xcode-select -p >/dev/null 2>&1; then
  log "Installing the Command Line Tools"
  xcode-select --install || true
  read -r -p "Press Enter once the Command Line Tools installer has finished. "
  xcode-select -p >/dev/null 2>&1 || die "Command Line Tools are still missing"
fi

# Homebrew
if ! command -v brew >/dev/null 2>&1 && [[ ! -x /opt/homebrew/bin/brew ]]; then
  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
# The installer doesn't add brew to this shell's PATH on Apple Silicon.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
command -v brew >/dev/null 2>&1 || die "brew is not on PATH after installation"

log "Installing chezmoi and 1Password"
brew list chezmoi >/dev/null 2>&1 || brew install chezmoi
brew list --cask 1password >/dev/null 2>&1 || brew install --cask 1password
brew list --cask 1password-cli >/dev/null 2>&1 || brew install --cask 1password-cli

cat <<'EOF'

Before continuing:
  1. Open 1Password and sign in.
  2. In 1Password > Settings > Developer, turn on
     "Use the SSH agent" and "Integrate with 1Password CLI".
  3. Sign in to the App Store (needed for the Mac App Store apps).

EOF
read -r -p "Press Enter when you're done. "
op whoami >/dev/null 2>&1 || op signin >/dev/null || die "1Password CLI sign-in failed. Check step 2 above."

log "Applying dotfiles with chezmoi"
chezmoi init --apply "$GITHUB_USER"

log "Done. Restart the Mac so every system preference takes effect."
echo "Next: cd ~/.local/share/chezmoi && make doctor   (and 'make restore' if you want your backups back)"
