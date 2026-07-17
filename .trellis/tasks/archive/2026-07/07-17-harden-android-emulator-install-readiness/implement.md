# Harden Android emulator install readiness - Implementation Plan

## Preconditions

- [x] User approved the task and exact-signature retry boundary.
- [x] Root cause is backed by publishing run `29560914835`, archived release
  evidence, current source, tests, workflow, and verification specs.
- [x] The task is one coherent `nexa_http_workspace/tooling` bugfix; no child
  task or ADR is required.
- [x] User reviews these planning artifacts and approves implementation start.
- [x] Load `trellis-before-dev` and all referenced tooling/TDD/spec contracts
  before the first code edit.

## TDD Execution Order

- [x] RED 1: add a command-boundary regression that emits stdout plus the
  recorded stderr signature, exits non-zero, and proves the current exception
  does not retain classifiable diagnostics.
- [x] GREEN 1: add a ProcessException-compatible verification command failure
  with 100-line stdout/stderr tails while preserving live line forwarding.
- [x] REFACTOR 1: keep bounded-tail collection private and make successful and
  failed command paths readable without changing the runner interface.
- [x] RED 2: add an Android runtime test where the first exact-signature install
  fails and the second succeeds; assert two identical install commands, one
  injected wait, and no later command before success.
- [x] GREEN 2: implement the three-attempt, two-second, exact-signature install
  recovery at the shared runtime smoke boundary.
- [x] RED 3: add non-matching and untyped install failures; assert one attempt,
  zero waits, and unchanged rethrow.
- [x] GREEN 3: keep classification strict and fail closed when diagnostics are
  absent or different.
- [x] RED 4: add persistent matching failures; assert exactly three attempts,
  two waits, and terminal attempt/device/APK/final-output diagnostics.
- [x] GREEN 4: implement bounded exhaustion without rebuilding, uninstalling,
  or hiding the final child failure.
- [x] REFACTOR 2: rerun the existing Android ordering, slow proof, bounded
  polling, duplicate proof, and best-effort cleanup tests.
- [x] Update `verification-command-contract.md` and
  `flutter-sdk-authoring-contract.md` with the coarse binder gate plus
  operation-adjacent exact-signature recovery contract.
- [x] Review the complete diff for accidental workflow, package, runtime, ABI,
  artifact, or `v2.0.2` changes.

## Execution Evidence

- RED 1 failed because `VerificationCommandFailure` did not exist. GREEN 1
  passed `command_test.dart` plus `process_runner_test.dart`, retaining the last
  100 lines per stream while forwarding all child output.
- RED 2 failed at compile time because `waitForAndroidInstallRetry` did not
  exist. GREEN 2 passed the complete adapter test file with the identical
  install command retried before any runtime command.
- The strict classifier added by GREEN 2 immediately passed the typed
  non-matching and untyped `ProcessException` fail-closed regressions with one
  attempt and zero waits.
- RED 4 reached exactly three attempts and two waits but lacked terminal
  attempt context. GREEN 4 passed with attempt/device/APK/final-tail diagnostics
  and retained `ProcessException` compatibility.
- Focused six-file verification passed 56 tests; the complete
  `test/verification` directory passed 142 tests; `fvm dart analyze` reported no
  issues.
- `verify-static --execution static-linux` produced schema v2 report
  `/tmp/android-install-readiness-static.json` with `status=passed` and exact
  equality between seven planned and completed check IDs.

## Hosted Validation Evidence

- Work commit `42a4c042857d089bcbd5e05abe6d9536bab868d5` was pushed to
  `main` by fast-forward and triggered CI run `29567885219`.
- Attempt 1 completed successfully: Catalog `87844568139`, static
  `87844778740`, Android `87844778760`, Windows `87844778767`, Apple
  `87844778796`, and aggregate `ci-gate` `87848403910` all passed.
- Attempt 1 Android log contained one `Performing Streamed Install`, followed
  by `NEXA_HTTP_RUNTIME_PROOF` with request completed, callback received, body
  consumed/released, and client closed all `true`.
- The successful Android job was rerun on a fresh hosted runner as attempt 2,
  job `87849145561`. It again contained one install and the complete runtime
  proof; dependent `ci-gate` `87852164021` passed.
- The authoritative run URL is
  `https://github.com/iamdennisme/nexa_http/actions/runs/29567885219`.
- Only Node 20 deprecation annotations from GitHub-maintained Actions remained;
  no suite failure, runtime failure, skipped target, or product diagnostic was
  present.
- Published `v2.0.2` was not dispatched, retagged, or otherwise mutated.

## Focused Validation

```bash
fvm dart format --output=none --set-exit-if-changed \
  scripts/verification/command.dart \
  scripts/verification/external_consumer_adapter.dart \
  test/verification/command_test.dart \
  test/verification/external_consumer_adapter_test.dart

fvm dart test \
  test/verification/command_test.dart \
  test/verification/process_runner_test.dart \
  test/verification/external_consumer_adapter_test.dart \
  test/verification/released_consumer_adapter_test.dart \
  test/verification/candidate_adapter_test.dart \
  test/verification/ci_workflow_test.dart

fvm dart test test/verification
fvm dart analyze
```

If the implementation reuses an existing test file instead of adding
`command_test.dart`, update the formatting and focused commands to match the
actual diff.

## Full Local Gate

```bash
fvm dart run scripts/workspace_tools.dart verify-static \
  --execution static-linux \
  --report-out /tmp/android-install-readiness-static.json
```

The report must be schema v2, `status=passed`, and have identical planned and
completed check IDs.

## Hosted Android Gate

1. Commit and fast-forward push `main` without force.
2. Monitor the automatically triggered CI run for the exact work commit.
3. Require `static-suite`, all integration rows, `android-linux`, and `ci-gate`
   to complete successfully; Android must produce a full runtime proof.
4. Rerun the successful Android job once on a fresh hosted runner and require
   Android plus its dependent `ci-gate` to pass again.
5. Do not dispatch `v2.0.2`: its immutable tag already exists, so transaction
   preflight correctly rejects it. Candidate-path proof belongs to the next
   normal non-publishing release rehearsal.

## Rollback Points

- A RED test failing for setup rather than missing behavior: correct the test
  before implementation.
- Command diagnostics break existing `ProcessException` catches or live output:
  stop at GREEN 1 and repair the compatibility contract.
- Non-matching install failure retries: stop; classification is too broad.
- Local static gate failure: do not commit or push.
- Hosted Android or aggregate failure: diagnose and fix forward; do not mark the
  task complete or weaken the proof requirement.
