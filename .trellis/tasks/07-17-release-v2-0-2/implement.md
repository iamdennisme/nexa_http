# Release v2.0.2 - Implementation Plan

## Preconditions

- [x] User authorized task creation, version preparation, push, rehearsal and publication.
- [x] GitHub CLI is authenticated as repository admin with `repo` scope.
- [x] `v2.0.1` is the current stable Release; `v2.0.2` tag and Release are absent.
- [x] Local main is clean before task creation and based directly on current remote main.
- [x] Planning artifacts pass convergence review and task is activated before metadata edits.
- [x] Load `trellis-before-dev` release/package guidance before editing.

## Ordered Checklist

- [x] Record exact local/remote heads, existing tag/Release state and six-package version baseline.
- [x] Update six release package pubspec versions from `2.0.1` to `2.0.2`.
- [x] Run normal pub resolution for root/packages/demo and retain only expected path-version lock changes.
- [x] Add `2.0.2` CHANGELOG notes for proxy normalization, Rust executor decomposition and Dart native transport consolidation.
- [x] Update root English/Chinese README, package README and layering example to `v2.0.2`; update governance assertion.
- [x] Confirm historical architecture provenance remains `v2.0.1` and no unrelated version literal changes.
- [x] Run focused release transaction, governance and documentation checks.
- [x] Run final `verify-static --execution static-linux` and save a machine-readable report.
- [x] Review the complete metadata diff; confirm runtime, ABI, bindings, workflow, target and artifact files are unchanged.
- [ ] Commit the release preparation as one coherent work commit.
- [ ] Fetch origin, prove fast-forward ancestry, push main without force and verify the exact SHA remotely.
- [ ] Run local dispatch validation against the pushed SHA.
- [ ] Dispatch and monitor `publish=false`; require every fragment, candidate row and aggregate to pass.
- [ ] Assert rehearsal created no `v2.0.2` tag, draft, prerelease or Release.
- [ ] Dispatch and monitor `publish=true` for the same SHA; require publisher success.
- [ ] Verify annotated tag target, stable Release and exact 11-asset set/digests.
- [ ] Record run IDs/candidate evidence, complete ACs, archive task, journal session and push bookkeeping commits.

## Local Validation Commands

```bash
fvm dart test test/release_transaction_test.dart \
  test/release_transaction_cli_test.dart \
  test/release_publication_gateway_test.dart
fvm dart test test/verification/ci_workflow_test.dart \
  test/trellis_governance_test.dart
fvm dart run scripts/workspace_tools.dart verify-static \
  --execution static-linux \
  --report-out /tmp/nexa-http-v2.0.2-static.json
```

After push:

```bash
fvm dart run scripts/release_transaction.dart validate \
  --mode dispatch \
  --workspace-root . \
  --repository iamdennisme/nexa_http \
  --version 2.0.2 \
  --commit-sha <40hex>
```

## Remote Commands

```bash
gh workflow run release-native-assets.yml --ref main \
  -f version=2.0.2 \
  -f commit_sha=<40hex> \
  -f publish=false

gh run watch <rehearsal-run-id> --exit-status

gh workflow run release-native-assets.yml --ref main \
  -f version=2.0.2 \
  -f commit_sha=<same-40hex> \
  -f publish=true

gh run watch <publish-run-id> --exit-status
```

## Review Gates

- Metadata diff contains only planned version, lock, changelog, README/spec/test and Trellis task files.
- Six pubspec versions are exactly one stable semver; lock changes contain no hosted dependency upgrades.
- Release commit is present on remote main before either dispatch.
- Publishing run is not dispatched until rehearsal success and public-state absence are both proven.
- Release is not accepted until tag target, Release state, asset count and workflow conclusion all match.

## Rollback Points

- Metadata edit/check failure: correct locally before commit.
- Remote main changed: stop; do not force push or dispatch stale SHA.
- Rehearsal failure: keep public state absent, diagnose and fix forward with a new SHA.
- Publishing failure: verify owned-state compensation before any retry.
- Successful release: never mutate `v2.0.2`; create a new patch release for corrections.
