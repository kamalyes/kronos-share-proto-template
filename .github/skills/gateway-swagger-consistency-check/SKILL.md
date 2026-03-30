---
name: gateway-swagger-consistency-check
description: "核对 gateway 与 swagger 一致性，覆盖 proto http/openapiv2 注解、swagger paths、aggregate.services/documents、swagger_embed.go 映射用于发布前检查、文档异常排查、路径白名单治理"
argument-hint: "请输入检查范围（全量/某服务）与输出模式（仅问题/问题+修复建议）"
user-invocable: true
---

# Gateway Swagger Consistency Check

## 技能目标

发现并定位“看起来配置了但实际不可用”的一致性问题：

1. proto 注解与 swagger 产物不一致
2. gateway 服务聚合与 swagger 文件不一致
3. documents 白名单路径与真实 paths 不一致
4. swagger_embed 注册与实际文件不一致

## 何时使用

- "为什么 swagger 页面没有这个服务"
- "为什么 documents 里接口丢了"
- "新增模块后 gateway 文档不生效"
- "发布前做 gateway/swagger 一致性检查"

## 默认证据文件

- [resources/gateway-dev.yaml](../../../resources/gateway-dev.yaml)
- [swagger_embed.go](../../../swagger_embed.go)
- [proto](../../../proto)
- [pb](../../../pb)

## 检查矩阵

1. Proto 层：
   - rpc 是否有 `google.api.http`
   - rpc 是否有 `openapiv2_operation`
2. Swagger 层：
   - `proto/<module>/*.swagger.yaml` 是否存在
   - `paths` 是否包含预期路由
3. Gateway services 层：
   - `aggregate.services[].spec-path` 是否指向存在文件
   - `service.name` 是否唯一
4. Gateway documents 层：
   - `sources.service` 是否存在于 `aggregate.services`
   - `include.path` 是否存在于对应 swagger `paths`
5. Embed 层：
   - `go:embed` 是否覆盖所有应暴露 swagger
   - `SwaggerFiles` map 是否完整

## 标准流程

### 第 1 步：构建服务索引

从 `aggregate.services` 构建服务索引：`serviceName -> specPath`

### 第 2 步：校验 spec 文件存在性

逐条校验 `spec-path` 文件是否存在，缺失记为阻断问题。

### 第 3 步：校验 documents 引用

若存在 `aggregate.documents`：

1. 校验 `sources.service` 存在
2. 校验 `include.path` 存在于目标 swagger `paths`
3. 若 `include` 为空，标注为潜在全量暴露风险

### 第 4 步：校验 embed 完整性

逐个对比服务 swagger 与 `swagger_embed.go`：

1. 是否有对应 `go:embed`
2. 是否有 map 键值映射

### 第 5 步：生成修复计划

按 `critical > major > minor` 输出，且每条都给出修改文件。

## 输出模板

1. 结论摘要：通过/失败、阻断项数量
2. Findings：
   - `critical`：会导致文档不可访问或错误暴露
   - `major`：会导致部分接口缺失或混乱
   - `minor`：命名/注释一致性问题
3. 修复顺序：先配 services，再配 documents，再配 embed
4. 回归验证：页面可见性、路径可访问性、GetSwaggerFile 可读取

## 典型问题与修复

1. `documents.sources.service` 拼写错误：改为 services 中存在的名称
2. `include.path` 写错：以 swagger `paths` 为准修正
3. 新服务未 embed：补 `go:embed` 与 `SwaggerFiles` map
4. spec-path 错目录：改为 `./proto/<module>/<file>.swagger.yaml`

## 完成标准

1. services/documents/embed 三层均完成一致性检查
2. 所有 `critical` 问题都有明确修复路径
3. 修复后可给出可执行回归步骤
