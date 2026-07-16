# Trellis architecture spec governance design

## Design Status

Planning-ready. The user confirmed the only open structural decision: all Rust package spec layers move from `backend/` to `rust/` in one clean cutover.

## Constraints

- Preserve the confirmed two-layer product architecture and four bounded contexts.
- Change only Trellis routing, project specs, tests, documentation, and package metadata.
- Do not change public API, native ABI/runtime behavior, artifact bytes, build hooks, verification composition, or release workflow behavior.
- Keep `.trellis/tasks/archive/` as history. Path metadata may be repaired, but historical requirements and decisions must not be rewritten.
- Do not add compatibility directories, symlinks, forwarding documents, or old/new spec paths in parallel.

## Package Routing

`.trellis/config.yaml` will route the repository through 13 real ownership units:

| Package | Path | Spec layer | Ownership |
| --- | --- | --- | --- |
| `nexa_http_workspace` | `.` | `tooling` | root workspace, verification and release tooling |
| `nexa_http` | `packages/nexa_http` | `dart` | public API and Dart native transport |
| `nexa_http_native_internal` | `packages/nexa_http_native_internal` | `dart` | target matrix, artifact lifecycle and bindings registry |
| `nexa_http_native_android` | `packages/nexa_http_native_android` | `flutter` | Android carrier adapter |
| `nexa_http_native_ios` | `packages/nexa_http_native_ios` | `flutter` | iOS carrier adapter |
| `nexa_http_native_macos` | `packages/nexa_http_native_macos` | `flutter` | macOS carrier adapter |
| `nexa_http_native_windows` | `packages/nexa_http_native_windows` | `flutter` | Windows carrier adapter |
| `nexa_http_native_core` | `native/nexa_http_native_core` | `rust` | shared Rust runtime and C ABI implementation |
| `nexa_http_native_apple_proxy` | `native/nexa_http_native_apple_proxy` | `rust` | shared pure Apple proxy parser |
| `nexa_http_native_android_ffi` | `packages/nexa_http_native_android/native/nexa_http_native_android_ffi` | `rust` | Android platform FFI adapter |
| `nexa_http_native_ios_ffi` | `packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi` | `rust` | iOS platform FFI adapter |
| `nexa_http_native_macos_ffi` | `packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi` | `rust` | macOS platform FFI adapter |
| `nexa_http_native_windows_ffi` | `packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi` | `rust` | Windows platform FFI adapter |

`default_package` will be removed. A cross-package task may keep `package: null`; a package-local task must choose an explicit owner. This prevents silent fallback to Rust core while preserving valid architecture-wide work.

Routing data flow:

```text
task.json package (or null)
  -> .trellis/config.yaml package map
  -> get_context.py --mode packages
  -> .trellis/spec/<package>/<layer>/index.md
  -> trellis-before-dev / trellis-check
```

## Target Spec Topology

The final tree follows real code ownership rather than template categories:

```text
.trellis/spec/
├── guides/                                  # cross-package contracts
├── nexa_http_workspace/tooling/
│   ├── index.md
│   └── verification-and-release.md
├── nexa_http/dart/
│   ├── index.md
│   ├── public-api.md
│   └── native-transport.md
├── nexa_http_native_internal/dart/
│   ├── index.md
│   ├── artifact-lifecycle.md
│   └── bindings-registry.md
├── nexa_http_native_{platform}/flutter/
│   └── index.md                             # platform differences only
├── nexa_http_native_core/rust/
│   ├── index.md
│   ├── directory-structure.md
│   ├── error-handling.md
│   └── quality-guidelines.md
├── nexa_http_native_apple_proxy/rust/
│   ├── index.md
│   └── proxy-parser-contract.md
└── nexa_http_native_{platform}_ffi/rust/
    ├── index.md
    ├── directory-structure.md
    ├── error-handling.md
    └── quality-guidelines.md
```

