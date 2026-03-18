# rust_net_core

`rust_net_core` is the pure Dart core package for `rust_net`.

It contains:

- immutable request/response entities
- transport-agnostic exception model
- `HttpExecutor` abstraction

This package has no Flutter/plugin dependencies, so it can be used in shared
domain layers, tests, and adapters.

## Install

```yaml
dependencies:
  rust_net_core: ^0.1.0
```

## Example

```dart
import 'package:rust_net_core/rust_net_core.dart';

final request = RustNetRequest.get(uri: Uri.parse('https://example.com/ping'));
```
