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
bash scripts/capture.sh screenshot [--output <path>] [--device <UDID|booted>]
bash scripts/capture.sh record [--output <path>] [--device <UDID|booted>] [--duration <seconds>]
```

Options:

- `--output <path>` writes to a file path, or writes a default filename inside a directory path.
- `--device <UDID|booted>` selects a simulator. Default: `booted`.
- `--duration <seconds>` sets the recording length in whole seconds. Default: `30`.
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
tests/capture_test.sh
```

The tests do not require macOS or Xcode. They replace `xcrun` with a temporary mock.

## License

MIT. See [LICENSE](LICENSE).
