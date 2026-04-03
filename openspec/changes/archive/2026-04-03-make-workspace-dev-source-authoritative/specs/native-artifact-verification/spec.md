## MODIFIED Requirements

### Requirement: workspace-dev SHALL support local source preparation
The development-mode resolver SHALL support preparing native artifacts from repository-local source, and it SHALL treat current workspace source as authoritative rather than treating an already-existing local binary as trusted input by default.

#### Scenario: Local development artifact is missing
- **WHEN** `workspace-dev` resolves a target whose local artifact does not yet exist
- **THEN** it MUST be allowed to prepare that artifact from the local workspace source
- **AND** the preparation behavior MUST be deterministic and documented

#### Scenario: Local development artifact already exists
- **WHEN** `workspace-dev` resolves a target whose local native binary already exists
- **THEN** it MUST NOT treat that binary's mere existence as sufficient proof that it matches current workspace source
- **AND** it MUST prepare, validate, or otherwise derive the artifact from current workspace source before trusting it for repository-local development

### Requirement: Repository verification SHALL enforce mode-specific artifact expectations
Repository verification SHALL assert that target metadata, packaged assets, release assets, and resolver rules remain aligned for both operating modes.

#### Scenario: Target matrix or asset identity changes
- **WHEN** a target tuple, file name, packaging location, or release identity changes
- **THEN** verification MUST fail if `workspace-dev` and `release-consumer` expectations drift from the authoritative distribution metadata

#### Scenario: Development path uses stale local binaries
- **WHEN** repository-local development verification exercises `workspace-dev`
- **THEN** it MUST fail if repository-local demo startup can succeed by trusting a stale pre-existing local binary without source-authoritative preparation or validation
