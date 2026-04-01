## Context

The Rust native transport implementation already separates a shared core crate from per-platform FFI crates, but proxy refresh ownership is still soft. Each platform crate currently owns the same runtime concerns: proxy snapshot storage, generation tracking, background refresh threading, and update coordination. Only the platform-specific proxy acquisition logic actually differs.

This duplication creates two problems. First, ownership is unclear because platform crates are acting as both platform adapters and runtime managers. Second, behavior and performance can drift across platforms because each crate evolves its own refresh loop. The current Android implementation demonstrates that risk by using frequent polling plus repeated subprocess calls for proxy discovery, which is disproportionately expensive for a mobile runtime.

This change needs a design because it touches multiple Rust crates, changes internal runtime composition, and must improve performance-sensitive behavior without altering the public FFI surface.

## Goals / Non-Goals

**Goals:**
- Move proxy refresh coordination into shared Rust runtime primitives inside `nexa_http_native_core`.
- Keep platform-specific proxy acquisition inside each platform FFI crate behind an explicit source interface.
- Support platform-aware refresh policy so platforms can declare whether proxy state is static or polled and at what cadence.
- Preserve existing FFI exports and client behavior while tightening internal ownership boundaries.
- Create room to reduce unnecessary background work, especially on Android, without forcing every platform into the same acquisition mechanism.

**Non-Goals:**
- Redesign the full Rust HTTP executor or request pipeline.
- Change the public C ABI exposed by platform FFI crates.
- Standardize all platforms on a single proxy acquisition mechanism.
- Introduce event-driven proxy notifications in this step if a platform does not already provide them.

## Decisions

### 1. Shared core owns proxy refresh coordination

`nexa_http_native_core` will own the runtime-side proxy state machine: cached snapshot, generation counter, current runtime view, and refresh coordination.

Alternative considered:
- Leave each platform crate responsible for its own `ProxyRuntimeState`.

Why not:
- The duplicated state machine does not encode platform-specific behavior. Keeping it in each platform crate preserves copy-pasted ownership and makes behavior drift likely.

### 2. Platform crates provide proxy facts through an explicit source interface

Each platform crate will implement a source abstraction responsible only for acquiring current proxy settings and declaring its refresh mode. The source will not own request client rebuild rules, concurrency, or runtime caching.

Alternative considered:
- Move all proxy detection logic into shared core.

Why not:
- The acquisition path is platform-specific by nature and depends on different system APIs and cost models.

### 3. Refresh policy is platform-aware, but coordination is shared

The shared runtime will react to a platform-declared refresh mode such as `Static` or `Polling { interval }`. This keeps the runtime reaction path uniform while allowing different platforms to choose different acquisition strategies and cadences.

Alternative considered:
- Keep one fixed global polling interval for every platform.

Why not:
- Platform acquisition cost differs materially. A fixed cadence either wastes work on expensive platforms or delays updates on cheap ones.

### 4. FFI crates become assembly layers, not runtime owners

Per-platform `lib.rs` files should primarily expose the ABI and assemble a shared runtime with a platform source. Platform-specific parsing and system calls may live in adjacent modules such as `proxy_source.rs`, but runtime state management should not remain in the FFI entrypoint.

Alternative considered:
- Keep current `lib.rs` structure and only tune the Android interval.

Why not:
- It addresses one symptom but preserves the weak ownership boundary that caused the issue.

### 5. Android polling cost should be reduced as part of the refactor

The first application of the new boundary will be lowering Android background proxy refresh cost by replacing the current aggressive fixed polling assumption with a platform-defined policy that can use a slower or otherwise bounded cadence.

Alternative considered:
- Refactor ownership first and defer Android policy changes entirely.

Why not:
- The current Android behavior is already an unreasonable runtime cost and should be corrected while the ownership seam is open.

## Risks / Trade-offs

- [Shared runtime abstractions become too generic] → Mitigation: keep the source interface narrow and centered only on proxy acquisition plus refresh mode.
- [Refactor changes proxy refresh timing on some platforms] → Mitigation: preserve existing behavior by default where reasonable and lock the intended policy in tests.
- [Android policy tuning may miss edge cases where proxy changes must be observed faster] → Mitigation: choose a bounded but conservative polling policy first and validate with targeted proxy refresh tests.
- [Moving state management into core increases coupling between runtime and platform modules] → Mitigation: keep platform-specific code behind trait boundaries and avoid leaking OS-specific types into shared runtime modules.

## Migration Plan

1. Introduce a shared proxy source trait and managed proxy runtime state in `nexa_http_native_core`.
2. Update one platform crate at a time to replace local proxy runtime state with the shared managed state while preserving existing FFI exports.
3. Move platform-specific proxy acquisition logic into dedicated source modules so `lib.rs` becomes a thin assembly layer.
4. Adjust Android refresh policy to a platform-defined bounded cadence and add tests that lock the intended behavior.
5. Re-run core and per-platform Rust tests to confirm proxy parsing, refresh, and client rebuild behavior remain correct.

Rollback is straightforward because the public FFI surface stays stable. If the shared runtime abstraction causes regressions, an individual platform crate can temporarily revert to its prior local state management without changing the external ABI.

## Open Questions

- Should the first shared refresh-mode abstraction support only `Static` and `Polling`, or should it reserve a shape for future externally triggered refresh without implementing it yet?
- What Android polling interval is conservative enough to reduce background cost materially without surprising users who change proxy settings during app lifetime?
