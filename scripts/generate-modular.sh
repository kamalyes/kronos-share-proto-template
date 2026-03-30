#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

GO_MODULE="<% .ModuleName %>"
PROTO_BASE_MODULES=(enums)
# 业务模块列表：新增模块后必须加到这里，否则不会被生成。
# Service module list: a new module must be registered here or it will not be generated
PROTO_SERVICE_MODULES=(common <% .ExampleModule %> <% .SecondModule %> <% .MixedModule %>)
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

clean_proto_outputs() {
    log_info "清理旧的 proto 目录生成文件..."
    find proto -name "*.pb.go" -delete 2>/dev/null || true
    find proto -name "*_grpc.pb.go" -delete 2>/dev/null || true
    find proto -name "*.gw.go" -delete 2>/dev/null || true
    find proto -name "*.swagger.json" -delete 2>/dev/null || true
    find proto -name "*.swagger.yaml" -delete 2>/dev/null || true
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

log_success "Protobuf 文件生成完成"
log_success "结构体标签注入完成"
log_success "Swagger 文件处理完成"

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
