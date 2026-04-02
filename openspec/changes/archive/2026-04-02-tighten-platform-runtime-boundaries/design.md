## Context

The workspace already separates concerns reasonably well, but it does not yet enforce them rigorously:

- `nexa_http` owns the public Dart HTTP API
- `nexa_http_runtime` owns dynamic-library loading and runtime registration
- `nexa_http_distribution` owns build-hook and release-time native artifact resolution
- per-platform carrier packages own packaged artifacts and platform-specific runtime integration
- `nexa_http_native_core` owns shared Rust execution and proxy/runtime coordination

The remaining issues are exactly where those boundaries overlap:

- the Windows target matrix is broader in runtime candidate discovery than it is in build hooks and release manifests
- macOS and Windows still keep overlapping dynamic-library discovery logic in both runtime loader and carrier runtime implementations
- platform proxy sources mostly default to polling refresh, even when the underlying settings are close to static
- carrier-package verification mostly proves registration and a single packaged asset path, not that runtime/distribution/packaging agree on the same target matrix

Because breaking changes are allowed, the right response is not a narrow cleanup. The right response is to re-draw the package boundary so each layer owns exactly one kind of platform knowledge.

## Goals / Non-Goals

**Goals:**
- Define one authoritative platform target and artifact model for runtime loading, carrier packaging, and release generation.
- Make `nexa_http_runtime` the single generic dynamic-library discovery/orchestration layer.
- Reduce carrier packages to host integration, packaged assets, and platform-specific native glue instead of duplicate loader policy.
- Replace implicit proxy polling defaults with explicit platform refresh models.
- Improve verification so target coverage and artifact contract drift are caught inside the repository.

**Non-Goals:**
- Add Linux support.
- Change request/response FFI semantics.
- Replace the shared Rust runtime architecture.
- Rewrite the HTTP execution model.

## Decisions

### 1. Make distribution-owned platform descriptors the single source of truth

The authoritative platform/architecture/SDK matrix should live in distribution-owned descriptors and be reused by:

- release manifest generation
- carrier build-hook target selection
- runtime candidate strategy construction
- platform-aware verification

Why:
- This is the layer that already owns release manifest schema and artifact identity.
- The biggest current drift is between release, build-hook, and runtime target definitions.

Alternative considered:
- Keep target rules split between runtime, distribution, and build hooks.

Why not:
- That preserves the inconsistency this change is trying to eliminate.

### 2. Make `nexa_http_runtime` the only generic loader/orchestrator

`nexa_http_runtime` should own:

- host platform resolution
- explicit override handling
- environment override handling
- candidate probing
- registered-runtime fallback
- generic packaged/workspace candidate search policy

Carrier packages should no longer carry broad candidate-walking logic that mirrors runtime loader behavior.

Carrier packages should only own:

- host-platform runtime registration
- packaged asset wiring
- host-specific loading behavior that cannot live in the generic loader
- platform-specific native glue

Why:
- The current duplication is small enough to be fixable, but large enough to drift.
- Loader strategy modules already exist and are the natural home for generic path search policy.

Alternative considered:
- Delete runtime loader and let each carrier package own all discovery.

Why not:
- That would fragment behavior and remove the one place where cross-platform policy is visible.

### 3. Treat proxy refresh as an explicit platform capability model

Platform proxy refresh should no longer be represented as “usually polling.” The model should become an explicit capability contract, for example:

- static for runtime lifetime
- refresh on runtime/client construction
- bounded polling with declared cadence

Shared coordination still belongs in Rust core, but platform sources should declare behavior that matches reality:

- use static behavior when runtime-stable is good enough
- use bounded polling only where the platform cannot do better and where change frequency justifies the cost
- avoid “always-on every few seconds” as the default answer for desktop and Apple platforms

Why:
- The current shared runtime already supports per-platform refresh modes.
- The remaining problem is that the current policy vocabulary nudges every platform toward polling.

Alternative considered:
- Keep current polling cadence and accept the background thread cost.

Why not:
- The cost is paid continuously while the practical proxy-change frequency is usually near zero.

### 4. Verify boundary agreement, not just isolated files

Verification should move up one level of abstraction. The repository should assert:

- the declared platform matrix is internally consistent
- runtime loader candidates are derived from that matrix
- carrier build hooks cover the same declared targets
- release manifest generation covers the same declared targets
- unsupported targets are rejected explicitly, not implied accidentally
- carrier packages do not grow generic loader policy back in through ad hoc helpers

Why:
- The current regressions are exactly the kind of drift shallow unit tests miss.

## Risks / Trade-offs

- [Refactoring multiple packages at once increases coordination risk] -> Mitigation: land the new platform model first, then route loader/hooks/tests through it in dependency order.
- [Over-correcting proxy refresh policy could miss legitimate runtime proxy changes on some platforms] -> Mitigation: keep bounded polling available where needed and prove policy choices with focused source tests.
- [Removing duplicated loader logic too aggressively could make packaged app loading brittle] -> Mitigation: keep the top-level loader behavior stable and compare old/new candidate coverage before deleting fallback paths.
- [Breaking package boundaries can confuse downstream users] -> Mitigation: document the new ownership model clearly in package READMEs and release notes.

## Migration Plan

1. Introduce one distribution-owned platform target model that names supported OS/architecture/SDK combinations and artifact identity.
2. Route release manifest generation, distribution resolution, and carrier build hooks through that model.
3. Refactor runtime loader strategies to derive candidates from the same model.
4. Simplify carrier packages so they stop maintaining duplicate generic loader search logic.
5. Redefine platform proxy refresh capabilities and update Rust platform sources accordingly.
6. Add cross-package verification that checks matrix agreement and boundary discipline.

Rollback is straightforward in repository terms because the work is boundary-local: reverting restores the previous split target definitions and loader duplication. The trade-off is that this change is intentionally breaking at the package-boundary level, so rollback should happen before any release that documents the new ownership model.

## Open Questions

- Whether Windows support should be constrained to the currently shipped release targets or expanded across additional toolchains/architectures in the same change should be decided during implementation, but the answer must be expressed through the single authoritative platform model.
