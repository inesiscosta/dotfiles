#!/usr/bin/env bash
#
# Check the health of this Mac's dotfiles setup. Read-only: it never changes
# anything, so it's safe to run at any time.
#
# Usage: scripts/doctor.sh
#
# Exits non-zero if any check fails. Warnings don't affect the exit status.

# pass/fail/caution always succeed, so `test && pass || caution` is a safe if/else.
# shellcheck disable=SC2015

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
set -uo pipefail # no -e: keep going after failed checks

case "${1:-}" in
-h | --help)
  sed -n '3,8p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
  ;;
esac

failures=0 warnings=0
pass() { printf '  %s✓%s %s\n' "$_c_green" "$_c_reset" "$*"; }
fail() {
  printf '  %s✗%s %s\n' "$_c_red" "$_c_reset" "$*"
  failures=$((failures + 1))
}
caution() {
  printf '  %s!%s %s\n' "$_c_yellow" "$_c_reset" "$*"
  warnings=$((warnings + 1))
}
hint() { printf '      %s\n' "$*"; }
heading() { printf '\n%s%s%s\n' "$_c_bold" "$*" "$_c_reset"; }

brew_env >/dev/null 2>&1 || true
export HOMEBREW_NO_AUTO_UPDATE=1 # keep `brew bundle check` read-only and fast

heading "System"
version="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
arch="$(uname -m)"
if [[ "${version%%.*}" =~ ^[0-9]+$ && "${version%%.*}" -ge 26 ]]; then
  pass "macOS $version"
else
  caution "macOS $version: these dotfiles are tested on macOS 26 and later"
fi
[[ "$arch" == arm64 ]] && pass "Apple Silicon ($arch)" || caution "$arch: these dotfiles assume Apple Silicon (/opt/homebrew)"
if xcode-select -p >/dev/null 2>&1; then
  pass "Command Line Tools ($(xcode-select -p))"
else
  fail "Command Line Tools missing"
  hint "xcode-select --install"
fi

heading "Homebrew"
if has brew; then
  pass "brew $(brew --version | head -n 1 | awk '{print $2}') at $(brew --prefix)"
  if brew bundle check --file="$DOTFILES_DIR/Brewfile" >/dev/null 2>&1; then
    pass "everything in the Brewfile is installed"
  else
    caution "some Brewfile entries are missing"
    hint "brew bundle check --file=$DOTFILES_DIR/Brewfile --verbose"
  fi
else
  fail "Homebrew not installed"
  hint "run setup.sh, or see https://brew.sh"
fi

heading "chezmoi"
if has chezmoi; then
  pass "chezmoi $(chezmoi --version | awk '{print $3}' | tr -d ,)"
  source_path="$(chezmoi source-path 2>/dev/null || true)"
  if [[ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml" ]]; then
    fail "chezmoi has not been initialised on this Mac"
    hint "chezmoi init inesiscosta   (or: chezmoi init --source=$DOTFILES_DIR)"
  elif [[ ! -d "$source_path" ]]; then
    fail "chezmoi source directory $source_path is missing"
  else
    pass "config generated, source: $source_path"
    pending="$(chezmoi status --exclude=scripts 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$pending" == 0 ]]; then
      pass "all managed files match the repository"
    else
      caution "$pending managed file(s) differ from the repository"
      hint "chezmoi diff   (then 'chezmoi apply' or 'chezmoi re-add')"
    fi
  fi
else
  fail "chezmoi not installed"
  hint "brew install chezmoi"
fi

heading "1Password"
[[ -d /Applications/1Password.app ]] && pass "1Password app" || fail "1Password app missing"
if has op; then
  pass "op $(op --version)"
else
  fail "1Password CLI (op) missing"
  hint "brew install --cask 1password-cli"
fi
agent="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [[ -S "$agent" ]]; then
  pass "SSH agent socket"
  if SSH_AUTH_SOCK="$agent" ssh-add -l >/dev/null 2>&1; then
    pass "SSH agent has keys"
  else
    caution "SSH agent has no keys"
    hint "1Password > Settings > Developer > Use the SSH agent"
  fi
else
  caution "1Password SSH agent not running"
  hint "1Password > Settings > Developer > Use the SSH agent"
fi

heading "Git signing"
if has git; then
  format="$(git config --global gpg.format 2>/dev/null || echo openpgp)"
  key="$(git config --global user.signingkey 2>/dev/null || true)"
  [[ "$(git config --global commit.gpgSign 2>/dev/null)" == true ]] && pass "commit signing enabled ($format)" || caution "commit signing disabled"
  if [[ -z "$key" ]]; then
    fail "user.signingkey not set"
  elif [[ "$format" == ssh ]]; then
    program="$(git config --global gpg.ssh.program 2>/dev/null || true)"
    [[ -x "$program" ]] && pass "op-ssh-sign available" || fail "gpg.ssh.program '$program' not executable"
  elif has gpg && gpg --list-secret-keys "$key" >/dev/null 2>&1; then
    pass "GPG secret key $key present"
  else
    fail "GPG secret key $key not in keyring"
    hint "scripts/restore.sh gpg"
  fi
  pinentry="$(awk '$1 == "pinentry-program" { print $2 }' "$HOME/.gnupg/gpg-agent.conf" 2>/dev/null)"
  if [[ "$format" != ssh && -n "$pinentry" && ! -x "$pinentry" ]]; then
    fail "pinentry-program $pinentry not found"
  fi
fi

heading "Shell tools"
for tool in zsh nvim fzf zoxide bat fnm pyenv dockutil; do
  has "$tool" && pass "$tool" || caution "$tool not installed"
done
prefix="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
[[ -r "$prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && pass "zsh-autosuggestions" || caution "zsh-autosuggestions not installed"
[[ "$SHELL" == */zsh ]] && pass "login shell is zsh" || caution "login shell is $SHELL"

heading "Backups"
dir="$(backup_dir)"
if [[ -d "$dir" ]]; then
  pass "backup dir: $dir"
  latest="$(find "$dir/developer" -maxdepth 1 -name 'developer-2*.zip' 2>/dev/null | sort | tail -n 1)"
  if [[ -n "$latest" ]]; then
    age_days=$((($(date +%s) - $(stat -f %m "$latest")) / 86400))
    ((age_days <= 30)) && pass "latest Developer backup: ${latest##*/} ($age_days days old)" ||
      caution "latest Developer backup is $age_days days old"
  else
    caution "no Developer backups yet"
    hint "make backup"
  fi
else
  caution "backup dir $dir does not exist yet"
  [[ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]] || hint "iCloud Drive does not seem to be enabled"
fi

heading "Summary"
if ((failures > 0)); then
  printf '  %s%d problem(s)%s, %d warning(s)\n' "$_c_red" "$failures" "$_c_reset" "$warnings"
  exit 1
fi
printf '  %sno problems%s, %d warning(s)\n' "$_c_green" "$_c_reset" "$warnings"
