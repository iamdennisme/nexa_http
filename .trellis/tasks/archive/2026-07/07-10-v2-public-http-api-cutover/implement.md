# V2 public HTTP API clean cutover：执行计划

## Preconditions 与 dependency gate

- [ ] Task 保持 `planning`；用户 review `prd.md`、`design.md`、`implement.md` 并明确批准后，才运行 `task.py start`。
- [ ] Implementation 开始前加载 `trellis-before-dev`，读取 HTTP API / Native Transport context、ADR-0001/0006/0007/0008、Flutter SDK、layering、TDD 和 native-core spec。
- [ ] 使用 `fvm` 固定 Flutter 3.41.5 / Dart 3.11.x；不得使用全局 Dart 3.6.x。
- [ ] 记录 `git status --short`，保护用户已有 skill 安装改动和其他无关 worktree changes。
- [ ] 当前 Codex dispatch mode 是 inline；`implement.jsonl` / `check.jsonl` 保持 seed-only，不伪造 sub-agent manifest readiness。
- [ ] 本任务没有 upstream implementation dependency；不得提前修改下游 Verification Catalog、Native Assets 或 release transaction 的业务范围。
- [ ] 每个 slice 必须观察一个目标行为的 RED，再做 minimum GREEN 和 REFACTOR；不得先写完全部 tests 或全部 implementation。
- [ ] 每个 GREEN 同时删除对应旧 API/path/consumer；不得提交新旧 surface并存的中间态。

Preflight：

~~~bash
fvm dart --version
fvm flutter --version
python3 ./.trellis/scripts/task.py current --source
git status --short
~~~

## Ordered TDD implementation

### 1. Public contract harness 与 generated bindings clean move

- [ ] 新增最小 positive root-import control，只证明当前稳定入口（例如 `NexaHttpClient`）可以从 `package:nexa_http/nexa_http.dart` analyze；最终12-type exact allowlist留到 failure/final surface slice。
- [ ] 新增 root `lib/` file allowlist test；先观察旧 root bindings file 使测试 RED。
- [ ] 新增单项 negative fixture，证明旧 `package:nexa_http/nexa_http_bindings_generated.dart` import 当前仍可用，因此 RED。
- [ ] 把 ffigen output 直接改为 `lib/src/native_bridge/nexa_http_bindings_generated.dart`。
- [ ] 同一次 GREEN 更新 production/test imports、analysis exclude、CI regeneration path、root ABI test 和 workspace source/layout tests。
- [ ] 删除旧 root bindings file，不创建 forwarding export。
- [ ] 运行 ffigen，确认 C ABI declarations 不变且新路径生成稳定。
- [ ] REFACTOR negative fixture runner：每个 fixture只引用一个禁止项，先跑 positive control，再断言目标 fixture analyze 失败。

Focused command：

~~~bash
cd packages/nexa_http
fvm flutter test test/nexa_http_api_export_test.dart test/public_api_negative_test.dart
fvm dart run ffigen --config ffigen.yaml
~~~

### 2. Typed failure surface 与 normalization

- [ ] RED：新增 enum surface test，精确要求七值 `NexaHttpFailureKind`。
- [ ] GREEN：把 `NexaHttpException` 改为 `kind/message/uri/diagnostics`，删除旧字段，重新生成 Freezed output。
- [ ] 逐项新增 negative fixture，证明 `code/statusCode/isTimeout/details` 不再可用。
- [ ] RED/GREEN：新增 `NativeHttpErrorMapper` exhaustive matrix：
  - `canceled`、`timeout`、`network`、`invalid_request`
  - `invalid_config`、`invalid_proxy`
  - `invalid_argument`、`invalid_utf8`、`invalid_client`、serialization、unknown code
