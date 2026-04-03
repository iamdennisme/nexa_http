## Why

`nexa_http` currently mixes native-library discovery policy across the core loader and platform carrier runtimes. That overlap makes successful startup depend on candidate-path probing instead of a single platform contract, which is why debug demos can appear healthy while external consumers and macOS release builds still fail. We need to turn native loading into a fixed runtime contract now so every supported platform uses one deterministic entrypoint and build-time artifact preparation stays out of runtime.

## What Changes

- Remove the core loader's broad candidate-path discovery and make registered platform runtime the default native-library entrypoint after any explicit test override.
- Redefine Android, iOS, macOS, and Windows runtime loading around fixed platform-specific entry contracts instead of workspace/app-bundle/legacy path probing.
- Restrict workspace-dev and source-build behavior to build hooks and artifact preparation, rather than letting runtime loading infer workspace state.
- Make external consumer artifact resolution fail with a structured setup error instead of silently compiling or selecting workspace-local binaries.
- Fix macOS external-consumer and release build behavior so the carrier hook resolves the correct packaged or released artifact without ambiguous universal-binary assembly from local workspace outputs.
- **BREAKING**: remove runtime candidate-walking and legacy path compatibility behavior from `nexa_http` and carrier runtimes.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `runtime-loader-platform-strategies`: replace candidate probing and registered-runtime fallback ordering with deterministic runtime-owned loading contracts.
- `platform-runtime-verification`: verify that core/runtime/build-hook contracts agree on one fixed loading entry per supported platform and reject overlapping discovery logic.
- `native-distribution-source-of-truth`: require build hooks and runtime loading to derive the same artifact identity rules from one source of truth instead of duplicating packaged/workspace assumptions.
- `git-consumer-dependency-boundary`: strengthen the external-consumer contract so git consumers never rely on workspace/source-build behavior during native startup.
- `demo-platform-runnability`: preserve workspace-dev demo behavior while keeping that development-only preparation in build tooling rather than runtime loader policy.

## Impact

- Affected code: `packages/nexa_http/lib/src/loader/*`, platform runtime plugins under `packages/nexa_http_native_*`, and native artifact resolution/build hooks.
- Affected behavior: native startup ordering on Android/iOS/macOS/Windows, external consumer startup, demo startup, and macOS release packaging.
- Affected verification: loader/runtime/hook consistency tests, platform runnability checks, and external-consumer verification.
