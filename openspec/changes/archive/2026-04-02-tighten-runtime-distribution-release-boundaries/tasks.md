## 1. Distribution Source Of Truth

- [x] 1.1 Add manifest descriptor and serialization tests that capture the current release manifest shape.
- [x] 1.2 Move manifest-generation primitives from the standalone script into `nexa_http_distribution`.
- [x] 1.3 Update `scripts/generate_native_asset_manifest.dart` to become a thin caller of shared distribution library logic.
- [x] 1.4 Verify the release workflow still emits the same manifest filename, asset descriptors, and checksum output.

## 2. Runtime Loader Strategy Split

- [x] 2.1 Add focused tests that lock current candidate discovery behavior per host platform.
- [x] 2.2 Split `nexa_http_runtime` candidate discovery into platform-specific strategy modules.
- [x] 2.3 Keep the top-level loader orchestration API stable while delegating all candidate expansion to the new strategy layer.
- [x] 2.4 Re-run runtime package tests and carrier package tests after the split.

## 3. Version Alignment Enforcement

- [x] 3.1 Restrict lockstep versioning to the seven release-train packages and explicitly exclude `packages/nexa_http/example`.
- [x] 3.2 Add a workspace verification command or check that fails when aligned package versions drift.
- [x] 3.3 Wire the version-alignment check into repository verification and release paths.
- [x] 3.4 Add release-time verification that the repository tag matches the aligned package versions.
- [x] 3.5 Update README and package documentation so the enforced policy matches the tooling behavior.
