## MODIFIED Requirements

### Requirement: Repository verification SHALL enforce runtime/carrier boundary discipline
The system SHALL verify that carrier packages own only platform-specific runtime opening contracts and build-time artifact preparation, while the shared runtime layer owns only loader orchestration, and no layer SHALL duplicate generic packaged/workspace candidate-walking behavior.

#### Scenario: Carrier package runtime integration is reviewed
- **WHEN** repository verification inspects a carrier package's runtime integration
- **THEN** it SHALL allow host-specific runtime registration and fixed platform entry logic
- **AND** it SHALL reject packaged/workspace candidate-walking logic that duplicates shared loader policy or revives legacy discovery behavior

#### Scenario: Shared loader integration is reviewed
- **WHEN** repository verification inspects the shared loader implementation
- **THEN** it SHALL require the loader to delegate to the registered runtime after any explicit override
- **AND** it SHALL reject generic candidate probing implemented in the shared runtime layer

### Requirement: Repository verification SHALL enforce platform target agreement
The system SHALL verify that runtime loading contracts, carrier-package build hooks, distribution resolution, and release artifact generation agree on the same supported platform targets and documented artifact identities.

#### Scenario: Supported target matrix is evaluated
- **WHEN** repository verification inspects the supported platform targets
- **THEN** it SHALL detect drift between runtime contracts, carrier build-hook target coverage, distribution target descriptors, and release manifest descriptors
- **AND** it SHALL fail with a message identifying the mismatched target definitions or artifact identities

#### Scenario: Unsupported target is not declared accidentally
- **WHEN** a platform, architecture, or SDK combination is not supported by the workspace
- **THEN** repository verification SHALL require that it is absent from runtime/build-hook/distribution declarations
- **AND** the system SHALL NOT imply support for that target through stray runtime probing or build-hook rules
