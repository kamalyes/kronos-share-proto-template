#!/bin/bash
set -euo pipefail

FORCE=false
PROTOC_RELEASE_VERSION="24.3"
REQUIRED_PROTOC_DISPLAY_VERSION="4.24.3"
REQUIRED_PROTOC_VERSION="libprotoc 24.3"
PROTO_FILES=(descriptor timestamp wrappers struct any empty duration field_mask)
for arg in "$@"; do
    case "$arg" in
        --force)
            FORCE=true
            ;;
        --no-pause)
            ;;
        --help|-h)
            echo "用法: scripts/setup-protobuf-includes.sh [--force] [--no-pause]"
            echo "  --force     即使 include 文件已存在也重新下载"
            echo "  --no-pause  兼容 Windows 版参数，shell 版不会暂停"
            exit 0
            ;;
        *)
            echo "❌ 未知选项: $arg"
            exit 1
            ;;
    esac
done

echo "🔧 设置 Protobuf Include 文件..."

download_file() {
    local output_path="$1"
    local url="$2"
    curl --http1.1 --retry 3 --retry-delay 2 --retry-all-errors --connect-timeout 20 --max-time 120 -fL -o "$output_path" "$url"
}

has_required_proto_files() {
    local include_dir="$1"
    local f
    for f in "${PROTO_FILES[@]}"; do
        if [ ! -f "$include_dir/google/protobuf/${f}.proto" ]; then
            return 1
        fi
    done
    return 0
}

copy_bundled_proto_files() {
    local source_include="$1"
    local target_include="$2"
    if [ ! -d "$source_include/google/protobuf" ]; then
        return 1
    fi

    mkdir -p "$target_include/google"
    cp -R "$source_include/google/." "$target_include/google/"
}

ensure_go_bin_dir() {
    if ! command -v go >/dev/null 2>&1; then
        echo "❌ Go 未安装，无法确定 protoc 安装目录"
        exit 1
    fi

    if [ -z "${GOPATH:-}" ]; then
        GOPATH="$(go env GOPATH)"
        export GOPATH
    fi
    if [ -z "$GOPATH" ]; then
        echo "❌ 无法获取 GOPATH，请手动设置"
        exit 1
    fi

    GO_BIN_DIR="$(go env GOBIN 2>/dev/null || true)"
    if [ -z "$GO_BIN_DIR" ]; then
        GO_BIN_DIR="$GOPATH/bin"
    fi
    mkdir -p "$GO_BIN_DIR"
}

protoc_asset_name() {
    local os_name arch_name
    case "$(uname -s)" in
        Darwin) os_name="osx" ;;
        Linux) os_name="linux" ;;
        *) echo "❌ 不支持的系统: $(uname -s)" >&2; return 1 ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) arch_name="x86_64" ;;
        arm64|aarch64)
            case "$os_name" in
                osx) arch_name="universal_binary" ;;
                *) arch_name="aarch_64" ;;
            esac
            ;;
        *) echo "❌ 不支持的架构: $(uname -m)" >&2; return 1 ;;
    esac

    echo "protoc-${PROTOC_RELEASE_VERSION}-${os_name}-${arch_name}.zip"
}

ensure_protoc_version() {
    local actual
    actual="$(protoc --version 2>/dev/null || true)"
    if [[ "$actual" == *"$REQUIRED_PROTOC_VERSION"* ]]; then
        echo "✅ protoc 版本符合要求: $actual"
        return 0
    fi

    if [ -n "$actual" ]; then
        echo "⚠️  protoc 版本不匹配，期望 ${REQUIRED_PROTOC_VERSION}，当前: $actual"
    else
        echo "⚠️  protoc 未安装，将自动安装固定版本 v${REQUIRED_PROTOC_DISPLAY_VERSION} (${REQUIRED_PROTOC_VERSION})"
    fi

    local asset zip_path extract_dir
    asset="$(protoc_asset_name)"
    zip_path="${TMPDIR:-/tmp}/$asset"
    extract_dir="${TMPDIR:-/tmp}/protoc-${PROTOC_RELEASE_VERSION}"
    rm -rf "$extract_dir" "$zip_path"

    echo "📦 正在下载 protoc v${REQUIRED_PROTOC_DISPLAY_VERSION}..."
    download_file "$zip_path" "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_RELEASE_VERSION}/${asset}"

    if ! command -v unzip >/dev/null 2>&1; then
        echo "❌ 需要 unzip 来解压 protoc release 包"
        exit 1
    fi

    echo "📦 正在安装 protoc 到 $GO_BIN_DIR..."
    unzip -q "$zip_path" -d "$extract_dir"
    cp "$extract_dir/bin/protoc" "$GO_BIN_DIR/protoc"
    chmod +x "$GO_BIN_DIR/protoc"
    copy_bundled_proto_files "$extract_dir/include" "$GO_BIN_DIR/include"

    actual="$($GO_BIN_DIR/protoc --version 2>/dev/null || true)"
    if [[ "$actual" != *"$REQUIRED_PROTOC_VERSION"* ]]; then
        echo "❌ protoc 版本校验失败，期望 ${REQUIRED_PROTOC_VERSION}，当前: ${actual:-未安装/无法获取}"
        exit 1
    fi
    echo "✅ protoc 已切换到固定版本: $actual"
}

