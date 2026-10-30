#!/bin/bash
set -euo pipefail

# Engine Kronos Share Proto Google APIs 和 gRPC-Gateway 依赖下载脚本
# 下载 gRPC-Gateway 所需的依赖 proto 文件到 GOPATH

TOOLS_ONLY=false
INJECT_TAG_ONLY=false
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --tools-only)
            TOOLS_ONLY=true
            ;;
        --inject-tag-only)
            INJECT_TAG_ONLY=true
            ;;
        --force)
            FORCE=true
            ;;
        --no-pause)
            ;;
        --help|-h)
            echo "用法: scripts/setup-dependencies.sh [--tools-only] [--inject-tag-only] [--force] [--no-pause]"
            echo "  --tools-only  仅安装并校验 protoc 插件版本，不下载 proto include 依赖"
            echo "  --inject-tag-only  仅安装并校验 protoc-go-inject-tag"
            echo "  --force       依赖目录已存在时重新下载"
            echo "  --no-pause    兼容 Windows 版参数，shell 版不会暂停"
            exit 0
            ;;
        *)
            echo "❌ 未知选项: $arg"
            exit 1
            ;;
    esac
done

if [ "$INJECT_TAG_ONLY" = true ]; then
    echo "🔐 安装并校验 protoc-go-inject-tag 版本..."
elif [ "$TOOLS_ONLY" = true ]; then
    echo "🔐 安装并校验 protoc 插件版本..."
else
    echo "📦 下载 Google APIs 和 gRPC-Gateway 依赖到 GOPATH..."
fi

if ! command -v go &>/dev/null; then
    echo "❌ Go 未安装，请先安装 Go 环境"
    exit 1
fi

# 检查 GOPATH
if [ -z "${GOPATH:-}" ]; then
    echo "⚠️  GOPATH 未设置，使用默认值..."
    GOPATH=$(go env GOPATH)
    if [ -z "$GOPATH" ]; then
        echo "❌ 无法获取 GOPATH，请手动设置"
        exit 1
    fi
fi
export GOPATH

GO_BIN_DIR="$(go env GOBIN 2>/dev/null || true)"
if [ -z "$GO_BIN_DIR" ]; then
    GO_BIN_DIR="$GOPATH/bin"
fi
mkdir -p "$GO_BIN_DIR"
case ":$PATH:" in
    *":$GO_BIN_DIR:"*) ;;
    *) export PATH="$GO_BIN_DIR:$PATH" ;;
esac

# 配置变量
GOOGLEAPIS_VERSION="master"
GRPC_GATEWAY_VERSION="v2.29.0"
REQUIRED_PROTOC_GEN_GO_VERSION="v1.36.11"
REQUIRED_PROTOC_GEN_GO_GRPC_VERSION="1.6.1"
REQUIRED_GRPC_GATEWAY_VERSION="$GRPC_GATEWAY_VERSION"
REQUIRED_OPENAPIV2_VERSION="$GRPC_GATEWAY_VERSION"
REQUIRED_INJECT_TAG_VERSION="1b80c07"
INJECT_TAG_MODULE="github.com/kamalyes/protoc-go-inject-tag@${REQUIRED_INJECT_TAG_VERSION}"
INJECT_TAG_LDFLAGS="-X github.com/kamalyes/protoc-go-inject-tag/bootstrap.Version=${REQUIRED_INJECT_TAG_VERSION}"
GOPATH_SRC_DIR="$GOPATH/src/github.com"
GOOGLEAPIS_DIR="$GOPATH_SRC_DIR/googleapis"
GRPC_GATEWAY_DIR="$GOPATH_SRC_DIR/grpc-ecosystem/grpc-gateway"
KAMALYES_GO_GRPC_GATEWAY_DIR="$GOPATH_SRC_DIR/kamalyes/go-rpc-gateway"

echo "🔍 GOPATH: $GOPATH"
echo "🔍 Go bin: $GO_BIN_DIR"
echo "🎯 目标目录 1: $GOOGLEAPIS_DIR"
echo "🎯 目标目录 2: $GRPC_GATEWAY_DIR"
echo "🎯 目标目录 3: $KAMALYES_GO_GRPC_GATEWAY_DIR"

