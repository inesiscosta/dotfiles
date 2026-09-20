# macOS defaults

[`scripts/macos-defaults.sh`](../scripts/macos-defaults.sh) applies the settings below. It reads each value first and only writes the ones that differ, so it's safe to re-run, and the preview shows exactly what would change:

```sh
make macos-preview   # dry run
make macos           # apply (asks for your password for system-wide settings)
```

chezmoi runs it automatically whenever the script or the computer name changes.

**Compatibility.** Every key was checked by reading it on macOS 27 (Apple Silicon) and is chosen for macOS 26 Tahoe and later. "Default" means the value already matches stock macOS; it's set explicitly so the intent is recorded. Settings marked *logout* take effect after logging out and back in.

## Security

| Setting | How | Value |
| --- | --- | --- |
| Application firewall | `socketfilterfw --setglobalstate` | on |

## Computer name

From the `computerName` and `localHostName` config values; left alone if empty.

| Setting | How |
| --- | --- |
| Name in Finder, AirDrop and Sharing | `scutil --set ComputerName` |
| Bonjour name (`<name>.local`) | `scutil --set LocalHostName` |
| Shell and DNS host name | `scutil --set HostName`, set to the LocalHostName because it must be DNS-safe |

## Power

Only on Macs with a battery.

| Setting | How | Value |
| --- | --- | --- |
| Low Power Mode on battery | `pmset -b lowpowermode` | on |
| Low Power Mode on power adapter | `pmset -c lowpowermode` | off |

## Language and region (*logout*)

All in `NSGlobalDomain`.

| Key | Value | Meaning |
| --- | --- | --- |
| `AppleLanguages` | `en-PT`, `pt-PT` | English first, then Portuguese |
| `AppleLocale` | `en_PT` | English in the Portugal region (euro, Portuguese conventions) |
| `AppleMeasurementUnits` / `AppleMetricUnits` | `Centimeters` / true | Metric |
| `AppleICUForce24HourTime` | true | 24-hour clock |
| `AppleFirstWeekday` | `gregorian = 2` | Week starts on Monday |
| `AppleICUDateFormatStrings` | `1 = dd-MM-yyyy` | Short date format |
| `AppleICUNumberSymbols` | `0 = "."`, `1 = " "`, `10 = "."`, `17 = " "` | `1 234 567.89`: dot decimal separator, narrow no-break space grouping (keys 10 and 17 are the currency equivalents) |

## Menu bar

| Key | Value |
| --- | --- |
| `-currentHost com.apple.controlcenter BatteryShowPercentage` | true |

Everything else in the menu bar and Control Center is a [manual step](installation.md#manual-steps).

## Dock

All in `com.apple.dock` unless noted. The Dock's apps and their order are set separately by [`scripts/dock.sh`](../scripts/dock.sh) (`make dock-preview`).

| Key | Value | Notes |
| --- | --- | --- |
| `tilesize` | 45 | Icon size |
| `magnification` / `largesize` | true / 57 | Magnify on hover |
| `orientation` | `right` | |
| `mineffect` | `genie` | Default |
| `minimize-to-application` | true | Minimise windows into their app icon |
| `autohide` | true | |
| `launchanim` | true | Default |
| `show-process-indicators` | true | Default |
| `show-recents` | false | No "recent apps" section |
| `com.apple.WindowManager GloballyEnabled` | false | Stage Manager off (default) |

## Trackpad (*logout*)

Built-in trackpads read `com.apple.AppleMultitouchTrackpad`; Magic Trackpads read `com.apple.driver.AppleBluetoothMultitouch.trackpad`. Both are set.

| Key | Value | Meaning |
| --- | --- | --- |
| `Clicking` (both domains) | true | Tap to click |
| `TrackpadRightClick` (both domains) | true | Two-finger secondary click |
| `NSGlobalDomain com.apple.mouse.tapBehavior` (also `-currentHost`) | 1 | Tap to click for this user and at the login window |
| `NSGlobalDomain com.apple.trackpad.forceClick` | true | Force Click |
| `ActuateDetents` / `ForceSuppressed` | 1 / false | Haptic feedback on |
| `NSGlobalDomain com.apple.trackpad.scaling` | 0.6875 | Tracking speed |

## Software updates

System-wide (`sudo`). The keys in `/Library/Preferences/com.apple.SoftwareUpdate` match the switches in System Settings → General → Software Update → Automatic Updates.

| Key | Value |
| --- | --- |
| `AutomaticCheckEnabled` | true |
| `AutomaticDownload` | true |
| `AutomaticallyInstallMacOSUpdates` | true |
| `CriticalUpdateInstall` | true (security responses and system files) |
| `ConfigDataInstall` | true (XProtect and other data files) |
| `/Library/Preferences/com.apple.commerce AutoUpdate` | true (App Store app updates) |

## Finder

| Key | Value | Meaning |
| --- | --- | --- |
| `com.apple.finder AppleShowAllFiles` | false | Hidden files stay hidden; toggle with ⌘⇧. (default) |
| `NSGlobalDomain AppleShowAllExtensions` | true | Always show file extensions |
| `com.apple.finder ShowPathbar` | true | Path bar at the bottom of windows |
| `com.apple.finder FXDefaultSearchScope` | `SCcf` | Search the current folder |
| `com.apple.finder FXEnableExtensionChangeWarning` | false | No warning when changing an extension |
