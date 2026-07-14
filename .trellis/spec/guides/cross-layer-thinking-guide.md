# 跨层思考指南

> 目的：实现前先梳理数据、职责和错误如何跨层流动。

## 问题

多数 bug 出现在层边界，而不是单层内部。常见问题：

- API 返回格式 A，消费者期待格式 B
- 数据存储为 X，service 转换成 Y 时丢字段
- 多个层各自实现同一套逻辑
- build hook、native artifact、平台包和宿主 App 对同一职责理解不同

## 实现跨层功能前

### 1. 画出数据流

```text
Source -> Transform -> Store -> Retrieve -> Transform -> Display
```

每条边都要回答：

- 当前数据格式是什么？
- 哪些地方可能失败？
- 谁负责校验？
- 谁负责错误语义转换？

### 2. 找出边界

| 边界 | 常见问题 |
|------|----------|
| API ↔ Service | 类型不匹配、字段缺失 |
| Service ↔ Database | 格式转换、null 处理 |
| Backend ↔ Frontend | 序列化、时间格式 |
| Component ↔ Component | props shape 漂移 |
| Dart SDK ↔ native runtime | ABI、artifact、错误映射 |
| SDK package ↔ host app | 集成职责泄漏 |

### 3. 定义 contract

每个边界都要写清楚：

- 输入格式
- 输出格式
- 可能错误
- 所有权归属
- 验证方式

## 常见错误

### 隐式格式假设

不要假设日期、payload、manifest 或 artifact 命名格式。边界处必须显式转换或校验。

### 分散校验

同一件事不要在多个层重复校验。优先在入口边界校验一次，再传递强类型或规范化后的值。

### 抽象泄漏

上层不应该理解下层内部结构。例如宿主 App 不应该理解 SDK 的 carrier package runtime API 或 artifact resolver。

### 每个消费者都解析同一 payload

坏例子：

```typescript
const thread = (ev as { thread?: string }).thread;
const labels = (ev as { labels?: string[] }).labels;
```

这表示每个消费者都私自拥有 event contract。

好例子：

```typescript
if (!isThreadEvent(ev)) return false;
return ev.thread === filter.thread;
```

规则：append-only log、JSON stream、RPC payload 或 config file 必须有一个所有者负责：

- event/payload type definition
- 从 `unknown` 到强类型的 type guard 和 normalization
- UI/command 使用的 metadata projection
- 从事实来源 replay 状态的 reducer

展示代码可以格式化字段，但不得重新定义 payload contract。

## 跨层功能检查清单

实现前：

- [ ] 已画出完整数据流。
- [ ] 已列出所有层边界。
- [ ] 每个边界的输入/输出格式已定义。
- [ ] 已决定校验发生在哪一层。
- [ ] 已决定错误由哪一层转换、哪一层暴露给用户。

实现后：

- [ ] 覆盖 null、empty、invalid 等边界案例。
- [ ] 验证每个边界的错误处理。
- [ ] 验证数据 round-trip 后不丢字段。
- [ ] 消费者 import 共享 decoder/projection，而不是本地 cast payload 字段。
- [ ] 派生状态能追溯到事实来源标识，例如 `seq`、`id`、`version`。

## 跨平台模板一致性

Trellis 的 command template 可能存在于多个平台目录。修改任一模板时必须：

- [ ] 找到所有平台副本：

```bash
find src/templates/*/commands/trellis/ -name "<command>.*"
```

- [ ] 同步 Markdown `.md` 和 TOML `.toml`。
- [ ] Gemini TOML 需要适配 line continuation 和 triple-quoted string。
- [ ] 运行对应 cross-layer 检查，确认没有漏改。

## 设备与宿主网络边界

移动设备、模拟器与宿主进程不共享同一个 loopback 命名空间。设计 clean-host runtime、fixture server 或端到端测试时必须显式回答：

- 宿主服务监听哪个地址和端口？
- App 内使用哪个 URL？
- 设备到宿主的通道由谁在何时建立？
- URL、端口和通道命令是否来自同一个 typed input？

Android verification 固定让宿主 fixture 监听 `127.0.0.1`，App 也使用 `127.0.0.1`，并在 Activity 启动前按 fixture URL 端口建立一次 `adb reverse tcp:<port> tcp:<port>`。不得依赖 emulator 特殊宿主地址、在多个 workflow 复制不同 URL，或失败后切换另一条网络路径。

检查：

- [ ] 设备侧 URL 与宿主监听地址是否通过显式 tunnel 对齐。
- [ ] tunnel 是否在 App 启动前建立，并在测试中锁定命令顺序。
- [ ] workflow、fixture build define 和 runtime runner 是否消费同一个 URL/端口。
- [ ] 是否删除了旧地址、fallback 和双轨网络路径。

## Runtime-parsed 模板升级一致性

有些生成文件既是文档，也是 runtime input。`.trellis/workflow.md` 会被 `get_context.py`、`workflow_phase.py`、SessionStart 过滤器和 per-turn hook 解析。

修改这类模板时必须：

- [ ] 找出所有 runtime parser，不只看写文件的代码。
- [ ] 检查语法是否位于 managed region 之外，例如 tag block 外。
- [ ] 验证 fresh init 输出。
- [ ] 验证旧版本 update 场景。
- [ ] 用旧 pristine template fixture 加 upgrade regression。
- [ ] 更新拥有 runtime contract 的 backend spec。

## Versioned docs 边界

版本化文档是一条跨层边界：source path、`docs.json` 路由和渲染出的版本选择器必须描述同一个 release line。

编辑前必须：

- [ ] 明确目标 release line：stable、beta 或 RC。
- [ ] 验证 MDX 路径匹配该 release line。
- [ ] 验证 `docs.json` navigation 指向同一版本路径。
- [ ] 提交前 grep 另一棵文档树，避免版本术语串线。
- [ ] 把 beta 内容出现在 root release path 视为 source-path bug。

## Mode-detection probe 检查

CLI 通过远程资源探测模式时，例如检查 `index.json` 是否存在来决定 marketplace 或 direct download，必须：

实现前：

- [ ] 所有使用结果的路径都执行 probe。
- [ ] 区分 404 和 transient error。
- [ ] transient error 必须 abort 或 retry，不得静默切换模式。
- [ ] 上下文变化时重置 shared cache/prefetch。
- [ ] shortcut path 必须和 probe path 有同等错误质量。

实现后：

- [ ] 从 probe result 到 mode decision 的每条路径都能追踪。
- [ ] 外部格式 contract 有测试或注释。
- [ ] metadata read 必须读完整响应或使用 streaming parser。
- [ ] 重建复合 identifier 时确认所有字段位置正确。
- [ ] shortcut 后调用的 action function 不得内部回到低质量 catch-all fetch。

## 新增 event kind 或字段

- [ ] 找到事件事实来源。
- [ ] 更新 type definition、decoder、projection 和 reducer。
- [ ] 更新所有消费者，不让消费者本地 cast 新字段。
- [ ] 增加 replay 或 round-trip 测试。
- [ ] 检查文档、示例和迁移说明是否同步。