check_command_version() {
    local cmd="$1"
    local expected="$2"
    local install_pkg="$3"
    local actual

    actual="$($cmd --version 2>/dev/null || true)"
    if [[ "$actual" == *"$expected"* ]]; then
        echo "✅ $cmd 版本符合要求: $actual"
        return 0
    fi

    echo "⚠️  $cmd 版本不匹配，期望 ${expected}，当前: ${actual:-未安装/无法获取}"
    echo "📦 正在安装 $install_pkg"
    go install "$install_pkg"
    actual="$($cmd --version 2>/dev/null || true)"
    if [[ "$actual" != *"$expected"* ]]; then
        echo "❌ $cmd 版本校验失败，期望 ${expected}，当前: ${actual:-未安装/无法获取}"
        exit 1
    fi
    echo "✅ $cmd 已切换到要求版本: $actual"
}

ensure_inject_tag_version() {
    local actual

    actual="$(protoc-go-inject-tag --version 2>/dev/null || true)"
    if [[ "$actual" == "$REQUIRED_INJECT_TAG_VERSION" || "$actual" == *"$REQUIRED_INJECT_TAG_VERSION"* ]]; then
        echo "✅ protoc-go-inject-tag 版本符合要求: $actual"
        return 0
    fi

    echo "⚠️  protoc-go-inject-tag 版本不匹配，期望 ${REQUIRED_INJECT_TAG_VERSION}，当前: ${actual:-未安装/无法获取}"
    echo "📦 正在安装 $INJECT_TAG_MODULE 并注入版本号"
    go install -ldflags "$INJECT_TAG_LDFLAGS" "$INJECT_TAG_MODULE"
    actual="$(protoc-go-inject-tag --version 2>/dev/null || true)"
    if [[ "$actual" != "$REQUIRED_INJECT_TAG_VERSION" && "$actual" != *"$REQUIRED_INJECT_TAG_VERSION"* ]]; then
        echo "❌ protoc-go-inject-tag 版本校验失败，期望 ${REQUIRED_INJECT_TAG_VERSION}，当前: ${actual:-未安装/无法获取}"
        exit 1
    fi
    echo "✅ protoc-go-inject-tag 已切换到要求版本: $actual"
}

ensure_generation_tools() {
    echo "🔐 校验 protoc 插件版本..."
    check_command_version "protoc-gen-go" "$REQUIRED_PROTOC_GEN_GO_VERSION" "google.golang.org/protobuf/cmd/protoc-gen-go@${REQUIRED_PROTOC_GEN_GO_VERSION}"
    check_command_version "protoc-gen-go-grpc" "$REQUIRED_PROTOC_GEN_GO_GRPC_VERSION" "google.golang.org/grpc/cmd/protoc-gen-go-grpc@v${REQUIRED_PROTOC_GEN_GO_GRPC_VERSION}"
    check_command_version "protoc-gen-grpc-gateway" "$REQUIRED_GRPC_GATEWAY_VERSION" "github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@${REQUIRED_GRPC_GATEWAY_VERSION}"
    check_command_version "protoc-gen-openapiv2" "$REQUIRED_OPENAPIV2_VERSION" "github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2@${REQUIRED_OPENAPIV2_VERSION}"
    ensure_inject_tag_version
    echo "✅ 所有必需插件可用"
}

if [ "$INJECT_TAG_ONLY" = true ]; then
    echo "🔐 校验 protoc-go-inject-tag 版本..."
    ensure_inject_tag_version
else
    ensure_generation_tools
fi

if [ "$INJECT_TAG_ONLY" = true ]; then
    echo "✅ protoc-go-inject-tag 版本校验完成"
    exit 0
fi

if [ "$TOOLS_ONLY" = true ]; then
    echo "✅ protoc 插件版本校验完成"
    exit 0
fi

# 创建目录（注意不要预创建 googleapis/grpc-ecosystem/kamalyes 目标目录本身，
# 否则下方 -d 判断会误认为已下载而跳过 clone，全新环境下导致依赖缺失）
mkdir -p "$GOPATH_SRC_DIR"

# 检查 Git
if ! command -v git &>/dev/null; then
    echo "❌ 需要 Git 来下载依赖，请安装 Git"
    exit 1
fi

# 下载 Google APIs
echo "🚀 下载 Google APIs..."
if [ -d "$GOOGLEAPIS_DIR" ]; then
    if [ "$FORCE" = false ]; then
        echo "✅ Google APIs 已存在，跳过下载"
    else
        rm -rf "$GOOGLEAPIS_DIR"
        echo "📥 使用 Git 下载 googleapis..."
        git clone --depth=1 --branch="$GOOGLEAPIS_VERSION" https://github.com/googleapis/googleapis.git "$GOOGLEAPIS_DIR"
        if [ $? -ne 0 ]; then
            echo "❌ Git 下载 googleapis 失败"
            exit 1
        fi
    fi
