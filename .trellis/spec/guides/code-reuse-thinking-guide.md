# 代码复用思考指南

> 目的：新增代码前先判断项目里是否已有可复用逻辑，避免重复实现造成长期漂移。

## 问题

重复代码是最常见的一致性 bug 来源。复制或重写已有逻辑会导致：

- bug fix 只修到一处
- 行为随时间分叉
- 后续维护者难以判断哪份实现才是准绳

## 写新代码前

### 1. 先搜索

```bash
rg "functionName" .
rg "keyword" .
```

### 2. 问这些问题

| 问题 | 如果答案是 yes |
|------|----------------|
| 是否已有相似函数？ | 复用或扩展它 |
| 是否已有相同模式？ | 跟随现有模式 |
| 是否应该成为共享 utility？ | 放到正确的共享位置 |
| 是否正在从别的文件复制代码？ | 停下来，抽出共享实现 |

## 常见重复模式

### Copy-paste 函数

不要把校验函数复制到另一个文件。应抽到共享 utility，再由调用方 import。

### 相似组件或模块

如果新组件或新模块和已有实现 80% 相似，先考虑扩展已有实现，而不是复制后微调。

### 重复常量

同一个常量不得在多个地方重新定义。应建立单一来源，然后统一 import。

### 重复 payload 字段解析

坏例子：

```typescript
const description = (ev as { description?: string }).description;
const context = (ev as { context?: ContextEntry[] }).context;
```

这类代码看起来只有两行，但每个消费者都在私自定义 payload contract。

好例子：

```typescript
if (isThreadEvent(ev)) {
  renderThreadEvent(ev);
}
```

规则：同一个未类型化 payload 字段被 2 个以上消费者读取时，新增第三个消费者之前必须创建共享 type guard、normalizer 或 projection。

## 何时抽象

应该抽象：

- 同样逻辑出现 3 次以上
- 逻辑复杂到容易出 bug
- 多个人或多个模块会依赖它

不应该抽象：

- 只用一次
- 只是微不足道的一行
- 抽象本身比重复更复杂

## 批量修改后

1. Review：是否覆盖了所有实例？
2. Search：用 `rg` 找遗漏。
3. Consider：是否应该抽成共享实现？

## Reducer 结构

当状态由 `action`、`kind`、`status`、`phase` 等值派生时，优先使用一个 reducer 和一个 `switch` 管理状态转移，避免散落的 `if/else`。

坏例子：

```typescript
if (action === "opened") { ... }
else if (action === "comment") { ... }
else if (action === "status") { ... }
```

好例子：

```typescript
switch (event.action) {
  case "opened":
    ...
    return;
  case "comment":
    ...
    return;
}
```

事件日志是事实来源时，reducer 就是 replay model。展示代码和命令代码不得各自复制 replay 逻辑。

## Python exhaustive check 坑点

Python 的 `if/elif/else` 没有编译期 exhaustive check。给 `Literal` 类型新增值时，旧分支可能静默落到 `else`，返回错误默认值。

坏例子：

```python
@property
def cli_name(self) -> str:
    if self.platform == "opencode":
        return "opencode"
    else:
        return "claude"
```

新增 `gemini` 后会错误返回 `claude`。

规则：新增 `Literal` 值时，搜索所有基于该类型的 `if/elif/else`，为新值补显式分支，不要假设 `else` 适合新值。

## 机制不对称坑点

两个不同机制产出同一批文件时，例如 init 使用递归复制、update 使用手写 `files.set()`，结构变更很容易只覆盖其中一条路径。

优先做法：

- 消除不对称，让手写路径调用自动收集逻辑。
- 如果不能消除，增加回归测试比较两条路径的输出。
- 迁移目录结构时，搜索所有引用旧结构的路径。

## Trellis 模板注册规则

新增 `src/templates/trellis/scripts/` 下的文件时，单一注册点是 `src/templates/trellis/index.ts`：

1. 添加 `export const xxxScript = readTemplate("scripts/path/file.py");`
2. 加入 `getAllScripts()` Map

`.trellis/scripts/` 和 `packages/cli/src/templates/trellis/scripts/` 必须保持一致。编辑 `.trellis/scripts/` 后同步：

```bash
rsync -av --delete --exclude='__pycache__' .trellis/scripts/ packages/cli/src/templates/trellis/scripts/
```

执行 `rsync` 前必须确认 source/destination，避免生成嵌套垃圾目录。

## Commit 前检查

- [ ] 已搜索相似代码。
- [ ] 没有应共享却复制的逻辑。
- [ ] 未类型化 payload 字段读取集中在共享 decoder/type guard/projection。
- [ ] 常量只有一个来源。
- [ ] 相似模式结构一致。
- [ ] reducer/action 转移集中在一个 reducer 或 command dispatcher。
