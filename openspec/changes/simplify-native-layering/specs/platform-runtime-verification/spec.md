## MODIFIED Requirements

### Requirement: Repository verification SHALL enforce platform target agreement
The system SHALL verify that `nexa_http`, the merged internal native layer, and platform/carrier artifact producers agree on the same supported platform targets and fixed artifact mappings, and it SHALL NOT verify release identities, manifest version alignment, consumer modes, or historical compatibility paths.

#### Scenario: supported target matrix is evaluated
- **WHEN** repository verification inspects the supported platform targets
- **THEN** it SHALL detect drift between `nexa_http`, merged native-layer artifact definitions, and carrier-produced platform artifacts
- **AND** it SHALL fail with a message identifying the mismatched target definitions or fixed artifact mappings

#### Scenario: unsupported target is not declared accidentally
- **WHEN** a platform, architecture, or SDK combination is not supported by the repository
- **THEN** repository verification SHALL require that it is absent from `nexa_http`, merged native-layer definitions, and carrier artifact-production logic
- **AND** the system SHALL NOT imply support through stray loader branches, release descriptors, or compatibility-only mappings

### Requirement: Repository verification SHALL enforce shared-loader and carrier boundaries
The system SHALL verify that native loading happens through the merged internal native layer and that carrier packages remain artifact producers only, and it SHALL reject separate runtime/distribution package boundaries, generic probing behavior, version-aware logic, release-aware logic, and legacy compatibility search.

#### Scenario: merged loader contract is reviewed
- **WHEN** repository verification inspects the native loading contract
- **THEN** it SHALL allow only explicit supported-artifact loading through the merged internal layer
- **AND** it SHALL reject generic packaged, workspace, environment-driven, or legacy probing behavior
- **AND** it SHALL reject remaining imports or package boundaries that preserve `nexa_http_runtime` or `nexa_http_distribution` as architectural layers

#### Scenario: carrier package responsibility is reviewed
- **WHEN** repository verification inspects a carrier package
- **THEN** it SHALL allow platform-specific artifact production and narrowly-scoped host integration only
- **AND** it SHALL reject overlapping runtime/distribution policy, version or release logic, and historical compatibility code
