## Context

The archived FFI-overhead change removed the largest Rust-side costs from the Flutter-to-Rust bridge, but two smaller hot-path inefficiencies remain in the request path.

Today:

- `NexaHttpTransportSession` opens a native client lease with default headers and fallback timeout values, and Rust stores those defaults in the `reqwest::Client`.
- `NativeHttpRequestMapper` still merges the same default headers and fallback timeout into every request DTO before FFI encoding.
- `RequestBody.bytes()` defensively materializes an immutable Dart copy, and FFI dispatch then copies those bytes again into a native-owned transfer buffer before Rust adopts ownership.

This means the request path still performs avoidable Dart work even though the native side already has the state needed to apply defaults and the existing ownership-transfer path can already accept native-owned body buffers.

## Goals / Non-Goals

**Goals:**
- Make native client config the single source of truth for client-level default headers and fallback timeout behavior.
- Keep request-level overrides explicit so per-request behavior remains unchanged.
- Introduce an internal bridge path that can hand request bytes to the FFI encoder without an extra Dart-side materialization step.
- Preserve the existing public `NexaHttpClient`, `Request`, and `Response` API behavior.

**Non-Goals:**
- Add streaming request bodies.
- Redesign the public request-body API around ownership types.
- Revisit response-body ownership; that path was already optimized in the previous change.
- Remove all UTF-8 string allocation from the bridge.

## Decisions

### 1. Treat native client config as the only fallback source for default headers and timeout

`createClient()` already sends default headers and timeout into the native lease, and Rust already applies those values when building the shared `reqwest::Client`. The bridge will stop copying those same defaults into every request DTO. The request DTO will only carry:

- request-specific headers
- request-specific timeout override
- request-specific method, URL, and body

Why:
- It removes redundant header merging, UTF-8 encoding, and FFI transport on every request.
- It tightens responsibility boundaries: client defaults belong to the lease, request DTOs describe request-local state.

Alternative considered:
- Keep the current double-expression of defaults for explicitness.

Why not:
- It preserves hot-path work without adding behavior the native client cannot already supply.

### 2. Keep request-level timeout optional and interpret absence as \"use client default\"

The current ABI already distinguishes `has_timeout = 0` from a concrete timeout value. The bridge will use that distinction to represent three cases cleanly:

- request override present: send that timeout
- no request override: omit timeout from the request args
- client default: remain on the native client lease only

Why:
- It avoids sending the same timeout twice while preserving the current public API semantics.

Alternative considered:
- Resolve the effective timeout entirely on the Dart side and always send a concrete request timeout.

Why not:
- That keeps the redundancy and prevents the native lease from being the authoritative config holder.

### 3. Add an internal owned-bytes path for request-body transfer

The bridge will keep the current safe public behavior, but internally it should support a request body representation that can skip the extra `List<int>.unmodifiable(...)` materialization when the caller already provides stable owned bytes. The FFI encoder still performs the one required copy into native-owned transfer memory, and Rust continues adopting that native buffer without cloning.

Why:
- Dart cannot safely expose GC-managed request bytes directly to async native execution.
- One Dart-to-native copy remains necessary, but the current pre-copy in `RequestBody.bytes()` is not always necessary.

Alternative considered:
- Make the public `RequestBody` API ownership-aware.

Why not:
- It expands public API surface for an optimization that is still bridge-internal.

### 4. Validate behavior with targeted request-path regression tests

The change should add focused tests around:

- request DTOs excluding lease-level defaults
- request-specific headers still overriding native defaults
- request-specific timeout override still winning over client default
- lower-copy request body path preserving bytes and ownership semantics

Why:
- The main risk is semantic drift while removing redundant transport.

## Risks / Trade-offs

- [Lease defaults and request DTO semantics drift apart] → Mitigation: add explicit tests for default-header fallback and per-request override precedence.
- [Internal low-copy body path leaks mutability assumptions] → Mitigation: keep it internal, document ownership expectations, and preserve public immutable behavior.
- [Bridge code becomes harder to follow because defaults move out of request mapping] → Mitigation: document the single-source-of-truth rule in request mapper and native lease setup.

## Migration Plan

1. Update request mapping so DTOs stop re-emitting lease-level defaults.
2. Adjust native execution tests to confirm request-local overrides still behave correctly with client defaults applied only at lease creation.
3. Introduce the internal low-copy request-body representation and route the FFI encoder through it.
4. Regenerate bindings only if the request ABI needs to change; otherwise keep the ABI stable.
5. Run Dart and Rust request-path tests before applying the change.

Rollback is straightforward because the old behavior is isolated to request mapping and body materialization helpers. Reverting those changes restores the previous double-expression path without affecting the public API.

## Open Questions

- None.
