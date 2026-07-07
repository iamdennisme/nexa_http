# nexa_http_native_windows

Windows carrier package for `nexa_http`.

This package is intentionally thin:

- owns Windows-specific native library materialization and packaging
- owns Windows-specific build hook integration
- does not expose public Dart runtime APIs

The actual transport API remains in `package:nexa_http`.
