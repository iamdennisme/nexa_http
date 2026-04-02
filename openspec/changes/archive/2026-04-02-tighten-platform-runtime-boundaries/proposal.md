## Why

The current cross-platform split is directionally correct, but the platform boundary is still expressed in too many places. Platform targets, dynamic-library discovery, carrier responsibilities, and proxy refresh policy are duplicated across runtime, distribution, and carrier packages, which has already produced target-matrix drift and loader/packaging duplication. Since breaking changes are allowed, this is the right time to collapse those boundaries into a cleaner architecture instead of patching around them.

## What Changes

- **BREAKING** Re-draw the package boundaries so `nexa_http_runtime` becomes the single dynamic-library discovery/orchestration layer and carrier packages stop owning overlapping generic loader logic.
- **BREAKING** Move platform target definitions, artifact identity, and supported release matrix rules into one authoritative model shared by runtime loading, distribution, and carrier build hooks.
- **BREAKING** Redefine platform proxy refresh policy so platform sources declare the actual refresh model they support instead of defaulting to unconditional short-interval polling.
- Add stronger cross-package verification so runtime, distribution, carrier packages, and release tooling must agree on the same supported platform targets and artifact contracts.

## Capabilities

### New Capabilities
- `platform-runtime-verification`: Verify runtime loading, distribution, carrier packaging, and release tooling all agree on the same supported platform targets and artifact contracts.

### Modified Capabilities
- `runtime-loader-platform-strategies`: Make runtime loading the single generic discovery/orchestration layer and remove overlapping carrier-owned loader responsibilities.
- `native-distribution-source-of-truth`: Make distribution own the authoritative platform target matrix and artifact identity model used across release, build hooks, and runtime.
- `native-proxy-runtime-boundaries`: Replace default polling assumptions with explicit platform refresh models aligned with real platform behavior and cost.

## Impact

- Affected code: `packages/nexa_http`, `packages/nexa_http_runtime`, `packages/nexa_http_distribution`, `packages/nexa_http_native_*`, `native/nexa_http_native_core`, scripts, and platform-specific tests.
- Affected APIs: runtime SPI, distribution/build-hook contracts, carrier-package responsibilities, and potentially internal/public package boundaries where platform behavior is exposed today.
- Affected systems: platform target support declarations, native library loading, proxy refresh behavior, release asset generation, workspace verification, and platform integration testing.
