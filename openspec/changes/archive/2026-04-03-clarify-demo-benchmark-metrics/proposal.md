## Why

The official demo benchmark currently compares `nexa_http` against Dart `HttpClient`, but its reported metrics are stronger as demo presentation than as diagnostic evidence for Flutter-to-Rust transport tradeoffs. It does not clearly separate lazy native startup cost from steady-state behavior, expose tail latency beyond P95, or explain failures beyond a single failure count, which makes benchmark results hard to interpret.

## What Changes

- Extend the example benchmark result model to report first-request latency, post-warmup average latency, P99 latency, max latency, categorized failures, and explicit run-order metadata.
- Keep the benchmark focused on the current demo scenarios and sequential comparison model; improve metric clarity rather than broadening workload coverage.
- Update benchmark JSON/export output so automated runs and future tooling can consume the richer diagnostics.
- Update the benchmark UI to surface the most decision-relevant additions without overwhelming the demo presentation.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `demo-platform-runnability`: the official demo benchmark must surface metrics that distinguish cold-start cost, steady-state latency, tail latency, and failure modes clearly enough for maintainers to reason about Flutter-to-Rust transport behavior.

## Impact

- Affected code: `packages/nexa_http/example/lib/src/benchmark/benchmark_runner.dart`, `benchmark_models.dart`, `benchmark_page.dart`, `packages/nexa_http/example/lib/main.dart`, and `packages/nexa_http/example/test/benchmark_runner_test.dart`
- Affected interfaces: benchmark JSON/export payload and benchmark metric cards in the official demo UI
- Affected systems: local demo benchmarking and any automation that consumes exported benchmark results
