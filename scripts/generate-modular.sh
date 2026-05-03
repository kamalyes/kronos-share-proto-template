#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

GO_MODULE="<% .ModuleName %>"
PROTO_BASE_MODULES=(enums)
# 业务模块列表：新增模块后必须加到这里，否则不会被生成。
# Service module list: a new module must be registered here or it will not be generated
PROTO_SERVICE_MODULES=(common <% .ExampleModule %> <% .SecondModule %> <% .MixedModule %><% if eq .IncludeKeyModule "true" %> key<% end %>)
PROTO_ALL_MODULES=("${PROTO_BASE_MODULES[@]}" "${PROTO_SERVICE_MODULES[@]}")

project_root

log_info "生成 Protobuf 文件 (分模块结构)..."

require_script "setup-all.sh"
bash "$SCRIPT_DIR/setup-all.sh" --no-pause
ensure_go
ensure_gopath
ensure_go_bin_on_path
ensure_protoc

if [[ ! -d proto ]]; then
    log_error "proto 目录不存在，请先创建 proto 目录并添加 .proto 文件"
    exit 1
fi

require_script "prepare-pb-output.sh"
bash "$SCRIPT_DIR/prepare-pb-output.sh" --input pb

PROTOC_PATH="$GO_BIN_DIR/protoc"
PROTOC_ROOT="$(cd "$(dirname "$PROTOC_PATH")/.." && pwd)"
PROTOC_INCLUDE="$PROTOC_ROOT/include"
if [[ ! -d "$PROTOC_INCLUDE/google/protobuf" ]]; then
    # include 文件在 setup-all.sh 内下载到 $GO_BIN_DIR/include，使用该路径
    PROTOC_INCLUDE="$GO_BIN_DIR/include"
fi

INCLUDE_ARGS=(-I"$PROTOC_INCLUDE" -I.)
if [[ -d "$GOPATH/src/github.com/googleapis" ]]; then
    INCLUDE_ARGS+=(-I"$GOPATH/src/github.com/googleapis")
    log_success "使用 GOPATH 中的 googleapis"
else
    log_warn "GOPATH 中未找到 googleapis"
fi

if [[ -d "$GOPATH/src/github.com/grpc-ecosystem/grpc-gateway" ]]; then
    INCLUDE_ARGS+=(-I"$GOPATH/src/github.com/grpc-ecosystem/grpc-gateway")
    log_success "使用 GOPATH 中的 grpc-gateway"
else
    log_warn "GOPATH 中未找到 grpc-gateway"
fi

find_tool() {
    local tool="$1"
    local path
    path="$(command -v "$tool" 2>/dev/null || true)"
    if [[ -z "$path" ]]; then
        log_error "未找到 $tool，请先运行 scripts/setup-all.sh --no-pause"
        exit 1
    fi
    if [[ ! -f "$path" && -f "$path.exe" ]]; then
        path="$path.exe"
    fi
    echo "$path"
}

protoc_plugin_path() {
    local path="$1"
    if command -v cygpath >/dev/null 2>&1 && [[ "$(basename "$PROTOC_PATH")" == protoc.exe ]]; then
        cygpath -w "$path"
        return 0
    fi
    echo "$path"
}

PROTOC_GEN_GO="$(protoc_plugin_path "$(find_tool protoc-gen-go)")"
PROTOC_GEN_GO_GRPC="$(protoc_plugin_path "$(find_tool protoc-gen-go-grpc)")"
PROTOC_GEN_GRPC_GATEWAY="$(protoc_plugin_path "$(find_tool protoc-gen-grpc-gateway)")"
PROTOC_GEN_OPENAPIV2="$(protoc_plugin_path "$(find_tool protoc-gen-openapiv2)")"

