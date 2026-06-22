#!/bin/bash
# iOS Simulator Capture Script
# Usage:
#   capture.sh screenshot [--output <path>] [--device <UDID|booted>] [--screen <name>] [--full-page]
#   capture.sh record [--output <path>] [--device <UDID|booted>] [--duration <seconds>] [--flow <name>]

set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage:' \
    '  capture.sh screenshot [--output <path>] [--device <UDID|booted>] [--screen <name>] [--full-page]' \
    '  capture.sh record [--output <path>] [--device <UDID|booted>] [--duration <seconds>] [--flow <name>]' \
    '' \
    'Options:' \
    '  --output <path>       File path to write, or a directory to place the default file in.' \
    '  --device <device>     Simulator UDID or "booted". Defaults to "booted".' \
    '  --duration <seconds>  Recording length in whole seconds. Defaults to 30.' \
    '  --screen <name>       Screenshot a named screen from .ios-capture-flows.yml.' \
    '  --flow <name>         Record while a named flow command from .ios-capture-flows.yml runs.' \
    '  --full-page           Screenshot a named screen by scrolling and optionally stitching viewports.' \
    '  -h, --help            Show this help.' >&2
}

die_usage() {
  usage
  exit 2
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

require_positive_integer() {
  value=$1
  case "$value" in
    ''|*[!0-9]*) die_usage ;;
  esac
  [[ "$value" -gt 0 ]] || die_usage
}

require_nonnegative_integer() {
  value=$1
  case "$value" in
    ''|*[!0-9]*) die "Expected a nonnegative integer, got: $value" ;;
  esac
}

config_get() {
  config_section=$1
  config_name=$2
  config_key=$3
  awk -v wanted_section="$config_section" -v wanted_name="$config_name" -v wanted_key="$config_key" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if ((value ~ /^".*"$/) || (value ~ /^\047.*\047$/)) {
        value = substr(value, 2, length(value) - 2)
      }
      return value
    }
    /^[[:space:]]*($|#)/ { next }
    /^[^[:space:]][^:]*:[[:space:]]*$/ {
      section = substr($0, 1, index($0, ":") - 1)
      name = ""
      nested = ""
      next
    }
    /^  [^[:space:]][^:]*:[[:space:]]*$/ {
      if (section == wanted_section) {
        name = trim(substr($0, 1, index($0, ":") - 1))
      } else {
        name = ""
      }
      nested = ""
      next
    }
    /^    [^[:space:]][^:]*:/ {
      if (section != wanted_section || name != wanted_name) {
        next
      }
      line = substr($0, 5)
      key = trim(substr(line, 1, index(line, ":") - 1))
      value = trim(substr(line, index(line, ":") + 1))
      if (value == "") {
        nested = key
        next
      }
      nested = ""
      if (key == wanted_key) {
        print value
        found = 1
        exit
      }
      next
    }
    /^      [^[:space:]][^:]*:/ {
      if (section != wanted_section || name != wanted_name || nested == "") {
        next
      }
      line = substr($0, 7)
      key = nested "." trim(substr(line, 1, index(line, ":") - 1))
      value = trim(substr(line, index(line, ":") + 1))
      if (key == wanted_key) {
        print value
        found = 1
        exit
      }
      next
    }
  ' "$config_file"
}

if [[ $# -lt 1 ]]; then
  die_usage
fi

subcommand=$1
shift

case "$subcommand" in
  screenshot|record) ;;
  -h|--help)
    usage
    exit 0
    ;;
  *) die_usage ;;
esac

device="booted"
duration="30"
duration_explicit=0
output=""
command_output=""
record_log=""
flow_status_file=""
screen_name=""
flow_name=""
full_page=0
config_file="${PWD}/.ios-capture-flows.yml"

