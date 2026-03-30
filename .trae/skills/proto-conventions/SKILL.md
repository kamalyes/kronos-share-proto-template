---
name: "proto-conventions"
description: "Protobuf 定义规范的检查与修正：文件结构、双语注释、命名、公共类型抽取、@inject_tag 校验标签、接口形态与 URL 约定、代码生成流程。当用户编写或修改 .proto 文件、要求审查 proto 风格、或需要统一 proto 注释规范时触发。"
---

# Protobuf 定义规范

本规范适用于所有业务模块的 `.proto` 文件，确保跨模块风格一致。
完整的目录分工见 `proto/CONVENTIONS.md`，风格速查见 `.vscode/skills/<% .OrgPrefix %>-proto-style/SKILL.md`。

---

## 1. 文件结构

每个 `.proto` 文件按以下顺序组织：

```
syntax / import / option / package / swagger 配置
分隔线：消息定义
分隔线：服务定义
```

### 推荐写法

```protobuf
syntax = "proto3";

import "google/api/annotations.proto";
import "google/protobuf/struct.proto";
import "google/protobuf/timestamp.proto";
import "google/protobuf/wrappers.proto";
import "protoc-gen-openapiv2/options/annotations.proto";
import "proto/common/common.proto";
import "proto/enums/enums.proto";

option go_package = "<% .ModuleName %>/pb/<module>";
option java_package = "<% .JavaPackage %>.<module>";
package <% .ProtoPackage %>.<module>;

option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_swagger) = { ... };

//===========================  消息定义 | Message Definitions  ==========================//

// ... messages ...

//===========================  服务定义 | Service Definition  ==========================//

service XxxService { ... }
```

### 约束

- import 按以下分组排序：`google/` → `protoc-gen-openapiv2/` → `proto/common/` → `proto/enums/` → `proto/业务模块/`
- 同组内按字母序排列
- 每个 `.proto` 文件只定义一个 service
- 同一个模块目录下**可以**有多个 service 文件（见第 8.5 节），它们共享 proto package 与 Go 包

---

## 2. 分隔线

用分隔线划分逻辑区域，格式固定：

```protobuf
//===========================  中文标题 | English Title  ==========================//
```

### 必须使用的分隔线位置

| 位置 | 中文 | English |
|------|------|---------|
| 消息定义区开头 | `XXX消息定义` | `XXX Message Definitions` |
| 服务定义区开头 | `服务定义` | `Service Definition` |

### 不推荐

- 使用 `// ---` 或 `// ===` 等不一致的分隔符
- 分隔线中缺少中英文双语

---

## 3. Message 注释

### 3.1 Message 头注释（必须）

每个 message 必须有双语头注释，格式为两行：

```protobuf
// 中文描述
// [EN] English description
message XxxInfo {
```

### 3.2 Field 注释（必须）

每个字段必须有行尾注释，格式：

```protobuf
  string id = 1;                                    // 中文描述 | [EN] English description
```

#### 对齐规则

- 字段类型 + 名称 + 编号 后，用空格对齐到统一列位置
- `//` 前至少一个空格
- 中文与 `|` 之间一个空格，`|` 与 `[EN]` 之间一个空格
- `@inject_tag` 等标签放在英文描述之后，空一格

#### 推荐写法

```protobuf
message XxxListRequest {
  common.Paging page_request = 1;                    // 分页请求 | [EN] Page request
  google.protobuf.StringValue keyword = 2;           // 关键词 | [EN] Keyword
  google.protobuf.StringValue type_code = 3;         // 类型编码 | [EN] Type code
  enums.XxxStatus status = 4;                        // 状态 | [EN] Status
}
```

#### 不推荐

```protobuf
// 缺少注释
message XxxListRequest {
  common.Paging page_request = 1;
  string keyword = 2;
}

// 注释格式不统一
message XxxListRequest {
  common.Paging page_request = 1; //分页请求
  string keyword = 2; // keyword
}

// 中英文缺少分隔符
message XxxListRequest {
  common.Paging page_request = 1;  // 分页请求 Page request
}
```

### 3.3 空消息

无字段的 message 也要有头注释：

```protobuf
// 查询类型请求
// [EN] List types request
message XxxTypesRequest {}
```

---

## 4. Service 注释

### 4.1 Service 描述（必须）

```protobuf
service XxxService {
  option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_tag) = {
    description: "中文服务描述 | English service description"
  };
```

### 4.2 RPC 方法注释（必须）

