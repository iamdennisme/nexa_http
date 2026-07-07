# nexa_http_native_ios

iOS carrier package for `nexa_http`.

This package is intentionally thin:

- owns iOS-specific native library materialization and packaging
- owns iOS-specific build hook integration
- does not expose public Dart runtime APIs

The actual transport API remains in `package:nexa_http`.
