#!/usr/bin/env bash

set -o pipefail

test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(cd "$test_dir/.." && pwd)
output_image=${1:-/tmp/cliamp-color-render.png}

rm -f "$output_image"
output=$(QT_QPA_PLATFORM=offscreen \
  PLUGIN_ROOT="$plugin_root" \
  COLOR_RENDER_OUTPUT="$output_image" \
  timeout 3 quickshell -p "$test_dir/color-render" 2>&1)
printf '%s\n' "$output"

if [[ ! -s "$output_image" ]] || ! grep -q 'COLOR_RENDER_SAVED' <<<"$output"; then
  exit 1
fi

histogram=$(magick "$output_image" -format %c histogram:info:-)

for color in '#00FF00' '#FFFF00' '#FF0000'; do
  if ! grep -q "$color" <<<"$histogram"; then
    exit 1
  fi
  printf 'COLOR_RENDER_PASS %s\n' "$color"
done
