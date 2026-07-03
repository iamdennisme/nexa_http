## MODIFIED Requirements

### Requirement: Platform runtime verification SHALL reflect explicit consumer platform selection
Repository verification SHALL treat platform package declaration as part of the supported public dependency contract.

#### Scenario: Verification checks public integration structure
- **WHEN** repository verification evaluates the supported integration model
- **THEN** it MUST model platform support as explicitly selected through consumer-declared `nexa_http_native_<platform>` dependencies
- **AND** it MUST NOT model platform support as fully implied by `nexa_http` alone

### Requirement: Verification SHALL preserve internal/native boundary isolation
Repository verification SHALL ensure internal runtime and native core layers remain outside the supported consumer dependency contract.

#### Scenario: Verification checks internal package usage
- **WHEN** repository verification inspects public integration examples or guidance
- **THEN** it MUST reject direct dependence on `nexa_http_native_internal` as a supported consumer contract
