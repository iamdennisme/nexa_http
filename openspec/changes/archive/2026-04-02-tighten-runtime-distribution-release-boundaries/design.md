## Context

The repository recently separated `nexa_http`, `nexa_http_runtime`, and `nexa_http_distribution`, which improved package boundaries for application code and carrier packages. Two important seams still remain soft.

First, native distribution metadata is consumed from `nexa_http_distribution`, but release-time manifest generation still lives in a standalone script with its own schema knowledge. That creates a second source of truth for asset descriptors, manifest fields, digest generation, and output naming.

Second, runtime loading was moved into `nexa_http_runtime`, but the candidate expansion logic is still concentrated in one large rules file. The package boundary improved, but the internal strategy boundary is still weak.

Finally, version lockstep is now documented but not enforced. The repository can still publish or merge changes that let the seven release-train packages diverge from one another or from the release tag.

## Goals / Non-Goals

**Goals:**
- Make `nexa_http_distribution` the authoritative home for native asset manifest shape and descriptor logic.
- Keep manifest generation callable from existing repository scripts without introducing a second standalone schema definition.
- Split runtime loading into a thin orchestration layer plus explicit platform-specific candidate strategy modules.
- Enforce workspace version alignment through automation instead of documentation alone.
- Make release tooling clearly consume the same source-of-truth logic used by the packages.

**Non-Goals:**
- Redesign the Rust transport runtime or carrier package public behavior.
- Change the current native asset naming convention unless required by consolidation.
- Introduce independent package versioning for runtime or distribution.
- Rework unrelated SDK API surfaces.

## Decisions

### 1. Move manifest schema ownership into `nexa_http_distribution`

`nexa_http_distribution` should own the manifest descriptor model, digest helpers, and serialization rules used by both build-time consumption and release-time generation.

Alternative considered:
- Keep generation in `scripts/generate_native_asset_manifest.dart` and only mirror behavior in the package.

Why not:
- It preserves duplicated schema knowledge and increases drift risk whenever asset descriptors or manifest fields change.

### 2. Keep release workflow and scripts as callers, not schema owners

The GitHub release workflow and repository scripts should keep orchestrating builds and uploads, but they should call shared distribution library logic rather than define manifest behavior themselves. The implementation target is a shared library API consumed by a thin script wrapper, not a new package-owned CLI.

Alternative considered:
- Introduce a package-owned CLI entrypoint for distribution manifest generation.

Why not:
- It adds another public surface and execution mode before the repository actually needs one.

Alternative considered:
- Move all release assembly directly into GitHub Actions shell scripts.

Why not:
- That would further hide schema behavior inside workflow YAML and make testing harder.

### 3. Split runtime loader candidate rules by host platform

`nexa_http_runtime` should keep one loader entrypoint, but delegate candidate discovery to platform-specific modules such as iOS, macOS, Windows, and Android strategy providers. Android may keep a simpler fixed-candidate strategy than desktop platforms; the goal is ownership clarity, not artificial symmetry.

Alternative considered:
- Keep one cross-platform candidate file and only add comments or regions.

Why not:
- The file would remain a rule pile with weak ownership and growing cognitive load.

### 4. Treat workspace version alignment as a verification concern

Version lockstep should be checked by workspace tooling or CI verification rather than relying on human review of README guidance. The enforced set is the seven release-train packages and explicitly excludes `app/demo`.

Alternative considered:
- Keep version policy purely in documentation.

Why not:
- The repository already has enough packages and release surfaces that drift is predictable without automated checks.

## Risks / Trade-offs

- [Shared release logic becomes more central] → Mitigation: keep the new distribution manifest module narrowly scoped and covered by tests.
- [Loader strategy splitting may initially increase file count] → Mitigation: accept more files in exchange for clearer per-platform ownership.
- [Version verification may fail existing ad-hoc workflows] → Mitigation: keep the rule simple, explicit, and aligned with the documented release train.
- [Refactoring release tooling can accidentally alter artifact names or manifest fields] → Mitigation: capture current output shape in tests before consolidation.

## Migration Plan

1. Introduce shared manifest-generation primitives under `nexa_http_distribution`.
2. Update the release script and workflow to consume that shared logic while preserving current output filenames and manifest format.
3. Split runtime candidate discovery into platform strategy modules behind the existing runtime loader API.
4. Add workspace version-alignment and release-tag checks to verification tooling and CI.
5. Update repository documentation to reflect the enforced release model.

Rollback is straightforward at each step because package entrypoints do not need to change. If a step destabilizes release tooling, the repository can temporarily revert to the prior script or candidate implementation without undoing the package split itself.

## Open Questions

- Should runtime candidate strategy modules continue to include workspace fallback behavior by default, or should debug-only fallback become explicit?
