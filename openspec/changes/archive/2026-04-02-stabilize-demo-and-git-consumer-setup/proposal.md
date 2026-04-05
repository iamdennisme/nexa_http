## Why

The current workspace still mixes two different product stories:

- repository contributors need a demo that can build native artifacts from local Rust sources and validate Flutter-to-Rust changes quickly
- external consumers need a clean SDK that can be integrated from git/ssh without understanding internal packages or installing Rust

The existing shape does neither cleanly enough. The example app still behaves like a repository-local fixture, external setup still leaks carrier/runtime details, native artifact resolution still guesses between local build and release consumption, and bootstrap failures are too opaque to debug. The recent macOS `create_client` failure is a symptom of that ambiguity: the library loads, but the system does not expose enough structured failure detail to tell whether the problem is artifact identity, config decoding, proxy resolution, or client construction.

## What Changes

- **BREAKING** Make `nexa_http` the only public dependency that app consumers declare.
- **BREAKING** Convert platform carrier packages into federated default implementations behind `nexa_http` instead of manually-added public dependencies.
- **BREAKING** Split native artifact resolution into two explicit modes:
  - `workspace-dev` for repository demo and contributors, which prepares native artifacts from local source
  - `release-consumer` for external git/ssh consumers, which resolves packaged or released native artifacts and never implicitly compiles Rust
- **BREAKING** Make the repository example the official development demo that exercises the `workspace-dev` path by default.
- Add structured native bootstrap diagnostics so client creation and runtime initialization failures surface actionable error codes and messages instead of `0`/generic `StateError`.
- Replace the current demo/consumer verification plan with CI that separately verifies repository development flow and external consumer flow.

## Capabilities

### New Capabilities
- `demo-platform-runnability`: defines the official repository demo as the development entrypoint and its local artifact preparation contract.
- `git-consumer-dependency-boundary`: defines the single-package public integration contract and the release-consumer artifact behavior.
- `native-artifact-verification`: defines explicit `workspace-dev` and `release-consumer` artifact resolution modes plus their verification.
- `ci-enforced-consumer-verification`: defines CI gates for development-path and external-consumer-path validation.

### Modified Capabilities
- `native-distribution-source-of-truth`: distribution-owned target metadata must drive both local-development artifact preparation and release-consumer artifact identity.

## Impact

- Affected code: `packages/nexa_http`, `packages/nexa_http_runtime`, `packages/nexa_http_distribution`, `packages/nexa_http_native_*`, `native/nexa_http_native_core`, `app/demo`, `scripts/`, `.github/workflows/`.
- Affected interfaces: public package dependency model, plugin registration topology, artifact resolver behavior, bootstrap error surface, README setup instructions, verification commands, CI workflows.
- Affected systems: demo startup, external git/ssh integration, native asset publication/consumption, platform bootstrap debugging.
