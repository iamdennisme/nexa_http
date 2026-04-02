### Requirement: Repository verification SHALL enforce platform target agreement
The system SHALL verify that runtime loading, carrier-package build hooks, distribution resolution, and release artifact generation agree on the same supported platform targets and artifact identities.

#### Scenario: Supported target matrix is evaluated
- **WHEN** repository verification inspects the supported platform targets
- **THEN** it SHALL detect drift between runtime target discovery, carrier build-hook target coverage, distribution target descriptors, and release manifest descriptors
- **AND** it SHALL fail with a message identifying the mismatched target definitions

#### Scenario: Unsupported target is not declared accidentally
- **WHEN** a platform, architecture, or SDK combination is not supported by the workspace
- **THEN** repository verification SHALL require that it is absent from runtime/distribution/carrier declarations
- **AND** the system SHALL NOT imply support for that target through stray loader candidates or build-hook rules

### Requirement: Repository verification SHALL enforce runtime/carrier boundary discipline
The system SHALL verify that carrier packages do not reintroduce generic loader policy that belongs to the shared runtime layer.

#### Scenario: Carrier package runtime integration is reviewed
- **WHEN** repository verification inspects a carrier package's runtime integration
- **THEN** it SHALL allow host-specific registration and explicit loading hooks
- **AND** it SHALL reject overlapping packaged/workspace candidate-walking logic that duplicates the shared runtime loader policy
