## MODIFIED Requirements

### Requirement: CI consumer verification SHALL validate the explicit dependency contract
CI consumer verification SHALL validate that supported consumer integrations declare `nexa_http` together with every platform native package required by the integration's supported target platforms.

#### Scenario: CI validates a supported consumer app
- **WHEN** CI verifies a consumer fixture for macOS, Windows, or Android
- **THEN** the fixture MUST declare `nexa_http`
- **AND** it MUST declare the matching `nexa_http_native_<platform>` package
- **AND** application code MUST still import only `package:nexa_http/nexa_http.dart`
- **AND** it MUST NOT depend on `nexa_http_native_internal`

### Requirement: CI SHALL distinguish API surface from dependency artifacts
CI validation SHALL not treat "only public API surface" as equivalent to "only declared package dependency".

#### Scenario: CI checks integration contract terminology
- **WHEN** CI or structural verification validates repository expectations
- **THEN** it MUST preserve the distinction between:
  - `nexa_http` as the public Dart API surface
  - platform native packages as public dependency artifacts

### Requirement: Release publication SHALL reuse release-consumer verification
The simplified architecture SHALL keep release-consumer verification as the publishing gate that proves Git-ref consumers can resolve native artifacts, while rejecting package-version alignment as a release identity source.

#### Scenario: Release workflow prepares native assets
- **WHEN** the release workflow is about to publish manifests or native assets for a tag or selected release ref
- **THEN** it MUST execute artifact-consistency verification and release-consumer verification
- **AND** release-consumer verification MUST use the consumer's selected Git tag/ref, not a locally declared package version
- **AND** publication MUST NOT rely on a separate unpublished rule set

#### Scenario: Release publication evaluates metadata drift
- **WHEN** artifact-consistency and release-consumer verification succeed for a selected release ref
- **THEN** publication MUST continue even if aligned workspace package versions differ from that ref
- **AND** package-version drift MUST NOT be treated as a release-blocking publish failure
