## Why

The current native stack exposes `nexa_http_runtime` and `nexa_http_distribution` as separate packages and embeds package-version-derived release identity, legacy compatibility logic, and split runtime/distribution policy across artifact resolution, runtime loading, and verification. That structure conflicts with the intended architecture where `nexa_http` is the only public Dart API surface, native runtime/distribution concerns are one internal layer, and platform carriers are explicit dependency artifacts selected by consumers.

## What Changes

- **BREAKING** Collapse `runtime` and `distribution` into one internal native layer consumed directly by `nexa_http`.
- **BREAKING** Remove `nexa_http_runtime` and `nexa_http_distribution` as independent package-level architecture concepts and public-facing surfaces.
- Remove package-version-derived release identity, historical fallback probing, and split runtime/distribution policy from code, verification, and documentation.
- Remove legacy and fallback artifact probing, historical path support, and compatibility-oriented loader behavior.
- Redefine platform/carrier responsibilities so they only produce supported platform artifacts, while `Flutter` / `Kino` / `app` selects which supported artifacts are used.
- Preserve `nexa_http` as the only public Dart API surface for app integration.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `native-distribution-source-of-truth`: replace the separate distribution package with a merged internal native-layer artifact model while preserving explicit workspace-dev and release-consumer source-selection rules.
- `runtime-loader-platform-strategies`: redefine runtime loading around explicit platform artifact selection with no legacy probing or split runtime/distribution boundary.
- `platform-runtime-verification`: enforce merged native-layer boundaries, explicit target agreement, and removal of version/release/legacy logic.
- `git-consumer-dependency-boundary`: keep `nexa_http` as the only public Dart API surface while shifting platform package selection to explicit consumer-owned dependency declarations.
- `workspace-version-alignment`: remove lockstep package-version and release-tag alignment requirements.
- `tag-authoritative-release-governance`: remove tag-authoritative release identity governance from the native integration model.
- `ci-enforced-consumer-verification`: keep release-consumer publication checks, but make them validate explicit platform dependencies and tag/ref-based artifact lookup instead of package-version alignment.

## Impact

- Affected code: `packages/nexa_http`, `packages/nexa_http_runtime`, `packages/nexa_http_distribution`, platform carrier packages, loader code, native target mapping, verification scripts, and release-oriented documentation.
- Affected APIs: internal native-loading and artifact-resolution boundaries; public app-facing Dart API remains `nexa_http`.
- Affected tooling: repository verification and native artifact preparation scripts will move away from package-version release governance and legacy compatibility behavior.
