## Context

The repository defines two different native-artifact operating modes: `workspace-dev` for local repository development and `release-consumer` for external applications. The intended contract is that the official demo runs in `workspace-dev` and reflects current workspace source, while external consumers rely on packaged or released assets without implicit local Rust compilation.

Today the development resolver still accepts an already-existing local native binary as a successful resolution result before it considers preparing a fresh artifact from source. That makes repository-local demo startup vulnerable to stale binaries: a previously built dylib can be treated as authoritative input even when the checked-out Rust source has changed. In practice this breaks the source-authoritative mental model and can produce runtime drift between the current repository state and the binary loaded by the demo.

## Goals / Non-Goals

**Goals:**
- Make `workspace-dev` source-authoritative for repository-local demo startup.
- Ensure local demo startup prepares or validates native artifacts against current workspace source instead of trusting stale binaries merely because they exist.
- Preserve `release-consumer` behavior for external projects and published GitHub Actions artifacts.
- Add verification that catches drift between current source and repository-local development artifacts.

**Non-Goals:**
- Changing external consumer artifact resolution semantics.
- Replacing published release assets with local builds for `release-consumer`.
- Redefining the supported target matrix or release asset naming.
- Introducing broader changes to Flutter runtime loading outside the governed `workspace-dev` contract.

## Decisions

### Decision: `workspace-dev` must treat source as authoritative, not existing binaries
The development resolver will no longer accept a pre-existing local binary as sufficient proof that the artifact is valid for the current source tree. In `workspace-dev`, source preparation must be the authoritative path, and any local binary that is reused must be the result of that source-driven preparation step rather than an unchecked discovery shortcut.

**Alternatives considered:**
- Keep current discovery-first behavior and document manual clean/rebuild steps. Rejected because it leaves the official demo path vulnerable to stale binary drift.
- Delete all local binaries before each run. Rejected because it is operationally heavy and treats cleanup as user work rather than resolver behavior.

### Decision: Preserve `release-consumer` exactly as-is
The change is limited to repository-local development semantics. External projects and published GitHub Actions assets must continue to use `release-consumer` rules without implicit local Rust compilation.

**Alternatives considered:**
- Unify both modes under one resolver strategy. Rejected because the two workflows intentionally have different trust boundaries and operational constraints.

### Decision: Enforce source-authoritative behavior in development-path verification
Repository verification should assert not only that local demo startup works, but also that the development path does not silently trust stale native binaries. The verification layer is the right place to lock this down because demo startup semantics are a governed contract.

**Alternatives considered:**
- Fix resolver behavior without adding verification. Rejected because the regression would be easy to reintroduce later.

## Risks / Trade-offs

- **More frequent local rebuilds may slow demo startup** → Accept the cost in `workspace-dev`; correctness of source-authoritative behavior is more important than reusing unchecked binaries.
- **Resolver changes could accidentally affect external consumers** → Keep the mode split explicit and add verification that `release-consumer` behavior remains unchanged.
- **Source freshness rules can become ambiguous if based only on file existence** → Prefer a source-preparation-first flow or a deterministic freshness check rather than existence-only discovery.
