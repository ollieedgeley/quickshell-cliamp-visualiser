#!/usr/bin/env bash

set -o pipefail

test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(cd "$test_dir/.." && pwd)
snapshot_dir=/tmp/cliamp-fancy-fidelity
render_width=104
render_height=26
crop_height=7
bottom_y=$((render_height - crop_height))
mkdir -p "$snapshot_dir"

failures=0

render_mode() {
  local mode=$1
  local output_image="$snapshot_dir/$mode.png"

  if ! QT_QPA_PLATFORM=offscreen \
    PLUGIN_ROOT="$plugin_root" \
    VISUALIZER_MODE="$mode" \
    RENDER_WIDTH="$render_width" \
    RENDER_HEIGHT="$render_height" \
    COLOR_RENDER_OUTPUT="$output_image" \
    timeout 3 quickshell -p "$test_dir/color-render" >/dev/null 2>&1; then
    printf 'FANCY_FIDELITY_FAIL %s did not render\n' "$mode"
    failures=$((failures + 1))
  fi
}

trim_width() {
  magick "$1" -alpha extract -threshold 1 -trim -format '%w' info:
}

opacity() {
  if [[ -n $2 ]]; then
    magick "$1" $2 -alpha extract -format '%[fx:mean]' info:
  else
    magick "$1" -alpha extract -format '%[fx:mean]' info:
  fi
}

check_min() {
  local mode=$1
  local trait=$2
  local actual=$3
  local minimum=$4

  if awk -v actual="$actual" -v minimum="$minimum" 'BEGIN { exit !(actual >= minimum) }'; then
    printf 'FANCY_FIDELITY_PASS %-9s %s=%s\n' "$mode" "$trait" "$actual"
  else
    printf 'FANCY_FIDELITY_FAIL %-9s %s=%s expected>=%s\n' "$mode" "$trait" "$actual" "$minimum"
    failures=$((failures + 1))
  fi
}

check_greater() {
  local mode=$1
  local trait=$2
  local greater=$3
  local lesser=$4

  if awk -v greater="$greater" -v lesser="$lesser" 'BEGIN { exit !(greater > lesser) }'; then
    printf 'FANCY_FIDELITY_PASS %-9s %s=%s>%s\n' "$mode" "$trait" "$greater" "$lesser"
  else
    printf 'FANCY_FIDELITY_FAIL %-9s %s=%s expected>%s\n' "$mode" "$trait" "$greater" "$lesser"
    failures=$((failures + 1))
  fi
}

for mode in ascii binary firefly firework flame logo pulse; do
  render_mode "$mode"
done

check_min ascii bottom_density "$(opacity "$snapshot_dir/ascii.png" "-crop ${render_width}x${crop_height}+0+${bottom_y}")" 0.25
check_min binary overall_density "$(opacity "$snapshot_dir/binary.png" '')" 0.06
check_min firefly grass_density "$(opacity "$snapshot_dir/firefly.png" "-crop ${render_width}x${crop_height}+0+${bottom_y}")" 0.15
check_min firework spread "$(trim_width "$snapshot_dir/firework.png")" 55
check_greater flame base_over_tips \
  "$(opacity "$snapshot_dir/flame.png" "-crop ${render_width}x${crop_height}+0+${bottom_y}")" \
  "$(opacity "$snapshot_dir/flame.png" "-crop ${render_width}x${crop_height}+0+0")"
check_min logo span "$(trim_width "$snapshot_dir/logo.png")" 70
check_min logo readable_density "$(opacity "$snapshot_dir/logo.png" '')" 0.045
check_min pulse span "$(trim_width "$snapshot_dir/pulse.png")" 55

if ((failures > 0)); then
  printf 'FANCY_FIDELITY_RESULT FAIL failures=%d\n' "$failures"
  exit 1
fi

printf 'FANCY_FIDELITY_RESULT PASS\n'
