# Implement OpenSpec simplify native layering

## Goal

Archive the completed OpenSpec change `simplify-native-layering` by syncing its delta specs into the main OpenSpec specs and moving the change under `openspec/changes/archive/`.

## Background

- `openspec` CLI is unavailable in this environment, so the OpenSpec archive and spec-sync flow must be performed manually from filesystem artifacts.
- The change directory is `openspec/changes/simplify-native-layering`.
- `openspec/changes/simplify-native-layering/tasks.md` marks all implementation tasks complete.
- The active delta specs modify these capabilities:
  - `ci-enforced-consumer-verification`
  - `git-consumer-dependency-boundary`
  - `native-distribution-source-of-truth`
  - `platform-runtime-verification`
  - `runtime-loader-platform-strategies`
  - `tag-authoritative-release-governance`
  - `workspace-version-alignment`
- The main specs still contain old runtime/distribution split, package-version alignment, and tag-authoritative release-identity requirements that this change removes or rewrites.
- A previously archived OpenSpec change, `clarify-public-api-vs-platform-dependencies`, already clarified that `nexa_http` is the only public Dart API surface while platform carrier packages remain explicit public dependency artifacts. This archive must preserve that distinction while applying `simplify-native-layering`.

## Requirements

- Sync each delta spec into its corresponding main spec without reintroducing stale wording from older changes.
- Preserve the explicit distinction between public Dart API surface (`nexa_http`) and explicit platform dependency artifacts (`nexa_http_native_<platform>`).
- Remove or rewrite main-spec requirements that depend on:
  - `nexa_http_runtime` or `nexa_http_distribution` as independent architectural layers
  - local package versions as native artifact release identity
  - lockstep workspace package-version governance
  - tag-authoritative native release identity
  - legacy path probing, fallback probing, workspace search, or environment-driven artifact discovery
  - hidden `default_package`-style implicit platform selection as the public contract
- Keep the completed change intact in an archive directory named with today's date.
- Commit the OpenSpec archive/spec-sync work separately from Trellis task archive and session journal commits.
- Leave unrelated untracked watermark files untouched.

## Acceptance Criteria

- [x] Main OpenSpec specs reflect the `simplify-native-layering` delta requirements.
- [x] Main OpenSpec specs no longer contain the old requirements removed by the delta specs.
- [x] The active change directory is moved to `openspec/changes/archive/2026-07-03-simplify-native-layering/`.
- [x] `git diff --check` passes before the work commit.
- [x] The work commit records the OpenSpec sync/archive work.
- [x] Trellis task archive and session journal are recorded after the work commit.
- [x] Remaining active OpenSpec changes are reported accurately.

## Completion Evidence

- Work commit `e91af2d` synchronized and archived the OpenSpec change.
- Trellis archive commit `b620ecb` closed the task; developer journal Session 4 records the archive/spec-sync checks.
- A later approved clean cutover removed the entire OpenSpec tree, so the historical archive directory is intentionally absent from the current repository rather than being an incomplete migration residue.

## Out of Scope

- Do not modify SDK/runtime implementation code unless archive validation reveals the OpenSpec tasks were incorrectly marked complete.
- Do not touch unrelated untracked files:
  - `remove_watermark.py`
  - `watermark_mask.png`
  - `watermark_removed.png`
