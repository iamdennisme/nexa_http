## ADDED Requirements

### Requirement: Test tag validation SHALL govern end-to-end tag publication
The repository SHALL define an official workflow for validating a test release tag from `develop`, including branch publication, tag publication, tag-triggered workflow observation, retry after fixes, and external consumer verification.

#### Scenario: Maintainer starts a test-tag validation run
- **WHEN** a maintainer begins a governed test-tag validation run
- **THEN** the workflow MUST define the ordered stages for publishing `develop`, publishing the test tag, observing tag-triggered automation, and running external consumer verification
- **AND** the workflow MUST identify which stages are local-only versus shared-state mutations

### Requirement: Shared-state mutations SHALL be explicit
The test-tag validation workflow SHALL explicitly mark operations that mutate shared repository state.

#### Scenario: Workflow performs remote-visible git changes
- **WHEN** the workflow pushes commits, deletes remote tags, creates remote tags, or republishes the same tag name
- **THEN** those operations MUST be treated as shared-state mutations
- **AND** the workflow MUST distinguish them from local-only setup, inspection, and temporary validation work

### Requirement: Test tag validation SHALL permit controlled same-tag retry
The repository SHALL allow a maintainer to fix failures and reissue the same test tag name until the governed success conditions are satisfied.

#### Scenario: Tag-triggered workflow fails for a governed release tag
- **WHEN** the governed tag-triggered workflow for a release tag such as `v1.0.1` fails
- **THEN** the workflow MUST allow the maintainer to repair the repository state, delete local and remote copies of that tag, and recreate the same tag at the corrected commit
- **AND** the retry loop MUST continue until the required tag-triggered workflows succeed or the maintainer stops the run
