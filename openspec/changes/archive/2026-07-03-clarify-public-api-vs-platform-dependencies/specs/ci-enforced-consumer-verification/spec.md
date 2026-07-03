## MODIFIED Requirements

### Requirement: CI consumer verification SHALL validate the explicit dependency contract
CI consumer verification SHALL validate that supported consumer integrations declare `nexa_http` together with every platform native package required by the integration's supported target platforms.

#### Scenario: CI validates a supported consumer app
- **WHEN** CI verifies a supported consumer integration
- **THEN** the integration MUST declare `nexa_http`
- **AND** it MUST declare the relevant `nexa_http_native_<platform>` package(s)
- **AND** it MUST NOT depend on `nexa_http_native_internal`

### Requirement: CI SHALL distinguish API surface from dependency artifacts
CI validation SHALL not treat “only public API surface” as equivalent to “only declared package dependency”.

#### Scenario: CI checks integration contract terminology
- **WHEN** CI or structural verification validates repository expectations
- **THEN** it MUST preserve the distinction between:
  - `nexa_http` as the public API surface
  - platform native packages as public dependency artifacts
