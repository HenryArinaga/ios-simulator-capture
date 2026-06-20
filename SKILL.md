---
name: ios-simulator-capture
description: Take screenshots and screen recordings of the iOS Simulator from the command line. macOS only.
---

# iOS Simulator Capture

Capture the screen of the running iOS Simulator — no manual interaction needed.

## Requirements

- macOS with Xcode installed
- iOS Simulator running

## Usage

Run the capture script from this skill's `scripts/` directory:

```bash
bash <skill-path>/scripts/capture.sh screenshot [--output <path>] [--device <UDID|booted>]
bash <skill-path>/scripts/capture.sh record [--output <path>] [--device <UDID|booted>] [--duration <seconds>]
```

### Examples

```bash
# Screenshot the booted simulator
bash <skill-path>/scripts/capture.sh screenshot

# Screenshot with custom output
bash <skill-path>/scripts/capture.sh screenshot --output ./my-screenshot.png

# Record 10 seconds
bash <skill-path>/scripts/capture.sh record --duration 10 --output ./demo.mp4
```

## Finding Simulator UDIDs

```bash
xcrun simctl list devices --json
```
