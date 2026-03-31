# nexa_http_example

Consumer-style demo app for `nexa_http`.

## Pages

The app has two pages:

- `HTTP Playground`: build a real request with the public API and inspect the
  response
- `Benchmark`: run the same concurrent request plan through `nexa_http` and
  Dart `HttpClient`

The benchmark supports two scenarios:

- `bytes`: hits `/bytes?size=...&seed=...`
- `image`: hits `/image?id=...`

## Run

From the repository root, start the fixture server:

```bash
dart run fixture_server/http_fixture_server.dart --port 8080
```

Then run the example app:

```bash
cd packages/nexa_http/example
fvm flutter pub get
fvm flutter run -d macos
```

Common local base URLs:

- macOS / Windows host: `http://127.0.0.1:8080`
- Android emulator: `http://10.0.2.2:8080`
- Android device with `adb reverse tcp:8080 tcp:8080`: `http://127.0.0.1:8080`

## Benchmark Defaults

The benchmark page is configurable in the UI, and these environment variables
set the initial values:

- `NEXA_HTTP_EXAMPLE_BASE_URL`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_SCENARIO`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_CONCURRENCY`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_TOTAL_REQUESTS`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_PAYLOAD_SIZE`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_WARMUP_REQUESTS`
- `NEXA_HTTP_EXAMPLE_BENCHMARK_TIMEOUT_MS`

Example launch:

```bash
fvm flutter run -d macos \
  --dart-define=NEXA_HTTP_EXAMPLE_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=NEXA_HTTP_EXAMPLE_BENCHMARK_SCENARIO=image \
  --dart-define=NEXA_HTTP_EXAMPLE_BENCHMARK_CONCURRENCY=16 \
  --dart-define=NEXA_HTTP_EXAMPLE_BENCHMARK_TOTAL_REQUESTS=120 \
  --dart-define=NEXA_HTTP_EXAMPLE_BENCHMARK_PAYLOAD_SIZE=65536 \
  --dart-define=NEXA_HTTP_EXAMPLE_BENCHMARK_WARMUP_REQUESTS=8 \
  --dart-define=NEXA_HTTP_EXAMPLE_BENCHMARK_TIMEOUT_MS=15000
```

## Metrics

Each benchmark run shows:

- total duration
- throughput in `MiB/s`
- requests per second
- average latency
- P50 latency
- P95 latency
- success count
- failure count
- bytes received

The two transports run sequentially on purpose, so one run does not steal
bandwidth or sockets from the other.
