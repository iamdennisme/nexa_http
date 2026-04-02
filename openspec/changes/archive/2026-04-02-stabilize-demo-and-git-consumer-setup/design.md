## Context

The repository already has a strong shared native core, but the product boundary is still wrong. Right now:

- the public SDK shape still exposes carrier-package choices to app users
- the example app behaves like a workspace fixture, not a first-class development entrypoint
- build hooks mix "local contributor build" and "external release consumption" into one implicit resolver
- native bootstrap failures collapse into a generic client-creation failure with no root-cause visibility

That creates friction in both intended use cases:

- contributors cannot rely on the demo as the canonical local development path
- external consumers cannot treat `nexa_http` as a coherent SDK

The redesign should stop treating those as one fuzzy path and instead model them as two explicit operating modes with one clean public package.

## Goals / Non-Goals

**Goals**
- Make `nexa_http` the only public dependency an app declares.
- Move platform carrier packages behind a federated plugin boundary owned by `nexa_http`.
- Define two explicit native artifact modes:
  - `workspace-dev`
  - `release-consumer`
- Make `packages/nexa_http/example` the canonical local development demo and ensure it exercises `workspace-dev`.
- Ensure external git/ssh consumers resolve native artifacts without implicit local Rust compilation.
- Replace opaque bootstrap failures with structured diagnostics that identify the failing stage.
- Make CI verify both product paths independently.

**Non-Goals**
- Publish to pub.dev.
- Collapse the native implementation into a single monolithic package.
- Change the HTTP request/response API exposed by `package:nexa_http/nexa_http.dart`.
- Add Linux support as part of this change.

## Decisions

### 1. `nexa_http` becomes the only public dependency

Apps should depend only on `nexa_http`.

Platform packages remain in the repository, but they become implementation packages selected by Flutter's federated plugin mechanism instead of user-declared dependencies. `nexa_http_runtime` and `nexa_http_distribution` become internal implementation details from the app consumer's perspective.

Why:
- This is the cleanest external integration story for git/ssh consumption.
- It removes user-facing coupling to internal package layout and platform registration details.
- It matches how a finished Flutter SDK should present itself.

### 2. Native artifact resolution gets two explicit modes

Artifact preparation must stop guessing user intent. The resolver will operate in one of two named modes:

- `workspace-dev`
  - intended for repository development and the official demo
  - allowed to build native artifacts from local source
  - should prefer fresh local artifacts for the checked-out workspace

- `release-consumer`
  - intended for apps consuming the SDK from git/ssh
  - must not implicitly invoke `cargo build`
  - should resolve packaged artifacts or release-published assets only

Mode selection should be explicit in repository tooling and deterministic in runtime/build-hook orchestration.

Why:
- Contributors need a reliable local iteration path.
- External consumers should not be surprised by hidden Rust toolchain requirements.
- Explicit mode removes current ambiguity around fallback behavior.

### 3. The repository example becomes a development tool, not just documentation

`packages/nexa_http/example` becomes the official development demo. Its job is not merely to show API usage; it must prove the contributor workflow:

- clone repository
- prepare native artifacts locally
- run the demo on supported platforms without source edits
- validate Flutter and Rust changes together

This implies example startup may orchestrate or depend on local native preparation as part of the documented development path.

Why:
- One canonical development entrypoint reduces ambiguity and drift.
- It gives contributors a real integration harness rather than scattered scripts.

### 4. Bootstrap failures become structured errors

Native bootstrap and client creation must stop returning a bare failure sentinel. The system should expose structured failures for at least:

- artifact resolution failure
- native library load failure
- client config decode failure
- platform proxy configuration failure
- HTTP client construction failure

These errors should surface through Dart in a way that allows demo users and integrators to distinguish environment/setup problems from runtime API failures.

Why:
- The current failure surface is too weak to debug real integration problems.
- Without diagnostics, both CI and user support devolve into guesswork.

### 5. CI must validate development path and consumer path separately

