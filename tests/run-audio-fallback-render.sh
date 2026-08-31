#!/usr/bin/env bash

set -o pipefail

test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=${PLUGIN_ROOT:-$(cd "$test_dir/.." && pwd)}
output_image=${1:-/tmp/cliamp-audio-fallback.png}
sink_name="cliamp_meter_render_$$"
module_id=
player_pid=

cleanup() {
  if [[ -n $player_pid ]]; then
    kill "$player_pid" 2>/dev/null || true
  fi
  if [[ -n $module_id ]]; then
    pactl unload-module "$module_id" 2>/dev/null || true
  fi
}
trap cleanup EXIT

module_id=$(pactl load-module module-null-sink \
  sink_name="$sink_name" rate=44100 channels=2 \
  channel_map=front-left,front-right)

python - "$sink_name" <<'PY' &
import math
import struct
import subprocess
import sys
import time

time.sleep(0.2)
sink = sys.argv[1]
rate = 44100
frames = rate * 2
pcm = bytearray()
for index in range(frames):
    phase = 2 * math.pi * 220 * index / rate
    pcm.extend(struct.pack("<ff", 0.75 * math.sin(phase), 0.06 * math.sin(phase)))

subprocess.run([
    "pacat", "--playback", "--device", sink,
    "--format", "float32le", "--rate", str(rate), "--channels", "2",
], input=pcm, check=True)
PY
player_pid=$!

render_output=$(QT_QPA_PLATFORM=offscreen \
  PLUGIN_ROOT="$plugin_root" \
  AUDIO_METER_DEVICE="$sink_name.monitor" \
  AUDIO_FALLBACK_RENDER_OUTPUT="$output_image" \
  timeout 4 quickshell -p "$test_dir/audio-fallback-render" 2>&1)
printf '%s\n' "$render_output"

if [[ ! -s $output_image ]] || ! grep -q 'AUDIO_FALLBACK_RENDER_PASS' <<<"$render_output"; then
  exit 1
fi
