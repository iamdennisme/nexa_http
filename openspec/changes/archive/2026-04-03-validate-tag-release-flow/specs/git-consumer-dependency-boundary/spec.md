## MODIFIED Requirements

### Requirement: External consumers SHALL declare only `nexa_http`
The supported external integration contract SHALL require app consumers to declare only `nexa_http` as a dependency input, including the governed tag-validation consumer check that resolves `packages/nexa_http` from a git+ssh tag reference.

#### Scenario: External app integrates the SDK through git
- **WHEN** a Flutter app outside the repository consumes the SDK through git/ssh
- **THEN** it MUST be sufficient to declare `nexa_http`
- **AND** it MUST NOT be necessary to declare platform carrier packages manually
- **AND** it MUST NOT be necessary to declare `nexa_http_runtime` or `nexa_http_distribution`

#### Scenario: Maintainer validates tag-based external consumption
- **WHEN** the governed test-tag validation workflow creates a temporary external Flutter app
- **THEN** the app MUST declare only `nexa_http` in `pubspec.yaml`
- **AND** it MUST resolve that dependency from the repository's git+ssh URL using `ref` set to the governed tag name
- **AND** the dependency path MUST target `packages/nexa_http`

### Requirement: External consumers SHALL use release-consumer artifact resolution
The supported external integration path SHALL use release-oriented native artifact resolution and SHALL NOT implicitly compile Rust from local source, including during the temporary tag-validation consumer proof.

#### Scenario: Consumer resolves native assets from a pinned git ref
- **WHEN** an external app runs dependency resolution and platform build steps from a supported git/ssh setup
- **THEN** native artifact resolution MUST execute in `release-consumer`
- **AND** it MUST use packaged or release-published assets
- **AND** it MUST fail with a structured setup/bootstrap error if required assets are unavailable instead of attempting hidden local Rust compilation
