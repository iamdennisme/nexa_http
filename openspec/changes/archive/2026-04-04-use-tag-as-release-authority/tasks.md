## 1. Update release governance scripts

- [x] 1.1 Refactor `scripts/workspace_tools.dart` so tag-triggered release publication no longer hard-fails on workspace package-version drift.
- [x] 1.2 Decide whether `check-release-train` becomes advisory or is removed, and update command handling/output accordingly.

## 2. Update release workflow behavior

- [x] 2.1 Update `.github/workflows/release-native-assets.yml` so release publication is gated by tag-driven contract checks instead of package-version equality.
- [x] 2.2 Preserve tag-derived manifest generation and release URL behavior while removing package-version release gating.

## 3. Align tests with tag-authoritative release governance

- [x] 3.1 Update `test/workspace_release_consistency_test.dart` to stop asserting package-version equality as a release-blocking rule.
- [x] 3.2 Update `test/workspace_tools_test.dart` for the new `check-release-train` / release-governance behavior.
- [x] 3.3 Update any workflow-facing verification tests to assert that tag-based publication remains guarded by artifact and consumer verification.

## 4. Re-verify the release path

- [x] 4.1 Run the affected script and test coverage for release-governance changes.
- [x] 4.2 Validate that a tag-driven release flow still derives manifest versioning and consumer verification from the Git tag.
