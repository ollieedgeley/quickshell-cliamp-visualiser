#!/usr/bin/env bash

set -o pipefail

test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(cd "$test_dir/.." && pwd)
output=$(PLUGIN_ROOT="$plugin_root" timeout 3 quickshell -p "$test_dir/interactions" 2>&1)
printf '%s\n' "$output"

grep -q 'INTERACTION_PASS' <<<"$output"
