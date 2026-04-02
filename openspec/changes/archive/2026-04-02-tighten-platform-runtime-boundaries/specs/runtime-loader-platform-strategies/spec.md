## MODIFIED Requirements

### Requirement: Runtime loader delegates candidate discovery by platform
The system SHALL separate runtime candidate discovery into explicit host-platform strategy modules instead of concentrating all candidate rules in one aggregated cross-platform file, and each strategy SHALL derive its supported target coverage and artifact identity rules from the authoritative platform target matrix used by carrier packaging and distribution.

#### Scenario: macOS candidate discovery runs
- **WHEN** the runtime loader needs macOS dynamic-library candidates
- **THEN** it SHALL obtain them from the macOS-specific strategy implementation
- **AND** that strategy SHALL only enumerate candidates for targets declared as supported by the authoritative platform target matrix

#### Scenario: Windows candidate discovery runs
- **WHEN** the runtime loader needs Windows dynamic-library candidates
- **THEN** it SHALL obtain them from the Windows-specific strategy implementation
- **AND** that strategy SHALL NOT imply support for toolchains or architectures that the authoritative platform target matrix does not declare

#### Scenario: Android candidate discovery runs
- **WHEN** the runtime loader needs Android dynamic-library candidates
- **THEN** it SHALL obtain them from the Android-specific strategy implementation
- **AND** the fixed candidate set SHALL remain aligned with the authoritative platform target matrix used by carrier packaging

### Requirement: Loader orchestration remains stable
The system SHALL preserve a single top-level runtime loader entrypoint that applies explicit-path override, environment override, candidate probing, and registered-runtime fallback in the documented order, and carrier runtimes SHALL NOT maintain overlapping broad candidate-walking logic that can drift from this orchestration.

#### Scenario: no explicit or discovered library exists
- **WHEN** no explicit path, environment override, or candidate path can be opened
- **THEN** the loader SHALL fall back to the registered runtime before throwing an error

#### Scenario: carrier runtime integrates with the host loader boundary
- **WHEN** a carrier package registers a host runtime implementation
- **THEN** that implementation SHALL use only clearly-scoped host integration behavior
- **AND** it SHALL NOT duplicate the runtime loader's broad packaged/workspace candidate search policy

#### Scenario: runtime loader owns generic discovery
- **WHEN** the system needs packaged or workspace candidate walking for a supported host platform
- **THEN** that behavior SHALL be implemented in `nexa_http_runtime`
- **AND** carrier packages SHALL consume that boundary instead of redefining equivalent generic search logic
