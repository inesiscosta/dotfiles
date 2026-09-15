#!/usr/bin/env bash
#
# Apply my macOS system preferences.
#
# Every setting is read first and only written when it differs, so the script
# is safe to re-run and `--dry-run` shows exactly what would change.
# Settings were verified against macOS 26 Tahoe and macOS 27 on Apple Silicon;
# see docs/macos-defaults.md for what each one does and what was removed.
#
# Usage: scripts/macos-defaults.sh [--dry-run] [--yes]
#
# Machine-specific values come from chezmoi's config (or the environment):
#   COMPUTER_NAME     e.g. "Inês’s MacBook"   (empty = leave unchanged)
#   LOCAL_HOST_NAME   e.g. "Iness-MacBook"    (empty = leave unchanged)

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
strict_mode

for arg in "$@"; do
  case $arg in
  -n | --dry-run) DRY_RUN=1 ;;
  -y | --yes) ASSUME_YES=1 ;;
  -h | --help)
    sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *) die "unknown option: $arg" ;;
  esac
done

[[ "$(uname -s)" == Darwin ]] || die "this script only runs on macOS"

COMPUTER_NAME="${COMPUTER_NAME-$(config_get computerName)}"
LOCAL_HOST_NAME="${LOCAL_HOST_NAME-$(config_get localHostName)}"

CHANGES=0
RESTART=" " # space-separated list of processes to restart at the end

# pref [--sudo] [--host] <domain> <key> <type> <value...>
#
# Write a preference only when its current value differs. Supported types:
# -bool -int -float -string -array (of strings) -dict (always written).
pref() {
  local use_sudo=0 host=0
  while [[ $1 == --* ]]; do
    case $1 in
    --sudo) use_sudo=1 ;;
    --host) host=1 ;;
    esac
    shift
  done
  local domain=$1 key=$2 type=$3
  shift 3

  local -a read_cmd=(defaults) write_cmd=(defaults)
  if ((host)); then
    read_cmd+=(-currentHost)
    write_cmd+=(-currentHost)
  fi
  ((use_sudo)) && write_cmd=(sudo "${write_cmd[@]}")

  local current desired
  current="$("${read_cmd[@]}" read "$domain" "$key" 2>/dev/null || echo "<unset>")"

  case $type in
  -bool)
    case $1 in true | yes | 1) desired=1 ;; *) desired=0 ;; esac
    ;;
  -int | -string) desired=$1 ;;
  -float)
    # Compare numerically: `defaults` may print 1.5 as 1.5 or 1.50.
    if [[ "$current" != "<unset>" ]] && awk -v a="$current" -v b="$1" 'BEGIN { exit !(a + 0 == b + 0) }'; then
      return 0
    fi
    desired=$1
    ;;
  -array)
    # Flatten `( "a", "b" )` to `a,b` for comparison.
    current="$(printf '%s' "$current" | tr -d ' \n"()')"
    desired="$(
      IFS=,
      printf '%s' "$*"
    )"
    ;;
  -dict) desired="<dict>" current="<always>" ;;
  *) die "pref: unsupported type $type" ;;
  esac

  [[ "$current" == "$desired" ]] && return 0

  info "$domain $key: ${current} → $*"
  run "${write_cmd[@]}" write "$domain" "$key" "$type" "$@"
  CHANGES=$((CHANGES + 1))
  case $domain in
  com.apple.dock | com.apple.WindowManager) RESTART="${RESTART}Dock " ;;
  com.apple.finder) RESTART="${RESTART}Finder " ;;
  com.apple.controlcenter) RESTART="${RESTART}ControlCenter " ;;
  esac
}

section() { log "$1"; }

if ! is_dry_run; then
  log "Requesting administrator access for system-wide settings"
  sudo_keepalive
fi

# --- Security -------------------------------------------------------------------
section "Security"

FW=/usr/libexec/ApplicationFirewall/socketfilterfw
if "$FW" --getglobalstate | grep -q "enabled"; then
  :
else
  info "application firewall: off → on"
  run sudo "$FW" --setglobalstate on
  CHANGES=$((CHANGES + 1))
fi

# --- Computer name --------------------------------------------------------------
section "Computer name"

set_name() {
  local kind=$1 value=$2 current
  [[ -z "$value" ]] && return 0
  current="$(scutil --get "$kind" 2>/dev/null || echo "<unset>")"
  [[ "$current" == "$value" ]] && return 0
  info "$kind: $current → $value"
  run sudo scutil --set "$kind" "$value"
  CHANGES=$((CHANGES + 1))
}

if [[ -n "$LOCAL_HOST_NAME" && ! "$LOCAL_HOST_NAME" =~ ^[A-Za-z0-9-]+$ ]]; then
  die "localHostName '$LOCAL_HOST_NAME' may only contain letters, digits and hyphens"
fi
set_name ComputerName "$COMPUTER_NAME"    # Friendly name shown in Finder, AirDrop and Sharing
set_name LocalHostName "$LOCAL_HOST_NAME" # Bonjour name: <name>.local
set_name HostName "$LOCAL_HOST_NAME"      # Shell/DNS host name; must be DNS-safe, so reuse LocalHostName

# --- Power ------------------------------------------------------------------------
section "Power"

