## MODIFIED Requirements

### Requirement: CI consumer verification SHALL validate the explicit dependency contract
CI consumer verification SHALL validate that supported consumer integrations declare `nexa_http` together with every platform native package required by the integration's supported target platforms.

#### Scenario: CI validates a supported consumer app
- **WHEN** CI verifies a supported consumer integration
- **THEN** the integration MUST declare `nexa_http`
- **AND** it MUST declare the relevant `nexa_http_native_<platform>` package(s)
- **AND** it MUST NOT depend on `nexa_http_native_internal`

### Requirement: CI SHALL distinguish API surface from dependency artifacts
CI validation SHALL not treat "only public API surface" as equivalent to "only declared package dependency".

#### Scenario: CI checks integration contract terminology
- **WHEN** CI or structural verification validates repository expectations
- **THEN** it MUST preserve the distinction between:
  - `nexa_http` as the public API surface
  - platform native packages as public dependency artifacts

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
