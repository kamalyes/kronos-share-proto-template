---
name: proto-lint-governance
description: "基于当前仓库实际实现检查并治理 proto 规范，覆盖 enum/message/common 复用、注释、gateway 注解、scripts 模块注册、aggregate.services/documents 与 swagger_embed.go 一致性用于发布前巡检和批量改造前体检"
argument-hint: "请输入检查范围（全仓库或模块路径）和输出深度（快速清单/完整报告）"
user-invocable: true
---

# Proto Lint Governance

## 技能目标

在一次执行中给出可落地的规范体检结果：

1. 识别 Proto 定义风格偏差（enum/message/common/注释/注解）
2. 识别 Gateway、Swagger、Embed、生成脚本四层不一致
3. 区分“通用规则”与“本仓库特例”，避免误报
4. 输出按严重度排序的问题清单与可执行修复建议

## 何时使用

出现以下诉求时使用：

- "proto 规范巡检"
- "enum 和 message 风格不统一"
- "gateway 配置是否一致"
- "documents 独立文档是否可靠"
- "发布前做一次 proto/gateway 健康检查"
- "新增模块后为什么文档没出来"
- "sh 和 bat 生成脚本是否同步"

## 输入参数

最少输入：

- 检查范围：全仓库或单模块（如 `proto/<% .ExampleModule %>`）

可选输入：

- 输出深度：快速清单 / 完整报告
- 修复偏好：只报问题 / 同时给补丁建议

## 当前仓库基线（以现状为准）

以下基线用于降低误报，若实际代码已变更，以当前文件内容为准动态更新：

1. `proto` 目录当前模块：`enums`、`common`、`<% .ExampleModule %>`、`<% .SecondModule %>`、`<% .MixedModule %>`
2. 生成脚本模块数组（以脚本当前内容为准，不要照抄本清单）：
	- `PROTO_BASE_MODULES=(enums)`（sh）
	- `PROTO_SERVICE_MODULES=(common <% .ExampleModule %> <% .SecondModule %> <% .MixedModule %>)`（sh）
	- `PROTO_BASE_MODULES=enums`（bat）
	- `PROTO_SERVICE_MODULES=common <% .ExampleModule %> <% .SecondModule %> <% .MixedModule %>`（bat）
3. gateway 聚合服务：`<% .ExampleService %>Service`、`<% .SecondService %>Service`、`<% .MixedService %>Service`、`<% .MixedService %>MemberService`
4. `aggregate.documents` 当前可不存在；不存在时不判错，仅给信息提示
5. `swagger_embed.go` 为每个服务模块各嵌入一份 swagger

## 事实来源（默认读取）

- [proto/common/common.proto](../../../proto/common/common.proto)
- [proto/enums/enums.proto](../../../proto/enums/enums.proto)
- [proto/<% .ExampleModule %>/<% .ExampleService | snake %>_service.proto](../../../proto/<% .ExampleModule %>/<% .ExampleService | snake %>_service.proto)
- [proto/<% .MixedModule %>/<% .MixedService | snake %>_service.proto](../../../proto/<% .MixedModule %>/<% .MixedService | snake %>_service.proto)
- [resources/<% .ProjectName %>-dev.yaml](../../../resources/<% .ProjectName %>-dev.yaml)
- [swagger_embed.go](../../../swagger_embed.go)
- [scripts/generate-modular.sh](../../../scripts/generate-modular.sh)
- [scripts/generate-modular.bat](../../../scripts/generate-modular.bat)

## 检查规则

### A. Proto 规范

1. 头部规范：`syntax`、`package`、`go_package`、`java_package` 是否完整
2. enum 规范（标准1）：
	- 零值必须使用 `*_UNSPECIFIED = 0`
	- 同一个 enum 内，所有枚举值必须使用统一前缀（通常为 enum 名的 UPPER_SNAKE_CASE 形式）
	- 非零值命名必须为 `UPPER_SNAKE_CASE`，禁止 CamelCase（如 `ExternalError`）
	- 新增枚举值只能追加，禁止重排或改号
	- 废弃枚举值必须使用 `reserved <number>` 或 `reserved "<name>"` 防止复用
	- 若因历史兼容必须保留 `*_UNKNOWN = 0`，需在 enum 注释中明确说明 `legacy-zero-value` 原因
3. message 规范：分页/排序优先复用 `common.Paging`、`common.Sorting`
4. wrappers 规范：更新/筛选可选字段优先 `google.protobuf.*Value`
5. 注释规范：
	- message/service/rpc 使用中文 + `[EN]` 对照
	- 字段尽量使用行尾中英注释
	- 大段结构优先使用分隔注释块（`//=========================== ...`）

#### A.1 Enum 写法模板（标准）

推荐示例：

```proto
enum CommonStatus {
  COMMON_STATUS_UNSPECIFIED = 0;  // 未指定 | [EN] Unspecified
  COMMON_STATUS_NORMAL = 1;       // 正常 | [EN] Normal
  COMMON_STATUS_DISABLED = 2;     // 禁用 | [EN] Disabled
}
```

反例（不推荐）：

```proto
enum StatusCode {
  OK = 0;
  ExternalError = 104;
}
```

修复方向：