- [ ] 新增 internal `NexaHttpFailures` helper，集中稳定 message、URI 与 diagnostics 构造。
- [ ] RED/GREEN：loader factory 将 missing carrier/library/symbol 归 `unavailable`，已有 `NexaHttpException` 原样传递。
- [ ] RED/GREEN：bootstrap inner `invalid_config/invalid_proxy` 归 `configuration`；null bootstrap diagnostic归 `unavailable`；malformed envelope/schema归 `internal`。
- [ ] RED/GREEN：async error decoder、invalid final URI 和 malformed JSON/UTF-8/schema 不泄漏 `FormatException`、DTO error 或 raw callback error。
- [ ] 保持 HTTP 4xx/5xx 为 `Response`，保持 programmer/lifecycle `StateError` 不被 catch-all normalization。
- [ ] 同一个 GREEN 更新 package内全部 exception constructors/assertions、native integration timeout断言、demo error rendering和consumer fixture；不得把旧 `code/statusCode/isTimeout/details` consumer延期到最终docs slice。
- [ ] Failure slice结束前运行 package full analyze/test与demo analyze/test，证明没有破损中间态。

Focused command：

~~~bash
cd packages/nexa_http
fvm flutter test test/native_http_error_mapper_test.dart test/ffi_nexa_http_response_decoder_test.dart test/nexa_http_native_data_source_factory_test.dart test/call_api_test.dart
fvm dart run build_runner build --delete-conflicting-outputs
(fvm flutter analyze && fvm flutter test)
(cd ../../app/demo && fvm flutter analyze && fvm flutter test)
~~~

### 3. Call surface、native cancel linearization 与 Dart registry

- [ ] RED：逐个 negative fixture拒绝 `Callback`、`enqueue()`、`clone()` 和 direct client `execute(request)`。
- [ ] 删除 `callback.dart`、Callback export/import 和 `RealCall.enqueue/clone`。
- [ ] RED：pre-execute cancel 的首次 execute 期望 typed canceled，第二次 execute 期望 `StateError`。
- [ ] RED：Rust test证明 callback commit 与 cancel 使用一个线性化点：
  - cancel 先赢返回 `1` 且 callback 永不调用；
  - 成功dispatch且仍outstanding的request在callback commit先赢时，cancel 返回 `0` 且 callback 必须调用；
  - unknown/already-removed request返回 `0`，但不承诺callback。
- [ ] GREEN：Rust inflight state 增加 `CallbackCommitted` 等价状态；completion 在构造 binary FFI result前 commit，cancel 使用同一锁判断。
- [ ] 更新 C header 注释，固定 cancel return-value 语义；不改签名、symbol 或 generated binding declaration。
- [ ] RED/GREEN：Dart registry分别追踪 Future terminal 与 callback outstanding。
- [ ] native cancel返回 `1` 时完成 `kind=canceled` 并移除 entry；对成功dispatch且仍outstanding的合法request，返回 `0` 时保留 entry并等待 callback winner；unknown ID不建立callback guarantee。
- [ ] 删除 transport post-response canceled check。
- [ ] 覆盖 repeated cancel最多转发一次、response-wins、cancel-wins、cancel-after-terminal、callback-committed `cancel → dispose → non-empty callback`。
- [ ] 确认 `NativeCallable` 只在所有 callback-outstanding entry 清空后关闭，accepted cancel不留下永久 tombstone。

Focused command：

~~~bash
cargo test -p nexa_http_native_core cancel_request

cd packages/nexa_http
fvm flutter test test/call_api_test.dart test/ffi_nexa_http_pending_request_registry_test.dart test/ffi_nexa_http_native_data_source_test.dart test/nexa_http_native_transport_test.dart
~~~

### 4. RequestBody ownership 与 copy budget

- [ ] RED：`RequestBody.takeBytes` 保持输入 `Uint8List` identity。
- [ ] GREEN：factory rename 与 ownership transfer；同一次删除旧 `RequestBody.bytes`、实例 `bytes()`、`byteStream()`、`payloadBytes`。
- [ ] 加入未 root-export 的 `RequestBodyTransportAccess`；public class不增加 raw getter。
- [ ] RED/GREEN：mapper DTO 与原始 `Uint8List` 使用 `same` identity。
- [ ] RED/GREEN：text encoder返回 `Uint8List` 时 identity不变化；generic `List<int>` 只允许一次 normalization。
- [ ] 给 FFI encoder加入 internal copier seam；默认仍执行一次 `setAll`。
- [ ] RED/GREEN：非空 dispatch copier调用一次、source identity不变、allocate一次、失败 release一次、ownership transfer后 Dart不释放。
- [ ] RED/GREEN：非空 native allocation返回 null 时抛 `NexaHttpFailureKind.internal`，不按 empty body继续。
- [ ] RED/GREEN：空 body不调用allocator/copier，保持零allocation、零copy。
- [ ] 逐个更新 RequestBuilder、Request、integration 和 public export tests，不通过兼容 getter读取 payload。

