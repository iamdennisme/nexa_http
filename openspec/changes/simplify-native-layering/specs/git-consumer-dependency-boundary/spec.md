## MODIFIED Requirements

### Requirement: External consumers SHALL declare only `nexa_http`
The supported integration contract SHALL expose only `nexa_http` as the public package surface for `Flutter` / `Kino` / `app`, and consumers SHALL NOT be required to declare platform carrier packages or any separate runtime/distribution package.

#### Scenario: External app integrates the SDK
- **WHEN** a supported app integration consumes the SDK
- **THEN** it MUST be sufficient to declare `nexa_http`
- **AND** it MUST NOT be necessary to declare platform carrier packages manually
- **AND** it MUST NOT be necessary to declare `nexa_http_runtime` or `nexa_http_distribution`

### Requirement: Platform implementations SHALL remain internal to the public contract
Platform/carrier implementations SHALL remain internal to the public package contract while exposing multiple supported artifacts that are selected by `Flutter` / `Kino` / `app`, and public integration guidance SHALL NOT rely on hidden federation defaults to choose those artifacts implicitly.

#### Scenario: Public integration describes platform choice
- **WHEN** repository or package documentation explains how platform support is chosen
- **THEN** it MUST present `nexa_http` as the only public package surface
- **AND** it MUST describe platform/carrier artifacts as consumer-selected internal implementation outputs
- **AND** it MUST NOT describe `default_package`-style implicit selection as the public contract

## REMOVED Requirements

### Requirement: External consumers SHALL use release-consumer artifact resolution
**Reason**: The new architecture removes release-consumer mode and all version/release-identity-driven artifact selection.
**Migration**: Use the explicit platform artifact-selection contract defined by `nexa_http` and the merged internal native layer.

### Requirement: External Consumer Contract Is Governed
**Reason**: The new architecture no longer models external integration through release-consumer governance and related dependency-surface rules.
**Migration**: Govern changes through the simplified `nexa_http` public-surface and platform-artifact-selection requirements instead.
