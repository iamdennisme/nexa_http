## ADDED Requirements

### Requirement: Git tag SHALL be the authoritative release identity
The repository SHALL treat the triggering Git tag as the single authoritative release identity for tag-triggered publication, manifest version derivation, release URL construction, and tag-consumer verification.

#### Scenario: Release workflow publishes a version tag
- **WHEN** the release workflow runs for a tag such as `v1.0.2`
- **THEN** it MUST derive release identity from that tag
- **AND** it MUST use that tag as the governing input for publication artifacts and release URLs

#### Scenario: Tag consumer validation runs
- **WHEN** repository tooling validates an external consumer against a tagged release ref
- **THEN** it MUST use the tag as the consumer-facing release identity
- **AND** it MUST NOT require aligned workspace package versions as an additional release identity input
