## MODIFIED Requirements

### Requirement: Shared runtime loader SHALL rely on explicit runtime inputs
The merged native loader SHALL load only explicitly selected supported platform artifacts from the merged internal native layer, and it SHALL NOT delegate to a separate distribution layer, registered runtime fallback boundary, generic packaged/workspace probing, environment-driven candidate discovery, or historical path search.

#### Scenario: Explicit supported artifact is selected
- **WHEN** `nexa_http` or supported platform integration selects a supported native artifact
- **THEN** the loader MUST load that exact artifact location
- **AND** it MUST NOT broaden the request into candidate discovery or fallback probing

#### Scenario: No supported artifact is selected
- **WHEN** runtime bootstrap starts without an explicit supported artifact selection
- **THEN** bootstrap MUST fail with a structured error
- **AND** it MUST identify the missing platform artifact selection
- **AND** it MUST NOT search packaged directories, workspace paths, legacy names, or environment hints

### Requirement: Platform integrations SHALL own platform-specific runtime sourcing
Platform integrations and carrier packages SHALL provide only the narrowly-scoped host-specific work required to expose supported artifacts to the merged native loader, and they SHALL NOT implement a separate runtime/distribution boundary, generic probing policy, or historical compatibility search.

#### Scenario: Platform integration prepares a runtime artifact
- **WHEN** a platform integration exposes a supported artifact to the merged native loader
- **THEN** it MUST provide only the explicit host-specific path or binding required for that artifact
- **AND** it MUST NOT reintroduce generic packaged/workspace candidate walking
- **AND** it MUST NOT depend on a separate `nexa_http_runtime` package surface
