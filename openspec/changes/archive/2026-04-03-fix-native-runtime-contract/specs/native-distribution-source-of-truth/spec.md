## MODIFIED Requirements

### Requirement: Distribution outputs remain stable during consolidation
The system SHALL preserve the currently documented manifest filename and native asset descriptor naming unless a deliberate breaking release change is introduced, while keeping packaged carrier assets, downloaded release assets, and runtime loading aligned to the same authoritative artifact identity rules.

#### Scenario: Existing release workflow runs after consolidation
- **WHEN** the release workflow publishes native assets
- **THEN** it SHALL continue to emit `nexa_http_native_assets_manifest.json` and the current asset filenames expected by carrier build hooks
- **AND** it SHALL fail if a required supported-target asset is missing from the authoritative matrix output
- **AND** runtime loading SHALL continue to target the same governed artifact identities instead of inventing parallel path conventions

#### Scenario: Carrier build hook resolves a native artifact
- **WHEN** a carrier package needs the artifact name and target identity for a supported platform build
- **THEN** it SHALL obtain that information from the distribution-owned target model
- **AND** it SHALL NOT redefine the same target/artifact mapping locally
- **AND** it SHALL distinguish external-consumer artifact resolution from workspace-dev artifact preparation explicitly instead of relying on fallback ordering
