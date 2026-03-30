---
name: "<% .OrgPrefix %>-proto-style"
description: "Enforces this project's proto conventions: bilingual comments, section separators, @inject_tag validation, naming, module structure, shared type extraction. Invoke when creating or editing any .proto file in <% .ProjectName %>."
---

# <% .OrgPrefix | pascal %> Proto 风格指南 | Proto Style Guide

本文件约束 `<% .ProjectName %>` 下所有 `.proto` 的写法新增或修改 proto 时必须遵守
[EN] This guide governs every `.proto` in `<% .ProjectName %>` and must be followed when
creating or modifying one

> 规范是为了让「谁写的都一样」：协议会被多个服务、多种语言、多年时间消费，
> 风格不统一的代价不是难看，而是每个下游都要为差异写一遍适配
>
> [EN] Conventions exist so that authorship becomes invisible: a contract is consumed by
> many services, several languages and for years. Inconsistency does not merely look
> bad, it makes every downstream write its own adapter for the differences

---

## 1. 目录结构与命名 | Structure and naming

```text
proto/
├── common/                  # 跨模块复用的消息 | messages reused across modules
│   ├── common.proto         # 聚合文件，import public 所有子文件 | aggregation file
│   ├── pagination.proto     # Paging / Sorting
│   ├── result.proto         # Result / Error / BatchResult
│   ├── empty.proto          # GeneralEmptyRequest / Response
│   └── <module>.proto       # 各模块的公共实体 | per-module shared entities
├── enums/                   # 全部枚举 | every enum
│   ├── enums.proto          # 聚合文件 | aggregation file
│   ├── status.proto         # CommonStatus / TrueOrFalse / SortDirection
│   └── <module>.proto       # 各模块的枚举 | per-module enums
├── <% .ExampleModule %>/    # 业务模块：完整 CRUD 示例 | business module: full CRUD example
├── <% .SecondModule %>/     # 业务模块：第二个 CRUD 示例 | second CRUD example
└── <% .MixedModule %>/      # 混合模块：一个模块多个 service 文件 | mixed module, several service files
    ├── <% .MixedService | snake %>_service.proto         # 聚合根 | aggregate root
    └── <% .MixedService | snake %>_member_service.proto  # 成员 | members
```

### 文件命名 | File naming

| 类型 \| Kind | 命名 \| Pattern | 示例 \| Example |
| --- | --- | --- |
| 服务文件 | `{service}_service.proto` | `<% .ExampleService | snake %>_service.proto` |
| 枚举子文件 | `{module}.proto` | `enums/<% .ExampleModule %>.proto` |
| 公共消息子文件 | `{module}.proto` | `common/<% .ExampleModule %>.proto` |
| 聚合文件 | `{dir}.proto` | `enums.proto` / `common.proto` |

### 模块划分原则 | How to split modules

一个模块是一个**限界上下文**，不是一个数据库表：按「谁来调、为什么调」划分，
而不是按实体数量划分模块太细会让 common/ 爆炸，太粗会让一次改动牵连无关服务

[EN] A module is a **bounded context**, not a database table: split by who calls it and
why, never by entity count. Too fine and common/ explodes; too coarse and one change
drags unrelated services along

---

## 2. 文件头模板 | File header template

```protobuf
syntax = "proto3";

import "google/api/annotations.proto";
import "google/protobuf/timestamp.proto";          // 按需 | as needed
import "google/protobuf/wrappers.proto";           // 按需 | as needed
import "protoc-gen-openapiv2/options/annotations.proto";
import "proto/common/common.proto";
import "proto/enums/enums.proto";

option go_package = "<% .ModuleName %>/pb/{module}";
option java_package = "<% .JavaPackage %>.{module}";
package <% .ProtoPackage %>.{module};

option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_swagger) = {
  info: {
    title: "<% .OrgPrefix | pascal %> {Service} Service"
    description: "中文描述 | English description"
    version: "1.0.0"
  }
  tags: [
    {
      name: "{Tag}"
      description: "中文标签 | English tag"
    }
  ]
};
```

### import 顺序 | Import order

1. `google/api/annotations.proto`
2. `google/protobuf/*.proto`（timestamp / wrappers，按需）
3. `protoc-gen-openapiv2/options/annotations.proto`
4. `proto/common/common.proto`
5. `proto/enums/enums.proto`
6. 其它业务模块 | other business modules

---

## 3. 双语注释（强制）| Bilingual comments (mandatory)

### 分节标题 | Section separators

```protobuf
//===========================  {中文}消息定义 | {English} Message Definitions  ==========================//
//===========================  服务定义 | Service Definition  ==========================//
```

### 消息与字段 | Messages and fields

