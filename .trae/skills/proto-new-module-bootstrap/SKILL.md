---
name: proto-new-module-bootstrap
description: "为新 proto 模块生成落地计划与变更清单，覆盖 proto 模板、scripts 模块注册、gateway aggregate.services/documents、swagger_embed.go 注册和验证步骤用于新增服务模块快速接入"
argument-hint: "请输入模块名和接入策略（例如：billing，加入 OpenService 文档）"
user-invocable: true
---

# Proto New Module Bootstrap

## 技能目标

将“新增 proto 模块”拆解为可执行步骤，确保一次改全：

1. 生成模块级变更清单（文件和顺序）
2. 提供可复制的 proto 与 gateway 片段模板
3. 明确 `aggregate.documents` 是否需要接入
4. 明确发布前验证路径

## 何时使用

- "新增一个 proto 模块"
- "新增服务后要改哪些文件"
- "把新服务接入 gateway 和 swagger"
- "新接口是否要进 OpenService 文档"

## 输入参数

最少输入：

- 模块名（如 `billing`）
- 服务名（如 `BillingService`）

可选输入：

- 是否接入独立文档（`aggregate.documents`）
- 文档白名单路径（如 `/v1/billing/orders`）
- 优先目标（最快接入 / 最严治理）

## 决策点

### 决策 1：模块类型

1. 基础模块：仅提供通用 enum/message（类似 common/enums）
2. 服务模块：包含 service/rpc/http/openapi 注解

### 决策 2：是否进入独立文档

1. 对外接口：加入 `aggregate.documents` 并限制 `include.path` 白名单
2. 内部接口：仅加入 `aggregate.services`，不加入 `documents`

## 标准流程

### 第 1 步：创建 proto 模块文件

新增：`proto/<module>/<module>_service.proto`

最小模板（服务模块，按当前仓库风格）：

```proto
syntax = "proto3";

import "google/api/annotations.proto";
import "google/protobuf/wrappers.proto";
import "protoc-gen-openapiv2/options/annotations.proto";
import "proto/common/common.proto";

option go_package = "github.com/kamalyes/kronos-share-proto-template/pb/<module>";
option java_package = "com.kamalyes.kronos.api.<module>";
package kronos.api.<module>;

option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_swagger) = {
  info: {
    title: "Engine Kronos <Module> Service"
    description: "<模块中文描述> | <Module English Description>"
    version: "1.0.0"
  }
  tags: [
    {
      name: "<ServiceTag>"
      description: "<标签中文描述> | <Tag English Description>"
    }
  ]
};

//===========================  消息定义 | Message Definitions  ==========================//

// 列表请求
// [EN] List request
message ListRequest {
  common.Paging page_request = 1;               // 分页请求 | [EN] Page request @inject_tag: validate:"required"
  common.Sorting sort = 2;                      // 排序 | [EN] Sorting
  google.protobuf.StringValue keyword = 3;      // 关键字 | [EN] Keyword
}

// 列表响应
// [EN] List response
message ListResponse {
  common.Paging page_response = 1;              // 分页响应 | [EN] Page response
}

//===========================  服务定义 | Service Definition  ==========================//

// <服务中文名>
// [EN] <Service English Name>
service <ServiceName> {
  // 列表查询
  // [EN] List query
  rpc List(ListRequest) returns (ListResponse) {
    option (google.api.http) = { get: "/v1/<resource>" };
    option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_operation) = {
      summary: "列表查询 | List query"
      description: "按条件分页查询 | Query by conditions with paging"
      tags: "<ServiceTag>"
    };
  }
}
```

### 第 2 步：注册生成脚本模块列表

同步更新：

- [scripts/generate-modular.sh](../../../scripts/generate-modular.sh)
- [scripts/generate-modular.bat](../../../scripts/generate-modular.bat)

将新模块加入服务模块数组 `PROTO_SERVICE_MODULES`（基础模块数组是 `PROTO_BASE_MODULES`，
只提供通用 enum/message 的模块才放那边）。

### 第 3 步：执行生成

执行生成脚本，产出：

1. `pb/<module>/*pb.go`
2. `pb/<module>/*pb.gw.go`
3. `proto/<module>/*swagger.yaml`

### 第 4 步：接入 gateway 服务聚合

更新 [resources/kronos-share-proto-template-dev.yaml](../../../resources/kronos-share-proto-template-dev.yaml) 的 `aggregate.services`

模板：

```yaml
- name: "BillingService"
  description: "账单服务"
  spec-path: "./proto/billing/billing_service.swagger.yaml"
  version: "1.0.0"
  enabled: true
```

### 第 5 步：接入 documents 独立文档（可选）

若需对外暴露，更新 `aggregate.documents`：

```yaml
documents:
  - name: "OpenService"
    title: "Open Service"
    description: "开放接口"
    version: "1.0.0"
    enabled: true
    sources:
      - service: "BillingService"
        include:
          - path: "/v1/billing/orders"
```

规则：

1. `service` 必须已在 `aggregate.services` 注册
2. `include.path` 必须是 swagger 真实存在路径
3. 严禁把内部管理路径直接全量暴露

### 第 6 步：接入 swagger_embed

更新 [swagger_embed.go](../../../swagger_embed.go)：

1. 新增 `go:embed proto/<module>/<module>_service.swagger.yaml`
2. 新增变量：`var <Module>ServiceSwagger []byte`
3. 更新 `SwaggerFiles` map

### 第 7 步：验证

1. swagger 聚合页面能看到新服务
2. 若接入 documents，独立文档只包含白名单路径
3. `GetSwaggerFile` 可读取新模块 swagger

## 输出模板

1. 变更文件清单（按执行顺序）
2. 每个文件的最小修改片段
3. documents 接入决策说明（接入/不接入）
4. 验证清单与回滚建议

## 完成标准

1. 新模块至少完成 proto、生成脚本、gateway、embed 四处联动
2. 如配置了 documents，必须完成 service 引用与 path 白名单校验
3. 给出可直接执行的验收步骤
