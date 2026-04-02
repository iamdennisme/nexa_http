## 1. Platform Matrix Alignment

- [x] 1.1 Define one authoritative supported-target and artifact-identity matrix for carrier packaging, runtime loading, and release asset generation.
- [x] 1.2 Align Windows target support across runtime loader candidates, build-hook source candidates, and release manifest descriptors.
- [x] 1.3 Update carrier package hooks, distribution helpers, and runtime target strategies to derive coverage from the same matrix.

## 2. Loader And Carrier Boundary Cleanup

- [x] 2.1 Refactor carrier package runtime implementations so generic packaged/workspace candidate discovery lives only in `nexa_http_runtime`.
- [x] 2.2 Keep the top-level runtime loader orchestration stable while tightening platform-specific strategy modules around the authoritative target matrix.
- [x] 2.3 Preserve explicit-path and registered-runtime override behavior while removing redundant carrier-owned discovery branches.

## 3. Proxy Refresh Policy Tightening

- [x] 3.1 Redefine the shared proxy refresh model so platforms can express static or construction-boundary refresh without background polling.
- [x] 3.2 Revisit per-platform proxy refresh policies and downgrade effectively static platforms away from unconditional short-interval polling where appropriate.
- [x] 3.3 Keep shared proxy refresh coordination in Rust core and update platform source tests to reflect the chosen refresh model.

## 4. Verification

- [x] 4.1 Add repository tests that assert runtime loader targets, carrier build-hook targets, distribution target descriptors, and release manifest targets stay aligned.
- [x] 4.2 Add verification that carrier packages do not reintroduce generic loader policy that belongs in `nexa_http_runtime`.
- [x] 4.3 Expand carrier/runtime verification beyond shallow registration checks so platform packaging and loader expectations are covered explicitly.
- [x] 4.4 Run focused Dart and Rust verification for runtime loader behavior, distribution target generation, and platform proxy sources.
