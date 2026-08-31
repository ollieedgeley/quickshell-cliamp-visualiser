#!/usr/bin/env bash

set -o pipefail

test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(cd "$test_dir/.." && pwd)
build_dir=$(mktemp -d)
sink_name="cliamp_meter_test_$$"
module_id=
meter_pid=

cleanup() {
  if [[ -n $meter_pid ]]; then
    kill "$meter_pid" 2>/dev/null || true
  fi
  if [[ -n $module_id ]]; then
    pactl unload-module "$module_id" 2>/dev/null || true
  fi
  find "$build_dir" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT

qml_output=$(PLUGIN_ROOT="$plugin_root" timeout 3 quickshell -p "$test_dir/audio-fallback" 2>&1)
printf '%s\n' "$qml_output"
if ! grep -q 'AUDIO_FALLBACK_ROUTING_PASS' <<<"$qml_output"; then
  exit 1
fi

cc -O2 -std=c11 -Wall -Wextra -Werror \
  "$plugin_root/audio-meter.c" \
  $(pkg-config --cflags --libs libpulse-simple) -lm \
  -o "$build_dir/audio-meter"

module_id=$(pactl load-module module-null-sink \
  sink_name="$sink_name" rate=44100 channels=2 \
  channel_map=front-left,front-right)

AUDIO_METER_DEVICE="$sink_name.monitor" \
  "$build_dir/audio-meter" >"$build_dir/output.ndjson" 2>"$build_dir/error.log" &
meter_pid=$!
sleep 0.15

python - "$sink_name" <<'PY'
import math
import struct
import subprocess
import sys

sink = sys.argv[1]
rate = 44100
frames = rate // 2
pcm = bytearray()
for index in range(frames):
    phase = 2 * math.pi * 440 * index / rate
    pcm.extend(struct.pack("<ff", 0.7 * math.sin(phase), 0.07 * math.sin(phase)))

subprocess.run([
    "pacat", "--playback", "--device", sink,
    "--format", "float32le", "--rate", str(rate), "--channels", "2",
], input=pcm, check=True)
PY

for _ in {1..30}; do
  if [[ -s $build_dir/output.ndjson ]]; then
    break
  fi
  sleep 0.05
done

meter_line=$(tail -n 1 "$build_dir/output.ndjson")
printf 'AUDIO_METER_FRAME %s\n' "$meter_line"
if ! jq -e '
  (.levels | length) == 2 and
  (.peaks | length) == 2 and
  .levels[0] > .levels[1] + 0.2 and
  .peaks[0] > .peaks[1] + 0.2
' <<<"$meter_line" >/dev/null; then
  cat "$build_dir/error.log" >&2
  exit 1
fi

meter_rss_kb=$(awk '/^VmRSS:/ { print $2 }' "/proc/$meter_pid/status")
meter_cpu=$(ps -o pcpu= -p "$meter_pid" | xargs)
printf 'AUDIO_METER_RESOURCES rss_kb=%s cpu_percent=%s\n' "$meter_rss_kb" "$meter_cpu"
printf 'AUDIO_METER_CAPTURE_PASS\n'