每个 rpc 方法上方必须有双语注释：

```protobuf
  // 查询列表
  // [EN] List items
  rpc XxxList(XxxListRequest) returns (XxxListResponse) {
```

### 4.3 swagger summary（必须）

summary 使用 `中文 | English` 格式：

```protobuf
    option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_operation) = {
      summary: "查询列表 | List items"
      tags: "XxxTag"
    };
```

### 不推荐

```protobuf
// rpc 方法缺少注释
rpc XxxList(XxxListRequest) returns (XxxListResponse) {

// summary 只有中文或只有英文
summary: "查询列表"
summary: "List items"
```

---

## 5. 命名规范

### 5.1 Message 命名

| 类型 | 格式 | 示例 |
|------|------|------|
| 实体信息 | `XxxInfo` | `UserInfo` |
| 列表请求 | `XxxListRequest` | `UserListRequest` |
| 列表响应 | `XxxListResponse` | `UserListResponse` |
| 创建请求 | `XxxCreateRequest` | `UserCreateRequest` |
| 创建响应 | `XxxCreateResponse` | `UserCreateResponse` |
| 更新请求 | `XxxUpdateRequest` | `UserUpdateRequest` |
| 更新响应 | `XxxUpdateResponse` | `UserUpdateResponse` |
| 删除请求 | `XxxDeleteRequest` | `UserDeleteRequest` |
| 删除响应 | `XxxDeleteResponse` | `UserDeleteResponse` |
| 状态更新请求 | `XxxUpdateStatusRequest` | `UserUpdateStatusRequest` |
| 状态更新响应 | `XxxUpdateStatusResponse` | `UserUpdateStatusResponse` |

### 5.2 字段命名

- 使用 `snake_case`
- 可选字段使用 `google.protobuf.StringValue` / `Int64Value` 等包装类型
- 结构化数据使用 `google.protobuf.Struct`
- 时间字段使用 `google.protobuf.Timestamp`

### 5.3 Service 命名

- 格式：`XxxService`；同一模块下的从属 service 用 `Xxx<子实体>Service`，如 `<% .MixedService | pascal %>MemberService`
- 文件名与 service 对应：`xxx_service.proto` / `xxx_<子实体>_service.proto`
- RPC 方法名使用 `PascalCase`，格式为 `实体+动作`：`XxxList`、`XxxCreate`、`XxxGet`、`XxxUpdate`、`XxxDelete`
- 动作型 RPC 用动词短语：`XxxRetrySync`、`XxxMemberBatchInvite`；子资源用 `Xxx<子资源><动作>`，如 `XxxRegionAssign`

---

## 6. 公共 Message 抽取

### 规则

当多个模块定义了字段结构完全相同的 message 时，必须抽取到 `common` 包统一维护。

### 抽取原则

- 放入 `proto/common/` 目录下语义最匹配的 `.proto` 文件
- 如果没有合适的文件，可以新建
- 新文件必须在 `proto/common/common.proto` 中添加 `import public`
- 公共 message 命名应通用化，不带模块前缀（如 `FieldOption` 而非 `TenantEditableFieldOption`）

### 引用方式

```protobuf
// 其他模块通过 common 包引用
repeated common.XxxTypeCapability types = 1;  // 类型列表 | [EN] Type list
```

### 不推荐

- 在多个模块中重复定义结构相同的 message
- 仅命名不同但字段完全一致的 message（如 `XxxFieldOption` vs `YyyFieldOption` 字段一样）

---

## 7. 字段校验标签（@inject_tag: validate）

使用 `@inject_tag` 在 proto 字段上注入 go-argus 校验规则，生成 Go 代码时会自动写入 struct tag

### 7.1 基本格式

```protobuf
  string id = 1;  // ID | [EN] ID @inject_tag: validate:"required"
```

**位置**：`@inject_tag` 放在双语注释之后，空一格，不换行。

### 7.2 常用校验规则速查

#### 核心规则

| 规则 | 说明 | 示例 |
|------|------|------|
| `required` | 必填 | `validate:"required"` |
| `omitempty` | 空值跳过后续校验 | `validate:"omitempty,min=1"` |
| `omitzero` | 零值跳过后续校验 | `validate:"omitzero,min=1"` |

#### 比较规则

