## MODIFIED Requirements

### Requirement: External consumers SHALL use release-consumer artifact resolution
The supported external integration path SHALL use release-oriented native artifact resolution and SHALL NOT implicitly compile Rust from local source, inspect workspace-local target outputs, or infer workspace-dev behavior during dependency resolution, build-hook execution, or runtime startup.

#### Scenario: Consumer resolves native assets from a pinned git ref
- **WHEN** an external app runs dependency resolution and platform build steps from a supported git/ssh setup
- **THEN** native artifact resolution MUST execute in `release-consumer`
- **AND** it MUST use packaged or release-published assets
- **AND** it MUST fail with a structured setup/bootstrap error if required assets are unavailable instead of attempting hidden local Rust compilation or workspace-local binary selection

#### Scenario: Consumer machine contains unrelated local workspace outputs
- **WHEN** an external app build runs on a machine that also contains local `nexa_http` repository build outputs
- **THEN** external-consumer artifact resolution MUST ignore those workspace-local outputs
- **AND** runtime startup MUST NOT depend on repository-relative candidate discovery
