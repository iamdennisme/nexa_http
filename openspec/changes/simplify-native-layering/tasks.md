## 1. 收敛模块边界

- [x] 1.1 将 `nexa_http_runtime` 与 `nexa_http_distribution` 的保留逻辑收敛到单一内部 native layer
- [x] 1.2 删除 `nexa_http_runtime` 与 `nexa_http_distribution` 作为独立对外 package surface 的入口、文档与边界测试
- [x] 1.3 更新 `packages/nexa_http` 依赖结构，使其直接集成合并后的内部 native layer

## 2. 清理版本与发布语义

- [x] 2.1 删除 native artifact resolver、manifest 与相关代码中的 version / release / tag / release identity / consumer 逻辑
- [x] 2.2 删除 `scripts/workspace_tools.dart` 中的 package version 对齐、release-train、tag 校验与 consumer 验证逻辑
- [x] 2.3 删除或重写依赖上述发布语义的仓库文档与说明

## 3. 去除兼容与历史路径

- [x] 3.1 删除 target matrix 中的 legacy path、fallback path 与历史兼容字段
- [x] 3.2 删除 runtime loader 中的 candidate probing、workspace 搜索、环境驱动搜索与历史路径回退逻辑
- [x] 3.3 将 native 加载与 artifact 定位改为固定支持目标与显式路径规则，缺失即直接失败

## 4. 收缩 platform / carrier 职责

- [x] 4.1 将各平台 carrier 收缩为仅负责平台产物生成与最小宿主集成
- [x] 4.2 删除 carrier 中残留的 runtime/distribution 策略、版本语义与兼容逻辑
- [x] 4.3 去除 `default_package` 式隐式平台选择，改为符合新规范的显式产物选择模型

## 5. 对齐验证与文档

- [x] 5.1 重写仓库验证，使其只校验 `nexa_http` 唯一 public surface、合并后的 native layer、固定支持目标与 artifact-only carrier 边界
- [x] 5.2 更新 `nexa_http` 与仓库级文档，明确新的 public surface、内部边界与平台产物选择方式
- [x] 5.3 运行并修正相关测试/验证，确保旧的 release/version/compatibility 假设已被清除
