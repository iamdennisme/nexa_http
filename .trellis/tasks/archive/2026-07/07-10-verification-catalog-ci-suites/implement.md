# Verification Catalog and CI suites — Implementation Plan

## 1. Preconditions

- Active dependency `07-10-v2-public-http-api-cutover` 已完成。
- 实现前读取：
  - `.trellis/spec/guides/verification-command-contract.md`
  - `.trellis/spec/guides/flutter-sdk-authoring-contract.md`
  - `.trellis/spec/guides/project-layering-contract.md`
  - `.trellis/spec/guides/tdd-development-policy.md`
  - `.trellis/spec/guides/code-reuse-thinking-guide.md`
  - `.trellis/spec/guides/cross-layer-thinking-guide.md`
  - `docs/adr/0010-verification-catalog-owns-gate-composition.md`
- 使用 FVM：Flutter 3.41.5 / Dart 3.11.3。
- 每个行为严格按一个 RED → 最小 GREEN → REFACTOR推进；不得先批量写完tests再实现。

## 2. Ordered TDD slices

### Slice 1 — Catalog integrity

1. RED：duplicate check ID构造Catalog失败。
2. GREEN：建立最小model/catalog与唯一性校验。
3. RED：suite引用未知check、重复membership或无法满足runner coverage时失败。
4. GREEN：加入suite index、dependency和coverage validation。
5. REFACTOR：固定稳定排序和typed IDs。

Validation：Catalog unit tests。

### Slice 2 — Thin CLI and clean command surface

1. RED：新CLI parser只接受 `bootstrap`、三个suite、`check`、`matrix`；旧commands返回unknown。
2. GREEN：抽出 `verification/cli.dart`，让 `workspace_tools.dart` 只dispatch。
3. RED：source contract拒绝 `workspace_tools.dart` 中存在 `Process.run`、suite member list、fixture/build实现。
4. GREEN：迁移最小process/utility seam，不增加forwarder。
5. REFACTOR：删除 generic `verify`、所有旧 top-level atomic verification commands、aliases和wrapper functions。

Validation：CLI/parser tests + legacy absence search。

### Slice 3 — Planner dedupe and run context

1. RED：同一 `(checkId, normalized scope)` 重复出现时只产生一个plan node。
2. GREEN：实现execution key与stable topological plan。
3. RED：同一build/fixture/digest resource被多个checks消费时producer只执行一次。
4. GREEN：实现run-context memoization和resource/conflict keys。
5. RED：冲突资源不得并发；独立资源可以进入有界并发。
6. GREEN/REFACTOR：实现executor最小调度策略。

Validation：fake runner instrumentation tests，断言exact execution counts。

### Slice 4 — Streaming process runner and workspace inventory

1. RED：长stdout/stderr被增量转发，runner不依赖完整buffer后才输出。
2. GREEN：用 `Process.start` 实现process runner与exit diagnostics。
3. RED：多check请求workspace packages时只扫描/解析一次。
4. GREEN：实现memoized `WorkspaceInventory`。
5. REFACTOR：从旧workspace tool提取package discovery，不复制逻辑。

Validation：process fake/integration tests + inventory counter tests。

### Slice 5 — `verify-static`

逐个行为加入：

1. workspace Dart analyze。
2. workspace Dart tests，每个package恰好一次。
3. Rust fmt check。
4. Rust workspace clippy。
5. Rust workspace tests。
6. generated bindings freshness。
7. FFI/source/workflow/architecture contract checks。

每项都先写缺失membership或fake-command RED，再加入一个Catalog check。不得把命令序列复制到suite implementation；suite只消费Catalog plan。

Validation：static suite membership tests、fake runner exact commands、真实本机可运行static checks。

### Slice 6 — Dynamic matrix and execution groups

1. RED：matrix logical target union必须与canonical targets双向一致。
2. GREEN：从canonical matrix派生 Android/Apple/Windows execution groups。
3. RED：target重复属于多个group或没有group时失败。
4. GREEN：加入exclusive coverage validation。
5. RED：Android/iOS多targets不得导致同一platform build script多次execution。
6. GREEN：planner按execution group生成一个build producer。
7. RED：`matrix --suite` stdout必须是稳定、可解析、无日志污染的JSON。
8. GREEN/REFACTOR：实现suite-specific Actions JSON projection。

