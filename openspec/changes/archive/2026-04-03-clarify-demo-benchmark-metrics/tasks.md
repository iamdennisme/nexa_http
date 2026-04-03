## 1. Extend Benchmark Aggregation

- [x] 1.1 Add failing tests for richer benchmark aggregation, including P99 latency, max latency, and categorized failure breakdown.
- [x] 1.2 Extend `BenchmarkMetrics` aggregation to compute P99 latency, max latency, and categorized failures from collected samples.
- [x] 1.3 Keep existing measured-run totals and request counts stable while adding the richer metrics.

## 2. Capture Cold-Start Signal Separately

- [x] 2.1 Add failing coverage that benchmark output records first-request latency separately from the measured concurrent run.
- [x] 2.2 Update the benchmark runner to capture a dedicated first-request latency without polluting measured samples or total-duration accounting.

## 3. Enrich Export And Demo Presentation

- [x] 3.1 Extend benchmark JSON/export output with first-request latency, post-warmup average latency, P99 latency, max latency, failure breakdown, and run-order metadata.
- [x] 3.2 Update the benchmark UI to show first-request latency, post-warmup average latency, and P99 latency.
- [x] 3.3 Surface failure breakdown only when failures occur so the benchmark remains readable in the success case.

## 4. Final Verification

- [x] 4.1 Run focused benchmark tests for metric aggregation and cold-start accounting.
- [x] 4.2 Run the example Flutter test suite and confirm the benchmark page still renders and reports the enriched metrics correctly.