| 规则 | 说明 | 示例 |
|------|------|------|
| `min=N` | 最小值/最小长度 | `validate:"required,min=1"` |
| `max=N` | 最大值/最大长度 | `validate:"required,max=10"` |
| `len=N` | 长度等于 | `validate:"required,len=6"` |
| `gt=N` | 大于 | `validate:"required,gt=0"` |
| `gte=N` | 大于等于 | `validate:"required,gte=1"` |
| `lt=N` | 小于 | `validate:"required,lt=100"` |
| `lte=N` | 小于等于 | `validate:"required,lte=99"` |

#### 集合与条件规则

| 规则 | 说明 | 示例 |
|------|------|------|
| `oneof=A B` | 普通字符串候选值（空格分隔） | `validate:"required,oneof=active inactive"` |
| `oneofci=A B` | 普通字符串候选值（忽略大小写） | `validate:"oneofci=active inactive"` |
| `noneof=A B` | 排除普通字符串值 | `validate:"noneof=unknown deleted"` |
| `required_if=Field Value` | 条件必填：字段等于值时 | `validate:"required_if=Type ADJUST"` |
| `required_unless=Field Value` | 条件必填：字段不等于值时 | `validate:"required_unless=Status 0"` |
| `required_with=Field1 Field2` | 条件必填：任一字段非空时 | `validate:"required_with=Email Phone"` |
| `required_with_all=F1 F2` | 条件必填：所有字段非空时 | `validate:"required_with_all=Name Code"` |
| `required_without=F1 F2` | 条件必填：任一字段为空时 | `validate:"required_without=ID Code"` |
| `required_without_all=F1 F2` | 条件必填：所有字段为空时 | `validate:"required_without_all=ID Code"` |

> **禁止对 protobuf 枚举字段使用 `oneof`、`oneofci`、`noneof` 或 `noneofci`**
> 当前 go-argus 会把 protobuf 枚举格式化为枚举名称后再与候选值比较，因此数字候选值会误拒绝合法请求；枚举名称候选值也会与生成代码名称耦合
> 当 `UNSPECIFIED = 0` 不允许作为请求值时，可使用 `required` 拒绝零值；具体允许哪些枚举值，必须在业务方法中通过 `switch`、范围判断或统一的枚举有效性逻辑校验，并返回 `InvalidArgument`

#### 排除规则

| 规则 | 说明 | 示例 |
|------|------|------|
| `excluded_if=Field Value` | 条件排除：字段等于值时 | `validate:"excluded_if=Type NONE"` |
| `excluded_unless=Field Value` | 条件排除：字段不等于值时 | `validate:"excluded_unless=Mode 1"` |
| `excluded_with=F1 F2` | 条件排除：任一字段非空时 | `validate:"excluded_with=AltID"` |
| `excluded_without=F1 F2` | 条件排除：任一字段为空时 | `validate:"excluded_without=RefID"` |

#### 跨字段比较规则

| 规则 | 说明 | 示例 |
|------|------|------|
| `eqfield=Field` | 等于指定字段 | `validate:"eqfield=Password"` |
| `nefield=Field` | 不等于指定字段 | `validate:"nefield=OldPassword"` |
| `gtfield=Field` | 大于指定字段 | `validate:"gtfield=StartAt"` |
| `gtefield=Field` | 大于等于指定字段 | `validate:"gtefield=MinPrice"` |
| `ltfield=Field` | 小于指定字段 | `validate:"ltfield=MaxAmount"` |
| `ltefield=Field` | 小于等于指定字段 | `validate:"ltefield=MaxPrice"` |
| `afterfield=Field` | 时间晚于指定字段 | `validate:"required,afterfield=StartAt"` |
| `beforefield=Field` | 时间早于指定字段 | `validate:"required,beforefield=EndAt"` |

#### 格式校验规则

| 规则 | 说明 | 示例 |
|------|------|------|
| `email` | 邮箱格式 | `validate:"required,email"` |
| `url` | URL 格式 | `validate:"required,url"` |
| `ip` | IP 地址（v4/v6） | `validate:"required,ip"` |
| `ipv4` | IPv4 地址 | `validate:"required,ipv4"` |
| `uuid` | UUID | `validate:"required,uuid"` |
| `json` | JSON 格式 | `validate:"required,json"` |
| `hostname` | 主机名 | `validate:"required,hostname"` |
| `datetime=FORMAT` | 日期时间格式 | `validate:"required,datetime=2006-01-02"` |
| `mongodb` | MongoDB ObjectID | `validate:"required,mongodb"` |
| `regex=PATTERN` | 正则匹配 | `validate:"required,regex=^[a-z]+$"` |

#### 字符串规则

