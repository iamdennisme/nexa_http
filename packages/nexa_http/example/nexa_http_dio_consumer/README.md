# nexa_http_dio_consumer

This app simulates a separate Flutter project that already uses `Dio` and
integrates `nexa_http` as its HTTP transport.

## Run

From the repository root:

```bash
dart run 'fixture_server/http_fixture_server.dart' --port 8080
```

Then in this app:

```bash
flutter pub get
flutter run -d macos
```

The app relies on the native asset resolved by the matching
`nexa_http_native_<platform>` package.

The macOS Runner entitlements in this example also enable
`com.apple.security.network.client`, since the default sandboxed template
cannot issue outbound HTTP requests without it.
