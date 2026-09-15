# shellcheck shell=bash
#
# Shared helpers for the scripts in this repository. Source it, don't run it:
#
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#
# Everything here must work with /bin/bash 3.2, because that is the only Bash
# available on a fresh Mac before Homebrew is installed.
#
# Environment variables understood by every script:
#   DRY_RUN=1      print mutating commands instead of running them
#   ASSUME_YES=1   answer "yes" to confirmation prompts (non-interactive use)
#   NO_COLOR=1     disable coloured output

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"

if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
  _c_reset=$'\033[0m' _c_bold=$'\033[1m' _c_blue=$'\033[34m'
  _c_green=$'\033[32m' _c_yellow=$'\033[33m' _c_red=$'\033[31m'
else
  _c_reset='' _c_bold='' _c_blue='' _c_green='' _c_yellow='' _c_red=''
fi

# --- Logging ------------------------------------------------------------------
# All output goes to stderr so that stdout stays usable for data.

log() { printf '%s==>%s %s%s%s\n' "$_c_blue" "$_c_reset" "$_c_bold" "$*" "$_c_reset" >&2; }
info() { printf '    %s\n' "$*" >&2; }
ok() { printf '    %s✓%s %s\n' "$_c_green" "$_c_reset" "$*" >&2; }
warn() { printf '%swarning:%s %s\n' "$_c_yellow" "$_c_reset" "$*" >&2; }
die() {
  printf '%serror:%s %s\n' "$_c_red" "$_c_reset" "$*" >&2
  exit 1
}

# Print the failing command and line when a script exits through `set -e`.
on_error() {
  local status=$? line=${1:-?}
  printf '%serror:%s %s:%s: command exited with status %s\n' \
    "$_c_red" "$_c_reset" "${BASH_SOURCE[1]:-$0}" "$line" "$status" >&2
}

# Enable strict mode and the error trap. Call once at the top of each script.
strict_mode() {
  set -Eeuo pipefail
  trap 'on_error $LINENO' ERR
}

# --- Execution helpers --------------------------------------------------------

is_dry_run() { [[ "$DRY_RUN" == 1 ]]; }

# Run a command that changes the system, or just print it in dry-run mode.
run() {
  if is_dry_run; then
    printf '    %s[dry-run]%s' "$_c_yellow" "$_c_reset" >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
  else
    "$@"
  fi
}

# Ask a yes/no question. Defaults to "no" and refuses without a terminal,
# so nothing destructive ever happens unattended unless ASSUME_YES=1.
confirm() {
  [[ "$ASSUME_YES" == 1 ]] && return 0
  if [[ ! -t 0 ]]; then
    warn "no terminal to confirm \"$1\"; re-run interactively or set ASSUME_YES=1"
    return 1
  fi
  local reply
  read -r -p "    $1 [y/N] " reply
  [[ "$reply" == [yY] || "$reply" == [yY][eE][sS] ]]
}

has() { command -v "$1" >/dev/null 2>&1; }

require() {
  has "$1" || die "'$1' is required but not installed.${2:+ $2}"
}

# Make `brew` available in this shell, even right after a fresh install when
# /opt/homebrew/bin is not on PATH yet.
brew_env() {
  has brew && return 0
  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      eval "$("$candidate" shellenv)"
      return 0
    fi
  done
  return 1
}

# Ask for the sudo password once and keep the timestamp fresh until the
# calling script exits. Skipped in dry-run mode.
sudo_keepalive() {
  is_dry_run && return 0
  sudo -v || die "sudo is required for this step"
  local parent=$$
  (while kill -0 "$parent" 2>/dev/null; do
    sudo -n true 2>/dev/null
    sleep 50
  done) &
}

# Note: inside $(…), write `cmd || fallback` *within* the substitution. With
# `set -E` the ERR trap fires in the subshell before an outer `||` can help.

# Ensure 1Password CLI is installed and signed in. With the desktop app's
# "Integrate with 1Password CLI" setting enabled this triggers Touch ID.
op_ready() {
  require op "Install it with: brew install --cask 1password-cli"
  if ! op whoami >/dev/null 2>&1; then
    # `op signin` prints an export statement only for manual (non-app) accounts.
    local session
    session="$(op signin || echo "op-signin-failed")"
    [[ "$session" == *op-signin-failed* ]] && die "1Password sign-in failed. Open 1Password and enable Settings > Developer > Integrate with 1Password CLI."
    [[ -n "$session" ]] && eval "$session"
  fi
}

# --- Configuration ------------------------------------------------------------
# Machine-specific values live in chezmoi's config (~/.config/chezmoi/chezmoi.toml),
# generated from home/.chezmoi.toml.tmpl by `chezmoi init`. Environment
# variables take precedence so scripts stay usable without chezmoi.

config_get() {
  local key=$1 fallback=${2:-} value=""
  if has chezmoi; then
    value="$(chezmoi execute-template "{{ get . \"$key\" }}" 2>/dev/null || true)"
  fi
  printf '%s' "${value:-$fallback}"
}

expand_tilde() {
  # shellcheck disable=SC2088 # matching a literal tilde on purpose
  case $1 in
  "~") printf '%s' "$HOME" ;;
  "~/"*) printf '%s/%s' "$HOME" "${1#"~/"}" ;;
  *) printf '%s' "$1" ;;
  esac
}

backup_dir() {
  # The tilde is literal on purpose: config values use ~ and expand_tilde resolves it.
  # shellcheck disable=SC2088
  local dir="${DOTFILES_BACKUP_DIR:-$(config_get backupDir "~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Backup")}"
  expand_tilde "$dir"
}

timestamp() { date +%Y%m%d-%H%M%S; }

# Apps whose preferences are backed up with `defaults export` and restored with
# `defaults import`: "<preferences domain>|<app bundle path>".
# See docs/backup-and-restore.md for why each one is (or isn't) a good fit.
# shellcheck disable=SC2034 # used by backup.sh and restore.sh
APP_PREFS=(
  "com.lwouis.alt-tab-macos|/Applications/AltTab.app"
  "pl.maketheweb.cleanshotx|/Applications/CleanShot X.app"
  "com.knollsoft.Rectangle|/Applications/Rectangle.app"
  "com.raycast.macos|/Applications/Raycast.app"
)

# Make a file stored in iCloud Drive available locally. With "Optimize Mac
# Storage" on, iCloud may have evicted it, leaving a placeholder ("dataless").
icloud_materialize() {
  local file=$1 waited=0
  [[ "$(stat -f %Sf "$file" 2>/dev/null || true)" == *dataless* ]] || return 0
  info "downloading ${file##*/} from iCloud…"
  is_dry_run && return 0
  brctl download "$file" >/dev/null 2>&1 || true
  while [[ "$(stat -f %Sf "$file" 2>/dev/null || true)" == *dataless* ]]; do
    ((waited >= 1800)) && die "timed out waiting for iCloud to download $file"
    sleep 5
    waited=$((waited + 5))
  done
}