| 规则 | 说明 | 示例 |
|------|------|------|
| `alpha` | 纯字母 | `validate:"required,alpha"` |
| `alphanum` | 字母数字 | `validate:"required,alphanum"` |
| `lowercase` | 全小写 | `validate:"required,lowercase"` |
| `uppercase` | 全大写 | `validate:"required,uppercase"` |
| `startswith=PREFIX` | 前缀匹配 | `validate:"required,startswith=com."` |
| `endswith=SUFFIX` | 后缀匹配 | `validate:"required,endswith=.com"` |
| `contains=SUB` | 包含子串 | `validate:"required,contains=@"` |

#### 其他规则

| 规则 | 说明 | 示例 |
|------|------|------|
| `unique` | 唯一性 | `validate:"required,unique"` |
| `number` | 数字 | `validate:"required,number"` |
| `boolean` | 布尔值 | `validate:"required,boolean"` |
| `dive` | 递归校验切片/映射元素 | `validate:"required,dive,required"` |

### 7.3 推荐写法

```protobuf
// 创建请求
// [EN] Create request
message XxxCreateRequest {
  string code = 1;                                 // 编码 | [EN] Code @inject_tag: validate:"required"
  string name = 2;                                 // 名称 | [EN] Name @inject_tag: validate:"required"
  int32 year = 3;                                  // 年限 | [EN] Year @inject_tag: validate:"required,min=1,max=10"
  enums.XxxStatus status = 4;                      // 状态；允许值由业务方法校验 | [EN] Status; allowed values are validated by the service @inject_tag: validate:"required"
  google.protobuf.Timestamp end_at = 5;            // 结束时间 | [EN] End at @inject_tag: validate:"required,afterfield=StartAt"
}

// 更新请求
// [EN] Update request
message XxxUpdateRequest {
  string id = 1;                                   // ID | [EN] ID @inject_tag: validate:"required"
  google.protobuf.StringValue name = 2;            // 名称 | [EN] Name
  google.protobuf.StringValue code = 3;            // 编码 | [EN] Code
}
```

### 7.4 不推荐

```protobuf
// validate 标签与注释之间没有空格
string id = 1; // ID | [EN] ID@inject_tag: validate:"required"

// 规则之间用逗号但有多余空格
string id = 1; // ID | [EN] ID @inject_tag: validate:"required, min=1"

// protobuf 枚举字段添加 oneof 系列规则；当前校验器会将枚举格式化为名称并误拒绝合法请求
enums.XxxStatus status = 2; // 状态 | [EN] Status  ← 禁止添加 oneof 系列规则；需要拒绝零值时只加 required，并在业务方法中校验允许值

// 不必要的校验（响应 message 不需要 validate）
message XxxInfo {
  string id = 1;  // ID | [EN] ID @inject_tag: validate:"required"  ← 不推荐
}

// 条件规则字段名未使用 PascalCase（go-argus 要求字段名与 Go struct 字段名一致）
string value = 1; // 值 | [EN] Value @inject_tag: validate:"required_if=type ADJUST"  ← 不推荐，应为 Type
```

### 7.5 校验标签使用原则

| # | 原则 | 说明 |
|---|------|------|
| 1 | 仅 Request message 需要校验 | Response / Info 类 message 不加 `@inject_tag: validate` |
| 2 | 必填字段必须标注 `required` | ID、名称等业务必填字段 |
| 3 | protobuf 枚举字段禁止使用 `oneof` 系列规则 | 需要拒绝 `UNSPECIFIED = 0` 时仅加 `required`；允许值由业务方法校验 |
| 4 | 时间范围使用 `afterfield`/`beforefield` | 结束时间晚于开始时间 |
| 5 | 条件必填使用 `required_if` 等 | 根据其他字段值决定是否必填 |
| 6 | 多规则逗号分隔 | `validate:"required,min=1,max=100"` |
| 7 | 条件规则字段名使用 PascalCase | 对应 Go struct 字段名，如 `Type` 而非 `type` |

---

## 8. 接口形态与 URL 约定

同一个模块里通常混着三类接口，分清它们是 URL 设计不走偏的前提。

[EN] A module usually mixes three kinds of endpoint, and telling them apart is what keeps
URL design from drifting.

### 8.1 标准 CRUD | Standard CRUD

