#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build_native_common.sh"

PROFILE="$(normalize_profile "${1:-release}")"

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

source_file="${RUST_CRATE_DIR}/target/${PROFILE}/librust_net_native.dylib"
[[ -f "${source_file}" ]] || die "Expected output not found: ${source_file}"

destination_file="${PACKAGE_ROOT}/macos/Libraries/librust_net_native.dylib"
mkdir -p "$(dirname "${destination_file}")"
cp "${source_file}" "${destination_file}"

log "Prepared ${destination_file}"
