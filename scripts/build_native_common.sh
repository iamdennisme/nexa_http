#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_ROOT="${REPO_ROOT}"
WORKSPACE_CARGO_TARGET_DIR="${REPO_ROOT}/target"

log() {
  printf '[nexa_http build] %s\n' "$*"
}

die() {
  printf '[nexa_http build] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local command_name="${1:?missing command name}"
  command -v "${command_name}" >/dev/null 2>&1 || die "Missing command: ${command_name}"
}

run_with_timeout() {
  local timeout_seconds="${1:?missing timeout seconds}"
  shift

  local timed_out_file
  timed_out_file="$(mktemp)"
  rm -f "${timed_out_file}"

  "$@" &
  local command_pid=$!
  (
    sleep "${timeout_seconds}"
    if kill -0 "${command_pid}" >/dev/null 2>&1; then
      : >"${timed_out_file}"
      kill "${command_pid}" >/dev/null 2>&1 || true
      sleep 2
      kill -KILL "${command_pid}" >/dev/null 2>&1 || true
    fi
  ) &
  local watchdog_pid=$!

  local exit_code=0
  wait "${command_pid}" || exit_code=$?
  kill "${watchdog_pid}" >/dev/null 2>&1 || true
  wait "${watchdog_pid}" >/dev/null 2>&1 || true

  if [[ -f "${timed_out_file}" ]]; then
    rm -f "${timed_out_file}"
    die "Command timed out after ${timeout_seconds}s: $*"
  fi
  rm -f "${timed_out_file}"

  return "${exit_code}"
}

append_env_flag() {
  local var_name="${1:?missing variable name}"
  local flag="${2:?missing flag}"
  local current_value="${!var_name:-}"
  if [[ -n "${current_value}" ]]; then
    printf -v "${var_name}" '%s %s' "${current_value}" "${flag}"
  else
    printf -v "${var_name}" '%s' "${flag}"
  fi
  export "${var_name}"
}

configure_macos_sdk_env() {
  require_command xcrun

  local sdk_root
  sdk_root="$(xcrun --sdk macosx --show-sdk-path)" || die 'Unable to resolve macOS SDK path with xcrun.'
  [[ -d "${sdk_root}" ]] || die "macOS SDK path does not exist: ${sdk_root}"

  export SDKROOT="${sdk_root}"
  export CC="${CC:-$(xcrun --sdk macosx --find clang)}"
  append_env_flag CFLAGS "-isysroot ${SDKROOT}"
  append_env_flag CXXFLAGS "-isysroot ${SDKROOT}"
}

ensure_rust_targets() {
  require_command rustup

  local installed_targets
  installed_targets="$(rustup target list --installed)"

  local missing_targets=()
  local target
  for target in "$@"; do
    if ! printf '%s\n' "${installed_targets}" | grep -Fx "${target}" >/dev/null; then
      missing_targets+=("${target}")
    fi
  done

  if [[ "${#missing_targets[@]}" -eq 0 ]]; then
    return 0
  fi

  run_with_timeout 600 rustup target add "${missing_targets[@]}" >/dev/null
}

normalize_profile() {
  local profile="${1:-release}"
  case "${profile}" in
    debug|release)
      printf '%s\n' "${profile}"
      ;;
    *)
      die "Unsupported profile \"${profile}\". Use debug or release."
      ;;
  esac
}
