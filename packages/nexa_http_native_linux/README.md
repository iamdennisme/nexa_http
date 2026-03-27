# nexa_http_native_linux

Linux carrier package for `nexa_http` native artifacts.

This package is intentionally thin:

- owns Linux-specific native artifact packaging
- owns Linux-specific build hook integration
- does not expose public Dart runtime APIs

The actual transport API remains in `package:nexa_http`.
