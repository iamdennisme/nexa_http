## 1. Simplify core runtime loading

- [x] 1.1 Remove generic candidate-path probing from `packages/nexa_http/lib/src/loader/nexa_http_native_library_loader.dart` so the loader uses only explicit path override and registered runtime delegation.
- [x] 1.2 Delete or reduce `packages/nexa_http/lib/src/loader/nexa_http_native_library_resolver.dart` to only the host-platform primitives still needed by tests after candidate discovery is removed.
- [x] 1.3 Update loader and factory tests in `packages/nexa_http/test/` to assert missing-runtime failures and registered-runtime delegation instead of candidate walking.

## 2. Converge platform runtimes on fixed loading contracts

- [x] 2.1 Simplify `packages/nexa_http_native_macos/lib/src/nexa_http_native_macos_plugin.dart` so it opens only the documented packaged/runtime entry instead of probing bundle, packaged, workspace, and legacy paths.
- [x] 2.2 Simplify `packages/nexa_http_native_windows/lib/src/nexa_http_native_windows_plugin.dart` so it opens only the documented packaged/runtime entry instead of probing packaged and workspace locations.
- [x] 2.3 Review Android and iOS runtime plugins to ensure they still match the fixed-contract design and adjust tests/documentation if any remaining generic discovery assumptions exist.

## 3. Separate external-consumer artifact resolution from workspace-dev

- [x] 3.1 Refactor `packages/nexa_http/lib/src/native_asset/nexa_http_native_artifact_resolver.dart` so external-consumer resolution never compiles Rust or inspects workspace-local target outputs implicitly.
- [x] 3.2 Update carrier build hooks in `packages/nexa_http_native_android`, `packages/nexa_http_native_ios`, `packages/nexa_http_native_macos`, and `packages/nexa_http_native_windows` to use explicit external-consumer versus workspace-dev behavior.
- [x] 3.3 Fix the macOS carrier hook so release/external-consumer builds resolve the correct packaged or released artifact without ambiguous universal-binary assembly from local workspace outputs.

## 4. Re-verify governed contracts

- [x] 4.1 Update repository verification and spec-aligned tests so they fail if shared loader logic or carrier runtimes reintroduce overlapping discovery behavior.
- [x] 4.2 Verify the official demo still runs through workspace-dev preparation without runtime workspace probing, using the repository FVM-managed Flutter/Dart toolchain.
- [x] 4.3 Verify an external consumer build path still works through packaged or released assets only, including macOS build coverage, using the repository FVM-managed Flutter/Dart toolchain.
