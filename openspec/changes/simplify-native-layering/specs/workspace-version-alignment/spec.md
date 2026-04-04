## REMOVED Requirements

### Requirement: Workspace package versions stay aligned
**Reason**: The simplified native architecture forbids version-aware module coordination and removes lockstep package-version governance as a repository contract.
**Migration**: Delete version-alignment verification and documentation; treat remaining package metadata as non-architectural and keep native integration logic version-agnostic.

### Requirement: Release tags match aligned package versions
**Reason**: The new architecture removes tag-driven native identity and package-version alignment as behavioral requirements.
**Migration**: Delete release-tag/package-version comparison logic and any release gating that depends on aligned package versions.

### Requirement: Documentation matches enforced release policy
**Reason**: The repository will no longer enforce a release policy built around aligned package versions.
**Migration**: Rewrite docs to describe the simplified public surface and explicit platform artifact model instead of version alignment.
