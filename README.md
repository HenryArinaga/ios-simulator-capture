# iOS Simulator Capture

Take screenshots and screen recordings of the iOS Simulator from the terminal. No manual interaction needed — captures the full simulator screen in one shot.

## Requirements

- macOS with Xcode installed
- iOS Simulator running (`xcrun simctl boot <UDID>`)

## Install

### With npx (recommended)
```bash
npx skills add https://github.com/YOURNAME/ios-simulator-capture --skill "ios-simulator-capture"
```

### Manual
```bash
git clone https://github.com/YOURNAME/ios-simulator-capture.git ~/.hermes/skills/ios-simulator-capture
```

## Usage

### Screenshot
```bash
# Default: screenshot the booted simulator, save to CWD
bash ~/.hermes/skills/ios-simulator-capture/scripts/capture.sh screenshot

# Custom output path
bash ~/.hermes/skills/ios-simulator-capture/scripts/capture.sh screenshot --output ./my-screenshot.png

# Specific device
bash ~/.hermes/skills/ios-simulator-capture/scripts/capture.sh screenshot --device <UDID>
```

### Screen Recording
```bash
# Default: record 30 seconds
bash ~/.hermes/skills/ios-simulator-capture/scripts/capture.sh record

# Custom duration
bash ~/.hermes/skills/ios-simulator-capture/scripts/capture.sh record --duration 10 --output ./demo.mp4
```

## Finding Simulator UDIDs

```bash
xcrun simctl list devices --json
```
