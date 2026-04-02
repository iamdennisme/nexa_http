## ADDED Requirements

### Requirement: Governed Workflow Contracts
The repository SHALL treat its official development, packaging, release, and external-consumer workflows as governed operating contracts rather than incidental implementation details.

#### Scenario: Maintainer identifies governed workflows
- **WHEN** a maintainer reviews the repository operating contract
- **THEN** the contract SHALL identify the official development-path, release-consumer-path, artifact-verification, and release-publication workflows

### Requirement: OpenSpec Required For Contract Changes
Changes to governed workflow behavior SHALL be proposed and reviewed through OpenSpec before implementation lands.

#### Scenario: Workflow behavior change is proposed
- **WHEN** a maintainer wants to change a governed debugging, packaging, release, CI, or consumer-integration workflow
- **THEN** the change SHALL include an OpenSpec proposal that updates the relevant governance requirements before or alongside implementation

### Requirement: Official Operating Entrypoints
The repository SHALL provide stable official entrypoints for governed workflows so maintainers and future sessions do not need to rediscover or reinvent the process.

#### Scenario: Maintainer needs the official verification entrypoints
- **WHEN** a maintainer consults the operating contract
- **THEN** the contract SHALL point to the repository-owned commands that verify development-path, release-consumer-path, artifact-consistency, and release-version alignment

### Requirement: Reusable Workflow Model
The operating contract SHALL define the repository model in a way that can be adopted by future repositories without renegotiating its core lifecycle.

#### Scenario: Team wants to apply the same model in another repository
- **WHEN** maintainers adopt this workspace pattern in a new repository
- **THEN** the operating contract SHALL provide stable principles for local development mode, external consumer mode, artifact publication, and change governance
