---
name: "apex-share-proto"
description: "Scaffolds Protobuf service definitions with bilingual comments, enums, and gateway config. Invoke when adding new proto services, messages, or enums to an apex-share-proto project."
---

# Apex Share Proto - gRPC/Protobuf Protocol Development

You are an expert in the Apex shared protobuf protocol project. When the user asks to add a new proto service, message, or enum, follow these conventions precisely.

## Project Architecture

```bash
project/
├── bootstrap/              # Gateway server startup
│   ├── main.go
│   ├── server.go
│   └── generate_handler.go
├── pb/                     # Generated Go code (DO NOT EDIT)
│   ├── common/
│   ├── enums/
│   └── {service}/
├── proto/                  # Protobuf source definitions
│   ├── common/                 # Shared messages (StatusCode, Error, Paging, etc.)
│   │   └── common.proto
│   ├── enums/                  # Shared enums (CommonStatus, UserStatus, etc.)
│   │   └── enums.proto
│   └── {service}/              # Per-service proto files
│       └── {service}_service.proto
├── resources/              # Gateway aggregation configs
│   └── gateway-dev.yaml
├── scripts/                # Code generation scripts
│   ├── generate-modular.bat/.sh
│   ├── inject-tags.bat/.sh
│   ├── setup-dependencies.bat/.sh
│   └── run.bat/.sh
├── swagger_embed.go        # Swagger doc embedding
└── go.mod
```

## Bilingual Comment Convention (MANDATORY)

All `.proto` files MUST use Chinese-English bilingual comments following these rules:

### File-level comments: Chinese on top, English below with `[EN]` prefix

```protobuf
// 状态码
// [EN] Status code
enum StatusCode { ... }
```

### Inline comments: Chinese and English on same line, separated by ` | `

```protobuf
STATUS_CODE_OK = 1;  // 正常 | [EN] OK
```

### Section separators: Bilingual title

```protobuf
//===========================  通用处理结果 | Common Processing Result  ==========================//
```

### Service/Message/RPC comments: Chinese on top, English below

```protobuf
// 健康检查请求
// [EN] Health check request
message HealthCheckRequest {}

// 健康检查服务
// [EN] Health check service
service HealthService {
  // 健康检查
  // [EN] Health check
  rpc HealthCheck(...) returns (...);
}
```

## Adding a New Proto Service - Complete Checklist

When the user says "add a XXX service/proto", perform ALL of the following steps:

### Step 1: Create Proto File (`proto/xxx/xxx_service.proto`)

