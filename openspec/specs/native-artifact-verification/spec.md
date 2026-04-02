## ADDED Requirements

### Requirement: Native artifact resolution SHALL expose explicit operating modes
The workspace SHALL define explicit native artifact resolution modes for development and external consumption.

#### Scenario: Resolver selects an artifact strategy
- **WHEN** the runtime/build-hook stack resolves a native artifact
- **THEN** it MUST operate in either `workspace-dev` or `release-consumer`
- **AND** the selected mode MUST determine whether local source compilation is permitted

### Requirement: workspace-dev SHALL support local source preparation
The development-mode resolver SHALL support preparing native artifacts from repository-local source.

#### Scenario: Local development artifact is missing
- **WHEN** `workspace-dev` resolves a target whose local artifact does not yet exist
- **THEN** it MUST be allowed to prepare that artifact from the local workspace source
- **AND** the preparation behavior MUST be deterministic and documented

### Requirement: release-consumer SHALL forbid implicit local Rust compilation
The external-consumer resolver SHALL not implicitly compile native artifacts from source.

#### Scenario: External consumer lacks a packaged/released artifact
- **WHEN** `release-consumer` cannot resolve a required native artifact from packaged or release assets
- **THEN** it MUST fail verification or bootstrap with a structured artifact/setup error
- **AND** it MUST NOT invoke `cargo build` automatically

### Requirement: Repository verification SHALL enforce mode-specific artifact expectations
Repository verification SHALL assert that target metadata, packaged assets, release assets, and resolver rules remain aligned for both operating modes.

#### Scenario: Target matrix or asset identity changes
- **WHEN** a target tuple, file name, packaging location, or release identity changes
- **THEN** verification MUST fail if `workspace-dev` and `release-consumer` expectations drift from the authoritative distribution metadata

### Requirement: Artifact Verification Is A Governed Release Contract
Artifact-consistency verification SHALL remain a governed prerequisite for supported release publication.

#### Scenario: Maintainer changes artifact verification policy
- **WHEN** a maintainer proposes to weaken, bypass, or substantially redefine the repository artifact verification contract
- **THEN** that change MUST be proposed through OpenSpec before implementation is considered complete