Validation：matrix schema/coverage/build-once tests。

### Slice 7 — Minimal consumer materialization

1. RED：fixture materializer只包含主包、目标carrier、internal transitive closure和必要workspace manifests。
2. GREEN：复用/抽取 `materialize_distribution.dart` 的dependency closure与filtered-copy能力。
3. RED：同一suite/execution多checks请求fixture时只materialize一次。
4. GREEN：lazy cached fixture handle + exactly-once cleanup。
5. RED：fixture runtime只import public API且依赖正确carrier。
6. GREEN：统一v2 fixture template。
7. RED：已发布release consumer诊断缺repo URL/ref或错误ref时返回明确失败。
8. GREEN：把旧 `verify-release-consumer` 能力迁移为Catalog `released-consumer` check，不保留top-level command。

Validation：fixture file-set、copy-count、public import和cleanup tests。

### Slice 8 — `verify-integration`

按execution group逐个增加：

1. 正式platform build script producer。
2. 同一artifact的exact ABI check。
3. development path。
4. external clean-host build/runtime smoke。
5. missing prerequisite失败和issue-ready diagnostics。

每个子行为独立RED/GREEN；删除现有iOS prerequisite skip-as-pass。若build script缺少明确target/group输入，只在对应platform script中增加正式参数，Catalog不得复制Cargo/toolchain逻辑。

Validation：fake build exact-once tests；Android/Apple/Windows build rows；Android、iOS、macOS、Windows分别独立的runtime proof；ABI和consumer integration tests。

### Slice 9 — Candidate set contract

1. RED：缺失opaque candidate identity/expected digest输入失败。
2. GREEN：typed candidate verification input parser；不固定transaction metadata schema。
3. RED：缺asset、额外asset、manifest/checksum不一致失败。
4. GREEN：canonical completeness validation。
5. RED：wrong digest失败，且同一artifact多个checks只stream读取一次。
6. GREEN：streaming digest cache与verified handles。
7. RED：suite input的candidate identity/digest/SDK ref不完整或与验证结果不一致时失败。
8. GREEN：opaque identity binding和candidate-set digest验证adapter。

Validation：complete/missing/extra/wrong-digest/wrong-identity fixtures + read-count instrumentation。

### Slice 10 — `verify-release-candidate`

1. RED：Android/iOS/macOS/Windows任一blocking row缺少candidate ABI/runtime membership时Catalog validation失败。
2. GREEN：逐个平台注册最小candidate ABI check。
3. RED：runtime check尝试build或打开未验证candidate path时失败。
4. GREEN：只传递verified candidate handle，instrumentation证明no-build/no-copy。
5. RED：fixture request未实际完成时suite失败；GREEN：接入真实request。
6. RED：callback未交付或多次交付时失败；GREEN：加入callback proof。
7. RED：body未消费/release或重复release时失败；GREEN：加入exactly-once body release proof。
8. RED：缺stage、target、SDK ref、candidate digest、expected action或underlying error任一字段时diagnostic contract失败。
9. GREEN/REFACTOR：完成issue-ready diagnostics并消除四平台重复fixture逻辑。

Validation：四平台matrix contract tests；本地可运行target的candidate smoke；其他平台由Actions runner阻断验证。

### Slice 11 — CI clean cutover

1. RED：workflow contract拒绝direct `dart test`/`cargo test` gate composition、手写target/asset/build command、旧alias。
2. GREEN：CI bootstrap job分别从static/integration `matrix --suite`读取JSON并写入独立outputs，matrix jobs只调用完整suite。
3. RED：完整suite的每个required check必须恰好由一个matrix row覆盖。
4. GREEN：每个row通过suite `--report-out`产出coverage report，最终 `ci-gate` 用同一suite的 `--aggregate-reports`模式验证union完整、无重复。
5. RED：row失败/取消、空matrix或缺report时最终gate失败。
6. GREEN：固定job dependencies与failure semantics，不使用continue-on-error/skip-as-pass。
7. REFACTOR：删除旧YAML sequences与正向保护旧结构的tests。

