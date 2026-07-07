# nexa_http_native_macos

macOS carrier package for `nexa_http`.

This package is intentionally thin:

- owns macOS-specific native library materialization and packaging
- owns macOS-specific build hook integration
- does not expose public Dart runtime APIs

The actual transport API remains in `package:nexa_http`.
