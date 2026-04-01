## ADDED Requirements

### Requirement: Distribution package owns manifest generation rules
The system SHALL define native asset manifest descriptor fields, digest generation rules, and manifest serialization behavior from `nexa_http_distribution` so release-time generation and build-time consumption share one authoritative implementation.

#### Scenario: Release tooling generates a manifest
- **WHEN** repository release tooling creates `nexa_http_native_assets_manifest.json`
- **THEN** the manifest structure SHALL be produced from logic owned by `nexa_http_distribution`

#### Scenario: Manifest schema changes
- **WHEN** a manifest field, asset descriptor rule, or checksum behavior changes
- **THEN** release generation and distribution consumption SHALL observe the same updated schema without duplicated rule edits

### Requirement: Distribution outputs remain stable during consolidation
The system SHALL preserve the currently documented manifest filename and native asset descriptor naming unless a deliberate breaking release change is introduced.

#### Scenario: Existing release workflow runs after consolidation
- **WHEN** the release workflow publishes native assets
- **THEN** it SHALL continue to emit `nexa_http_native_assets_manifest.json` and the current asset filenames expected by carrier build hooks
