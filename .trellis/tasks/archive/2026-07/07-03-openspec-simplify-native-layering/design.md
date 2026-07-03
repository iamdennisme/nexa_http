# Design

## Boundary

This task is an OpenSpec archival sync, not a new implementation pass. The source of truth is the completed change at `openspec/changes/simplify-native-layering`; the target is the main spec tree under `openspec/specs/` plus the OpenSpec archive directory.

## Flutter SDK Contract Mapping

- Host dependency declaration: supported consumers declare `nexa_http` plus the target platform carrier package(s), for example `nexa_http_native_macos` for macOS.
- Host runtime code: application code imports only `package:nexa_http/nexa_http.dart`; carrier packages and internal native layers remain outside runtime API examples.
- Hidden internal collaboration: the merged internal native layer owns supported artifact metadata, fixed artifact paths, runtime loading, and structured bootstrap errors; carrier packages only produce or expose platform artifacts.
- Lifecycle ownership: SDK/carrier/build tooling owns artifact preparation, verification, registration, and packaging. Standard docs must not require host native project edits, manual file copies, or custom host scripts.
- Formal configuration: release-consumer resolution uses the selected Git tag/ref or documented package-manager dependency shape, not package-version-derived release identity.
- Failure reporting: missing artifact selection or unavailable release assets must fail with structured setup/bootstrap errors identifying the failure stage and platform context.
- Clean-host acceptance: repository release/consumer verification must model a clean host declaring `nexa_http` and explicit target carrier dependencies, then importing only the `nexa_http` public API.

## Spec Sync Strategy

Apply the delta specs semantically instead of blindly copying files. The main specs already include changes from `clarify-public-api-vs-platform-dependencies`, so the sync must merge both decisions:

- `nexa_http` remains the only public Dart API surface for application code.
- Platform carrier packages remain explicit public dependency artifacts selected by consumers.
- Internal native runtime/distribution concerns collapse into one merged internal native layer.
- The architecture rejects local package versions, lockstep package-version alignment, tag-derived native release identity, historical fallback paths, and generic runtime probing.

## Capability Updates

- `ci-enforced-consumer-verification`: keep CI consumer checks but make release-consumer verification depend on selected Git tag/ref and explicit platform dependencies, not package-version alignment.
- `git-consumer-dependency-boundary`: preserve the public API/dependency-artifact distinction while removing any need for `nexa_http_runtime` or `nexa_http_distribution`.
- `native-distribution-source-of-truth`: rewrite the old distribution-package source-of-truth requirement into a merged internal native-layer source-of-truth requirement and remove stable distribution-output compatibility requirements.
- `platform-runtime-verification`: enforce merged native-layer target agreement, artifact-only carrier boundaries, no version/release/legacy logic, and no separate runtime/distribution layers.
- `runtime-loader-platform-strategies`: require explicit supported artifact loading through the merged internal native layer, with structured failure when no artifact is selected.
- `tag-authoritative-release-governance`: remove tag-authoritative native release identity requirements.
- `workspace-version-alignment`: remove workspace version-alignment, release-tag/package-version matching, and matching documentation requirements.

## Archive Shape

Move `openspec/changes/simplify-native-layering` to `openspec/changes/archive/2026-07-03-simplify-native-layering`. The move preserves `.openspec.yaml`, proposal, design, tasks, and delta specs.

## Rollback

If validation shows an incorrect sync, restore from the active change directory before archiving or from the archive copy after the move. Keep the work commit separate so the OpenSpec sync/archive can be reverted without touching Trellis journal/archive commits.
