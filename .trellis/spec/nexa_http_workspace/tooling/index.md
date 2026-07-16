# nexa_http_workspace 工具规范

> 根 workspace 拥有跨 package 的验证目录、release transaction、仓库级契约测试和文档治理；它不拥有任一 package 的 runtime 行为。

## Scope

- `scripts/workspace_tools.dart` 与 `scripts/verification/`
- `scripts/release_transaction.dart` 与 `scripts/release/`
- 根 `test/`、GitHub Actions、workspace package inventory
- 根 README、架构索引和 verification 文档的导航关系

## 规范索引

| 规范 | 说明 |
| --- | --- |
| [验证与发布](./verification-and-release.md) | Verification Catalog、完整 suites、candidate proof 和 release transaction |

## Pre-Development Checklist

- [ ] 修改验证或 release tooling 前阅读 [验证与发布](./verification-and-release.md) 和共享 [验证命令与 CI 所有权契约](../../guides/verification-command-contract.md)。
- [ ] 修改 package、carrier、artifact 或 clean-host gate 前阅读 [项目分层契约](../../guides/project-layering-contract.md) 和 [Flutter SDK 编写契约](../../guides/flutter-sdk-authoring-contract.md)。
- [ ] 新增仓库级 contract test 前确认它验证稳定 CLI 或文件契约，不复制 production parser。
- [ ] 修改配置、路径或命令前先搜索全部生产者、消费者和历史元数据引用。

## Quality Check

- [ ] 根 Dart contract tests 通过。
- [ ] `verify-static --execution static-linux` 通过真实 Verification Catalog runner。
- [ ] package inventory、target matrix、suite membership 和文档 authority 各只有一个事实来源。
- [ ] workspace tooling 没有接管 package-local runtime、FFI 或 carrier 行为。
