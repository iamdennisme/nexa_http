## MODIFIED Requirements

### Requirement: External consumers SHALL use release-consumer artifact resolution
The supported external integration path SHALL use release-consumer native artifact resolution, and tag-triggered consumer validation SHALL treat the Git tag as the authoritative release identity instead of relying on aligned workspace package versions.

#### Scenario: Consumer resolves native assets from a pinned git ref
- **WHEN** an external app runs dependency resolution and platform build steps from a supported git/ssh setup
- **THEN** native artifact resolution MUST execute in `release-consumer`
- **AND** it MUST use packaged or release-published assets
- **AND** it MUST fail with a structured setup/bootstrap error if required assets are unavailable instead of attempting hidden local Rust compilation

#### Scenario: External consumer runs near a workspace checkout
- **WHEN** an external consumer resolves runtime assets while repository-local native build outputs or source trees happen to exist on disk
- **THEN** the supported external path MUST ignore workspace-dev assumptions and workspace-local probing
- **AND** it MUST remain in `release-consumer` mode
- **AND** it MUST NOT switch to workspace-local or native-source behavior implicitly

#### Scenario: Tag consumer verification runs for publication
- **WHEN** repository tooling validates a tagged consumer flow before or during release publication
- **THEN** it MUST use the Git tag as the release identity presented to the consumer path
- **AND** it MUST NOT require aligned workspace package versions as an additional publication gate
