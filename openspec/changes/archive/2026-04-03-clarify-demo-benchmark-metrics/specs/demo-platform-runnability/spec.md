## MODIFIED Requirements

### Requirement: Repository example SHALL be the official development demo
The workspace SHALL treat `packages/nexa_http/example` as the single official development demo for supported platform debugging, Flutter-to-Rust integration validation, and benchmark-based transport diagnosis.

#### Scenario: Repository documentation references the demo
- **WHEN** setup guidance or verification refers to the official demo
- **THEN** it MUST point to `packages/nexa_http/example`
- **AND** it MUST describe that demo as the repository development entrypoint rather than a second-class example

### Requirement: Demo bootstrap failures SHALL be diagnosable
The official demo SHALL surface structured bootstrap errors when native startup fails, and its benchmark output SHALL surface enough structured transport metrics to distinguish startup cost, steady-state behavior, tail latency, and failure modes.

#### Scenario: Native startup fails during demo initialization
- **WHEN** native artifact resolution, library loading, proxy preparation, config decoding, or client creation fails
- **THEN** the demo MUST surface a structured failure with a machine-readable code and stage
- **AND** verification MUST be able to assert on those diagnostics

#### Scenario: Maintainer inspects successful benchmark output
- **WHEN** the demo benchmark completes successfully
- **THEN** the reported metrics MUST include first-request latency
- **AND** they MUST include post-warmup aggregate latency
- **AND** they MUST include tail latency through at least P99
- **AND** they MUST preserve categorized benchmark failures whenever failures occur

#### Scenario: Benchmark results are exported for automation
- **WHEN** benchmark results are written to stdout or a benchmark output file
- **THEN** the exported payload MUST preserve the enriched metric fields
- **AND** it MUST identify the transport run order used for the comparison