Focused command：

~~~bash
cd packages/nexa_http
fvm flutter test test/request_body_test.dart test/request_builder_test.dart test/nexa_http_request_test.dart test/native_http_request_mapper_test.dart test/ffi_nexa_http_request_encoder_test.dart
~~~

### 5. ResponseBody owner、single consumption 与 release

- [ ] RED：internal transport payload必须显式持有 one-shot body owner，而不是裸 `List<int>` ownership。
- [ ] GREEN：decoder创建 internal Dart/native owner；mapper最后一步 take ownership并交给 `ResponseBodyTransportAccess`。
- [ ] Mapper/handoff中途抛错时立即 release；不得依赖 finalizer。
- [ ] 保留封闭 `final ResponseBody`，内部使用 Dart-buffered/native-adopted private storage。
- [ ] RED/GREEN：public buffered factory snapshot一次，首次 `bytes()` 直接转移 owned `Uint8List`，不做第二次 copy。
- [ ] RED/GREEN：non-empty native `bytes()` 恰好一次 copy并 release一次。
- [ ] RED/GREEN：`string()` 收到原 native view、无 full-body pre-copy，并在 success/decode failure 的 `finally` release一次。
- [ ] RED/GREEN：`close()` 零 copy、幂等；第二次 `bytes()/string()` 为 `StateError`；consume后 close不重复 release。
- [ ] RED/GREEN：零长度 native result在 decoder阶段释放，public body返回 Dart-owned empty `Uint8List`。
- [ ] 删除 Response fake `byteStream()`、旧 `adoptResponseBodyBytes` 和 duplicate forwarding file。
- [ ] 更新 client/mapper/integration tests，禁止对同一 body先 bytes再 string。

Focused command：

~~~bash
cd packages/nexa_http
fvm flutter test test/response_body_test.dart test/ffi_nexa_http_response_decoder_test.dart test/ffi_nexa_http_native_data_source_test.dart test/nexa_http_response_mapper_test.dart test/nexa_http_client_test.dart
~~~

### 6. Final root allowlist、demo、docs 与 integration fixture

- [ ] 把 `api.dart` 和 `nexa_http.dart` 收敛为最终显式 `show` allowlist。
- [ ] Public contract test精确验证12个批准 types和唯一 root library。
- [ ] 更新 package README、root README/中文 README中受影响用法和所有剩余 consumer fixture；exception consumer已在failure slice原子切换。
- [ ] 重写 `packages/nexa_http/CHANGELOG.md` 的 `2.0.0` 条目，明确 breaking API removal、typed failure和body ownership；不创建第二份 package release-note source。
- [ ] 真实 native integration suite标记为 macOS/native-integration，增加 client/body deterministic cleanup；普通 package suite在不支持平台不会把 skip当成真实 native通过。
- [ ] 更新 ABI/workspace tests的 bindings path和final API fixture。
- [ ] Production/demo legacy absence scan归零；negative fixtures和ADR/spec中保留的历史名称不计为残留。

Focused command：

~~~bash
cd packages/nexa_http
fvm flutter test test/nexa_http_api_export_test.dart test/public_api_negative_test.dart test/nexa_http_native_integration_test.dart

cd ../../app/demo
fvm flutter analyze
fvm flutter test
~~~

### 7. Full validation 与 downstream handoff

- [ ] 重新运行 ffigen和build_runner；比较生成前后 hash，证明 checked-in generated files稳定。
- [ ] 运行 package analyze、deterministic full test和macOS native integration。
- [ ] 因 Rust cancellation semantics改变，运行 core/workspace Rust format/test；本地macOS重建 artifact后再跑 native integration和clean consumer。
- [ ] 运行 root analyze、ABI/path/workspace tests、workspace analyze/test、development path和external consumer。
- [ ] 运行 scoped legacy absence checks、`git diff --check` 和 task validator。
- [ ] 复核 PRD acceptance、记录实际 RED/GREEN evidence，并把 final API/bindings path/fixture handoff给下游任务。
- [ ] 不自动 start下游 child。

