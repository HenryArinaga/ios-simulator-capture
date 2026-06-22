#!/bin/bash

set -u

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
REPO_ROOT=$(CDPATH= cd "${SCRIPT_DIR}/.." && pwd -P)
CAPTURE_SCRIPT="${REPO_ROOT}/scripts/capture.sh"
ORIGINAL_PATH=$PATH

pass_count=0
fail_count=0
current_tmp=""

fail() {
  printf 'not ok - %s\n' "$1" >&2
  fail_count=$((fail_count + 1))
}

pass() {
  printf 'ok - %s\n' "$1"
  pass_count=$((pass_count + 1))
}

assert_eq() {
  label=$1
  expected=$2
  actual=$3
  if [[ "$expected" != "$actual" ]]; then
    printf '  expected: %s\n  actual:   %s\n' "$expected" "$actual" >&2
    return 1
  fi
  return 0
}

assert_contains() {
  label=$1
  needle=$2
  file=$3
  if ! grep -Fq -- "$needle" "$file"; then
    printf '  expected %s to contain: %s\n' "$file" "$needle" >&2
    printf '  actual:\n' >&2
    sed 's/^/    /' "$file" >&2
    return 1
  fi
  return 0
}

assert_match() {
  label=$1
  pattern=$2
  value=$3
  if [[ ! "$value" =~ $pattern ]]; then
    printf '  expected value to match: %s\n  actual: %s\n' "$pattern" "$value" >&2
    return 1
  fi
  return 0
}

assert_file_exists() {
  label=$1
  path=$2
  if [[ ! -f "$path" ]]; then
    printf '  expected file to exist: %s\n' "$path" >&2
    return 1
  fi
  return 0
}

make_tmp() {
  current_tmp=$(mktemp -d "${TMPDIR:-/tmp}/ios-sim-capture-test.XXXXXX")
  # Normalize macOS /var -> /private/var symlink differences so expected
  # paths match the capture script's absolute-path output.
  current_tmp=$(CDPATH= cd "$current_tmp" && pwd -P)
}

cleanup_tmp() {
  if [[ -n "$current_tmp" && -d "$current_tmp" ]]; then
    rm -rf "$current_tmp"
  fi
  current_tmp=""
}

make_mock_xcrun() {
  mock_bin="${current_tmp}/bin"
  mkdir -p "$mock_bin"
  cat >"${mock_bin}/xcrun" <<'MOCK'
#!/bin/bash
set -u

if [[ -n "${XCRUN_MOCK_LOG:-}" ]]; then
  printf '%s\n' "$*" >> "$XCRUN_MOCK_LOG"
fi

if [[ "${1:-}" == "simctl" && "${2:-}" == "list" && "${3:-}" == "devices" && "${4:-}" == "booted" ]]; then
  if [[ "${XCRUN_MOCK_BOOTED:-1}" == "1" ]]; then
    printf '    iPhone 15 (11111111-1111-1111-1111-111111111111) (Booted)\n'
    exit 0
  fi
  printf '== Devices ==\n'
  exit 0
fi

if [[ "${1:-}" == "simctl" && "${2:-}" == "io" && "${4:-}" == "screenshot" ]]; then
  if [[ "${XCRUN_MOCK_SCREENSHOT_FAIL:-0}" == "1" ]]; then
    printf 'mock screenshot failed\n' >&2
    exit 42
  fi
  output=${5:-}
  mkdir -p "$(dirname "$output")"
  printf 'mock screenshot\n' > "$output"
  exit 0
fi

if [[ "${1:-}" == "simctl" && "${2:-}" == "openurl" ]]; then
  exit 0
fi

if [[ "${1:-}" == "simctl" && "${2:-}" == "io" && "${4:-}" == "recordVideo" ]]; then
  output=${5:-}
  mkdir -p "$(dirname "$output")"
  printf 'mock recording started\n' > "$output"
  trap 'printf "INT\n" >> "${XCRUN_MOCK_RECORD_SIGNAL:?}"; exit "${XCRUN_MOCK_RECORD_INT_STATUS:-130}"' INT
  trap 'printf "TERM\n" >> "${XCRUN_MOCK_RECORD_SIGNAL:?}"; exit "${XCRUN_MOCK_RECORD_TERM_STATUS:-143}"' TERM
  while :; do
    sleep 1
  done
fi

printf 'unexpected xcrun call: %s\n' "$*" >&2
exit 99
MOCK
  chmod +x "${mock_bin}/xcrun"
  printf '%s\n' "$mock_bin"
}

