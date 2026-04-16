# better-mac

A lightweight macOS utility that brings two iPhone-style niceties to your Mac:

1. **Dynamic Island** — hover the top-middle of the screen and a black rounded panel drops out of the notch showing the currently playing track (artwork, title, artist, play/pause/skip, and seek bar). When audio is playing the collapsed island widens into a compact pill showing the album cover on the left and an animated waveform on the right (frozen when paused). Blends seamlessly into the physical notch on notched MacBooks; falls back to a floating pill on non-notched displays.
2. **iPhone-style volume HUD** — the native macOS volume HUD is suppressed. In its place, a tall pill appears on the right edge of the screen showing the current volume, the output device icon (built-in speakers, AirPods, Bluetooth, USB, AirPlay), and the device name.

Runs as a menu bar agent with no Dock icon.

## Build & run

Requirements:
- macOS 14 (Sonoma) or later
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you want to regenerate the project: `brew install xcodegen`

```bash
xcodegen generate   # optional — regenerates better-mac.xcodeproj from project.yml
xcodebuild -project better-mac.xcodeproj -scheme better-mac -configuration Debug build
open /Users/$USER/Library/Developer/Xcode/DerivedData/better-mac-*/Build/Products/Debug/better-mac.app
```

## Permissions

On first launch, the app will prompt for **Accessibility** permission. This is required for the volume key interceptor (it uses a `CGEventTap` to consume hardware volume key presses so the native macOS HUD never fires). Without it, the Dynamic Island still works — only the volume HUD feature is disabled.

The Spotify fallback uses AppleScript. macOS will prompt for Apple Events permission the first time Spotify info is fetched.

## Features & toggles

Click the menu bar icon to toggle:
- Dynamic Island
- Volume HUD
- Open at Login

## How it works

- **Media info** — uses the private `MediaRemote.framework` (via `dlopen` + `CFBundleGetFunctionPointerForName`) to subscribe to system-wide Now Playing updates. Falls back to AppleScript polling of Spotify when MediaRemote goes silent.
- **Notch detection** — uses `NSScreen.safeAreaInsets` plus `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` to compute the notch rect on any notched MacBook. Non-notched displays render a floating pill instead.
- **Volume key handling** — a `CGEventTap` at `.cgSessionEventTap` intercepts `NSSystemDefined` subtype-8 events (the ones the hardware volume keys produce) and returns `nil` from the callback so macOS never sees them. The interceptor then sets the volume via `AudioObjectSetPropertyData` on `kAudioDevicePropertyVolumeScalar` of the current default output device.
- **Output device classification** — uses `kAudioDevicePropertyTransportType` plus a name-contains check for "AirPods" / "Beats".

## Known limitations

- Requires Accessibility permission for the volume HUD feature.
- `MediaRemote` is a private framework — Apple could break this on a future macOS.
- On external (non-notched) displays, the island renders as a floating pill rather than trying to mimic a notch.
- Enterprise Macs with MDM-restricted Accessibility will only get the Dynamic Island feature.

## Distribution

v0.1 is built for direct distribution, unsandboxed, targeting macOS 14+. For shipping the `.app` to other Macs, sign with a Developer ID cert and notarize:

```bash
codesign --deep --options runtime --sign "Developer ID Application: <NAME>" better-mac.app
xcrun notarytool submit better-mac.zip --apple-id <email> --password <app-specific>
```

No Mac App Store support — the features rely on private frameworks and global event taps that the sandbox rejects.

## Project structure

```
better-mac/
├── better-mac/
│   ├── App/          # App lifecycle, status bar, settings
│   ├── Island/       # Dynamic Island NSPanel + SwiftUI content
│   ├── Media/        # MediaRemote bridge + Spotify fallback
│   ├── Volume/       # CGEventTap + CoreAudio + HUD pill
│   ├── Support/      # Logger, Permissions, NSScreen+Notch
│   └── Resources/    # Info.plist, Assets
├── better-macTests/  # Unit tests
└── project.yml       # XcodeGen spec
```

## Acknowledgements

Technique references (no code copied):
- [Atoll](https://github.com/Ebullioscopic/Atoll) — MediaRemote dlopen pattern, notch geometry
- [NotchDrop](https://github.com/Lakr233/NotchDrop) — notch width math
- [volumeHUD](https://github.com/dannystewart/volumeHUD) — CGEventTap for volume keys
- [volume-grid](https://github.com/euxx/volume-grid) — CoreAudio default-output listener