PR CI should explicitly test:

- repository development path (`workspace-dev`)
- external consumer path (`release-consumer`)
- artifact publication/source-of-truth consistency

Release workflows should only publish after the release-consumer path and artifact consistency checks pass.

Why:
- These are different promises with different failure modes.
- One generic verification command is not enough to protect both.

## Architecture

### Public Package Topology

- `nexa_http`
  - public API package
  - federated plugin app-facing entrypoint
  - owns public bootstrap diagnostics surface

- `nexa_http_native_android|ios|macos|windows`
  - federated default implementations
  - own host/platform wiring and platform-specific native asset bundle declarations
  - no longer appear in public integration instructions

- `nexa_http_runtime`
  - internal runtime loading/orchestration
  - mode-aware artifact/library resolution support

- `nexa_http_distribution`
  - authoritative target matrix
  - artifact identity and manifest generation
  - mode-aware resolver metadata

### Artifact Modes

#### `workspace-dev`

Inputs:
- checked-out repository workspace
- local native crates
- contributor toolchain

Behavior:
- resolves target metadata from distribution
- prepares missing local artifacts from source in a deterministic, documented way
- prefers local workspace artifacts over release assets

Primary users:
- repository demo
- contributors
- local platform debugging

#### `release-consumer`

Inputs:
- pinned git repository ref
- packaged assets and/or published release assets

Behavior:
- resolves target metadata from distribution
- uses packaged assets or manifest-backed release assets
- never invokes local Rust compilation implicitly

Primary users:
- external apps
- CI validation of public integration path
- release verification

### Bootstrap Diagnostics

Introduce a typed bootstrap error contract between native and Dart:

- native returns a structured error payload instead of just `0`
- Dart maps bootstrap failures to a dedicated exception family
- logs/tests can assert on stage and code rather than substring matching

At minimum, bootstrap diagnostics should cover:
- library open / symbol load
- artifact resolution mode decision
- client config parsing
- platform proxy validation
- reqwest client creation

### Verification Layers

1. **Development-path verification**
   - example/demo bootstraps in `workspace-dev`
   - local artifact preparation path is exercised
   - startup failures are reported with structured diagnostics

2. **External-consumer verification**
   - consumer depends only on `nexa_http`
   - resolves from git/ssh at a pinned ref
   - uses `release-consumer`
   - does not require a Rust toolchain

3. **Artifact/source-of-truth verification**
   - target matrix, release manifest, packaged assets, and resolver rules remain aligned
   - mode-specific artifact expectations stay consistent

### CI Integration

- PR CI:
  - verify artifact/source-of-truth consistency
  - verify external consumer path
  - verify repository demo path on supported hosts
- Release CI:
  - build/publish assets
  - re-run release-consumer verification before publication

## Risks / Trade-offs

- [Federated plugin restructuring may require Flutter/package-layout changes across multiple packages]
  - Mitigation: make the public dependency simplification an explicit breaking change and verify package resolution with a real consumer fixture.
- [Two artifact modes add conceptual surface area]
  - Mitigation: the surface is explicit and simpler than the current implicit guessing behavior.
- [Structured bootstrap errors require ABI and runtime changes]
  - Mitigation: version the FFI contract inside the repo and update all carrier/runtime packages in one coordinated change.
- [Repository demo may need stronger tooling assumptions than external consumers]
  - Mitigation: document `workspace-dev` prerequisites explicitly and keep them out of the release-consumer path.

## Migration Plan

1. Redefine the change as a breaking redesign of public package boundary and artifact modes.
2. Add failing verification for:
   - single-package external integration
   - explicit dev vs consumer artifact resolution
   - structured bootstrap diagnostics
3. Restructure package/plugin wiring so apps declare only `nexa_http`.
4. Implement mode-aware artifact resolution and demo startup flow.
5. Replace generic bootstrap failures with structured native diagnostics.
6. Update docs, demo commands, and CI to reflect the new product model.
