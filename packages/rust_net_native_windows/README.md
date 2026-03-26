# rust_net_native_windows

Windows carrier package for `rust_net` native artifacts.

This package is intentionally thin:

- owns Windows-specific native artifact packaging
- owns Windows-specific build hook integration
- does not expose public Dart runtime APIs

The actual transport API remains in `package:rust_net`.
