#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build_native_common.sh"

PROFILE="$(normalize_profile "${1:-release}")"
TARGET='x86_64-pc-windows-gnu'
PACKAGE_ROOT="${REPO_ROOT}/packages/nexa_http_native_windows"
RUST_CRATE_DIR="${PACKAGE_ROOT}/native/nexa_http_native_windows_ffi"
CARGO_MANIFEST_PATH="${RUST_CRATE_DIR}/Cargo.toml"

require_command cargo
require_command rustup

ensure_rust_targets "${TARGET}"

build_tool=(cargo build)
if cargo zigbuild --help >/dev/null 2>&1; then
  require_command zig
  build_tool=(cargo zigbuild)
elif [[ "${OSTYPE:-}" != msys* && "${OSTYPE:-}" != cygwin* && "${OSTYPE:-}" != win32* ]]; then
  die 'Cross-building Windows from non-Windows host requires cargo-zigbuild and zig.'
fi

build_args=(
  --manifest-path
  "${CARGO_MANIFEST_PATH}"
  --target
  "${TARGET}"
)
if [[ "${PROFILE}" == 'release' ]]; then
  build_args+=(--release)
fi

log "Building Windows native library (${TARGET}, ${PROFILE})"
"${build_tool[@]}" "${build_args[@]}"

source_file="${WORKSPACE_CARGO_TARGET_DIR}/${TARGET}/${PROFILE}/nexa_http_native_windows_ffi.dll"
[[ -f "${source_file}" ]] || die "Expected output not found: ${source_file}"

destination_dir="${WORKSPACE_ROOT}/packages/nexa_http_native_windows/windows/Libraries"
mkdir -p "${destination_dir}"
cp "${source_file}" "${destination_dir}/nexa_http_native.dll"

log "Prepared ${destination_dir}/nexa_http_native.dll"
