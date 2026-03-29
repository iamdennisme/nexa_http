# Proxy Runtime State Design

## Context

The current proxy model works, but its responsibility split is not ideal:

- `native core` owns the client lifecycle and also owns proxy refresh probing
- platform runtimes expose only `proxy_settings()`
- Android proxy discovery uses `getprop` with a short cache to reduce cost
- proxy changes are detected by periodic probing instead of platform-driven change tracking

This has two drawbacks:

1. `native core` is carrying platform-refresh policy that should belong to platform runtimes.
2. Runtime refresh is efficient enough for today, but it is still probe-based instead of event-driven.

The design goal is to keep `native core` focused on HTTP execution while moving platform change tracking fully into each `native_<platform>` runtime.

## Goals

- Keep `native core` focused on runtime lifecycle and HTTP execution.
- Remove proxy refresh probing from `native core`.
- Let each platform runtime own proxy discovery, change listening, and refresh policy.
- Make request hot paths cheap.
- Support near-real-time proxy refresh through platform-driven state updates.

## Non-Goals

- Redesign the public Dart API.
- Move platform logic back into Dart.
- Introduce a single cross-platform proxy listener implementation inside `native core`.
- Expand proxy behavior beyond the current `http / https / all / bypass` model in this phase.

## Design Summary

Each `native_<platform>` runtime will initialize and own a platform state object.

That state object will maintain:

- the latest proxy snapshot
- a monotonically increasing proxy generation
- any platform-specific listener or watcher resources

`native core` will no longer probe for proxy changes on a timer.
Instead, it will only compare the client's recorded proxy generation against the runtime's current proxy generation.

If the generation is unchanged, the existing reqwest client is reused.
If the generation changed, `native core` reads the latest snapshot once, rebuilds the reqwest client once, and updates the stored generation.

This keeps platform change detection inside platform runtimes and keeps the request hot path limited to a small amount of in-memory state checking.

## Runtime Boundary

### Platform Runtime Init

Each platform runtime should explicitly initialize its platform state when the runtime is created.

Conceptually:

- `native_android` creates an Android proxy state manager
- `native_ios` creates an iOS proxy state manager
- `native_macos` creates a macOS proxy state manager
- `native_windows` creates a Windows proxy state manager

That init step is platform-local.
`native core` does not know how the platform listener works.
It only receives a capability object that exposes current state access.

### Platform Capability Contract

Replace the current narrow `proxy_settings()` capability with a runtime state contract that supports:

- reading the current proxy snapshot
- reading the current proxy generation

The contract should remain read-only from the `native core` side.
Platform runtimes mutate their own state internally.

Conceptual shape:

```rust
pub trait PlatformRuntimeState: Send + Sync + 'static {
    fn current_proxy_snapshot(&self) -> ProxySettings;
    fn proxy_generation(&self) -> u64;
}
```

This is intentionally narrow.
It exposes state, not policy.

## Client Lifecycle

### On Runtime Init

Platform runtime:

- discovers the initial proxy snapshot
- starts its platform-specific change listener if available
- stores `snapshot + generation`

### On Client Create

`native core`:

- reads `current_proxy_snapshot()`
- reads `proxy_generation()`
- builds the reqwest client with that snapshot
- stores the generation alongside the client entry

### On Request Execute

`native core`:

1. reads the current `proxy_generation()`
2. compares it with the generation stored in the client entry
3. if unchanged, reuses the existing reqwest client
4. if changed, reads `current_proxy_snapshot()`, rebuilds the reqwest client, updates the stored generation, and continues

This replaces refresh probes with generation checks.

## Threading Model

Platform runtime state should be owned by the platform runtime and shared safely:

- `proxy_generation`: atomic integer
- `proxy_snapshot`: `RwLock<ProxySettings>` or equivalent

Platform listener thread or callback:

- computes the new snapshot
- writes the new snapshot
- increments `proxy_generation`

`native core` request path:

- atomically reads generation
- only takes the snapshot read path when generation changed

This ensures:

- no system API calls on the request hot path
- no periodic probing logic in `native core`
- bounded lock contention, only on real change or client rebuild

## Platform Responsibilities

### Android

Android runtime should own:

- initial proxy discovery
- change tracking mechanism
- local state cache

The current `getprop` mapping logic can remain as the snapshot-construction logic for the first phase.
What changes is where refresh policy lives.

### iOS and macOS

Apple runtimes should own:

- initial SystemConfiguration proxy snapshot
- listener registration for proxy-related system changes
- local generation updates

### Windows

Windows runtime should own:

- initial registry snapshot
- registry or system-setting change tracking
- local generation updates

## Native Core Changes

`native core` should:

- stop using time-based refresh probes for proxy drift
- remove `needs_refresh`, `refresh_in_progress`, and `next_refresh_probe_at` if they are only serving proxy refresh
- keep client rebuild behavior, but trigger it only from generation mismatch

`native core` should not:

- own platform listeners
- poll system settings
- encode platform-specific proxy refresh rules

## Migration Plan

### Phase 1

- introduce the new platform runtime state contract
- keep existing per-platform snapshot-building logic
- wire client entries to store `proxy_generation`
- replace refresh probes with generation comparison

### Phase 2

- add real platform-driven change listeners for each supported platform
- update platform states to increment generation on change

### Phase 3

- remove obsolete probe/backoff code from `native core`
- simplify runtime tests around proxy refresh

## Testing Strategy

### Native Core

Add tests that verify:

- unchanged generation reuses the existing client
- changed generation rebuilds exactly once
- repeated requests after rebuild stay on the fast path

### Platform Runtime

Add tests that verify:

- initial snapshot creation
- generation increments on simulated platform change
- snapshot reads return the newest state after change

### Performance

The main acceptance criterion is structural:

- no system proxy lookup should happen on the request steady-state hot path

This should be verified by tests using counting capabilities or injected fakes.

## Expected Outcome

After this redesign:

- platform runtimes fully own proxy discovery and proxy change tracking
- `native core` only consumes platform state
- request steady-state cost becomes a generation check instead of a probe model
- proxy refresh becomes event-driven at the platform boundary
- `native core` remains focused on client lifecycle and HTTP execution
