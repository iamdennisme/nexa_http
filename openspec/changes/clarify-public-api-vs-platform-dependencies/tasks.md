## 1. 修正公开契约术语
- [ ] 1.1 将所有 “only public surface” 文案拆分为 “only public API surface” 与 “public dependency artifacts”
- [ ] 1.2 删除或改写将 `nexa_http` 描述为唯一 public package/dependency surface 的表述
- [ ] 1.3 明确 `nexa_http_native_runtime_internal` 与 native core 为非公开实现细节

## 2. 修正 consumer dependency boundary
- [ ] 2.1 更新 `git-consumer-dependency-boundary` spec，要求消费者声明 `nexa_http`
- [ ] 2.2 更新该 spec，要求消费者按目标平台显式声明 `nexa_http_native_<platform>`
- [ ] 2.3 更新该 spec，禁止消费者依赖 `nexa_http_native_runtime_internal`

## 3. 修正验证模型
- [ ] 3.1 更新 `platform-runtime-verification`，校验平台选择属于公开依赖契约的一部分
- [ ] 3.2 更新 `ci-enforced-consumer-verification`，从 `nexa_http`-only 假设改为 `nexa_http` + 平台包模型
- [ ] 3.3 增加 example/consumer 场景验证，确保 internal 不是公开依赖面

## 4. 修正文档与示例指导
- [ ] 4.1 更新架构文档，明确 API surface 与 dependency artifacts 的区别
- [ ] 4.2 更新安装说明，要求消费者声明所需平台包
- [ ] 4.3 更新 example guidance，要求 example 只依赖公开依赖面

## 5. 收敛仓库包边界表达
- [ ] 5.1 识别当前 package metadata 与目标公开契约的不一致之处
- [ ] 5.2 为后续实现 change 记录这些不一致作为 follow-up work
