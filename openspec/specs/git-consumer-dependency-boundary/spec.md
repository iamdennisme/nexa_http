## ADDED Requirements

### Requirement: External consumers SHALL declare `nexa_http` and target platform packages
The supported integration contract SHALL expose only `nexa_http` as the public Dart API surface for `Flutter` / `Kino` / `app`, while requiring consumers to declare the target platform carrier packages they ship.

#### Scenario: External app integrates the SDK
- **WHEN** a supported app integration consumes the SDK
- **THEN** application code MUST import `package:nexa_http/nexa_http.dart`
- **AND** its dependency declaration MUST include `nexa_http`
- **AND** its dependency declaration MUST include each required `nexa_http_native_<platform>` package
- **AND** it MUST NOT treat `nexa_http` alone as sufficient native-platform dependency declaration
- **AND** it MUST NOT be necessary to declare `nexa_http_runtime` or `nexa_http_distribution`

### Requirement: Internal native packages SHALL remain outside the consumer contract
Internal native runtime packages and native core implementation layers SHALL NOT be part of the supported public consumer dependency contract.

#### Scenario: Consumer dependency guidance
- **WHEN** repository or package documentation explains supported dependencies
- **THEN** it MUST NOT instruct consumers to declare `nexa_http_native_internal`
- **AND** it MUST describe internal runtime/core layers as non-public implementation details

### Requirement: Platform implementations SHALL remain internal to the public contract
Platform/carrier implementations SHALL remain outside the runtime API contract while acting as explicit public dependency artifacts selected by `Flutter` / `Kino` / `app`, and public integration guidance SHALL NOT rely on hidden federation defaults to choose those artifacts implicitly.

#### Scenario: Public integration describes platform choice
- **WHEN** repository or package documentation explains how platform support is chosen
- **THEN** it MUST present `nexa_http` as the only public Dart API surface
- **AND** it MUST describe platform/carrier packages as consumer-selected dependency artifacts
- **AND** it MUST NOT describe `default_package`-style implicit selection as the public contract

### Requirement: External consumers SHALL use release-consumer artifact resolution
The supported external Git ref integration path SHALL use release-consumer native artifact resolution and SHALL NOT implicitly compile Rust from local source.

#### Scenario: Git consumer resolves native assets
- **WHEN** a consumer depends on a Git tag/ref
- **THEN** native artifact resolution MUST use the selected Git tag/ref
- **AND** it MUST fail with a structured artifact error if release assets are unavailable
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
