## ADDED Requirements

### Requirement: Repository example SHALL be the official development demo
The workspace SHALL treat `packages/nexa_http/example` as the single official development demo for supported platform debugging, Flutter-to-Rust integration validation, and benchmark-based transport diagnosis, and repository documentation for that demo MUST describe the current startup flow, host base URLs, and benchmark surface accurately.

#### Scenario: Repository documentation references the demo
- **WHEN** setup guidance or verification refers to the official demo
- **THEN** it MUST point to `packages/nexa_http/example`
- **AND** it MUST describe that demo as the repository development entrypoint rather than a second-class example

#### Scenario: Benchmark documentation describes demo output
- **WHEN** repository documentation explains what the benchmark page measures
- **THEN** it MUST describe the current benchmark metrics exposed by the demo
- **AND** it MUST include the enriched latency and failure-surface information the demo now reports

### Requirement: Demo SHALL use workspace-dev artifact preparation
The official demo SHALL execute the local-development native artifact path instead of the release-consumer path, and that `workspace-dev` path SHALL prepare or validate native artifacts from current repository source rather than trusting pre-existing local binaries as authoritative input.

#### Scenario: Contributor runs the demo from a repository checkout
- **WHEN** a user clones the repository and follows the documented demo steps
- **THEN** the demo startup flow MUST prepare or resolve native artifacts through `workspace-dev`
- **AND** it MAY require documented local development prerequisites
- **AND** it MUST NOT require editing demo source files or demo dependency declarations

#### Scenario: Repository contains stale local native binaries
- **WHEN** repository-local demo startup runs in `workspace-dev` and stale local native binaries are present from an older source state
- **THEN** the demo MUST NOT trust those binaries solely because they already exist
- **AND** it MUST use current repository source as the authoritative development input

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

### Requirement: Demo Startup Is A Governed Development Contract
The official demo startup path SHALL remain a governed repository workflow.

#### Scenario: Maintainer changes demo startup semantics
- **WHEN** a maintainer proposes to change how the official demo resolves artifacts, starts native transport, or is launched for repository development
- **THEN** that change MUST be proposed through OpenSpec before implementation is considered complete
