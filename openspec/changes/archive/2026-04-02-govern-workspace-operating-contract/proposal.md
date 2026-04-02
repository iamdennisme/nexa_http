## Why

The repository now has a stable development path, release-consumer path, and native release pipeline, but those rules still depend too much on recent conversation context. We need an explicit operating contract so future sessions and future projects do not casually rewrite debugging, packaging, or release behavior.

## What Changes

- Add a new governance capability that defines the repository's official debugging, packaging, release, and consumer-integration entrypoints.
- Define which workflows are stable operating contracts and SHALL NOT change without a new OpenSpec change.
- Define the required verification and CI gates that protect those contracts from drift.
- Define how future repositories can inherit this model without re-negotiating core workflow behavior.

## Capabilities

### New Capabilities
- `workspace-operating-contract`: Defines the repository's stable development, packaging, release, and change-governance rules.

### Modified Capabilities
- `ci-enforced-consumer-verification`: Clarify that CI enforcement is part of the repository operating contract, not just implementation convenience.
- `demo-platform-runnability`: Clarify that the demo startup path is a governed contract and requires OpenSpec review to change.
- `git-consumer-dependency-boundary`: Clarify that the external consumer dependency model is a governed contract and requires OpenSpec review to change.
- `native-artifact-verification`: Clarify that artifact verification is a governed contract and release prerequisite.

## Impact

Affected systems include OpenSpec governance, repository documentation, workspace verification commands, CI policy, and future release-process changes. This does not introduce a public API change; it formalizes how core workflows are allowed to evolve.