```protobuf
syntax = "proto3";

import "google/api/annotations.proto";
import "google/protobuf/timestamp.proto";
import "protoc-gen-openapiv2/options/annotations.proto";
import "proto/common/common.proto";
import "proto/enums/enums.proto";

option go_package = "{module}/pb/xxx";
option java_package = "{java_package}.xxx";
package {proto_package}.xxx;

option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_swagger) = {
  info: {
    title: "{OrgPrefix} Xxx Service"
    description: "XXX服务 | Xxx Service"
    version: "1.0.0"
  }
  tags: [
    {
      name: "XxxManagement"
      description: "XXX管理 | Xxx Management"
    }
  ]
};

//===========================  XXX消息定义 | Xxx Message Definitions  ==========================//

// XXX创建请求
// [EN] Xxx create request
message CreateXxxRequest {
  string name = 1;                // 名称 | [EN] Name
  int32 status = 2;               // 状态 | [EN] Status
}

// XXX更新请求
// [EN] Xxx update request
message UpdateXxxRequest {
  string xxx_id = 1;              // XXX ID | [EN] Xxx ID
  string name = 2;                // 名称 | [EN] Name
  int32 status = 3;               // 状态 | [EN] Status
}

// XXX查询请求
// [EN] Xxx query request
message GetXxxRequest {
  string xxx_id = 1;              // XXX ID | [EN] Xxx ID
}

// XXX列表请求
// [EN] Xxx list request
message ListXxxRequest {
  int32 page = 1;                 // 页码 | [EN] Page number
  int32 size = 2;                 // 每页条数 | [EN] Page size
}

// XXX响应
// [EN] Xxx response
message XxxResponse {
  XxxData data = 1;               // 数据 | [EN] Data
}

// XXX列表响应
// [EN] Xxx list response
message ListXxxResponse {
  repeated XxxData items = 1;     // 列表 | [EN] Items
  common.Paging paging = 2;       // 分页 | [EN] Paging
}

// XXX数据
// [EN] Xxx data
message XxxData {
  string xxx_id = 1;              // XXX ID | [EN] Xxx ID
  string name = 2;                // 名称 | [EN] Name
  int32 status = 3;               // 状态 | [EN] Status
  google.protobuf.Timestamp created_at = 4;  // 创建时间 | [EN] Created at
  google.protobuf.Timestamp updated_at = 5;  // 更新时间 | [EN] Updated at
}

//===========================  XXX服务定义 | Xxx Service Definition  ==========================//

// XXX管理服务
// [EN] Xxx management service
service XxxService {
  // 创建XXX
  // [EN] Create xxx
  rpc CreateXxx(CreateXxxRequest) returns (XxxResponse) {
    option (google.api.http) = {
      post: "/v1/xxx"
      body: "*"
    };
    option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_operation) = {
      summary: "创建XXX | Create Xxx"
      description: "创建一个新的XXX | Create a new xxx"
      tags: "XxxManagement"
    };
  }

  // 获取XXX
  // [EN] Get xxx
  rpc GetXxx(GetXxxRequest) returns (XxxResponse) {
    option (google.api.http) = {
      get: "/v1/xxx/{xxx_id}"
    };
    option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_operation) = {
      summary: "获取XXX | Get Xxx"
      description: "根据ID获取XXX详情 | Get xxx details by ID"
      tags: "XxxManagement"
    };
  }

  // 更新XXX
  // [EN] Update xxx
  rpc UpdateXxx(UpdateXxxRequest) returns (XxxResponse) {
    option (google.api.http) = {
      put: "/v1/xxx/{xxx_id}"
      body: "*"
    };
    option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_operation) = {
      summary: "更新XXX | Update Xxx"
      description: "更新XXX信息 | Update xxx information"
      tags: "XxxManagement"
    };
  }

  // 列表查询XXX
  // [EN] List xxx
  rpc ListXxx(ListXxxRequest) returns (ListXxxResponse) {
    option (google.api.http) = {
      get: "/v1/xxx"
    };
    option (grpc.gateway.protoc_gen_openapiv2.options.openapiv2_operation) = {
      summary: "列表查询XXX | List Xxx"
      description: "分页查询XXX列表 | List xxx with pagination"
      tags: "XxxManagement"
    };
  }
}
```

### Step 2: Register Module in Generate Script (`scripts/generate-modular.bat`)

Find the `PROTO_MODULES` variable and add the new module name:
```batch
set "PROTO_MODULES=existing_module xxx"
```

Do the same in `scripts/generate-modular.sh`:
```bash
PROTO_MODULES=(existing_module xxx)
```

### Step 3: Add Gateway Aggregation Config (`resources/gateway-dev.yaml`)

Add the new service to the `aggregate.services` section:
```yaml
aggregate:
  services:
    - name: xxx-service
      host: localhost
      port: 9190  # the service's gRPC port
```

### Step 4: Add Swagger Embed (if `swagger_embed.go` exists)

Add embed directive and mapping for the new service's swagger file.

### Step 5: Generate Code

```bash
# Windows
scripts\generate-modular.bat

# Linux/Mac
./scripts/generate-modular.sh
```

## Adding New Enums (`proto/enums/enums.proto`)

```protobuf
// XXX类型
// [EN] Xxx type
enum XxxType {
  XXX_TYPE_UNSPECIFIED = 0;   // 未指定 | [EN] Unspecified
  XXX_TYPE_A = 1;             // 类型A | [EN] Type A
  XXX_TYPE_B = 2;             // 类型B | [EN] Type B
}
```

