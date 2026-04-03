## Context

The repository already has governed development-path and release-consumer verification, but the specific workflow for publishing a test tag from `develop`, observing tag-triggered automation, and proving external git+ssh tag consumption is still implicit. This gap matters because the workflow includes destructive shared-state operations such as deleting remote tags and reusing the same tag name after fixes, and those operations need an agreed retry contract before implementation can automate them.

The requested flow has four distinct phases:
- prepare and publish repository state (`push` + tag lifecycle changes)
- observe remote GitHub Actions triggered by the tag
- if automation fails, repair the repository and reissue the same tag name
- only after automation succeeds, prove the tag is consumable from a temporary external Flutter app using `pubspec.yaml` git+ssh tag resolution

Those phases cross local git state, remote git state, GitHub Actions, and external-consumer setup. They also introduce a success-loop requirement: a maintainer may intentionally reuse the same governed release tag (for example `v1.0.1`) until the tag-triggered workflow is green.

## Goals / Non-Goals

**Goals:**
- Define the official workflow for publishing a test tag from `develop` and validating it end to end.
- Make shared-state mutations explicit so maintainers know which steps affect only local state and which steps affect the remote repository.
- Define the success standard for a tag validation run in terms of tag-triggered GitHub Actions completion.
- Define the retry loop for fixing failures and reissuing the same tag name until automation succeeds.
- Define a minimal, reproducible external consumer verification using a temporary Flutter app outside the repository.
- Define cleanup expectations for that temporary demo.

**Non-Goals:**
- Redesigning the release asset contents or target matrix.
- Replacing the existing release workflows with a different CI/CD system.
- Expanding external-consumer verification beyond the minimum needed to prove git+ssh tag consumption.
- Governing arbitrary versioning strategy beyond this test-tag validation flow.

## Decisions

### 1. Treat shared-state mutations as first-class workflow boundaries
The workflow will explicitly classify steps into local-only and shared-state operations.

Shared-state operations include:
- pushing `develop`
- deleting remote tags
- publishing tag `v1.0.1`
- republishing the same tag name after fixes

Why:
- These actions affect other maintainers and consumers immediately.
- They need stronger confirmation semantics than local-only validation work.

Alternatives considered:
- Treat the whole flow as one homogeneous automation sequence. Rejected because it obscures when the workflow crosses from reversible local work into remote-visible mutation.

### 2. Define tag success by required tag-triggered workflow completion
The workflow will define a release-test tag as successful only when the repository's required tag-triggered GitHub Actions complete successfully for that tag.

Why:
- A pushed tag is not useful by itself; the automation it triggers is part of the contract.
- External consumer validation should happen only after the repository proves the tag is internally publishable/usable.

Alternatives considered:
- Treat local tests or the existence of the tag as sufficient. Rejected because the user explicitly wants online action success as the gate.

### 3. Allow controlled reissue of the same tag name
The workflow will allow deleting and recreating the same governed release tag (for example `v1.0.1`) after fixes until the required tag-triggered workflows succeed.

Why:
- This is the requested operating mode for pre-release/test-tag validation.
- It keeps the validation target stable for the temporary external consumer.

Alternatives considered:
- Require monotonically increasing tags for each retry. Rejected because it changes the requested loop and makes the validation target drift.

### 4. Scope external verification to a minimal temporary consumer
The external validation target will be a temporary Flutter app created outside the repository that depends on `packages/nexa_http` via git+ssh and `ref` set to the governed release tag (for example `v1.0.1`) in `pubspec.yaml`.

The minimum success bar is:
- dependency resolution succeeds from the tag
- the consumer declares only `nexa_http`
- the app can complete the minimum configured `flutter pub get` and build/test step required by the governed workflow
- the temporary app is deleted after verification

Why:
- This proves the public git+ssh tag contract without polluting the repository.
- It limits verification to the smallest useful external-consumer check.

Alternatives considered:
- Keep verification inside the repository. Rejected because it does not prove an external consumer setup.
- Build a full-featured demo app. Rejected because the goal is tag consumability, not product demo quality.

## Risks / Trade-offs

- [Deleting all remote tags can break existing consumers or collaborator workflows] → Mitigation: treat remote tag deletion as an explicit governed shared-state operation and document it as high-risk.
- [Reusing the same tag name can make debugging historical failures harder] → Mitigation: rely on GitHub Actions run history and commit references for traceability during the retry loop.
- [Tag-triggered workflow definitions may be ambiguous] → Mitigation: make the required-success workflow set explicit in specs and repository-owned validation instructions.
- [Temporary external verification can fail for reasons unrelated to the tag, such as local Flutter setup] → Mitigation: keep the verification scope minimal and define exactly which consumer step counts as proof.

## Migration Plan

1. Define the governed requirements for tag publication, retry, action success, and external consumer verification.
2. Update repository automation and instructions so the flow can be executed consistently.
3. Implement any missing workflow observation and retry handling needed to satisfy the contract.
4. Validate the end-to-end path with a real governed release-tag run and temporary external consumer.

## Open Questions

- Which exact GitHub Actions workflows are the authoritative tag-success gates for this repository?
- Should the temporary external consumer prove only dependency resolution and build, or also a minimal runtime smoke path?
