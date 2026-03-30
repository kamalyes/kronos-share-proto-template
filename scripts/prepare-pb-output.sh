#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

INPUT_DIR="pb"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input|-i)
            if [[ -z "${2:-}" ]]; then
                log_error "$1 需要指定目录"
                exit 1
            fi
            INPUT_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "用法: scripts/prepare-pb-output.sh [--input DIR]"
            echo "  清空并重建 DIR，确保生成前没有旧产物残留"
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            exit 1
            ;;
    esac
done

project_root

case "$INPUT_DIR" in
    ""|"."|".."|"/")
        log_error "拒绝清空危险输出目录: ${INPUT_DIR:-<empty>}"
        exit 1
        ;;
esac

log_info "清空 $INPUT_DIR 输出目录..."
rm -rf "$INPUT_DIR"
mkdir -p "$INPUT_DIR"