```text
POST   /v1/{module}/{resources}                  创建 | create
GET    /v1/{module}/{resources}                  列表（分页 + 排序 + 过滤）| list
GET    /v1/{module}/{resources}/{id}             详情 | get
PUT    /v1/{module}/{resources}/{id}             整体更新 | full update
PATCH  /v1/{module}/{resources}/{id}/{sub}       局部更新（如 status）| partial update
DELETE /v1/{module}/{resources}/{id}             删除 | delete
```

- `POST` / `PUT` / `PATCH` 必须带 `body: "*"`
- 路径参数名与字段名一致：`{tenant_id}` 对应 `tenant_id`
- 资源名用复数短横线形式：`tenant-members` 而不是 `tenantMember`

### 8.2 动作型接口 | Action endpoints

不是对资源字段的增删改，而是触发一次行为（重试同步、重新发券、强制下线）。

```text
POST   /v1/{module}/{resources}/{id}/retry-sync        触发重试 | trigger a retry
POST   /v1/{module}/{resources}/{id}/members/batch-invite  批量邀请 | batch invite
```

| 规则 \| Rule | 原因 \| Why |
| --- | --- |
| 统一用 `POST` + 动词短横线路径 | 它不改字段，重复调用也不是幂等覆盖，塞进 PUT/PATCH 会误导调用方 |
| 必须有自己的 Request/Response | 复用 `GetRequest` 的话，以后加「只同步某个下游」这类参数就没地方放 |
| 结果用枚举而不是 bool | 动作的结局常常超过两种（待同步/已同步/失败）|

[EN] Action endpoints always use POST with a verb path: they do not edit fields and
repeating them is not an idempotent overwrite. They need their own request/response so
future parameters have somewhere to live, and their outcome is an enum because actions
usually have more than two possible results.

### 8.3 子资源 | Sub-resources

挂在聚合根下、有独立 ID、需要单独增改删的东西。

```text
POST   /v1/{module}/{resources}/{id}/region-assignments            创建 | create
PUT    /v1/{module}/{resources}/{id}/region-assignments/{aid}      更新 | update
DELETE /v1/{module}/{resources}/{id}/region-assignments/{aid}      删除 | delete
GET    /v1/{module}/{resources}/{id}/members                       列表 | list
```

- 父 ID 放路径，不要再塞进 body
- 只读的附属数据不需要独立 ID，直接作为父资源的字段返回
- 子资源列表同样要分页：它会随父资源增长

[EN] The parent ID lives in the path, never also in the body. Read-only attached data needs
no ID of its own and rides along as a field of the parent. Sub-resource lists are paged too,
because they grow with the parent.

### 8.4 批量操作 | Batch operations

```text
POST   /v1/{module}/{resources}/batch-delete      body: { ids: [...] }
```

| 规则 \| Rule | 原因 \| Why |
| --- | --- |
| 走 `POST`，不要用带 body 的 `DELETE` | 网关与代理对带 body 的 DELETE 行为不一致 |
| 必须有条数上限 | `validate:"required,max=100"`，否则一次请求能打爆下游 |
| 逐条返回结果 | 用 `common.BatchResult`，让调用方能精确重试，而不是整体成功/失败 |

### 8.5 一个模块多个 service | Several services in one module

一个 `.proto` 文件只定义一个 service，但同一个模块目录下可以有多个 service 文件 ——
它们共享 proto package 与 Go 包，共用 `common/{module}.proto` 与 `enums/{module}.proto`。

[EN] One service per `.proto` file, but a module directory may hold several service files.
They share the proto package and Go package, and reuse the module's shared entities and enums.

| 什么时候拆成两个 service \| When to split | 什么时候合并 \| When to keep one |
| --- | --- |
| 调用方不同（运营后台 vs 控制台）| 调用方相同，只是接口多 |
| 权限边界不同，需要分别授权 | 权限完全一致 |
| 变更频率差距大 | 总是一起改 |
| 需要独立部署或限流 | 同进程、同配额 |

拆开后两个 service **不要互相 import**：共享的类型提到 `common/`，否则两个 service 又被焊回一起。

[EN] Once split, the two services must not import each other: lift shared types into
`common/`, or they are welded back together.

---

## 9. 常见约束清单

