## MODIFIED Requirements

### Requirement: Demo Startup Is A Governed Development Contract
The official repository demo SHALL remain a governed development-path contract that can be started without source or pubspec edits on supported platforms.

#### Scenario: Maintainer runs the official demo
- **WHEN** a maintainer follows the documented demo startup path on a supported platform
- **THEN** the demo SHALL use the governed development-path workflow
- **AND** any change to that startup workflow SHALL require an OpenSpec change that updates the governing specs
