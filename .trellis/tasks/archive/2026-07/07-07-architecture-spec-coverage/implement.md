# Implementation Plan

## Scope

Write the confirmed two-layer architecture principles into AI-facing context/spec and human-facing README/verification documentation, then remove or correct stale AI documentation that would mislead future sessions.

## Ordered Steps

- [x] Read task artifacts and applicable Trellis shared guides before editing.
- [x] Update `CONTEXT.md` so the domain context uses the two main monorepo layers as the primary architecture frame.
- [x] Add or update Trellis spec guidance for the confirmed project layering, external app dependency contract, artifact materialization, and native-core boundary.
- [x] Update README / verification documentation so external integration examples and architecture wording match the confirmed contract.
- [x] Search for stale wording that treats release assets, native runtime artifacts, carrier packages, or internal native helper as independent top-level architecture layers.
- [x] Audit remaining project docs and AI docs for template placeholders, dead references, stale OpenSpec entrypoints, and language-policy conflicts.
- [x] Correct stale workspace/task/ADR/spec content that is still useful.
- [x] Delete local AI docs that are obsolete and not part of the current Trellis workflow.
- [x] Run lightweight documentation validation commands and report any skipped broader checks.

## Validation

```bash
rg -n "vX\.Y\.Z|native runtime artifact|release asset|nexa_http_native_internal|package:nexa_http_native" CONTEXT.md README.md README.zh-CN.md docs/verification-playbook.md .trellis/spec
rg -n "docs/superpowers|All documentation must be written|\(Add details\)|Fill with" AGENTS.md CONTEXT.md README.md README.zh-CN.md docs .trellis/spec .trellis/workspace .trellis/tasks/07-07-architecture-spec-coverage .agents
find .claude/commands .claude/skills .codex .agents/skills -maxdepth 3 \( -path '*openspec*' -o -path '*opsx*' -o -path '*improve-codebase-architecture*' \) -print
python3 ./.trellis/scripts/get_context.py --mode packages
```

Latest validation result: the searches only report intentional historical references in workspace journal and current task notes; no current OpenSpec entrypoint, template placeholder, or architecture-conflicting public doc remains. `git diff --check` and `get_context.py --mode packages` pass.

## Risk / Rollback Points

- `CONTEXT.md`: preserve existing glossary facts while changing the organizing frame.
- `.trellis/spec/guides/`: keep rules in Chinese and add index links so future agents can discover them.
- README and verification docs: preserve user-facing examples while replacing placeholders or stale architecture language.
- Do not modify SDK/runtime implementation code in this task.