| # | 约束 | 说明 |
|---|------|------|
| 1 | 每个 message 必须有双语头注释 | `// 中文\n// [EN] English` |
| 2 | 每个字段必须有双语行尾注释 | `// 中文 \| [EN] English` |
| 3 | 每个 rpc 方法必须有双语注释 | `// 中文\n// [EN] English` |
| 4 | swagger summary 必须双语 | `中文 \| English` |
| 5 | 消息定义区和服务定义区必须有分隔线 | `//===========================  ...  ==========================//` |
| 6 | 字段注释必须对齐 | 同一 message 内 `//` 对齐 |
| 7 | `//` 后必须有一个空格 | 禁止 `//注释` |
| 8 | 公共结构必须抽取到 common | 避免跨模块重复定义 |
| 9 | import 分组排序 | google → openapiv2 → common → enums → 业务模块 |
| 10 | 空消息也必须有头注释 | `message EmptyReq {}` 上方也要有注释 |
| 11 | Request 必填字段必须加 `@inject_tag: validate` | Response / Info 不加 |
| 12 | `@inject_tag` 放在双语注释之后空一格 | 禁止与注释粘连 |
| 13 | 条件规则字段名使用 PascalCase | `required_if=Type ADJUST` 而非 `type` |
| 14 | protobuf 枚举字段禁止使用 `oneof` 系列规则 | 允许值必须由业务方法校验 |
| 15 | 动作型接口统一 `POST` + 动词短横线路径 | 不是改字段，别塞进 PUT/PATCH（见第 8.2 节）|
| 16 | 批量接口必须有条数上限且逐条返回结果 | `validate:"required,max=N"` + `common.BatchResult`（见第 8.4 节）|
| 17 | 子资源的父 ID 只放路径 | 不要同时塞进 body（见第 8.3 节）|
| 18 | 同模块的两个 service 不得互相 import | 共享类型提到 `common/`（见第 8.5 节）|

---

## 10. 完整示例

以下示例直接取自本仓库的真实文件，可以对照着看。
[EN] The following examples are the repository's real files, so you can read them side by side.

### 10.1 枚举子文件 — `proto/enums/<% .MixedModule %>.proto`

```protobuf
syntax = "proto3";

option go_package = "<% .ModuleName %>/pb/enums";
option java_package = "<% .JavaPackage %>.enums";
package <% .ProtoPackage %>.enums;

// <% .MixedService | pascal %> 状态
// [EN] <% .MixedService | pascal %> status
enum <% .MixedService | pascal %>Status {
  <% .MixedService | snake | upper %>_STATUS_UNSPECIFIED = 0; // 未指定 | [EN] Unspecified
  <% .MixedService | snake | upper %>_STATUS_PENDING = 1;     // 待激活 | [EN] Pending activation
  <% .MixedService | snake | upper %>_STATUS_NORMAL = 2;      // 正常 | [EN] Normal
  <% .MixedService | snake | upper %>_STATUS_FROZEN = 3;      // 冻结 | [EN] Frozen
}
```

写完必须在 `proto/enums/enums.proto` 里 `import public`，否则业务模块看不到它。
[EN] It must be registered with `import public` in `proto/enums/enums.proto` or business modules cannot see it.

### 10.2 公共子文件 — `proto/common/pagination.proto`

```protobuf
syntax = "proto3";

option go_package = "<% .ModuleName %>/pb/common";
option java_package = "<% .JavaPackage %>.common";
package <% .ProtoPackage %>.common;

// 分页信息
// [EN] Paging information
// 请求与响应共用一个消息：请求里填 page/size，响应里回填 total
// [EN] Shared by request and response: requests fill page/size, responses fill total
message Paging {
  int32 page = 1;           // 当前页码 | [EN] Current page number  @inject_tag: validate:"omitempty,gte=1"
  int32 size = 2;           // 每页条数（上限保护）| [EN] Page size, capped  @inject_tag: validate:"omitempty,gte=1,lte=200"
  int32 total = 3;          // 总条数（响应字段）| [EN] Total count @inject_tag: swagger:"omitrequired"
}

// 排序信息
// [EN] Sorting information
message Sorting {
  string field = 1;         // 排序字段 | [EN] Sort field
  bool ascending = 2;       // 是否升序 | [EN] Whether ascending
}
```

注意分页只有 `Paging` 一个消息，请求用 `page_request`、响应用 `page_response` 两个字段名区分，
不要再造一个 `PagingResponse`：两份结构早晚会漂。

[EN] There is a single `Paging` message; requests and responses distinguish it by field name
(`page_request` / `page_response`) instead of a second `PagingResponse` type, which would drift.

### 10.3 业务模块 — 混合模块的聚合根（节选）

