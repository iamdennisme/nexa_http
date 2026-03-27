#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build_native_common.sh"

PROFILE="$(normalize_profile "${1:-release}")"
PACKAGE_ROOT="${REPO_ROOT}/packages/nexa_http_native_macos"
RUST_CRATE_DIR="${PACKAGE_ROOT}/native/nexa_http_native_macos_ffi"
CARGO_MANIFEST_PATH="${RUST_CRATE_DIR}/Cargo.toml"

if [[ "${OSTYPE:-}" != darwin* ]]; then
  die 'macOS build must run on a macOS host.'
fi

require_command cargo

log "Building macOS native library (${PROFILE})"

build_args=(
  build
  --manifest-path
  "${CARGO_MANIFEST_PATH}"
)
if [[ "${PROFILE}" == 'release' ]]; then
  build_args+=(--release)
fi

cargo "${build_args[@]}"

source_file="${WORKSPACE_CARGO_TARGET_DIR}/${PROFILE}/libnexa_http_native_macos_ffi.dylib"
[[ -f "${source_file}" ]] || die "Expected output not found: ${source_file}"

destination_file="${WORKSPACE_ROOT}/packages/nexa_http_native_macos/macos/Libraries/libnexa_http_native.dylib"
mkdir -p "$(dirname "${destination_file}")"
cp "${source_file}" "${destination_file}"

log "Prepared ${destination_file}"
