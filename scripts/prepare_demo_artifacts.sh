#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build_native_common.sh"

PROFILE="$(normalize_profile "${1:-debug}")"

remove_if_exists() {
  local target="${1:?missing target path}"
  if [[ -e "${target}" ]]; then
    rm -rf "${target}"
  fi
}

log "Cleaning previously prepared demo artifacts (${PROFILE})"

remove_if_exists "${WORKSPACE_ROOT}/packages/nexa_http_native_android/android/src/main/jniLibs"
remove_if_exists "${WORKSPACE_ROOT}/packages/nexa_http_native_ios/ios/Frameworks"
remove_if_exists "${WORKSPACE_ROOT}/packages/nexa_http_native_macos/macos/Libraries"
remove_if_exists "${WORKSPACE_ROOT}/packages/nexa_http_native_windows/windows/Libraries"

case "${OSTYPE:-}" in
  darwin*)
    "${WORKSPACE_ROOT}/scripts/build_native_macos.sh" "${PROFILE}"
    "${WORKSPACE_ROOT}/scripts/build_native_ios.sh" "${PROFILE}"
    ;;
  linux*)
    "${WORKSPACE_ROOT}/scripts/build_native_android.sh" "${PROFILE}"
    ;;
  msys*|cygwin*|win32*)
    "${WORKSPACE_ROOT}/scripts/build_native_windows.sh" "${PROFILE}"
    ;;
  *)
    die "Unsupported host OS for demo artifact preparation: ${OSTYPE:-unknown}"
    ;;
esac

log "Prepared fresh demo artifacts (${PROFILE})"
