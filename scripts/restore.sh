#!/usr/bin/env bash
#
# Restore backups made by scripts/backup.sh. Nothing is restored unless you
# ask for it, and every step previews what it will change first.
#
# Usage: scripts/restore.sh [--dry-run] [--yes] [--from STAMP] [all | gpg | dev | prefs ...]
#
#   gpg    Import GPG keys and ownertrust from 1Password. Additive: existing
#          keys are kept, and the 1Password documents are never deleted.
#   dev    Unpack the newest (or --from) Developer archive into ~/Developer.
#          Existing files are kept unless you confirm overwriting them.
#   prefs  Import app preferences for installed apps that aren't running.
#          Current preferences are saved first so the import can be undone.
#
# --from STAMP picks a specific backup, e.g. --from 20261115-171500.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
strict_mode

usage() { sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'; }

components=()
FROM=""
while [[ $# -gt 0 ]]; do
  case $1 in
  -n | --dry-run) DRY_RUN=1 ;;
  -y | --yes) ASSUME_YES=1 ;;
  --from)
    FROM="${2:?--from needs a timestamp}"
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  all) components+=(gpg prefs dev) ;;
  gpg | dev | prefs) components+=("$1") ;;
  *) die "unknown argument: $1 (see --help)" ;;
  esac
  shift
