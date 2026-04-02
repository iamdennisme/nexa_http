## Context

The previous request-path cleanup removed redundant lease defaults and the largest avoidable copies, but it intentionally preserved the existing public request-body API. That left the bridge in an awkward middle state:

- public `RequestBody` still accepts generic `List<int>` input
- `RequestBody` stores both a public read view and a transport handoff view
- `NativeHttpRequestDto` still presents request bytes as `List<int>?`
- `ClientOptions.defaultHeaderEntries` remains in the codebase even though request mapping no longer consumes it

The transport path is already binary-first in practice. Dart encodes strings into bytes, copies bytes into a native-owned transfer buffer, and Rust adopts that native buffer. The remaining mismatch is that the public Dart API still pretends the boundary is list-shaped and transport-agnostic.

## Goals / Non-Goals

**Goals:**
- Make the request-body API explicitly binary-first.
- Remove dual-view request-body state and transport-aware public accessors.
- Tighten request transport DTOs and encoder inputs to `Uint8List` semantics.
- Delete dead abstractions left behind by earlier request-default cleanup.

**Non-Goals:**
- Add streaming uploads.
- Revisit response-body ownership.
- Change the native request ABI unless the Dart-side cleanup requires it.
- Preserve source compatibility for existing `RequestBody.bytes(List<int>)` or `RequestBody.fromString(...)` callers.

## Decisions

### 1. Make `RequestBody` an owned-binary value type

`RequestBody` will have a single canonical payload representation: an owned `Uint8List`. The public API will stop accepting generic `List<int>` input and stop exposing transport-specific alternate views of the same body.

The intended shape is:

- one canonical constructor or factory that accepts owned binary bytes
- optional explicit text convenience that eagerly encodes to owned bytes
- one body read path backed by the same owned bytes

Why:
- It aligns the public API with the real transport contract.
- It removes the need to maintain separate read and transfer representations.
- It forces callers to make byte ownership explicit at the boundary.

Alternative considered:
- Keep `List<int>` in the public API and only tighten internals.

Why not:
- That preserves the semantic mismatch that caused the current cleanup.

### 2. Remove transport-leaking `RequestBody` accessors

The bridge should not depend on public API objects exposing a separate FFI transfer accessor. Internal request mapping and encoding should consume the canonical owned bytes directly.

This means removing accessors like:

- `bytesValue`
- `ffiTransferBytes`

Why:
- Public API consumers should not need to understand transport handoff details.
- One owned binary payload is enough once compatibility is no longer required.

Alternative considered:
- Keep a hidden second accessor for the bridge.

Why not:
- The bridge can read the same owned bytes without carrying dual-state complexity.

### 3. Tighten request DTOs to explicit binary buffers

`NativeHttpRequestDto.bodyBytes` will move from `List<int>?` to `Uint8List?`. The FFI encoder will operate on binary buffers, not generic lists.

Why:
- It makes the transport contract self-describing.
- It avoids generic list semantics on a hot-path binary payload.
- It reduces ambiguity for tests and future internal optimizations.

Alternative considered:
- Keep `List<int>?` because `Uint8List` implements `List<int>`.

Why not:
- The more generic type hides the ownership and representation assumptions the bridge already relies on.

### 4. Delete stale request-default helper abstractions

`ClientOptions.defaultHeaderEntries` is no longer part of the request path and should be removed rather than kept as dead cache machinery.

Why:
- Dead abstractions make the design look more complicated than it is.
- Leaving them behind risks future code drifting back toward the old double-merge model.

### 5. Treat this as an intentional breaking cleanup

The change will not carry a compatibility shim. Callers that currently pass `List<int>` or rely on `RequestBody.fromString(...)` will need to migrate to the new binary-first API.

Migration expectations:

- callers with binary data must materialize `Uint8List`
- callers with text data must use the new explicit text helper or encode text to bytes before constructing the body
- internal tests and examples must update to the new contract

Why:
- The project has explicitly chosen a breaking upgrade over a long-lived compatibility layer.
- A shim would preserve the same loose semantics this change is meant to remove.

## Risks / Trade-offs

- [Breaking callers that currently hand `List<int>` directly to `RequestBody`] -> Mitigation: document the migration path in proposal, tasks, and final release notes.
- [Removing `fromString(...)` may reduce ergonomics for common JSON/form callers] -> Mitigation: provide one explicit text-to-bytes helper if needed, but keep the binary-first model canonical.
- [Dart tests may overfit to `List<int>` semantics] -> Mitigation: update tests to assert `Uint8List` ownership and identity where relevant.

## Migration Plan

1. Redefine `RequestBody` around one owned `Uint8List` payload and remove transport-specific dual accessors.
2. Update request mapping and FFI request DTOs to consume explicit binary buffers only.
3. Remove stale `ClientOptions.defaultHeaderEntries`.
4. Update examples and tests to the new request-body API.
5. Run Dart and Rust request-path verification to confirm behavior is unchanged apart from the intended source break.

Rollback is straightforward because the change is contained to the Dart-side API, request mapping, and related tests. Reverting restores the previous compatibility surface.

## Open Questions

- Whether the text convenience should be named `utf8`, `text`, or omitted entirely can be decided during implementation, but it must remain a thin wrapper over owned binary bytes rather than a second semantic model.