```protobuf
//===========================  <% .MixedService | pascal %> 消息定义 | Message Definitions  ==========================//

// 创建<% .MixedService | pascal %>请求
// [EN] Create <% .MixedService | pascal %> request
message <% .MixedService | pascal %>CreateRequest {
  string code = 1;                                      // 编码（全局唯一，创建后不可改）| [EN] Code, immutable @inject_tag: validate:"required,min=2,max=32"
  string name = 2;                                      // 名称 | [EN] Name @inject_tag: validate:"required,min=2,max=64"
  string platform_id = 3;                               // 平台ID | [EN] Platform ID @inject_tag: validate:"required"
  repeated string region_ids = 4;                       // 初始地区列表 | [EN] Initial region list @inject_tag: validate:"omitempty,max=20"
}

// 列表请求
// [EN] List request
message <% .MixedService | pascal %>ListRequest {
  common.Paging page_request = 1;                       // 分页请求 | [EN] Page request @inject_tag: validate:"required"
  common.Sorting sort = 2;                              // 排序 | [EN] Sorting
  google.protobuf.StringValue keyword = 3;              // 关键词 | [EN] Keyword
  enums.<% .MixedService | pascal %>Status status = 4;  // 状态 | [EN] Status
}

//===========================  服务定义 | Service Definition  ==========================//

service <% .MixedService | pascal %>Service {
  option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_tag) = {
    description: "<% .MixedService | pascal %> 管理服务 | <% .MixedService | pascal %> management"
  };

  // 创建<% .MixedService | pascal %>
  // [EN] Create <% .MixedService | pascal %>
  rpc <% .MixedService | pascal %>Create(<% .MixedService | pascal %>CreateRequest) returns (<% .MixedService | pascal %>CreateResponse) {
    option (google.api.http) = {
      post: "/v1/<% .MixedModule %>/<% .MixedService | kebab %>s"
      body: "*"
    };
    option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_operation) = {
      summary: "创建<% .MixedService | pascal %> | Create <% .MixedService | pascal %>"
      tags: "<% .MixedService | pascal %>Management"
    };
  }

  // 重试下游同步（动作型接口）
  // [EN] Retry downstream sync (action-style endpoint)
  rpc <% .MixedService | pascal %>RetrySync(<% .MixedService | pascal %>RetrySyncRequest) returns (<% .MixedService | pascal %>RetrySyncResponse) {
    option (google.api.http) = {
      post: "/v1/<% .MixedModule %>/<% .MixedService | kebab %>s/{<% .MixedService | snake %>_id}/retry-sync"
      body: "*"
    };
    option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_operation) = {
      summary: "重试下游同步 | Retry downstream sync"
      tags: "<% .MixedService | pascal %>Management"
    };
  }
}
```

完整文件见 `proto/<% .MixedModule %>/<% .MixedService | snake %>_service.proto`，
同模块第二个 service 见 `proto/<% .MixedModule %>/<% .MixedService | snake %>_member_service.proto`。

[EN] See the full files under `proto/<% .MixedModule %>/`.

### 10.4 聚合文件注册 | Registering in the aggregation files

```protobuf
// proto/common/common.proto
import public "proto/common/<% .MixedModule %>.proto";

// proto/enums/enums.proto
import public "proto/enums/<% .MixedModule %>.proto";
```

---

## 11. 代码生成流程

### 11.1 首次准备（只需一次）| One-time setup

```bash
bash scripts/setup-all.sh --no-pause     # Linux / macOS
scripts\setup-all.bat --no-pause         # Windows
```

安装固定版本的 protoc 与 5 个插件到 `GOPATH/bin`，并准备 googleapis / grpc-gateway 的 proto。
版本写死在脚本里，不跟随系统 protoc —— 不同机器装不同版本会让 pb 的 diff 永远对不上。

[EN] Installs the pinned protoc and five plugins into `GOPATH/bin` and prepares the
googleapis / grpc-gateway protos. Versions are pinned in the scripts rather than following
the system protoc, because mixed versions make the pb diff never settle.

### 11.2 生成命令 | Generate

```bash
bash scripts/generate-modular.sh         # Linux / macOS
scripts\generate-modular.bat             # Windows
```

### 11.3 生成流程 | What it does

