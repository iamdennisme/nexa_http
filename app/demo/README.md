# nexa_http_demo

This is the official demo app for the `nexa_http` workspace.

Its job is simple:

- show how an app uses the public SDK
- prove that the Flutter → FFI → Rust path still works end to end

## What is in the demo

The app has two sections:

- `HTTP Playground` — send a real request through `nexa_http`
- `Benchmark` — compare `nexa_http` with Dart `HttpClient`

Benchmark scenarios:

- `bytes` — `/bytes?size=...&seed=...`
- `image` — `/image?id=...`

## Run

From the repository root, start the fixture server:

```bash
fvm dart run fixture_server/http_fixture_server.dart --port 8080
```

Then build fresh local artifacts and run the demo on macOS:

```bash
./scripts/build_native_macos.sh debug
./scripts/build_native_ios.sh debug
cd app/demo
fvm flutter pub get
fvm flutter run -d macos
```

Other supported targets:

```bash
cd app/demo
fvm flutter pub get
fvm flutter run -d windows
fvm flutter run -d android
fvm flutter run -d ios
```

## Local base URLs

- macOS / Windows host: `http://127.0.0.1:8080`
- Android emulator: `http://10.0.2.2:8080`
- Android device with `adb reverse tcp:8080 tcp:8080`: `http://127.0.0.1:8080`
- iOS simulator on the same host: `http://127.0.0.1:8080`

## Benchmark environment variables

- `NEXA_HTTP_DEMO_BASE_URL`
- `NEXA_HTTP_DEMO_BENCHMARK_SCENARIO`
- `NEXA_HTTP_DEMO_BENCHMARK_CONCURRENCY`
- `NEXA_HTTP_DEMO_BENCHMARK_TOTAL_REQUESTS`
- `NEXA_HTTP_DEMO_BENCHMARK_PAYLOAD_SIZE`
- `NEXA_HTTP_DEMO_BENCHMARK_WARMUP_REQUESTS`
- `NEXA_HTTP_DEMO_BENCHMARK_TIMEOUT_MS`
- `NEXA_HTTP_DEMO_AUTO_RUN_BENCHMARK`
- `NEXA_HTTP_DEMO_EXIT_AFTER_BENCHMARK`
- `NEXA_HTTP_DEMO_BENCHMARK_OUTPUT_PATH`

Example:

```bash
fvm flutter run -d macos \
  --dart-define=NEXA_HTTP_DEMO_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=NEXA_HTTP_DEMO_BENCHMARK_SCENARIO=image \
  --dart-define=NEXA_HTTP_DEMO_BENCHMARK_CONCURRENCY=16 \
  --dart-define=NEXA_HTTP_DEMO_BENCHMARK_TOTAL_REQUESTS=120 \
  --dart-define=NEXA_HTTP_DEMO_BENCHMARK_PAYLOAD_SIZE=65536 \
  --dart-define=NEXA_HTTP_DEMO_BENCHMARK_WARMUP_REQUESTS=8 \
  --dart-define=NEXA_HTTP_DEMO_BENCHMARK_TIMEOUT_MS=15000
```

## Notes

For local native debugging, prepare fresh artifacts with the platform build scripts before running the demo. The demo should consume prepared binaries at runtime instead of rebuilding Rust implicitly during app integration.

For the full verification flow, including Windows guidance and git+tag consumer validation, see [`../../docs/verification-playbook.md`](../../docs/verification-playbook.md).
