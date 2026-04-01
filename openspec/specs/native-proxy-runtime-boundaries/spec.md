### Requirement: Shared runtime SHALL own proxy refresh coordination
The Rust native transport implementation SHALL maintain proxy snapshot caching, generation tracking, and refresh coordination in shared runtime code rather than duplicating those responsibilities in each platform FFI crate.

#### Scenario: Platform runtime is assembled
- **WHEN** a platform FFI crate constructs the native runtime
- **THEN** it MUST assemble shared proxy refresh coordination from `nexa_http_native_core`
- **AND** it MUST NOT reimplement its own proxy snapshot cache and generation state machine in the FFI entrypoint

### Requirement: Platform crates SHALL provide proxy acquisition through explicit source modules
Each platform FFI crate SHALL provide platform-specific proxy discovery through an explicit source abstraction that is responsible for acquiring current proxy settings for that platform.

#### Scenario: Platform-specific proxy acquisition is needed
- **WHEN** the runtime needs current proxy settings for Android, iOS, macOS, or Windows
- **THEN** the request MUST be satisfied by platform-specific acquisition code
- **AND** that acquisition code MUST remain isolated from shared client rebuild and refresh coordination logic

### Requirement: Refresh policy SHALL be platform-aware
The Rust native transport runtime SHALL allow each platform proxy source to declare its refresh mode and cadence so background proxy refresh behavior can vary by platform cost and capability.

#### Scenario: Platform declares bounded polling
- **WHEN** a platform source uses polling to refresh proxy settings
- **THEN** the shared runtime MUST apply the polling cadence declared by that platform source
- **AND** it MUST NOT force every platform to use the same fixed global interval

#### Scenario: Platform has static proxy settings
- **WHEN** a platform source declares that proxy settings are static for the runtime lifetime
- **THEN** the shared runtime MUST avoid starting a background polling loop for that source

### Requirement: Android proxy refresh SHALL avoid unreasonable background cost
The Android native proxy implementation SHALL use a bounded refresh policy that avoids the current aggressive fixed high-frequency polling assumption for proxy discovery.

#### Scenario: Android runtime is idle
- **WHEN** the Android platform source is active and no requests are being executed
- **THEN** background proxy refresh behavior MUST remain bounded by the platform-declared refresh policy
- **AND** it MUST avoid a design that repeatedly spawns proxy discovery subprocesses at a high fixed frequency