done
[[ ${#components[@]} -gt 0 ]] || {
  usage
  exit 1
}

brew_env || true
BACKUP_DIR="$(backup_dir)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"

# Pick the newest entry matching a glob, or the one for --from.
pick() {
  local dir=$1 prefix=$2 suffix=$3
  [[ -d "$dir" ]] || return 0
  if [[ -n "$FROM" ]]; then
    [[ -e "$dir/$prefix$FROM$suffix" ]] || die "no backup $prefix$FROM$suffix in $dir"
    printf '%s' "$dir/$prefix$FROM$suffix"
  else
    find "$dir" -maxdepth 1 -name "$prefix"'2*'"$suffix" 2>/dev/null | sort | tail -n 1
  fi
}

# --- GPG -----------------------------------------------------------------------

op_get_document() {
  local title=$1 marker=$2 content
  content="$(op document get "$title" 2>/dev/null || true)"
  if [[ -n "$marker" && "$content" != *"$marker"* ]] || [[ -z "$content" ]]; then
    die "1Password document \"$title\" is missing, empty or not a GPG export. Older versions of backup.sh uploaded empty files; check the item's history in 1Password."
  fi
  printf '%s\n' "$content"
}

restore_gpg() {
  log "GPG keys ← 1Password"
  require gpg "Install it with: brew install gnupg"
  if [[ -n "$(gpg --list-secret-keys 2>/dev/null || true)" ]]; then
    ok "secret keys already present; skipping"
    return 0
  fi
  op_ready

  local public secret trust
  public="$(op_get_document "GPG Public Keys" "BEGIN PGP PUBLIC KEY BLOCK")"
  secret="$(op_get_document "GPG Private Keys" "BEGIN PGP PRIVATE KEY BLOCK")"
  trust="$(op_get_document "GPG TrustDB" "")"

  if is_dry_run; then
    printf '%s\n' "$public" | gpg --show-keys 2>/dev/null | grep -E '^(pub|uid)' | sed 's/^/    /' >&2
    info "would import the keys above and their ownertrust"
    return 0
  fi

  # Pipes only: the keys never touch disk outside ~/.gnupg.
  printf '%s\n' "$public" | gpg --batch --import
  printf '%s\n' "$secret" | gpg --import
  printf '%s\n' "$trust" | gpg --import-ownertrust
  ok "imported. The 1Password documents were left in place."
}

# --- Developer folder ----------------------------------------------------------

DEV_TARGET="${DEV_TARGET:-$HOME/Developer}"

restore_dev() {
  log "Developer folder ← backup"
  local archive
  archive="$(pick "$BACKUP_DIR/developer" developer- .zip)"
  [[ -n "$archive" ]] || die "no Developer backups in $BACKUP_DIR/developer"
  info "archive: ${archive##*/}"

  icloud_materialize "$archive"
  [[ -f "$archive.sha256" ]] && icloud_materialize "$archive.sha256"
  if is_dry_run && [[ "$(stat -f %Sf "$archive" 2>/dev/null || true)" == *dataless* ]]; then
    info "archive is still in iCloud only; can't preview its contents in dry-run mode"
    return 0
  fi

  if [[ -f "$archive.sha256" ]]; then
    (cd "$(dirname "$archive")" && shasum -a 256 -c "${archive##*/}.sha256" >/dev/null) ||
      die "checksum mismatch: ${archive##*/} is corrupt or incomplete (iCloud may still be syncing)"
    ok "checksum verified"
  else
    warn "no checksum file; testing the archive instead"
  fi
  unzip -tq "$archive" >/dev/null || die "${archive##*/} failed the integrity test"

  # Preview: which files in the archive already exist locally?
  local total conflicts
  total="$(unzip -Z1 "$archive" | grep -vc '/$' || true)"
  conflicts="$(unzip -Z1 "$archive" | grep -v '/$' | while IFS= read -r f; do
    [[ -e "$DEV_TARGET/$f" ]] && printf '%s\n' "$f"
  done || true)"
  local nconflicts=0
  [[ -n "$conflicts" ]] && nconflicts="$(printf '%s\n' "$conflicts" | wc -l | tr -d ' ')"
  info "$total files in archive, $nconflicts already exist in $DEV_TARGET"
  if ((nconflicts > 0)); then
    printf '%s\n' "$conflicts" | head -n 10 | sed 's/^/      /' >&2
    ((nconflicts > 10)) && info "  … and $((nconflicts - 10)) more"
  fi

  local mode=-n # never overwrite
  if ((nconflicts > 0)) && ! is_dry_run; then
    if confirm "Overwrite those $nconflicts existing files with the backup copies?"; then
      mode=-o
    else
      info "keeping existing files; only missing files will be restored"
    fi
  fi
  run mkdir -p "$DEV_TARGET"
  run unzip -q "$mode" "$archive" -d "$DEV_TARGET"
  is_dry_run || ok "restored into $DEV_TARGET"
}

# --- App preferences -------------------------------------------------------------

restore_prefs() {
  log "App preferences ← backup"
  local source_dir
  source_dir="$(pick "$BACKUP_DIR/preferences" "" "")"
  [[ -n "$source_dir" && -d "$source_dir" ]] || die "no preference backups in $BACKUP_DIR/preferences"
  info "snapshot: ${source_dir##*/}"

  local undo_dir entry domain app plist
  undo_dir="$STATE_DIR/pre-restore/$(timestamp)"
  for entry in "${APP_PREFS[@]}"; do
    domain="${entry%%|*}" app="${entry#*|}" plist="$source_dir/$domain.plist"
    [[ -f "$plist" ]] || continue
    icloud_materialize "$plist"
    if [[ ! -d "$app" ]]; then
      info "skipping $domain: ${app##*/} is not installed"
      continue
    fi
    if pgrep -f "$app/Contents/MacOS/" >/dev/null 2>&1; then
      warn "skipping $domain: quit ${app##*/} first (it would overwrite the imported settings)"
      continue
    fi
    if defaults read "$domain" >/dev/null 2>&1; then
      confirm "Replace the current ${app##*/} preferences with the backup?" || continue
      run mkdir -p "$undo_dir"
      run defaults export "$domain" "$undo_dir/$domain.plist"
    fi
    run defaults import "$domain" "$plist"
    ok "$domain"
  done
  [[ -d "$undo_dir" ]] && info "previous preferences saved to $undo_dir (restore with: defaults import <domain> <file>)"
  return 0
}

for component in "${components[@]}"; do
  "restore_$component"
done
log "Restore complete"