The existing `flutter-sdk-authoring-contract.md`, `project-layering-contract.md`, and `verification-command-contract.md` remain the shared authorities. New package specs link to them and contain only owner-specific source patterns, tests, and anti-patterns.

The useful rules in `database-guidelines.md` move into `directory-structure.md` as state/persistence boundaries. Logging and diagnostic rules move into `error-handling.md`. The 10 source files and their index rows are then deleted.

Platform FFI `quality-guidelines.md` retain only crate-local ABI, platform source, proxy, target and Rust test rules. Carrier hook, CodeAsset, CI runner, clean-host and release proof rules move to the actual carrier/workspace specs or remain in an existing shared guide.

## Architecture Documentation

Create `docs/architecture.md` as a navigation and governance index, not a new source of architectural decisions. It will contain:

- the two-layer architecture summary and links to the four context glossaries;
- a table of ADR-0001 through ADR-0010 with status and owned decision;
- the authority/supersession order;
- links from each implementation area to its package spec;
- review provenance: architecture review tasks, key commits, `v2.0.1`, and verification evidence entry points.

Authority order:

1. `CONTEXT-MAP.md` and context files own vocabulary only.
2. Accepted ADRs own durable architecture decisions; only a later ADR may supersede them.
3. Shared and package Trellis specs translate those decisions into current executable constraints.
4. README files and `verification-playbook.md` explain consumption and operation; they must follow the decisions and specs.
5. Archived task artifacts provide provenance, not current authority.

`README.md`, `CONTEXT-MAP.md`, and `.trellis/spec/guides/index.md` will link to `docs/architecture.md`.

## Metadata And History Repairs

- Replace `Internal merged native layer` with a description of the internal artifact/bindings helper.
- Make each carrier README describe plugin registration, its hook adapter, carrier-owned bindings factory, and lack of public runtime API.
- Update current ADR source links and the project-layering release example to `v2.0.1`.
- Remove the manually stale developer/session count from `.trellis/workspace/index.md`; retain stable discovery and journal instructions.
- Repair archive-relative links after the `backend/ -> rust/` migration. For task names that were never retained, use non-link historical text rather than inventing files.
- Update archived JSONL spec paths as path metadata only; do not alter their reasons or historical task conclusions.

## Verification Design

Add a root Dart contract test because `verify-static` already runs root `dart test` on `static-linux`.

The test will:

- execute `python3 ./.trellis/scripts/get_context.py --mode packages --json`;
- assert the 13 package names, exact paths, expected layers, and `defaultPackage == null`;
- assert every configured path and declared spec index exists;
- verify package indexes reference existing local files;
- scan tracked Markdown local links while ignoring fenced examples, external URLs, anchors and placeholder paths;
- reject the old `backend/` spec path, `Internal merged native layer`, stale `v1.0.2` integration examples, and spec placeholders.

This tests the same discovery output consumed by Trellis skills instead of merely parsing YAML independently.

## Migration And Rollback

The spec migration is atomic:

1. Add the failing routing/document contract test.
2. Update package config and move all six Rust layers with `git mv`.
3. Reshape existing Rust specs and add Dart/Flutter/tooling specs.
4. Update every current and archived path reference in the same change.
5. Add the architecture index and synchronize metadata/docs.
6. Pass focused tests and the full static suite.

There is no runtime rollout. Rollback is a single Git revert of the governance commit. A partially migrated tree must not be committed because it would leave skill routing and task references inconsistent.

## Risks

- Root package path `.` overlaps all child paths. It is intentionally the owner only for root tooling; package-local tasks must select a more specific package.
- Renaming spec paths can invalidate archived JSONL and Markdown links. The contract test and full reference search are release gates for this task.
- A naive Markdown scanner can misclassify skill examples. The test must ignore fenced code and documented placeholder targets while still checking real links.
- `.trellis/config.yaml` is project-owned customization and may be reported as modified by future `trellis update`; Trellis must preserve it rather than replacing it with auto-detected Cargo-only packages.
