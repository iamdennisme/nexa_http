#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build_native_common.sh"

PROFILE="$(normalize_profile "${1:-release}")"
TARGET='x86_64-unknown-linux-gnu'

require_command cargo
require_command rustup

ensure_rust_targets "${TARGET}"

build_tool=(cargo build)
if cargo zigbuild --help >/dev/null 2>&1; then
  require_command zig
  build_tool=(cargo zigbuild)
elif [[ "${OSTYPE:-}" != linux* ]]; then
  die 'Cross-building Linux from non-Linux host requires cargo-zigbuild and zig.'
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

log "Building Linux native library (${TARGET}, ${PROFILE})"
"${build_tool[@]}" "${build_args[@]}"

source_file="${RUST_CRATE_DIR}/target/${TARGET}/${PROFILE}/librust_net_native.so"
[[ -f "${source_file}" ]] || die "Expected output not found: ${source_file}"

destination_dir="${PACKAGE_ROOT}/linux/Libraries"
mkdir -p "${destination_dir}"
cp "${source_file}" "${destination_dir}/librust_net_native.so"

log "Prepared ${destination_dir}/librust_net_native.so"
