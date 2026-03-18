#!/usr/bin/env bash
set -euo pipefail

PROXY_BASE_URL="${RUST_NET_PROXY_BASE_URL:-http://127.0.0.1:8081}"

log() {
  printf '%s\n' "$1"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'smoke test failed: %s\nexpected to find: %s\nactual: %s\n' "$label" "$needle" "$haystack" >&2
    exit 1
  fi
}

assert_status() {
  local expected="$1"
  local url="$2"
  local label="$3"
  local actual
  actual="$(curl -sS -o /tmp/rust_net_smoke_body.$$ -w '%{http_code}' "$url")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'smoke test failed: %s\nexpected status: %s\nactual status: %s\n' "$label" "$expected" "$actual" >&2
    printf 'body: %s\n' "$(cat /tmp/rust_net_smoke_body.$$)" >&2
    rm -f /tmp/rust_net_smoke_body.$$
    exit 1
  fi
  rm -f /tmp/rust_net_smoke_body.$$
}

log "Running proxy smoke checks against ${PROXY_BASE_URL}"

healthz_body="$(curl -sS "${PROXY_BASE_URL}/healthz")"
assert_contains "$healthz_body" "ok" "GET /healthz"

get_body="$(curl -sS "${PROXY_BASE_URL}/get?source=smoke")"
assert_contains "$get_body" '"source":"smoke"' "GET /get"

post_body="$(curl -sS -X POST "${PROXY_BASE_URL}/echo" -H 'content-type: application/json' --data '{"hello":"post"}')"
assert_contains "$post_body" '"hello":"post"' "POST /echo"

put_body="$(curl -sS -X PUT "${PROXY_BASE_URL}/echo" -H 'content-type: application/json' --data '{"hello":"put"}')"
assert_contains "$put_body" '"hello":"put"' "PUT /echo"

patch_body="$(curl -sS -X PATCH "${PROXY_BASE_URL}/echo" -H 'content-type: application/json' --data '{"hello":"patch"}')"
assert_contains "$patch_body" '"hello":"patch"' "PATCH /echo"

delete_body="$(curl -sS -X DELETE "${PROXY_BASE_URL}/delete")"
assert_contains "$delete_body" '"deleted":true' "DELETE /delete"

head_headers="$(curl -sSI "${PROXY_BASE_URL}/head")"
assert_contains "$head_headers" 'HTTP/1.1 200 OK' "HEAD /head"
assert_contains "$head_headers" 'X-Fixture-Head: true' "HEAD /head header"

options_headers="$(curl -sSI -X OPTIONS "${PROXY_BASE_URL}/options")"
assert_contains "$options_headers" 'HTTP/1.1 204 No Content' "OPTIONS /options"
assert_contains "$options_headers" 'Allow: GET,POST,PUT,PATCH,DELETE,HEAD,OPTIONS' "OPTIONS /options allow header"

for status in 200 201 202 204 400 401 403 404 429 500 502 503; do
  assert_status "$status" "${PROXY_BASE_URL}/status/${status}" "GET /status/${status}"
done

redirect_body="$(curl -sS -L "${PROXY_BASE_URL}/redirect/302?location=/get?source=smoke_redirect")"
assert_contains "$redirect_body" '"source":"smoke_redirect"' "GET /redirect/302"

for status in 301 303 307 308; do
  redirect_status_body="$(curl -sS -L "${PROXY_BASE_URL}/redirect/${status}?location=/get?source=redirect_${status}")"
  assert_contains "$redirect_status_body" "\"source\":\"redirect_${status}\"" "GET /redirect/${status}"
done

log "Proxy smoke checks passed."
