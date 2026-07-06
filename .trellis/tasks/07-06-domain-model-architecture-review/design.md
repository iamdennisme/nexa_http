# Formalize domain model and architecture review - Design

## Overview

This is a documentation and architecture-review baseline task. It creates current written sources for domain language and architectural decisions, then removes historical design docs that would otherwise compete with the new baseline.

No runtime code, public API, native ABI, package layout, hook behavior, or release tooling should change.

## Current Source Model

Current authoritative sources after the task:

- `CONTEXT.md`: domain glossary for architecture review and future planning.
- `docs/adr/`: accepted architectural decisions that reviews should not re-litigate.
- `.trellis/spec/`: project coding and integration contracts.
- README files: user-facing usage and package responsibility summary.
- `docs/verification-playbook.md`: verification workflow.

Temporary source during the task:

- `docs/superpowers/specs/*.md`: historical design docs used only to extract current decisions into ADRs, then removed.

## Domain Glossary Shape

`CONTEXT.md` uses English canonical terms with Chinese explanations.

Each entry should include:

- status: confirmed, inferred, or needs-owner-decision
- definition
- owns / does not own
- key relationships
- evidence references

The glossary should avoid historical/deprecated terms. Superseded vocabulary belongs in ADR alternatives or consequences if needed, not in the current domain glossary.

Initial confirmed terms:

- `public Dart SDK`
- `host app`
- `platform carrier`
- `native artifact`
- `native transport`
- `Rust transport core`
- `platform FFI crate`
- `uniform C ABI`
- `proxy settings`
- `platform runtime state`
- `release artifact`
- `clean-host consumer`

## ADR Baseline

Create four ADRs:

1. `public Dart SDK root API`
   - Source: `docs/superpowers/specs/2026-03-31-nexa-http-okhttp-api-alignment-design.md`
   - Decision: root API exposes HTTP semantics only; lifecycle/runtime/FFI concerns stay internal.
2. `explicit platform carrier dependencies`
   - Source: `docs/superpowers/specs/2026-03-27-nexa-http-federated-native-design.md`, README files, Flutter SDK authoring contract.
   - Decision: host apps explicitly depend on `nexa_http` plus target platform carriers; carriers own native artifact/package integration.
3. `unified async FFI transport`
   - Source: `docs/superpowers/specs/2026-03-29-unified-async-ffi-transport-design.md`.
   - Decision: all supported platforms use one async FFI request pipeline.
4. `platform-owned proxy runtime state`
   - Source: `docs/superpowers/specs/2026-03-29-proxy-runtime-state-design.md`, current Rust core/platform FFI specs.
   - Decision: platform FFI crates provide proxy/runtime state sources; Rust transport core consumes abstract platform state.

Do not preserve superseded design docs as current architecture evidence after ADR extraction.

## Cleanup Boundary

Delete `docs/superpowers/specs/` after extracting the current decisions.

If `docs/superpowers/` becomes empty, remove the empty directory as part of the cleanup.

Do not delete:

- `docs/verification-playbook.md`
- README files
- `.trellis/spec/`
- task artifacts

## Regenerated Architecture Report

Run the architecture review again after `CONTEXT.md` and ADRs exist.

Report requirements:

- Chinese body text.
- English architecture terms where required by the architecture-review skill: module, interface, implementation, depth, deep, shallow, seam, adapter, leverage, locality.
- Self-contained HTML written to OS temp directory, not the repo.
- Explicitly cites `CONTEXT.md` and `docs/adr/` as the baseline.
- Marks ADR conflicts if a candidate challenges an accepted decision.

## Flutter SDK Contract Mapping

This task changes documentation only.

- Host integration surface: unchanged; host runtime code still imports `package:nexa_http/nexa_http.dart`.
- Native lifecycle ownership: unchanged; carriers and internal packages keep artifact/loading responsibilities.
- Formal configuration: unchanged; no new build-time or runtime configuration.
- Failure reporting: unchanged; ADRs should preserve existing failure-reporting decisions where relevant.
- Clean-host acceptance: regenerated architecture report and ADRs must not imply host native project edits or manual artifact copying.

## Tradeoffs

- Removing historical design docs makes current architecture easier to scan, but ADRs must capture the load-bearing decisions before deletion.
- Keeping ADRs concise avoids turning them into stale design specs, but they must include enough consequence text to block repeated old recommendations.
- `CONTEXT.md` avoids deprecated terms to keep the current domain model clean; historical context moves to ADR alternatives when needed.

## Rollback

Rollback is documentation-only:

- Restore deleted historical docs from git if an omitted decision is discovered.
- Remove or amend an ADR if it captured a decision incorrectly.
- Regenerate the architecture report after corrections.

