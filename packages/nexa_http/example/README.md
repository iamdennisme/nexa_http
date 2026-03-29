# nexa_http_example

Demo app for `nexa_http`.

It currently includes two demos:

- HTTP inspector: enter a full URL, send a `GET` request with `nexa_http`, and inspect request and response details
- Image performance: compare the default image transport against a `nexa_http`-backed cache pipeline

## Run

From the repository root:

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
```

Then in this app:

```bash
cd packages/nexa_http/example
fvm flutter pub get
fvm flutter run -d macos
```

The default base URL is:

```text
http://127.0.0.1:8080
```

Target-specific base URLs:

- macOS / Windows host: `http://127.0.0.1:8080`
- Android emulator: `http://10.0.2.2:8080`
- Android device with `adb reverse tcp:8080 tcp:8080`: `http://127.0.0.1:8080`
- Physical device over LAN: start the fixture server with `--host 0.0.0.0` and use your host LAN IP

You can override the base URL at launch time:

```bash
fvm flutter run -d macos \
  --dart-define=RUST_NET_EXAMPLE_BASE_URL=http://127.0.0.1:8080
```

## Autorun Image Benchmark

You can launch the image performance demo directly:

```bash
fvm flutter run -d macos \
  --dart-define=RUST_NET_EXAMPLE_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=RUST_NET_EXAMPLE_IMAGE_PERF_SCENARIO=image \
  --dart-define=RUST_NET_EXAMPLE_IMAGE_PERF_TRANSPORT=default_http \
  --dart-define=RUST_NET_EXAMPLE_IMAGE_PERF_IMAGE_COUNT=24
```

Supported benchmark defines:

- `RUST_NET_EXAMPLE_IMAGE_PERF_SCENARIO`: `image` or `autoscroll`
- `RUST_NET_EXAMPLE_IMAGE_PERF_TRANSPORT`: `default_http` or `nexa_http`
- `RUST_NET_EXAMPLE_IMAGE_PERF_IMAGE_COUNT`: total fixture tiles to render
