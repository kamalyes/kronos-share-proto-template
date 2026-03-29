# [[ .OrgPrefix ]] 服务共享 Protobuf 定义

> 本项目是 [[ .OrgPrefix ]] 微服务生态系统的核心，用于集中管理所有服务的 Protobuf 定义
> 通过这些定义，我们生成统一的 Go gRPC 代码、HTTP 网关以及 API 文档

## ✨ 功能特性

- **统一接口定义**：使用 Protobuf 作为接口定义语言 (IDL)，确保各服务间通信规范一致
- **gRPC & RESTful API**：同时支持 gRPC 高性能通信和基于 gRPC-Gateway 的 RESTful HTTP/JSON 接口
- **模块化结构**：按服务模块组织 `.proto` 文件，结构清晰
- **自动化代码生成**：提供一键式脚本，自动生成所有需要的 Go 代码、gRPC 网关和 Swagger 文档
- **结构体标签注入**：通过 `protoc-go-inject-tag` 自动为生成的 Go 结构体注入 `json`, `gorm` 等标签
- **依赖自动安装**：脚本会自动检测并安装所需的 `protoc` 插件

## 📂 项目结构

```bash
.
├── bootstrap/            # 服务启动引导程序
│   ├── main.go              # 主入口文件
│   ├── server.go            # 服务器配置
│   └── generate_handler.go  # API 代码生成处理器
├── deployments/          # 部署相关文件
├── pb/                   # 生成的 Go 代码存放目录 (按模块划分)
├── proto/                # Protobuf 源文件 (.proto)，按模块划分
│   ├── common/              # 公共消息定义
│   ├── enums/               # 枚举类型定义
│   └── [[ .ExampleServiceName | snake ]]/  # 示例服务定义
├── resources/            # 配置文件目录
│   └── gateway-dev.yaml     # 网关开发环境配置
├── scripts/              # 自动化脚本
│   ├── generate-modular.bat/.sh   # 核心代码生成脚本
│   ├── inject-tags.bat/.sh        # 标签注入脚本
│   ├── setup-dependencies.bat/.sh # 依赖设置脚本
│   ├── setup-protobuf-includes.bat/.sh # Protobuf Include 设置
│   └── run.bat/.sh                # 服务启动脚本
├── go.mod                # Go 模块定义
├── swagger_embed.go      # Swagger 文档嵌入
└── README.md             # 项目说明文档
```

## 🚀 快速开始

### 1. 环境要求

