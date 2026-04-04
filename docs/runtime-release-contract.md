# Workspace Operating Contract

This document defines the repository workflows that are treated as stable
operating contracts rather than incidental implementation details.

If a change affects any contract below, it must land through an OpenSpec
change that updates the governing specs before or alongside implementation.

Primary OpenSpec sources of truth:

- [`openspec/specs/workspace-operating-contract/spec.md`](../openspec/specs/workspace-operating-contract/spec.md)
- [`openspec/specs/demo-platform-runnability/spec.md`](../openspec/specs/demo-platform-runnability/spec.md)
- [`openspec/specs/git-consumer-dependency-boundary/spec.md`](../openspec/specs/git-consumer-dependency-boundary/spec.md)
- [`openspec/specs/native-artifact-verification/spec.md`](../openspec/specs/native-artifact-verification/spec.md)
- [`openspec/specs/ci-enforced-consumer-verification/spec.md`](../openspec/specs/ci-enforced-consumer-verification/spec.md)

## Governed Contracts

The following workflows are governed:

- `development-path`: repository-local demo and maintainer workflow
- `release-consumer-path`: external `git/ssh` consumer workflow
- `artifact-consistency`: native asset naming, completeness, and manifest checks
- `release-publication`: tag-driven GitHub Actions asset publication
- `test-tag-validation`: governed publication, retry, workflow observation, and external tag-consumer proof for a release tag

## Official Entrypoints

Repository verification commands:

```bash
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart verify-release-consumer
fvm dart run scripts/workspace_tools.dart verify-tag-consumer --tag vX.Y.Z
fvm dart run scripts/workspace_tools.dart verify-artifact-consistency
fvm dart run scripts/workspace_tools.dart check-release-train --tag vX.Y.Z
```

Native artifact preparation entrypoints:

```bash
./scripts/build_native_macos.sh debug
./scripts/build_native_ios.sh debug
./scripts/build_native_android.sh debug
./scripts/build_native_windows.sh debug
```

Release publication entrypoints:

- [`.github/workflows/release-native-assets.yml`](../.github/workflows/release-native-assets.yml)
- [`scripts/tag_release_validation.sh`](../scripts/tag_release_validation.sh)

## Stable Rules

### 1. Local Demo Contract

- The official demo is [`packages/nexa_http/example`](../packages/nexa_http/example).
- Repository-local demo startup defaults to `workspace-dev`.
- Repository-local demo startup must not require source edits or pubspec edits.

### 2. External Consumer Contract

- External applications declare only `nexa_http`.
- External consumers default to `release-consumer`.
- External consumers must not implicitly require local Rust compilation.
- Published native asset lookup is governed by the selected Git tag/ref release identity, not by local package version metadata.

### 3. Artifact Contract

- Native asset names and target coverage come from the distribution-owned target
  matrix.
- Artifact consistency must be verifiable before release publication.
- Release consumers depend on a published manifest plus matching native assets.

### 4. Release Contract

- The workspace is one release train.
- Package versions and repository tag must stay aligned.
- Supported release assets are published by GitHub Actions, not by ad hoc local
  copying.

### 5. Test Tag Validation Contract

- Test-tag validation starts from `develop` and uses a governed release tag such as `vX.Y.Z`.
- The flow must distinguish local-only work from shared-state mutations such as pushing `develop`, deleting remote tags, and republishing the same tag name.
- Tag validation succeeds only after the required tag-triggered GitHub Actions complete successfully.
- External tag-consumer verification uses a temporary Flutter app outside the repository with git+ssh `ref: vX.Y.Z` and `path: packages/nexa_http`.
- The temporary external consumer must be cleaned up after verification unless explicitly preserved for debugging.

### 6. Change Governance Contract

The following changes require a new OpenSpec change:

- altering demo startup semantics
- altering external consumer dependency shape
- altering artifact resolution defaults
- altering native release asset naming or coverage
- removing or renaming official verification commands
- weakening CI enforcement for governed workflows

## Guidance For Future Repositories

If another repository adopts this model, keep the same high-level split:

- repo-local development path
- external release-consumer path
- asset verification before publication
- spec-driven governance for workflow changes

The exact script names may differ, but the contract-bearing workflows should not
become informal or session-specific.
