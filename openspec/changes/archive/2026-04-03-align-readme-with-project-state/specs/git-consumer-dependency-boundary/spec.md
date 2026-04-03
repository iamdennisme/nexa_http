## MODIFIED Requirements

### Requirement: External consumers SHALL declare only `nexa_http`
The supported external integration contract SHALL require app consumers to declare only `nexa_http` as a dependency input, and repository/package documentation MUST present that public integration path clearly and accurately, including the current git+ssh tag-based consumption shape.

#### Scenario: External app integrates the SDK through git
- **WHEN** a Flutter app outside the repository consumes the SDK through git/ssh
- **THEN** it MUST be sufficient to declare `nexa_http`
- **AND** it MUST NOT be necessary to declare platform carrier packages manually
- **AND** it MUST NOT be necessary to declare `nexa_http_runtime` or `nexa_http_distribution`

#### Scenario: Documentation explains external tag consumption
- **WHEN** repository or package documentation shows how to consume the SDK from git/ssh
- **THEN** it MUST use the public `nexa_http` package surface
- **AND** it MUST describe the current tag-based `ref` and `path: packages/nexa_http` contract accurately