Validation：workflow parser/contract tests + Actions YAML syntax review。

### Slice 12 — Remove unsafe release authority and documentation drift

1. RED：absence contract拒绝旧 release workflow、tag-triggered/publication-before-gate入口和旧 verification commands。
2. GREEN：删除 `.github/workflows/release-native-assets.yml` 及旧layout tests。
3. 更新 README、verification playbook、Trellis specs和相关 package quality guides，只引用Catalog suite或 `check <id>`。
4. 全仓搜索旧commands、forwarders、target lists和release workflow path，逐项清零。

Validation：legacy absence gate + docs/spec search。

## 3. Expected file areas

主要新增/修改：

- `scripts/workspace_tools.dart`
- `scripts/verification/**`
- `test/verification/**` 或现有root contract tests的重组
- `.github/workflows/ci.yml`
- `scripts/build_native_<platform>.sh`（仅正式target/group参数，若suite实现确实需要）
- `scripts/materialize_distribution.dart`（仅抽共享最小dependency closure能力）
- verification/SDK相关README、playbook和`.trellis/spec/`

直接删除：

- `.github/workflows/release-native-assets.yml`
- 旧 alias/forwarder code
- 正向保护旧YAML/command composition的tests

必须保护，不得顺手提交：

- 用户现有 `.agents/skills/**`、`skills-lock.json`
- `CONTEXT.md`删除、`CONTEXT-MAP.md`、`docs/contexts/**`
- 父任务和其他planning child的未提交改动
- 与本child无关的ADR/spec改动

## 4. Full validation gate

规划中的命令名在实现后以Catalog最终CLI为准；至少执行：

```bash
fvm dart analyze
fvm dart test
fvm dart run scripts/workspace_tools.dart verify-static --execution <local-static-execution>
fvm dart run scripts/workspace_tools.dart matrix --suite verify-static
fvm dart run scripts/workspace_tools.dart matrix --suite verify-integration
fvm dart run scripts/workspace_tools.dart matrix --suite verify-release-candidate
```

按可用host执行integration/candidate row；完整任务完成必须由Actions Android/Apple/Windows build rows和Android/iOS/macOS/Windows独立runtime proof证明：

```bash
fvm dart run scripts/workspace_tools.dart verify-integration --execution <matrix-row>
fvm dart run scripts/workspace_tools.dart verify-release-candidate \
  --execution <matrix-row> \
  --candidate-dir <fixture-or-staged-candidate> \
  --candidate-id <opaque-id> \
  --candidate-digest <sha256> \
  --sdk-ref <ref>
```

Rust与生成物底层命令仍通过Catalog执行，但收尾可额外独立确认：

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
fvm dart run ffigen --config ffigen.yaml
git diff --exit-code -- packages/nexa_http/lib/src/native_bridge/nexa_http_bindings_generated.dart
```

最后执行absence searches，确认无旧commands、旧release workflow引用、YAML target/Cargo/asset lists和compatibility code。

## 5. Review gates before `task.py start`

- [ ] 用户确认 PRD、design和implementation scope。
- [ ] 用户确认旧 release workflow本任务直接删除，直到后续transaction task前没有备用发布入口。
- [ ] execution groups避免Android/iOS按target重复build。
- [ ] candidate原地只读、digest一次、fixture最小closure且单次物化。
- [ ] no fallback / no deprecated alias / no dual-track已写入可测试验收。
- [ ] implementation不侵入Native Assets authoritative packaging或publication transaction scope。

## 6. Rollback points

- 每个TDD slice保持tests可单独说明行为，但任务只以完整clean cutover提交，不产生可合并的旧新双轨commit。
- 任何matrix completeness、build-once、candidate digest或clean-host gate失败时停止并修复，不通过skip/allow-failure降低标准。
- 唯一rollback是整体revert任务commit；不恢复旧commands或旧release workflow作为fallback。
