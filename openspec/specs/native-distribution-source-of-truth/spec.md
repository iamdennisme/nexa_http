### Requirement: Distribution package SHALL own the authoritative artifact identity model
The system SHALL define native asset manifest descriptor fields, digest generation rules, manifest serialization behavior, artifact identity, the authoritative supported target matrix, and the explicit `workspace-dev` versus `release-consumer` source-selection contract from `nexa_http_distribution` so release-time generation, carrier build-hook consumption, runtime bootstrap, build tooling, and verification share one authoritative implementation.

#### Scenario: Release tooling generates a manifest
- **WHEN** repository release tooling creates `nexa_http_native_assets_manifest.json`
- **THEN** the manifest structure SHALL be produced from logic owned by `nexa_http_distribution`
- **AND** the released assets SHALL correspond only to targets declared in the authoritative distribution-owned target matrix

#### Scenario: Workspace-dev tooling prepares a native artifact
- **WHEN** repository-local development tooling prepares a native artifact for demo or local verification use
- **THEN** it SHALL derive the target identity, artifact naming, and expected descriptor fields from the distribution-owned model
- **AND** it SHALL select source artifacts through the explicit `workspace-dev` contract rather than inventing a separate artifact identity scheme

#### Scenario: Release-consumer tooling resolves a native artifact
- **WHEN** external-consumer tooling resolves a native artifact for supported release use
- **THEN** it SHALL derive the same target identity, artifact naming, and descriptor fields from the distribution-owned model
- **AND** it SHALL select source artifacts through the explicit `release-consumer` contract

#### Scenario: Manifest schema or target support changes
- **WHEN** a manifest field, asset descriptor rule, checksum behavior, supported target definition, or mode distinction changes
- **THEN** release generation, carrier build-hook consumption, runtime bootstrap, build tooling, and repository verification SHALL observe the same updated schema, artifact identity, target matrix, and source-selection contract without duplicated rule edits

### Requirement: Distribution outputs remain stable during consolidation
The system SHALL preserve the currently documented manifest filename and native asset descriptor naming unless a deliberate breaking release change is introduced, while keeping packaged carrier assets, workspace-dev artifacts, and downloaded release assets aligned with the same authoritative target and identity model.

#### Scenario: Existing release workflow runs after consolidation
- **WHEN** the release workflow publishes native assets
- **THEN** it SHALL continue to emit `nexa_http_native_assets_manifest.json` and the current asset filenames expected by carrier build hooks
- **AND** it SHALL fail if a required supported-target asset is missing from the authoritative matrix output

#### Scenario: Carrier build hook resolves a native artifact
- **WHEN** a carrier package needs the artifact name, target identity, and source-selection mode for a supported platform build
- **THEN** it SHALL obtain that information from the distribution-owned target model
- **AND** it SHALL preserve the explicit `workspace-dev` versus `release-consumer` distinction supplied by that model
- **AND** it SHALL NOT redefine the same target, artifact, or mode mapping locally
