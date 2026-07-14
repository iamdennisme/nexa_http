## 2.0.0

- Make `Call.execute()` + `Call.cancel()` the only request execution surface;
  remove `Callback`, `enqueue()`, `clone()`, and direct client execution.
- Add the seven-value `NexaHttpFailureKind` taxonomy and remove legacy string
  error codes, HTTP status fields, timeout flags, and untyped details.
- Replace byte-backed request construction with ownership-transferring
  `RequestBody.takeBytes()`; remove request-body read and fake streaming APIs.
- Make `ResponseBody` single-consumption with deterministic native ownership:
  `bytes()` copies native data exactly once, while `string()` and `close()` do
  not pre-copy the full body.
- Move generated FFI bindings under `lib/src/` and remove public native
  ownership helpers and secondary package-root libraries.
- Linearize native cancellation acknowledgment with Callback Commit so cancel
  and response/error terminal winners cannot overwrite each other.
- Raise the minimum toolchain to Dart 3.11 / Flutter 3.41.5.

## 1.0.0

- Migrate native request execution path to a rinf-style runtime signal channel.
- Enforce Rust-native transport as the primary path for Dio and image cache integrations.
- Shrink Android native artifacts by building release binaries and stripping unneeded symbols.
- Refresh all platform native release artifacts (Android/iOS/macOS/Windows).

## 0.1.1

- Add Rust-side proxy strategy support with dynamic refresh for HTTP, HTTPS, and SOCKS.
- Refresh package docs and simplify the example app into a request/response test page.
- Add Android project files for the example app.

## 0.1.0

- Split domain contracts into a standalone native-core package.
- Keep Flutter FFI transport and Dio integration in the public Dart package.
- Convert repository to a multi-package workspace (`packages/*`).

## 0.0.1

* TODO: Describe initial release.