```protobuf
// 创建Xxx请求
// [EN] Create Xxx request
message XxxCreateRequest {
  string tenant_id = 1;                          // 租户ID | [EN] Tenant ID @inject_tag: validate:"required,tenant_id"
  string name = 2;                               // 名称 | [EN] Name @inject_tag: validate:"required,min=2,max=64"
  string remark = 3;                             // 备注 | [EN] Remark
}
```

- 格式：`// 中文描述 | [EN] English description  @inject_tag: ...`
- 中文在前，`[EN]` 在后，用 `|` 分隔
- 同一 message 内注释起始列尽量对齐
- `//` 后必须有一个空格

### RPC 与服务 | RPCs and services

```protobuf
service XxxService {
  option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_tag) = {
    description: "中文描述 | English description"
  };

  // 中文方法描述
  // [EN] English method description
  rpc XxxGet(XxxGetRequest) returns (XxxGetResponse) {
    option (google.api.http) = { get: "/v1/{module}/xxxs/{xxx_id}" };
    option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_operation) = {
      summary: "中文描述 | English description"
      tags: "{Tag}"
    };
  }
}
```

---

## 4. 校验标签 | Validation tags

`@inject_tag` 里的 `validate:"..."` 由 `scripts/inject-tags.sh` 注入成 Go struct tag，
运行时由 `validation/` 下的 go-argus 校验层执行完整规则速查见
`.trae/skills/proto-conventions/SKILL.md` 第 7 节

[EN] The `validate:"..."` inside `@inject_tag` is injected into Go struct tags by
`scripts/inject-tags.sh` and enforced at runtime by the go-argus layer under
`validation/`. The full rule reference lives in section 7 of
`.trae/skills/proto-conventions/SKILL.md`

| 场景 \| Case | 写法 \| Tag |
| --- | --- |
| 必填字符串 | `validate:"required"` |
| 带长度约束 | `validate:"required,min=2,max=64"` |
| 可选且有格式 | `validate:"omitempty,email"` / `omitempty,url` / `omitempty,e164` |
| 数值区间 | `validate:"gte=0,lte=9999"` |
| 批量条数上限 | `validate:"required,max=100"` |
| 枚举字段 | 仅 `validate:"required"`（拒绝 `UNSPECIFIED = 0`）|
| 项目自有规则 | `validate:"required,tenant_id"`（在 `validation/validator.go` 注册）|

### 三条铁律 | Three hard rules

1. **只给 Request 加校验**：Response / Info 类消息不加，它们不经过校验层
   [EN] Only requests carry validation; responses and info messages never pass through it
2. **枚举禁用 `oneof` 系列**：proto 加了新枚举值时手写列表会悄悄过期
   [EN] Never use oneof-style rules on enums: a hand-written list goes stale silently
3. **必填字段漏标就是没有校验**：拦截器对着没 tag 的字段永远返回通过
   [EN] A required field without the tag is simply unvalidated; the interceptor passes it

---

## 5. 命名规范 | Naming

| 对象 \| Object | 规范 \| Rule | 示例 \| Example |
| --- | --- | --- |
| message | PascalCase，`{Service}{Action}{Request/Response}` | `ProductCreateRequest` |
| 字段 | lower_snake_case | `tenant_id` |
| service | `{Service}Service` | `ProductService` |
| rpc | `{Service}{Action}` | `ProductCreate` |
| 枚举类型 | PascalCase | `CommonStatus` |
| 枚举值 | UPPER_SNAKE_CASE，带类型前缀 | `COMMON_STATUS_NORMAL` |
| 枚举零值 | 必须是 `*_UNSPECIFIED = 0` | `PRODUCT_TYPE_UNSPECIFIED = 0` |

### ID 类型 | ID types

- 业务主键用 `string`：便于后续换雪花/UUID 而不破坏协议
- 数据库自增主键用 `int64`
- 多租户体系 ID 统一用 `string`：`tenant_id` / `platform_id` / `region_id`

[EN] Business keys are `string` so the ID scheme can change without breaking the contract;
database auto-increment keys are `int64`; multi-tenant identifiers are always `string`

### 字段名一旦发布就不要改 | Field names are forever

改字段名等于破坏兼容：JSON 的 key 变了、Java/TS 客户端的属性变了编号（tag number）
更不能复用，删字段要用 `reserved`

[EN] Renaming a field breaks compatibility: JSON keys and client properties change. Field
numbers must never be reused — mark removed fields `reserved`

---

## 6. 公共类型抽取 | Extracting shared types

| 什么时候抽 \| When | 抽到哪 \| Where |
| --- | --- |
| 两个以上模块引用同一实体 | `proto/common/{module}.proto` |
| 两个以上模块引用同一枚举 | `proto/enums/{module}.proto` |
| 只有一个模块用 | 留在该模块的服务文件里 |

