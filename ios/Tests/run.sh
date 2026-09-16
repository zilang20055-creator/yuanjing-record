#!/bin/bash
set -eu
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/yuanjing-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
swiftc -module-cache-path "$test_dir/cache" "$project_dir/Yuanjing/Models.swift" "$project_dir/Yuanjing/Migration.swift" "$project_dir/Tests/main.swift" -o "$test_dir/domain-tests"
"$test_dir/domain-tests" "$@"
