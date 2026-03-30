# nexa_http_example

Single consumer-style demo app for `nexa_http`.

This app intentionally uses `git` dependencies so it exercises the same package
layout and platform loading path that external projects use.

It includes two pages:

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

## Startup Initialization

The first `NexaHttpClient()` construction is synchronous. It does three pieces
of work on the calling thread:

- resolve and open the native dynamic library
- build the Dart FFI data source
- call the native `createClient` entry point, which lazily initializes the Rust runtime

Because of that, the example app intentionally delays native client
initialization until after the first frame instead of constructing it directly
inside the first `initState()` frame.

When the client finishes initializing, the HTTP demo page shows a timing summary
and also prints it to the console:

```text
nexa_http init: total 18.412 ms | load 3.902 ms | data source 0.115 ms | createClient 14.221 ms
```

The timing fields mean:

- `total`: full synchronous `NexaHttpClient()` construction time
- `load`: dynamic library resolution and `DynamicLibrary.open(...)`
- `data source`: Dart FFI wrapper creation
- `createClient`: native `nexa_http_client_create(...)`

If macOS startup feels janky, check this line first. It tells you whether the
cost is mostly in library loading or in the first native runtime/client setup.

## Local Workspace Debugging

When you need to validate uncommitted local changes, create a temporary
`pubspec_overrides.yaml` next to `pubspec.yaml` and point the packages back to
the workspace paths. The file is ignored on purpose so the committed demo stays
in `git` consumption mode by default.

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