GO_ARGS=(--plugin="protoc-gen-go=$PROTOC_GEN_GO" --plugin="protoc-gen-go-grpc=$PROTOC_GEN_GO_GRPC" --go_out=. --go_opt=module="$GO_MODULE" --go-grpc_out=. --go-grpc_opt=module="$GO_MODULE")
GATEWAY_ARGS=(--plugin="protoc-gen-grpc-gateway=$PROTOC_GEN_GRPC_GATEWAY" --grpc-gateway_out=. --grpc-gateway_opt=module="$GO_MODULE" --grpc-gateway_opt=generate_unbound_methods=true)
OPENAPI_ARGS=(--plugin="protoc-gen-openapiv2=$PROTOC_GEN_OPENAPIV2" --openapiv2_out=. --openapiv2_opt=logtostderr=true --openapiv2_opt=json_names_for_fields=false --openapiv2_opt=output_format=yaml)

# 聚合 OpenAPI 文档的参数 | Arguments for the aggregated OpenAPI document
#
# allow_merge 把命令行上的全部 proto 合成一份文档，merge_file_name 决定文件名
#
# 必须是 yaml 而不是 json：后处理工具 protoc-go-inject-tag 对 yaml 做的是文本编辑，
# 对 json 则是「反序列化成 Go map 再写回」，而 Go 的 map 遍历顺序是随机的，于是同样
# 的 proto 每次生成出来的 json 字段顺序都不同。入库后每次跑生成都会出现几百行的无意义
# diff，发版流水线的「生成物是否与 proto 一致」校验会永远报红。yaml 路径实测三次生成
# 字节完全一致。下游生成器（openapi-generator-ts-cli 等）本来就同时吃 yaml 与 json。
#
# [EN] It must be yaml, not json. The post-processor protoc-go-inject-tag edits yaml as text but
# round-trips json through a Go map, and Go randomizes map iteration order, so the same protos
# produce a different key order on every run. Committed, that means hundreds of lines of
# meaningless diff per generation and a permanently red "artifacts match the protos" check in the
# release pipeline. The yaml path was measured byte-identical across three runs, and downstream
# generators (openapi-generator-ts-cli among them) accept yaml and json alike.
OPENAPI_BUNDLE_DIR="docs"
OPENAPI_BUNDLE_FILE="$OPENAPI_BUNDLE_DIR/openapi.swagger.yaml"
OPENAPI_BUNDLE_INFO_PROTO="proto/openapi/bundle.proto"
BUNDLE_ARGS=(--plugin="protoc-gen-openapiv2=$PROTOC_GEN_OPENAPIV2" --openapiv2_out="$OPENAPI_BUNDLE_DIR" --openapiv2_opt=logtostderr=true --openapiv2_opt=json_names_for_fields=false --openapiv2_opt=output_format=yaml --openapiv2_opt=allow_merge=true --openapiv2_opt=merge_file_name=openapi)

clean_proto_outputs() {
    log_info "清理旧的 proto 目录生成文件..."
    find proto -name "*.pb.go" -delete 2>/dev/null || true
    find proto -name "*_grpc.pb.go" -delete 2>/dev/null || true
    find proto -name "*.gw.go" -delete 2>/dev/null || true
    find proto -name "*.swagger.json" -delete 2>/dev/null || true
    find proto -name "*.swagger.yaml" -delete 2>/dev/null || true
    rm -f "$OPENAPI_BUNDLE_FILE"
}

module_protos() {
    local module="$1"
    compgen -G "proto/$module/*.proto" || true
}

generate_go_for_module() {
    local module="$1"
    local protos
    protos="$(module_protos "$module")"
    [[ -z "$protos" ]] && return 0

    mkdir -p "pb/$module"
    log_info "生成 $module 模块 Go/gRPC 代码..."
    protoc "${INCLUDE_ARGS[@]}" "${GO_ARGS[@]}" $protos
}

generate_gateway_for_module() {
    local module="$1"
    local protos
    protos="$(module_protos "$module")"
    [[ -z "$protos" ]] && return 0
    grep -q "google.api.http" $protos || return 0

    log_info "生成 $module 模块 gRPC-Gateway 代码..."
    if ! protoc "${INCLUDE_ARGS[@]}" "${GATEWAY_ARGS[@]}" $protos; then
        log_error "$module 模块 gRPC-Gateway 代码生成失败，已中断"
        exit 1
    fi
}

