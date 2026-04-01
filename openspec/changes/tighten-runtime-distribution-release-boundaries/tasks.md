## 1. Distribution Source Of Truth

- [ ] 1.1 Add manifest descriptor and serialization tests that capture the current release manifest shape.
- [ ] 1.2 Move manifest-generation primitives from the standalone script into `nexa_http_distribution`.
- [ ] 1.3 Update `scripts/generate_native_asset_manifest.dart` to become a thin caller of shared distribution library logic.
- [ ] 1.4 Verify the release workflow still emits the same manifest filename, asset descriptors, and checksum output.

## 2. Runtime Loader Strategy Split

- [ ] 2.1 Add focused tests that lock current candidate discovery behavior per host platform.
- [ ] 2.2 Split `nexa_http_runtime` candidate discovery into platform-specific strategy modules.
- [ ] 2.3 Keep the top-level loader orchestration API stable while delegating all candidate expansion to the new strategy layer.
- [ ] 2.4 Re-run runtime package tests and carrier package tests after the split.

## 3. Version Alignment Enforcement

- [ ] 3.1 Restrict lockstep versioning to the seven release-train packages and explicitly exclude `packages/nexa_http/example`.
- [ ] 3.2 Add a workspace verification command or check that fails when aligned package versions drift.
- [ ] 3.3 Wire the version-alignment check into repository verification and release paths.
- [ ] 3.4 Add release-time verification that the repository tag matches the aligned package versions.
- [ ] 3.5 Update README and package documentation so the enforced policy matches the tooling behavior.
