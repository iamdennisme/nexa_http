## 2.0.0

- Migrate `rust_net` to `hook/build.dart` + `code_assets` based native asset distribution.
- Raise the workspace and package SDK baseline to Dart 3.11 / Flutter 3.41.5.
- Stop tracking platform native binaries in git; publish them via GitHub Release assets instead.
- Keep the RINF-style execute channel while switching native symbol binding to `@Native`.
