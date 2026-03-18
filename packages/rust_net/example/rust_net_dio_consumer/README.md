# rust_net_dio_consumer

This app simulates a separate Flutter project that already uses `Dio` and
integrates `rust_net` as its HTTP transport.

## Run

From the repository root:

```bash
dart run rust_net:prepare_macos_native --configuration debug
dart run 'fixture_server/http_fixture_server.dart' --port 8080
```

Then in this app:

```bash
flutter pub get
flutter run -d macos
```

The app does not pass a `nativeLibraryPath`. It relies on the packaged macOS
plugin resource that `prepare_macos_native` produces under
`../../macos/Libraries/`.

The macOS Runner entitlements in this example also enable
`com.apple.security.network.client`, since the default sandboxed template
cannot issue outbound HTTP requests without it.
