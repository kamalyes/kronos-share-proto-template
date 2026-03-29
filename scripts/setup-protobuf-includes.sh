#!/bin/bash
set -euo pipefail

echo "🔧 设置 Protobuf Include 文件..."

PROTOC_PATH=$(which protoc)
PROTOC_DIR=$(dirname "$PROTOC_PATH")
PROTOC_ROOT=$(dirname "$PROTOC_DIR")
PROTOC_INCLUDE="$PROTOC_ROOT/include"

echo "📁 Protoc 路径: $PROTOC_PATH"
echo "📁 Include 目录: $PROTOC_INCLUDE"

mkdir -p "$PROTOC_INCLUDE/google/protobuf"

echo "📥 下载标准 protobuf 文件..."

PROTO_FILES=(descriptor timestamp wrappers struct any empty duration field_mask)

for file in "${PROTO_FILES[@]}"; do
    echo "📋 下载 $file.proto..."
    curl -sSL "https://raw.githubusercontent.com/protocolbuffers/protobuf/main/src/google/protobuf/$file.proto" \
        -o "$PROTOC_INCLUDE/google/protobuf/$file.proto"
    if [ $? -ne 0 ]; then
        echo "❌ 下载 $file.proto 失败"
        exit 1
    fi
done

if [ -f "$PROTOC_INCLUDE/google/protobuf/timestamp.proto" ]; then
    echo ""
    echo "✅ 标准 protobuf 文件设置完成！"
else
    echo "❌ 设置失败，请手动下载 protobuf 文件"
    exit 1
fi
