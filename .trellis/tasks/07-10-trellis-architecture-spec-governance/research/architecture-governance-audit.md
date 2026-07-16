# Architecture governance source audit

## Scope

Audit date: 2026-07-16. Baseline: `v2.0.1` at `2bdfcce`, plus current `main` documentation and Trellis `0.6.7` update.

This audit covered package ownership, `.trellis/config.yaml`, every package spec, four context glossaries, ADR-0001 through ADR-0010, root/package README files, `docs/verification-playbook.md`, active and archived task metadata, and tracked Markdown navigation. Product API/runtime/build/release behavior was read as evidence but was not changed.

## Source inventory

| Source | Authority used in this review |
| --- | --- |
| `CONTEXT-MAP.md` and `docs/contexts/*/CONTEXT.md` | Ubiquitous language for four bounded contexts |
| `docs/adr/0001-0010` | Accepted durable architecture decisions |
| `.trellis/spec/guides/` | Cross-package execution constraints |
| `.trellis/spec/<package>/<layer>/` | Package-local current implementation constraints |
| Root/package README and verification playbook | Consumer and operator instructions |
| `.trellis/tasks/archive/` and Git history | Review, migration and verification provenance |

## Findings

- Trellis registered only six Rust crates and defaulted unscoped work to `nexa_http_native_core`; the root workspace, public SDK, internal helper and four carriers had no route.
- All six Rust specs used the generic `backend/` layer name. Five crates also carried ten thin database/logging files that duplicated state and diagnostic boundaries.
- Platform FFI quality files owned Flutter carrier, APK/app packaging, CI runner, clean-host and release proof rules outside their Rust adapter boundary.
- No human-facing page joined contexts, ADR status, package specs, authority/取代 order and review evidence.
- `nexa_http_native_internal` metadata used the obsolete `Internal merged native layer` description; carrier README files omitted plugin registration and carrier-owned bindings factories.
- The project layering example used `v1.0.2`, while the known-good release is `v2.0.1`.
- `.trellis/workspace/index.md` manually recorded developer/session counts that the workflow does not maintain.
- Archived `07-10-v2-public-http-api-cutover/design.md` had 11 broken local links: nine were repairable after archive depth changes and two referenced tasks never retained in this repository.
- Two archived JSONL records pointed to Android FFI quality rules that now belong to workspace verification/release ownership.
- Three ignored `.trellis/.backup-*` directories were confirmed unnecessary and removed before this implementation; ignored `.dist/` and `.claude/tmp/` outputs remain outside documentation governance.

## Decisions applied

- Register 13 real package owners and remove `default_package`; architecture-wide tasks may remain unscoped.
- Rename the six Rust layers to `rust/` atomically with no alias, symlink, forwarding document or parallel path.
- Merge process-state/persistence rules into `directory-structure.md` and diagnostic rules into `error-handling.md`, then delete the ten thin files.
- Put public API/transport, artifact/bindings, carrier differences and workspace verification/release rules with their actual owners.
- Keep `docs/architecture.md` as a navigation/governance index; it cannot supersede an ADR or package spec.
- Preserve archived tasks as history while repairing current path metadata and honest navigation.
- Enforce the topology, terminology and Markdown navigation through the root Dart governance contract test consumed by `verify-static`.

## Evidence baseline

- `95dad7a`: split domain language into bounded contexts.
- `55dee2d`: record four-platform integration proof.
- `90d55ec`: add immutable native release transaction.
- `dc5cd28`: resolve exact release identity through the Dart pub cache topology.
- Annotated `v2.0.1` tag: candidate `gha:29384993870:8331179239`, digest `7fcbe86664266b0b704a4c530367344a476f563700325f13f417e6fa77e44516`.

The current task PRD, design and implementation plan own the accepted migration scope. This audit records evidence and classification only; it does not create an additional architecture authority.
