# iOS Simulator Capture

Open the iOS Simulator, capture the visible current simulator viewport, and record the visible current simulator viewport from a small Bash helper.

The basic workflow does not require Maestro, deep links, UI tests, or app-specific config.

## Quick Start

Open the iOS Simulator app:

```bash
bash scripts/capture.sh open
```

Screenshot the current visible simulator viewport:

```bash
bash scripts/capture.sh screenshot --output ./captures/current.png
```

Record 30 seconds of the current visible simulator viewport:

```bash
bash scripts/capture.sh record --duration 30 --output ./captures/demo.mp4
```

## Requirements

- macOS for `open`
- macOS plus Xcode or Xcode Command Line Tools for screenshot and record
- A booted iOS Simulator for screenshot and record
- Bash and standard POSIX command-line tools

Install Xcode Command Line Tools if `xcrun` is missing:

```bash
xcode-select --install
```

## Install

```bash
npx skills add https://github.com/HenryArinaga/ios-simulator-capture --skill "ios-simulator-capture"
```

After installation, run the script from the installed skill directory:

```bash
bash scripts/capture.sh --help
```

## Usage

```bash
bash scripts/capture.sh open
bash scripts/capture.sh screenshot [--output <path>] [--device <UDID|booted>]
bash scripts/capture.sh record [--output <path>] [--device <UDID|booted>] [--duration <seconds>]
```

Options:

- `--output <path>` writes to a file path, or writes a default filename inside a directory path.
- `--device <UDID|booted>` selects a simulator for screenshot or record. Default: `booted`.
- `--duration <seconds>` sets the recording length in whole seconds. Default: `30`.
- `-h`, `--help` prints usage.

Default filenames are timestamped:

- `screenshot-YYYYMMDD-HHMMSS.png`
- `recording-YYYYMMDD-HHMMSS.mp4`

The script prints the absolute output path on successful screenshot and record commands. `open` prints a concise success message.

## Examples

Capture a screenshot from the booted simulator:

```bash
bash scripts/capture.sh screenshot
```

Capture a screenshot to a specific file:

```bash
bash scripts/capture.sh screenshot --output ./captures/home.png
```

Capture a screenshot into a directory using the default filename:

```bash
bash scripts/capture.sh screenshot --output ./captures/
```

Record 10 seconds:

```bash
bash scripts/capture.sh record --duration 10 --output ./captures/demo.mp4
```

Target a specific booted simulator:

```bash
bash scripts/capture.sh screenshot --device <UDID>
```

## Advanced Optional Config

Named screens, named recording flows, and full-page scrolling are advanced optional features. They are not needed for the default visible viewport workflow.

Full-page scroll capture is not automatic. It requires app-specific automation that can reliably scroll the simulator content, such as a custom UI test, Maestro flow, or another command you provide. Without that extra automation, the supported behavior is current visible viewport capture and recording.

Advanced usage:

```bash
bash scripts/capture.sh screenshot --screen home --output ./captures/home.png
bash scripts/capture.sh screenshot --screen home --full-page --output ./captures/home-full.png
bash scripts/capture.sh record --flow signup --output ./captures/signup.mp4
```

Advanced options:

- `--screen <name>` opens a named screen from `.ios-capture-flows.yml` before taking a screenshot.
- `--flow <name>` records while a named flow command from `.ios-capture-flows.yml` runs.
- `--full-page` captures a named screen through configured scroll automation and optionally stitches the viewports.

Named screens and flows require a `.ios-capture-flows.yml` file in the current working directory where `capture.sh` is invoked. If `--screen` or `--flow` is used and the file is missing, the script prints:

```text
Error: Named screens/flows require a repo-local .ios-capture-flows.yml file.
```

Supported config format:

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

`screens.<name>.open_url` runs:

```bash
xcrun simctl openurl <device> <url>
```

`screens.<name>.wait` is optional and waits whole seconds before capture.

`flows.<name>.command` runs as a shell command. `record --flow <name>` starts recording, runs the command, then stops when the command finishes or the duration expires, whichever comes first. If `--duration` is not supplied, `flows.<name>.duration` is used when present. The `record` setting documents that the flow is intended for recording; `record --flow` records regardless.

`--full-page` requires `--screen`. The script opens the screen URL, captures the initial viewport, repeats `full_page.scrolls` times by running `full_page.scroll_command`, then captures each new viewport. If `full_page.stitch: true`, it runs ImageMagick:

```bash
magick <viewport-pngs...> -append <output>
```

If `magick` is missing, install it with:

```bash
brew install imagemagick
```

When stitching is requested but `magick` is unavailable, individual viewport screenshots are kept and printed, and stitching is skipped.

## Finding Simulator UDIDs

```bash
xcrun simctl list devices
```

For machine-readable output:

```bash
xcrun simctl list devices --json
```

## Troubleshooting

`open is macOS-only`

Run `bash scripts/capture.sh open` on macOS.

`xcrun not found`

Install Xcode or the Xcode Command Line Tools, then make sure `xcrun` is on `PATH`.

`No simulator is currently booted`

Start a simulator from Xcode, or boot one from the command line:

```bash
xcrun simctl boot <UDID>
```

Screenshot or recording command fails

Run the matching `xcrun simctl io ...` command directly to see the underlying simulator error. Confirm the simulator is booted and the target output directory is writable.

Recording does not stop immediately

The script starts `simctl io recordVideo`, waits for the requested duration, and sends `SIGINT` to stop recording cleanly. Very short durations may still take a moment while `simctl` finalizes the `.mp4` file.

## Development

Run syntax checks and tests:

```bash
bash -n scripts/capture.sh
bash -n tests/capture_test.sh
bash tests/capture_test.sh
git diff --check
```

The tests do not require macOS or Xcode. They replace `open`, `xcrun`, `magick`, and configured scroll or flow commands with temporary mocks.

## License

MIT. See [LICENSE](LICENSE).
