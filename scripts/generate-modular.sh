#!/bin/bash
set -euo pipefail

echo "🔧 生成 Protobuf 文件 (分模块结构)..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

if [ -z "${GOPATH:-}" ]; then
    GOPATH=$(go env GOPATH)
    if [ -z "$GOPATH" ]; then
        echo "❌ GOPATH 环境变量未设置"
        exit 1
    fi
fi

if ! command -v protoc &>/dev/null; then
    echo "❌ protoc 未安装，请先安装 Protocol Buffers"
    exit 1
fi
echo "✅ protoc 已安装"

if ! command -v go &>/dev/null; then
    echo "❌ Go 未安装，请先安装 Go 环境"
    exit 1
fi
echo "✅ Go 环境已安装"

echo "🔍 检查必需的 protoc 插件..."

missing_plugins=()
all_plugins_found=true

PLUGINS_CHECK=(
    "protoc-gen-go:google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.11"
    "protoc-gen-go-grpc:google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.6.1"
    "protoc-gen-grpc-gateway:github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@v2.28.0"
    "protoc-gen-openapiv2:github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2@v2.28.0"
    "protoc-go-inject-tag:github.com/kamalyes/protoc-go-inject-tag@c54ecfe"
)

for item in "${PLUGINS_CHECK[@]}"; do
    cmd="${item%%:*}"
    pkg="${item#*:}"
    if command -v "$cmd" &>/dev/null; then
        echo "✅ $cmd 已安装"
    else
        echo "❌ $cmd 未找到"
        missing_plugins+=("$pkg")
        all_plugins_found=false
    fi
done

if [ "$all_plugins_found" = false ]; then
    echo ""
    echo "📦 检测到缺失插件，正在安装..."
    for plugin in "${missing_plugins[@]}"; do
        echo "安装 $plugin"
        go install "$plugin"
        if [ $? -ne 0 ]; then
            echo "❌ 安装 $plugin 失败"
            exit 1
        fi
    done
    echo "✅ 所有插件安装完成"
fi

echo "✅ 所有必需插件可用"
echo ""

if [ ! -d "proto" ]; then
    echo "❌ proto 目录不存在，请先创建 proto 目录并添加 .proto 文件"
    exit 1
fi

echo "🧹 清理旧的生成文件..."
find proto -name "*.pb.go" -delete 2>/dev/null || true
find proto -name "*_grpc.pb.go" -delete 2>/dev/null || true
find proto -name "*.gw.go" -delete 2>/dev/null || true
find proto -name "*.swagger.json" -delete 2>/dev/null || true

PROTOC_PATH=$(which protoc)
PROTOC_DIR=$(dirname "$PROTOC_PATH")
PROTOC_ROOT=$(dirname "$PROTOC_DIR")
PROTOC_INCLUDE="$PROTOC_ROOT/include"

echo "📁 Protoc 路径: $PROTOC_PATH"
echo "📁 Include 路径: $PROTOC_INCLUDE"

GOOGLEAPIS_PATH=""
GRPC_GATEWAY_PATH=""

if [ -d "$GOPATH/src/github.com/googleapis" ]; then
    GOOGLEAPIS_PATH="-I $GOPATH/src/github.com/googleapis"
    echo "✅ 使用 GOPATH 中的 googleapis"
else
    echo "⚠️  警告：GOPATH 中未找到 googleapis"
fi

if [ -d "$GOPATH/src/github.com/grpc-ecosystem/grpc-gateway" ]; then
    GRPC_GATEWAY_PATH="-I $GOPATH/src/github.com/grpc-ecosystem/grpc-gateway"
    echo "✅ 使用 GOPATH 中的 grpc-gateway"
else
    echo "⚠️  警告：GOPATH 中未找到 grpc-gateway"
fi

GO_MODULE="[[ .ModuleName ]]"
GO_OPT="--go_opt=module=$GO_MODULE"
GO_GRPC_OPT="--go-grpc_opt=module=$GO_MODULE"
GRPC_GATEWAY_OPT="--grpc-gateway_opt=module=$GO_MODULE"

