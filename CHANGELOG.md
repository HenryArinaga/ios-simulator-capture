# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

- Add `capture.sh open` for opening the iOS Simulator app with `open -a Simulator`.
- Make current visible viewport screenshot and recording the primary documented workflow.
- De-emphasize named screens, named flows, and full-page scrolling as advanced optional config.
- Document that full-page scroll capture requires app-specific scroll automation and is not automatic.
- Add optional repo-local `.ios-capture-flows.yml` support for named screenshot screens and record flows.
- Add `screenshot --screen <name>`, `record --flow <name>`, and `screenshot --screen <name> --full-page`.
- Add full-page viewport capture with configured scroll automation and optional ImageMagick vertical stitching.
- Initial public-ready Bash skill for capturing screenshots and timed screen recordings from the iOS Simulator.
- Includes local Bash tests that mock `xcrun`.
