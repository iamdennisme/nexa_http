#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="${1:-release}"

platform_scripts=(
  build_native_linux.sh
  build_native_macos.sh
  build_native_android.sh
  build_native_ios.sh
  build_native_windows.sh
)

for platform_script in "${platform_scripts[@]}"; do
  "${SCRIPT_DIR}/${platform_script}" "${PROFILE}"
done

printf '[rust_net build] Completed all platform builds (%s)\n' "${PROFILE}"
