# nexa_http_native_android

Android carrier package for `nexa_http` native artifacts.

This package is intentionally thin:

- owns Android-specific native artifact packaging
- owns Android-specific build hook integration
- does not expose public Dart runtime APIs

The actual transport API remains in `package:nexa_http`.
