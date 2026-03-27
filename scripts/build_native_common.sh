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

ensure_rust_targets() {
  require_command rustup
  rustup target add "$@" >/dev/null
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
