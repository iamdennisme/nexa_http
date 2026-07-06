# Formalize domain model and architecture review

## Goal

Create a repository-backed domain glossary and ADR baseline before treating architecture-review output as actionable guidance.

After this task, future architecture scans should use `CONTEXT.md` and `docs/adr/` as the current vocabulary and decision baseline instead of inferred README/package names or historical design drafts.

## Background

The `improve-codebase-architecture` workflow expects:

- `CONTEXT.md` to provide domain language for naming modules and seams.
- `docs/adr/` to record accepted decisions that architecture reviews should not re-litigate.

Repository inspection found no `CONTEXT.md` and no `docs/adr/` directory. The repo does contain README files, Trellis specs, verification docs, tests, package names, and historical design docs under `docs/superpowers/specs/`. A preliminary architecture report was generated from inferred vocabulary; it is not authoritative because the domain glossary did not exist yet.

## Confirmed Facts

- The product is `nexa_http`, a Flutter HTTP SDK with an OkHttp-style Dart API and a Rust-powered transport core.
- Runtime app code imports only `package:nexa_http/nexa_http.dart`; app dependency declarations include `nexa_http` plus each target platform carrier package.
- `packages/nexa_http` owns the `public Dart SDK` surface: `NexaHttpClient`, `NexaHttpClientBuilder`, `Request`, `RequestBuilder`, `Call`, `Response`, `ResponseBody`, `Headers`, `MediaType`, `Callback`, and `NexaHttpException`.
- `packages/nexa_http_native_internal` owns internal runtime/loading, platform registry, native artifact materialization, target matrix, and release-consumer helpers.
- Android, iOS, macOS, and Windows carrier packages own platform-specific native artifact packaging and do not expose public Dart runtime APIs.
- `native/nexa_http_native_core` is the shared Rust transport core. Trellis specs describe it as owning HTTP runtime, FFI data structures, proxy abstraction, and error model.
- Platform FFI crates under `packages/*/native/*_ffi` produce platform native artifacts, bind shared core runtime to platform proxy sources, and export the uniform C ABI.
- Existing design docs record load-bearing decisions about federated native packaging, OkHttp-style public API alignment, unified async FFI transport, platform-owned proxy runtime state, and release/consumer verification.
- The Flutter SDK authoring contract requires clean-host integration through standard package management, public Dart API, and standard Flutter build/run flows.

## Requirements

- Create `CONTEXT.md` at repository root.
- Write `CONTEXT.md` with English canonical terms and Chinese explanations.
- Use `public Dart SDK` as the canonical term for the app-facing `packages/nexa_http` package.
- Keep `CONTEXT.md` focused on the current domain model; do not include a historical/deprecated terms section.
- Mark glossary entries as confirmed, inferred, or needs-owner-decision when evidence does not fully settle the term.
- Include relationships for architecture review language, especially among `public Dart SDK`, `native transport`, `platform carrier`, `native artifact`, `Rust transport core`, `platform FFI crate`, `proxy settings`, `platform runtime state`, `release artifact`, and `clean-host consumer`.
- Create `docs/adr/`.
- Write ADRs in Chinese while preserving English canonical terms where they map to code/package/module names.
- Name ADR files with stable English numbered slugs, for example `docs/adr/0001-public-dart-sdk-root-api.md`.
- Use a consistent ADR structure: title, status, background, decision, consequences, and alternatives considered.
- Create these four initial ADRs:
  - `nexa_http` is the `public Dart SDK`; the root API exposes HTTP semantics only.
  - Platform carriers use explicit app dependencies and own native artifact/package integration.
  - All supported platforms use one unified async FFI transport pipeline.
  - Platform FFI crates own proxy/runtime state sources; the Rust transport core consumes abstract platform state.
- Do not create standalone ADRs for superseded `Public API Simplification`, draft `Platform Features V1`, or demo README refresh decisions unless a later conflict requires them.
- Remove `docs/superpowers/specs/` after extracting load-bearing current decisions into ADRs. The cleaned repository should treat `CONTEXT.md`, `docs/adr/`, Trellis specs, README files, and verification docs as the current written sources.
- Regenerate the architecture review after `CONTEXT.md` and ADRs exist.
- The regenerated report must be Chinese, self-contained HTML in the OS temp directory, and explicitly cite the confirmed glossary/ADR baseline.
- Do not implement architecture refactors as part of this task.

## Out Of Scope

- Refactoring Dart, Rust, hooks, release tooling, or package layout.
- Changing public API, native ABI, artifact packaging, or verification commands.
- Converting every historical design doc into an ADR mechanically.
- Preserving `docs/superpowers/specs/` as a long-term canonical source.

## Acceptance Criteria

- [x] `CONTEXT.md` exists and contains a concise domain glossary with evidence-backed terms and explicit uncertainty markers.
- [x] `docs/adr/` exists with the four initial ADRs listed in Requirements.
- [x] Planning identifies which historical design docs are sources for each ADR.
- [x] `docs/superpowers/specs/` has been removed after ADR extraction, or the task records why removal was unsafe.
- [x] The regenerated architecture report uses `CONTEXT.md` vocabulary instead of inferred temporary vocabulary.
- [x] The regenerated report marks any candidate that contradicts an ADR as an explicit ADR conflict.
- [x] No source-code behavior changes are made.
- [x] Final verification confirms changed files are docs/task/report only, unless the user explicitly expands scope.

## Open Questions

None.
