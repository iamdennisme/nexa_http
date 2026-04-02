## MODIFIED Requirements

### Requirement: Distribution package owns manifest generation rules
The system SHALL define native asset manifest descriptor fields, digest generation rules, manifest serialization behavior, artifact identity, and authoritative supported target metadata from `nexa_http_distribution` so release-time generation, federated platform implementations, runtime loading, development-mode artifact preparation, release-consumer artifact resolution, and repository verification share one authoritative implementation.

#### Scenario: Manifest schema or target support changes
- **WHEN** a manifest field, asset descriptor rule, checksum behavior, supported target definition, or artifact mode rule changes
- **THEN** release generation, platform implementation packaging, runtime loading, development-mode artifact preparation, release-consumer resolution, and verification SHALL observe the same updated schema and target metadata without duplicated rule edits

#### Scenario: Resolver needs a target identity
- **WHEN** development-mode or release-consumer resolution needs file identity, target tuple, packaging location, or fallback policy inputs for a supported platform build
- **THEN** it SHALL obtain that information from the distribution-owned target model
- **AND** repository verification SHALL be able to compare both artifact modes against that same target model
