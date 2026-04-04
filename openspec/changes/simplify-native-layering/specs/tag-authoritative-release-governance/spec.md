## REMOVED Requirements

### Requirement: Git tag SHALL be the authoritative release identity
**Reason**: The simplified native architecture removes tag-authoritative release identity from native integration, artifact lookup, and verification behavior.
**Migration**: Remove tag-derived release identity logic and keep native artifact selection based only on explicit supported artifact definitions.
