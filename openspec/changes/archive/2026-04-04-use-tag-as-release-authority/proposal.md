## Why

The current release workflow treats Git tags and aligned package versions as two equally authoritative release signals, even though the actual release pipeline, manifest generation, and consumer validation are already driven by the Git tag. That makes otherwise valid release tags fail late for metadata drift that does not affect the native asset contract, so we should simplify release governance now and make the tag the single release authority.

## What Changes

- Remove package-version release gating from the release workflow so tag-triggered publication is governed by tag validity, artifact consistency, and consumer-path verification instead of aligned `pubspec.yaml` versions.
- Reframe repository release governance so Git tags are the authoritative release identity for native asset manifests, release URLs, and tag-consumer validation.
- Keep package versions as package metadata, but stop treating release-train alignment as a hard prerequisite for publishing tag-based releases.
- Update verification scripts, workflow tests, and release-policy specs to reflect tag-first release authority.
- **BREAKING**: release publication will no longer fail solely because workspace package versions drift from the triggering Git tag.

## Capabilities

### New Capabilities
- `tag-authoritative-release-governance`: defines Git tag as the single release authority for release workflow gating, manifest versioning, and tag-based consumer validation.

### Modified Capabilities
- `ci-enforced-consumer-verification`: release publication requirements change from tag-plus-package-version gating to tag-plus-contract verification.
- `workspace-version-alignment`: version alignment stops being a release-blocking rule for tag-based publication.
- `git-consumer-dependency-boundary`: release governance for git/tag consumers changes to rely on tag identity rather than aligned package versions.
- `native-distribution-source-of-truth`: release manifest generation continues to use tag-derived version identity as the source of truth for published assets.

## Impact

- Affected code: `.github/workflows/release-native-assets.yml`, `scripts/workspace_tools.dart`, and release-governance tests under `test/`.
- Affected behavior: release tags can publish when artifact/consumer verification succeeds even if workspace package versions have not been lockstep-bumped.
- Affected governance: OpenSpec release-policy and CI-verification specs will shift from dual authority (tag + package version) to tag-authoritative release rules.
