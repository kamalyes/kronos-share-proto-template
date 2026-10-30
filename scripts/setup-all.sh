#!/bin/bash
set -euo pipefail

echo "========================================"
echo "🚀 一键安装所有依赖"
echo "========================================"
echo ""

SETUP_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --no-pause)
            ;;
        --force)
            SETUP_ARGS+=("--force")
            ;;
        --help|-h)
            echo "用法: scripts/setup-all.sh [--force] [--no-pause]"
            echo "  --force     依赖已存在时重新下载"
            echo "  --no-pause  兼容 Windows 版参数，shell 版不会暂停"
            exit 0
            ;;
        *)
            echo "❌ 未知选项: $arg"
            exit 1
            ;;
    esac
done

# 获取项目根目录。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo ""
echo "========================================"
echo "📥 安装依赖文件"
echo "========================================"
echo ""

# 设置 Protobuf Include 文件
echo "[1/2] 设置 Protobuf Include 文件..."
if [ -f "scripts/setup-protobuf-includes.sh" ]; then
    bash scripts/setup-protobuf-includes.sh ${SETUP_ARGS[@]+"${SETUP_ARGS[@]}"}
    if [ $? -ne 0 ]; then
        echo "❌ Protobuf Include 文件设置失败"
        exit 1
    fi
else
    echo "❌ 未找到 scripts/setup-protobuf-includes.sh"
    exit 1
fi
echo ""

# 安装 protoc 插件并下载 Google APIs 和 gRPC-Gateway 依赖
echo "[2/2] 安装 protoc 插件并下载 Google APIs 和 gRPC-Gateway 依赖..."
if [ -f "scripts/setup-dependencies.sh" ]; then
    bash scripts/setup-dependencies.sh ${SETUP_ARGS[@]+"${SETUP_ARGS[@]}"}
    if [ $? -ne 0 ]; then
        echo "❌ protoc 插件安装或依赖下载失败"
        exit 1
    fi
else
    echo "❌ 未找到 scripts/setup-dependencies.sh"
    exit 1
fi

echo ""
echo "========================================"
echo "✅ 所有依赖安装完成！"
echo "========================================"
echo ""
echo "📝 下一步："
echo "  1. 运行 scripts/generate-modular.sh 生成 protobuf 代码"
echo "  2. 运行 go mod tidy 更新 Go 模块依赖"
echo "  3. 运行 go run ./bootstrap 启动服务"
echo ""
