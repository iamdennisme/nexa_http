## Context

The current bridge already uses one async FFI request pipeline, but the data model and ownership rules still leave unnecessary work in the path between Flutter and Rust.

Today:

- Dart preserves repeated request headers, but Rust converts them into `HashMap<String, String>` and drops earlier values.
- Native client creation still serializes config through JSON even though the rest of the request path is structured.
- Request bodies are copied from Dart bytes into FFI memory and then copied again into a Rust-owned `Vec<u8>`.
- Response bodies are read from reqwest and then copied again into `NativeHttpOwnedBody`.
- Native code always sends `final_url`, even when it matches the request URL.
- `Call.cancel()` never reaches native execution once a request has been dispatched.

The affected code crosses Dart request mapping, FFI encoding/decoding, Rust ABI types, runtime execution, and response lifecycle ownership, so this change needs one coordinated design.

## Goals / Non-Goals

**Goals:**
- Preserve repeated request headers and request header order through the full bridge.
- Remove JSON from native client creation.
- Remove one Rust-side request-body copy and one Rust-side response-body copy.
- Stop transporting unchanged final-URL metadata.
- Add request-level native cancellation with single-completion behavior in Dart.

**Non-Goals:**
- Redesign the public `NexaHttpClient`, `Request`, or `Response` APIs.
- Introduce streaming request or response bodies in this change.
- Eliminate all UTF-8 string allocation for headers or URLs.
- Redesign rare error-path payload transport beyond keeping current behavior compatible.

## Decisions

### 1. Use structured native config args instead of JSON for client creation

Add a typed `NexaHttpClientConfigArgs` FFI struct plus default-header entry array and stop calling `nexa_http_client_create` with JSON.

Why:
- Client creation is not the hottest path, but it is still avoidable serialization at the Dart/Rust boundary.
- Keeping both request dispatch and client creation structured makes the ABI internally consistent.

Alternative considered:
- Keep JSON because client creation happens once per lease.

Why not:
- It leaves one unnecessary serialization contract in the bridge and keeps native parsing logic split between structured request args and JSON config.

### 2. Preserve repeated request headers as ordered entries in Rust

Change the Rust request model from `HashMap<String, String>` to `Vec<NativeHttpHeader>` and apply request headers to reqwest in incoming order.

Why:
- The current bridge pays to preserve repeated headers in Dart and FFI, then drops them in Rust.
- This is a semantic bug first and a wasted bridge cost second.

Alternative considered:
- Keep a map and join repeated values into one comma-separated string.

Why not:
- That changes header semantics and still loses the explicit repeated-entry model that Dart already provides.

### 3. Transfer request body ownership through native-allocated buffers

Add a native request-body allocation/free contract so Dart copies request bytes once into native-owned memory before dispatch. After a successful dispatch, Rust adopts that owned buffer without cloning it into a second `Vec<u8>`.

Why:
- Dart cannot safely hand Rust a raw pointer to GC-managed request bytes for async execution.
- A native-owned buffer keeps the one unavoidable Dart-to-native copy while removing the second Rust-side copy.

Alternative considered:
- Keep Dart arena allocation plus Rust `to_vec()`.

Why not:
- It preserves the extra hot-path copy that this change exists to remove.

### 4. Return response bodies through an opaque native owner instead of re-boxing bytes

Extend `NexaHttpBinaryResult` so it can carry `body_ptr`, `body_len`, and an opaque native owner token. Rust keeps the original reqwest body owner alive behind that token, and `nexa_http_binary_result_free` drops it.

Why:
- `reqwest::bytes()` already returns owned response bytes.
- Re-boxing those bytes into `Box<[u8]>` is pure extra work before Dart adopts the final native buffer.

Alternative considered:
- Keep `NativeHttpOwnedBody::from_bytes(bytes.as_ref())`.

Why not:
- It always clones the response payload even though Dart already has a finalizer-based native ownership path.

### 5. Only send final URL when it actually changed

Populate `final_url` in the native success result only when the resolved response URL differs from the original request URL. Dart response mapping reuses the original `Request` when `final_url` is absent.

Why:
- Most successful requests do not redirect.
- Sending unchanged URL text and rebuilding `Request` objects adds traffic and allocations without changing behavior.

Alternative considered:
- Keep always returning `final_url` for uniformity.

Why not:
- The public `Response.finalUrl` already falls back naturally to `request.url`, so the uniform payload is unnecessary.

### 6. Add request-level cancellation as an internal execution contract

Add `nexa_http_client_cancel_request(client_id, request_id)` to the native ABI. Dart tracks the active request id for each executing call, forwards `cancel()` into native code, completes the Dart future with `NexaHttpException(code: 'canceled', ...)`, and frees any late native result without surfacing it.

Rust keeps abort handles for in-flight requests keyed by `(client_id, request_id)` and aborts best-effort work when cancellation arrives.

Why:
- The current `cancel()` only flips a Dart boolean and does not stop native work.
- For large bodies or slow networks, this becomes real wasted CPU, memory, and socket activity.

Alternative considered:
- Make cancellation Dart-only and just ignore late results.

Why not:
- It hides completion from user code but still burns native resources on work the caller no longer wants.

## Risks / Trade-offs

- [Bridge ownership rules become more complex] → Mitigation: add focused ownership/free tests for request buffers, response buffers, and late callback disposal.
- [ABI changes require regeneration across packages] → Mitigation: keep one coordinated header/bindings update and rerun carrier-package tests after regeneration.
- [Cancellation introduces race conditions] → Mitigation: keep one completion authority in Dart pending-request tracking and make late native callbacks idempotently free-only.
- [Final URL omission could accidentally change observable response state] → Mitigation: keep `Response.finalUrl` fallback behavior identical and add redirect/no-redirect mapping tests.

## Migration Plan

1. Update native header/ABI types and regenerate Dart bindings.
2. Implement structured config args plus repeated-header preservation in Rust and Dart bridge code.
3. Introduce native-owned request buffer allocation and response owner-token adoption.
4. Add request-cancel ABI plus Dart-side cancel propagation and late-result disposal.
5. Re-run bridge tests, native tests, and benchmark/demo verification before merging.

Rollback stays straightforward because the previous JSON config path, copied-body path, and no-cancel behavior are all isolated within the bridge layer. If a later step destabilizes the ABI, the repository can revert the bridge/header changes without changing the public Dart API.

## Open Questions

- None.
