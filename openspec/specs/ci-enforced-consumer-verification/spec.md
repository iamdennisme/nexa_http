## ADDED Requirements

### Requirement: CI SHALL block merges on development-path and consumer-path failures
The repository SHALL run PR CI that blocks merge when development-path verification, release-consumer verification, or artifact/source-of-truth verification fails.

#### Scenario: Pull request updates code, assets, or setup docs
- **WHEN** the PR CI workflow runs
- **THEN** it MUST fail if any required development-path, external-consumer-path, or artifact-consistency verification step fails
- **AND** repository policy MUST treat that workflow as merge-blocking

### Requirement: CI SHALL validate supported paths on the relevant hosts
The repository SHALL exercise the supported verification surfaces across the host platforms needed for those paths.

#### Scenario: CI validates the workspace
- **WHEN** the normal CI workflow runs
- **THEN** it MUST include the host/platform coverage required to validate repository development flow and external consumer flow
- **AND** each job MUST run the path-specific verification relevant to that host

### Requirement: Release publication SHALL reuse release-consumer verification
The release workflow SHALL run the same release-consumer and artifact-consistency checks that protect external users before publishing assets.

#### Scenario: Release workflow prepares native assets
- **WHEN** the release workflow is about to publish manifests or native assets
- **THEN** it MUST execute the repository verification that protects the release-consumer path
- **AND** it MUST NOT rely on a separate unpublished rule set
