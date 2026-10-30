@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

rem 一键打通：装工具链 → 生成 pb/gateway/swagger → 解析依赖 → 自检
rem
rem 四步顺序不能换：pb/ 为空时 go mod tidy 会把 github.com/kamalyes/kronos-share-proto-template/pb/<module>
rem 当成远程模块去解析（只有 validation 的测试文件 import 它们），于是报一串
rem "Repository not found"，让人以为是仓库或网络问题。
rem 刚 kopy new 出来的项目第一反应往往就是 go mod tidy，所以把顺序收进这一条命令。

set "SKIP_SETUP=false"
set "SKIP_TEST=false"

:parse_args
if "%~1"=="" goto after_parse_args
if /i "%~1"=="--skip-setup" set "SKIP_SETUP=true" && shift && goto parse_args
if /i "%~1"=="--skip-test" set "SKIP_TEST=true" && shift && goto parse_args
if /i "%~1"=="--help" goto show_help
if /i "%~1"=="-h" goto show_help
echo ❌ 未知选项: %~1
exit /b 1

:show_help
echo 用法: scripts\init.bat [--skip-setup] [--skip-test]
echo   --skip-setup  跳过工具链安装（protoc 与 5 个插件已就位时用）
echo   --skip-test   跳过 go test 自检
exit /b 0

:after_parse_args

set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fi"
cd /d "%PROJECT_ROOT%"

echo ========================================
echo 🚀 初始化协议中心
echo ========================================
echo.

if "%SKIP_SETUP%"=="true" (
    echo ⚠️  [1/4] 按 --skip-setup 跳过工具链安装
) else (
    echo ℹ️  [1/4] 安装工具链：固定版本 protoc + 5 个插件 + googleapis
    call "%SCRIPT_DIR%setup-all.bat" --no-pause
    if errorlevel 1 (
        echo ❌ 工具链安装失败，已中断
        exit /b 1
    )
)
echo.

echo ℹ️  [2/4] 生成 pb / gateway / swagger 并注入 struct tag
call "%SCRIPT_DIR%generate-modular.bat"
if errorlevel 1 (
    echo ❌ 代码生成失败，已中断
    exit /b 1
)
echo.

echo ℹ️  [3/4] 解析依赖（pb/ 已存在，github.com/kamalyes/kronos-share-proto-template/pb/... 才解析得到）
go mod tidy
if errorlevel 1 (
    echo ❌ go mod tidy 失败，已中断
    exit /b 1
)
echo ✅ go mod tidy 完成
echo.

echo ℹ️  [4/4] 自检
go build ./...
if errorlevel 1 (
    echo ❌ go build 失败，已中断
    exit /b 1
)
echo ✅ go build ./... 通过
if "%SKIP_TEST%"=="true" (
    echo ⚠️  按 --skip-test 跳过测试
) else (
    go test ./...
    if errorlevel 1 (
        echo ❌ go test 失败，已中断
        exit /b 1
    )
    echo ✅ go test ./... 通过
)

echo.
echo ========================================
echo ✅ 初始化完成
echo ========================================
echo.
echo 下一步：
echo   go run bootstrap                       启动文档网关，浏览聚合 OpenAPI
echo   git add -A ^&^& git commit -m "chore: bootstrap share proto"
echo.
echo 注意 pb/ 要一起提交：下游服务按 commit 引用本模块，不入库就是一个没有 Go 代码的空模块。
exit /b 0
