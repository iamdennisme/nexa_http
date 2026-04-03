## MODIFIED Requirements

### Requirement: Distribution outputs remain stable during consolidation
The system SHALL preserve the currently documented manifest filename and native asset descriptor naming unless a deliberate breaking release change is introduced, while keeping packaged carrier assets, workspace-dev artifacts, and downloaded release assets aligned with the same authoritative target and identity model.

#### Scenario: Existing release workflow runs after consolidation
- **WHEN** the release workflow publishes native assets for a release tag
- **THEN** it SHALL continue to emit `nexa_http_native_assets_manifest.json` and the current asset filenames expected by carrier build hooks
- **AND** it SHALL derive release manifest version identity from the triggering Git tag
- **AND** it SHALL fail if a required supported-target asset is missing from the authoritative matrix output

#### Scenario: Carrier build hook resolves a native artifact
- **WHEN** a carrier package needs the artifact name, target identity, and source-selection mode for a supported platform build
- **THEN** it SHALL obtain that information from the distribution-owned target model
- **AND** it SHALL preserve the explicit `workspace-dev` versus `release-consumer` distinction supplied by that model
- **AND** it SHALL NOT redefine the same target, artifact, or mode mapping locally
