# kronos-share-proto-template - gRPC 协议中心

**简体中文** | [English](./README.en.md)

> `kronos-share-proto-template` 是 Kronos 体系的**协议唯一真相源**：所有服务的 gRPC 接口、消息、枚举都在这里定义，由 protoc 一次性产出 Go 结构体、gRPC 客户端/服务端、gRPC-Gateway 反向代理和 OpenAPI 文档下游服务只需 `go get` 本仓库即可拿到强类型客户端，不需要各自维护一份 DTO

[![Go](https://img.shields.io/github/go-mod/go-version/kamalyes/kronos-share-proto-template)](https://golang.org/)
[![gRPC](https://img.shields.io/badge/gRPC-grpc--gateway%20v2-244c5a.svg?logo=grpc)](https://github.com/grpc-ecosystem/grpc-gateway)
[![Protobuf](https://img.shields.io/badge/protobuf-proto3-blue.svg)](https://protobuf.dev/)
[![Validation](https://img.shields.io/badge/validation-go--argus-7c3aed.svg)](https://github.com/kamalyes/go-argus)
[![CI](https://github.com/kamalyes/kronos-share-proto-template/actions/workflows/generate-pb.yml/badge.svg)](https://github.com/kamalyes/kronos-share-proto-template/actions/workflows/generate-pb.yml)
[![commit](https://img.shields.io/github/last-commit/kamalyes/kronos-share-proto-template)](https://github.com/kamalyes/kronos-share-proto-template/commits)
[![issues](https://img.shields.io/github/issues/kamalyes/kronos-share-proto-template)](https://github.com/kamalyes/kronos-share-proto-template/issues)
[![license](https://img.shields.io/github/license/kamalyes/kronos-share-proto-template)](./LICENSE)

## 📚 文档导航

- [🏠 仓库主页](https://github.com/kamalyes/kronos-share-proto-template)
- [⚙️ 代码生成说明](./API_GENERATE.md)
- [📐 Proto 目录规范](./proto/CONVENTIONS.md)
- [🎨 Proto 规范（含校验规则速查）](./.trae/skills/kronos-proto-style/SKILL.md)
- [🔍 规范巡检](./.trae/skills/proto-lint-governance/SKILL.md) ｜ [🏗️ 新模块落地](./.trae/skills/proto-new-module-bootstrap/SKILL.md) ｜ [🔗 网关一致性核对](./.trae/skills/gateway-swagger-consistency-check/SKILL.md)
- [👷 CI/CD 流水线说明](./.github/workflows/GUIDE.md)
- [🌍 English README](./README.en.md)

## 🚀 为什么要有协议中心

### ⚡ 核心特性

- **📐 契约先行**: proto 是唯一真相源，Go 结构体、gRPC stub、HTTP 路由、OpenAPI 文档全部由它推导
- **🧩 多模块组织**: `common/` 放跨模块实体，`enums/` 放全部枚举，业务模块按限界上下文拆分
- **🔁 全套 CRUD 示例**: 两个示例模块覆盖 POST / GET / 列表分页 / PUT / PATCH / DELETE / 批量操作
- **🧬 混合模块示例**: `proto/tenant/` 一个模块下两个 service，接口混着 CRUD、动作型（retry-sync）与子资源（region-assignments）
- **🏷️ 校验写在契约里**: 字段注释里的 `@inject_tag: validate:"..."` 会被注入成 struct tag，由 go-argus 在运行时执行
- **🌐 网关文档聚合**: 生成的 swagger 自动聚合成一个可浏览的文档站，支持按受众拆分入口
- **🤖 pb 自动生成**: proto 变更合并到 `master` 后，CI 自动重新生成 pb 并提交；PR 阶段会先验证是否同步
- **🈶 双语注释规范**: 所有消息、字段、RPC 都是「中文 | [EN] English」，多语言团队都能读
- **🔌 开箱即用的校验拦截器**: `validation.UnaryServerInterceptor` 一行接入，新增 RPC 自动被覆盖
- **🏷️ 版本化发版**: `release.yml` 一键打 tag 发版，自动校验生成物、产出聚合 OpenAPI 资产、识别不兼容变更
- **🛰️ 下游自动联动**: 发版后主动通知下游 Go 服务升级依赖、通知 TS SDK 仓库重新生成并发 npm

### 为什么生成代码要提交进仓库

下游服务是直接引用本仓库这个 Go module 的：如果 `pb/` 不入库，它们 `go get` 到的就是一个
没有任何 Go 代码的空模块。把生成物提交进来，还有两个额外好处：接口变更会以可
review 的 diff 出现在 PR 里；任何人 clone 下来不装 protoc 也能编译。

## ⚠️ 重要约定

| 约定 | 说明 |
| --- | --- |
| `pb/` 禁止手改 | 每次生成会整体覆盖，改动必然丢失；要改就改 proto |
| 先 generate 再 tidy | 刚初始化时 `pb/` 为空，`go mod tidy` 会失败，顺序见下方「首次初始化」 |
| 新模块必须登记 | 加到 `scripts/generate-modular.sh|bat` 的 `PROTO_SERVICE_MODULES`，否则不会被生成 |
| 必填字段必须标 `@inject_tag` | 漏标就等于没有校验，拦截器会放它过去 |
| 字段编号不可复用 | 删字段要用 `reserved`，复用编号会让老客户端解析出错数据 |
| 公共类型必须抽取 | 两个以上模块用到的消息/枚举放 `common/` 与 `enums/` 并注册到聚合文件 |

## 🏗️ 项目结构

```text
kronos-share-proto-template/
├── proto/                              # 协议定义（唯一真相源）
│   ├── common/                         # 跨模块复用消息
│   │   ├── common.proto                # 聚合文件（import public）
│   │   ├── pagination.proto            # Paging / Sorting
│   │   ├── result.proto                # Result / Error / BatchResult
│   │   ├── empty.proto                 # GeneralEmptyRequest / Response
│   │   ├── catalog.proto  # Product 实体与嵌套消息
│   │   └── inventory.proto   # Warehouse 实体
│   ├── enums/                          # 全部枚举
│   │   ├── enums.proto                 # 聚合文件
│   │   ├── status.proto                # CommonStatus / TrueOrFalse / SortDirection
│   │   ├── catalog.proto  # Product 相关枚举
│   │   └── inventory.proto   # Warehouse 相关枚举
│   ├── catalog/           # 示例模块一：完整 CRUD
│   ├── inventory/            # 示例模块二：完整 CRUD + 跨模块复用
│   ├── tenant/             # 混合模块：两个 service + 动作型 + 子资源
│   │   ├── tenant_service.proto         # 聚合根
│   │   └── tenant_member_service.proto  # 成员（同模块第二个 service）
│   ├── openapi/                        # 聚合文档的元信息（不生成 Go 代码）
│   │   └── bundle.proto                # 标题 / 鉴权声明 / 分组说明
│   └── CONVENTIONS.md                  # 目录规范
├── pb/                                 # 生成的 Go 代码（入库，禁止手改）
├── docs/                               # 对外产物与下游模板
│   ├── openapi.swagger.yaml            # 聚合 OpenAPI 文档（入库，发版资产）
│   └── downstream-proto-sync.yml        # 下游 Go 服务的同步工作流（复制去用）
├── validation/                         # go-argus 校验层
│   ├── validator.go                    # 校验器、i18n、自定义规则、枚举校验
│   ├── interceptor.go                  # gRPC 拦截器 + IP 白名单
│   ├── validator_test.go               # 校验层单测
│   └── contract_test.go                # inject-tags 契约测试
├── scripts/                            # 代码生成与环境准备（.sh / .bat 双版本）
├── resources/                          # 网关配置（按环境拆分）
├── bootstrap/                          # 文档网关启动器（可删）
├── swagger_embed.go                    # swagger 嵌入（-tags swagger 才编译）
└── .github/workflows/                  # pb 自动生成 + 发版 + CI/CD + PR 通知
```

## 📦 快速开始

### 环境要求

| 工具 | 版本 | 说明 |
| --- | --- | --- |
| Go | >= 1.25 | 生成插件与编译 |
| protoc | 24.3 | 由 `scripts/setup-all.sh` 自动安装到 `GOPATH/bin` |
| make / bash | — | Windows 用对应的 `.bat` 脚本 |

### 首次初始化

一条命令打通，顺序由脚本保证：

```bash
bash scripts/init.sh                     # Linux / macOS
scripts\init.bat                         # Windows
```

它依次做四件事：装固定版本工具链 → 生成 pb/gateway/swagger 并注入 tag →
`go mod tidy` → `go build ./... && go test ./...`。幂等，重复执行无副作用。
工具链已就位可加 `--skip-setup`，想跳过测试可加 `--skip-test`。

<details>
<summary>等价的手工步骤，以及为什么顺序不能换</summary>

```bash
bash scripts/setup-all.sh --no-pause     # 安装 protoc + 5 个插件 + googleapis
bash scripts/generate-modular.sh         # 生成 pb / gateway / swagger 并注入 tag
go mod tidy                              # 此时 pb/ 已存在，依赖才能解析
go build ./... && go test ./...
git add -A && git commit -m "chore: bootstrap share proto"
```

先 `go mod tidy` 会失败：`pb/` 为空时 Go 把 `github.com/kamalyes/kronos-share-proto-template/pb/<module>` 当成
**远程模块**去拉（只有 `validation/` 的测试文件 import 它们），于是报一串
`Repository not found`，看起来像仓库或网络问题，其实只是还没生成。

</details>

### 启动文档网关

```bash
go run ./bootstrap
# 打开 http://127.0.0.1:18080/swagger
```

只需要协议产物、不需要文档站的项目，可以直接删掉 `bootstrap/`、`resources/` 和
`swagger_embed*.go`

## 🧩 三个示例模块

| 模块 | 定位 | 覆盖的 HTTP 方法 |
| --- | --- | --- |
| `proto/catalog/` | 完整 CRUD 示例，含批量操作 | POST / GET / GET列表 / PUT / PATCH / DELETE / POST批量 |
| `proto/inventory/` | 第二个 CRUD，演示跨模块复用 common 与 enums | POST / GET / GET列表 / PUT / PATCH / DELETE |
| `proto/tenant/` | 混合模块：一个模块两个 service，共用模块级实体与枚举 | POST / GET / GET列表 / PUT / DELETE + 动作型 + 子资源 |

`catalog` 模块的接口形态：

```text
POST   /v1/catalog/products                      创建
GET    /v1/catalog/products                      列表（分页 + 排序 + 过滤）
GET    /v1/catalog/products/{id}                 详情
PUT    /v1/catalog/products/{id}                 整体更新
PATCH  /v1/catalog/products/{id}/status          局部更新状态
DELETE /v1/catalog/products/{id}                 删除
POST   /v1/catalog/products/batch-delete         批量删除（逐条返回结果）
```

混合模块的接口形态（真实项目最常见的那种）：

```text
POST   /v1/tenant/tenants                                   创建聚合根
GET    /v1/tenant/tenants/{id}                              详情
PUT    /v1/tenant/tenants/{id}                              更新
DELETE /v1/tenant/tenants/{id}                              删除
POST   /v1/tenant/tenants/{id}/retry-sync                   动作型：重试下游同步
POST   /v1/tenant/tenants/{id}/region-assignments           子资源：分配地区
PUT    /v1/tenant/tenants/{id}/region-assignments/{aid}     子资源：更新分配
DELETE /v1/tenant/tenants/{id}/region-assignments/{aid}     子资源：移除分配
GET    /v1/tenant/tenants/{id}/members                      第二个 service：成员列表
POST   /v1/tenant/tenants/{id}/members                      添加成员
DELETE /v1/tenant/tenants/{id}/members/{mid}                移除成员
PUT    /v1/tenant/tenants/{id}/members/{mid}/roles          动作型：覆盖角色
POST   /v1/tenant/tenants/{id}/members/batch-invite         批量邀请
```

不需要的模块直接删目录，并同步删掉 `scripts/generate-modular.sh|bat` 里的登记、
`swagger_embed.go` 里的 embed、`resources/kronos-share-proto-template-dev.yaml` 里的聚合条目。

## ⚙️ 代码生成

```bash
bash scripts/generate-modular.sh
```

一条命令里串了五件事：

```text
1. setup-all.sh          确认 protoc 与插件版本（已装则跳过）
2. protoc --go_out       pb/<module>/*.pb.go          Go 结构体
   protoc --go-grpc_out  pb/<module>/*_grpc.pb.go     gRPC 客户端/服务端
3. protoc --grpc-gateway_out  pb/<module>/*.pb.gw.go  HTTP 反向代理
4. protoc --openapiv2_out     proto/<module>/*.swagger.yaml  OpenAPI 文档
5. inject-tags.sh        把 @inject_tag 注入成 struct tag（validate/json/swagger）
```

详细说明见 [API_GENERATE.md](./API_GENERATE.md)

## ✅ 校验层（go-argus）

字段校验规则写在 proto 注释里，运行时由 [`validation/`](./validation) 下的
[go-argus](https://github.com/kamalyes/go-argus) 执行 —— 零依赖、零反射快路径、内置九种语言。

```protobuf
string tenant_id = 1;   // 租户ID | [EN] Tenant ID @inject_tag: validate:"required,tenant_id"
string name = 2;        // 名称 | [EN] Name @inject_tag: validate:"required,min=2,max=64"
string icon_url = 3;    // 图标 | [EN] Icon URL @inject_tag: validate:"omitempty,url"
```

### 接入 gRPC 服务

```go
import "github.com/kamalyes/kronos-share-proto-template/validation"

server := grpc.NewServer(
    grpc.UnaryInterceptor(validation.UnaryServerInterceptor(validation.InterceptorOptions{
        // 免校验的方法（如健康检查）
        // 免校验方法，格式 "/<包名>.<模块>.<服务>Service/<方法>"，典型是健康检查
        SkipMethods: []string{"/kronos.api.catalog.ProductService/ProductList"},
        // 只允许集群内调用，支持 CIDR 与通配符；留空不限制
        AllowedPeerCIDRs: []string{"10.0.0.0/8", "192.168.1.*"},
    })),
)
```

校验失败自动返回 `codes.InvalidArgument`，消息里带字段名与本地化描述；
语言按请求的 `accept-language` 协商，默认 `zh`

### 用到的 argus 能力

| 能力 | 用在哪 |
| --- | --- |
| struct tag 校验（含嵌套结构体） | `validation.Struct` / `StructCtx` |
| 国际化错误消息（内置九种语言） | `validation.Messages(err, locale)` |
| 注册额外语言 | `validation/validator.go` 的 `registerExtraLocales` |
| 自定义规则 | `validation/validator.go` 的 `tenant_id` 规则 |
| 泛型枚举校验 | `validation.Enum(...)`，直接传生成的枚举值 |
| 零反射快路径 | `validation.VarString`，网关层校验单个字符串 |
| JSON Schema 校验 | 第三方回调没有 proto 契约时的兜底，见单测 |
| IP 白名单 / 黑名单 | 拦截器的 `AllowedPeerCIDRs` |

## 🔌 下游服务怎么用

```bash
# 推荐：引用一个发布版本 | Recommended: pin a released version
go get github.com/kamalyes/kronos-share-proto-template@v1.0.0

# 开发期联调：引用主干最新 commit | While iterating: track the trunk
go get github.com/kamalyes/kronos-share-proto-template@master
```

为什么推荐版本而不是 commit hash：hash 读不出兼容性，`v1.3.0 → v2.0.0` 一眼就知道要改代码；
Go 的版本选择（MVS）只认 tag，多个服务共享同一协议时，pseudo-version 会出现
「同一个 proto 被解析成两个版本」的冲突。

```go
import (
    "github.com/kamalyes/kronos-share-proto-template/pb/catalog"
    "github.com/kamalyes/kronos-share-proto-template/pb/common"
    "github.com/kamalyes/kronos-share-proto-template/pb/enums"
)

client := catalog.NewProductServiceClient(conn)
resp, err := client.ProductList(ctx, &catalog.ProductListRequest{
    PageRequest: &common.Paging{Page: 1, Size: 20},
    Status:      enums.CommonStatus_COMMON_STATUS_NORMAL,
})
```

proto 改了之后：等 CI 在 `master` 上自动生成并提交 pb，再在下游 `go get` 新 hash
抢在 CI 之前引用会拿到旧的 pb

## 📦 发版与下游联动

协议中心的价值在于「一处改，处处跟上」这条链路由 `release.yml` 串起来，全程不需要人
手动去各个仓库 `go get`：

```text
  在 Actions 里跑 Release Contract（选 patch / minor / major）
            │
            ├─ 重新生成全部产物并校验：go build、go test、与仓库里的 pb 逐字节比对
            │   （有差异直接拦住：不允许从「proto 改了但 pb 没重新生成」的状态发版）
            │
            ├─ 打 tag、建 GitHub Release，附带两个资产：
            │     openapi.swagger.yaml          全部服务的聚合文档
            │     openapi-specs-vX.Y.Z.tar.gz   按模块拆分的文档
            │
            ├─ 发布说明自动写上：go get 引用方式、变更的 proto 文件、
            │   以及「删掉的 rpc / message / 改过的字段号」这类可能的不兼容变更
            │
            └─ 通知下游（repository_dispatch）
                  ├─ Go 服务仓库  → 自动 go get 新版本、tidy、go build 验证后推送
                  └─ TS SDK 仓库  → 拉聚合文档重新生成、验证、写 changeset、发 npm
```

| 入口 | 怎么触发 | 结果 |
| --- | --- | --- |
| Actions 手动发版 | Release Contract，选 `patch`/`minor`/`major` | 自动算下一个版本号、校验、打 tag、发布、通知 |
| 指定版本号 | Release Contract，填 `version=v2.0.0` | 用这个版本号发布（支持 `v2.0.0-rc.1`）|
| 只看不发 | Release Contract，勾 `dry-run` | 只跑校验并打印将要发布的内容 |
| 本地打 tag | `git tag v1.2.0 && git push origin v1.2.0` | 推上去同样走完整校验与发布 |

### 配置下游通知

| 配置项 | 填在哪 | 作用 |
| --- | --- | --- |
| `DOWNSTREAM_REPOS` | 仓库变量（或模板变量 `DownstreamRepos`）| 要通知的 Go 服务仓库，逗号分隔 |
| `SDK_REPO` | 仓库变量（或模板变量 `SdkRepo`）| 要通知的 TypeScript SDK 仓库 |
| `OPS_CLI_APP_ID` / `OPS_CLI_APP_PRIVATE_KEY` | 仓库 Secret | 跨仓库通知用的 GitHub App 凭证 |

`GITHUB_TOKEN` 不能跨仓库触发工作流，所以通知下游必须有一个 GitHub App 凭证；
没配的话发版本身照常完成，只是跳过通知这一步。

下游 Go 服务那一侧要放的工作流已经写好了，复制
[docs/downstream-proto-sync.yml](./docs/downstream-proto-sync.yml) 到服务仓库的
`.github/workflows/proto-sync.yml` 即可。TypeScript SDK 那一侧用
[openapi-ts-sdk-template](https://github.com/kamalyes/openapi-ts-sdk-template)
生成，它自带 `sync-contract.yml`，把本仓库填进它的 `ProtoRepo` 就接上了。

### 聚合文档是什么

`docs/openapi.swagger.yaml` 是全部业务模块合并后的单份 OpenAPI 2.0 文档，和网关文档站
不是一回事：文档站要跑着服务才能看，这份是入库的静态文件，下游不起任何服务就能拿到完整
契约。它的标题、鉴权声明和分组描述写在
[proto/openapi/bundle.proto](./proto/openapi/bundle.proto) 里，新增模块记得在那里补一条
`tags`，否则聚合文档里这个分组只有名字没有说明。

## 👷 CI/CD

| 工作流 | 触发 | 作用 |
| --- | --- | --- |
| `generate-pb.yml` | `proto/**` 变更（push / PR / 手动）| 自动重新生成 pb 并提交；PR 阶段只验证并把 diff 评论到 PR |
| `release.yml` | 手动 / 推送 `v*` tag | 校验生成物、打 tag、发 Release 与聚合文档资产、通知下游 |
| `pipeline.yml` | push `dev` / tag / 手动 | 构建、镜像、部署、代码质量检查 |
| `pr-opened-notify.yml` | PR 开启 | 变更摘要评论 + 通知 |
| `pr-merged-notify.yml` | PR 合并 | 合并通知 |

不需要 CI 的项目删掉 `.github/workflows/` 即可通知与质量检查复用
`kamalyes/deploy-pipeline` 的公共工作流，需要配置仓库 Secret（见
[.github/PIPELINE_CONFIG.md](./.github/PIPELINE_CONFIG.md)）。

## 🧰 脚本速览

| 脚本 | 作用 |
| --- | --- |
| `scripts/setup-all.sh` | 一键准备环境：protoc + 插件 + googleapis/grpc-gateway |
| `scripts/setup-dependencies.sh` | 只装 protoc 与 Go 插件 |
| `scripts/setup-protobuf-includes.sh` | 只准备 protobuf include 文件 |
| `scripts/generate-modular.sh` | 分模块生成 pb / gateway / swagger 并注入 tag |
| `scripts/inject-tags.sh` | 单独执行 struct tag 注入 |
| `scripts/prepare-pb-output.sh` | 清理与准备 pb 输出目录 |
| `scripts/build-linux.sh` | 交叉编译文档网关二进制 |

每个脚本都有同名 `.bat` 版本，Windows 下行为一致。

## ❓ 常见问题

**`go mod tidy` 报找不到 `github.com/kamalyes/kronos-share-proto-template/pb/...`？**
`pb/` 还是空的先跑 `bash scripts/generate-modular.sh`，再 `go mod tidy`

**新加的接口在文档站里看不到？**
三个地方要登记：`scripts/generate-modular.sh|bat` 的模块列表、`swagger_embed.go` 的 embed、
`resources/kronos-share-proto-template-dev.yaml` 的 `aggregate.services`

**校验没生效？**
先确认 proto 字段注释里有 `@inject_tag: validate:"..."`，再确认 `pb/` 里的结构体
确实带上了 tag（`grep validate pb/catalog/*.pb.go`）
`validation/contract_test.go` 就是专门守这条链路的。

**能不能不用 bootstrap 的文档网关？**
可以删掉 `bootstrap/`、`resources/`、`swagger_embed*.go` 和 go.mod 里的
`go-config` / `go-rpc-gateway` 依赖，仓库就只剩纯协议产物。

**Windows 下脚本报编码错误？**
`.bat` 脚本已经 `chcp 65001`，请用 UTF-8 的终端（Windows Terminal / PowerShell 7）。

## 许可证

Copyright (c) 2026 by kamalyes, All Rights Reserved.
