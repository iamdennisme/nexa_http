# Release v2.0.3 - Implementation Plan

## Preconditions

- [x] User authorized creation of a Trellis task and planning for `v2.0.3`.
- [x] Current `main` equals `origin/main` at `567472f2cb04c6b6a3548fa00fc7cbce9831c07f` before task creation.
- [x] `v2.0.2` is published and immutable; `v2.0.3` tag and Release are absent.
- [x] Current HEAD CI run `29570619943` passed every platform row and `ci-gate`.
- [x] GitHub CLI is authenticated as `iamdennisme` with `repo` scope.
- [x] User reviews the converged planning artifacts and explicitly approves implementation/publication.
- [x] Activate the task with `task.py start`, then load `trellis-before-dev` package/release guidance before metadata edits.

## Ordered Checklist

- [x] Re-fetch and record exact local/remote heads, `v2.0.2` peeled target, `v2.0.3` tag/Release absence and six-package version baseline.
- [x] Change six release package versions from `2.0.2` to `2.0.3`.
- [x] Run normal pub resolution in `packages/nexa_http` and the four carrier packages; retain only five local `nexa_http_native_internal` path-version lock changes.
- [x] Add the `2.0.3` CHANGELOG entry for bounded verification diagnostics and exact Android install boot-race recovery.
- [x] Update root EN/ZH README, package README, layering current-release example and governance assertion to `v2.0.3`.
- [x] Search all tracked `2.0.2` references and classify every remaining occurrence; explicitly preserve hosted `node_preamble`, old CHANGELOG, archived task evidence and journal provenance.
- [x] Run focused command/Android adapter, release transaction, workflow and governance tests.
- [x] Run the complete `test/verification` suite, `dart analyze` and final `verify-static --execution static-linux`; save the machine-readable report.
- [x] Review the complete diff and prove that runtime/native/ABI/bindings/target/carrier/workflow/publication files have no unplanned changes.
- [x] Commit release preparation as one coherent work commit.
- [x] Fetch origin, prove fast-forward ancestry, push `main:main` without force and verify the exact remote SHA.
- [x] Wait for the exact pushed SHA's normal CI rows and final `ci-gate` to succeed.
- [x] Run local dispatch validation against that exact pushed SHA.
- [x] Dispatch and monitor `publish=false`; require transaction input, fragments, candidate assembly, four platform rows and aggregate to pass.
- [x] Verify rehearsal publisher was skipped and no `v2.0.3` tag, draft, prerelease or Release exists.
- [x] Dispatch and monitor `publish=true` for the same SHA; require all gates, aggregate and unique publisher to succeed.
- [x] Verify annotated tag target, stable Release, exact 11-asset names/states/digests, manifest and `SHA256SUMS` consistency.
- [x] Write `evidence.md`, update acceptance checkboxes, perform final quality check, archive task, record journal and push bookkeeping commits.
- [x] Confirm final `origin/main`, clean worktree, no active Trellis task and immutable `v2.0.2` state.

## Metadata Files

Version authorities:

```text
packages/nexa_http/pubspec.yaml
packages/nexa_http_native_internal/pubspec.yaml
packages/nexa_http_native_android/pubspec.yaml
packages/nexa_http_native_ios/pubspec.yaml
packages/nexa_http_native_macos/pubspec.yaml
packages/nexa_http_native_windows/pubspec.yaml
```

Tracked local path resolutions:

```text
packages/nexa_http/pubspec.lock
packages/nexa_http_native_android/pubspec.lock
packages/nexa_http_native_ios/pubspec.lock
packages/nexa_http_native_macos/pubspec.lock
packages/nexa_http_native_windows/pubspec.lock
```

Current documentation references:

```text
README.md
README.zh-CN.md
packages/nexa_http/README.md
.trellis/spec/guides/project-layering-contract.md
test/trellis_governance_test.dart
packages/nexa_http/CHANGELOG.md
```

## Local Validation Commands

```bash
fvm dart test test/verification/command_test.dart \
  test/verification/external_consumer_adapter_test.dart

fvm dart test test/release_transaction_test.dart \
  test/release_transaction_cli_test.dart \
  test/release_publication_gateway_test.dart \
  test/verification/ci_workflow_test.dart \
  test/trellis_governance_test.dart

fvm dart test test/verification
fvm dart analyze

fvm dart run scripts/workspace_tools.dart verify-static \
  --execution static-linux \
  --report-out /tmp/nexa-http-v2.0.3-static.json
```

After push:

```bash
fvm dart run scripts/release_transaction.dart validate \
  --mode dispatch \
  --workspace-root . \
  --repository iamdennisme/nexa_http \
  --version 2.0.3 \
  --commit-sha <release-commit-40hex>
```

## Remote Commands

```bash
gh workflow run release-native-assets.yml --ref main \
  -f version=2.0.3 \
  -f commit_sha=<release-commit-40hex> \
  -f publish=false

gh run watch <rehearsal-run-id> --exit-status

gh workflow run release-native-assets.yml --ref main \
  -f version=2.0.3 \
  -f commit_sha=<same-release-commit-40hex> \
  -f publish=true

gh run watch <publish-run-id> --exit-status
```

## Review Gates

- Metadata diff contains only planned version, path lock, CHANGELOG, current README/spec assertion and Trellis task changes on top of the already-reviewed Android verification increment.
- Six pubspec versions are exactly `2.0.3`; five local path locks resolve `nexa_http_native_internal 2.0.3`; no hosted dependency changed.
- Release commit is present on remote main and its normal CI is green before either release dispatch.
- Publishing run is not dispatched until rehearsal success and stable public-state absence are both proven.
- Release is not accepted until tag target, Release state, asset count/digests and all four runtime reports match the acceptance contract.

## Rollback Points

- Metadata/check failure: correct locally before push and rerun all affected gates.
- Remote main changed: stop; never force push or dispatch stale history.
- Rehearsal/normal CI failure: keep public state absent, fix forward with a new SHA and repeat from validation.
- Publishing failure: verify transaction-owned cleanup and stable absence before considering a retry.
- Successful release: never mutate `v2.0.3`; use a later patch release for corrections.
