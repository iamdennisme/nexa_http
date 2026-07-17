# Harden Android emulator install readiness

## Goal

Prevent a verified Android candidate from losing an otherwise valid CI or
release transaction when the freshly booted emulator exposes the package
binder service before its internal package manager is ready to accept the
first APK write.

## Background

- The `v2.0.2` publishing run `29560914835`, attempt 1, built the unique
  release APK successfully and then failed at `adb install -t -r` with an
  Android system `NullPointerException` from
  `PackageManagerInternal.freeStorage` during
  `StorageManagerService.allocateBytes`.
- The non-publishing rehearsal and publishing attempt 2 both passed the same
  Android candidate contract. The failed attempt created no public state and
  the successful retry reused the publishing transaction's exact candidate.
- `scripts/wait_android_package_service.sh:6-14` currently waits for
  `adb shell service check package` to report `found`. The incident proves
  that binder visibility is necessary but not sufficient for the later APK
  write path.
- Both `.github/workflows/ci.yml:76-93` and
  `.github/workflows/release-native-assets.yml:248-258` run that readiness
  script before the complete Catalog suite.
- `scripts/verification/external_consumer_adapter.dart:144-163` issues the
  only APK install. The same adapter serves integration, candidate, and
  released-consumer verification.
- `scripts/verification/command.dart:22-45` streams child output to the CLI but
  throws a generic `ProcessException` without retaining stdout/stderr in the
  failure object, so the adapter cannot currently distinguish this boot race
  from a real packaging or install defect.

## Requirements

### R1. Recognize only the proven transient failure

- Recovery is limited to the exact observed package-manager boot-race
  signature; it does not apply to every failed `adb install`.
- Classify the Android boot race from structured command failure diagnostics,
  using the `PackageManagerInternal` null failure observed in run
  `29560914835` as the regression fixture.
- Signature mismatch, missing diagnostics, and every unrelated `adb install`
  failure must fail immediately.

### R2. Recover within one verification row

- Retry the exact same `adb install -t -r` command only for the recognized
  boot race.
- Recovery must be bounded by an explicit attempt limit and delay, with no
  unbounded polling or fixed unconditional stabilization sleep.
- Exhaustion must surface the final original command failure and diagnostics.

### R3. Preserve the clean-host contract

- Continue to build the release APK exactly once and reuse
  `app-release.apk`; do not rebuild, uninstall, change profile, or use
  `flutter run`.
- After a successful install, preserve the existing order: clear logcat,
  establish one `adb reverse`, start the Activity, require one complete proof,
  and best-effort force-stop the fixture.
- Do not add another artifact source, runtime fallback, skipped platform, or
  success-by-retry for product/runtime failures.

### R4. Preserve actionable command diagnostics

- A failed verification command must retain bounded stdout/stderr diagnostics
  while continuing to stream the same lines to the live CI log.
- Existing `ProcessException` handling for Flutter teardown and best-effort
  cleanup must remain compatible.

### R5. Prove the behavior test-first

- Add a failing regression test before implementation for transient install
  failure followed by success.
- Cover immediate non-transient failure, bounded transient exhaustion, exact
  command ordering, retry waits, and preserved final diagnostics.
- Keep mocks at the external command/time boundary; do not require a real
  emulator for deterministic unit tests.

### R6. Keep executable contracts current

- Update the verification/release spec to state that package binder visibility
  is not sufficient and define the narrowly bounded install recovery.
- Keep CI and release workflow ownership unchanged; both must continue to run
  complete Catalog suites through the shared adapter.

### R7. Verify locally and on a real hosted Android runner

- Focused command/adapter/workflow tests, formatting, analyze, and final
  `verify-static --execution static-linux` must pass locally.
- After the work commit reaches `main`, the normal CI `android-linux`
  integration row and aggregate `ci-gate` must pass on the hosted ATD
  emulator; a skipped or retried-away runtime proof is not success.

## Acceptance Criteria

- [x] AC1 (`R1`): The recorded `PackageManagerInternal` boot-race diagnostic
  is recognized, while an unrelated install error is attempted once and
  rethrown unchanged.
- [x] AC2 (`R2`): A transient first install followed by success performs one
  bounded wait and continues through the existing Android runtime proof flow.
- [x] AC3 (`R2`): Repeated transient failures stop at the configured limit and
  expose the final original stdout/stderr diagnostics.
- [x] AC4 (`R3`): Tests prove one APK build, repeated install of only the same
  APK when eligible, and unchanged logcat/reverse/start/proof/cleanup order.
- [x] AC5 (`R4`): Verification command failures retain bounded child output
  without suppressing live output or breaking existing `ProcessException`
  consumers.
- [x] AC6 (`R5`): RED/GREEN evidence and focused regression coverage are
  recorded in the task artifacts.
- [x] AC7 (`R6`): Specs and governance tests describe one shared, bounded
  readiness/recovery contract with no workflow-local duplicate logic.
- [ ] AC8 (`R7`): Final local static gate and hosted `android-linux`/`ci-gate`
  both pass; worktree is clean and the task is archived.

## Out Of Scope

- Changing the Android API level, ATD image, emulator action, target matrix, or
  release transaction topology.
- Retrying every `adb` or Flutter command, uninstalling packages, rebuilding
  the APK, or accepting a missing runtime proof.
- SDK runtime, public Dart API, Rust, C ABI, native assets, package versions,
  or any mutation of the published `v2.0.2` tag and assets.
