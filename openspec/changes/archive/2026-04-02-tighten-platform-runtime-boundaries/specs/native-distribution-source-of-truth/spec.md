## MODIFIED Requirements

### Requirement: Distribution package owns manifest generation rules
The system SHALL define native asset manifest descriptor fields, digest generation rules, manifest serialization behavior, artifact identity, and the authoritative supported target matrix from `nexa_http_distribution` so release-time generation, carrier build-hook consumption, runtime loading, and verification share one authoritative implementation.

#### Scenario: Release tooling generates a manifest
- **WHEN** repository release tooling creates `nexa_http_native_assets_manifest.json`
- **THEN** the manifest structure SHALL be produced from logic owned by `nexa_http_distribution`
- **AND** the released assets SHALL correspond only to targets declared in the authoritative distribution-owned target matrix

#### Scenario: Manifest schema or target support changes
- **WHEN** a manifest field, asset descriptor rule, checksum behavior, or supported target definition changes
- **THEN** release generation, carrier build-hook consumption, runtime loading, and repository verification SHALL observe the same updated schema, artifact identity, and target matrix without duplicated rule edits

### Requirement: Distribution outputs remain stable during consolidation
The system SHALL preserve the currently documented manifest filename and native asset descriptor naming unless a deliberate breaking release change is introduced, while keeping packaged carrier assets and downloaded release assets aligned with the same supported target matrix.

#### Scenario: Existing release workflow runs after consolidation
- **WHEN** the release workflow publishes native assets
- **THEN** it SHALL continue to emit `nexa_http_native_assets_manifest.json` and the current asset filenames expected by carrier build hooks
- **AND** it SHALL fail if a required supported-target asset is missing from the authoritative matrix output

#### Scenario: Carrier build hook resolves a native artifact
- **WHEN** a carrier package needs the artifact name and target identity for a supported platform build
- **THEN** it SHALL obtain that information from the distribution-owned target model
- **AND** it SHALL NOT redefine the same target/artifact mapping locally
