# nexa_http_example

Simple `nexa_http` demo app.

The page does one thing:

- enter a full URL
- send a `GET` request with `nexa_http`
- inspect request and response details on screen

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

The default URL is:

```text
http://127.0.0.1:8080/get?source=nexa_http_example
```

You can override the base URL at build time:

```bash
flutter run -d macos --dart-define=RUST_NET_EXAMPLE_BASE_URL=http://127.0.0.1:8080
```
