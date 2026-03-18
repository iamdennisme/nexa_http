#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build_native_common.sh"

PROFILE="$(normalize_profile "${1:-release}")"
TARGET='x86_64-pc-windows-gnu'

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

source_file="${RUST_CRATE_DIR}/target/${TARGET}/${PROFILE}/rust_net_native.dll"
[[ -f "${source_file}" ]] || die "Expected output not found: ${source_file}"

destination_dir="${PACKAGE_ROOT}/windows/Libraries"
mkdir -p "${destination_dir}"
cp "${source_file}" "${destination_dir}/rust_net_native.dll"

log "Prepared ${destination_dir}/rust_net_native.dll"
