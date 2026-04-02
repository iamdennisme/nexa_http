## 1. Break Public Package Boundary

- [x] 1.1 Add failing verification that an external Flutter app can integrate by declaring only `nexa_http`.
- [x] 1.2 Restructure `nexa_http` and platform packages into a federated/default-package model so public setup no longer requires user-declared carrier packages.
- [x] 1.3 Remove internal runtime/distribution and carrier-package wiring from public integration guidance and external consumer fixtures.

## 2. Introduce Explicit Artifact Modes

- [x] 2.1 Add failing tests for explicit `workspace-dev` and `release-consumer` artifact resolution behavior.
- [x] 2.2 Implement deterministic `workspace-dev` local artifact preparation for repository development and demo startup.
- [x] 2.3 Implement `release-consumer` resolution that uses packaged/released assets and forbids implicit local Rust compilation.
- [x] 2.4 Ensure distribution-owned target metadata drives both artifact modes and their verification.

## 3. Rebuild The Demo Around Development Mode

- [x] 3.1 Update `packages/nexa_http/example` so it is the canonical development demo for Flutter-to-Rust debugging.
- [x] 3.2 Ensure the documented demo startup path executes `workspace-dev` without requiring source or pubspec edits.
- [x] 3.3 Add verification that demo startup failures surface structured bootstrap diagnostics.

## 4. Add Structured Bootstrap Diagnostics

- [x] 4.1 Add failing tests for structured native bootstrap/client-creation errors across the Dart and native boundary.
- [x] 4.2 Replace generic client-creation/bootstrap failure sentinels with structured error payloads and Dart exception mapping.
- [x] 4.3 Update demo and integration tests to assert on machine-readable bootstrap failure codes/stages where relevant.

## 5. Rework Verification And CI

- [x] 5.1 Replace the current verification commands with explicit development-path, release-consumer-path, and artifact-consistency checks.
- [x] 5.2 Update PR CI to run those checks on the required hosts and make them merge-blocking.
- [x] 5.3 Update release workflows to reuse the release-consumer and artifact-consistency checks before publication.

## 6. Final Verification

- [x] 6.1 Run focused local verification for:
  - single-package external integration
  - `workspace-dev` demo startup
  - `release-consumer` artifact resolution
  - structured bootstrap diagnostics
- [x] 6.2 Run the relevant Dart/Flutter/Rust test suites touched by the redesign and confirm the final workspace state matches the new product model.
