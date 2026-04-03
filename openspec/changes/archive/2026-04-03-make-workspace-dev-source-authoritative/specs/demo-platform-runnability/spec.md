## MODIFIED Requirements

### Requirement: Demo SHALL use workspace-dev artifact preparation
The official demo SHALL execute the local-development native artifact path instead of the release-consumer path, and that `workspace-dev` path SHALL prepare or validate native artifacts from current repository source rather than trusting pre-existing local binaries as authoritative input.

#### Scenario: Contributor runs the demo from a repository checkout
- **WHEN** a user clones the repository and follows the documented demo steps
- **THEN** the demo startup flow MUST prepare or resolve native artifacts through `workspace-dev`
- **AND** it MAY require documented local development prerequisites
- **AND** it MUST NOT require editing demo source files or demo dependency declarations

#### Scenario: Repository contains stale local native binaries
- **WHEN** repository-local demo startup runs in `workspace-dev` and stale local native binaries are present from an older source state
- **THEN** the demo MUST NOT trust those binaries solely because they already exist
- **AND** it MUST use current repository source as the authoritative development input
