# rust_net_native_ios

iOS carrier package for `rust_net` native artifacts.

This package is intentionally thin:

- owns iOS-specific native artifact packaging
- owns iOS-specific build hook integration
- does not expose public Dart runtime APIs

The actual transport API remains in `package:rust_net`.
