# Release v2.0.2 - Design

## Release Boundary

This task changes release metadata only. The release commit contains:

```text
six package pubspec versions -> 2.0.2
tracked path lock resolutions -> 2.0.2
nexa_http CHANGELOG -> compatible internal architecture notes
copyable Git dependency examples -> v2.0.2
layering release example + governance assertion -> v2.0.2
```

It does not change Dart runtime code, Rust code, C ABI, generated bindings, target matrix, build hooks, candidate assembly or publication tooling.

## Version And Documentation Ownership

- The six `packages/*/pubspec.yaml` release packages are the validator's version authority and must have one exact stable value.
- Checked-in lockfiles are outputs of normal pub resolution; only local path package versions may change.
- `packages/nexa_http/CHANGELOG.md` records product-facing changes since `v2.0.1`.
- Root English/Chinese README and `packages/nexa_http/README.md` own copyable consumer dependency examples.
- `.trellis/spec/guides/project-layering-contract.md` owns the current architectural dependency example; its literal governance assertion moves with it.
- `docs/architecture.md` keeps historical `v2.0.1` review provenance until a separate post-release audit deliberately updates known-good evidence.

## Host Integration Contract

The release changes only Git refs:

```yaml
dependencies:
  nexa_http:
    git: {url: <repo>, ref: v2.0.2, path: packages/nexa_http}
  nexa_http_native_<platform>:
    git: {url: <repo>, ref: v2.0.2, path: packages/nexa_http_native_<platform>}
```

Host runtime code remains:

```dart
import 'package:nexa_http/nexa_http.dart';
```

Artifact download, checksum verification and cache remain owned by `nexa_http_native_internal`; registration and packaging remain owned by the carrier and standard Flutter build chain. No configuration surface or host workaround is added.

## Transaction Sequence

```text
prepare metadata
  -> local full static gate
  -> commit exact release source
  -> fetch/fast-forward push main
  -> validate exact SHA on origin/main
  -> workflow dispatch publish=false
       -> 3 immutable fragments
       -> 1 candidate (9 native assets + manifest + SHA256SUMS)
       -> Android/iOS/macOS/Windows candidate gates
       -> aggregate
       -> publisher skipped; public state absent
  -> workflow dispatch publish=true for the same SHA
       -> new immutable candidate transaction
       -> identical gate topology
       -> unique publisher creates annotated tag + stable Release
  -> verify tag target, Release state and 11 assets
  -> archive task and push bookkeeping commits
```

The rehearsal and publishing runs have different private candidate IDs because they are independent transactions, but both build the same approved source SHA. Within each run, every gate and publisher consumes exactly one candidate ID/digest without rebuild or copy.

## Remote Mutation Rules

- Before push, fetch `origin/main`; if it is no longer an ancestor of local `main`, stop and reconcile without force.
- Push only `main:main` as a normal fast-forward.
- Dispatch input uses stable version `2.0.2` without `v` and the exact lowercase 40-character release commit SHA.
- Do not create a local or remote `v2.0.2` tag. The publisher creates it after aggregate success.
- `publish=true` is already authorized by the user's instruction, but remains mechanically blocked until the rehearsal succeeds.

## Failure And Rollback

- Before push: revert or amend the unshared release preparation normally; no remote state exists.
- After push but before publication: fix forward with a new commit and use the new SHA; never rewrite remote main.
- Rehearsal/gate failure: inspect the failed job, leave `v2.0.2` absent and return to implementation/check.
- Publisher failure: verify workflow compensation removed only its owned tag/Release. Any residual or ambiguous public state blocks retry and requires explicit audit.
- Successful publication is immutable. Subsequent corrections use `v2.0.3` or another new version.

## Verification Evidence

- Local source gate: `verify-static --execution static-linux` report.
- Remote release gate: all four `verify-release-candidate` row reports plus aggregate in each Actions run.
- Publication proof: exact tag target, stable Release metadata, 11 asset names/digests and successful workflow conclusion.
- Optional post-publication diagnosis may exercise a real `v2.0.2` released consumer, but cannot replace or retroactively redefine the pre-publication candidate gate.