抽取后必须注册到聚合文件，否则别的模块 import 不到：

[EN] After extracting, register it in the aggregation file or other modules cannot see it:

```protobuf
// proto/common/common.proto
import public "proto/common/{module}.proto";

// proto/enums/enums.proto
import public "proto/enums/{module}.proto";
```

---

## 7. 接口设计 | API design

### RESTful 映射 | RESTful mapping

```text
POST   /v1/{module}/{resources}                  → Create
GET    /v1/{module}/{resources}                  → List（分页 + 过滤）
GET    /v1/{module}/{resources}/{id}             → Get
PUT    /v1/{module}/{resources}/{id}             → Update（整体更新）
PATCH  /v1/{module}/{resources}/{id}/{sub}       → 局部更新（如 status）
DELETE /v1/{module}/{resources}/{id}             → Delete
POST   /v1/{module}/{resources}/batch-delete     → 批量操作（带 body）
```

- `POST` / `PUT` / `PATCH` 必须带 `body: "*"`
- 批量操作走 `POST`，不要用带 body 的 `DELETE`：网关与代理对它的行为不一致
- 路径参数名与字段名保持一致：`{product_id}` 对应 `product_id`

[EN] POST/PUT/PATCH always carry `body: "*"`; batch operations use POST because DELETE
with a body behaves inconsistently across gateways and proxies; path parameters match
their field names

### 分页 | Pagination

```protobuf
message XxxListRequest {
  common.Paging page_request = 1;                // 分页请求 | [EN] Page request @inject_tag: validate:"required"
  common.Sorting sort = 2;                       // 排序 | [EN] Sorting
  google.protobuf.StringValue keyword = 3;       // 关键词 | [EN] Keyword
}

message XxxListResponse {
  common.Paging page_response = 1;               // 分页响应 | [EN] Page response
  repeated common.XxxInfo infos = 2;             // 列表 | [EN] List
}
```

### 可选字段用 wrappers | Optional fields use wrappers

更新接口的可选字段必须用 `google.protobuf.*Value`：proto3 的裸标量分不清
「没传」和「传了零值」，用裸字段会把「不改」误解成「改成空」

[EN] Optional fields on update APIs must use `google.protobuf.*Value`: a bare proto3
scalar cannot distinguish "absent" from "zero", so "leave unchanged" is read as "set to empty"

---

## 8. 新增模块清单 | New module checklist

1. 复制一个现有模块为 `proto/{module}/`（单 service 抄 `<% .ExampleModule %>/`，多 service 抄 `<% .MixedModule %>/`），重命名服务文件并改掉包名
2. 新枚举放 `proto/enums/{module}.proto` 并注册到 `enums.proto`
3. 新公共消息放 `proto/common/{module}.proto` 并注册到 `common.proto`
4. 把 `{module}` 加到 `scripts/generate-modular.sh` 与 `.bat` 的 `PROTO_SERVICE_MODULES`
5. 运行 `bash scripts/generate-modular.sh`（含 pb / gateway / swagger / inject-tags）
6. 在 `swagger_embed.go` 注册新服务的 swagger 文件
7. 在 `resources/<% .GatewayPrefix %>-dev.yaml` 的 `aggregate.services` 登记，文档站才能看到
8. `go mod tidy && go build ./... && go test ./...`

漏掉第 4 步最常见：proto 写完了但生成脚本没登记，CI 不会报错，只是新接口凭空消失

[EN] Step 4 is the one most often missed: the proto exists but the generation script does
not know it, CI stays green, and the new endpoints simply never appear

---

## 9. 禁止事项 | Anti-patterns

| ❌ 禁止 \| Forbidden | ✅ 正确 \| Correct |
| --- | --- |
| 单语注释 | 双语注释 `中文 \| [EN] English` |
| 缺少分节标题 | 消息定义区与服务定义区都要有 |
| 必填字段漏 `@inject_tag: validate:"required"` | 必填字段必须标注 |
| 在 `proto/common/` 之外重复定义公共消息 | 抽取到 `common/` 并注册 |
| 在业务服务文件里定义枚举 | 放 `proto/enums/` 并注册 |
| 枚举字段用 `oneof=` 系列规则 | 只用 `required` |
| 更新接口用裸标量表示可选 | 用 `google.protobuf.*Value` |
| 带 body 的 `DELETE` | 批量操作用 `POST` |
| 复用已删除字段的编号 | 用 `reserved` 占位 |
| 多租户 ID 用 `int64` | `tenant_id` 等统一 `string` |
| 手改 `pb/` 下的生成代码 | 改 proto 后重新生成 |
