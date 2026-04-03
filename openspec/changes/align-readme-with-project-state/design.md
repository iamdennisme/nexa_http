## Context

The repository has recently tightened its release-tag workflow, external consumer verification, and governed operating-contract documentation. Those changes are in the code and in some newer docs, but the README surface is still uneven: the top-level docs contain a stale Rust path, the example docs do not fully describe the current benchmark metrics, and some command examples still assume plain `dart` even though the actual repo workflow now leans on `fvm` for reliable toolchain matching.

There is also a reader-experience problem rather than just a correctness problem. The current top-level README is internally accurate in many places, but it reads from the repository's point of view instead of the reader's point of view. External users, demo runners, and maintainers all land in the same document, yet the document starts with internal structure before telling each audience what they actually need to do.

## Goals / Non-Goals

**Goals:**
- Correct README content that no longer matches the actual repository structure or recommended workflow.
- Align example benchmark documentation with the metrics currently exposed by the demo.
- Make the top-level README files easier to read by organizing them around user tasks before internal architecture.
- Preserve the governed integration/release contract while making it easier to discover.
- Keep English and Chinese top-level docs aligned in structure and intent.

**Non-Goals:**
- Redesigning the SDK API or release process itself.
- Rewriting every package README in the workspace.
- Changing governed workflow semantics beyond the documentation needed to describe the current state.
- Turning the README into a full maintainer manual; deeper release/process details can still live in dedicated docs.

## Decisions

### 1. Use a task-first README structure
The top-level README files will lead with the most common reader tasks:
- what the SDK is
- how to use it in an app
- how to run the demo
- how to consume from a release tag
- what maintainers should run
- only then, how the workspace is structured internally

Why:
- Most readers arrive with a job to do, not a desire to study the package graph.
- This keeps the docs more human without weakening technical accuracy.

Alternatives considered:
- Keep the current structure and only patch factual mismatches. Rejected because it would preserve the current “correct but colder” reading experience.

### 2. Prefer `fvm` in repository-facing command examples
Documentation that tells readers how to run repository-local Dart/Flutter workflows will prefer `fvm dart` / `fvm flutter` where toolchain drift is a realistic failure mode.

Why:
- Recent real usage in this repository showed that system `dart` can be too old for current language-version requirements.
- README examples should bias toward the path most likely to work.

Alternatives considered:
- Keep using plain `dart` everywhere for brevity. Rejected because it understates a real source of failure.

### 3. Treat benchmark docs as part of the demo contract
The example README should describe the benchmark metrics the UI and exported model actually provide today, including first-request, post-warmup, P99, max latency, and failure breakdown.

Why:
- The benchmark is part of the official demo path.
- If the README describes an older metric surface, readers form the wrong expectations.

Alternatives considered:
- Leave benchmark metric details to the UI only. Rejected because the README is the user's first map of what the benchmark is for.

## Risks / Trade-offs

- [Task-first docs can hide some internal architecture context from maintainers who liked the old structure] → Mitigation: keep a dedicated workspace-layout section later in the document.
- [Preferring `fvm` may feel heavier for users with a correct local SDK already installed] → Mitigation: explain that plain `dart` can still work when the local toolchain matches.
- [English and Chinese docs can drift again after the rewrite] → Mitigation: keep the section order and intent aligned even when phrasing differs.
