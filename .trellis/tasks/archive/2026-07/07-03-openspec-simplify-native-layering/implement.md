# Implementation Plan

## Checklist

- [x] Review `openspec/changes/simplify-native-layering` proposal, design, tasks, and delta specs.
- [x] Compare delta specs with main specs and identify stale requirements that must be removed or merged.
- [x] Update each affected main spec under `openspec/specs/`.
- [x] Search for stale OpenSpec wording after the sync:
  - `nexa_http_distribution` as an authoritative package boundary
  - `nexa_http_runtime` as an independent runtime package boundary
  - workspace package-version alignment
  - tag-authoritative release identity
  - default-package implicit selection as public contract
  - fallback/probing/legacy path loader behavior
- [x] Move the completed change to `openspec/changes/archive/2026-07-03-simplify-native-layering/`.
- [x] Run `git diff --check`.
- [x] Commit the OpenSpec sync/archive work.
- [ ] Run Trellis finish-work: archive this task and record the session journal.

## Validation Commands

```bash
git diff --check
git status --short
git log --oneline -5
find openspec/changes -maxdepth 1 -mindepth 1 -type d -print | sort
```

## Risk Points

- The previous `clarify-public-api-vs-platform-dependencies` archive changed related public API/dependency wording. Do not overwrite it with older delta text.
- Removed requirements should be deleted from main specs, not left as contradictory historical requirements.
- Leave unrelated untracked watermark files untouched.
