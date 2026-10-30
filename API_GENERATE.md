# 代码生成说明 | Code generation guide

本文件讲清楚 `scripts/generate-modular.sh` 到底做了什么、产物落在哪、出错怎么查。
[EN] What `scripts/generate-modular.sh` actually does, where the output lands, and how to debug it

## 一条命令 | One command

```bash
bash scripts/generate-modular.sh          # Linux / macOS
scripts\generate-modular.bat              # Windows
```

## 六个阶段 | Six stages

```text
┌─ 1. 环境确认 | Toolchain check ───────────────────────────────────────────┐
│ setup-all.sh 校验 protoc 24.3 与 5 个插件；已装则跳过，版本不符则重装      │
└──────────────────────────────────────────────────────────────────────────┘
                              ↓
┌─ 2. Go 结构体与 gRPC | Go structs and gRPC ──────────────────────────────┐
│ protoc --go_out       → pb/<module>/*.pb.go                              │
│ protoc --go-grpc_out  → pb/<module>/*_grpc.pb.go                         │
│ 顺序：先 enums，再 common，最后业务模块（被依赖的先生成）                   │
└──────────────────────────────────────────────────────────────────────────┘
                              ↓
┌─ 3. HTTP 反向代理 | HTTP reverse proxy ──────────────────────────────────┐
│ protoc --grpc-gateway_out → pb/<module>/*.pb.gw.go                       │
│ 只对含 google.api.http 注解的文件生成                                      │
└──────────────────────────────────────────────────────────────────────────┘
                              ↓
┌─ 4. OpenAPI 文档 | OpenAPI documents ────────────────────────────────────┐
│ protoc --openapiv2_out → proto/<module>/*.swagger.yaml                   │
│ 输出 yaml 而非 json，json_names_for_fields=false 保持 snake_case 字段名    │
└──────────────────────────────────────────────────────────────────────────┘
                              ↓
┌─ 5. 结构体标签注入 | Struct tag injection ───────────────────────────────┐
│ inject-tags.sh 把 proto 注释里的 @inject_tag 写进 pb/*.pb.go 的 struct tag │
│ 同时清理 swagger 里的 @inject_tag 污染并把约束注入 swagger                 │
└──────────────────────────────────────────────────────────────────────────┘
                              ↓
┌─ 6. 聚合文档 | Aggregated document ──────────────────────────────────────┐
│ allow_merge 把全部业务 proto 合成一份 docs/openapi.swagger.yaml           │
│ 元信息（标题、鉴权声明、分组说明）来自 proto/openapi/bundle.proto          │
│ 这份文件是下游多语言 SDK 与 API 门户的输入，发版时作为 release 资产上传     │
└──────────────────────────────────────────────────────────────────────────┘
```

## 产物清单 | Output

| 路径 \| Path | 内容 \| Content | 是否入库 \| Committed |
| --- | --- | --- |
| `pb/<module>/*.pb.go` | 消息结构体、枚举 | ✅ |
| `pb/<module>/*_grpc.pb.go` | gRPC 客户端与服务端接口 | ✅ |
| `pb/<module>/*.pb.gw.go` | gRPC-Gateway HTTP 代理 | ✅ |
| `proto/<module>/*.swagger.yaml` | 按模块拆分的 OpenAPI 2.0 文档 | ✅ |
| `docs/openapi.swagger.yaml` | 全部模块合并的聚合文档 | ✅ |

全部入库的原因：下游按 commit hash 引用本仓库，不入库就是一个没有 Go 代码的空模块。
[EN] Everything is committed because downstream pins this repo by commit hash; without the
output it would be a module with no Go code at all

## @inject_tag 是怎么生效的 | How @inject_tag works

```protobuf
// proto 里这样写 | written in proto
string tenant_id = 1;   // 租户ID | [EN] Tenant ID @inject_tag: validate:"required,tenant_id"
```