cleanup() {
  if [[ -n "$record_log" && -f "$record_log" ]]; then
    rm -f "$record_log"
  fi
  if [[ -n "$flow_status_file" && -f "$flow_status_file" ]]; then
    rm -f "$flow_status_file"
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
      require_positive_integer "$duration"
      duration_explicit=1
      shift 2
      ;;
    --screen)
      [[ "$subcommand" == "screenshot" ]] || die_usage
      [[ $# -ge 2 ]] || die_usage
      screen_name=$2
      [[ -n "$screen_name" ]] || die_usage
      shift 2
      ;;
    --flow)
      [[ "$subcommand" == "record" ]] || die_usage
      [[ $# -ge 2 ]] || die_usage
      flow_name=$2
      [[ -n "$flow_name" ]] || die_usage
      shift 2
      ;;
    --full-page)
      [[ "$subcommand" == "screenshot" ]] || die_usage
      full_page=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die_usage
      ;;
  esac
done

if [[ "$full_page" -eq 1 && -z "$screen_name" ]]; then
  die_usage
fi

if [[ -n "$screen_name" || -n "$flow_name" ]]; then
  if [[ ! -f "$config_file" ]]; then
    die "Named screens/flows require a repo-local .ios-capture-flows.yml file."
  fi
fi

if ! command -v xcrun >/dev/null 2>&1; then
  die "xcrun not found. Install Xcode Command Line Tools: xcode-select --install"
fi

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
elif [[ -d "$output" || "$output" == */ ]]; then
  output_dir_target=${output%/}
  if [[ -z "$output_dir_target" ]]; then
    output_dir_target="/"
  fi
  mkdir -p "$output_dir_target"
  output="${output_dir_target}/${default_name}"
fi

output_dir=$(dirname "$output")
output_base=$(basename "$output")

if [[ ! -d "$output_dir" ]]; then
  mkdir -p "$output_dir"
fi

abs_output_dir=$(cd "$output_dir" && pwd -P)
abs_output="${abs_output_dir}/${output_base}"

if [[ "$device" == "booted" ]] && ! xcrun simctl list devices booted 2>/dev/null | grep -q "(Booted)"; then
  die "No simulator is currently booted. Boot a simulator first: xcrun simctl boot <UDID>."
fi

capture_visible_screenshot() {
  screenshot_output=$1
  set +e
  command_output=$(xcrun simctl io "$device" screenshot "$screenshot_output" 2>&1)
  command_status=$?
  set -e

  if [[ "$command_status" -ne 0 ]]; then
    if [[ -n "$command_output" ]]; then
      printf '%s\n' "$command_output" >&2
    fi
    exit "$command_status"
  fi
}

stop_recording() {
  record_pid=$1
  if kill -0 "$record_pid" >/dev/null 2>&1; then
    kill -INT "$record_pid" >/dev/null 2>&1 || true

    # Some macOS shell/process combinations do not exit promptly on SIGINT
    # in non-interactive background jobs. Prefer INT so simctl can finalize
    # the movie cleanly, then escalate so the wrapper never hangs forever.
    shutdown_wait=0
    while kill -0 "$record_pid" >/dev/null 2>&1 && [[ "$shutdown_wait" -lt 5 ]]; do
      sleep 1
      shutdown_wait=$((shutdown_wait + 1))
    done
    if kill -0 "$record_pid" >/dev/null 2>&1; then
      kill -TERM "$record_pid" >/dev/null 2>&1 || true
      sleep 1
    fi
    if kill -0 "$record_pid" >/dev/null 2>&1; then
      kill -KILL "$record_pid" >/dev/null 2>&1 || true
    fi
  fi
}

start_recording() {
  record_log=$(mktemp "${TMPDIR:-/tmp}/ios-simulator-capture.XXXXXX")
  (
    trap - INT
    exec xcrun simctl io "$device" recordVideo "$abs_output"
  ) >"$record_log" 2>&1 &
  record_pid=$!
}

finish_recording() {
  stopped_by_timer=$1
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
}

run_timed_recording() {
  start_recording

  elapsed=0
  stopped_by_timer=0
  while kill -0 "$record_pid" >/dev/null 2>&1 && [[ "$elapsed" -lt "$duration" ]]; do
    sleep 1
    elapsed=$((elapsed + 1))
  done

  if kill -0 "$record_pid" >/dev/null 2>&1; then
    stop_recording "$record_pid"
    stopped_by_timer=1
  fi

  finish_recording "$stopped_by_timer"
}

run_flow_recording() {
  flow_command=$1
  start_recording

  flow_status_file=$(mktemp "${TMPDIR:-/tmp}/ios-simulator-capture-flow.XXXXXX")
  rm -f "$flow_status_file"
  (
    set +e
    bash -c "$flow_command" >&2
    printf '%s\n' "$?" > "$flow_status_file"
  ) &
  flow_pid=$!

  elapsed=0
  stopped_by_timer=0
  flow_stopped_by_timer=0
  while kill -0 "$record_pid" >/dev/null 2>&1 && [[ ! -f "$flow_status_file" ]] && [[ "$elapsed" -lt "$duration" ]]; do
    sleep 1
    elapsed=$((elapsed + 1))
  done

  if kill -0 "$record_pid" >/dev/null 2>&1; then
    stop_recording "$record_pid"
    stopped_by_timer=1
  fi

  if [[ ! -f "$flow_status_file" && "$elapsed" -ge "$duration" ]] && kill -0 "$flow_pid" >/dev/null 2>&1; then
    flow_stopped_by_timer=1
    kill -TERM "$flow_pid" >/dev/null 2>&1 || true
    flow_shutdown_wait=0
    while kill -0 "$flow_pid" >/dev/null 2>&1 && [[ "$flow_shutdown_wait" -lt 5 ]]; do
      sleep 1
      flow_shutdown_wait=$((flow_shutdown_wait + 1))
    done
    if kill -0 "$flow_pid" >/dev/null 2>&1; then
      kill -KILL "$flow_pid" >/dev/null 2>&1 || true
    fi
  fi

  set +e
  wait "$flow_pid"
  wrapper_status=$?
  set -e

  if [[ -f "$flow_status_file" ]]; then
    flow_status=$(cat "$flow_status_file")
  else
    flow_status=$wrapper_status
  fi

  finish_recording "$stopped_by_timer"

  if [[ "$flow_stopped_by_timer" -eq 0 && "$flow_status" -ne 0 ]]; then
    exit "$flow_status"
  fi
}

navigate_to_screen() {
  open_url=$(config_get screens "$screen_name" open_url)
  if [[ -z "$open_url" ]]; then
    die "Screen '$screen_name' was not found or has no open_url in .ios-capture-flows.yml."
  fi

  xcrun simctl openurl "$device" "$open_url"

  screen_wait=$(config_get screens "$screen_name" wait)
  if [[ -n "$screen_wait" ]]; then
    require_nonnegative_integer "$screen_wait"
    sleep "$screen_wait"
  fi
}

run_full_page_screenshot() {
  scrolls=$(config_get screens "$screen_name" full_page.scrolls)
  scroll_command=$(config_get screens "$screen_name" full_page.scroll_command)
  stitch=$(config_get screens "$screen_name" full_page.stitch)

  if [[ -z "$scrolls" ]]; then
    die "Screen '$screen_name' full_page.scrolls is required for --full-page."
  fi
  require_nonnegative_integer "$scrolls"

  if [[ "$scrolls" -gt 0 && -z "$scroll_command" ]]; then
    die "Screen '$screen_name' full_page.scroll_command is required when full_page.scrolls is greater than 0."
  fi

  output_prefix=$abs_output
  case "$output_prefix" in
    *.png) output_prefix=${output_prefix%.png} ;;
  esac

  viewport_paths=()
  first_viewport="${output_prefix}-viewport-0.png"
  capture_visible_screenshot "$first_viewport"
  viewport_paths+=("$first_viewport")

  scroll_index=1
  while [[ "$scroll_index" -le "$scrolls" ]]; do
    bash -c "$scroll_command"
    sleep 1
    viewport_path="${output_prefix}-viewport-${scroll_index}.png"
    capture_visible_screenshot "$viewport_path"
    viewport_paths+=("$viewport_path")
    scroll_index=$((scroll_index + 1))
  done

  if [[ "$stitch" == "true" ]]; then
    if command -v magick >/dev/null 2>&1; then
      magick "${viewport_paths[@]}" -append "$abs_output"
      printf '%s\n' "$abs_output"
    else
      printf '%s\n' "Error: magick not found. Install ImageMagick with: brew install imagemagick" >&2
      printf '%s\n' "Stitching skipped; saved individual viewport screenshots:" >&2
      printf '  %s\n' "${viewport_paths[@]}" >&2
      printf '%s\n' "${viewport_paths[@]}"
    fi
  else
    printf '%s\n' "${viewport_paths[@]}"
  fi
}

case "$subcommand" in
  screenshot)
    if [[ -n "$screen_name" ]]; then
      navigate_to_screen
    fi

    if [[ "$full_page" -eq 1 ]]; then
      run_full_page_screenshot
    else
      capture_visible_screenshot "$abs_output"
      echo "$abs_output"
    fi
    ;;
  record)
    if [[ -n "$flow_name" ]]; then
      flow_command=$(config_get flows "$flow_name" command)
      if [[ -z "$flow_command" ]]; then
        die "Flow '$flow_name' was not found or has no command in .ios-capture-flows.yml."
      fi

      flow_duration=$(config_get flows "$flow_name" duration)
      if [[ "$duration_explicit" -eq 0 && -n "$flow_duration" ]]; then
        duration=$flow_duration
        require_positive_integer "$duration"
      fi

      run_flow_recording "$flow_command"
    else
      run_timed_recording
    fi
    echo "$abs_output"
    ;;
esac
