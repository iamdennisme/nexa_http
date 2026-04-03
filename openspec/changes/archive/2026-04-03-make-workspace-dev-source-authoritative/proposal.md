## Why

The local repository demo is supposed to run in `workspace-dev`, where native artifacts come from current workspace source rather than from published release assets. Today that contract is too weak: if a stale local native binary already exists, the resolver can reuse it as input instead of rebuilding from current source, which allows repository-local demo startup to drift away from the checked-out Rust code.

## What Changes

- Make `workspace-dev` source-authoritative so repository-local demo startup does not trust pre-existing local native binaries as authoritative input.
- Require development-mode native artifact resolution to prepare artifacts from current workspace source instead of silently reusing stale local dylib outputs.
- Preserve `release-consumer` behavior for external projects and GitHub Actions release assets.
- Tighten repository verification so development-path checks assert the new source-authoritative behavior.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `native-artifact-verification`: `workspace-dev` must treat source as authoritative and must not resolve stale local binaries as trusted input.
- `demo-platform-runnability`: the official repository demo must continue to use `workspace-dev`, but that path must now prepare native artifacts from current repository source rather than relying on pre-existing local binaries.

## Impact

- Affected code: `packages/nexa_http_distribution/lib/src/native_asset/nexa_http_native_artifact_resolver.dart`, target-resolution helpers, platform build hooks, demo verification scripts, and development-path tests
- Affected workflows: repository-local demo startup and development-path verification
- Unchanged workflows: external `release-consumer` resolution and GitHub Actions release publication
