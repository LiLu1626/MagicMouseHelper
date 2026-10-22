#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT
sdk_dir="$(xcrun --sdk macosx --show-sdk-path)"
xcrun swiftc -sdk "$sdk_dir" -target arm64-apple-macosx27.0 \
  -module-cache-path "$check_dir/cache" -parse-as-library \
  "$repo_dir/MagicMouseHelper/Preferences.swift" \
  "$repo_dir/MagicMouseHelper/MouseEngine.swift" \
  "$repo_dir/Tests/EngineChecks.swift" -o "$check_dir/checks"
"$check_dir/checks"