PROTO_BASE_MODULES=(enums common)
PROTO_MODULES=([[ .ExampleServiceName | snake ]])
PROTO_INJECT_TAGS_MODULES=("${PROTO_BASE_MODULES[@]}" "${PROTO_MODULES[@]}")

mkdir -p pb

echo "🚀 生成 gRPC 代码..."

for module in "${PROTO_BASE_MODULES[@]}"; do
    mkdir -p "pb/$module"
    if ls proto/$module/*.proto &>/dev/null; then
        echo "📦 生成 $module 模块..."
        protoc -I"$PROTOC_INCLUDE" $GOOGLEAPIS_PATH $GRPC_GATEWAY_PATH -I. \
            --go_out=. $GO_OPT \
            --go-grpc_out=. $GO_GRPC_OPT \
            proto/$module/*.proto
        if [ $? -ne 0 ]; then
            echo "❌ $module 模块生成失败"
            exit 1
        fi
    fi
done

for module in "${PROTO_MODULES[@]}"; do
    mkdir -p "pb/$module"
    if ls proto/$module/*.proto &>/dev/null; then
        echo "📦 生成 $module 模块..."
        protoc -I"$PROTOC_INCLUDE" $GOOGLEAPIS_PATH $GRPC_GATEWAY_PATH -I. \
            --go_out=. $GO_OPT \
            --go-grpc_out=. $GO_GRPC_OPT \
            proto/$module/*.proto
        if [ $? -ne 0 ]; then
            echo "❌ $module 模块生成失败"
            exit 1
        fi
    fi
done

echo "🌐 生成 gRPC-Gateway 代码..."

for module in "${PROTO_MODULES[@]}"; do
    if ls proto/$module/*.proto &>/dev/null; then
        if grep -l "google.api.http" proto/$module/*.proto &>/dev/null; then
            echo "📦 生成 $module 模块网关代码..."
            protoc -I"$PROTOC_INCLUDE" $GOOGLEAPIS_PATH $GRPC_GATEWAY_PATH -I. \
                --grpc-gateway_out=. $GRPC_GATEWAY_OPT \
                --grpc-gateway_opt=generate_unbound_methods=true \
                proto/$module/*.proto
            if [ $? -ne 0 ]; then
                echo "⚠️  $module 模块网关代码生成失败，跳过..."
            fi
        fi
    fi
done

echo "📖 生成 OpenAPI 文档..."

for module in "${PROTO_MODULES[@]}"; do
    if ls proto/$module/*.proto &>/dev/null; then
        if grep -l "openapiv2_swagger" proto/$module/*.proto &>/dev/null; then
            echo "📖 生成 $module 模块文档..."
            protoc -I"$PROTOC_INCLUDE" $GOOGLEAPIS_PATH $GRPC_GATEWAY_PATH -I. \
                --openapiv2_out=. \
                --openapiv2_opt=logtostderr=true \
                --openapiv2_opt=json_names_for_fields=false \
                --openapiv2_opt=output_format=yaml \
                proto/$module/*.proto
            if [ $? -ne 0 ]; then
                echo "⚠️  $module 模块文档生成失败，跳过..."
            fi
        fi
    fi
done

echo "🏷️  注入结构体标签..."

for module in "${PROTO_INJECT_TAGS_MODULES[@]}"; do
    if ls pb/$module/*.pb.go &>/dev/null; then
        echo "🏷️  注入 $module 模块标签..."
        protoc-go-inject-tag --input="pb/$module/*.pb.go"
        if [ $? -ne 0 ]; then
            echo "⚠️  $module 模块标签注入失败，跳过..."
        fi
    fi
done

echo ""
echo "✅ Protobuf 文件生成完成！"
echo "✅ 结构体标签注入完成！"
echo ""
echo "📝 下一步："
echo "   1. 运行 go mod tidy 更新依赖"
echo "   2. 运行 go run bootstrap 启动服务"
