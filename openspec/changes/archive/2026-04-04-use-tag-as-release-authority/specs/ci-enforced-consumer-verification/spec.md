## MODIFIED Requirements

### Requirement: Release publication SHALL reuse release-consumer verification
The release workflow SHALL run the same release-consumer and artifact-consistency checks that protect external users before publishing assets, and tag-triggered publication SHALL be governed by tag validity plus those contract checks rather than aligned workspace package versions.

#### Scenario: Release workflow prepares native assets
- **WHEN** the release workflow is about to publish manifests or native assets for a release tag
- **THEN** it MUST execute the repository verification that protects the release-consumer path
- **AND** it MUST NOT rely on a separate unpublished rule set

#### Scenario: Maintainer validates a published test tag
- **WHEN** a maintainer publishes a governed test tag such as `v1.0.2`
- **THEN** the repository MUST define the required tag-triggered GitHub Actions workflows that determine whether that tag is considered successful
- **AND** the test-tag validation flow MUST NOT proceed to external consumer verification until those required workflows have completed successfully

#### Scenario: Release publication evaluates metadata drift
- **WHEN** artifact-consistency and release-consumer verification succeed for a valid release tag
- **THEN** publication MUST continue even if aligned workspace package versions differ from that tag
- **AND** package-version drift MUST NOT be treated as a release-blocking publish failure
