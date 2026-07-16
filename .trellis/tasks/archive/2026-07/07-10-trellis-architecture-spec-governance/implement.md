# Trellis architecture spec governance implementation plan

## Preconditions

- Work from the existing `07-10-trellis-architecture-spec-governance` task.
- Load `trellis-before-dev` before implementation and follow the project TDD policy for routing behavior.
- Do not start product refactors or modify runtime/build/release behavior.
- Keep the worktree scoped to this task; the existing `chore(trellis): update to 0.6.7` commit remains separate.

## 1. Add RED governance contracts

- [x] Add `test/trellis_governance_test.dart`.
- [x] Assert the expected 13-package discovery result, exact paths, spec layers and no default package.
- [x] Assert configured paths, layer indexes and index-local links exist.
- [x] Add tracked-Markdown local-link validation with fenced-example exclusions.
- [x] Add absence assertions for `/backend/` spec paths, `Internal merged native layer`, stale integration tag examples and spec placeholders.
- [x] Run the focused test and record the expected failures against the current tree.

Validation:

```bash
fvm dart test test/trellis_governance_test.dart
```

## 2. Correct Trellis package routing

- [x] Update `.trellis/config.yaml` with the 13 real package owners from `design.md`.
- [x] Remove `default_package: nexa_http_native_core` without replacing it.
- [x] Run package discovery in text and JSON modes.
- [x] Confirm cross-package tasks may remain unscoped while every package-local task can choose a real owner.

Validation:

```bash
python3 ./.trellis/scripts/get_context.py --mode packages
python3 ./.trellis/scripts/get_context.py --mode packages --json
```

## 3. Migrate and tighten Rust specs

- [x] Move every `.trellis/spec/<rust-package>/backend/` directory to `rust/` with Git-aware moves.
- [x] Merge no-persistence rules into each owner’s `directory-structure.md`.
- [x] Merge logging/diagnostic rules into each owner’s `error-handling.md`.
- [x] Delete the five `database-guidelines.md` and five `logging-guidelines.md` files and remove their index rows.
- [x] Remove carrier hook, CodeAsset, CI runner, clean-host and release orchestration rules from FFI quality files while preserving crate-local ABI/proxy/test rules.
- [x] Update all current/archived Markdown and JSONL references from `backend/` to `rust/` without changing historical decisions.

Rollback point: after this step, no `backend/` spec directory or reference may remain. If reference repair is incomplete, revert the whole step rather than adding aliases.

## 4. Add Dart, Flutter carrier and tooling specs

- [x] Add `nexa_http/dart` specs for public API and native transport ownership using public API tests, FFI source tests and ADR-0001/0003/0006/0007/0008.
- [x] Add `nexa_http_native_internal/dart` specs for artifact lifecycle, target matrix and immutable bindings registry using the corresponding source/tests.
- [x] Add a minimal `flutter/index.md` for each carrier containing only platform-specific registration, hook adapter, CodeAsset ID and validation differences; link shared rules instead of copying them.
- [x] Add `nexa_http_workspace/tooling` specs for Verification Catalog, workspace inventory, release transaction and documentation ownership, backed by `scripts/verification/`, root tests and ADR-0009/0010.
- [x] Verify every package layer index has scope, Pre-Development Checklist, Quality Check and valid links.

## 5. Add architecture navigation and provenance

- [x] Add `docs/architecture.md` with context, ADR, authority, spec ownership and provenance tables.
- [x] Link it from `README.md`, `README.zh-CN.md`, `CONTEXT-MAP.md` and `.trellis/spec/guides/index.md`.
- [x] Record the source audit and migration decisions in the current task’s `research/architecture-governance-audit.md`.
- [x] Ensure the index describes current authority without duplicating full ADR/spec content.

## 6. Synchronize current documentation and metadata

- [x] Fix the `nexa_http_native_internal` package description.
- [x] Update four carrier README files with current hook/registration/bindings ownership.
- [x] Update project-layering examples to `v2.0.1` and refresh ADR current-source links after the spec move.
- [x] Simplify `.trellis/workspace/index.md` by removing manually stale counts.
- [x] Repair the 11 known links in the archived v2 public API design; replace two non-existent task links with honest historical text.
- [x] Re-run old-term and old-path searches before continuing.

## 7. Final consistency and quality gate

- [x] Format the new Dart contract test.
- [x] Run the focused governance test until GREEN.
- [x] Run package discovery and inspect all 13 entries.
- [x] Run placeholder, old-path, old-term and stale-version searches.
- [x] Run the repository’s full static verification suite.
- [x] Run `git diff --check` and review the final diff against every PRD acceptance criterion.

Validation commands:

```bash
fvm dart format --output=none --set-exit-if-changed test/trellis_governance_test.dart
fvm dart test test/trellis_governance_test.dart
python3 ./.trellis/scripts/get_context.py --mode packages
rg -n "To be filled|TODO: fill|placeholder" .trellis/spec
rg -n "\.trellis/spec/.*/backend/|Internal merged native layer|ref: v1\.0\.2" . --hidden --glob '!**/.git/**' --glob '!**/.dart_tool/**' --glob '!**/build/**'
fvm dart run scripts/workspace_tools.dart verify-static --execution static-linux
git diff --check
```

Expected search result: no old spec path, drift term or stale integration example. Placeholder wording is allowed only in documents that explicitly teach placeholder detection, not in project specs.

## Start Review Gate

Before running `task.py start`:

- [x] `prd.md`, `design.md` and `implement.md` are complete and mutually consistent.
- [x] No blocking open question remains.
- [x] The user approves implementation of the planned package map, `rust/` migration, spec cleanup, documentation repairs and tests.
