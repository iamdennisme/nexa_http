# TDD 开发准则

> 目的：让所有有行为变化的开发默认通过测试驱动完成，避免先写实现再补测试导致测试只验证实现形状。

## 核心规则

所有新增功能、bug 修复、重构和跨层行为变更都必须默认按 TDD 执行。

标准循环：

```text
RED:   先写一个描述目标行为的测试，并确认它失败
GREEN: 写刚好让这个测试通过的最小实现
REFACTOR: 在所有测试通过后整理结构，再跑测试
```

每次只推进一个垂直切片：一个行为测试，一个最小实现。不得一次性写完所有测试，再一次性写完所有实现。

## 适用范围

必须使用 TDD：

- 新增 public API、命令、build hook、runtime 行为或 release workflow 行为。
- 修 bug，必须先写能复现问题的回归测试。
- 修改 FFI ABI、artifact materialization、platform carrier、clean-host consumer 或跨层 contract。
- 重构已有逻辑且可能改变外部可观察行为。
- 增加错误处理、校验、fallback、timeout、cache 或 platform-specific 分支。

可以不走完整 RED/GREEN 的例外：

- 纯文档、纯注释或 spec 更新。
- 纯格式化、import 排序或机械重命名，且无行为变化。
- 生成文件同步，前提是生成源头已经被测试覆盖。
- 探索性只读分析、架构 review 或报告生成。

使用例外时，最终总结必须说明为什么没有新增或先写测试。

## 测试形状

测试必须优先验证行为，而不是实现细节。

规则：

- 通过 public interface 或稳定 module interface 测试。
- 测试名描述“发生了什么行为”，不要描述“调用了哪个内部函数”。
- 期望值必须来自独立事实，例如明确 literal、协议文档、fixture 或已确认示例。
- 不要用和实现相同的算法计算 expected value。
- 不要 mock 自己控制的内部 module。
- 只在系统边界 mock：网络、时间、随机数、文件系统、外部命令、外部平台能力。
- 复杂跨层逻辑优先写 integration-style test；单元测试用于补充边界条件和纯函数。

## 开发流程

实现前：

- [ ] 读 `CONTEXT.md` 和相关 ADR，测试命名使用项目领域词汇。
- [ ] 读当前任务的 `prd.md`、`design.md`、`implement.md`。
- [ ] 找到最小 public 或稳定 module interface。
- [ ] 列出第一个要证明的行为，不列实现步骤。

每个 TDD 循环：

- [ ] 写一个失败测试。
- [ ] 确认失败原因是目标行为缺失，不是测试环境错误。
- [ ] 写最小实现让测试通过。
- [ ] 跑该测试，必要时跑相邻测试。
- [ ] 绿色后再重构。
- [ ] 重构后重跑测试。

收尾前：

- [ ] 跑受影响 package 的质量检查。
- [ ] 如果发现新的 contract、坑点或约定，写回 `.trellis/spec/`。
- [ ] 总结哪些测试先失败、哪些测试最终通过。

## 反模式

不要水平切片：

```text
错误：先写 test1/test2/test3，再写 impl1/impl2/impl3
正确：test1 -> impl1 -> test2 -> impl2 -> test3 -> impl3
```

不要测试实现细节：

```text
错误：断言内部 helper 被调用 1 次
正确：断言 public interface 返回目标行为
```

不要写同义反复测试：

```text
错误：expected = inputs.map(...).reduce(...)，算法和实现相同
正确：expected = 明确 literal 或独立 fixture
```

不要为了测试方便降低真实 contract：

- 不要把 production error path 改成测试专用返回值。
- 不要暴露 private implementation 只为测试它。
- 不要用 mock 代替项目内部真实 module，除非它是外部系统边界。

## 检查清单

- [ ] 本次行为变化是否先有 RED 测试。
- [ ] 测试是否走 public/stable interface。
- [ ] 测试是否能在内部重构后继续成立。
- [ ] expected value 是否独立于实现算法。
- [ ] mock 是否只用于系统边界。
- [ ] 是否避免一次性写完所有测试或所有实现。
- [ ] 是否在 GREEN 后才重构。
- [ ] 最终总结是否报告测试和任何未测试风险。
