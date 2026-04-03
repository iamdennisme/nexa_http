### Requirement: Repository verification SHALL enforce platform target agreement
The system SHALL verify that shared runtime loading, carrier-package build hooks, workspace-dev preparation, release-consumer resolution, distribution descriptors, and release artifact generation agree on the same supported platform targets and artifact identities.

#### Scenario: supported target matrix is evaluated
- **WHEN** repository verification inspects the supported platform targets
- **THEN** it SHALL detect drift between carrier build-hook target coverage, workspace-dev artifact preparation, release-consumer artifact resolution, distribution target descriptors, and release manifest descriptors
- **AND** it SHALL fail with a message identifying the mismatched target definitions or artifact identities

#### Scenario: unsupported target is not declared accidentally
- **WHEN** a platform, architecture, or SDK combination is not supported by the workspace
- **THEN** repository verification SHALL require that it is absent from runtime, carrier, workspace-dev, and release-consumer declarations
- **AND** the system SHALL NOT imply support for that target through stray loader registrations, artifact descriptors, or build-hook rules

### Requirement: Repository verification SHALL enforce shared-loader and carrier boundaries
The system SHALL verify that the shared runtime loader only consumes explicit runtime inputs or registered runtime delegation, and that carrier packages do not reintroduce generic loader policy that belongs outside the shared loader boundary.

#### Scenario: shared loader contract is reviewed
- **WHEN** repository verification inspects the shared loader integration contract
- **THEN** it SHALL allow explicit-path loading and registered-runtime delegation
- **AND** it SHALL reject generic packaged, workspace, or environment-driven probing behavior in the shared loader layer

#### Scenario: carrier package runtime integration is reviewed
- **WHEN** repository verification inspects a carrier package's runtime integration
- **THEN** it SHALL allow host-specific preparation, registration, and explicit loading hooks
- **AND** it SHALL reject overlapping candidate-walking or boundary-blurring logic that assumes the shared loader will probe workspace or packaged locations implicitly
