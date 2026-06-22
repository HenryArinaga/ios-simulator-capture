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

if [[ "${1:-}" == "simctl" && "${2:-}" == "io" && "${4:-}" == "recordVideo" ]]; then
  output=${5:-}
  mkdir -p "$(dirname "$output")"
  printf 'mock recording started\n' > "$output"
  trap 'printf "INT\n" >> "${XCRUN_MOCK_RECORD_SIGNAL:?}"; exit "${XCRUN_MOCK_RECORD_INT_STATUS:-130}"' INT
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
    assert_contains "record stopped" "INT" "$signal_file"
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
run_test test_no_booted_simulator
run_test test_screenshot_default_output_path
run_test test_screenshot_directory_output_path
run_test test_screenshot_existing_directory_output_path
run_test test_screenshot_failure_propagates
run_test test_record_stops_after_duration

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"

if [[ "$fail_count" -ne 0 ]]; then
  exit 1
fi
