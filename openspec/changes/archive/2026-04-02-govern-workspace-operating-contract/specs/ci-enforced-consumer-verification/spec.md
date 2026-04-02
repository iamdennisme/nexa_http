## MODIFIED Requirements

### Requirement: CI Blocks On Contract Verification
The repository SHALL run merge-blocking CI that verifies the governed development-path, release-consumer-path, and artifact-consistency contracts on the required hosts.

#### Scenario: Pull request changes repository workflow behavior
- **WHEN** a pull request changes code, scripts, workflow files, or package wiring that could affect the development-path, release-consumer-path, or artifact-consistency contracts
- **THEN** CI SHALL run the repository's official verification commands for those contracts
- **AND** the pull request SHALL remain non-mergeable if any governed verification fails
