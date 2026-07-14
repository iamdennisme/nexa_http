#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build_native_common.sh"

parse_native_build_args "$@"
validate_requested_targets aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
PACKAGE_ROOT="${REPO_ROOT}/packages/nexa_http_native_ios"
RUST_CRATE_DIR="${PACKAGE_ROOT}/native/nexa_http_native_ios_ffi"
CARGO_MANIFEST_PATH="${RUST_CRATE_DIR}/Cargo.toml"

if [[ "${OSTYPE:-}" != darwin* ]]; then
  die 'iOS build must run on a macOS host.'
fi

require_command cargo
require_command rustup

ensure_rust_targets "${TARGETS[@]}"

for triple in "${TARGETS[@]}"; do
  case "${triple}" in
    aarch64-apple-ios) output_name='nexa_http-native-ios-arm64.dylib' ;;
    aarch64-apple-ios-sim) output_name='nexa_http-native-ios-sim-arm64.dylib' ;;
    x86_64-apple-ios) output_name='nexa_http-native-ios-sim-x64.dylib' ;;
  esac
  build_args=(
    build
    --manifest-path
    "${CARGO_MANIFEST_PATH}"
    --target
    "${triple}"
  )
  if [[ "${PROFILE}" == 'release' ]]; then
    build_args+=(--release)
  fi

  log "Building iOS target ${triple} (${PROFILE})"
  cargo "${build_args[@]}"

  source_file="${WORKSPACE_CARGO_TARGET_DIR}/${triple}/${PROFILE}/libnexa_http_native_ios_ffi.dylib"
  [[ -f "${source_file}" ]] || die "Expected output not found: ${source_file}"
  atomic_copy "${source_file}" "${OUTPUT_DIR}/${output_name}"
done

log "Prepared iOS native libraries in ${OUTPUT_DIR}"
