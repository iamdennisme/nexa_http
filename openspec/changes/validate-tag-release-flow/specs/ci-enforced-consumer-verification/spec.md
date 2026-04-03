## MODIFIED Requirements

### Requirement: Release publication SHALL reuse release-consumer verification
The release workflow SHALL run the same release-consumer and artifact-consistency checks that protect external users before publishing assets, and the repository SHALL define which tag-triggered GitHub Actions outcomes count as successful test-tag validation before external consumer verification proceeds.

#### Scenario: Release workflow prepares native assets
- **WHEN** the release workflow is about to publish manifests or native assets
- **THEN** it MUST execute the repository verification that protects the release-consumer path
- **AND** it MUST NOT rely on a separate unpublished rule set

#### Scenario: Maintainer validates a published test tag
- **WHEN** a maintainer publishes a governed test tag such as `v1.0.1`
- **THEN** the repository MUST define the required tag-triggered GitHub Actions workflows that determine whether that tag is considered successful
- **AND** the test-tag validation flow MUST NOT proceed to external consumer verification until those required workflows have completed successfully
