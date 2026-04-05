## MODIFIED Requirements

### Requirement: Repository example SHALL be the official development demo
The workspace SHALL treat `app/demo` as the single official development demo for supported platform debugging, Flutter-to-Rust integration validation, and benchmark-based transport diagnosis, and repository documentation for that demo MUST describe the current startup flow, host base URLs, and benchmark surface accurately.

#### Scenario: Repository documentation references the demo
- **WHEN** setup guidance or verification refers to the official demo
- **THEN** it MUST point to `app/demo`
- **AND** it MUST describe that demo as the repository development entrypoint rather than a second-class example

#### Scenario: Benchmark documentation describes demo output
- **WHEN** repository documentation explains what the benchmark page measures
- **THEN** it MUST describe the current benchmark metrics exposed by the demo
- **AND** it MUST include the enriched latency and failure-surface information the demo now reports