- **Go**: 版本 `1.22+` 或更高
- **Protobuf Compiler (`protoc`)**: [官方安装指南](https://grpc.io/docs/protoc-installation/)

> **提示**: 项目脚本会自动检测并尝试通过 `go install` 安装所需的 `protoc` 插件

### 2. 使用 kopy 生成项目

#### 交互模式

```bash
# 将[[ .ProjectName ]替换为你的真实项目名
kopy new git@github.com:kamalyes/kronos-share-proto-template.git -o ./[[ .ProjectName ]]
```

交互式问答示例：

```
❓ 组织名称（如 kamalyes，用于 Go 模块路径 github.com/{org}/{project}） [kamalyes]:
❓ 组织前缀（如 kronos，用于项目名 {prefix}-share-proto） [kronos]:
❓ 项目名称（如 kronos-share-proto） [kronos-share-proto]:
❓ Go 模块路径（如 github.com/kamalyes/kronos-share-proto） [github.com/kamalyes/kronos-share-proto]:
❓ Go 版本 [1.25]:
❓ 作者名称 [kamalyes]:
❓ 作者邮箱 [example@qq.com]:
❓ 网关配置前缀（如 gateway-kronos） [gateway-kronos]:
❓ HTTP 端口 [8080]:
❓ Java 包名（如 com.kronos.api） [com.kronos.api]:
❓ Proto 包名前缀（如 kronos.api） [kronos.api]:
❓ 示例服务名称（PascalCase，如 Health） [Health]:
```

#### 非交互模式

使用 `--var` 参数跳过交互式问答：

```bash
# 将[[ .ProjectName ]替换为你的真实项目名
kopy new git@github.com:kamalyes/kronos-share-proto-template.git -o ./[[ .ProjectName ]] \
  --var OrgName=kamalyes \
  --var OrgPrefix=kronos \
  --var ServiceType=payment \
  --var ServiceName=PaymentService \
  --var ModuleName=payment-service \
  --var ProjectName=kronos-payment-service \
  --var AuthorName=kamalyes \
  --var AuthorEmail=dev@example.com \
  --var GoVersion=1.25 \
  --var GatewayPrefix=gateway-payment \
  --var GRPCPort=9190 \
  --var HTTPPort=8190 \
  --var HealthPort=8191 \
  --var DBName=payment_service \
  --var CachePrefix=payment: \
  --var MetricsNamespace=payment \
  --var UseRedis=true \
  --var UseAuthInterceptor=true \
  --var UseSubscriber=false \
  --var GenerateExample=true \
  --var ExampleName=Order \
  --var ShareProtoModule=github.com/kamalyes/kronos-share-proto \
  --overwrite
```

#### 预览模式

使用 `--dry-run` 仅预览生成结果，不写入文件：

```bash
kopy new ./kronos-share-proto-template --dry-run --var OrgName=kamalyes --var OrgPrefix=kronos
```

### 3. 生成后步骤

```bash
cd [[ .ProjectName ]]

# 1. 安装依赖
go mod tidy

# 2. 下载 Google APIs 和 gRPC-Gateway 依赖
scripts\setup-dependencies.bat    # Windows
# bash scripts/setup-dependencies.sh  # Linux/Mac

# 3. 设置 Protobuf Include 路径
scripts\setup-protobuf-includes.bat   # Windows
# bash scripts/setup-protobuf-includes.sh  # Linux/Mac

# 4. 生成 Proto 代码
scripts\generate-modular.bat      # Windows
# bash scripts/generate-modular.sh    # Linux/Mac

# 5. 注入结构体标签（如 db/json 标签）
scripts\inject-tags.bat           # Windows
# bash scripts/inject-tags.sh         # Linux/Mac

# 6. 启动 Gateway 服务
scripts\run.bat                   # Windows
# bash scripts/run.sh                 # Linux/Mac
```

## 📋 模板变量

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `OrgName` | string | `kamalyes` | 组织名称，用于 Go 模块路径 `github.com/{org}/{project}` |
| `OrgPrefix` | string | `kronos` | 组织前缀，用于项目名 `{prefix}-share-proto` |
| `ProjectName` | string | `[[ .OrgPrefix ]]-share-proto` | 项目名称 |
| `ModuleName` | string | `github.com/[[ .OrgName ]]/[[ .OrgPrefix ]]-share-proto` | Go 模块路径 |
| `GoVersion` | select | `1.25` | Go 版本（1.22/1.23/1.24/1.25） |
| `AuthorName` | string | `kamalyes` | 作者名称 |
| `AuthorEmail` | string | `example@qq.com` | 作者邮箱 |
| `GatewayPrefix` | string | `gateway-[[ .OrgPrefix ]]` | 网关配置前缀 |
| `HTTPPort` | int | `8080` | HTTP 端口 |
| `JavaPackage` | string | `com.[[ .OrgPrefix ]].api` | Java 包名 |
| `ProtoPackage` | string | `[[ .OrgPrefix ]].api` | Proto 包名前缀 |
| `ExampleServiceName` | string | `Health` | 示例服务名称（PascalCase） |

## 🔄 文件重命名规则

| 模式 | 替换为 | 说明 |
|------|--------|------|
| `__project_name__` | `[[ .ProjectName ]]` | 项目名称 |
| `__org_prefix__` | `[[ .OrgPrefix ]]` | 组织前缀 |
| `__example_service__` | `[[ .ExampleServiceName \| snake ]]` | 示例服务名称（蛇形） |
| `__gateway_prefix__` | `[[ .GatewayPrefix ]]` | 网关配置前缀 |

## 🔤 命名转换函数

模板中的 `default` 字段和文件内容支持以下命名转换函数：

| 函数 | 说明 | 示例 |
|------|------|------|
| `snake` | 蛇形命名 | `HealthService` → `health_service` |
| `camel` | 驼峰命名 | `health_service` → `healthService` |
| `pascal` | 帕斯卡命名 | `health_service` → `HealthService` |
| `kebab` | 短横线命名 | `HealthService` → `health-service` |
| `lower` | 转小写 | `Hello` → `hello` |
| `upper` | 转大写 | `hello` → `HELLO` |

## 📝 如何添加或修改服务

1. 在 `proto/` 目录下创建或修改对应模块的 `.proto` 文件
2. 如果你创建了一个全新的模块，请在 `scripts/generate-modular.bat` (或 `.sh`) 文件中的 `PROTO_MODULES` 变量中添加你的模块名
3. 基础模块（无 gRPC 服务定义）添加到 `PROTO_BASE_MODULES`，服务模块添加到 `PROTO_MODULES`
4. 运行代码生成脚本来更新代码
5. 如需嵌入 Swagger 文档，在 `swagger_embed.go` 中添加对应的 `go:embed` 指令和映射
6. 如需网关聚合，在 `resources/gateway-dev.yaml` 的 `aggregate.services` 中注册新服务
7. 运行 `go mod tidy` 更新依赖

## ⚠️ 重要注意事项

### 命名冲突问题

在定义 `.proto` 文件时，需要特别注意**枚举类型**与 **RPC 方法/消息类型**之间的命名冲突：

```protobuf
// ❌ 不推荐：枚举与 RPC 方法同名
enum PasswordResetStage { ... }
rpc PasswordResetStage(...) returns (...);

// ✅ 推荐：使用不同的名称
enum PasswordResetStatus { ... }
rpc CheckPasswordResetStage(...) returns (...);
```

**命名规范建议**：

- 枚举类型：使用 `XXXStatus`、`XXXType`、`XXXState` 等后缀
- RPC 方法：使用动词开头，如 `Get`、`List`、`Create`、`Update`、`Delete`、`Check` 等
- 消息类型：使用 `XXXRequest`、`XXXResponse` 后缀

### 中英文双语注释规范

所有 `.proto` 文件必须使用中英文双语注释：

```protobuf
// 中文注释
// [EN] English comment
enum CommonStatus {
  COMMON_STATUS_UNSPECIFIED = 0;  // 未指定 | [EN] Unspecified
  COMMON_STATUS_NORMAL = 1;       // 正常 | [EN] Normal
}
```

- 文件级注释：中文在上，英文在下，使用 `[EN]` 前缀标记
- 行内注释：中文与英文在同一行，使用 `|` 分隔，英文以 `[EN]` 开头
- 分隔线：`//===========================  中文标题 | English Title  ==========================//`

## 导出前端 APIs

```bash
openapi-generator-cli generate -i ./[[ .OrgPrefix ]]-openapi-service.swagger.json -g typescript-axios -o ./generate --additional-properties modelPropertyNaming=original,stringEnums=true,withSeparateModelsAndApi=true,modelPackage=models,apiPackage=apis,supportsES6=true,enumPropertyNaming=UPPERCASE
```
