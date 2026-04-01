### Requirement: Workspace package versions stay aligned
The system SHALL verify that these seven release-train packages use the same semantic version for a coordinated release: `nexa_http`, `nexa_http_runtime`, `nexa_http_distribution`, `nexa_http_native_android`, `nexa_http_native_ios`, `nexa_http_native_macos`, and `nexa_http_native_windows`. The check SHALL exclude `packages/nexa_http/example`.

#### Scenario: one package version drifts
- **WHEN** repository verification runs and one aligned package declares a different version
- **THEN** verification SHALL fail with a message identifying the mismatched package versions

#### Scenario: release preparation runs
- **WHEN** a coordinated workspace release is prepared
- **THEN** the version-alignment check SHALL pass before release steps proceed

### Requirement: Release tags match aligned package versions
The system SHALL verify that repository release tags resolve to the same semantic version declared by the seven aligned workspace packages.

#### Scenario: release tag does not match package versions
- **WHEN** release preparation runs for a tag whose semantic version differs from the aligned package versions
- **THEN** release verification SHALL fail before native assets or package artifacts are published

### Requirement: Documentation matches enforced release policy
The system SHALL document the same lockstep versioning rule that repository verification enforces.

#### Scenario: a contributor reads release documentation
- **WHEN** they review repository README or package README guidance
- **THEN** they SHALL see the same aligned-package release policy enforced by the tooling
