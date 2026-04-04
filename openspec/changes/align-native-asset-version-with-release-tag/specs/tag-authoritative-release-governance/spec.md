## MODIFIED Requirements

### Requirement: Git tag SHALL be the authoritative release identity
The repository SHALL treat the triggering Git tag or externally selected git ref as the single authoritative release identity for tag-triggered publication, manifest version derivation, release URL construction, and tag-consumer verification. Release-consumer native hooks MUST use that authoritative release identity instead of deriving release URLs from local package `pubspec.yaml` versions.

#### Scenario: Release workflow publishes a version tag
- **WHEN** the release workflow runs for a tag such as `v1.0.2`
- **THEN** it MUST derive release identity from that tag
- **AND** it MUST use that tag as the governing input for publication artifacts and release URLs

#### Scenario: Tag consumer validation runs
- **WHEN** repository tooling validates an external consumer against a tagged release ref
- **THEN** it MUST use the tag as the consumer-facing release identity
- **AND** it MUST NOT require aligned workspace package versions as an additional release identity input

#### Scenario: Native carrier hook runs for a git-tag consumer
- **WHEN** a consumer resolves `nexa_http` from a git tag or equivalent release ref
- **THEN** the native carrier hook MUST construct manifest and asset release URLs from that authoritative ref
- **AND** it MUST NOT fall back to the local carrier package version when a release ref is available
- **AND** the public dependency contract MUST remain centered on `nexa_http` rather than requiring external apps to depend on carrier packages directly
