# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

- Add optional repo-local `.ios-capture-flows.yml` support for named screenshot screens and record flows.
- Add `screenshot --screen <name>`, `record --flow <name>`, and `screenshot --screen <name> --full-page`.
- Add full-page viewport capture with configured scroll automation and optional ImageMagick vertical stitching.
- Initial public-ready Bash skill for capturing screenshots and timed screen recordings from the iOS Simulator.
- Includes local Bash tests that mock `xcrun`.
