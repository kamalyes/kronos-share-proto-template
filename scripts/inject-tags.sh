#!/bin/bash
set -euo pipefail

# <% .OrgPrefix | pascal %> Share Proto 标签注入脚本
# 使用 protoc-go-inject-tag 为生成的 Go 结构体注入标签。

source "$(cd "$(dirname "$0")" && pwd)/common.sh"
project_root

# 初始化变量
VERBOSE=""
FORCE=""
INPUT_DIR="pb"
SKIP_TOOL_CHECK=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --skip-tool-check)
            SKIP_TOOL_CHECK=true
            shift
            ;;
        --input|-i)
            INPUT_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "标签注入脚本使用说明"
            echo ""
            echo "用法:"
            echo "  scripts/inject-tags.sh [选项]"
            echo ""
            echo "选项:"
            echo "  --verbose, -v     显示详细输出"
            echo "  --force, -f       强制执行（忽略检查）"
            echo "  --skip-tool-check 跳过 protoc-go-inject-tag 版本检查（生成脚本内部调用）"
            echo "  --input, -i DIR   指定输入目录 (默认: pb)"
            echo "  --help, -h        显示帮助信息"
            echo ""
            echo "功能:"
            echo "  - 自动安装 protoc-go-inject-tag 工具"
            echo "  - 为生成的 .pb.go 文件注入结构体标签"
            echo "  - 支持 JSON、GORM、Validator、BSON 等标签"
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            echo "使用 --help 查看帮助信息"
            exit 1
            ;;
    esac
done

# 检查 Go 环境
if ! command -v go &>/dev/null; then
    log_error "Go 未安装，请先安装 Go 环境"
    exit 1
fi

if [ -z "$SKIP_TOOL_CHECK" ]; then
    if [ -f "scripts/setup-dependencies.sh" ]; then
        bash scripts/setup-dependencies.sh --inject-tag-only --no-pause
    else
        log_error "未找到依赖设置脚本: scripts/setup-dependencies.sh"
        exit 1
    fi
fi

# 检查输入目录
if [ ! -d "$INPUT_DIR" ]; then
    log_error "输入目录不存在: $INPUT_DIR"
    echo "请先运行生成脚本或指定正确的目录"
    exit 1
fi

# 查找 .pb.go 文件
pb_file_count=0

# 检查根目录的pb文件
for f in "$INPUT_DIR"/*.pb.go; do
    if [ -f "$f" ]; then
        pb_file_count=$((pb_file_count + 1))
    fi
done

# 检查proto子目录下的各模块
for module_dir in "$INPUT_DIR"/*/; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "${module_dir%/}")
        [[ "$module_name" == backup_* ]] && continue
        for f in "$module_dir"*.pb.go; do
            if [ -f "$f" ]; then
                pb_file_count=$((pb_file_count + 1))
            fi
        done
    fi
done

if [ $pb_file_count -eq 0 ]; then
    log_warn "在 $INPUT_DIR 目录中没有找到 .pb.go 文件"
    log_warn "请先运行 scripts/generate-modular.sh 生成 protobuf 代码"
    exit 1
else
    log_info "找到 $pb_file_count 个 .pb.go 文件"
fi

# 注入标签
log_info "开始注入结构体标签..."

# 注入根目录文件
if ls "$INPUT_DIR"/*.pb.go &>/dev/null; then
    input_pattern="$INPUT_DIR/*.pb.go"
    if [ -n "$VERBOSE" ]; then
        log_info "执行命令: protoc-go-inject-tag --input=\"$input_pattern\""
    fi
    protoc-go-inject-tag --input="$input_pattern"
    if [ $? -ne 0 ]; then
        log_error "根目录标签注入失败，已中断"
        exit 1
    else
        log_success "根目录标签注入完成"
    fi
fi

# 注入各模块文件
for module_dir in "$INPUT_DIR"/*/; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "${module_dir%/}")
        [[ "$module_name" == backup_* ]] && continue
        if ls "$module_dir"*.pb.go &>/dev/null; then
            module_pattern="${module_dir}*.pb.go"
            if [ -n "$VERBOSE" ]; then
                log_info "执行命令: protoc-go-inject-tag --input=\"$module_pattern\""
            fi
            protoc-go-inject-tag --input="$module_pattern"
            if [ $? -ne 0 ]; then
                log_error "$module_name 模块标签注入失败，已中断"
                exit 1
            else
                log_success "$module_name 模块标签注入完成"
            fi
        fi
    fi
done

log_success "所有模块标签注入完成"

# 验证注入结果
log_info "验证标签注入结果..."

has_tags=false

# 检查根目录
for f in "$INPUT_DIR"/*.pb.go; do
    if [ -f "$f" ]; then
        if grep -q 'json:\|gorm:\|validate:' "$f" 2>/dev/null; then
            has_tags=true
            if [ -n "$VERBOSE" ]; then
                log_info "文件 $f 包含注入的标签"
            fi
        fi
    fi
done

# 检查各模块目录
for module_dir in "$INPUT_DIR"/*/; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "${module_dir%/}")
        [[ "$module_name" == backup_* ]] && continue
        for f in "$module_dir"*.pb.go; do
            if [ -f "$f" ]; then
                if grep -q 'json:\|gorm:\|validate:' "$f" 2>/dev/null; then
                    has_tags=true
                    if [ -n "$VERBOSE" ]; then
                        log_info "文件 $f 包含注入的标签"
                    fi
                fi
            fi
        done
    fi
done

if [ "$has_tags" = true ]; then
    log_success "标签注入验证通过"
else
    log_warn "未发现注入的标签，请检查 proto 文件中的 @gotags 注释"
fi

echo ""
log_success "标签注入流程完成 🎉"
echo ""
log_info "使用提示："
echo "  1. 在 proto 文件中使用 @gotags 注释定义标签"
echo "  2. 运行 scripts/generate-modular.sh 生成 protobuf 代码"
echo "  3. 运行此脚本注入结构体标签"
echo ""
echo "ℹ️  标签示例："
echo '  // @gotags: json:"username" gorm:"uniqueIndex" validate:"required"'
echo "  string username = 1;"