## Validation commands

### Generated source freshness

~~~bash
cd packages/nexa_http

before_bindings="$(shasum -a 256 lib/src/native_bridge/nexa_http_bindings_generated.dart)"
before_exception="$(shasum -a 256 lib/src/api/nexa_http_exception.freezed.dart)"

fvm dart run ffigen --config ffigen.yaml
fvm dart run build_runner build --delete-conflicting-outputs

after_bindings="$(shasum -a 256 lib/src/native_bridge/nexa_http_bindings_generated.dart)"
after_exception="$(shasum -a 256 lib/src/api/nexa_http_exception.freezed.dart)"

test "$before_bindings" = "$after_bindings"
test "$before_exception" = "$after_exception"
~~~

CI clean checkout继续使用更新后的 internal path执行 regeneration + `git diff --ignore-all-space --exit-code`。

### Dart package gate

~~~bash
cd packages/nexa_http
fvm flutter analyze
fvm flutter test
~~~

### Rust cancellation/core gate

~~~bash
cargo fmt --all --check
cargo test -p nexa_http_native_core
cargo test --workspace
~~~

### macOS native integration 与 host clean consumer

~~~bash
./scripts/build_native_macos.sh debug
(cd packages/nexa_http && fvm flutter test test/nexa_http_native_integration_test.dart)
fvm dart run scripts/workspace_tools.dart verify-development-path
fvm dart run scripts/workspace_tools.dart verify-external-consumer
~~~

`verify-development-path` 和 `verify-external-consumer` 只证明当前 host，不代表四平台 candidate gate。

### Root/workspace gate

~~~bash
fvm dart analyze
fvm dart test test/native_ffi_abi_contract_test.dart test/workspace_demo_and_consumer_verification_test.dart test/workspace_tools_test.dart test/workspace_package_layout_test.dart

fvm dart run scripts/workspace_tools.dart analyze
fvm dart run scripts/workspace_tools.dart test
~~~

当前不存在 `verify-static`、`verify-integration`、`verify-release-candidate`；它们由下一个 Verification Catalog child实现。本任务也不运行需要真实已发布 tag/ref的 `verify-release-consumer`。

### Legacy absence

~~~bash
test ! -e packages/nexa_http/lib/src/api/callback.dart
test ! -e packages/nexa_http/lib/nexa_http_bindings_generated.dart
test ! -e packages/nexa_http/lib/src/internal/transport/native_response_body_bytes.dart
test -z "$(find packages/nexa_http/lib -maxdepth 1 -type f ! -name nexa_http.dart -print)"

! rg -n "package:nexa_http/nexa_http_bindings_generated\\.dart|lib/nexa_http_bindings_generated\\.dart" packages/nexa_http/lib packages/nexa_http/ffigen.yaml packages/nexa_http/analysis_options.yaml .github/workflows/ci.yml

! rg -n "RequestBody\\.bytes\\(|\\.byteStream\\(|\\bpayloadBytes\\b|\\badoptResponseBodyBytes\\b" packages/nexa_http/lib app/demo/lib

! rg -n "\\bCallback\\b|\\benqueue\\(|\\bclone\\(" packages/nexa_http/lib app/demo/lib
~~~

### Planning/finish hygiene

~~~bash
git diff --check
python3 ./.trellis/scripts/task.py validate .trellis/tasks/07-10-v2-public-http-api-cutover

! rg -n '^TBD\\.?$|^- TBD$|\\[ \\] TBD' .trellis/tasks/07-10-v2-public-http-api-cutover
~~~

## Review gates

1. **Surface gate**：root file/type allowlist精确；所有旧 public execution/body/error symbol不可通过root import。
2. **Bindings gate**：generated file只有internal path；ffigen、imports、analysis、CI、ABI tests一次切换。
3. **Cancellation gate**：Rust cancel/callback线性化、Dart terminal winner和callback handle lifetime都有确定性race tests。
4. **Copy/ownership gate**：Request dispatch一次copy；Response mapping零中间copy，bytes一次copy，string/close零copy，release exactly once。
5. **Failure gate**：七值穷举，unknown/malformed/loader/bootstrap/dispatch归一化，HTTP status和StateError不被误分类。
6. **Consumer/absence gate**：README/demo/CHANGELOG/fixture只使用final v2 surface；host clean consumer通过；无compatibility中间态。

