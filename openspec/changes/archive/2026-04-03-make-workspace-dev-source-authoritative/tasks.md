## 1. Rework workspace-dev Resolution Semantics

- [x] 1.1 Add failing coverage that `workspace-dev` does not trust a stale pre-existing local native binary solely because it exists.
- [x] 1.2 Update the development-mode artifact resolver so current workspace source is authoritative and existing local binaries are treated only as outputs to validate or regenerate, not as trusted input.
- [x] 1.3 Keep `release-consumer` resolution behavior unchanged for external projects and published assets.

## 2. Align Demo Startup With Source-Authoritative Development

- [x] 2.1 Add failing verification that repository-local demo startup prepares or validates native artifacts from current source when stale local binaries are present.
- [x] 2.2 Update the demo/build-hook development path so `workspace-dev` no longer succeeds by reusing stale local binaries without source-authoritative preparation.

## 3. Strengthen Verification

- [x] 3.1 Extend development-path verification to detect stale-binary trust regressions in `workspace-dev`.
- [x] 3.2 Run the relevant resolver, demo, and verification suites to confirm the local development path remains source-authoritative while release-consumer stays unchanged.