generate_openapi_for_module() {
    local module="$1"
    local has_openapi_proto=false
    local file
    for file in proto/"$module"/*.proto; do
        [[ -e "$file" ]] || continue
        grep -qE "openapiv2_swagger|google\.api\.http" "$file" || continue
        has_openapi_proto=true
        log_info "生成 $(basename "$file" .proto) OpenAPI 文档..."
        if ! protoc "${INCLUDE_ARGS[@]}" "${OPENAPI_ARGS[@]}" "$file"; then
            log_error "$(basename "$file" .proto) OpenAPI 文档生成失败，已中断"
            exit 1
        fi
    done
    [[ "$has_openapi_proto" == true ]] || return 0
}

generate_root() {
    local protos
    protos="$(compgen -G "proto/*.proto" || true)"
    [[ -z "$protos" ]] && return 0

    log_info "生成根目录 proto Go/gRPC 代码..."
    protoc "${INCLUDE_ARGS[@]}" "${GO_ARGS[@]}" $protos

    if grep -q "google.api.http" $protos; then
        log_info "生成根目录 gRPC-Gateway 代码..."
        if ! protoc "${INCLUDE_ARGS[@]}" "${GATEWAY_ARGS[@]}" $protos; then
            log_error "根目录 gRPC-Gateway 代码生成失败，已中断"
            exit 1
        fi
    fi

    local has_root_openapi_proto=false
    local file
    for file in proto/*.proto; do
        [[ -e "$file" ]] || continue
        grep -qE "openapiv2_swagger|google\.api\.http" "$file" || continue
        has_root_openapi_proto=true
        log_info "生成根目录 $(basename "$file" .proto) OpenAPI 文档..."
        if ! protoc "${INCLUDE_ARGS[@]}" "${OPENAPI_ARGS[@]}" "$file"; then
            log_error "根目录 $(basename "$file" .proto) OpenAPI 文档生成失败，已中断"
            exit 1
        fi
    done
    [[ "$has_root_openapi_proto" == true ]] || return 0
}

# 生成聚合 OpenAPI 文档 | Produce the aggregated OpenAPI document
#
# 与网关文档站的区别：网关（bootstrap/）在运行时按 resources 配置把各模块 swagger
# 合并成一个可浏览的站点，只有跑着服务才看得到；这里产出的是一份静态文件，入库后
# 下游不用起任何服务就能拿到完整契约，CI 发版时作为 release 资产上传
#
# [EN] How this differs from the docs gateway: the gateway (bootstrap/) merges the
# per-module swagger files at runtime into a browsable site, which requires a running
# service. This produces a static file that is committed, so downstream consumers get the
# full contract without starting anything, and CI attaches it to the release.
generate_openapi_bundle() {
    if [[ ! -f "$OPENAPI_BUNDLE_INFO_PROTO" ]]; then
        log_warn "未找到 $OPENAPI_BUNDLE_INFO_PROTO，跳过聚合文档生成"
        return 0
    fi

    # 元信息 proto 必须排在第一个：合并后的 info 取自参数列表里的第一个文件
    # [EN] The metadata proto must come first: the merged info is taken from the first file
    local protos=("$OPENAPI_BUNDLE_INFO_PROTO")
    local module file
    for module in "${PROTO_SERVICE_MODULES[@]}"; do
        for file in proto/"$module"/*.proto; do
            [[ -e "$file" ]] || continue
            grep -qE "openapiv2_swagger|google\.api\.http" "$file" || continue
            protos+=("$file")
        done
    done
    for file in proto/*.proto; do
        [[ -e "$file" ]] || continue
        grep -qE "openapiv2_swagger|google\.api\.http" "$file" || continue
        protos+=("$file")
    done

    if [[ ${#protos[@]} -le 1 ]]; then
        log_warn "没有带 HTTP 注解的 proto，跳过聚合文档生成"
        return 0
    fi

    mkdir -p "$OPENAPI_BUNDLE_DIR"
    log_info "生成聚合 OpenAPI 文档（$((${#protos[@]} - 1)) 个服务 proto）..."
    if ! protoc "${INCLUDE_ARGS[@]}" "${BUNDLE_ARGS[@]}" "${protos[@]}"; then
        log_error "聚合 OpenAPI 文档生成失败，已中断"
        exit 1
    fi
}

clean_proto_outputs

for module in "${PROTO_BASE_MODULES[@]}"; do
    generate_go_for_module "$module"
done

for module in "${PROTO_SERVICE_MODULES[@]}"; do
    generate_go_for_module "$module"
done

generate_root

for module in "${PROTO_SERVICE_MODULES[@]}"; do
    generate_gateway_for_module "$module"
    generate_openapi_for_module "$module"
done

require_script "inject-tags.sh"
bash "$SCRIPT_DIR/inject-tags.sh" --force --skip-tool-check --input pb

log_info "处理 Swagger 文件：清理 @inject_tag 污染并注入约束..."
PROTOC_GO_INJECT_TAG="$(find_tool protoc-go-inject-tag)"
for module in "${PROTO_SERVICE_MODULES[@]}"; do
    if compgen -G "proto/$module/*.swagger.yaml" >/dev/null 2>&1; then
        log_info "处理 $module 模块的 Swagger 文件..."
        "$PROTOC_GO_INJECT_TAG" swagger --proto-dir="proto/$module" -v || {
            log_error "$module 模块 Swagger 处理失败"
            exit 1
        }
    fi
done

if compgen -G "proto/*.swagger.yaml" >/dev/null 2>&1; then
    log_info "处理根目录的 Swagger 文件..."
    "$PROTOC_GO_INJECT_TAG" swagger --input="proto/*.proto" -v || {
        log_error "根目录 Swagger 处理失败"
        exit 1
    }
fi

generate_openapi_bundle

if [[ -f "$OPENAPI_BUNDLE_FILE" ]]; then
    # 聚合文档走同一套后处理：剥掉 description 里的 @inject_tag 文本，
    # 并把 validate 约束翻译成 swagger 的 required/minLength/pattern 等字段，
    # 这样下游 SDK 生成器拿到的就是带校验信息的干净文档
    # [EN] The bundle goes through the same post-processing: strip @inject_tag text out of
    # the descriptions and translate validate constraints into swagger's
    # required/minLength/pattern fields, so downstream generators receive a clean document
    # that still carries the validation rules.
    log_info "处理聚合文档：清理 @inject_tag 污染并注入约束..."
    "$PROTOC_GO_INJECT_TAG" swagger --proto-dir=proto -s="$OPENAPI_BUNDLE_FILE" -v || {
        log_error "聚合文档处理失败"
        exit 1
    }
fi

log_success "Protobuf 文件生成完成"
log_success "结构体标签注入完成"
log_success "Swagger 文件处理完成"
if [[ -f "$OPENAPI_BUNDLE_FILE" ]]; then
    log_success "聚合 OpenAPI 文档生成完成: $OPENAPI_BUNDLE_FILE"
fi

echo ""
echo "生成的 Go 文件："
for module in "${PROTO_ALL_MODULES[@]}"; do
    if has_go_pb_files "pb/$module"; then
        echo "  $module:"
        find "pb/$module" -maxdepth 1 \( -name "*.pb.go" -o -name "*.gw.go" \) -print | sort
    fi
done

if has_go_pb_files "pb"; then
    echo "  root:"
    find pb -maxdepth 1 \( -name "*.pb.go" -o -name "*.gw.go" \) -print | sort
fi

echo ""
echo "下一步："
echo "  1. go mod tidy"
echo "  2. go run bootstrap"
