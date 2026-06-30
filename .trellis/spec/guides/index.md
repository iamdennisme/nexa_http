# 思考与规则指南

> **目的**：在编码前暴露容易漏掉的问题，并保存项目级规则。

---

## 可用指南

| 指南 | 目的 | 何时使用 |
|------|------|----------|
| [文档语言规范](./documentation-language-policy.md) | 规定 `.trellis/spec/` 规则文档必须使用中文 | 新增或修改任何 spec 规则文档时 |
| [代码复用思考指南](./code-reuse-thinking-guide.md) | 识别重复模式，避免同一逻辑散落多处 | 新增工具函数、常量、解析逻辑或看到相似代码时 |
| [跨层思考指南](./cross-layer-thinking-guide.md) | 梳理跨 API、数据、构建、平台边界的数据流和职责 | 变更触达多个层或多个消费者时 |
| [Flutter SDK 编写契约](./flutter-sdk-authoring-contract.md) | 保证 SDK 只能通过公开 Dart API 和标准 Flutter 构建链路集成 | 修改 Dart SDK surface、carrier 包、native artifact 或发布验收时 |

---

## 快速触发条件

### 修改规则文档时

- [ ] 你正在新增或修改 `.trellis/spec/**/*.md`
- [ ] 你发现模板里仍有英文规则说明
- [ ] 你需要新增项目约定、质量标准、检查清单或反模式

→ 阅读 [文档语言规范](./documentation-language-policy.md)

### 思考跨层问题时

- [ ] 功能触达 3 层以上，例如 API、Service、Component、Database、build hook、native artifact
- [ ] 数据格式会在多个层之间转换
- [ ] 多个消费者依赖同一份数据或事件
- [ ] 不确定逻辑应该放在哪一层
- [ ] 正在新增 event kind、JSONL 记录、RPC payload 或 config field
- [ ] UI 或命令代码开始直接 cast 原始 payload 字段

→ 阅读 [跨层思考指南](./cross-layer-thinking-guide.md)

### 思考代码复用时

- [ ] 正在写和现有代码相似的逻辑
- [ ] 同一模式重复出现 3 次以上
- [ ] 正在给多个地方新增同一个字段
- [ ] 正在修改任何常量或配置
- [ ] 正在创建新的 utility/helper function
- [ ] 两个文件都在读取同一个未类型化 payload 字段
- [ ] 多个分支基于 `kind`、`action` 或 `status` 更新同一类派生状态

→ 阅读 [代码复用思考指南](./code-reuse-thinking-guide.md)

### 应用 Flutter SDK 编写契约时

- [ ] 修改 `packages/nexa_http` 公开 API、README 示例或宿主可见文档
- [ ] 修改 platform carrier package 或 `nexa_http_native_internal`
- [ ] 修改 native assets、release artifacts、checksums、manifests、hooks、CocoaPods、Gradle、CMake 或 plugin registration
- [ ] 新增 mirror、offline artifact、debug path 或 enterprise distribution 配置
- [ ] 修改 clean-host、external-consumer 或 release-consumer 验证
- [ ] 某个修复方案要求宿主 App 改 native 工程、复制文件、手动注册插件或运行 SDK 专用脚本

→ 阅读 [Flutter SDK 编写契约](./flutter-sdk-authoring-contract.md)

---

## AI Review 结果校验

- [ ] Reviewer 说“用户输入可能恶意”时，先确认实际数据源是内部 manifest、用户配置还是外部 API。
- [ ] Reviewer 说“缺少校验”时，确认数据是否来自可信内部来源。
- [ ] Reviewer 说“行为变化”时，先读代码注释，确认是否是有意设计。
- [ ] Reviewer 说“测试有 bug”时，先判断删掉被测功能后测试是否仍会通过；如果会，通过的是 tautological test。

常见误报模式：

1. **信任边界混淆**：把内部 bundled manifest 当成不可信外部输入。
2. **忽略设计注释**：把代码注释里说明的有意行为当成 bug。
3. **变量误读**：没有追到变量真实定义，例如把按 path keyed 的 Map 当成按 name keyed。

规则：所有 CRITICAL/WARNING 发现必须先对照真实代码验证，再决定优先级。AI review 误报率按 35% 预算处理。

---

## 修改前搜索规则

> 修改任何值之前，必须先搜索。

```bash
rg "value_to_change" .
```

这条规则用于避免只改一个入口、漏掉其他消费者。

---

## 使用方式

1. 编码前读相关指南。
2. 发现重复、跨层或 SDK 集成边界变化时，回到对应指南检查。
3. 修 bug 后，如果学到新约定或坑点，把它写回这里。
