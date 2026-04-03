### Requirement: Shared runtime loader SHALL rely on explicit runtime inputs
The shared runtime loader SHALL accept an explicit native library path from higher-level tooling and SHALL delegate to a registered host runtime when no explicit path is supplied, and it SHALL NOT implement generic packaged, workspace, or environment-driven candidate probing on its own.

#### Scenario: explicit runtime path is provided
- **WHEN** platform tooling, demo bootstrap, or another supported caller provides an explicit native library path to the shared loader
- **THEN** the loader SHALL attempt to load that exact path
- **AND** it SHALL NOT broaden the request into generic candidate discovery

#### Scenario: no explicit path is provided but a registered runtime exists
- **WHEN** no explicit native library path is provided
- **AND** a host runtime has been registered for the current platform
- **THEN** the shared loader SHALL delegate runtime acquisition to that registered runtime boundary
- **AND** it SHALL NOT walk packaged or workspace directories on its own

#### Scenario: no explicit path or registered runtime is available
- **WHEN** the shared loader receives no explicit native library path
- **AND** no host runtime has been registered for the current platform
- **THEN** it SHALL fail with a structured bootstrap error
- **AND** the failure SHALL identify the missing explicit runtime input or runtime registration

### Requirement: Platform integrations SHALL own platform-specific runtime sourcing
Carrier packages and other platform integrations SHALL own host-specific runtime preparation and registration behavior while consuming the shared loader boundary, and they SHALL NOT rely on shared generic probing behavior in `nexa_http_runtime`.

#### Scenario: carrier runtime integrates with the shared loader boundary
- **WHEN** a carrier package registers a host runtime implementation
- **THEN** that implementation SHALL provide only clearly-scoped host integration behavior such as explicit runtime preparation, runtime registration, or direct loading hooks
- **AND** it SHALL NOT reintroduce generic packaged/workspace candidate-walking logic through the shared loader contract

#### Scenario: supported platform startup is implemented
- **WHEN** a supported platform needs to start the native runtime
- **THEN** platform-specific tooling SHALL provide the explicit path or registered runtime behavior required for that platform
- **AND** the shared loader SHALL remain unaware of workspace layout or packaged artifact search policy