make_mock_open() {
  mock_bin="${current_tmp}/bin"
  mkdir -p "$mock_bin"
  cat >"${mock_bin}/uname" <<'MOCK'
#!/bin/bash
printf 'Darwin\n'
MOCK
  cat >"${mock_bin}/open" <<'MOCK'
#!/bin/bash
set -u
printf '%s\n' "$*" >> "${OPEN_MOCK_LOG:?}"
if [[ "${OPEN_MOCK_FAIL:-0}" == "1" ]]; then
  printf 'mock open failed\n' >&2
  exit 42
fi
exit 0
MOCK
  chmod +x "${mock_bin}/uname" "${mock_bin}/open"
  printf '%s\n' "$mock_bin"
}

add_fake_scroll_command() {
  mock_bin=$1
  cat >"${mock_bin}/fake-scroll" <<'MOCK'
#!/bin/bash
set -u
printf 'scroll\n' >> "${FAKE_SCROLL_LOG:?}"
MOCK
  chmod +x "${mock_bin}/fake-scroll"
}

add_fake_flow_command() {
  mock_bin=$1
  cat >"${mock_bin}/fake-flow" <<'MOCK'
#!/bin/bash
set -u
printf 'flow\n' >> "${FAKE_FLOW_LOG:?}"
MOCK
  chmod +x "${mock_bin}/fake-flow"
}

add_fake_magick() {
  mock_bin=$1
  cat >"${mock_bin}/magick" <<'MOCK'
#!/bin/bash
set -u
printf '%s\n' "$*" >> "${FAKE_MAGICK_LOG:?}"
output=${@: -1}
mkdir -p "$(dirname "$output")"
printf 'stitched\n' > "$output"
MOCK
  chmod +x "${mock_bin}/magick"
}

run_capture() {
  workdir=$1
  path_value=$2
  shift 2
  stdout_file="${current_tmp}/stdout"
  stderr_file="${current_tmp}/stderr"
  (
    cd "$workdir" || exit 97
    PATH="$path_value" "$CAPTURE_SCRIPT" "$@"
  ) >"$stdout_file" 2>"$stderr_file"
  status=$?
}

test_no_args_prints_usage() {
  make_tmp
  run_capture "$current_tmp" "${current_tmp}/empty-bin" || true
  assert_eq "status" "2" "$status" &&
    assert_contains "usage" "Usage:" "$stderr_file"
}

test_invalid_duration_prints_usage() {
  make_tmp
  run_capture "$current_tmp" "${current_tmp}/empty-bin" record --duration 0 || true
  assert_eq "status" "2" "$status" &&
    assert_contains "usage" "--duration <seconds>" "$stderr_file"
}

test_missing_xcrun() {
  make_tmp
  mkdir -p "${current_tmp}/empty-bin"
  run_capture "$current_tmp" "${current_tmp}/empty-bin" screenshot || true
  assert_eq "status" "1" "$status" &&
    assert_contains "missing xcrun" "xcrun not found" "$stderr_file"
}

test_open_simulator_uses_macos_open_without_xcrun() {
  make_tmp
  mock_bin=$(make_mock_open)
  log_file="${current_tmp}/open.log"
  OPEN_MOCK_LOG="$log_file" run_capture "$current_tmp" "$mock_bin" open || true
  assert_eq "status" "0" "$status" &&
    assert_contains "success message" "Opened iOS Simulator." "$stdout_file" &&
    assert_contains "open command" "-a Simulator" "$log_file"
}

test_open_simulator_reports_open_failure() {
  make_tmp
  mock_bin=$(make_mock_open)
  log_file="${current_tmp}/open.log"
  OPEN_MOCK_LOG="$log_file" OPEN_MOCK_FAIL=1 run_capture "$current_tmp" "$mock_bin" open || true
  assert_eq "status" "1" "$status" &&
    assert_contains "open stderr" "mock open failed" "$stderr_file" &&
    assert_contains "open failure" "Could not open Simulator" "$stderr_file"
}

test_no_booted_simulator() {
  make_tmp
  mock_bin=$(make_mock_xcrun)
  XCRUN_MOCK_BOOTED=0 run_capture "$current_tmp" "${mock_bin}:${ORIGINAL_PATH}" screenshot || true
  assert_eq "status" "1" "$status" &&
    assert_contains "no booted simulator" "No simulator is currently booted" "$stderr_file"
}

test_screenshot_default_output_path() {
  make_tmp
  mock_bin=$(make_mock_xcrun)
  run_capture "$current_tmp" "${mock_bin}:${ORIGINAL_PATH}" screenshot || true
  output=$(tr -d '\n' < "$stdout_file")
  assert_eq "status" "0" "$status" &&
    assert_match "default path" "^${current_tmp}/screenshot-[0-9]{8}-[0-9]{6}\\.png$" "$output" &&
    assert_file_exists "screenshot file" "$output"
}

