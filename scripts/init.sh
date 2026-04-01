#!/usr/bin/env bash
# 一键打通：装工具链 → 生成 pb/gateway/swagger → 解析依赖 → 自检
#
# 存在的理由是这四步的顺序不能换：pb/ 为空时 `go mod tidy` 会把
# <% .ModuleName %>/pb/<module> 当成远程模块去解析（只有 validation 的测试文件
# import 它们），于是报一串 "Repository not found"，让人以为是仓库或网络问题。
# 刚 kopy new 出来的项目第一反应往往就是 go mod tidy，所以把顺序收进这一条命令。
#
# 幂等：重复执行只是重新生成并再 tidy 一遍，不会累积副作用。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"
project_root

SKIP_SETUP=0
SKIP_TEST=0
for arg in "$@"; do
    case "$arg" in
        --skip-setup)
            SKIP_SETUP=1
            ;;
        --skip-test)
            SKIP_TEST=1
            ;;
        --help|-h)
            echo "用法: bash scripts/init.sh [--skip-setup] [--skip-test]"
            echo "  --skip-setup  跳过工具链安装（protoc 与 5 个插件已就位时用）"
            echo "  --skip-test   跳过 go test 自检"
            exit 0
            ;;
        *)
            log_error "未知选项: $arg"
            exit 1
            ;;
    esac
done

echo "========================================"
echo "🚀 初始化协议中心"
echo "========================================"
echo ""

if [[ "$SKIP_SETUP" == 0 ]]; then
    log_info "[1/4] 安装工具链：固定版本 protoc + 5 个插件 + googleapis"
    bash "$SCRIPT_DIR/setup-all.sh" --no-pause
else
    log_warn "[1/4] 按 --skip-setup 跳过工具链安装"
fi
echo ""

log_info "[2/4] 生成 pb / gateway / swagger 并注入 struct tag"
bash "$SCRIPT_DIR/generate-modular.sh"
echo ""

log_info "[3/4] 解析依赖（pb/ 已存在，<% .ModuleName %>/pb/... 才解析得到）"
go mod tidy
log_success "go mod tidy 完成"
echo ""

log_info "[4/4] 自检"
go build ./...
log_success "go build ./... 通过"
if [[ "$SKIP_TEST" == 0 ]]; then
    go test ./...
    log_success "go test ./... 通过"
else
    log_warn "按 --skip-test 跳过测试"
fi

echo ""
echo "========================================"
log_success "初始化完成"
echo "========================================"
echo ""
echo "下一步："
echo "  go run bootstrap                       # 启动文档网关，浏览聚合 OpenAPI"
echo "  git add -A && git commit -m \"chore: bootstrap share proto\""
echo ""
echo "注意 pb/ 要一起提交：下游服务按 commit 引用本模块，不入库就是一个没有 Go 代码的空模块。"
