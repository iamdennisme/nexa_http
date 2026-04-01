## Why

The workspace package split is now cleaner, but the release pipeline, runtime loader rules, and version policy are still only partially aligned with those new boundaries. If they continue to evolve separately, the repository will drift back toward duplicated rules, inconsistent release behavior, and weak cross-package guarantees.

## What Changes

- Move native asset manifest generation concerns toward `nexa_http_distribution` so manifest schema, digest rules, and file naming have a single source of truth.
- Reshape `nexa_http_runtime` loader internals around explicit per-platform candidate strategy modules instead of one aggregated rule file.
- Add workspace-level version alignment verification so the seven release-train packages cannot silently drift:
  `nexa_http`, `nexa_http_runtime`, `nexa_http_distribution`, `nexa_http_native_android`, `nexa_http_native_ios`, `nexa_http_native_macos`, and `nexa_http_native_windows`.
- Update release tooling and documentation so the repository treats SDK, runtime, distribution, and native assets as one coordinated release train.

## Capabilities

### New Capabilities
- `native-distribution-source-of-truth`: Define one authoritative manifest-generation and artifact-schema layer for native distribution metadata.
- `runtime-loader-platform-strategies`: Define platform-specific runtime loader strategies with explicit boundaries between orchestration and candidate discovery.
- `workspace-version-alignment`: Define enforceable rules for keeping workspace package versions aligned with repository releases.

### Modified Capabilities

- None.

## Impact

- Affected code: `packages/nexa_http_runtime`, `packages/nexa_http_distribution`, `scripts/generate_native_asset_manifest.dart`, `.github/workflows/release-native-assets.yml`, workspace verification scripts, and repository documentation.
- Affected systems: native asset publishing, runtime dynamic-library discovery, workspace release/version policy.
- Dependencies: no new product dependency is required, but release tooling and CI checks will need to call the new shared logic.
