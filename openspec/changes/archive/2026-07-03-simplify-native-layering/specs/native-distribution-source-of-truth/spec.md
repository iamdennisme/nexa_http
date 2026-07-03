## MODIFIED Requirements

### Requirement: Distribution package SHALL own the authoritative artifact identity model
The system SHALL define supported target descriptors, artifact naming, artifact location rules, packaged artifact metadata, and explicit `workspace-dev` versus `release-consumer` source-selection rules from the merged internal native layer consumed by `nexa_http`, and it SHALL NOT use a separate `nexa_http_distribution` package or locally declared package versions as native release identity.

#### Scenario: Native artifact metadata is needed
- **WHEN** `nexa_http`, platform tooling, or carrier build logic needs supported target and artifact metadata
- **THEN** it MUST obtain that metadata from the merged internal native layer
- **AND** it MUST NOT reintroduce a separate distribution-owned architecture boundary
- **AND** it MUST use the selected Git tag/ref as release-consumer identity
- **AND** it MUST NOT derive release identity from local package version metadata

#### Scenario: Supported target definitions change
- **WHEN** a supported platform, architecture, SDK, artifact name, or packaged location changes
- **THEN** the merged internal native layer MUST remain the single source of truth for that change
- **AND** runtime loading, artifact preparation, and carrier build logic MUST consume the same updated target definition
- **AND** no duplicate target or artifact mapping logic may remain in separate runtime or distribution modules

## REMOVED Requirements

### Requirement: Distribution outputs remain stable during consolidation
**Reason**: The new architecture does not preserve release-manifest, release-identity, or consumer-mode contracts during consolidation.
**Migration**: Replace release-oriented manifest and source-selection behavior with explicit artifact metadata and fixed supported-target rules owned by the merged internal native layer.
