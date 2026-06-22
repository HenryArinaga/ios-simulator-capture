# iOS Simulator Capture

Capture screenshots and timed screen recordings from the iOS Simulator with `xcrun simctl`.

This skill is macOS-only for real captures because it depends on Xcode's `xcrun` and `simctl`. Its test suite runs on Linux by mocking `xcrun`.

## Requirements

- macOS
- Xcode or Xcode Command Line Tools
- A booted iOS Simulator, unless you pass a specific booted simulator UDID
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
bash scripts/capture.sh screenshot [--output <path>] [--device <UDID|booted>] [--screen <name>] [--full-page]
bash scripts/capture.sh record [--output <path>] [--device <UDID|booted>] [--duration <seconds>] [--flow <name>]
```

Options:

- `--output <path>` writes to a file path, or writes a default filename inside a directory path.
- `--device <UDID|booted>` selects a simulator. Default: `booted`.
- `--duration <seconds>` sets the recording length in whole seconds. Default: `30`.
- `--screen <name>` opens a named screen from `.ios-capture-flows.yml` before taking a screenshot.
- `--flow <name>` records while a named flow command from `.ios-capture-flows.yml` runs.
- `--full-page` captures a named screen through configured scroll automation and optionally stitches the viewports.
- `-h`, `--help` prints usage.

Default filenames are timestamped:

- `screenshot-YYYYMMDD-HHMMSS.png`
- `recording-YYYYMMDD-HHMMSS.mp4`

The script prints the absolute output path on success.

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

Target a specific simulator:

```bash
bash scripts/capture.sh screenshot --device <UDID>
```

Capture a named screen from a repo-local config:

```bash
bash scripts/capture.sh screenshot --screen home --output ./captures/home.png
```

Capture a configured full-page screen:

```bash
bash scripts/capture.sh screenshot --screen home --full-page --output ./captures/home-full.png
```

Record while a configured flow command runs:

```bash
bash scripts/capture.sh record --flow signup --output ./captures/signup.mp4
```

Override a configured flow duration:

```bash
bash scripts/capture.sh record --flow signup --duration 10
```

## Named Screens and Flows

Named screens and flows are optional. They require a `.ios-capture-flows.yml` file in the current working directory where `capture.sh` is invoked. If `--screen` or `--flow` is used and the file is missing, the script prints:

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

Full-page screenshots are visible-viewport captures plus configured scrolling. `--full-page` requires `--screen`; the script opens the screen URL, captures the initial viewport, repeats `full_page.scrolls` times by running `full_page.scroll_command`, then captures each new viewport. If `full_page.stitch: true`, it runs ImageMagick:

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

The tests do not require macOS or Xcode. They replace `xcrun`, `magick`, and configured scroll or flow commands with temporary mocks.

## License

MIT. See [LICENSE](LICENSE).
