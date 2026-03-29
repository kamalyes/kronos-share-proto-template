#!/bin/bash
set -euo pipefail

echo "📦 下载 Google APIs 和 gRPC-Gateway 依赖到 GOPATH..."

if [ -z "${GOPATH:-}" ]; then
    GOPATH=$(go env GOPATH)
    if [ -z "$GOPATH" ]; then
        echo "❌ GOPATH 环境变量未设置"
        exit 1
    fi
fi

GOOGLEAPIS_VERSION="master"
GRPC_GATEWAY_VERSION="v2.19.0"
GOPATH_SRC_DIR="$GOPATH/src/github.com"
GOOGLEAPIS_DIR="$GOPATH_SRC_DIR/googleapis"
GRPC_GATEWAY_DIR="$GOPATH_SRC_DIR/grpc-ecosystem/grpc-gateway"

echo "🔍 GOPATH: $GOPATH"
echo "🎯 目标目录 1: $GOOGLEAPIS_DIR"
echo "🎯 目标目录 2: $GRPC_GATEWAY_DIR"

mkdir -p "$GOPATH_SRC_DIR/googleapis"
mkdir -p "$GOPATH_SRC_DIR/grpc-ecosystem"

echo "🚀 下载 Google APIs..."
if [ ! -d "$GOOGLEAPIS_DIR" ]; then
    if command -v git &>/dev/null; then
        echo "📥 使用 Git 下载 googleapis..."
        git clone --depth=1 --branch="$GOOGLEAPIS_VERSION" https://github.com/googleapis/googleapis.git "$GOOGLEAPIS_DIR"
        if [ $? -ne 0 ]; then
            echo "❌ Git 下载 googleapis 失败"
            exit 1
        fi
    else
        echo "❌ 需要 Git 来下载依赖，请安装 Git"
        exit 1
    fi
else
    echo "✅ Google APIs 已存在，跳过下载"
fi

echo "🚀 下载 gRPC-Gateway..."
if [ ! -d "$GRPC_GATEWAY_DIR" ]; then
    if command -v git &>/dev/null; then
        echo "📥 使用 Git 下载 grpc-gateway..."
        git clone --depth=1 --branch="$GRPC_GATEWAY_VERSION" https://github.com/grpc-ecosystem/grpc-gateway.git "$GRPC_GATEWAY_DIR"
        if [ $? -ne 0 ]; then
            echo "❌ Git 下载 grpc-gateway 失败"
            exit 1
        fi
    else
        echo "❌ 需要 Git 来下载依赖，请安装 Git"
        exit 1
    fi
else
    echo "✅ gRPC-Gateway 已存在，跳过下载"
fi

echo "🔍 验证下载结果..."
validation_failed=false

if [ -f "$GOOGLEAPIS_DIR/google/api/annotations.proto" ]; then
    echo "✅ Google APIs annotations.proto 存在"
else
    echo "❌ Google APIs annotations.proto 缺失"
    validation_failed=true
fi

if [ -f "$GRPC_GATEWAY_DIR/protoc-gen-openapiv2/options/annotations.proto" ]; then
    echo "✅ gRPC-Gateway openapiv2 annotations.proto 存在"
else
    echo "❌ gRPC-Gateway openapiv2 annotations.proto 缺失"
    validation_failed=true
fi

if [ "$validation_failed" = true ]; then
    echo "❌ 依赖验证失败，请检查下载"
    exit 1
fi

echo ""
echo "✅ 所有依赖下载完成到 GOPATH！"
