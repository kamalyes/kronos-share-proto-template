# share-proto-template - 通用 gRPC 协议中心工程模板

> 这是一个 [kopy](https://github.com/kamalyes/kopy) 模板：`kopy new` 一条命令生成一个**开箱即跑**的 gRPC/Protobuf 协议中心仓库 —— 多模块 proto 组织、protoc 全套生成链路（pb / gRPC / gateway / OpenAPI）、`@inject_tag` 校验注入、[go-argus](https://github.com/kamalyes/go-argus) 运行时校验层、swagger 文档聚合网关、pb 自动生成 CI，以及一整套双语 proto 规范。
>
> **完全通用**：组织名、项目名、Go 模块路径、proto/Java 包名、示例模块名、网关前缀、分支名、复用工作流仓库、校验语言全部是模板变量，没有任何写死的组织或业务信息。
>
> [EN] A [kopy](https://github.com/kamalyes/kopy) template that scaffolds a ready-to-run gRPC/Protobuf contract hub: multi-module protos, the full protoc pipeline, `@inject_tag` validation injection, a go-argus runtime validation layer, a swagger aggregation gateway, pb auto-generation CI and a complete bilingual proto convention set. Everything organization-specific is a template variable.

[![kopy](https://img.shields.io/badge/kopy-template-7c3aed.svg)](https://github.com/kamalyes/kopy)
[![Go](https://img.shields.io/badge/Go-%3E%3D1.22-00ADD8.svg?logo=go)](https://golang.org/)
[![protoc](https://img.shields.io/badge/protoc-24.3-blue.svg)](https://protobuf.dev/)
[![grpc-gateway](https://img.shields.io/badge/grpc--gateway-v2-244c5a.svg)](https://github.com/grpc-ecosystem/grpc-gateway)
[![go-argus](https://img.shields.io/badge/validation-go--argus-7c3aed.svg)](https://github.com/kamalyes/go-argus)
[![license](https://img.shields.io/badge/license-Apache--2.0-green.svg)](./LICENSE)

## 📚 文档导航 | Navigation

- [🧩 kopy 脚手架](https://github.com/kamalyes/kopy)
- [✅ go-argus 校验库](https://github.com/kamalyes/go-argus)
- [📦 生成项目的中文说明](./readme.tpl)（渲染后成为 `README.md`）
- [🌍 生成项目的英文说明](./readme-en.tpl)（渲染后成为 `README.en.md`）
- [⚙️ 生成链路说明](./api-generate.tpl)（渲染后成为 `API_GENERATE.md`）
- [🎨 Proto 风格指南](./.vscode/skills/__org_prefix__-proto-style/SKILL.md)
- [✅ 校验规则速查](./.trae/skills/proto-conventions/SKILL.md)

## 🚀 为什么需要这个模板 | Why

协议中心的难点从来不是写 proto，而是它周边那一圈：protoc 要装哪个版本、插件怎么配、
模块按什么顺序生成、struct tag 怎么注入、swagger 怎么聚合、pb 由谁生成并提交、
新人怎么知道注释该写成什么样每个团队自己摸一遍，就是每个团队都踩一遍同样的坑。

[EN] The hard part of a contract hub is never writing proto; it is everything around it:
which protoc version, how the plugins are wired, in what order modules generate, how
struct tags get injected, how swagger is aggregated, who regenerates and commits pb, and
how a newcomer learns what a comment should look like

### ⚡ 模板提供什么 | What you get

- **🧱 三个示例模块**: 两个单 service 的完整 CRUD（POST/GET/列表/PUT/PATCH/DELETE/批量）、一个混合模块（一模块两个 service + 动作型 + 子资源）
- **⚙️ 完整生成链路**: 16 个脚本（.sh/.bat 双版本），protoc 24.3 与 5 个插件版本固定可复现
- **🏷️ 校验写进契约**: proto 注释里的 `@inject_tag: validate:"..."` 注入成 struct tag，运行时由 go-argus 执行
- **🔌 现成的校验拦截器**: gRPC 一元拦截器 + i18n 错误消息 + IP 白名单，新增 RPC 自动覆盖
- **🧪 守链路的契约测试**: 专门验证「@inject_tag 真的变成了 struct tag」，这条链路断了不会有任何报错
- **🌐 文档聚合网关**: 生成的 swagger 自动聚合成文档站，支持按受众拆分入口
- **🤖 pb 自动生成 CI**: proto 变更合并后自动生成并提交，PR 阶段先验证同步并把 diff 评论到 PR
- **📐 双语规范三件套**: 风格指南 + 校验规则速查 + 目录规范，全部中英双语
- **🈶 中英双语注释**: 每个文件都有 banner 与逐段注释，解释的是「为什么这么做」

## 📦 快速开始 | Quick start

### 环境要求 | Requirements

```bash
go install github.com/kamalyes/kopy@latest     # 模板渲染 | render the template
# protoc 与插件由生成项目的 scripts/setup-all.sh 自动安装，无需手动准备
```

### 生成项目 | Generate

```bash
# 交互式：逐项确认 22 个变量 | interactive
kopy new https://github.com/kamalyes/kronos-share-proto-template -o ./my-share-proto

# 非交互：用 --var 跳过全部提问 | non-interactive
kopy new https://github.com/kamalyes/kronos-share-proto-template -o ./demo-share-proto \
  --var OrgName=kamalyes \
  --var OrgPrefix=demo \
  --var ProjectName=demo-share-proto \
  --var ModuleName=github.com/kamalyes/demo-share-proto \
  --var GoVersion=1.25 \
  --var AuthorName=kamalyes \
  --var AuthorEmail=501893067@qq.com \
  --var BaseBranch=master \
  --var ProtoPackage=demo.api \
  --var JavaPackage=com.kamalyes.demo.api \
  --var ExampleModule=catalog \
  --var ExampleService=Product \
  --var SecondModule=inventory \
  --var SecondService=Warehouse \
  --var MixedModule=tenant \
  --var MixedService=Tenant \
  --var GatewayPrefix=gateway-demo \
  --var HTTPPort=18080 \
  --var DefaultLocale=zh \
  --var PipelineRepo=kamalyes/deploy-pipeline \
  --var DownstreamRepos=demo-user-service,demo-order-service \
  --var SdkRepo=kamalyes/demo-api-sdk

# 预览不写盘 | preview without writing
kopy new ./kronos-share-proto-template -o /tmp/preview --dry-run

# 查看全部变量与默认值 | list variables and defaults
kopy list ./kronos-share-proto-template
```

> ⚠️ 必须用完整的 Git 地址。kopy README 里写的 `@owner/repo` 简写在当前版本**并未实现**：
> `source.isGitURL` 只认 `https://` / `http://` / `git@` / `git://` 或 `.git` 结尾，
> 传 `@kamalyes/xxx` 会被当成本地路径，报「访问模板源路径失败」。
> 带分支就用 `https://github.com/owner/repo#branch`。
>
> [EN] Use the full Git URL. The `@owner/repo` shorthand documented in kopy's README is not
> implemented in the current release: `source.isGitURL` only accepts `https://`, `http://`,
> `git@`, `git://` or a `.git` suffix, so `@kamalyes/xxx` is treated as a local path and fails
> with "访问模板源路径失败". Append `#branch` to the URL to pick a branch.


### 初始化生成出来的项目 | Bootstrap the output

```bash
cd demo-share-proto
bash scripts/setup-all.sh --no-pause     # 装 protoc 24.3 + 5 个插件 + googleapis
bash scripts/generate-modular.sh         # 生成 pb / gateway / swagger 并注入 tag
go mod tidy                              # 必须在 generate 之后
go build ./... && go test ./...
go run ./bootstrap                        # 文档站 http://127.0.0.1:18080/swagger
```

> ⚠️ 顺序不能换：`pb/` 为空时 `go mod tidy` 解析不到 `<module>/pb/...`
> 这不是模板缺陷，而是协议仓库的固有顺序（CI 也是这么跑的）。
>
> [EN] The order is fixed: while `pb/` is empty, `go mod tidy` cannot resolve `<module>/pb/...`.
> Not a template defect but the inherent order of a contract repository, and CI does the same.

> ⚠️ 当前版本的 kopy 还**不会执行** `kopy.yaml` 里的 `hooks`，所以上面这几步要手动跑。
>
> [EN] The current kopy release does not execute the `hooks` block yet, so run these manually.

## 🔧 模板变量 | Template variables

| 变量 \| Variable | 类型 | 默认值 \| Default | 说明 \| Description |
| --- | --- | --- | --- |
| `OrgName` | string | `kamalyes` | GitHub 组织或用户名，用于模块路径与仓库地址 |
| `OrgPrefix` | string | `demo` | 项目前缀，决定项目名、proto 包名、swagger 标题 |
| `ProjectName` | string | `<prefix>-share-proto` | 仓库名 / 目录名 |
| `ModuleName` | string | `github.com/<org>/<project>` | Go 模块路径，决定所有 `go_package` |
| `GoVersion` | select | `1.25` | 写入 go.mod |
| `AuthorName` | string | `kamalyes` | 文件头 banner 与版权行 |
| `AuthorEmail` | string | `example@qq.com` | 文件头 banner |
| `BaseBranch` | select | `master` | CI 触发分支、pb 自动生成的目标分支 |
| `ProtoPackage` | string | `<prefix>.api` | proto 包名前缀，模块名会追加在后面 |
| `JavaPackage` | string | `com.<org>.<prefix>.api` | Java 包名前缀 |
| `ExampleModule` | string | `catalog` | 示例模块一的目录名 |
| `ExampleService` | string | `Product` | 示例模块一的服务名 |
| `SecondModule` | string | `inventory` | 示例模块二的目录名 |
| `SecondService` | string | `Warehouse` | 示例模块二的服务名 |
| `MixedModule` | string | `tenant` | 混合模块的目录名（一模块多 service）|
| `MixedService` | string | `Tenant` | 混合模块的聚合根服务名，成员服务自动叫 `XxxMember` |
| `GatewayPrefix` | string | `gateway-<prefix>` | 网关配置文件前缀 |
| `HTTPPort` | int | `18080` | 文档网关端口 |
| `DefaultLocale` | select | `zh` | 校验错误默认语言（go-argus 内置九种）|
| `PipelineRepo` | string | `kamalyes/deploy-pipeline` | 复用型工作流仓库 |
| `DownstreamRepos` | string | 空 | 发版后要通知的下游 Go 服务仓库，逗号分隔；可被仓库变量 `DOWNSTREAM_REPOS` 覆盖 |
| `SdkRepo` | string | 空 | 发版后要通知的 TypeScript SDK 仓库；可被仓库变量 `SDK_REPO` 覆盖 |

内置变量 `Year` 由 kopy 注入，用于版权行。

## 🏗️ 模板结构 | Template layout

```text
kronos-share-proto-template/
├── kopy.yaml                       # 模板定义：变量、忽略、重命名 | template definition
├── README.md                       # 模板自述（不进入生成项目）| template docs, never copied
├── readme.tpl                      # → 生成项目的 README.md（中文）
├── readme-en.tpl                   # → 生成项目的 README.en.md（英文）
├── api-generate.tpl                # → 生成项目的 API_GENERATE.md
├── proto/
│   ├── CONVENTIONS.md              # 目录规范 | directory conventions
│   ├── common/                     # 公共消息（含两个示例模块的实体）
│   ├── enums/                      # 枚举（status + 两个示例模块）
│   ├── __module__/                 # 示例模块一：完整 CRUD + 批量
│   ├── __module2__/                # 示例模块二：完整 CRUD + 跨模块复用
│   ├── __module3__/                # 混合模块：两个 service + 动作型 + 子资源
│   └── openapi/bundle.proto        # 聚合文档的元信息：标题 / 鉴权 / 分组说明
├── docs/downstream-proto-sync.yml  # 下游 Go 服务的协议同步工作流（给生成项目复制去用）
├── validation/                     # go-argus 校验层 + 拦截器 + 契约测试
├── scripts/                        # 16 个生成/环境脚本（.sh + .bat）
├── resources/__gateway_prefix__-dev.yaml  # 网关与 swagger 聚合配置
├── bootstrap/                      # 文档网关启动器
├── swagger_embed.go / _stub.go     # swagger 嵌入（build tag 分流）
├── go.mod                          # 依赖：grpc / protobuf / gateway / argus / go-config
├── .github/
│   ├── workflows/*.yml.tpl         # 工作流模板：pb 自动生成、协议发版、CI/CD、PR 通知
│   │                               # 带 .tpl 是为了不让 GitHub 解析模板仓库自己的工作流
│   ├── workflows/GUIDE.md          # 流水线详解
│   ├── PIPELINE_CONFIG.md          # 需要配置的 vars / secrets
│   ├── copilot-instructions.md     # commit message 规范
│   └── skills/                     # 3 份 AI 协作规范
├── .trae/                          # proto 规范 + commit 规范
└── .vscode/                        # 编辑器配置 + proto 风格指南 SKILL
```

## 🧠 模板渲染机制 | How rendering works

### ⚠️ 定界符是 `<% %>`，不是 kopy 默认的 `[[ ]]`

bash 的条件测试语法本身就是双方括号（`if [[ -z "$x" ]]`），与 kopy 默认定界符冲突，
整个 `scripts/` 目录会渲染失败换成 `<% %>` 后，生产项目里的 shell 脚本可以逐字节
同步进来，不需要为了模板引擎把 `[[ ]]` 改写成 `[ ]`（改写会悄悄改变语义，比如 `=~` 和 `&&`）。

[EN] bash's own test syntax uses double brackets, which collides with kopy's default
delimiters and breaks the whole scripts/ directory. With `<% %>`, shell scripts from a real
project sync byte for byte instead of being rewritten into single-bracket form, which would
silently change semantics.

### 其它要知道的 | Other things to know

| 机制 \| Mechanism | 行为 \| Behaviour | 影响 \| Consequence |
| --- | --- | --- |
| 渲染范围 | 文件**内容和路径**都会渲染 | 任何字面量 `<%` 都会被当成模板语法 |
| 变量类型 | 全部是字符串，`bool` 得到 `"true"` / `"false"` | 条件必须写 `eq .X "true"` |
| 执行顺序 | **先 rename 再 ignore** | 要忽略某文件，得忽略它 rename **之后**的路径 |
| ignore 匹配 | 精确 / 前缀 `dir/` / 后缀 `*.ext` / 路径段 | 不带斜杠的模式会连子目录同名文件一起忽略 |
| hooks | 当前版本**不执行** | 初始化步骤只能写进文档让人手动跑 |
| 内置变量 | 只有 `Year` | 其余都要显式定义成 question |

### 三份文档模板的落位 | Three doc templates

模板自己的 README 和生成项目的 README 都叫 `README.md`，而 ignore 作用在 rename
**之后**的路径，两者在匹配时是同一个字符串解决办法是有序的 rename 加一条带斜杠的
ignore（带斜杠只做前缀匹配，所以只命中根目录那一份）：

[EN] The template's own README and the generated one are both `README.md`, and ignore
rules see post-rename paths, so the two are indistinguishable. Ordered renames plus a
trailing-slash ignore (prefix match, hitting only the root one) solve it:

```yaml
rename:
  - pattern: "README.md"         # 1. 模板自述 → 忽略标记
    value: "__kopy_template_doc__"
  - pattern: "readme-en.tpl"     # 2. 英文说明 → README.en.md
    value: "README.en.md"
  - pattern: "readme.tpl"        # 3. 中文说明 → README.md
    value: "README.md"
  - pattern: "api-generate.tpl"  # 4. 生成说明 → API_GENERATE.md
    value: "API_GENERATE.md"
ignore:
  - "__kopy_template_doc__/"     # 带斜杠：只忽略根目录那一份
```

顺序颠倒会导致生成项目没有 README，或者模板说明被当成项目 README
`proto/CONVENTIONS.md`、`.github/workflows/GUIDE.md` 这些子目录文档刻意不叫 README.md，
就是为了避开第 1 条规则的子串匹配。

[EN] Swapping the order drops the README or ships the template docs as one. Sub-directory
docs are deliberately not named README.md to dodge rule 1's substring match.

## 🔄 从生产项目同步脚本 | Syncing scripts from a real project

`scripts/` 下的 16 个脚本与 `.github/`、`.vscode/`、`.trae/` 的规范文件都是从生产仓库
同步来的，项目专属的部分只有这么几处，升级时照着替换即可：

[EN] The 16 scripts and the convention files are synced from a production repository. Only
these spots are project-specific, so an upgrade is a copy plus a few substitutions:

| 文件 \| File | 要模板化的内容 \| What to template |
| --- | --- |
| `scripts/generate-modular.sh` / `.bat` | `GO_MODULE` 与 `PROTO_SERVICE_MODULES` |
| `scripts/build-linux.sh` | `BINARY_NAME` 与文件头 banner |
| `.github/workflows/*.yml` | 分支名、复用工作流仓库、secret 名 |
| `.vscode/settings.json` | 版权行里的作者名 |
| 全部文件 | 组织名、项目名、Go 模块路径、proto/Java 包名 |

## 🔗 三个仓库怎么串起来 | How the three repositories connect

这个模板生成的是链路的**源头**：proto 改一次，Go 服务和 TypeScript SDK 自动跟上。

[EN] This template generates the **head** of a chain: change a proto once and both the Go services
and the TypeScript SDK follow automatically.

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ 本模板 → 协议中心仓库                                                          │
│   proto 是唯一真相源，产出：                                                   │
│     pb/**                      Go 结构体与 gRPC stub（入库）                   │
│     proto/**/*.swagger.yaml    按模块拆分的 OpenAPI 文档（入库）                │
│     docs/openapi.swagger.yaml  全部模块合并的聚合文档（入库）                   │
│   release.yml 发版：校验 → 打 tag → Release 附带聚合文档 → 通知下游             │
└────────────────┬────────────────────────────────────┬────────────────────────┘
                 │ go get <module>@vX.Y.Z             │ repository_dispatch
                 ▼                                    ▼
┌────────────────────────────────┐   ┌──────────────────────────────────────────┐
│ Go 业务服务仓库                  │   │ openapi-ts-sdk-template → SDK 仓库        │
│  用 pb 里的 stub 实现 gRPC      │   │  sync-contract.yml 收到通知后：            │
│  proto-sync.yml 自动升级依赖     │   │   拉聚合文档 → pnpm generate → 验证        │
│  （模板见 docs/ 目录）           │   │   → 写 changeset → 发 npm                 │
└────────────────────────────────┘   └──────────────────────────────────────────┘
```

| 角色 \| Role | 仓库 \| Repository | 它负责什么 \| Responsibility |
| --- | --- | --- |
| 协议中心 | 本模板生成 | proto 真相源、pb 代码、聚合 OpenAPI 文档、版本与发版 |
| Go 业务服务 | 各自的仓库 | 实现 gRPC 服务；`docs/downstream-proto-sync.yml` 负责自动升级协议依赖 |
| TypeScript SDK | [openapi-ts-sdk-template](https://github.com/kamalyes/openapi-ts-sdk-template) 生成 | 把聚合文档变成类型完整的 npm 包 |
| 生成器 | [openapi-generator-ts-cli](https://github.com/kamalyes/openapi-generator-ts-cli) | 被 SDK 仓库调用，把 OpenAPI 文档变成 TypeScript 源码 |
| 流水线公共件 | [deploy-pipeline](https://github.com/kamalyes/deploy-pipeline) | 复用型工作流与 composite action（通知、代码质量、协议依赖升级）|

### 接线清单 | Wiring checklist

| 步骤 \| Step | 在哪做 \| Where |
| --- | --- |
| 1. 生成协议中心 | `kopy new .../kronos-share-proto-template`，填 `SdkRepo` 与 `DownstreamRepos` |
| 2. 生成 SDK 仓库 | `kopy new .../openapi-ts-sdk-template`，填 `ProtoRepo` 为协议中心仓库 |
| 3. 下游 Go 服务 | 复制生成项目里的 `docs/downstream-proto-sync.yml` 到服务仓库的 `.github/workflows/` |
| 4. 配 GitHub App | 各仓库配 `OPS_CLI_APP_ID` / `OPS_CLI_APP_PRIVATE_KEY`（跨仓库通知必需）|
| 5. 验证 | 协议中心跑一次 Release Contract，看下游是否自动起了对应工作流 |

> 💡 `DOWNSTREAM_REPOS` / `SDK_REPO` 也可以在仓库 Variables 里配，优先级高于模板变量，
> 这样后续新增一个服务不需要重新渲染模板。
>
> [EN] `DOWNSTREAM_REPOS` / `SDK_REPO` can also be set as repository variables, which take
> precedence over the template values, so adding a service later needs no re-render.

## 🛠️ 二次定制 | Customizing

| 想改什么 \| Goal | 改哪里 \| Where |
| --- | --- |
| 加一个交互变量 | `kopy.yaml` 的 `questions`，再在文件里用 `<% .NewVar %>` |
| 加/删示例模块 | 单 service 复制 `proto/__module__/`，多 service 复制 `proto/__module3__/`，并同步 `scripts/generate-modular.*`、`swagger_embed.go`、`resources/*.yaml` |
| 换 protoc 版本 | `scripts/common.sh|bat` 的 `REQUIRED_PROTOC_VERSION` 与 setup 脚本 |
| 换校验库 | `validation/` 整个替换（proto 侧的 `@inject_tag` 语法不用动）|
| 不要文档网关 | 删 `bootstrap/`、`resources/`、`swagger_embed*.go` 与对应依赖 |
| 不要 CI | 删 `.github/workflows/` |
| 不要 AI 规范文件 | 删 `.trae/`、`.github/skills/`、`.vscode/skills/` |

## ✅ 已验证 | Verified

模板的每条链路都在本机实跑验证过（变量取 `catalog/Product` + `inventory/Warehouse`）：

[EN] Every path was executed locally with the default example variables:

| 环节 \| Step | 结果 \| Result |
| --- | --- |
| `kopy new` | 69 文件渲染，`__module__` / `__module3__` 等占位符全部落位，无残留定界符 |
| `scripts/setup-all.sh` | protoc 24.3 + 5 个插件 + googleapis 安装成功 |
| `scripts/generate-modular.sh` | 24 个 pb.go + 4 个 gateway 代理 + 4 份 swagger 全部生成 |
| `inject-tags` | `validate:"required,tenant_id"` 等 13 条规则注入进 struct tag |
| `go mod tidy && go build ./...` | 通过 |
| `go vet ./...` | 通过 |
| `go test ./...` | 19 个用例通过（含 6 个契约测试：必填、嵌套、自定义规则、批量上限、同模块两个 service）|
| `go build -tags swagger ./...` | 通过（swagger 嵌入真实生成的 yaml）|
| `go run ./bootstrap` | 文档网关启动成功，`GET /swagger` 返回 200 |
| 聚合 OpenAPI 文档 | 16 条路径 + 56 个 definition 合并成一份 `docs/openapi.swagger.yaml`，4 个分组描述齐全，`@inject_tag` 零残留 |
| 生成幂等性 | 连续两次 `generate-modular.sh` 后 `git diff` 为空（发版流水线的同步校验依赖这一点）|
| `release.yml` 版本推算 | patch/minor/major/显式版本/prerelease/首次发布六种情况实跑，非法版本号被拦住 |
| `release.yml` 发布说明 | 实跑生成：引用方式、变更的 proto、删掉的 rpc 与改动的字段号都被正确识别 |
| `release.yml` 资产 | 实跑产出 `openapi.swagger.yaml`（info.version 已对齐 tag）与按模块拆分的 tar |
| 全链路到 TS SDK | 用生成出来的聚合文档喂 `openapi-ts-sdk-template`：27 文件生成，typecheck 通过，16 个用例通过，tsup 构建出 ESM/CJS/d.ts |

## 许可证 | License

Copyright (c) 2026 by kamalyes, All Rights Reserved.
