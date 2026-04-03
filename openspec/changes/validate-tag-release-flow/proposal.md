## Why

The repository already has release workflows and external-consumer verification paths, but there is no explicit governed contract for destructive tag resets, tag-triggered workflow validation, and git+ssh tag-consumer verification. Right now a maintainer can perform a risky test-tag release loop ad hoc, without a shared definition of success, retry behavior, or cleanup boundaries.

## What Changes

- Add a new governed workflow capability for validating a release tag from `develop`, including push, tag publication, workflow observation, and consumer verification.
- Define a shared-state-aware release-test flow that explicitly distinguishes local-only steps from remote-visible steps such as pushing commits, deleting remote tags, and re-publishing the same tag name.
- Define success criteria for a tag validation run, including which tag-triggered GitHub Actions must succeed before the tag is considered usable.
- Define the retry loop for fixing failures and reissuing the same governed release tag (for example `v1.0.1`) until the tag-triggered workflows pass.
- Define a minimal external consumer verification step using a temporary demo outside the repository with `pubspec.yaml` git+ssh tag resolution against `packages/nexa_http`.
- Define cleanup expectations for the temporary consumer demo after verification completes.

## Capabilities

### New Capabilities
- `tag-release-validation`: Defines the governed workflow for publishing a test tag, validating tag-triggered automation, retrying the same tag after fixes, and proving external git+ssh tag consumption.

### Modified Capabilities
- `workspace-operating-contract`: Extend the operating contract so test-tag publication, shared-state mutations, and tag-consumer verification are explicit governed workflows rather than ad hoc maintainer behavior.
- `ci-enforced-consumer-verification`: Clarify which tag-triggered GitHub Actions outcomes count as release-tag validation success before an external consumer test proceeds.
- `git-consumer-dependency-boundary`: Clarify that external consumer verification must include tag-based git+ssh resolution of `packages/nexa_http`, not only branch or path-based repository-local checks.

## Impact

Affected systems include git tag lifecycle management, GitHub Actions tag-triggered workflows, external consumer verification procedures, and repository operating-contract documentation. Affected code and configuration will likely include release workflow definitions, verification scripts, and any repository-owned instructions used to validate git+ssh tag consumption.