```proto
enum StatusCode {
  STATUS_CODE_UNSPECIFIED = 0;
  STATUS_CODE_OK = 1;
  EXTERNAL_ERROR = 104;
}
```

#### A.2 Enum 兼容性约束（标准）

1. 对外已发布 enum：重命名会影响 JSON 文本值与 OpenAPI 枚举名，默认判 `major`
2. 变更零值语义或改动既有编号：可能引发跨语言兼容问题，默认判 `critical`
3. 新增值未追加到尾部：默认判 `major`
4. 删除值但未 `reserved`：默认判 `major`

### B. Gateway 与 OpenAPI 注解

1. service/rpc 是否定义 `google.api.http`
2. rpc 是否定义 `openapiv2_operation` 且至少包含 `summary/tags`
3. 文件级是否定义 `openapiv2_swagger` 元信息与 tags
4. `openapiv2_operation.tags` 应能在文件级 tags 中找到对应项

### C. 生成链路一致性（仓库特有）

1. 服务模块新增后，必须同时更新：
	- [scripts/generate-modular.sh](../../../scripts/generate-modular.sh)
	- [scripts/generate-modular.bat](../../../scripts/generate-modular.bat)
2. 模块数组应保持语义一致：
	- 基础模块放 `PROTO_BASE_MODULES`
	- 服务模块放 `PROTO_SERVICE_MODULES`
3. 生成产物路径应匹配当前工程约定：
	- `pb/<module>/*.pb.go`
	- `pb/<module>/*_grpc.pb.go`
	- `pb/<module>/*.pb.gw.go`（有 http 注解时）
	- `proto/<module>/*.swagger.yaml`（有 openapiv2_swagger 时）

### D. services 聚合

1. `aggregate.services[].name/spec-path/enabled` 是否完整
2. `spec-path` 指向的 swagger 文件是否真实存在
3. service 名称是否重复或语义冲突
4. `swagger.spec-path` 默认文档入口是否指向存在文件

### E. documents 独立文档（特殊）

若存在 `aggregate.documents`，额外校验：

1. `documents[].sources[].service` 必须能在 `aggregate.services` 找到
2. `documents[].sources[].include[].path` 必须能在目标 swagger 的 `paths` 找到
3. 对外文档必须采用白名单路径，避免全量暴露
4. `name/title/description/version` 必须可读且与业务域一致

若不存在 `aggregate.documents`：

1. 不报错
2. 给出信息级提示：当前未配置独立文档聚合

### F. swagger_embed 注册

1. 是否有对应 `go:embed proto/<module>/<file>.swagger.yaml`
2. 是否有对应变量声明
3. `SwaggerFiles` map 是否包含该 swagger 文件键值

### G. 仓库已知特例（避免误判）

1. `common` 与 `enums` 属于基础模块，只提供 message / enum，不强制要求
   service、http 或 openapi 注解
2. 探活类接口（如 `/health`、`/ready`）不强制 `/v1/*` 前缀：它们由基础设施
   按固定路径探测，加版本前缀反而要改探针配置
3. 本节是「本仓库当前的例外」，不是通用规则。新增例外前先确认它确实是
   有意为之而不是漏改——把漏改写进例外清单，等于把问题变成规范

## 执行流程

1. 建立“当前仓库基线快照”（模块、脚本数组、services、embed）
2. 收集范围内 proto、swagger、gateway 配置与 embed 文件
3. 先做单文件规则检查，再做跨文件一致性检查
4. 对问题标注严重度：`critical`、`major`、`minor`、`info`
5. 生成最小修复路径，必要时附分步补丁清单

## 输出模板

1. 基线快照：本次检查使用的模块与配置事实
2. 概览：检查范围、发现数量、阻断项数量
3. Findings（按严重度排序，附文件路径与原因）
4. 修复建议（逐文件，优先最小改动）
5. 回归检查点（修复后如何验证）

## 回归验证建议

1. 重新执行生成脚本并确认 pb/swagger 产物齐全
2. 检查 [resources/<% .ProjectName %>-dev.yaml](../../../resources/<% .ProjectName %>-dev.yaml) 聚合页面是否可见目标服务
3. 检查 [swagger_embed.go](../../../swagger_embed.go) 的 `GetSwaggerFile` 是否能读取目标 swagger
4. 若存在 documents，校验文档只含白名单路径

## 严重度定义

1. `critical`：会导致文档生成失败、网关路由缺失、对外文档误暴露
2. `major`：不阻断运行，但会导致模块接入不完整或后续高概率出错（如 sh/bat 数组不一致）
3. `minor`：文档与注释一致性问题、命名可读性问题
4. `info`：当前未启用但可选的治理项（如未配置 documents）

补充（enum 专项）：

1. `critical`：修改已发布 enum 的编号、修改零值语义
2. `major`：已发布 enum 重命名、删除值未做 `reserved`、新增值非追加
3. `minor`：命名风格不统一（如前缀不一致、CamelCase 混入）

## 完成标准

满足以下条件才算完成：

1. 覆盖 Proto、生成脚本、Gateway、services/documents、embed 五个维度
2. 明确区分“规则问题”与“已知特例”，避免误报
3. 给出可执行修复建议，而不仅是抽象结论
4. 明确哪些问题会阻断发布
