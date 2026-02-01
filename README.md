# TimeDial

A lightweight macOS menu bar app for comparing timezones with interactive analog clocks.

## Requirements
- macOS 13+
- Xcode 15+ (for building)

## Build & Run (local)
1) Open `timedial.xcodeproj` in Xcode
2) Select the `timedial` scheme
3) Product → Run

The app appears as a clock icon in the menu bar.

## Release ZIP (no paid developer account)
Use the helper script to build a Release and package it into a `.zip`:

```
./package_zip.sh
```

The archive will be created in `dist/` and can be attached to a GitHub Release.

### Gatekeeper note
Unsigned apps will show a warning on first open. Users can right-click → Open, or allow it in
System Settings → Privacy & Security.

