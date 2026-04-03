## Context

`nexa_http` currently splits native library discovery across two layers: the core loader in `packages/nexa_http` and the platform carrier runtimes in `packages/nexa_http_native_*`. The core loader applies explicit-path override, environment override, broad candidate probing, and only then falls back to a registered runtime. At the same time, macOS and Windows carrier runtimes also walk packaged, workspace, and legacy paths. That overlap breaks the intended plugin/runtime boundary and makes successful startup depend on incidental file layout rather than a fixed contract.

This is already causing two different failure classes:
- debug consumers can load the wrong binary because a broad candidate list finds an existing but incorrect framework before the intended FFI library
- macOS external-consumer and release packaging can resolve workspace/source artifacts during build-hook execution, leading to invalid universal-binary assembly and non-reproducible consumer behavior

The repository already has stronger contracts than the implementation:
- carrier build hooks define packaged artifact identities per platform
- OpenSpec says external consumers must use release-consumer behavior
- OpenSpec says carrier packages must not duplicate generic loader policy

This change brings implementation back in line with those contracts.

## Goals / Non-Goals

**Goals:**
- Make registered platform runtime the default and authoritative native loading path after any explicit test override.
- Remove generic candidate-path probing from the core loader.
- Give each supported platform one deterministic runtime loading contract.
- Keep workspace-dev and source-build behavior inside build hooks and artifact preparation, not runtime loading.
- Ensure external-consumer builds use packaged or released assets and never silently drift into workspace/source resolution.
- Eliminate the macOS release/external-consumer ambiguity that currently allows incorrect artifact selection and broken universal-binary assembly.

**Non-Goals:**
- Preserving legacy runtime search behavior for historical app layouts.
- Supporting undocumented manual carrier-package dependency shapes as a public contract.
- Adding new platforms or changing the public HTTP API.
- Reworking demo UX beyond what is required to keep workspace-dev bootstrap working under the new contract.

## Decisions

### 1. Core loader stops owning path discovery
The core loader will keep only two responsibilities:
- accept an explicit `libraryPath` for tests or narrowly-scoped advanced overrides
- delegate to the registered `NexaHttpNativeRuntime`

It will no longer enumerate package, bundle, framework, or workspace candidates. This makes the runtime boundary real instead of advisory.

**Why this over keeping a reduced candidate list?**
A reduced candidate list still keeps path policy in the wrong layer and guarantees future drift. The platform runtime or build tooling is the correct place to define where a native library comes from.

### 2. Platform runtimes define one loading contract each
Each platform runtime will load exactly one documented integration target:
- Android: packaged `libnexa_http_native.so`
- iOS: process-linked symbols via `DynamicLibrary.process()`
- macOS: a single packaged native library contract produced by carrier build tooling
- Windows: a single packaged native library contract produced by carrier build tooling

Carrier runtimes will stop walking workspace and legacy locations.

**Why this over preserving workspace convenience in runtime?**
Runtime convenience is what makes consumer behavior nondeterministic. Workspace-dev support belongs in artifact preparation, where it can be explicit and testable.

### 3. Build hooks become the only place that distinguishes workspace-dev from external-consumer
Artifact resolution will explicitly separate:
- external-consumer: packaged assets and release-published assets only
- workspace-dev: local source/build preparation only when the repository is acting as its own development workspace

Default source-dir behavior will not be part of the external-consumer path.

**Why this over keeping current fallback order?**
Current fallback order allows consumer builds to succeed or fail depending on incidental local binaries. That violates the documented external-consumer contract.

### 4. Artifact identity remains stable while runtime policy changes
We will keep the documented artifact names already governed by existing specs unless a later deliberate breaking release changes them. This change fixes loading and resolution policy, not artifact naming.

**Why this over renaming artifacts now?**
Changing both identity and loading contract at once would increase migration risk without being necessary to solve the current architectural defect.

### 5. Verification must assert contract boundaries, not just file existence
Tests and repository verification must prove:
- core loader no longer performs candidate walking
- carrier runtimes do not duplicate generic discovery
- external-consumer artifact resolution does not compile or select workspace-local Rust outputs
- workspace-dev flows still function for the official demo

**Why this over only fixing the failing macOS path?**
The current issue exposed a general contract problem. Without verification, similar regressions will recur on other platforms.

## Risks / Trade-offs

- **[Risk]** Tightening runtime loading may break undocumented consumer setups that rely on legacy path probing.  
  **Mitigation:** Treat this as an intentional contract correction and document the supported integration path clearly.

- **[Risk]** The demo currently depends on workspace-dev behavior and may fail if build-hook mode separation is incomplete.  
  **Mitigation:** Keep demo verification in scope and explicitly test workspace-dev bootstrap after resolver changes.

- **[Risk]** macOS packaged-path assumptions may still be wrong if current bundle output does not match the governed artifact contract.  
  **Mitigation:** verify actual produced bundle layout during implementation and make carrier build tooling normalize the output to the documented contract.

- **[Risk]** Removing core candidate probing could expose missing platform runtime registration in tests or edge environments more quickly.  
  **Mitigation:** update test scaffolding to register fake runtimes explicitly and treat missing runtime as a real error.

## Migration Plan

1. Simplify the core loader so registered runtime becomes the default loading path after explicit override.
2. Remove generic discovery helpers and update loader tests to assert the new orchestration.
3. Simplify macOS and Windows carrier runtimes to fixed packaged-entry loading contracts.
4. Split native artifact resolution into explicit external-consumer and workspace-dev behavior.
5. Re-run consumer verification, demo verification, and macOS release/debug checks using the repository FVM-managed Flutter/Dart toolchain so verification does not depend on an older system SDK.
6. Update docs/spec references if implementation changes surface any governed contract wording gaps.

Rollback is straightforward while the change is unmerged: restore the previous loader and carrier runtime implementations. After merge, rollback should be avoided unless verification proves the new fixed contract is incomplete, because reintroducing candidate probing would reopen the architectural defect.

## Open Questions

- For macOS and Windows, what exact final packaged filesystem location should the runtime open after bundling, independent of intermediate hook/build artifact shapes?
- Does current Flutter/code-assets integration expose a more direct platform-native loading handle that would let macOS/Windows avoid filesystem path construction entirely?
- Should platform environment variable overrides remain supported outside tests, or should they also be restricted to explicit debug/developer workflows?