else
    echo "📥 使用 Git 下载 googleapis..."
    git clone --depth=1 --branch="$GOOGLEAPIS_VERSION" https://github.com/googleapis/googleapis.git "$GOOGLEAPIS_DIR"
    if [ $? -ne 0 ]; then
        echo "❌ Git 下载 googleapis 失败"
        exit 1
    fi
fi

# 下载 gRPC-Gateway
echo "🚀 下载 gRPC-Gateway..."
if [ -d "$GRPC_GATEWAY_DIR" ]; then
    if [ "$FORCE" = false ]; then
        echo "✅ gRPC-Gateway 已存在，跳过下载"
    else
        rm -rf "$GRPC_GATEWAY_DIR"
        echo "📥 使用 Git 下载 grpc-gateway..."
        git clone --depth=1 --branch="$GRPC_GATEWAY_VERSION" https://github.com/grpc-ecosystem/grpc-gateway.git "$GRPC_GATEWAY_DIR"
        if [ $? -ne 0 ]; then
            echo "❌ Git 下载 grpc-gateway 失败"
            exit 1
        fi
    fi
else
    echo "📥 使用 Git 下载 grpc-gateway..."
    git clone --depth=1 --branch="$GRPC_GATEWAY_VERSION" https://github.com/grpc-ecosystem/grpc-gateway.git "$GRPC_GATEWAY_DIR"
    if [ $? -ne 0 ]; then
        echo "❌ Git 下载 grpc-gateway 失败"
        exit 1
    fi
fi

# 下载 kamalyes/go-rpc-gateway
echo "🚀 下载 kamalyes/go-rpc-gateway..."
if [ -d "$KAMALYES_GO_GRPC_GATEWAY_DIR" ]; then
    if [ "$FORCE" = false ]; then
        echo "✅ kamalyes/go-rpc-gateway 已存在，跳过下载"
    else
        rm -rf "$KAMALYES_GO_GRPC_GATEWAY_DIR"
        echo "📥 使用 Git 下载 kamalyes/go-rpc-gateway..."
        git clone --depth=1 https://github.com/kamalyes/go-rpc-gateway.git "$KAMALYES_GO_GRPC_GATEWAY_DIR"
        if [ $? -ne 0 ]; then
            echo "❌ Git 下载 kamalyes/go-rpc-gateway 失败"
            exit 1
        fi
    fi
else
    echo "📥 使用 Git 下载 kamalyes/go-rpc-gateway..."
    git clone --depth=1 https://github.com/kamalyes/go-rpc-gateway.git "$KAMALYES_GO_GRPC_GATEWAY_DIR"
    if [ $? -ne 0 ]; then
        echo "❌ Git 下载 kamalyes/go-rpc-gateway 失败"
        exit 1
    fi
fi

# 验证下载
echo "🔍 验证下载结果..."

validation_failed=false

if [ -f "$GOOGLEAPIS_DIR/google/api/annotations.proto" ]; then
    echo "✅ Google APIs annotations.proto 存在"
else
    echo "❌ Google APIs annotations.proto 缺失"
    validation_failed=true
fi

if [ -f "$GOOGLEAPIS_DIR/google/api/http.proto" ]; then
    echo "✅ Google APIs http.proto 存在"
else
    echo "❌ Google APIs http.proto 缺失"
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
echo ""
echo "📁 已下载的关键文件："
echo "  - $GOOGLEAPIS_DIR/google/api/annotations.proto"
echo "  - $GOOGLEAPIS_DIR/google/api/http.proto"
echo "  - $GOOGLEAPIS_DIR/google/protobuf/timestamp.proto"
echo "  - $GOOGLEAPIS_DIR/google/protobuf/wrappers.proto"
echo "  - $GRPC_GATEWAY_DIR/protoc-gen-openapiv2/options/annotations.proto"
echo "  - $KAMALYES_GO_GRPC_GATEWAY_DIR/proto/common.proto"
echo ""
echo "🎉 现在可以使用 gRPC-Gateway 功能了！"
echo "💡 提示：generate-modular.sh 将自动从 GOPATH 查找这些文件"
