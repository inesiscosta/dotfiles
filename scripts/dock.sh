#!/usr/bin/env bash
#
# Set the Dock's pinned apps and their order with dockutil.
#
# The Dock is only rebuilt when the current pinned apps differ from DOCK_APPS,
# so re-running is a no-op. Apps that aren't installed are skipped with a
# warning. Folders/stacks on the right side of the Dock are left alone.
#
# Usage: scripts/dock.sh [--dry-run] [--yes] [--print]
#
#   --print  Show the current Dock as a DOCK_APPS list, to paste below.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
strict_mode

# Pinned apps, top to bottom (the Dock is on the right). Use "spacer" for a gap.
# Tip: print the current Dock in this format with `scripts/dock.sh --print`.
DOCK_APPS=(
  "/System/Applications/Apps.app"
  "/System/Applications/FaceTime.app"
  "/System/Applications/Messages.app"
  "/Applications/Spark Desktop.app"
  "/Applications/WhatsApp.app"
  "/System/Applications/Notes.app"
  "/System/Applications/Photos.app"
  "/Applications/Google Chrome.app"
  "/Applications/Spotify.app"
  "/Applications/Alacritty.app"
  "/System/Applications/System Settings.app"
  "/Applications/Visual Studio Code.app"
)

PRINT=0
for arg in "$@"; do
  case $arg in
  -n | --dry-run) DRY_RUN=1 ;;
  -y | --yes) ASSUME_YES=1 ;;
  -p | --print) PRINT=1 ;;
  -h | --help)
    sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *) die "unknown option: $arg" ;;
  esac
done

# Desired list, keeping only apps that exist on this Mac.
desired=()
for app in "${DOCK_APPS[@]}"; do
  if [[ "$app" == spacer || -d "$app" ]]; then
    desired+=("$app")
  else
    warn "skipping ${app##*/}: not installed"
  fi
done

# Current pinned apps (and spacers), read from the Dock's plist with the
# built-in PlistBuddy. URLs are percent-decoded into plain paths.
DOCK_PLIST="$HOME/Library/Preferences/com.apple.dock.plist"
current_dock() {
  local i=0 type url
  while :; do
    type="$(/usr/libexec/PlistBuddy -c "Print :persistent-apps:$i:tile-type" "$DOCK_PLIST" 2>/dev/null || true)"
    [[ -z "$type" ]] && break
    case $type in
    *spacer*) echo spacer ;;
    *)
      url="$(/usr/libexec/PlistBuddy -c "Print :persistent-apps:$i:tile-data:file-data:_CFURLString" "$DOCK_PLIST" 2>/dev/null || true)"
      url="${url#file://}"
      url="${url%/}"
      printf '%b\n' "${url//%/\\x}"
      ;;
    esac
    i=$((i + 1))
  done
}
current="$(current_dock)"

if ((PRINT)); then
  printf 'DOCK_APPS=(\n'
  printf '%s\n' "$current" | sed 's/.*/  "&"/'
  printf ')\n'
  exit 0
fi

brew_env || true
require dockutil "Install it with: brew install dockutil"
wanted="$(printf '%s\n' "${desired[@]}")"

if [[ "$current" == "$wanted" ]]; then
  ok "Dock already matches"
  exit 0
fi

log "Updating Dock apps"
diff <(printf '%s\n' "$current") <(printf '%s\n' "$wanted") | sed 's/^/    /' >&2 || true

# Remove only pinned apps and spacers, one by one, so stacks are untouched.
while IFS= read -r app; do
  [[ -n "$app" && "$app" != spacer ]] && run dockutil --remove "$app" --no-restart
done <<<"$current"
if [[ "$current" == *spacer* ]]; then
  run dockutil --remove spacer-tiles --no-restart
fi
for app in "${desired[@]}"; do
  if [[ "$app" == spacer ]]; then
    run dockutil --add '' --type spacer --section apps --no-restart
  else
    run dockutil --add "$app" --no-restart
  fi
done
run killall Dock
is_dry_run || ok "Dock updated"
