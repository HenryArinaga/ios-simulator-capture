---
name: ios-simulator-capture
description: Capture screenshots and timed screen recordings from the iOS Simulator with xcrun simctl. macOS only.
---

# iOS Simulator Capture

Use this skill when the user wants a screenshot or short screen recording from a running iOS Simulator.

This skill is macOS-only for real captures. It depends on Xcode's `xcrun simctl`; do not expect it to capture from Linux or Windows. The included tests can run on Linux because they mock `xcrun`.

## Requirements

- macOS
- Xcode or Xcode Command Line Tools
- A booted iOS Simulator, or a specific booted simulator UDID
- Bash and standard POSIX command-line tools

If `xcrun` is missing, install Xcode Command Line Tools:

```bash
xcode-select --install
```

## Usage

Run the helper script from this skill directory:

```bash
bash scripts/capture.sh screenshot [--output <path>] [--device <UDID|booted>]
bash scripts/capture.sh record [--output <path>] [--device <UDID|booted>] [--duration <seconds>]
```

Options:

- `--output <path>` writes to a file path, or writes a timestamped default filename inside a directory path.
- `--device <UDID|booted>` selects the simulator. Default: `booted`.
- `--duration <seconds>` sets the recording length in whole seconds. Default: `30`.
- `-h`, `--help` prints usage.

On success, the script prints the absolute output path.

## Examples

```bash
# Screenshot the booted simulator.
bash scripts/capture.sh screenshot

# Screenshot into a directory using a timestamped filename.
bash scripts/capture.sh screenshot --output ./captures/

# Screenshot to an exact file path.
bash scripts/capture.sh screenshot --output ./captures/home.png

# Record 10 seconds from the booted simulator.
bash scripts/capture.sh record --duration 10 --output ./captures/demo.mp4

# Target a specific simulator.
bash scripts/capture.sh screenshot --device <UDID>
```

## Simulator Discovery

List available simulators:

```bash
xcrun simctl list devices
```

List simulators as JSON:

```bash
xcrun simctl list devices --json
```

Boot a simulator:

```bash
xcrun simctl boot <UDID>
```

## Troubleshooting

`xcrun not found`

Install Xcode or Xcode Command Line Tools and confirm `xcrun` is on `PATH`.

`No simulator is currently booted`

Open or boot an iOS Simulator first, or pass `--device <UDID>` for a specific booted simulator.

Capture command fails

Check that the simulator is booted and the output directory is writable. The script forwards `simctl` error output for screenshot failures and record startup failures.

Recording finalization takes a moment

The script stops timed recordings by sending `SIGINT` to `simctl io recordVideo`, then waits for the process to finish writing the video file.

## Development

Run local checks:

```bash
bash -n scripts/capture.sh
bash -n tests/capture_test.sh
tests/capture_test.sh
```