ensure_go_bin_dir
ensure_protoc_version

# 获取 protoc 路径。
PROTOC_PATH=$(which protoc 2>/dev/null || true)
if [ -z "$PROTOC_PATH" ]; then
    echo "❌ protoc 未安装，请先安装 Protocol Buffers"
    echo "   macOS: brew install protobuf"
    exit 1
fi

PROTOC_DIR=$(dirname "$PROTOC_PATH")
PROTOC_ROOT=$(dirname "$PROTOC_DIR")
PROTOC_INCLUDE="$PROTOC_ROOT/include"

echo "📁 Protoc 路径: $PROTOC_PATH"
echo "📁 Protoc 根目录: $PROTOC_ROOT"
echo "📁 Include 目录: $PROTOC_INCLUDE"
echo "🎯 固定版本: protoc v${REQUIRED_PROTOC_DISPLAY_VERSION} (${REQUIRED_PROTOC_VERSION})"

if has_required_proto_files "$PROTOC_INCLUDE" && [ "$FORCE" = false ]; then
    echo "✅ 标准 protobuf include 文件已存在，跳过下载"
    exit 0
fi

RELEASE_INCLUDE="${TMPDIR:-/tmp}/protoc-${PROTOC_RELEASE_VERSION}/include"
if copy_bundled_proto_files "$RELEASE_INCLUDE" "$PROTOC_INCLUDE" && has_required_proto_files "$PROTOC_INCLUDE"; then
    echo "✅ 已从 protoc release 包补齐标准 protobuf include 文件"
    exit 0
fi

# 创建 include 目录
mkdir -p "$PROTOC_INCLUDE/google/protobuf"

# 下载标准 protobuf 文件
echo "📥 下载标准 protobuf 文件..."

for f in "${PROTO_FILES[@]}"; do
    echo "📋 下载 ${f}.proto..."
    if ! download_file "$PROTOC_INCLUDE/google/protobuf/${f}.proto" \
        "https://raw.githubusercontent.com/protocolbuffers/protobuf/v${PROTOC_RELEASE_VERSION}/src/google/protobuf/${f}.proto"; then
        echo "❌ 下载 ${f}.proto 失败"
        exit 1
    fi
done

# 检查是否成功
if [ -f "$PROTOC_INCLUDE/google/protobuf/timestamp.proto" ]; then
    echo ""
    echo "✅ 标准 protobuf 文件设置完成！"
    echo "📁 Include 路径: $PROTOC_INCLUDE"
    echo ""
    echo "📋 已下载的文件："
    for f in "${PROTO_FILES[@]}"; do
        if [ -f "$PROTOC_INCLUDE/google/protobuf/${f}.proto" ]; then
            echo "  ✓ ${f}.proto"
        else
            echo "  ✗ ${f}.proto (缺失)"
        fi
    done
else
    echo "❌ 设置失败，请手动下载 protobuf 文件"
    echo "💡 请访问: https://github.com/protocolbuffers/protobuf"
    exit 1
fi

echo ""
echo "🎉 完成！"
echo "💡 提示：如果需要 Google APIs 和 gRPC-Gateway 依赖，"
echo "   generate-modular.sh 会自动调用 setup-dependencies.sh 下载"
