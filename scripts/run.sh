#!/bin/bash
set -euo pipefail

echo "🚀 启动 [[ .ProjectName ]] 服务..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -f "go.mod" ]; then
    echo "❌ 未找到 go.mod 文件"
    echo "请先运行: go mod init [[ .ModuleName ]]"
    exit 1
fi

echo "📦 检查并更新依赖..."
go mod tidy
if [ $? -ne 0 ]; then
    echo "❌ 依赖更新失败"
    exit 1
fi

if [ -d "proto" ]; then
    if ls proto/*.proto &>/dev/null; then
        if ! ls pb/*.pb.go &>/dev/null; then
            echo "🔧 检测到 proto 文件，自动生成 gRPC 代码..."
            bash scripts/generate-modular.sh
            if [ $? -ne 0 ]; then
                echo "❌ protobuf 代码生成失败"
                exit 1
            fi
        fi
    fi
fi

echo "🔍 编译检查..."
if ! go build -o /dev/null .; then
    echo "❌ 编译失败，请检查代码错误"
    exit 1
fi

echo "🌟 启动服务中..."
echo "按 Ctrl+C 停止服务"
echo "----------------------------------------"
go run bootstrap
