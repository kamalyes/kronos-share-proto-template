# kronos-share-proto-template - gRPC Contract Hub

**English** | [简体中文](./README.md)

> `kronos-share-proto-template` is the **single source of truth** for the Kronos platform's contracts: every gRPC service, message and enum is defined here, and protoc turns them into Go structs, gRPC client/server stubs, gRPC-Gateway reverse proxies and OpenAPI documents in one pass. Downstream services just `go get` this repository to obtain a strongly typed client instead of maintaining their own DTOs.

[![Go](https://img.shields.io/github/go-mod/go-version/kamalyes/kronos-share-proto-template)](https://golang.org/)
[![gRPC](https://img.shields.io/badge/gRPC-grpc--gateway%20v2-244c5a.svg?logo=grpc)](https://github.com/grpc-ecosystem/grpc-gateway)
[![Protobuf](https://img.shields.io/badge/protobuf-proto3-blue.svg)](https://protobuf.dev/)
[![Validation](https://img.shields.io/badge/validation-go--argus-7c3aed.svg)](https://github.com/kamalyes/go-argus)
[![CI](https://github.com/kamalyes/kronos-share-proto-template/actions/workflows/generate-pb.yml/badge.svg)](https://github.com/kamalyes/kronos-share-proto-template/actions/workflows/generate-pb.yml)
[![commit](https://img.shields.io/github/last-commit/kamalyes/kronos-share-proto-template)](https://github.com/kamalyes/kronos-share-proto-template/commits)
[![issues](https://img.shields.io/github/issues/kamalyes/kronos-share-proto-template)](https://github.com/kamalyes/kronos-share-proto-template/issues)
[![license](https://img.shields.io/github/license/kamalyes/kronos-share-proto-template)](./LICENSE)

## 📚 Navigation

- [🏠 Repository](https://github.com/kamalyes/kronos-share-proto-template)
- [⚙️ Code generation guide](./API_GENERATE.md)
- [📐 Proto directory conventions](./proto/CONVENTIONS.md)
- [🎨 Proto conventions, including the validation rule reference](./.trae/skills/kronos-proto-style/SKILL.md)
- [🔍 Convention audit](./.trae/skills/proto-lint-governance/SKILL.md) ｜ [🏗️ New module bootstrap](./.trae/skills/proto-new-module-bootstrap/SKILL.md) ｜ [🔗 Gateway consistency check](./.trae/skills/gateway-swagger-consistency-check/SKILL.md)
- [👷 CI/CD pipeline guide](./.github/workflows/GUIDE.md)
- [🌏 中文说明](./README.md)

## 🚀 Why a contract hub

### ⚡ Features

- **📐 Contract first**: proto is the single source of truth; Go structs, gRPC stubs, HTTP routes and OpenAPI docs all derive from it
- **🧩 Multi-module layout**: `common/` holds cross-module entities, `enums/` holds every enum, business modules split by bounded context
- **🔁 Full CRUD examples**: two example modules cover POST / GET / paged list / PUT / PATCH / DELETE / batch operations
- **🧬 Mixed module example**: `proto/tenant/` hosts two services in one module, mixing CRUD, action endpoints (retry-sync) and sub-resources (region-assignments)
- **🏷️ Validation lives in the contract**: `@inject_tag: validate:"..."` in field comments becomes a struct tag enforced at runtime by go-argus
- **🌐 Gateway docs aggregation**: generated swagger files are merged into one browsable site with per-audience entries
- **🤖 Automatic pb generation**: once proto changes land on `master`, CI regenerates and commits pb; on a PR it first verifies the two are in sync
- **🈶 Bilingual comment conventions**: every message, field and RPC reads "中文 | [EN] English", so mixed-language teams can both work
- **🔌 Ready-made validation interceptor**: wire `validation.UnaryServerInterceptor` once and every new RPC is covered automatically
- **🏷️ Versioned releases**: `release.yml` tags and publishes in one click, verifying the artifacts, attaching the aggregated OpenAPI document and flagging possibly breaking changes
- **🛰️ Downstream fan-out**: after a release it notifies Go services to upgrade their dependency and the TypeScript SDK repository to regenerate and publish to npm

### Why generated code is committed

Downstream services pin this repository by commit hash: without `pb/` in the tree they
would `go get` a module containing no Go code at all. Committing the output brings two
bonuses: contract changes show up as reviewable diffs in pull requests, and anyone can
clone and build without installing protoc.

## ⚠️ Important conventions

| Convention | Detail |
| --- | --- |
| Never hand-edit `pb/` | Every run overwrites it; change the proto instead |
| Generate before tidy | `pb/` starts empty, so `go mod tidy` fails first; see "First run" below |
| Register every new module | Add it to `PROTO_SERVICE_MODULES` in `scripts/generate-modular.sh|bat` or it is never generated |
| Tag required fields | A field without `@inject_tag` is simply unvalidated; the interceptor lets it through |
| Never reuse field numbers | Mark removed fields `reserved`, or old clients decode garbage |
| Extract shared types | Messages and enums used by two or more modules belong in `common/` and `enums/`, registered in the aggregation files |

## 🏗️ Project layout

```text
kronos-share-proto-template/
├── proto/                              # contract definitions (single source of truth)
│   ├── common/                         # messages reused across modules
│   │   ├── common.proto                # aggregation file (import public)
│   │   ├── pagination.proto            # Paging / Sorting
│   │   ├── result.proto                # Result / Error / BatchResult
│   │   ├── empty.proto                 # GeneralEmptyRequest / Response
│   │   ├── catalog.proto  # Product entity and nested messages
│   │   └── inventory.proto   # Warehouse entity
│   ├── enums/                          # every enum
│   │   ├── enums.proto                 # aggregation file
│   │   ├── status.proto                # CommonStatus / TrueOrFalse / SortDirection
│   │   ├── catalog.proto  # Product enums
│   │   └── inventory.proto   # Warehouse enums
│   ├── catalog/           # example module #1: full CRUD
│   ├── inventory/            # example module #2: full CRUD + cross-module reuse
│   ├── tenant/             # mixed module: two services + actions + sub-resources
│   │   ├── tenant_service.proto         # aggregate root
│   │   └── tenant_member_service.proto  # members (second service)
│   ├── openapi/                        # Bundle metadata (generates no Go code)
│   │   └── bundle.proto                # Title / security scheme / tag descriptions
│   └── CONVENTIONS.md                  # directory conventions
├── pb/                                 # generated Go code (committed, never edited)
├── docs/                               # Published artifacts and downstream templates
│   ├── openapi.swagger.yaml            # Aggregated OpenAPI document (committed, release asset)
│   └── downstream-proto-sync.yml        # Sync workflow for downstream Go services (copy it)
├── validation/                         # go-argus validation layer
│   ├── validator.go                    # validator, i18n, custom rules, enum validation
│   ├── interceptor.go                  # gRPC interceptor + IP allowlist
│   ├── validator_test.go               # unit tests for the layer
│   └── contract_test.go                # inject-tags contract test
├── scripts/                            # generation and environment setup (.sh / .bat)
├── resources/                          # gateway configuration per environment
├── bootstrap/                          # docs gateway launcher (deletable)
├── swagger_embed.go                    # swagger embedding (only built with -tags swagger)
└── .github/workflows/                  # pb generation + releases + CI/CD + PR notifications
```

## 📦 Quick start

### Requirements

| Tool | Version | Purpose |
| --- | --- | --- |
| Go | >= 1.25 | plugins and compilation |
| protoc | 24.3 | installed into `GOPATH/bin` by `scripts/setup-all.sh` |
| bash / cmd | — | Windows uses the matching `.bat` scripts |

### First run

One command, with the script enforcing the order:

```bash
bash scripts/init.sh                     # Linux / macOS
scripts\init.bat                         # Windows
```

It does four things in turn: install the pinned toolchain, generate pb/gateway/swagger and
inject struct tags, run `go mod tidy`, then `go build ./... && go test ./...`. It is
idempotent. Pass `--skip-setup` when the toolchain is already in place, or `--skip-test` to
skip the tests.

<details>
<summary>The equivalent manual steps, and why the order matters</summary>

```bash
bash scripts/setup-all.sh --no-pause     # install protoc + 5 plugins + googleapis
bash scripts/generate-modular.sh         # generate pb / gateway / swagger and inject tags
go mod tidy                              # pb/ now exists, so dependencies resolve
go build ./... && go test ./...
git add -A && git commit -m "chore: bootstrap share proto"
```

Running `go mod tidy` first fails: while `pb/` is empty, Go tries to resolve
`github.com/kamalyes/kronos-share-proto-template/pb/<module>` as a **remote module** (only the test files under
`validation/` import them) and reports a wall of `Repository not found`, which looks like a
repository or network problem when it merely means the code has not been generated yet.

</details>

### Run the docs gateway

```bash
go run ./bootstrap
# open http://127.0.0.1:18080/swagger
```

Projects that only need the artifacts can delete `bootstrap/`, `resources/` and
`swagger_embed*.go`.

## 🧩 The three example modules

| Module | Role | HTTP methods covered |
| --- | --- | --- |
| `proto/catalog/` | Full CRUD example including batch operations | POST / GET / GET list / PUT / PATCH / DELETE / POST batch |
| `proto/inventory/` | Second CRUD, shows reuse of common and enums | POST / GET / GET list / PUT / PATCH / DELETE |
| `proto/tenant/` | Mixed module: two services in one module sharing module-level entities and enums | POST / GET / GET list / PUT / DELETE + actions + sub-resources |

Endpoint shape of the `catalog` module:

```text
POST   /v1/catalog/products                      create
GET    /v1/catalog/products                      list (paging + sorting + filters)
GET    /v1/catalog/products/{id}                 get
PUT    /v1/catalog/products/{id}                 full update
PATCH  /v1/catalog/products/{id}/status          partial status update
DELETE /v1/catalog/products/{id}                 delete
POST   /v1/catalog/products/batch-delete         batch delete (per-item results)
```

Endpoint shape of the mixed module — the layout real projects converge on:

```text
POST   /v1/tenant/tenants                                   create the aggregate root
GET    /v1/tenant/tenants/{id}                              get
PUT    /v1/tenant/tenants/{id}                              update
DELETE /v1/tenant/tenants/{id}                              delete
POST   /v1/tenant/tenants/{id}/retry-sync                   action: retry downstream sync
POST   /v1/tenant/tenants/{id}/region-assignments           sub-resource: assign a region
PUT    /v1/tenant/tenants/{id}/region-assignments/{aid}     sub-resource: update
DELETE /v1/tenant/tenants/{id}/region-assignments/{aid}     sub-resource: remove
GET    /v1/tenant/tenants/{id}/members                      second service: member list
POST   /v1/tenant/tenants/{id}/members                      add member
DELETE /v1/tenant/tenants/{id}/members/{mid}                remove member
PUT    /v1/tenant/tenants/{id}/members/{mid}/roles          action: replace roles
POST   /v1/tenant/tenants/{id}/members/batch-invite         batch invite
```

To drop a module, delete its directory and also remove its entry from
`scripts/generate-modular.sh|bat`, its embed from `swagger_embed.go` and its aggregation
entry from `resources/kronos-share-proto-template-dev.yaml`.

## ⚙️ Code generation

```bash
bash scripts/generate-modular.sh
```

One command chains five steps:

```text
1. setup-all.sh          verify protoc and plugin versions (skipped when present)
2. protoc --go_out       pb/<module>/*.pb.go          Go structs
   protoc --go-grpc_out  pb/<module>/*_grpc.pb.go     gRPC client/server
3. protoc --grpc-gateway_out  pb/<module>/*.pb.gw.go  HTTP reverse proxy
4. protoc --openapiv2_out     proto/<module>/*.swagger.yaml  OpenAPI documents
5. inject-tags.sh        turn @inject_tag into struct tags (validate/json/swagger)
```

See [API_GENERATE.md](./API_GENERATE.md) for details.

## ✅ Validation layer (go-argus)

Field rules live in proto comments and are enforced at runtime by
[go-argus](https://github.com/kamalyes/go-argus) under [`validation/`](./validation) —
zero dependencies, a zero-reflection fast path and nine built-in locales.

```protobuf
string tenant_id = 1;   // 租户ID | [EN] Tenant ID @inject_tag: validate:"required,tenant_id"
string name = 2;        // 名称 | [EN] Name @inject_tag: validate:"required,min=2,max=64"
string icon_url = 3;    // 图标 | [EN] Icon URL @inject_tag: validate:"omitempty,url"
```

### Wiring it into a gRPC server

```go
import "github.com/kamalyes/kronos-share-proto-template/validation"

server := grpc.NewServer(
    grpc.UnaryInterceptor(validation.UnaryServerInterceptor(validation.InterceptorOptions{
        // Methods that skip validation, e.g. health checks
        // Methods that skip validation, shaped "/<package>.<module>.<Service>Service/<Method>"
        SkipMethods: []string{"/kronos.api.catalog.ProductService/ProductList"},
        // Restrict callers to the cluster; CIDR and wildcards supported, empty disables it
        AllowedPeerCIDRs: []string{"10.0.0.0/8", "192.168.1.*"},
    })),
)
```

A failure returns `codes.InvalidArgument` with field names and localized descriptions.
The locale is negotiated from the request's `accept-language`, defaulting to
`zh`.

### argus capabilities in use

| Capability | Where |
| --- | --- |
| Struct tag validation, nested structs included | `validation.Struct` / `StructCtx` |
| Localized error messages (nine locales) | `validation.Messages(err, locale)` |
| Registering extra locales | `registerExtraLocales` in `validation/validator.go` |
| Custom rules | the `tenant_id` rule in `validation/validator.go` |
| Generic enum validation | `validation.Enum(...)`, fed with generated enum values |
| Zero-reflection fast path | `validation.VarString` for single gateway parameters |
| JSON Schema validation | fallback for third-party callbacks with no proto contract, see the tests |
| IP allowlist / blocklist | `AllowedPeerCIDRs` on the interceptor |

## 🔌 Using it downstream

```bash
# Recommended: pin a released version
go get github.com/kamalyes/kronos-share-proto-template@v1.0.0

# While iterating: track the trunk
go get github.com/kamalyes/kronos-share-proto-template@master
```

Why a version rather than a commit hash: a hash says nothing about compatibility while
`v1.3.0 -> v2.0.0` does; Go's minimal version selection only understands tags, and once several
services share one contract, pseudo-versions produce "the same proto resolved to two versions"
conflicts.

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

After changing proto: wait for CI to regenerate and commit pb on `master`, then cut a
release (or `go get` the new commit while iterating). Referencing it before CI finishes pulls the
old pb.

## 📦 Releases and downstream fan-out

The point of a contract hub is "change it once, everything follows". `release.yml` wires that
path end to end, with nobody running `go get` by hand in each repository:

```text
  Run "Release Contract" in Actions (choose patch / minor / major)
            |
            |- Regenerate everything and verify: go build, go test, and a byte comparison
            |   against the committed pb (a difference blocks the release, so you can never
            |   publish from a state where the proto changed but pb was not regenerated)
            |
            |- Tag, create a GitHub Release and attach two assets:
            |     openapi.swagger.yaml          every service in one document
            |     openapi-specs-vX.Y.Z.tar.gz   the per-module documents
            |
            |- Release notes are composed automatically: the go get line, which proto files
            |   changed, and a screen for removed rpcs / messages / touched field numbers
            |
            `- Notify downstream (repository_dispatch)
                  |- Go services -> go get, tidy and go build, then push when it compiles
                  `- TS SDK      -> pull the bundle, regenerate, verify, changeset, publish
```

| Entry point | How | Result |
| --- | --- | --- |
| Manual release | Release Contract, choose `patch`/`minor`/`major` | Computes the next version, verifies, tags, publishes, notifies |
| Explicit version | Release Contract with `version=v2.0.0` | Publishes that version (`v2.0.0-rc.1` works too) |
| Verify only | Release Contract with `dry-run` | Runs the checks and prints what would be published |
| Local tag | `git tag v1.2.0 && git push origin v1.2.0` | Goes through the same verification and publishing |

### Configuring the fan-out

| Setting | Where | Purpose |
| --- | --- | --- |
| `DOWNSTREAM_REPOS` | Repository variable (or the `DownstreamRepos` template variable) | Go service repositories to notify, comma separated |
| `SDK_REPO` | Repository variable (or the `SdkRepo` template variable) | TypeScript SDK repository to notify |
| `OPS_CLI_APP_ID` / `OPS_CLI_APP_PRIVATE_KEY` | Repository secrets | GitHub App credentials for cross-repository dispatch |

`GITHUB_TOKEN` cannot trigger workflows in another repository, so the fan-out needs a GitHub App.
Without one the release still completes and only the notification step is skipped.

The downstream Go side already has its workflow written: copy
[docs/downstream-proto-sync.yml](./docs/downstream-proto-sync.yml) into the service repository as
`.github/workflows/proto-sync.yml`. The TypeScript side is generated from
[openapi-ts-sdk-template](https://github.com/kamalyes/openapi-ts-sdk-template), which ships
`sync-contract.yml`; point its `ProtoRepo` at this repository and the chain is complete.

### What the aggregated document is

`docs/openapi.swagger.yaml` is every business module merged into a single OpenAPI 2.0 document.
It is not the same thing as the docs gateway: the gateway needs a running service, while this is a
committed static file, so downstream gets the full contract without starting anything. Its title,
security scheme and tag descriptions live in
[proto/openapi/bundle.proto](./proto/openapi/bundle.proto) — register a new module's `tags` there,
or its group shows up in the bundle with a name and no description.

## 👷 CI/CD

| Workflow | Trigger | Purpose |
| --- | --- | --- |
| `generate-pb.yml` | `proto/**` changes (push / PR / manual) | Regenerate and commit pb; on a PR it only verifies and comments the diff |
| `release.yml` | Manual / pushing a `v*` tag | Verifies artifacts, tags, publishes the Release and bundle assets, notifies downstream |
| `pipeline.yml` | push to `dev` / tags / manual | Build, image, deploy, code quality |
| `pr-opened-notify.yml` | PR opened | Change summary comment and notification |
| `pr-merged-notify.yml` | PR merged | Merge notification |

Projects without CI can delete `.github/workflows/`. Notifications and quality checks
reuse the shared workflows from `kamalyes/deploy-pipeline` and need repository secrets — see
[.github/PIPELINE_CONFIG.md](./.github/PIPELINE_CONFIG.md).

## 🧰 Scripts

| Script | Purpose |
| --- | --- |
| `scripts/setup-all.sh` | Prepare everything: protoc + plugins + googleapis/grpc-gateway |
| `scripts/setup-dependencies.sh` | Install only protoc and the Go plugins |
| `scripts/setup-protobuf-includes.sh` | Prepare only the protobuf include files |
| `scripts/generate-modular.sh` | Generate pb / gateway / swagger per module and inject tags |
| `scripts/inject-tags.sh` | Run struct tag injection on its own |
| `scripts/prepare-pb-output.sh` | Clean and prepare the pb output directory |
| `scripts/build-linux.sh` | Cross-compile the docs gateway binary |

Every script has a `.bat` twin that behaves identically on Windows.

## ❓ FAQ

**`go mod tidy` cannot find `github.com/kamalyes/kronos-share-proto-template/pb/...`**
`pb/` is still empty. Run `bash scripts/generate-modular.sh` first, then `go mod tidy`.

**My new endpoints are missing from the docs site**
Three places need the module: the list in `scripts/generate-modular.sh|bat`, the embed in
`swagger_embed.go`, and `aggregate.services` in `resources/kronos-share-proto-template-dev.yaml`.

**Validation does not fire**
Check that the proto field comment carries `@inject_tag: validate:"..."`, then check the
struct really got the tag (`grep validate pb/catalog/*.pb.go`).
`validation/contract_test.go` exists to guard exactly this chain.

**Can I drop the bootstrap docs gateway?**
Yes. Delete `bootstrap/`, `resources/`, `swagger_embed*.go` and the `go-config` /
`go-rpc-gateway` requirements from go.mod, and the repository becomes pure contracts.

**The `.bat` scripts show mojibake on Windows**
They already call `chcp 65001`; use a UTF-8 terminal such as Windows Terminal or
PowerShell 7.

## License

Copyright (c) 2026 by kamalyes, All Rights Reserved.
