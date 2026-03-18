#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build_native_common.sh"

PROFILE="$(normalize_profile "${1:-release}")"

if [[ "${OSTYPE:-}" != darwin* ]]; then
  die 'iOS build must run on a macOS host.'
fi

require_command cargo
require_command rustup

targets=(
  'aarch64-apple-ios|librust_net_native-ios-arm64.dylib'
  'aarch64-apple-ios-sim|librust_net_native-ios-sim-arm64.dylib'
  'x86_64-apple-ios|librust_net_native-ios-sim-x64.dylib'
)

ensure_rust_targets aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

destination_dir="${PACKAGE_ROOT}/ios/Frameworks"
mkdir -p "${destination_dir}"

for entry in "${targets[@]}"; do
  IFS='|' read -r triple output_name <<<"${entry}"
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

  source_file="${RUST_CRATE_DIR}/target/${triple}/${PROFILE}/librust_net_native.dylib"
  [[ -f "${source_file}" ]] || die "Expected output not found: ${source_file}"
  cp "${source_file}" "${destination_dir}/${output_name}"
done

log "Prepared iOS native libraries in ${destination_dir}"
