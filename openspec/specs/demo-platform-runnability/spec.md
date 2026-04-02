## ADDED Requirements

### Requirement: Repository example SHALL be the official development demo
The workspace SHALL treat `packages/nexa_http/example` as the single official development demo for supported platform debugging and Flutter-to-Rust integration validation.

#### Scenario: Repository documentation references the demo
- **WHEN** setup guidance or verification refers to the official demo
- **THEN** it MUST point to `packages/nexa_http/example`
- **AND** it MUST describe that demo as the repository development entrypoint rather than a second-class example

### Requirement: Demo SHALL use workspace-dev artifact preparation
The official demo SHALL execute the local-development native artifact path instead of the release-consumer path.

#### Scenario: Contributor runs the demo from a repository checkout
- **WHEN** a user clones the repository and follows the documented demo steps
- **THEN** the demo startup flow MUST prepare or resolve native artifacts through `workspace-dev`
- **AND** it MAY require documented local development prerequisites
- **AND** it MUST NOT require editing demo source files or demo dependency declarations

### Requirement: Demo bootstrap failures SHALL be diagnosable
The official demo SHALL surface structured bootstrap errors when native startup fails.

#### Scenario: Native startup fails during demo initialization
- **WHEN** native artifact resolution, library loading, proxy preparation, config decoding, or client creation fails
- **THEN** the demo MUST surface a structured failure with a machine-readable code and stage
- **AND** verification MUST be able to assert on those diagnostics
