#!/bin/bash
set -euo pipefail

echo "🏷️ 注入结构体标签..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

INPUT_DIR="${1:-pb}"

if ! command -v protoc-go-inject-tag &>/dev/null; then
    echo "📦 安装 protoc-go-inject-tag..."
    go install github.com/kamalyes/protoc-go-inject-tag@c54ecfe
    if [ $? -ne 0 ]; then
        echo "❌ protoc-go-inject-tag 安装失败"
        exit 1
    fi
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "❌ 输入目录不存在: $INPUT_DIR"
    echo "请先运行 scripts/generate-modular.sh 生成 protobuf 代码"
    exit 1
fi

echo "🏷️ 开始注入结构体标签..."

if ls "$INPUT_DIR"/*.pb.go &>/dev/null; then
    protoc-go-inject-tag --input="$INPUT_DIR/*.pb.go"
    if [ $? -ne 0 ]; then
        echo "⚠️ 根目录标签注入失败，跳过..."
    else
        echo "✅ 根目录标签注入完成"
    fi
fi

for module_dir in "$INPUT_DIR"/*/; do
    if [ -d "$module_dir" ] && ls "$module_dir"*.pb.go &>/dev/null; then
        module_name=$(basename "$module_dir")
        echo "🏷️ 注入 $module_name 模块标签..."
        protoc-go-inject-tag --input="$module_dir*.pb.go"
        if [ $? -ne 0 ]; then
            echo "⚠️ $module_name 模块标签注入失败，跳过..."
        else
            echo "✅ $module_name 模块标签注入完成"
        fi
    fi
done

echo "✅ 所有模块标签注入完成"
