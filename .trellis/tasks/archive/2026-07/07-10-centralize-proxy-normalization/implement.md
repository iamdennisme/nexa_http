# Centralize proxy normalization - Implementation Plan

## Preconditions

- [x] 用户已审阅 `prd.md`、`design.md` 和本计划，并明确批准实现。
- [x] 批准后运行 `task.py start`；planning 阶段没有修改 production code。
- [x] 实现前加载 `trellis-before-dev`，重新读取受影响 package specs 和 TDD policy。
- [x] 重新检查 `07-10-decompose-rust-executor` 与当前 worktree，确认没有重叠迁移。

## Ordered Checklist

- [x] 记录 focused test baseline，并确认 workspace 当前通过。
- [x] RED: 添加 test-only shared fixture 与 core primitive integration tests；确认失败原因是 planned exports 尚不存在。
- [x] GREEN: 新增 `platform/proxy_normalization.rs`，实现 cleanup、URL normalize、bypass split、bypass canonicalize，并从 `platform/mod.rs` 重导出。
- [x] 将 core env fallback、bypass merge 和 snapshot canonicalization 切换到唯一 shared implementation，删除 `proxy.rs` 中重复 helper。
- [x] 将 Apple parser 切换到 shared cleanup/URL/canonicalization；保持 entry/port/default scheme/`<local>` 逻辑；删除本地 helper和 direct `url` dependency。
- [x] 扩充 Apple tests：支持 scheme/invalid/quote fixture、negative port、invalid sibling isolation、含 separator 的 atomic exception。
- [x] 将 Android adapter 切换到 shared primitives；保留 `getprop`/`with_port`；删除本地 helper和 direct `reqwest` dependency；用 shared expectations补 bypass/empty/invalid coverage。
- [x] 将 Windows adapter 切换到 shared primitives；保留 registry/`ProxyServer` grammar且不调用 cleanup；删除本地 helper和 direct `reqwest` dependency；用 shared expectations补 exact bypass/empty/invalid/quote coverage。
- [x] 保持 iOS/macOS adapter代码不变；运行其 delegation 和 refresh tests。
- [x] 搜索确认所有生产重复 helper、forwarder和 parser-only direct dependency 已删除。
- [x] 运行 `trellis-update-spec`，更新 core、Apple、Android、Windows 和 project layering ownership 文档。
- [x] 运行 focused checks、workspace checks、Apple integration gate 和 diff scope review。

## Validation Commands

Focused behavior and lint:

```bash
cargo fmt --all -- --check
cargo clippy --no-deps \
  -p nexa_http_native_core \
  -p nexa_http_native_apple_proxy \
  -p nexa_http_native_android_ffi \
  -p nexa_http_native_windows_ffi \
  --all-targets -- -D warnings
cargo test \
  -p nexa_http_native_core \
  -p nexa_http_native_apple_proxy \
  -p nexa_http_native_android_ffi \
  -p nexa_http_native_windows_ffi \
  -p nexa_http_native_ios_ffi \
  -p nexa_http_native_macos_ffi
cargo test --workspace
```

Clean-cutover searches:

```bash
rg -n "fn (normalize_proxy_url|clean_value|parse_bypass_list|dedup_bypass|canonicalize_bypass)" native packages --glob '*.rs'
rg -n "use (reqwest|url)::Url" native/nexa_http_native_apple_proxy packages/nexa_http_native_android packages/nexa_http_native_windows --glob '*.rs'
cargo tree -p nexa_http_native_apple_proxy -e normal --depth 1
cargo tree -p nexa_http_native_android_ffi -e normal --depth 1
cargo tree -p nexa_http_native_windows_ffi -e normal --depth 1
```

The first search should find only the canonical core functions whose final names intentionally match; it must not find platform-local wrappers. Dependency trees may still contain `reqwest` transitively through core, but the platform manifests must not declare parser-only direct dependencies.

Scope and patch hygiene:

```bash
git diff --check
git diff --name-only
git status --short
```

Expected source scope is core proxy module/tests, Apple/Android/Windows parser sources/tests/manifests, possible `Cargo.lock`, and relevant Trellis task/spec documents. Public Dart, C header/bindings, carrier hooks, artifact/release scripts and iOS/macOS SystemConfiguration sources must remain unchanged.

## Risky Files

- `native/nexa_http_native_core/src/platform/proxy.rs`
- `native/nexa_http_native_core/src/platform/proxy_normalization.rs`
- `native/nexa_http_native_core/src/platform/mod.rs`
- `native/nexa_http_native_core/tests/fixtures/proxy_normalization_cases.rs`
- `native/nexa_http_native_apple_proxy/src/lib.rs`
- Android/Windows `src/proxy_source.rs`
- Apple/Android/Windows `Cargo.toml` and possibly `Cargo.lock`
- Core/Apple/Android/Windows proxy tests
- `.trellis/spec/guides/project-layering-contract.md` and affected Rust package specs

## Rollback Points

- After fixture RED: verify cases describe existing behavior, especially quoted Windows bypass and atomic Apple exceptions.
- After core GREEN: run core tests before migrating any adapter.
- After each adapter migration: run that crate's focused tests before deleting its direct dependency.
- Before spec update: run duplicate/dependency searches and confirm the final ownership matches the design.
- Any public API/ABI, artifact, refresh policy or raw grammar change requires returning to planning; do not absorb it into this refactor.

## TDD Evidence

| Slice | RED | GREEN / verification |
|---|---|---|
| Core primitives | `cargo test -p nexa_http_native_core --test proxy_normalization` failed with unresolved imports because the new exports did not exist. | Added the pure module and re-exports; cleanup, all six supported schemes, invalid URL, splitting and canonicalization tests passed. |
| Apple migration | Existing Apple parser suite was the behavior baseline; the new shared fixture/atomic-exception assertions guarded the migration boundary. | `cargo test -p nexa_http_native_apple_proxy` passed 10 tests; iOS/macOS adapter suites each passed 3 tests. |
| Android/Windows migration | Existing adapter tests supplied the raw grammar baseline; shared expectation cases were added before deleting local helpers. | Android 4 tests and Windows 5 tests passed, including empty/direct, invalid sibling, and Windows quote preservation. |

## Verification Results

- `cargo fmt --all -- --check`: passed.
- `cargo clippy --no-deps -p nexa_http_native_core -p nexa_http_native_apple_proxy -p nexa_http_native_android_ffi -p nexa_http_native_windows_ffi --all-targets -- -D warnings`: passed.
- `cargo clippy --workspace --all-targets -- -D warnings`: passed.
- `cargo test --workspace`: passed.
- `cargo tree` confirmed Apple `url` and Android/Windows direct `reqwest` are absent; core `reqwest` remains transitive/owned by core.
- Apple integration command with real simulator ID `52F67B16-7615-48D7-9F13-2698EA9E8023` and `macos=macos` passed native build, iOS simulator/macOS runtime proofs, external consumer, development path and demo tests. Report: `/tmp/nexa-http-apple-macos-report.json`.
- The first integration attempt used the placeholder `ios-simulator` and failed only at device selection; it was rerun with the discovered real simulator ID and passed.

## Review Gate

Implementation and verification are complete. Inline mode did not curate the seed `implement.jsonl` / `check.jsonl`; context was loaded through `trellis-before-dev`.
