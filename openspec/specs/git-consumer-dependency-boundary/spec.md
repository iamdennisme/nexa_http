## ADDED Requirements

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

### Requirement: External consumers SHALL use release-consumer artifact resolution
The supported external integration path SHALL use release-consumer native artifact resolution, and it SHALL NOT implicitly depend on workspace-local paths, repository checkout layout, or Rust source compilation behavior.

#### Scenario: Consumer resolves native assets from a pinned git ref
- **WHEN** an external app runs dependency resolution and platform build steps from a supported git/ssh setup
- **THEN** native artifact resolution MUST execute in `release-consumer`
- **AND** it MUST use packaged or release-published assets looked up from that same pinned tag or selected git ref
- **AND** it MUST fail with a structured setup/bootstrap error if required assets are unavailable instead of attempting hidden local Rust compilation
- **AND** it MUST NOT derive the release URL or manifest lookup path from a locally declared package version

#### Scenario: External consumer runs near a workspace checkout
- **WHEN** an external consumer resolves runtime assets while repository-local native build outputs or source trees happen to exist on disk
- **THEN** the supported external path MUST ignore workspace-dev assumptions and workspace-local probing
- **AND** it MUST remain in `release-consumer` mode
- **AND** it MUST NOT switch to workspace-local or native-source behavior implicitly

### Requirement: External Consumer Contract Is Governed
The supported external integration model SHALL remain a governed repository contract.

#### Scenario: Maintainer changes external integration shape
- **WHEN** a maintainer proposes to change the dependency surface, federation shape, or release-consumer expectations for external apps
- **THEN** that change MUST be proposed through OpenSpec before implementation is considered complete