**Rules:**
- First value MUST be `XXX_UNSPECIFIED = 0`
- Use `SCREAMING_SNAKE_CASE` for enum values
- Use `XXXStatus`, `XXXType`, `XXXState` suffixes to avoid naming conflicts with RPC methods
- NEVER name an enum the same as an RPC method

## Adding Common Messages (`proto/common/common.proto`)

```protobuf
//===========================  XXX通用消息 | Xxx Common Messages  ==========================//

// XXX筛选条件
// [EN] Xxx filter criteria
message XxxFilter {
  string keyword = 1;           // 关键字 | [EN] Keyword
  int32 status = 2;             // 状态 | [EN] Status
}
```

## Naming Convention Rules (CRITICAL)

### Avoid Naming Conflicts

Enum names MUST differ from RPC method names and message type names:

```protobuf
// ❌ WRONG: enum and RPC method have the same name
enum PasswordResetStage { ... }
rpc PasswordResetStage(...) returns (...);

// ✅ CORRECT: different names
enum PasswordResetStatus { ... }
rpc CheckPasswordResetStage(...) returns (...);
```

### Naming Patterns

| Type | Pattern | Example |
|------|---------|---------|
| Enum | `XxxStatus`, `XxxType`, `XxxState` | `UserStatus`, `AccountType` |
| RPC Method | Verb + Noun | `GetUser`, `ListUsers`, `CreateUser` |
| Request Message | `{Method}Request` or `{Verb}{Noun}Request` | `CreateUserRequest` |
| Response Message | `{Method}Response` or `{Verb}{Noun}Response` | `CreateUserResponse` |
| Data Message | `{Noun}Data` | `UserData` |
| Proto Package | `{prefix}.api.{service}` | `apex.api.access_control` |
| Go Package | `{module}/pb/{service}` | `github.com/HitGameAI/apex-share-proto/pb/access_control` |
| Java Package | `com.{prefix}.api.{service}` | `com.apex.api.access_control` |

## HTTP Path Convention

| Operation | HTTP Method | Path Pattern |
|-----------|-------------|-------------|
| Create | POST | `/v1/{resource}` |
| Get | GET | `/v1/{resource}/{id}` |
| Update | PUT | `/v1/{resource}/{id}` |
| Delete | DELETE | `/v1/{resource}/{id}` |
| List | GET | `/v1/{resource}` |
| Custom Action | POST | `/v1/{resource}/{id}:{action}` |

## @inject_tag Usage

Use `@inject_tag` comments for custom JSON/GORM tags on response fields:
```protobuf
message XxxResponse {
  XxxData data = 1; // 数据 | [EN] Data @inject_tag: json:"data,omitempty"
}
```

## Important Rules

1. **ALWAYS** use bilingual comments (Chinese + `[EN]` English) - no exceptions
2. **ALWAYS** use `SCREAMING_SNAKE_CASE` for enum values with `_UNSPECIFIED = 0` first
3. **NEVER** name enums the same as RPC methods - use suffixes like `Status`, `Type`, `State`
4. **ALWAYS** add `openapiv2_swagger` option with bilingual info/tags for new service files
5. **ALWAYS** add `openapiv2_operation` option for each RPC with bilingual summary/description
6. **ALWAYS** import `proto/common/common.proto` for shared types (Paging, Error, StatusCode)
7. **ALWAYS** import `proto/enums/enums.proto` when using shared enums
8. **ALWAYS** register new modules in BOTH `.bat` and `.sh` generate scripts
9. **ALWAYS** add gateway config for new services in `resources/gateway-dev.yaml`
10. **ALWAYS** use section separators with bilingual titles between logical groups
11. **NEVER** edit files in `pb/` directory - they are auto-generated
12. **ALWAYS** run `go mod tidy` after generating code
