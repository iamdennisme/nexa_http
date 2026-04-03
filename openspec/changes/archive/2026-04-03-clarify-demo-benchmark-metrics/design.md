## Context

The official demo benchmark already provides a lightweight A/B comparison between `nexa_http` and Dart `HttpClient`, and its current execution model is intentionally simple: both transports run the same scenario sequentially against the local fixture server. The benchmark already collects per-request samples with latency, bytes, success state, status code, and error message, but the exported result model and UI compress those samples into a small summary that hides startup cost, tail behavior, and failure causes.

The repository also treats demo startup and diagnosis as a governed development contract. Because `nexa_http` uses lazy native startup, benchmark consumers need a clearer separation between cold-start signal and measured steady-state metrics without broadening workload scope or changing the current sequential benchmark model.

## Goals / Non-Goals

**Goals:**
- Make benchmark results more diagnostic without changing the official demo scenarios.
- Surface the most decision-relevant signals for Flutter-to-Rust transport evaluation: first-request cost, post-warmup aggregate latency, tail latency, and failure categories.
- Preserve current benchmark execution semantics closely enough that existing request counts, total measured runs, and sequential comparison behavior remain understandable.
- Keep benchmark JSON output suitable for future automation.

**Non-Goals:**
- Adding new benchmark scenarios or changing fixture-server behavior.
- Introducing CPU, memory, thread, or system-level profiling.
- Replacing sequential transport execution with parallel or randomized scheduling.
- Changing the public `nexa_http` API or native runtime behavior.

## Decisions

### Decision: Keep the benchmark execution model and enrich only the result semantics
The benchmark will continue to run Dart `HttpClient` first and `nexa_http` second against the existing `bytes` and `image` scenarios. Instead of broadening workload coverage, this change will make the current benchmark easier to interpret by exporting richer metrics and metadata.

**Alternatives considered:**
- Expand workload coverage first. Rejected because it increases scope before fixing the clarity problem in the current benchmark.
- Randomize transport order. Rejected for this change because order control is a separate experimental-design concern; exposing run-order metadata is enough for now.

### Decision: Measure cold-start signal separately from the measured run
The benchmark runner will capture a dedicated first-request latency signal separately from the measured concurrent run. That cold-start request will not be folded into the measured sample set or measured total duration, which preserves the meaning of the main run while surfacing lazy startup cost explicitly.

**Alternatives considered:**
- Infer first-request latency from the first completed sample. Rejected because the sample list is completion-ordered under concurrency and does not reliably identify the first dispatched request.
- Fold cold-start into average latency only. Rejected because it obscures whether regressions come from startup or steady-state execution.

### Decision: Compute richer latency and failure summaries from existing samples
The benchmark will extend its aggregation layer to derive P99 latency, max latency, and categorized failure counts from the collected per-request samples. This keeps the change localized to the demo benchmark and avoids expanding transport interfaces.

**Alternatives considered:**
- Add new transport-specific instrumentation. Rejected because the current sample model already carries enough information for the first diagnostic upgrade.
- Export raw samples only and leave aggregation to downstream tooling. Rejected because the official demo should remain directly interpretable by maintainers.

### Decision: Keep the UI focused on a small set of added metrics
The benchmark page will expose first-request latency, post-warmup average latency, and P99 latency as the primary new fields. Failure breakdown will appear only when failures occur, and max latency can remain available in exported output without immediately becoming a prominent UI field.

**Alternatives considered:**
- Show every new metric in the primary card. Rejected because it would make the demo harder to scan in the success case.

## Risks / Trade-offs

- **Cold-start probe changes benchmark semantics slightly** → Keep the cold-start request separate from measured totals and document the distinction explicitly in exported output and UI wording.
- **Failure categorization may be heuristic** → Start with coarse, stable buckets such as timeout, HTTP error, and transport/native error rather than overfitting detailed classifications.
- **Richer metrics may tempt over-interpretation** → Preserve explicit run-order metadata and keep the proposal scoped to metric clarity rather than broader performance claims.
