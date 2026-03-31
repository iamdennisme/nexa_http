# Nexa HTTP Demo and README Refresh Design

## Status

Approved in chat on 2026-03-31.

## Context

The current `nexa_http` example and README set still reflect the pre-alignment
story:

- the example app is framed as a mixed "HTTP + image performance" demo
- the image page is tied to cache/image-widget behavior rather than raw HTTP
  transport benchmarking
- the root and package READMEs still carry old startup explanations, old git tag
  examples, and workspace-internal details that distract from the new public API
- the public API now aligns with OkHttp semantics, but the demo and docs do not
  tell that story cleanly yet

After the public API simplification, the project needs one consistent external
story:

- end-user code uses `NexaHttpClient`, `RequestBuilder`, `Call`, and `Response`
- platform carrier packages exist, but do not dominate the public narrative
- the example app demonstrates normal HTTP usage and transport benchmarks only
- benchmark results compare `nexa_http` against Dart's default HTTP client under
  the same concurrent workload

## Goals

- Replace the example app's current mixed demo with two clear entry points:
  `HTTP Playground` and `Benchmark`.
- Make the benchmark page compare `nexa_http` vs Dart `HttpClient`.
- Benchmark both byte payload and image download scenarios.
- Keep benchmark parameters adjustable, but limited to a small practical set.
- Rewrite the root, package, and example READMEs so they match the OkHttp-style
  API and the new demo.
- Remove obsolete startup-timing and image-cache-performance narratives.

## Non-Goals

- Redesign the `nexa_http` public API again.
- Add interceptors or new transport features.
- Build a full laboratory-grade benchmark suite with export/report tooling.
- Add new fixture-server protocols unless the existing endpoints prove
  insufficient.
- Turn the example into a polished product UI; clarity is more important than
  presentation flourishes.

## Design Principles

- The example should teach the public API first, internals second.
- Each page should have one job.
- Benchmark controls should be few and understandable.
- Comparisons should be fair and reproducible enough for local development.
- Documentation should explain how to use the SDK, not how the maintainers think
  about every internal subsystem.

## Example App Design

### App Structure

The example app will expose two sections:

- `HTTP Playground`
- `Benchmark`

The app shell remains lightweight and Cupertino-based to fit the existing
example package patterns.

### HTTP Playground

This page is the API teaching surface. It should let a developer:

- enter a full URL
- choose an HTTP method
- optionally edit a request body for body-bearing methods
- send a request through `nexa_http`
- inspect request metadata, response metadata, and body preview

The page should make the OkHttp-aligned flow obvious:

`NexaHttpClientBuilder -> RequestBuilder -> client.newCall(request) -> execute()`

The playground should not talk about manual initialization or runtime lifecycle
because those are now internal concerns.

### Benchmark

This page is a transport comparison tool, not an image cache demo.

It will compare:

- `nexa_http`
- Dart `HttpClient`

under the same request plan, run sequentially to reduce self-interference.

The benchmark page will expose these controls:

- `baseUrl`
- `scenario`: `bytes` or `image`
- `concurrency`
- `totalRequests`
- `payloadSize`
- `warmupRequests`
- `timeout`

Scenario rules:

- `bytes` uses `/bytes?size=...&seed=...`
- `image` uses `/image?id=...` with unique IDs to avoid misleading repeated-path
  behavior

Results will include:

- total duration
- throughput
- average latency
- P50 latency
- P95 latency
- success count
- failure count
- bytes received

The benchmark page should show a side-by-side result summary plus a simple
"winner" comparison for the key metrics.

## Example File Boundaries

- `main.dart`: app shell and top-level section switching
- `src/playground/*`: request playground UI and formatting helpers
- `src/benchmark/*`: benchmark controls, runner, metrics, and result views

The old `src/image_perf/*` implementation should be removed because it encodes a
different product story and drags in unrelated dependencies.

## README Rewrite Design

### Root `README.md`

The root English README should explain:

- what the workspace contains
- what the public API looks like
- how end-user apps consume the package plus matching carrier package
- how to run the example app
- how to run the benchmark against the fixture server

It should remove:

- stale release tag examples
- image-cache benchmark narrative
- startup timing storytelling that exposes internal boot mechanics

### Root `README.zh-CN.md`

This should be the Chinese counterpart of the English root README, not a
different document with divergent emphasis.

### `packages/nexa_http/README.md`

This package README should focus on:

- public API shape
- package vs carrier-package responsibility
- compact usage examples
- where to look for the example app and workspace-level docs

### `packages/nexa_http/example/README.md`

This README should explain:

- the two demo pages
- how to launch the fixture server
- how to run the example app
- which environment variables configure the benchmark
- what the benchmark metrics mean

## Testing Strategy

- Widget tests should assert the new `HTTP Playground` and `Benchmark` sections.
- Unit tests should cover the benchmark metric calculations and scenario request
  generation.
- Example package tests should no longer assert the removed image-cache demo.
- Documentation will be validated by matching it against the implemented example
  structure and current public API.
