## MODIFIED Requirements

### Requirement: Release publication SHALL reuse release-consumer verification
The simplified architecture SHALL keep release-consumer verification as the publishing gate that proves Git-tag consumers can resolve native artifacts, while rejecting package-version alignment as a release identity source.

#### Scenario: Release workflow prepares native assets
- **WHEN** the release workflow is about to publish manifests or native assets for a tag
- **THEN** it MUST execute artifact-consistency verification and release-consumer verification
- **AND** release-consumer verification MUST use the consumer's selected Git tag/ref, not a locally declared package version

### Requirement: CI consumer verification SHALL enforce explicit platform dependencies
Consumer verification SHALL model public integration as `nexa_http` plus the platform carrier package required by the target host.

#### Scenario: CI validates a supported consumer app
- **WHEN** CI verifies a consumer fixture for macOS, Windows, or Android
- **THEN** the fixture MUST declare `nexa_http`
- **AND** it MUST declare the matching `nexa_http_native_<platform>` package
- **AND** application code MUST still import only `package:nexa_http/nexa_http.dart`
