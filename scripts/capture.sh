#!/bin/bash
# iOS Simulator Capture Script
# Usage:
#   capture.sh screenshot [--output <path>] [--device <UDID|booted>]
#   capture.sh record [--output <path>] [--device <UDID|booted>] [--duration <seconds>]

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  capture.sh screenshot [--output <path>] [--device <UDID|booted>]
  capture.sh record [--output <path>] [--device <UDID|booted>] [--duration <seconds>]
USAGE
}

die_usage() {
  usage
  exit 2
}

if ! command -v xcrun >/dev/null 2>&1; then
  echo "Error: xcrun not found. Install Xcode Command Line Tools: xcode-select --install" >&2
  exit 1
fi

if [[ $# -lt 1 ]]; then
  die_usage
fi

subcommand=$1
shift

case "$subcommand" in
  screenshot|record) ;;
  *) die_usage ;;
esac

device="booted"
duration="30"
output=""
command_output=""
record_log=""

cleanup() {
  if [[ -n "$record_log" && -f "$record_log" ]]; then
    rm -f "$record_log"
  fi
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || die_usage
      output=$2
      shift 2
      ;;
    --device)
      [[ $# -ge 2 ]] || die_usage
      device=$2
      shift 2
      ;;
    --duration)
      [[ "$subcommand" == "record" ]] || die_usage
      [[ $# -ge 2 ]] || die_usage
      duration=$2
      case "$duration" in
        ''|*[!0-9]*) die_usage ;;
      esac
      shift 2
      ;;
    *)
      die_usage
      ;;
  esac
done

timestamp=$(date +"%Y%m%d-%H%M%S")
case "$subcommand" in
  screenshot)
    default_name="screenshot-${timestamp}.png"
    ;;
  record)
    default_name="recording-${timestamp}.mp4"
    ;;
esac

if [[ -z "$output" ]]; then
  output="./${default_name}"
elif [[ -d "$output" ]]; then
  output="${output%/}/${default_name}"
fi

output_dir=$(dirname "$output")
output_base=$(basename "$output")

if [[ ! -d "$output_dir" ]]; then
  mkdir -p "$output_dir"
fi

abs_output_dir=$(cd "$output_dir" && pwd -P)
abs_output="${abs_output_dir}/${output_base}"

if [[ "$device" == "booted" ]] && ! xcrun simctl list devices booted 2>/dev/null | grep -q "(Booted)"; then
  echo "Error: No simulator is currently booted. Boot a simulator first: xcrun simctl boot <UDID>." >&2
  exit 1
fi

case "$subcommand" in
  screenshot)
    set +e
    command_output=$(xcrun simctl io "$device" screenshot "$abs_output" 2>&1)
    command_status=$?
    set -e

    if [[ "$command_status" -ne 0 ]]; then
      if [[ -n "$command_output" ]]; then
        printf '%s\n' "$command_output" >&2
      fi
      exit "$command_status"
    fi
    ;;
  record)
    record_log=$(mktemp "${TMPDIR:-/tmp}/ios-simulator-capture.XXXXXX")

    (
      trap - INT
      exec xcrun simctl io "$device" recordVideo "$abs_output"
    ) >"$record_log" 2>&1 &
    record_pid=$!

    elapsed=0
    stopped_by_timer=0
    while kill -0 "$record_pid" >/dev/null 2>&1 && [[ "$elapsed" -lt "$duration" ]]; do
      sleep 1
      elapsed=$((elapsed + 1))
    done

    if kill -0 "$record_pid" >/dev/null 2>&1; then
      kill -INT "$record_pid" >/dev/null 2>&1 || true
      stopped_by_timer=1
    fi

    set +e
    wait "$record_pid"
    record_status=$?
    set -e

    if [[ "$stopped_by_timer" -eq 0 && "$record_status" -ne 0 ]]; then
      if [[ -s "$record_log" ]]; then
        cat "$record_log" >&2
      fi
      exit "$record_status"
    fi
    ;;
esac

echo "$abs_output"
