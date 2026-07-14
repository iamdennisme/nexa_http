#!/usr/bin/env bash
set -euo pipefail

max_attempts="${1:-60}"

adb wait-for-device
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if adb shell service check package 2>/dev/null | grep -q 'found'; then
    exit 0
  fi
  sleep 2
done

echo 'Android package service did not become ready.' >&2
exit 1
