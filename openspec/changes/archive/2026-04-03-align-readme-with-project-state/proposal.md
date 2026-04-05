## Why

The repository README files are mostly accurate, but they no longer line up cleanly with the current project state or the way real readers approach the repo. Some paths and commands have drifted from reality, benchmark metric descriptions are incomplete, and the top-level docs prioritize internal structure before reader tasks, which makes them correct but harder to follow.

## What Changes

- Update the top-level English and Chinese READMEs so they match the current repository structure, release-tag workflow, and demo behavior.
- Fix factual mismatches such as outdated Rust path references and documentation that recommends plain `dart` where the repository now works more reliably with `fvm`.
- Refresh example benchmark documentation so the described metrics match the current UI and exported model.
- Reorganize README flow so app consumers, demo runners, and maintainers can find the right entrypoints in a more human, task-first order.
- Keep the documented integration contract stable: app users still depend only on `nexa_http`, demo users still use the example app plus fixture server, and maintainers still use governed verification/release workflows.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `demo-platform-runnability`: Documentation for the official demo must match the current example startup flow, benchmark surface, and supported local host guidance.
- `git-consumer-dependency-boundary`: Documentation for external consumption must accurately describe the current git+ssh tag-based integration path and public package surface.
- `workspace-operating-contract`: Repository documentation must point readers to the current governed verification, release-tag, and maintainer entrypoints.

## Impact

Affected files include `README.md`, `README.zh-CN.md`, and `app/demo/README.md`. Affected systems are repository onboarding, external git/tag consumption guidance, demo setup instructions, and maintainer workflow discoverability.