if pmset -g batt | grep -q InternalBattery; then
  pmset_ensure() {
    local flag=$1 profile=$2 want=$3 have
    have="$(pmset -g custom | awk -v p="$profile" '/Power:$/ { cur = $0 } cur ~ p && $1 == "lowpowermode" { print $2 }')"
    [[ "$have" == "$want" ]] && return 0
    info "low power mode ($profile): ${have:-<unset>} → $want"
    run sudo pmset "$flag" lowpowermode "$want"
    CHANGES=$((CHANGES + 1))
  }
  pmset_ensure -b "Battery" 1 # Low Power Mode on battery
  pmset_ensure -c "AC" 0      # Full performance when plugged in
fi

# --- Language & region ------------------------------------------------------------
# Locale changes take effect after logging out.
section "Language & region"

pref NSGlobalDomain AppleLanguages -array "en-PT" "pt-PT"
pref NSGlobalDomain AppleLocale -string "en_PT" # English, region Portugal (EUR currency)
pref NSGlobalDomain AppleMeasurementUnits -string "Centimeters"
pref NSGlobalDomain AppleMetricUnits -bool true
pref NSGlobalDomain AppleICUForce24HourTime -bool true
pref NSGlobalDomain AppleFirstWeekday -dict gregorian 2            # Monday
pref NSGlobalDomain AppleICUDateFormatStrings -dict 1 "dd-MM-yyyy" # Short date format
# Number format "1 234 567.89": "." decimal separator, narrow no-break space grouping.
# Keys: 0/1 = number decimal/grouping, 10/17 = currency decimal/grouping.
NNBSP=$'\xe2\x80\xaf'
pref NSGlobalDomain AppleICUNumberSymbols -dict 0 "." 1 "$NNBSP" 10 "." 17 "$NNBSP"

# --- Menu bar ---------------------------------------------------------------------
# On macOS 26+, menu bar items are managed in System Settings > Menu Bar.
# Only the battery percentage has a stable, verified preference key.
section "Menu bar"

pref --host com.apple.controlcenter BatteryShowPercentage -bool true

# --- Dock ------------------------------------------------------------------------
# Dock apps and their order are handled by scripts/dock.sh.
section "Dock"

pref com.apple.dock tilesize -int 45
pref com.apple.dock magnification -bool true
pref com.apple.dock largesize -int 57
pref com.apple.dock orientation -string "right"
pref com.apple.dock mineffect -string "genie"
pref com.apple.dock minimize-to-application -bool true
pref com.apple.dock autohide -bool true
pref com.apple.dock launchanim -bool true
pref com.apple.dock show-process-indicators -bool true
pref com.apple.dock show-recents -bool false
pref com.apple.WindowManager GloballyEnabled -bool false # Stage Manager off

# --- Trackpad --------------------------------------------------------------------
# Built-in trackpads read com.apple.AppleMultitouchTrackpad; Magic Trackpads read
# com.apple.driver.AppleBluetoothMultitouch.trackpad. Changes apply after logout.
section "Trackpad"

for domain in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
  pref "$domain" Clicking -bool true           # Tap to click
  pref "$domain" TrackpadRightClick -bool true # Two-finger secondary click
done
pref NSGlobalDomain com.apple.mouse.tapBehavior -int 1        # Tap to click for this user
pref --host NSGlobalDomain com.apple.mouse.tapBehavior -int 1 # …and at the login window
pref NSGlobalDomain com.apple.trackpad.forceClick -bool true  # Force Click and haptic feedback
pref com.apple.AppleMultitouchTrackpad ActuateDetents -int 1  # Haptic feedback
pref com.apple.AppleMultitouchTrackpad ForceSuppressed -bool false
pref NSGlobalDomain com.apple.trackpad.scaling -float 0.6875 # Tracking speed

# --- Software updates --------------------------------------------------------------
section "Software updates"

SU=/Library/Preferences/com.apple.SoftwareUpdate
pref --sudo "$SU" AutomaticCheckEnabled -bool true
pref --sudo "$SU" AutomaticDownload -bool true
pref --sudo "$SU" AutomaticallyInstallMacOSUpdates -bool true
pref --sudo "$SU" CriticalUpdateInstall -bool true                        # Security responses and system files
pref --sudo "$SU" ConfigDataInstall -bool true                            # XProtect and other system data files
pref --sudo /Library/Preferences/com.apple.commerce AutoUpdate -bool true # App Store app updates

# --- Finder ------------------------------------------------------------------------
section "Finder"

pref com.apple.finder AppleShowAllFiles -bool false # Hidden files stay hidden (toggle with ⌘⇧.)
pref NSGlobalDomain AppleShowAllExtensions -bool true
pref com.apple.finder ShowPathbar -bool true
pref com.apple.finder FXDefaultSearchScope -string "SCcf" # Search the current folder
pref com.apple.finder FXEnableExtensionChangeWarning -bool false

# --- Apply -------------------------------------------------------------------------
log "Done"
if ((CHANGES == 0)); then
  ok "everything already up to date"
  exit 0
fi

for process in Dock Finder ControlCenter; do
  case $RESTART in *" $process "*) run killall "$process" 2>/dev/null || true ;; esac
done

if is_dry_run; then
  ok "$CHANGES setting(s) would change"
else
  ok "$CHANGES setting(s) changed. Log out and back in for locale and trackpad changes to apply."
fi
