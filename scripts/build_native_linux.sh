#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build_native_common.sh"

PROFILE="$(normalize_profile "${1:-release}")"
TARGET='x86_64-unknown-linux-gnu'
PACKAGE_ROOT="${REPO_ROOT}/packages/nexa_http_native_linux"
RUST_CRATE_DIR="${PACKAGE_ROOT}/native/nexa_http_native_linux_ffi"
CARGO_MANIFEST_PATH="${RUST_CRATE_DIR}/Cargo.toml"

require_command cargo

build_tool=(cargo build)
build_args=(
  --manifest-path
  "${CARGO_MANIFEST_PATH}"
)

if [[ "${OSTYPE:-}" != linux* ]]; then
  if cargo zigbuild --help >/dev/null 2>&1; then
    require_command zig
    build_tool=(cargo zigbuild)
    build_args+=(--target "${TARGET}")
  else
    die 'Cross-building Linux from non-Linux host requires cargo-zigbuild and zig.'
  fi
fi

if [[ "${PROFILE}" == 'release' ]]; then
  build_args+=(--release)
fi

log "Building Linux native library (${PROFILE})"
"${build_tool[@]}" "${build_args[@]}"

source_file="${WORKSPACE_CARGO_TARGET_DIR}/${PROFILE}/libnexa_http_native_linux_ffi.so"
if [[ "${build_tool[1]}" == 'zigbuild' ]]; then
  source_file="${WORKSPACE_CARGO_TARGET_DIR}/${TARGET}/${PROFILE}/libnexa_http_native_linux_ffi.so"
fi
[[ -f "${source_file}" ]] || die "Expected output not found: ${source_file}"

destination_dir="${WORKSPACE_ROOT}/packages/nexa_http_native_linux/linux/Libraries"
mkdir -p "${destination_dir}"
cp "${source_file}" "${destination_dir}/libnexa_http_native.so"

log "Prepared ${destination_dir}/libnexa_http_native.so"