## Risky files 与 rollback points

| 范围 | 风险 | Rollback |
|---|---|---|
| `native/.../runtime/executor.rs` | cancel与callback线性化错误会造成丢callback或use-after-close | revert整个 cancellation slice；不得在Dart加timer/fallback |
| `real_call.dart`、transport、pending registry/data source | terminal winner、重复完成、dispose时机 | revert整个 Call slice并保留RED tests，修正后重新clean cutover |
| RequestBody/mapper/encoder | mutable backing泄漏或重复copy | revert整个 RequestBody slice；不恢复deprecated getter |
| ResponseBody/decoder/transport owner/mapper | body leak、double free、释放后view逃逸 | revert整个 ResponseBody slice；不恢复长期native view API |
| exception/freezed/mappers/loader | public taxonomy漂移或raw error泄漏 | revert整个 failure slice；不恢复string code |
| ffigen/analysis/CI/ABI tests | generated path部分迁移 | revert整个 bindings slice；禁止root forwarding library |
| README/demo/CHANGELOG/fixtures | 文档与真实surface不一致 | 与owning code slice一起修正，不保留旧示例 |

## Completion 与 downstream handoff

完成前必须：

- [x] PRD全部 acceptance criteria 有对应 test/command evidence。
- [x] 实际 RED/GREEN顺序追加到本文件或 task notes，而不是用最终全绿替代TDD证据。
- [x] `packages/nexa_http/CHANGELOG.md` 与final API一致。
- [x] 下游收到唯一 root API、internal bindings path、consumer fixture和failure/body semantics。
- [x] 当前 child归档前不start下游任务；任何未通过gate保持本任务 `in_progress`。

## 实际 TDD 与验证证据（2026-07-10）

### RED → GREEN

- Call surface：删除 `clone()` 后旧测试编译失败；改为 `client.newCall(request)` 后 focused suite 通过。
- Pre-execute cancellation：首次 execute 实际抛 `StateError`；切换为 typed `canceled` 且占用 one-shot 后通过。
- Native linearization：callback 已进入时 `cancel_request` 实际返回 `1`；加入 `CallbackCommitted` 同锁提交后返回 `0` 且 callback 保证交付。
- Dart acknowledgment：native cancel 返回 `0` 时 Future 实际提前完成 canceled；改为保留 pending 等 callback 后 response-wins 通过。
- Transport terminal winner：callback response 到达后 post-response canceled check 实际覆盖 response；删除该 check 后通过。
- Request body：`takeBytes`/transport access 缺失导致编译 RED；clean cutover 后 identity 通过。Null allocator 未报错、copier失败未释放分别先 RED，归一化/释放后通过。
- Response body：buffered `bytes()` 返回非 `Uint8List` 且可重复消费；one-shot storage 后通过。Mapper 抛错时 owner 未释放先 RED，增加 handoff `finally` 后通过。
- Response decoder：空 body 先 free 再读 `status_code` 导致状态码变为 `0`；先 snapshot 标量后通过。
- Codegen：`build_runner` 扫描 `test/` 导致 fixture package/analyzer cycle 失败；新增 `build.yaml` 限定 `lib/**.dart` 后 freshness gate通过。

### Final gates

- `packages/nexa_http`：`fvm flutter analyze` 通过；`fvm flutter test` 102 tests通过。
- Demo：analyze通过；11 tests通过。
- Generated freshness：ffigen/build_runner二次执行0 output，bindings/Freezed hash不变。
- Rust：`cargo fmt --all --check`、core tests、`cargo test --workspace` 通过。
- Native integration：重建macOS debug artifact后，8 tests通过并确定性关闭 client/body。
- Root/workspace：root analyze、23个ABI/workspace contract tests、workspace analyze/test通过。
- Host consumer：`verify-development-path`、`verify-external-consumer`、`verify-artifact-consistency`通过。
- Hygiene：legacy absence、`git diff --check`、task validator通过；未启动任何下游 child。