| 步骤 | 说明 |
|------|------|
| 1. 环境确认 | 调 `setup-all.sh` 校验 protoc 与插件版本，已装则跳过 |
| 2. 清理旧产物 | 删除 `proto/` 下的 `.pb.go`、`.gw.go`、`.swagger.yaml` 残留 |
| 3. 准备输出目录 | `prepare-pb-output.sh` 清理并重建 `pb/` |
| 4. 生成 Go / gRPC | 按 `enums` → `common` → 业务模块的顺序执行 `protoc --go_out --go-grpc_out` |
| 5. 生成 Gateway | 对含 `google.api.http` 的文件执行 `protoc --grpc-gateway_out` |
| 6. 生成 OpenAPI | 对含 `openapiv2_swagger` 或 `google.api.http` 的文件执行 `protoc --openapiv2_out`（输出 yaml）|
| 7. 注入 struct tag | `inject-tags.sh` 把 `@inject_tag` 写进 `pb/*.pb.go`，并清理 swagger 里的残留、注入约束 |

顺序不是随意的：`enums` 和 `common` 被业务模块依赖，必须先生成。

[EN] The order matters: `enums` and `common` are depended on by business modules and must
be generated first.

### 11.4 新增模块必须登记三处 | Three places to register a new module

| # | 位置 | 漏掉的后果 |
|---|------|-----------|
| 1 | `scripts/generate-modular.sh` 与 `.bat` 的 `PROTO_SERVICE_MODULES` | 完全不会被生成，CI 也不报错 |
| 2 | `swagger_embed.go` 的 `//go:embed` 与 `SwaggerFiles` | 文档站拿不到这个服务的 swagger |
| 3 | `resources/<% .GatewayPrefix %>-dev.yaml` 的 `aggregate.services` | 网关不聚合，接口在文档里不可见 |

第 1 步最常被漏：proto 写完了但脚本没登记，新接口凭空消失。
[EN] Step 1 is missed most often: the proto exists but the script does not know it, and the
new endpoints simply never appear.

### 11.5 校验规则在哪执行 | Where the rules run

`@inject_tag: validate:"..."` 只是把规则写进 struct tag，真正执行它的是 `validation/` 下的
go-argus 校验层：

[EN] `@inject_tag: validate:"..."` only writes the rule into a struct tag; the go-argus layer
under `validation/` is what enforces it:

```text
proto 注释  →  protoc 生成 pb.go（无 tag）  →  inject-tags 注入 tag  →  validation.Struct(req) 执行
```

- 业务服务接 `validation.UnaryServerInterceptor`，新增 RPC 自动被覆盖
- 项目自有规则（如 `tenant_id`）在 `validation/validator.go` 注册后即可在 proto 注释里使用
- `validation/contract_test.go` 守住这条链路：注入断了会直接测试失败，而不是线上静默放行

[EN] Services wire `validation.UnaryServerInterceptor` so new RPCs are covered automatically;
project-specific rules are registered in `validation/validator.go`; and
`validation/contract_test.go` guards the chain so a broken injection fails a test instead of
silently passing everything in production.

### 11.6 生成后的文件结构 | Output layout

```text
<% .ProjectName %>/
├── pb/
│   ├── enums/                    # .pb.go
│   ├── common/                   # .pb.go
│   ├── <% .MixedModule %>/       # .pb.go, _grpc.pb.go, .pb.gw.go（两个 service 都在这个包里）
│   └── ...
└── proto/
    ├── <% .MixedModule %>/       # .proto 源文件 + .swagger.yaml
    └── ...
```

### 11.7 本地联调 | Local development

下游服务想试尚未提交的协议改动时，在下游的 go.mod 里替换成本地路径：

[EN] To try unreleased contract changes downstream, replace the dependency with a local path
in the downstream go.mod:

```bash
go mod edit -replace <% .ModuleName %>=../<% .ProjectName %>
go mod tidy
```

联调完记得撤销 replace，不要把它提交进去。
[EN] Remove the replace before committing.

### 11.8 注意事项 | Gotchas

| # | 注意 | 说明 |
|---|------|------|
| 1 | 先 generate 再 `go mod tidy` | `pb/` 为空时 tidy 解析不到自身的 pb 包，会直接失败 |
| 2 | 改 proto 后必须重新生成 | 否则 Go 代码与协议不一致，而编译不会报错 |
| 3 | `pb/` 要提交进仓库 | 下游按 commit hash 引用，不入库就是一个没有 Go 代码的空模块 |
| 4 | 不要手改 `pb/` | 下次生成会整体覆盖 |
| 5 | 生成失败先看 import 路径 | proto 之间的 import 必须相对仓库根目录，如 `proto/common/common.proto` |
| 6 | CI 会自动补齐 pb | `proto/**` 变更合并到 `<% .BaseBranch %>` 后由 `generate-pb.yml` 重新生成并提交 |
