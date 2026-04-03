## MODIFIED Requirements

### Requirement: Loader orchestration remains stable
The system SHALL preserve a single top-level runtime loader entrypoint that accepts an explicit library-path override for controlled testing and debugging, then delegates native-library opening to the registered platform runtime, and SHALL NOT perform generic packaged, bundle, framework, or workspace candidate probing inside the core loader.

#### Scenario: explicit path is provided
- **WHEN** the caller constructs the loader with an explicit native library path
- **THEN** the loader SHALL open that path directly
- **AND** it SHALL NOT consult the registered runtime before attempting the explicit path

#### Scenario: registered runtime is available
- **WHEN** no explicit native library path is provided and a platform runtime has been registered
- **THEN** the loader SHALL delegate native-library opening to the registered runtime
- **AND** it SHALL NOT enumerate generic candidate paths in the core loader

#### Scenario: no runtime is registered
- **WHEN** no explicit native library path is provided and no platform runtime has been registered
- **THEN** the loader SHALL fail with a structured missing-runtime error
- **AND** it SHALL instruct the consumer to add the matching `nexa_http_native_<platform>` package through the supported integration path

### Requirement: Runtime loader delegates candidate discovery by platform
The system SHALL treat platform runtime implementations as the authoritative owners of supported loading contracts, and the shared runtime layer SHALL NOT maintain cross-platform candidate-discovery policy that can drift from build-hook and packaging rules.

#### Scenario: platform runtime defines loading behavior
- **WHEN** a supported host platform registers a runtime implementation
- **THEN** that runtime SHALL define the platform-native loading entry contract for that host
- **AND** the shared runtime layer SHALL NOT duplicate equivalent generic candidate discovery for that host

#### Scenario: unsupported path compatibility is removed
- **WHEN** historical bundle, framework, or workspace path variants are not part of the documented platform runtime contract
- **THEN** the shared runtime layer SHALL NOT probe them opportunistically
- **AND** consumer startup SHALL fail rather than silently selecting an undocumented binary
