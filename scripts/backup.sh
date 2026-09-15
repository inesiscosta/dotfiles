#!/usr/bin/env bash
#
# Back up things chezmoi can't manage: GPG keys, the Developer folder,
# app preferences and a snapshot of installed Homebrew packages.
#
# Usage: scripts/backup.sh [--dry-run] [--yes] [all | gpg | dev | prefs | brew ...]
#
#   gpg    Export GPG keys and ownertrust to 1Password documents.
#   dev    Zip ~/Developer (without node_modules/.venv/__pycache__) into the backup dir.
#   prefs  Export supported app preferences with `defaults export`.
#   brew   Save a Brewfile snapshot and show drift from the curated Brewfile.
#
# Archives are timestamped; only the newest `backupKeep` (default 3) of each
# kind are kept. The curated Brewfile in this repository is never modified.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
strict_mode

usage() { sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; }

components=()
for arg in "$@"; do
  case $arg in
  -n | --dry-run) DRY_RUN=1 ;;
  -y | --yes) ASSUME_YES=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  all) components+=(gpg dev prefs brew) ;;
  gpg | dev | prefs | brew) components+=("$arg") ;;
  *) die "unknown argument: $arg (see --help)" ;;
  esac
done
[[ ${#components[@]} -gt 0 ]] || {
  usage
  exit 1
}

umask 077 # Backups may contain secrets: owner-only permissions.
brew_env || true

BACKUP_DIR="$(backup_dir)"
KEEP="$(config_get backupKeep 3)"
STAMP="$(timestamp)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-backup.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

BACKUP_DIR_READY=0
ensure_backup_dir() {
  ((BACKUP_DIR_READY)) && return 0
  BACKUP_DIR_READY=1
  local parent
  parent="$(dirname "$BACKUP_DIR")"
  [[ -d "$parent" ]] || die "backup location $parent does not exist. Is iCloud Drive (with Desktop & Documents) enabled? Set backupDir with 'chezmoi init' or DOTFILES_BACKUP_DIR."
  run mkdir -p "$BACKUP_DIR"
}

# Delete all but the newest $KEEP entries matching a glob, oldest first.
prune() {
  local dir=$1 pattern=$2 entries=() i
  [[ -d "$dir" ]] || return 0
  # Names embed a sortable timestamp, so lexical order is chronological.
  while IFS= read -r entry; do entries+=("$entry"); done < <(find "$dir" -maxdepth 1 -name "$pattern" | sort)
  for ((i = 0; i < ${#entries[@]} - KEEP; i++)); do
    info "removing old backup ${entries[i]##*/}"
    run rm -rf "${entries[i]}" "${entries[i]}.sha256"
  done
}

# --- GPG -----------------------------------------------------------------------
# Keys are exported straight into 1Password over a pipe; they never touch disk.

op_put_document() {
  local title=$1 filename=$2 content=$3
  if op document get "$title" >/dev/null 2>&1; then
    confirm "Replace the existing 1Password document \"$title\"?" || {
      warn "kept existing \"$title\""
      return 0
    }
    is_dry_run || printf '%s\n' "$content" | op document edit "$title" - --file-name "$filename" >/dev/null
  else
    is_dry_run || printf '%s\n' "$content" | op document create - --title "$title" --file-name "$filename" >/dev/null
  fi
  ok "$title"
}

backup_gpg() {
  log "GPG keys → 1Password"
  require gpg "Install it with: brew install gnupg"
  [[ -n "$(gpg --list-secret-keys 2>/dev/null || true)" ]] || die "no GPG secret keys in this keyring; nothing to back up"
  op_ready

  if is_dry_run; then
    gpg --list-secret-keys --keyid-format long 2>/dev/null | grep -E '^(sec|uid)' | sed 's/^/    /' >&2
    local title
    for title in "GPG Public Keys" "GPG Private Keys" "GPG TrustDB"; do
      if op document get "$title" >/dev/null 2>&1; then
        info "would replace 1Password document \"$title\" (after confirmation)"
      else
        info "would create 1Password document \"$title\""
      fi
    done
    return 0
  fi

  local public secret trust
  public="$(gpg --armor --export)"
  secret="$(gpg --armor --export-secret-keys)" # prompts for the passphrase
  trust="$(gpg --export-ownertrust)"

  # Refuse to upload anything that isn't a real export. An earlier version of
  # this script redirected the exports to /dev/null and uploaded empty files.
  [[ "$public" == *"BEGIN PGP PUBLIC KEY BLOCK"* ]] || die "public key export is empty; aborting before touching 1Password"
  [[ "$secret" == *"BEGIN PGP PRIVATE KEY BLOCK"* ]] || die "secret key export is empty; aborting before touching 1Password"
  [[ -n "$trust" ]] || die "ownertrust export is empty; aborting before touching 1Password"

  op_put_document "GPG Public Keys" pubkeys.asc "$public"
  op_put_document "GPG Private Keys" privatekeys.asc "$secret"
  op_put_document "GPG TrustDB" trust.txt "$trust"
}

# --- Developer folder ----------------------------------------------------------

DEV_SOURCE="${DEV_SOURCE:-$HOME/Developer}"

backup_dev() {
  log "$DEV_SOURCE → $BACKUP_DIR/developer"
  [[ -d "$DEV_SOURCE" ]] || die "$DEV_SOURCE does not exist"
  ensure_backup_dir
  local name="developer-$STAMP.zip" dest="$BACKUP_DIR/developer"
  local archive="$WORK_DIR/$name"

  if is_dry_run; then
    info "would archive $(du -sh "$DEV_SOURCE" | cut -f1) (before exclusions) to $dest/$name"
  else
    # Build in a local temp dir, verify, then move: iCloud never sees a partial file.
    # Paths are stored relative to $DEV_SOURCE; symlinks are stored as links.
    (cd "$DEV_SOURCE" && zip -r -q -y "$archive" . \
      -x '*/node_modules/*' '*/.venv/*' '*/__pycache__/*' '*.DS_Store')
    unzip -tq "$archive" >/dev/null || die "archive verification failed; nothing was written to $dest"
    (cd "$WORK_DIR" && shasum -a 256 "$name" >"$name.sha256")
    mkdir -p "$dest"
    mv "$archive" "$archive.sha256" "$dest/"
    ok "$name ($(du -h "$dest/$name" | cut -f1)), verified"
  fi
  prune "$dest" 'developer-*.zip'
  info "iCloud uploads in the background; wait for it to finish before erasing this Mac."
}

# --- App preferences -------------------------------------------------------------

backup_prefs() {
  log "App preferences → $BACKUP_DIR/preferences/$STAMP"
  ensure_backup_dir
  local dest="$BACKUP_DIR/preferences/$STAMP" entry domain exported=0
  for entry in "${APP_PREFS[@]}"; do
    domain="${entry%%|*}"
    if ! defaults read "$domain" >/dev/null 2>&1; then
      info "skipping $domain: no preferences on this Mac"
      continue
    fi
    run mkdir -p "$dest"
    run defaults export "$domain" "$dest/$domain.plist"
    ok "$domain"
    exported=$((exported + 1))
  done
  ((exported > 0)) && prune "$BACKUP_DIR/preferences" '20*'
  return 0
}

# --- Homebrew snapshot -------------------------------------------------------------

# Normalise Brewfile lines to `type "name"`, dropping options and comments.
entries() { sed -nE 's/^(tap|brew|cask|mas|vscode) "([^"]+)".*/\1 "\2"/p' | sort -u; }

backup_brew() {
  log "Homebrew snapshot → $BACKUP_DIR/brew"
  require brew
  ensure_backup_dir
  local snapshot="$WORK_DIR/Brewfile-$STAMP"
  brew bundle dump --file=- --no-describe >"$snapshot"
  run mkdir -p "$BACKUP_DIR/brew"
  run cp "$snapshot" "$BACKUP_DIR/brew/"
  prune "$BACKUP_DIR/brew" 'Brewfile-*'

  local curated="$DOTFILES_DIR/Brewfile" extra missing
  extra="$(comm -13 <(entries <"$curated") <(entries <"$snapshot"))"
  missing="$(comm -23 <(entries <"$curated") <(entries <"$snapshot"))"
  if [[ -z "$extra$missing" ]]; then
    ok "installed packages match the Brewfile"
    return 0
  fi
  [[ -n "$extra" ]] && {
    info "installed but not in the Brewfile (add them by hand if you want to keep them):"
    printf '%s\n' "$extra" | sed 's/^/      /' >&2
  }
  [[ -n "$missing" ]] && {
    info "in the Brewfile but not installed (run 'brew bundle' to install):"
    printf '%s\n' "$missing" | sed 's/^/      /' >&2
  }
  return 0
}

for component in "${components[@]}"; do
  "backup_$component"
done
log "Backup complete"
