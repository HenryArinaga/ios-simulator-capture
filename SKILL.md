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
bash scripts/capture.sh screenshot [--output <path>] [--device <UDID|booted>] [--screen <name>] [--full-page]
bash scripts/capture.sh record [--output <path>] [--device <UDID|booted>] [--duration <seconds>] [--flow <name>]
```

Options:

- `--output <path>` writes to a file path, or writes a timestamped default filename inside a directory path.
- `--device <UDID|booted>` selects the simulator. Default: `booted`.
- `--duration <seconds>` sets the recording length in whole seconds. Default: `30`.
- `--screen <name>` opens a named screen from `.ios-capture-flows.yml` before taking a screenshot.
- `--flow <name>` records while a named flow command from `.ios-capture-flows.yml` runs.
- `--full-page` captures a named screen through configured scroll automation and optional stitching.
- `-h`, `--help` prints usage.

On success, the script prints the absolute output path. In full-page mode without stitching, it prints the saved viewport screenshot paths.

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

# Open a configured screen before capture.
bash scripts/capture.sh screenshot --screen home --output ./captures/home.png

# Capture a configured full-page screen.
bash scripts/capture.sh screenshot --screen home --full-page --output ./captures/home-full.png

# Record while a configured flow command runs.
bash scripts/capture.sh record --flow signup --output ./captures/signup.mp4
```

## Repo-Local Screen and Flow Config

Named screens and flows are optional and require `.ios-capture-flows.yml` in the current working directory where the script is invoked. If `--screen` or `--flow` is used and the file is missing, the script reports that named screens and flows require a repo-local config file.

Supported config shape:

```yaml
screens:
  home:
    open_url: spicy://home
    wait: 2
    full_page:
      scrolls: 4
      scroll_command: maestro test .maestro/scroll-down.yml
      stitch: true
flows:
  signup:
    command: xcodebuild test -scheme Spicy -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:SpicyUITests/SignupFlowTests/testSignupFlow
    record: true
    duration: 20
```

`screens.<name>.open_url` runs `xcrun simctl openurl <device> <url>`. Optional `wait` delays capture by whole seconds after navigation.

`record --flow <name>` starts recording, runs `flows.<name>.command`, and stops when the command finishes or the duration expires. Explicit `--duration` overrides `flows.<name>.duration`; otherwise the configured duration is used when present. The `record` setting documents that a flow is intended for recording.

`screenshot --screen <name> --full-page` opens the configured URL, captures the initial viewport, then runs `full_page.scroll_command` and captures another viewport for each configured scroll. If `full_page.stitch: true`, ImageMagick `magick ... -append` creates the final PNG. If `magick` is missing, install it with `brew install imagemagick`; the script keeps individual viewport screenshots and explains that stitching was skipped.

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
bash tests/capture_test.sh
git diff --check
```
