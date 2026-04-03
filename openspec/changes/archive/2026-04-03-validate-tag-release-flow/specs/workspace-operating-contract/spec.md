## MODIFIED Requirements

### Requirement: Governed Workflow Contracts
The repository SHALL treat its official development, packaging, release, external-consumer, and test-tag validation workflows as governed operating contracts rather than incidental implementation details.

#### Scenario: Maintainer identifies governed workflows
- **WHEN** a maintainer reviews the repository operating contract
- **THEN** the contract SHALL identify the official development-path, release-consumer-path, artifact-verification, release-publication, and test-tag-validation workflows

### Requirement: Official Operating Entrypoints
The repository SHALL provide stable official entrypoints for governed workflows so maintainers and future sessions do not need to rediscover or reinvent the process.

#### Scenario: Maintainer needs the official verification entrypoints
- **WHEN** a maintainer consults the operating contract
- **THEN** the contract SHALL point to the repository-owned commands or procedures that verify development-path, release-consumer-path, artifact-consistency, release-version alignment, and test-tag validation

### Requirement: OpenSpec Required For Contract Changes
Changes to governed workflow behavior SHALL be proposed and reviewed through OpenSpec before implementation lands.

#### Scenario: Workflow behavior change is proposed
- **WHEN** a maintainer wants to change a governed debugging, packaging, release, CI, consumer-integration, or test-tag validation workflow
- **THEN** the change SHALL include an OpenSpec proposal that updates the relevant governance requirements before or alongside implementation