```go
// 第 2 步生成出来（还没有 tag）| after step 2, no tag yet
TenantId string `protobuf:"bytes,1,opt,name=tenant_id,json=tenantId,proto3" json:"tenant_id,omitempty"`

// 第 5 步注入之后 | after step 5
TenantId string `protobuf:"..." json:"tenant_id,omitempty" validate:"required,tenant_id"`
```

运行时由 `validation/` 下的 go-argus 读取这些 tag字段名取 `json` tag，所以校验错误里
的字段名与 HTTP 请求体一致，可以直接回给前端。

[EN] At runtime the go-argus layer under `validation/` reads these tags. Field names come
from the `json` tag, so error messages match the HTTP body and can be returned as-is

## 新增模块 | Adding a module

```bash
# 单 service 的模块：复制示例模块一 | single-service module: copy example module #1
cp -r proto/catalog proto/<module>
mv proto/<module>/product_service.proto proto/<module>/<service>_service.proto

# 多 service 的模块：复制混合模块 | multi-service module: copy the mixed module
cp -r proto/tenant proto/<module>

# 然后改 go_package / java_package / package、服务名、消息与 RPC
```

然后**必须**登记三处，漏一处就会「写了但没生效」：

[EN] Then register it in three places; missing any one means "written but never active":

| # | 位置 \| Where | 漏掉的后果 \| If missed |
| --- | --- | --- |
| 1 | `scripts/generate-modular.sh` 与 `.bat` 的 `PROTO_SERVICE_MODULES` | 完全不会被生成，CI 也不报错 |
| 2 | `swagger_embed.go` 的 `//go:embed` 与 `SwaggerFiles` | 文档站拿不到这个服务的 swagger |
| 3 | `resources/kronos-share-proto-template-dev.yaml` 的 `aggregate.services` | 网关不聚合，接口在文档里不可见 |
| 4 | `proto/openapi/bundle.proto` 的 `tags` | 聚合文档里这个分组只有名字没有描述 |

## 常见故障 | Troubleshooting

| 现象 \| Symptom | 原因与处理 \| Cause and fix |
| --- | --- |
| `protoc: command not found` | 先跑 `bash scripts/setup-all.sh --no-pause` |
| `google/api/annotations.proto: File not found` | googleapis 未克隆，重跑 setup-all.sh |
| 生成了 pb 但没有 `.pb.gw.go` | 该 proto 没有 `google.api.http` 注解 |
| 生成了 pb 但没有 swagger | 该 proto 没有 `openapiv2_swagger` 或 `google.api.http` |
| struct 没有 `validate` tag | proto 注释里 `@inject_tag` 写错位置（必须在双语注释之后空一格）|
| `go mod tidy` 找不到 `pb/...` | 还没生成，先 generate 再 tidy |
| CI 自动提交了 pb 改动 | 正常：`generate-pb.yml` 在 `master` 上会把生成结果补齐 |
| 没生成 `docs/openapi.swagger.yaml` | `proto/openapi/bundle.proto` 被删了，或所有 proto 都没有 HTTP 注解 |
| 聚合文档每次生成都有巨量 diff | 把输出改成了 json。后处理工具对 json 会过一遍 Go map，字段顺序随机，必须用 yaml |
| 发版被「生成物未同步」拦住 | 本地跑一次 `bash scripts/generate-modular.sh` 并提交结果 |

## 环境准备脚本 | Setup scripts

| 脚本 \| Script | 作用 \| Purpose |
| --- | --- |
| `setup-all.sh` | 串起下面两个，一键就位 |
| `setup-dependencies.sh` | 安装固定版本 protoc 与 5 个 Go 插件到 `GOPATH/bin` |
| `setup-protobuf-includes.sh` | 准备 protobuf include 与 googleapis / grpc-gateway 的 proto |

版本固定在脚本里（`REQUIRED_PROTOC_VERSION`），不跟随系统 protoc：
生成结果必须可复现，不同机器装不同版本会让 pb 的 diff 永远对不上。

[EN] Versions are pinned in the scripts rather than following the system protoc: output
must be reproducible, and mixed versions make the pb diff never settle
