#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build_native_common.sh"

PROFILE="$(normalize_profile "${1:-release}")"

if [[ "${OSTYPE:-}" != linux* ]]; then
  die 'Linux build must run on a Linux host.'
fi

require_command cargo

build_args=(
  build
  --manifest-path
  "${CARGO_MANIFEST_PATH}"
)
if [[ "${PROFILE}" == 'release' ]]; then
  build_args+=(--release)
fi

log "Building Linux native library (${PROFILE})"
cargo "${build_args[@]}"

source_file="${RUST_CRATE_DIR}/target/${PROFILE}/librust_net_native.so"
[[ -f "${source_file}" ]] || die "Expected output not found: ${source_file}"

destination_dir="${WORKSPACE_ROOT}/packages/rust_net_native_linux/linux/Libraries"
mkdir -p "${destination_dir}"
cp "${source_file}" "${destination_dir}/librust_net_native.so"

log "Prepared ${destination_dir}/librust_net_native.so"
