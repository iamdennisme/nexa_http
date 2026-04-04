## MODIFIED Requirements

### Requirement: Distribution package SHALL own the authoritative artifact identity model
The system SHALL define supported target descriptors, artifact naming, artifact location rules, and packaged artifact metadata from a single merged internal native layer consumed by `nexa_http`, and it SHALL NOT define release identity, authoritative tag selection, package-version-derived manifest lookup, or explicit `workspace-dev` versus `release-consumer` source-selection modes.

#### Scenario: Native artifact metadata is needed
- **WHEN** `nexa_http`, platform tooling, or carrier build logic needs supported target and artifact metadata
- **THEN** it MUST obtain that metadata from the merged internal native layer
- **AND** it MUST NOT reintroduce a separate distribution-owned architecture boundary
- **AND** it MUST NOT encode tag, version, release identity, or consumer mode semantics

#### Scenario: Supported target definitions change
- **WHEN** a supported platform, architecture, SDK, artifact name, or packaged location changes
- **THEN** the merged internal native layer MUST remain the single source of truth for that change
- **AND** runtime loading, artifact preparation, and carrier build logic MUST consume the same updated target definition
- **AND** no duplicate target or artifact mapping logic may remain in separate runtime or distribution modules

## REMOVED Requirements

### Requirement: Distribution outputs remain stable during consolidation
**Reason**: The new architecture does not preserve release-manifest, release-identity, or consumer-mode contracts during consolidation.
**Migration**: Replace release-oriented manifest and source-selection behavior with explicit artifact metadata and fixed supported-target rules owned by the merged internal native layer.
