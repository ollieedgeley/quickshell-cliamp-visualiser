#!/usr/bin/env bash

set -o pipefail

test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(cd "$test_dir/.." && pwd)
output=$(PLUGIN_ROOT="$plugin_root" timeout 2 quickshell -p "$test_dir/mode-follow" 2>&1)
printf '%s\n' "$output"

if grep -q 'MODE_FOLLOW_PASS' <<<"$output"; then
  exit 0
fi

exit 1
