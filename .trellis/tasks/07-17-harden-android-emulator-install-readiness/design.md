# Harden Android emulator install readiness - Design

## Ownership Boundary

The fix stays in the root workspace verification owner:

```text
VerificationProcessRunner
  -> runVerificationCommand (live output + bounded failure tail)
  -> shared Flutter runtime smoke runner
       -> Android exact-signature install recovery
       -> existing logcat/reverse/start/proof/cleanup flow
  -> integration / candidate / released-consumer callers
```

The workflows keep their coarse `wait_android_package_service.sh` startup
gate and continue to call complete Catalog suites. Retry logic does not enter
workflow YAML, a carrier package, `nexa_http_native_internal`, Rust, or the
fixture App.

## Command Failure Contract

`runVerificationCommand` continues to accept a `VerificationCommand` and
return `Future<void>`. On a non-zero exit it throws a ProcessException-compatible
typed failure containing:

```text
executable
arguments
working directory
exit code
bounded stdout tail
bounded stderr tail
```

The implementation retains the last 100 lines from each stream. Every line is
still forwarded immediately to the existing stdout/stderr handler, so GitHub
Actions logging and runtime proof observation do not change. The bounded tail
exists for classification and terminal diagnostics; it is not a second log.

Existing callers that catch `ProcessException` remain compatible. Successful
commands allocate only bounded line buffers and expose no new public CLI
surface.

## Android Install Recovery

The shared runtime smoke runner extracts the install into one operation with
these constants:

```text
maximum attempts: 3
delay between eligible attempts: 2 seconds
command: adb -s <device> install -t -r <same-app-release.apk>
```

An attempt is eligible for retry only when the typed command failure's combined
stdout/stderr tail contains the observed Android platform signature:

```text
PackageManagerInternal.freeStorage
null object reference
```

`StorageManagerService.allocateBytes` may be retained as supporting diagnostic
evidence but is not required if Android changes stack formatting around the
same failing method. Matching is case-sensitive because the Java method and
platform exception text are stable literals from the recorded failure.

Behavior:

1. Run the one canonical install command.
2. On success, continue without delay.
3. On a typed matching failure before attempt 3, wait two seconds and rerun the
   identical command.
4. On a non-matching or untyped failure, rethrow immediately without waiting.
5. On the third matching failure, throw a ProcessException-compatible terminal
   failure that reports attempt count, device, APK path, and the final retained
   diagnostics.

Retry never rebuilds the APK, changes candidate identity, uninstalls an App,
clears data, changes emulator configuration, or treats missing runtime proof as
success.

## Existing Runtime Sequence

After install succeeds, the current order remains authoritative:

```text
clear target-device logcat
  -> adb reverse fixture port once
  -> start the release Activity
  -> poll filtered flutter:I logcat up to 60 times
  -> require exactly one complete lifecycle proof
  -> best-effort force-stop
```

The finalizer remains best-effort and cannot mask an install or proof failure.

## Flutter SDK Contract Mapping

- Host dependency and runtime import shape: unchanged. The generated clean
  host still depends on the public SDK plus Android carrier and imports only
  `package:nexa_http/nexa_http.dart`.
- Native lifecycle ownership: unchanged. Artifact preparation, candidate
  verification, plugin registration, packaging, and loading remain SDK-owned;
  this task changes only workspace verification process control.
- Host setup: unchanged. No Gradle, manifest, source, environment, mirror, or
  manual native-library step is added for users.
- Failure reporting: terminal errors identify install stage, Android device,
  APK path, attempt count, exit code, and bounded original child output.
- Clean-host acceptance: deterministic tests cover the retry state machine;
  hosted `android-linux` integration exercises the real ATD release APK and
  must still emit the full request/callback/body/client lifecycle proof.

## Compatibility And Rollback

- No Dart SDK, Rust, ABI, artifact, package version, workflow topology, or
  released `v2.0.2` state changes.
- CI and release candidate behavior changes only for the exact recorded Android
  system boot race.
- Rollback is one coherent revert of command diagnostics, adapter recovery,
  tests, and spec updates. There is no compatibility branch or alternate
  install path.

## Alternatives Rejected

- Fixed post-boot sleep or repeated binder checks: they do not exercise the
  failing StorageManager/package-install dependency and can still race.
- A synthetic one-byte install session: stronger than binder visibility but
  adds API-sensitive session parsing and cleanup before the real install.
- Retry every install error: delays invalid APK, signature, storage, and device
  defects and blurs infrastructure readiness with product failures.
- Workflow-local retry: duplicates logic between CI and release and misses
  released-consumer diagnostics that share the Dart adapter.
