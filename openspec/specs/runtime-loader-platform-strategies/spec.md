### Requirement: Runtime loader delegates candidate discovery by platform
The system SHALL separate runtime candidate discovery into explicit host-platform strategy modules instead of concentrating all candidate rules in one aggregated cross-platform file.

#### Scenario: macOS candidate discovery runs
- **WHEN** the runtime loader needs macOS dynamic-library candidates
- **THEN** it SHALL obtain them from the macOS-specific strategy implementation

#### Scenario: Windows candidate discovery runs
- **WHEN** the runtime loader needs Windows dynamic-library candidates
- **THEN** it SHALL obtain them from the Windows-specific strategy implementation

#### Scenario: Android candidate discovery runs
- **WHEN** the runtime loader needs Android dynamic-library candidates
- **THEN** it SHALL obtain them from the Android-specific strategy implementation, even if that strategy only returns a fixed candidate set

### Requirement: Loader orchestration remains stable
The system SHALL preserve a single top-level runtime loader entrypoint that applies explicit-path override, environment override, candidate probing, and registered-runtime fallback in the documented order.

#### Scenario: no explicit or discovered library exists
- **WHEN** no explicit path, environment override, or candidate path can be opened
- **THEN** the loader SHALL fall back to the registered runtime before throwing an error
