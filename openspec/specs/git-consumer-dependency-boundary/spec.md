## ADDED Requirements

### Requirement: External consumers SHALL declare only `nexa_http`
The supported external integration contract SHALL require app consumers to declare only `nexa_http` as a dependency input, and repository/package documentation MUST present that public integration path clearly and accurately, including the current git+ssh tag-based consumption shape.

#### Scenario: External app integrates the SDK through git
- **WHEN** a Flutter app outside the repository consumes the SDK through git/ssh
- **THEN** it MUST be sufficient to declare `nexa_http`
- **AND** it MUST NOT be necessary to declare platform carrier packages manually
- **AND** it MUST NOT be necessary to declare `nexa_http_runtime` or `nexa_http_distribution`

#### Scenario: Documentation explains external tag consumption
- **WHEN** repository or package documentation shows how to consume the SDK from git/ssh
- **THEN** it MUST use the public `nexa_http` package surface
- **AND** it MUST describe the current tag-based `ref` and `path: packages/nexa_http` contract accurately

### Requirement: Platform implementations SHALL remain internal to the public contract
Platform carrier packages SHALL be selected through the plugin/federation wiring owned by `nexa_http`, not through public setup instructions.

#### Scenario: Public documentation describes platform integration
- **WHEN** README or package documentation explains how to integrate the SDK
- **THEN** it MUST present `nexa_http` as the public package surface
- **AND** it MUST NOT instruct users to add platform carrier packages as public dependencies

### Requirement: External consumers SHALL use release-consumer artifact resolution
The supported external integration path SHALL use release-oriented native artifact resolution and SHALL NOT implicitly compile Rust from local source, including during the temporary tag-validation consumer proof.

#### Scenario: Consumer resolves native assets from a pinned git ref
- **WHEN** an external app runs dependency resolution and platform build steps from a supported git/ssh setup
- **THEN** native artifact resolution MUST execute in `release-consumer`
- **AND** it MUST use packaged or release-published assets
- **AND** it MUST fail with a structured setup/bootstrap error if required assets are unavailable instead of attempting hidden local Rust compilation

### Requirement: External Consumer Contract Is Governed
The supported external integration model SHALL remain a governed repository contract.

#### Scenario: Maintainer changes external integration shape
- **WHEN** a maintainer proposes to change the dependency surface, federation shape, or release-consumer expectations for external apps
- **THEN** that change MUST be proposed through OpenSpec before implementation is considered complete
