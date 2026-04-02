## MODIFIED Requirements

### Requirement: External Consumer Model Is Governed
The external git consumer dependency boundary SHALL remain a governed repository contract.

#### Scenario: Maintainer changes how external apps integrate
- **WHEN** a maintainer proposes to change the dependency model, package entrypoint, or artifact-resolution expectations for external git consumers
- **THEN** that change SHALL require an OpenSpec change that updates the governed dependency-boundary requirements before implementation is considered complete
