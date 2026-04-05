## MODIFIED Requirements

### Requirement: `nexa_http` SHALL remain the only public Dart API surface
The supported integration contract SHALL expose `nexa_http` as the only public Dart API surface for application code.

#### Scenario: App imports and uses the SDK
- **WHEN** a supported app integration uses the SDK API
- **THEN** application code MUST import and call `nexa_http`
- **AND** application code MUST NOT be required to use `nexa_http_native_internal` APIs directly

### Requirement: Consumers SHALL declare platform native packages explicitly
The supported integration contract SHALL require consumers to declare the platform native packages needed for their target platforms.

#### Scenario: App declares supported platform integration
- **WHEN** a supported app integration defines its supported target platforms
- **THEN** it MUST declare `nexa_http`
- **AND** it MUST declare every corresponding `nexa_http_native_<platform>` package required by that target set
- **AND** it MUST NOT treat `nexa_http` alone as sufficient native-platform dependency declaration

### Requirement: Internal native packages SHALL remain outside the consumer contract
Internal native runtime packages and native core implementation layers SHALL NOT be part of the supported public consumer dependency contract.

#### Scenario: Consumer dependency guidance
- **WHEN** repository or package documentation explains supported dependencies
- **THEN** it MUST NOT instruct consumers to declare `nexa_http_native_internal`
- **AND** it MUST describe internal runtime/core layers as non-public implementation details
