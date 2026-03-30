#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REQUIRED_PROTOC_VERSION="libprotoc 24.3"

if [[ -t 1 ]]; then
    COLOR_RED=$'\033[31m'
    COLOR_GREEN=$'\033[32m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_CYAN=$'\033[36m'
    COLOR_RESET=$'\033[0m'
else
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_CYAN=""
    COLOR_RESET=""
fi

log_info() {
    echo "${COLOR_CYAN}ℹ️  $1${COLOR_RESET}"
}

log_success() {
    echo "${COLOR_GREEN}✅ $1${COLOR_RESET}"
}

log_warn() {
    echo "${COLOR_YELLOW}⚠️  $1${COLOR_RESET}"
}

log_error() {
    echo "${COLOR_RED}❌ $1${COLOR_RESET}" >&2
}

project_root() {
    cd "$PROJECT_ROOT"
}

ensure_go() {
    if ! command -v go >/dev/null 2>&1; then
        log_error "Go 未安装，请先安装 Go 环境"
        return 1
    fi
    log_success "Go 环境已安装"
}

ensure_gopath() {
    if [[ -z "${GOPATH:-}" ]]; then
        GOPATH="$(go env GOPATH)"
        export GOPATH
    fi

    if [[ -z "$GOPATH" ]]; then
        log_error "GOPATH 环境变量未设置"
        log_warn "请设置 GOPATH 环境变量"
        return 1
    fi
    log_success "GOPATH: $GOPATH"
}

ensure_go_bin_on_path() {
    ensure_go
    ensure_gopath

    GO_BIN_DIR="$(go env GOBIN 2>/dev/null || true)"
    if [[ -z "$GO_BIN_DIR" ]]; then
        GO_BIN_DIR="$GOPATH/bin"
    fi

    mkdir -p "$GO_BIN_DIR"
    case ":$PATH:" in
        *":$GO_BIN_DIR:"*) ;;
        *) export PATH="$GO_BIN_DIR:$PATH" ;;
    esac
    export GO_BIN_DIR
    log_success "Go bin: $GO_BIN_DIR"
}

ensure_protoc() {
    if [[ ! -f "$GO_BIN_DIR/protoc" ]]; then
        log_error "protoc v${REQUIRED_PROTOC_VERSION} 未安装于 $GO_BIN_DIR/protoc"
        log_warn "请运行 scripts/setup-all.sh --no-pause 自动安装固定版本"
        return 1
    fi

    local actual
    actual="$("$GO_BIN_DIR/protoc" --version 2>/dev/null || true)"
    log_success "protoc 版本: $actual"
}

require_script() {
    local script_name="$1"
    if [[ ! -f "$SCRIPT_DIR/$script_name" ]]; then
        log_error "未找到脚本: $SCRIPT_DIR/$script_name"
        return 1
    fi
}

has_proto_files() {
    compgen -G "$1/*.proto" >/dev/null
}

has_go_pb_files() {
    compgen -G "$1/*.pb.go" >/dev/null
}
