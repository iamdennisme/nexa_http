#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build_native_common.sh"

parse_native_build_args "$@"
validate_requested_targets aarch64-apple-darwin x86_64-apple-darwin
PACKAGE_ROOT="${REPO_ROOT}/packages/nexa_http_native_macos"
RUST_CRATE_DIR="${PACKAGE_ROOT}/native/nexa_http_native_macos_ffi"
CARGO_MANIFEST_PATH="${RUST_CRATE_DIR}/Cargo.toml"

if [[ "${OSTYPE:-}" != darwin* ]]; then
  die 'macOS build must run on a macOS host.'
fi

require_command cargo
configure_macos_sdk_env
ensure_rust_targets "${TARGETS[@]}"

for target in "${TARGETS[@]}"; do
  build_args=(build --manifest-path "${CARGO_MANIFEST_PATH}" --target "${target}")
  if [[ "${PROFILE}" == 'release' ]]; then
    build_args+=(--release)
  fi
  log "Building macOS native library (${target}, ${PROFILE})"
  cargo "${build_args[@]}"
  source_file="${WORKSPACE_CARGO_TARGET_DIR}/${target}/${PROFILE}/libnexa_http_native_macos_ffi.dylib"
  [[ -f "${source_file}" ]] || die "Expected output not found: ${source_file}"
  case "${target}" in
    aarch64-apple-darwin) output_name='nexa_http-native-macos-arm64.dylib' ;;
    x86_64-apple-darwin) output_name='nexa_http-native-macos-x64.dylib' ;;
  esac
  atomic_copy "${source_file}" "${OUTPUT_DIR}/${output_name}"
done

log "Prepared macOS native libraries in ${OUTPUT_DIR}"
