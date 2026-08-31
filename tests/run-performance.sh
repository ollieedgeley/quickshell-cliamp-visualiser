#!/usr/bin/env bash

set -o pipefail

test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(cd "$test_dir/.." && pwd)
mode=${1:-flame}
log_file=$(mktemp)
start_ns=$(date +%s%N)
clock_ticks=$(getconf CLK_TCK)
max_rss_kb=0
last_cpu_ticks=0

QT_QPA_PLATFORM=offscreen \
  PLUGIN_ROOT="$plugin_root" \
  PERF_MODE="$mode" \
  quickshell -p "$test_dir/performance" >"$log_file" 2>&1 &
perf_pid=$!

while kill -0 "$perf_pid" 2>/dev/null; do
  if [[ -r /proc/$perf_pid/status ]]; then
    rss_kb=$(awk '/^VmRSS:/ { print $2 }' "/proc/$perf_pid/status" 2>/dev/null || true)
    if [[ -n $rss_kb ]] && ((rss_kb > max_rss_kb)); then
      max_rss_kb=$rss_kb
    fi
  fi
  if [[ -r /proc/$perf_pid/stat ]]; then
    cpu_ticks=$(awk '{ print $14 + $15 }' "/proc/$perf_pid/stat" 2>/dev/null || true)
    if [[ -n $cpu_ticks ]]; then
      last_cpu_ticks=$cpu_ticks
    fi
  fi
  sleep 0.05
done

wait "$perf_pid"
end_ns=$(date +%s%N)
output=$(<"$log_file")
unlink "$log_file"

elapsed_seconds=$(awk -v start="$start_ns" -v end="$end_ns" 'BEGIN { print (end - start) / 1000000000 }')
cpu_percent=$(awk -v ticks="$last_cpu_ticks" -v hz="$clock_ticks" -v elapsed="$elapsed_seconds" \
  'BEGIN { if (elapsed > 0) printf "%.1f", ticks / hz / elapsed * 100; else print "0.0" }')

printf '%s\n' "$output" | rg 'PERF_RESULT|PERF_SETUP_FAIL' || true
printf 'PERF_RESOURCES peak_rss_kb=%d cpu_percent=%s elapsed_seconds=%s\n' \
  "$max_rss_kb" "$cpu_percent" "$elapsed_seconds"

result=$(grep 'PERF_RESULT' <<<"$output")
paints=$(sed -n 's/.*paints=\([0-9][0-9]*\).*/\1/p' <<<"$result")
feeds=$(sed -n 's/.*feeds=\([0-9][0-9]*\).*/\1/p' <<<"$result")
animation_frames=$(sed -n 's/.*animationFrames=\([0-9][0-9]*\).*/\1/p' <<<"$result")

if [[ -z $paints || -z $feeds || -z $animation_frames ]]; then
  exit 1
fi

if [[ $mode == idle && $animation_frames != 0 ]]; then
  printf 'PERF_IDLE_FAIL animationFrames=%d\n' "$animation_frames"
  exit 1
fi

if ((paints > feeds + 12)); then
  printf 'PERF_SCHEDULING_FAIL paints=%d feeds=%d redundant>%d\n' "$paints" "$feeds" 12
  exit 1
fi

printf 'PERF_SCHEDULING_PASS paints=%d feeds=%d\n' "$paints" "$feeds"
