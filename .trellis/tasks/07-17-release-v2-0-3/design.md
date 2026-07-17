# Release v2.0.3 - Design

## Release Boundary

`v2.0.3` 的 source interval 是已发布 `v2.0.2` peeled commit `4baef319fbddcdb47722c5696ee6f7bacc7bda15` 到本次 release preparation commit。唯一产品仓库行为增量位于 verification tooling：

```text
failed child command
  -> live stdout/stderr handlers remain unchanged
  -> immutable bounded tails retained on typed failure
  -> Android install adapter classifies one exact boot-race signature
       -> matching: same device + same release APK, max 3 attempts, 2s delay
       -> non-matching/untyped: fail immediately
  -> install success resumes the unchanged full runtime proof chain
```

本次 metadata edit 只允许包含：

```text
six package pubspec versions -> 2.0.3
five tracked path lock resolutions -> 2.0.3
nexa_http CHANGELOG -> verification-only 2.0.3 notes
copyable Git dependency examples -> v2.0.3
layering current-release example + governance assertion -> v2.0.3
Trellis release task/evidence
```

不修改 Dart product runtime、Rust/native source、C ABI、generated bindings、target matrix、build hooks、candidate assembly、release workflow 或 publication tooling。

## Version And Documentation Ownership

| Authority | `v2.0.3` action | Must remain historical |
| --- | --- | --- |
| Six release package `pubspec.yaml` files | Set one exact stable version | None |
| Five tracked package lockfiles | Resolve only local `nexa_http_native_internal` path version | Hosted `node_preamble 2.0.2` |
| `packages/nexa_http/CHANGELOG.md` | Add a new top section | Existing `2.0.2` and older sections |
| Root EN/ZH and package README | Move current copyable refs to `v2.0.3` | No historical provenance is owned here |
| Layering contract + governance assertion | Move current integration example together | Archived tasks/spec evidence |
| Archived tasks and workspace journal | No edit | All `v2.0.2` release and hardening facts |

The validator derives the dispatch version from the six package pubspecs. Lockfiles are normal dependency-resolution outputs, not a second version authority.

## Flutter SDK Authoring Contract Mapping

- **Host integration surface:** dependency refs move to `v2.0.3`; host runtime code remains `import 'package:nexa_http/nexa_http.dart'`.
- **Hidden internal packages:** `nexa_http_native_internal` remains an implementation dependency and is not documented as an app-facing API.
- **Native lifecycle ownership:** carrier registration, artifact packaging, bindings ownership and native body/client lifecycle do not change.
- **Formal configuration:** no mirror, offline, source-selection, debug or host-native configuration is added.
- **Failure reporting:** bounded stdout/stderr tails are CI/verification diagnostics only; public SDK failure taxonomy and app-visible errors do not change.
- **Clean-host acceptance:** candidate consumers for Android, iOS, macOS and Windows remain mandatory. Android retry success is not acceptance; the unchanged request/callback/body consume/body release/client close proof is still required.

## Transaction Sequence

```text
prepare exact metadata
  -> local focused + full static validation
  -> commit release source
  -> fetch and fast-forward push main
  -> wait exact-SHA normal CI + ci-gate
  -> validate exact origin/main SHA for dispatch
  -> workflow dispatch publish=false
       -> 3 immutable fragments
       -> 1 private candidate (9 native assets + manifest + SHA256SUMS)
       -> Android/iOS/macOS/Windows candidate consumers
       -> aggregate
       -> publisher skipped
       -> assert v2.0.3 public state absent
  -> workflow dispatch publish=true for the same source SHA
       -> independent private candidate transaction
       -> same four-platform topology and aggregate
       -> unique publisher creates annotated tag + stable Release
  -> verify tag target, Release state, all 11 names and digests
  -> record evidence, archive task, journal and push bookkeeping
```

Rehearsal and publishing runs have different private candidate IDs because they are separate transactions, but both build the same approved source SHA. Within either run, all platform gates and the publisher must consume one exact candidate ID/digest without rebuilding, renaming or copying a second candidate.

## Remote State Invariants

- Before release preparation push: local planning/metadata only; `v2.0.3` tag and Release absent.
- After push and normal CI: approved source exists on `origin/main`; `v2.0.3` public state still absent.
- After rehearsal: private diagnostics may exist as Actions artifacts; public tag/Release state remains absent.
- After successful publication: one annotated `v2.0.3` tag, one stable Release and exactly 11 uploaded assets exist and are immutable.
- `v2.0.2` tag, Release and assets are never inputs to mutation or cleanup.

## Failure And Rollback

- **Before push:** correct local metadata and rerun gates; no remote release state exists.
- **Remote main advanced:** stop and reconcile by normal history; never force push or dispatch a stale SHA.
- **Normal CI or rehearsal failed:** leave `v2.0.3` absent, diagnose, fix forward on main, and restart validation with the new SHA.
- **Publishing gate failed before publisher:** public state must remain absent; do not manually promote partial artifacts.
- **Publisher failed:** audit its transaction marker and compensation. Retry is blocked until owned state is stably absent and no ambiguous public state remains.
- **Publication succeeded:** no rollback by retagging or asset replacement; any correction becomes a later patch release.

## Evidence Contract

- Record approved release commit and exact `origin/main` resolution.
- Record local focused/full gate results and exact-SHA normal CI run.
- Record rehearsal and publishing run IDs, conclusions, candidate identities/digests, per-platform report results and aggregate state.
- Record annotated tag object/peeled target, Release ID/state/URL and exact 11-asset name/digest set.
- Keep evidence in task-local `evidence.md` before archive; historical `v2.0.2` evidence remains untouched.
