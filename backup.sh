#!/bin/bash
set -e
eval $(op signin) &>/dev/null
TMP_DIR=$(mktemp -d)

echo "Starting Backup."

# Save GPG Secrets
gpg -a --export >"$TMP_DIR/pubkeys.asc" &>/dev/null
gpg -a --export-secret-keys >"$TMP_DIR/privatekeys.asc" &>/dev/null
gpg --export-ownertrust >"$TMP_DIR/trust.txt" &>/dev/null

update_or_create() {
    local doc_name="$1"
    local file_path="$2"
    if op document get "$doc_name" &>/dev/null; then
        op document edit "$doc_name" "$file_path" &>/dev/null
    else
        op document create "$file_path" --title "$doc_name" &>/dev/null
    fi
}

update_or_create "GPG Private Keys" "$TMP_DIR/privatekeys.asc"
update_or_create "GPG Public Keys" "$TMP_DIR/pubkeys.asc"
update_or_create "GPG TrustDB" "$TMP_DIR/trust.txt"

# Clean up the temporary files
rm -rf "$TMP_DIR"

# Update Brewfile
BrewfilePath="$HOME/.local/share/chezmoi/Brewfile"
brew bundle dump --file="$BrewfilePath" --force

# Backup my Developer directory to iCloud.
DEV_DIR="$HOME/Developer"
ZIP_PATH="$HOME/Documents/dev_backup.zip"
cd "$DEV_DIR"
zip -r "$ZIP_PATH" . &>/dev/null

ICLOUD_DOCS="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents"
if [ -d "$ICLOUD_DOCS" ]; then
  mv "$ZIP_PATH" "$ICLOUD_DOCS/Backup/dev_backup.zip"
fi

# Backup Dock and LaunchPad Preferences
lporg save --icloud &>/dev/null

# Backup App Preferences
APP_PREFS_DIR="$ICLOUD_DOCS/Backup/AppPreferences"
mkdir -p "$APP_PREFS_DIR"

defaults export com.lwouis.alt-tab-macos "$APP_PREFS_DIR/alttab.plist"
defaults export com.if.Amphetamine "$APP_PREFS_DIR/amphetamine.plist"
defaults export pl.maketheweb.cleanshotx "$APP_PREFS_DIR/cleanshotx.plist"
defaults export com.knollsoft.Rectangle "$APP_PREFS_DIR/rectangle.plist"
defaults export com.raycast.macos "$APP_PREFS_DIR/raycast.plist"

echo "Backup Complete."