test_screenshot_directory_output_path() {
  make_tmp
  mock_bin=$(make_mock_xcrun)
  output_dir="${current_tmp}/captures/"
  run_capture "$current_tmp" "${mock_bin}:${ORIGINAL_PATH}" screenshot --output "$output_dir" || true
  output=$(tr -d '\n' < "$stdout_file")
  assert_eq "status" "0" "$status" &&
    assert_match "directory output" "^${current_tmp}/captures/screenshot-[0-9]{8}-[0-9]{6}\\.png$" "$output" &&
    assert_file_exists "screenshot file" "$output"
}

test_screenshot_existing_directory_output_path() {
  make_tmp
  mock_bin=$(make_mock_xcrun)
  output_dir="${current_tmp}/existing-captures"
  mkdir -p "$output_dir"
  run_capture "$current_tmp" "${mock_bin}:${ORIGINAL_PATH}" screenshot --output "$output_dir" || true
  output=$(tr -d '\n' < "$stdout_file")
  assert_eq "status" "0" "$status" &&
    assert_match "existing directory output" "^${current_tmp}/existing-captures/screenshot-[0-9]{8}-[0-9]{6}\\.png$" "$output" &&
    assert_file_exists "screenshot file" "$output"
}

test_screenshot_failure_propagates() {
  make_tmp
  mock_bin=$(make_mock_xcrun)
  XCRUN_MOCK_SCREENSHOT_FAIL=1 run_capture "$current_tmp" "${mock_bin}:${ORIGINAL_PATH}" screenshot --output failed.png || true
  assert_eq "status" "42" "$status" &&
    assert_contains "failure output" "mock screenshot failed" "$stderr_file"
}

test_record_stops_after_duration() {
  make_tmp
  mock_bin=$(make_mock_xcrun)
  signal_file="${current_tmp}/record-signal"
  log_file="${current_tmp}/xcrun.log"
  XCRUN_MOCK_RECORD_SIGNAL="$signal_file" XCRUN_MOCK_LOG="$log_file" \
    run_capture "$current_tmp" "${mock_bin}:${ORIGINAL_PATH}" record --duration 1 || true
  output=$(tr -d '\n' < "$stdout_file")
  assert_eq "status" "0" "$status" &&
    assert_match "record path" "^${current_tmp}/recording-[0-9]{8}-[0-9]{6}\\.mp4$" "$output" &&
    assert_file_exists "recording file" "$output" &&
    assert_contains "record command" "simctl io booted recordVideo" "$log_file" &&
    assert_file_exists "record stopped" "$signal_file"
}

test_named_screen_requires_config() {
  make_tmp
  run_capture "$current_tmp" "${current_tmp}/empty-bin" screenshot --screen home || true
  assert_eq "status" "1" "$status" &&
    assert_contains "missing config" "Named screens/flows require a repo-local .ios-capture-flows.yml file." "$stderr_file"
}

test_named_screen_opens_url_before_screenshot() {
  make_tmp
  mock_bin=$(make_mock_xcrun)
  log_file="${current_tmp}/xcrun.log"
  cat >"${current_tmp}/.ios-capture-flows.yml" <<'YAML'
screens:
  home:
    open_url: spicy://home
    wait: 0
YAML

  XCRUN_MOCK_LOG="$log_file" run_capture "$current_tmp" "${mock_bin}:${ORIGINAL_PATH}" screenshot --screen home --output home.png || true
  output=$(tr -d '\n' < "$stdout_file")
  assert_eq "status" "0" "$status" &&
    assert_eq "output" "${current_tmp}/home.png" "$output" &&
    assert_file_exists "screenshot file" "$output" &&
    assert_contains "openurl" "simctl openurl booted spicy://home" "$log_file" &&
    assert_contains "screenshot" "simctl io booted screenshot ${current_tmp}/home.png" "$log_file"
}

