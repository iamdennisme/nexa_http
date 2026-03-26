# rust_net_core

`rust_net_core` is a deprecated compatibility shim for older integrations.

New code should depend on `package:rust_net` directly. The canonical Dart API
surface now lives in `package:rust_net`, while platform-specific native
artifacts are being split into separate carrier packages.

## Install

```yaml
dependencies:
  rust_net: ^2.0.0
```

## Example

```dart
import 'package:rust_net/rust_net.dart';

final request = RustNetRequest.get(uri: Uri.parse('https://example.com/ping'));
```
