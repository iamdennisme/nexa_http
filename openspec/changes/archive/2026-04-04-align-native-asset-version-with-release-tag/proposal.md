## Why

Tag consumers currently break when the repository publishes a release tag like `v0.0.1` while package metadata inside the workspace still says `1.0.1`, because native asset hooks build release-manifest URLs from local package versions instead of the authoritative Git tag. This must be fixed now so remote git consumers can resolve native assets correctly from tagged releases without depending on local workspace state.

## What Changes

- Make native asset release resolution derive consumer-facing release identity from the authoritative Git tag/ref rather than from local package `pubspec.yaml` versions.
- Collapse release lookup onto one semantic source of truth so published native asset resolution is governed only by the selected release identity and never by a competing local package-version meaning.
- Update carrier/native distribution tooling so all supported platforms follow the same tag-driven release lookup contract while preserving `nexa_http` as the only public dependency surface.
- Keep workspace package version alignment as maintenance metadata, but do not let local package versions override or reinterpret tag-based release asset resolution for consumers.
- Refresh release-validation documentation and tests so tagged releases prove that native hooks resolve the right manifest and assets even when workspace package versions differ.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `tag-authoritative-release-governance`: Release consumers and publication tooling use the Git tag/ref as the authoritative release identity.
- `workspace-version-alignment`: Workspace version alignment remains diagnostic metadata instead of the source of truth for tag consumer resolution.
- `native-distribution-source-of-truth`: Native artifact manifest resolution preserves stable filenames but derives release identity from the authoritative tag contract.

## Impact

- `packages/nexa_http_distribution` native artifact resolution logic
- Carrier hook/build logic under `packages/nexa_http_native_*`
- Release/tag validation scripts and docs
- Remote git consumers such as Kino that depend on tagged releases instead of local path workspaces
