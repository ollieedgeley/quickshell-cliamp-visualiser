#!/usr/bin/env bash

set -o pipefail

test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(cd "$test_dir/.." && pwd)
snapshot_dir=/tmp/cliamp-spectrum-palette
mkdir -p "$snapshot_dir"

failures=0
for mode in barsdot barsoutline wave rain sakura scope; do
  output_image="$snapshot_dir/$mode.png"
  if ! QT_QPA_PLATFORM=offscreen \
    PLUGIN_ROOT="$plugin_root" \
    VISUALIZER_MODE="$mode" \
    RENDER_WIDTH=104 \
    RENDER_HEIGHT=26 \
    COLOR_RENDER_OUTPUT="$output_image" \
    timeout 3 quickshell -p "$test_dir/color-render" >/dev/null 2>&1; then
    printf 'SPECTRUM_PALETTE_FAIL %-11s did not render\n' "$mode"
    failures=$((failures + 1))
    continue
  fi

  histogram=$(magick "$output_image" -format %c histogram:info:-)
  missing=""
  for color in '#00FF00' '#FFFF00' '#FF0000'; do
    if ! grep -q "$color" <<<"$histogram"; then
      missing="$missing $color"
    fi
  done

  if [[ -n $missing ]]; then
    printf 'SPECTRUM_PALETTE_FAIL %-11s missing:%s\n' "$mode" "$missing"
    failures=$((failures + 1))
  else
    printf 'SPECTRUM_PALETTE_PASS %s\n' "$mode"
  fi
done

if ((failures > 0)); then
  printf 'SPECTRUM_PALETTE_RESULT FAIL failures=%d\n' "$failures"
  exit 1
fi

printf 'SPECTRUM_PALETTE_RESULT PASS\n'
