## MODIFIED Requirements

### Requirement: Workspace package versions stay aligned
The system SHALL support inspecting whether the seven release-train packages use the same semantic version for coordinated maintenance, but this alignment check SHALL remain advisory metadata hygiene rather than a required gate for tag-triggered release publication or release-consumer native asset resolution. The check SHALL exclude `app/demo`.

#### Scenario: one package version drifts
- **WHEN** repository tooling inspects aligned package metadata and one aligned package declares a different version
- **THEN** the inspection MUST identify the mismatched package versions
- **AND** the result MUST be available to maintainers as a diagnostic signal

#### Scenario: tag-triggered release preparation runs
- **WHEN** a coordinated release is prepared from a Git tag
- **THEN** workspace package-version drift MUST NOT block publication by itself
- **AND** release success MUST be governed by the tag-driven release contract instead

### Requirement: Release tags define the release version
The system SHALL treat repository release tags as the authoritative semantic release identity for tag-triggered publication and release-consumer native asset lookup rather than requiring them to equal aligned workspace package versions.

#### Scenario: release tag does not match package versions
- **WHEN** release preparation runs for a tag whose semantic version differs from aligned workspace package versions
- **THEN** repository tooling MUST preserve the tag as the release identity
- **AND** it MUST NOT fail publication solely because package metadata differs

#### Scenario: release-consumer hook runs with mismatched package metadata
- **WHEN** a carrier hook executes from a workspace snapshot whose local package versions differ from the consumer's selected release tag
- **THEN** the hook MUST resolve release artifacts from the selected release tag
- **AND** it MUST treat local package versions as advisory metadata only
- **AND** it MUST NOT preserve a second competing version meaning for published asset lookup

### Requirement: Documentation matches enforced release policy
The system SHALL document that Git tags are authoritative for release publication and release-consumer lookup, and SHALL NOT claim that aligned package versions are a mandatory gate for tag-triggered releases unless repository tooling enforces that rule again in the future.

#### Scenario: a contributor reads release documentation
- **WHEN** they review repository README or package README guidance
- **THEN** they SHALL see the same tag-authoritative release policy enforced by the tooling
