## Context

The repository currently models native integration through separate `nexa_http_runtime` and `nexa_http_distribution` packages. That split is reinforced by package boundaries, tests, verification scripts, and release-oriented documentation. At the same time, `nexa_http` is already the app-facing package, but it still depends directly on the split runtime/distribution model and on federated carrier wiring that automatically selects platform implementations.

The target architecture is simpler: `nexa_http` is the only public surface for `Flutter` / `Kino` / `app`; runtime and distribution are a single inseparable internal concern; platform/carrier packages exist only to produce platform artifacts; and the codebase must stop encoding version numbers, tags, release identities, consumer modes, or historical fallback behavior.

This is a cross-cutting change because it affects package structure, native artifact resolution, loader behavior, platform integration, verification, and repository documentation.

## Goals / Non-Goals

**Goals:**
- Make `nexa_http` the only public integration surface.
- Collapse runtime and distribution into one internal native layer.
- Remove all version-, release-, tag-, and release-identity-driven source logic from the native stack.
- Remove all legacy/fallback path probing and historical compatibility behavior.
- Restrict platform/carrier responsibilities to producing supported platform artifacts.
- Align verification and docs with the simplified architecture.

**Non-Goals:**
- Preserving compatibility with existing release-consumer, tag-consumer, or workspace-dev contracts.
- Maintaining current federated automatic platform selection behavior if it conflicts with explicit artifact selection.
- Minimizing change scope; large removals are acceptable.
- Introducing new public app-facing APIs beyond what is required to preserve `nexa_http` as the single public surface.

## Decisions

### 1. Merge runtime and distribution into one internal native layer under `nexa_http`
`nexa_http_runtime` and `nexa_http_distribution` will no longer remain as independent architectural layers. Their surviving logic will be consolidated into a single internal native layer consumed directly by `nexa_http`.

**Why:** The current split is artificial in practice, since runtime loading already depends on distribution-owned target and artifact knowledge. Keeping the split preserves the wrong architecture and leaks internal concerns into package boundaries, tests, and docs.

**Alternatives considered:**
- Keep both packages and only hide them from documentation. Rejected because the codebase would still encode the wrong layering.
- Keep one extra internal-only helper package. Acceptable only if needed mechanically, but not as a first-class architecture layer.

### 2. Treat platform/carrier packages as artifact producers only
Platform packages will be reduced to platform-specific artifact production and narrowly-scoped host integration. They must not own version/release logic, generic probing rules, or duplicated runtime/distribution policy.

**Why:** Carrier packages should exist to produce and expose platform artifacts, not to participate in architectural policy.

**Alternatives considered:**
- Continue using carriers as semi-smart integration packages. Rejected because that keeps boundary logic fragmented and hard to reason about.

### 3. Remove version, tag, release identity, and consumer mode logic entirely
The merged native layer, verification scripts, and documentation will no longer model release identity, package version alignment, tag-authoritative resolution, `workspace-dev`, or `release-consumer` source selection.

**Why:** The desired architecture explicitly rejects version-aware modules. Keeping any of these concepts would preserve a second architecture hidden inside tooling and manifests.

**Alternatives considered:**
- Keep release/tag logic in scripts only. Rejected because the architecture rule is that modules do not care about versions.

### 4. Replace fallback discovery with explicit target and path rules
Native loading and artifact resolution will use explicit supported-target definitions and fixed artifact locations. If a required artifact is not available, bootstrap/build fails directly instead of searching legacy names or historical paths.

**Why:** Legacy probing encodes compatibility behavior and makes the actual runtime contract unclear.

**Alternatives considered:**
- Keep limited fallback for local development convenience. Rejected because it violates the no-compatibility rule and prolongs cleanup.

### 5. Shift platform artifact choice out of implicit federation defaults
The architecture will stop depending on hidden `default_package`-style automatic platform selection if that prevents explicit consumer-owned platform artifact choice.

**Why:** The target model says platform/carrier outputs are selected by `Flutter` / `Kino` / `app`, not silently chosen by internal federation defaults.

**Alternatives considered:**
- Keep current federation wiring and reinterpret it as selection. Rejected because it preserves implicit selection and hides product decisions in package metadata.

### 6. Rewrite verification around simplified structural invariants
Repository verification will validate only the new structure: `nexa_http` as the sole public surface, merged internal native layer, supported target agreement, absence of version/release logic, and absence of legacy probing.

**Why:** Existing checks enforce the architecture being removed.

**Alternatives considered:**
- Keep old verification and add exceptions. Rejected because the old checks would continue to encode removed concepts.

## Risks / Trade-offs

- [Large removal surface] → Delete-oriented refactors can break build wiring unexpectedly. Mitigation: perform structural changes first, then reintroduce only the minimum artifact-loading path that matches the new design.
- [Platform integration churn] → Moving away from implicit federation defaults may require coordination across Flutter/Kino/app integration points. Mitigation: make explicit platform-selection contract part of the spec and update integration docs at the same time.
- [Spec overlap] → Several existing specs currently encode release/tag/consumer behavior that this change removes. Mitigation: update all affected capability specs in the same change so archive/apply reflects the new architecture cleanly.
- [Transient repository breakage during implementation] → Intermediate states may fail verification because the old checks are being removed. Mitigation: replace old checks in the same implementation sequence rather than trying to keep both systems valid in parallel.

## Migration Plan

1. Update specs to remove release/tag/version/consumer governance and define the merged native-layer contract.
2. Remove or rewrite verification artifacts so they enforce only the new structural rules.
3. Consolidate surviving runtime/distribution logic into `nexa_http` (or a single private helper package if mechanically necessary).
4. Delete obsolete runtime/distribution package surfaces and release-oriented tooling.
5. Simplify platform carriers to artifact-only responsibilities and replace implicit platform selection with the explicit model required by the new spec.
6. Update repository/package documentation to reflect the new public and internal boundaries.

## Open Questions

- Does explicit platform artifact selection need a single shared configuration shape across Flutter, Kino, and app, or is “consumer-owned selection” sufficient without a common config API?
- Should any carrier package survive as a published package boundary for build tooling reasons, or can all platform artifact handling be absorbed behind `nexa_http` plus raw artifacts?
