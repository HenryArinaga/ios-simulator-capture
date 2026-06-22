---
name: ios-simulator-capture
description: Open the iOS Simulator app, screenshot the current visible simulator viewport, and record timed video from the current visible simulator viewport. macOS only.
---

# iOS Simulator Capture

Use this skill when the user wants Hermes to open the iOS Simulator, take a screenshot of the current simulator, or record a short video of the current simulator.

The default behavior is simple visible viewport capture. Do not steer the user toward named screens, full-page capture, Maestro, deep links, UI tests, or app config unless they explicitly ask for advanced automation.

## Intent Mapping

Map common user phrases to these commands:

- "open simulator" or "open the iOS simulator": `bash scripts/capture.sh open`
- "screenshot current simulator": `bash scripts/capture.sh screenshot --output ./captures/current.png`
- "take a picture of the simulator": `bash scripts/capture.sh screenshot --output ./captures/current.png`
- "record 30 seconds of simulator": `bash scripts/capture.sh record --duration 30 --output ./captures/demo.mp4`

For similar screenshot requests, capture the current visible simulator viewport. For similar recording requests, record the current visible simulator viewport for the requested duration, defaulting to 30 seconds if the user does not specify a duration.

## Requirements

- macOS for `open`
- macOS plus Xcode or Xcode Command Line Tools for screenshot and record
- A booted iOS Simulator for screenshot and record
- Bash and standard POSIX command-line tools

If `xcrun` is missing, install Xcode Command Line Tools:

```bash
xcode-select --install
```

## Usage

Run the helper script from this skill directory:

```bash
bash scripts/capture.sh open
bash scripts/capture.sh screenshot --output ./captures/current.png
bash scripts/capture.sh record --duration 30 --output ./captures/demo.mp4
```

General command shape:

```bash
bash scripts/capture.sh open
bash scripts/capture.sh screenshot [--output <path>] [--device <UDID|booted>]
bash scripts/capture.sh record [--output <path>] [--device <UDID|booted>] [--duration <seconds>]
```

Options:

- `--output <path>` writes to a file path, or writes a timestamped default filename inside a directory path.
- `--device <UDID|booted>` selects the simulator for screenshot or record. Default: `booted`.
- `--duration <seconds>` sets the recording length in whole seconds. Default: `30`.
- `-h`, `--help` prints usage.

On success, screenshot and record print the absolute output path. `open` prints a concise success message.

## Examples

```bash
# Open the iOS Simulator app.
bash scripts/capture.sh open

# Screenshot the current visible simulator viewport.
bash scripts/capture.sh screenshot --output ./captures/current.png

# Screenshot into a directory using a timestamped filename.
bash scripts/capture.sh screenshot --output ./captures/

# Record 30 seconds from the current visible simulator viewport.
bash scripts/capture.sh record --duration 30 --output ./captures/demo.mp4

# Target a specific booted simulator.
bash scripts/capture.sh screenshot --device <UDID>
```

## Advanced Optional Config

Named screens, named recording flows, and full-page scrolling are optional advanced features. They are not the primary Hermes workflow.

Full-page scroll capture is not automatic. It requires extra app-specific automation that can scroll the content and expose each viewport, such as a custom UI test, Maestro flow, or another command. Without that extra automation, the supported workflow is current visible viewport capture and recording.

Advanced commands:

```bash
bash scripts/capture.sh screenshot --screen home --output ./captures/home.png
bash scripts/capture.sh screenshot --screen home --full-page --output ./captures/home-full.png
bash scripts/capture.sh record --flow signup --output ./captures/signup.mp4
```

Advanced options:

- `--screen <name>` opens a named screen from `.ios-capture-flows.yml` before taking a screenshot.
- `--flow <name>` records while a named flow command from `.ios-capture-flows.yml` runs.
- `--full-page` captures a named screen through configured scroll automation and optional stitching.

Named screens and flows require `.ios-capture-flows.yml` in the current working directory where the script is invoked. If `--screen` or `--flow` is used and the file is missing, the script reports that named screens and flows require a repo-local config file.

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

`open is macOS-only`

Run `bash scripts/capture.sh open` on macOS.

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