test_full_page_screenshot_stitches_viewports() {
  make_tmp
  mock_bin=$(make_mock_xcrun)
  add_fake_scroll_command "$mock_bin"
  add_fake_magick "$mock_bin"
  scroll_log="${current_tmp}/scroll.log"
  magick_log="${current_tmp}/magick.log"
  xcrun_log="${current_tmp}/xcrun.log"
  cat >"${current_tmp}/.ios-capture-flows.yml" <<'YAML'
screens:
  home:
    open_url: spicy://home
    wait: 0
    full_page:
      scrolls: 2
      scroll_command: fake-scroll
      stitch: true
YAML

  FAKE_SCROLL_LOG="$scroll_log" FAKE_MAGICK_LOG="$magick_log" XCRUN_MOCK_LOG="$xcrun_log" \
    run_capture "$current_tmp" "${mock_bin}:${ORIGINAL_PATH}" screenshot --screen home --full-page --output full.png || true
  output=$(tr -d '\n' < "$stdout_file")
  assert_eq "status" "0" "$status" &&
    assert_eq "stitched output" "${current_tmp}/full.png" "$output" &&
    assert_file_exists "stitched file" "$output" &&
    assert_file_exists "viewport 0" "${current_tmp}/full-viewport-0.png" &&
    assert_file_exists "viewport 1" "${current_tmp}/full-viewport-1.png" &&
    assert_file_exists "viewport 2" "${current_tmp}/full-viewport-2.png" &&
    assert_contains "openurl" "simctl openurl booted spicy://home" "$xcrun_log" &&
    assert_contains "magick append" "-append ${current_tmp}/full.png" "$magick_log" &&
    assert_eq "scroll count" "2" "$(wc -l < "$scroll_log" | tr -d ' ')"
}

test_full_page_without_magick_keeps_viewports() {
  make_tmp
  mock_bin=$(make_mock_xcrun)
  add_fake_scroll_command "$mock_bin"
  scroll_log="${current_tmp}/scroll.log"
  cat >"${current_tmp}/.ios-capture-flows.yml" <<'YAML'
screens:
  home:
    open_url: spicy://home
    wait: 0
    full_page:
      scrolls: 1
      scroll_command: fake-scroll
      stitch: true
YAML

  FAKE_SCROLL_LOG="$scroll_log" \
    run_capture "$current_tmp" "${mock_bin}:${ORIGINAL_PATH}" screenshot --screen home --full-page --output full.png || true
  assert_eq "status" "0" "$status" &&
    assert_contains "missing magick" "brew install imagemagick" "$stderr_file" &&
    assert_contains "viewport 0 output" "${current_tmp}/full-viewport-0.png" "$stdout_file" &&
    assert_contains "viewport 1 output" "${current_tmp}/full-viewport-1.png" "$stdout_file" &&
    assert_file_exists "viewport 0" "${current_tmp}/full-viewport-0.png" &&
    assert_file_exists "viewport 1" "${current_tmp}/full-viewport-1.png" &&
    assert_eq "scroll count" "1" "$(wc -l < "$scroll_log" | tr -d ' ')"
}

test_record_flow_uses_config_command_and_duration() {
  make_tmp
  mock_bin=$(make_mock_xcrun)
  add_fake_flow_command "$mock_bin"
  signal_file="${current_tmp}/record-signal"
  flow_log="${current_tmp}/flow.log"
  xcrun_log="${current_tmp}/xcrun.log"
  cat >"${current_tmp}/.ios-capture-flows.yml" <<'YAML'
flows:
  signup:
    command: fake-flow
    record: true
    duration: 1
YAML

  FAKE_FLOW_LOG="$flow_log" XCRUN_MOCK_RECORD_SIGNAL="$signal_file" XCRUN_MOCK_LOG="$xcrun_log" \
    run_capture "$current_tmp" "${mock_bin}:${ORIGINAL_PATH}" record --flow signup --output signup.mp4 || true
  output=$(tr -d '\n' < "$stdout_file")
  assert_eq "status" "0" "$status" &&
    assert_eq "recording output" "${current_tmp}/signup.mp4" "$output" &&
    assert_file_exists "recording file" "$output" &&
    assert_contains "record command" "simctl io booted recordVideo ${current_tmp}/signup.mp4" "$xcrun_log" &&
    assert_contains "flow command" "flow" "$flow_log" &&
    assert_file_exists "record stopped" "$signal_file"
}

run_test() {
  name=$1
  cleanup_tmp
  if "$name"; then
    pass "$name"
  else
    fail "$name"
  fi
  cleanup_tmp
}

run_test test_no_args_prints_usage
run_test test_invalid_duration_prints_usage
run_test test_missing_xcrun
run_test test_open_simulator_uses_macos_open_without_xcrun
run_test test_open_simulator_reports_open_failure
run_test test_no_booted_simulator
run_test test_screenshot_default_output_path
run_test test_screenshot_directory_output_path
run_test test_screenshot_existing_directory_output_path
run_test test_screenshot_failure_propagates
run_test test_record_stops_after_duration
run_test test_named_screen_requires_config
run_test test_named_screen_opens_url_before_screenshot
run_test test_full_page_screenshot_stitches_viewports
run_test test_full_page_without_magick_keeps_viewports
run_test test_record_flow_uses_config_command_and_duration

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"

if [[ "$fail_count" -ne 0 ]]; then
  exit 1
fi
