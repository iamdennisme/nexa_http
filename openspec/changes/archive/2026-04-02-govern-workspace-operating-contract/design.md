## Context

The repository already has concrete behavior for local development, external git consumption, artifact production, and CI enforcement. Those behaviors are correct, but their status as long-lived policy is implicit. Without an explicit operating contract, a future session can treat them as normal implementation details and accidentally regress the workflow model while still making code-level progress.

## Goals / Non-Goals

**Goals:**
- Establish a stable repository-level operating contract for development, packaging, release, and integration.
- Define the set of official commands and pipelines that future changes must preserve or explicitly renegotiate.
- Make OpenSpec the required mechanism for changing governed workflow behavior.
- Make the governance model reusable by future repositories that adopt this workspace pattern.

**Non-Goals:**
- Redesign the current implementation again.
- Change the public `nexa_http` API.
- Introduce a new release pipeline or new distribution backend.
- Replace CI jobs or scripts beyond what is needed to document and govern them.

## Decisions

### Decision: Introduce a dedicated `workspace-operating-contract` capability
This governance rule is broader than any single runtime or artifact capability. A dedicated capability keeps the maintenance contract visible and gives future changes one obvious spec to consult before touching core workflows.

Alternative considered:
- Scatter governance language across existing specs only. Rejected because the policy would remain fragmented and easier to overlook.

### Decision: Treat development path, release-consumer path, artifact verification, and release publication as governed contracts
These are no longer implementation accidents. They are part of how the repository is supposed to be operated. Future changes may evolve them, but only through an explicit OpenSpec change that updates the governing specs.

Alternative considered:
- Keep them as informal documentation plus CI. Rejected because CI alone tells us something changed, but not whether the change was authorized.

### Decision: Require OpenSpec for workflow-level changes, not just product-level changes
The same discipline used for API/runtime behavior should apply to debugging, packaging, release, and integration workflows. This makes future sessions and future repos consistent: if a workflow is contract-bearing, it must have a spec.

Alternative considered:
- Limit OpenSpec to end-user behavior and allow workflow changes directly in scripts. Rejected because the user explicitly wants these workflows to stop drifting across sessions and projects.

### Decision: Keep the contract implementation-agnostic
The governance spec defines required invariants, official entrypoints, and change discipline. It does not freeze exact script internals or CI job names beyond what consumers and maintainers rely on.

Alternative considered:
- Specify exact implementation details for every script. Rejected because it would create needless churn and make safe refactors harder.

## Risks / Trade-offs

- [Governance overhead] -> Some future workflow changes will require more upfront spec work. Mitigation: keep governance specs short and focused on invariants, not incidental implementation detail.
- [Spec duplication] -> Governance language can overlap with capability specs. Mitigation: use the operating contract as the umbrella rule and keep lower-level specs focused on concrete behavior.
- [False sense of safety] -> A spec alone does not prevent drift. Mitigation: continue pairing the contract with CI gates and repository verification commands.

## Migration Plan

1. Add the new governance capability and update affected existing capabilities with governance language.
2. Update repository documentation to point maintainers at the operating contract before changing core workflows.
3. Preserve the current verification commands and CI gates as the operational baseline.
4. Require future workflow changes to land through OpenSpec changes that modify the governing specs.

## Open Questions

- Whether the long-term template for future repositories should live as a dedicated repository template or as a documented extraction process from this workspace.
- Whether maintainers want a separate `docs/` contract summary in addition to the OpenSpec source of truth.
