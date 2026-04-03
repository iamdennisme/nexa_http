## MODIFIED Requirements

### Requirement: Official Operating Entrypoints
The repository SHALL provide stable official entrypoints for governed workflows so maintainers and future sessions do not need to rediscover or reinvent the process, and repository-level documentation MUST point readers to the current verification, release-tag, and maintainer entrypoints in a way that matches the current workflow surface.

#### Scenario: Maintainer needs the official verification entrypoints
- **WHEN** a maintainer consults the operating contract or top-level repository documentation
- **THEN** the documentation SHALL point to the repository-owned commands or procedures that verify development-path, release-consumer-path, artifact-consistency, release-version alignment, and test-tag validation
- **AND** those entrypoints MUST match the current repository workflow surface
