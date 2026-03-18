#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build_native_common.sh"

PROFILE="$(normalize_profile "${1:-release}")"
ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-21}"

require_command cargo
require_command rustup

resolve_android_ndk_dir() {
  local candidate
  for candidate in "${ANDROID_NDK_HOME:-}" "${ANDROID_NDK_ROOT:-}"; do
    if [[ -n "${candidate}" && -d "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  local sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  if [[ -n "${sdk_root}" && -d "${sdk_root}/ndk" ]]; then
    candidate="$(ls -1 "${sdk_root}/ndk" 2>/dev/null | sort -Vr | head -n 1 || true)"
    if [[ -n "${candidate}" && -d "${sdk_root}/ndk/${candidate}" ]]; then
      printf '%s\n' "${sdk_root}/ndk/${candidate}"
      return 0
    fi
  fi

  return 1
}

resolve_ndk_prebuilt_dir() {
  local ndk_dir="${1:?missing ndk dir}"
  local prebuilt_root="${ndk_dir}/toolchains/llvm/prebuilt"
  [[ -d "${prebuilt_root}" ]] || return 1

  local host_prefix
  case "${OSTYPE:-}" in
    darwin*) host_prefix='darwin' ;;
    linux*) host_prefix='linux' ;;
    msys*|cygwin*|win32*) host_prefix='windows' ;;
    *) return 1 ;;
  esac

  local preferred_arch
  preferred_arch="$(uname -m)"

  local candidate
  candidate="$(find "${prebuilt_root}" -mindepth 1 -maxdepth 1 -type d -name "${host_prefix}-*" | sort | grep -E "${preferred_arch}" | head -n 1 || true)"
  if [[ -z "${candidate}" ]]; then
    candidate="$(find "${prebuilt_root}" -mindepth 1 -maxdepth 1 -type d -name "${host_prefix}-*" | sort | head -n 1 || true)"
  fi
  [[ -n "${candidate}" ]] || return 1

  printf '%s\n' "${candidate}"
}

ndk_dir="$(resolve_android_ndk_dir)" || die 'Unable to locate Android NDK. Set ANDROID_NDK_HOME or ANDROID_NDK_ROOT.'
ndk_prebuilt_dir="$(resolve_ndk_prebuilt_dir "${ndk_dir}")" || die "Unable to locate NDK LLVM prebuilt dir in ${ndk_dir}."
llvm_ar="${ndk_prebuilt_dir}/bin/llvm-ar"
[[ -x "${llvm_ar}" ]] || die "Missing llvm-ar: ${llvm_ar}"
llvm_strip="${ndk_prebuilt_dir}/bin/llvm-strip"
[[ -x "${llvm_strip}" ]] || die "Missing llvm-strip: ${llvm_strip}"

targets=(
  'aarch64-linux-android|arm64-v8a|aarch64-linux-android'
  'armv7-linux-androideabi|armeabi-v7a|armv7a-linux-androideabi'
  'x86_64-linux-android|x86_64|x86_64-linux-android'
)

ensure_rust_targets aarch64-linux-android armv7-linux-androideabi x86_64-linux-android

for entry in "${targets[@]}"; do
  IFS='|' read -r triple abi linker_prefix <<<"${entry}"
  linker="${ndk_prebuilt_dir}/bin/${linker_prefix}${ANDROID_API_LEVEL}-clang"
  [[ -x "${linker}" ]] || die "Missing linker: ${linker}"

  cargo_target_env="$(echo "${triple}" | tr '[:lower:]-' '[:upper:]_')"
  cc_env="CC_${triple//-/_}"
  ar_env="AR_${triple//-/_}"

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

  log "Building Android ${abi} (${triple}, ${PROFILE})"
  env \
    "CARGO_TARGET_${cargo_target_env}_LINKER=${linker}" \
    "${cc_env}=${linker}" \
    "${ar_env}=${llvm_ar}" \
    cargo "${build_args[@]}"

  source_file="${RUST_CRATE_DIR}/target/${triple}/${PROFILE}/librust_net_native.so"
  [[ -f "${source_file}" ]] || die "Expected output not found: ${source_file}"

  destination_dir="${PACKAGE_ROOT}/android/src/main/jniLibs/${abi}"
  mkdir -p "${destination_dir}"
  cp "${source_file}" "${destination_dir}/librust_net_native.so"
  "${llvm_strip}" --strip-unneeded "${destination_dir}/librust_net_native.so"
done

log 'Prepared Android native libraries in packages/rust_net/android/src/main/jniLibs'
