# Formalize domain model and architecture review - Implementation Plan

## Checklist

- [x] Review historical design docs one last time and map each to ADR, non-authoritative, or deletion-only.
- [x] Create `CONTEXT.md` with current domain glossary.
- [x] Create `docs/adr/`.
- [x] Write ADR-0001: `public Dart SDK root API`.
- [x] Write ADR-0002: `explicit platform carrier dependencies`.
- [x] Write ADR-0003: `unified async FFI transport`.
- [x] Write ADR-0004: `platform-owned proxy runtime state`.
- [x] Delete `docs/superpowers/specs/` after ADR extraction.
- [x] Remove empty `docs/superpowers/` if no files remain.
- [x] Regenerate the Chinese architecture HTML report in the OS temp directory.
- [x] Update task PRD acceptance checkboxes if the completed work satisfies them.

Generated report:

- `/var/folders/cd/sw2110553dq651kvkmh937jw0000gn/T/architecture-review-20260707-005309.html`

## Validation Commands

Documentation / cleanup validation:

```bash
test -f CONTEXT.md
test -d docs/adr
test ! -d docs/superpowers/specs
! rg -n "rust_net|Dio adapter|binary pipeline|rinf|NexaHttp\\.warmUp|NexaHttp\\.shutdown|NexaHttpClient\\.open" CONTEXT.md README.md README.zh-CN.md packages/*/README.md docs/verification-playbook.md .trellis/spec
git diff --name-only -- '*.dart' '*.rs' '*.sh' 'Cargo.toml' 'pubspec.yaml'
git status --short
```

ADRs may mention superseded terms in `alternatives considered`; the stale-term check intentionally excludes `docs/adr`.

Report validation:

```bash
test -f "$REPORT_PATH"
rg -n "CONTEXT.md|docs/adr|public Dart SDK|platform carrier|Rust transport core|module|interface|seam|adapter|locality|leverage" "$REPORT_PATH"
```

No runtime test suite is required because the task should not change source behavior. If implementation accidentally touches Dart/Rust/source files, stop and re-scope before continuing.

## Risky Files / Rollback Points

- `docs/superpowers/specs/`: delete only after ADR content exists.
- `docs/adr/*.md`: keep ADRs concise; they are durable decision records, not full design specs.
- `CONTEXT.md`: avoid historical/deprecated terms; current model only.

Rollback points:

- Before deleting `docs/superpowers/specs/`, confirm ADRs exist and cite their source docs.
- After regenerating the report, confirm it references the new glossary and ADRs rather than temporary inferred vocabulary.

## Review Gate

Before `task.py start`, review:

- `prd.md`
- `design.md`
- `implement.md`

Implementation should not begin until the user approves this planning set.
