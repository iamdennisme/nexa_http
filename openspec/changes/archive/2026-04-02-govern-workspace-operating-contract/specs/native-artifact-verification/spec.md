## MODIFIED Requirements

### Requirement: Artifact Verification Is A Release Contract
Native artifact verification SHALL remain a governed release contract and a prerequisite for publishing a supported release.

#### Scenario: Release publication is prepared
- **WHEN** the repository prepares a versioned release for external consumers
- **THEN** the governed artifact-consistency verification SHALL complete successfully before publication
- **AND** any change to the artifact verification contract SHALL require an OpenSpec change that updates the governing specs
