@echo off
setlocal enabledelayedexpansion

:: Engine IM Push Service Google APIs 和 gRPC-Gateway 依赖下载脚本
:: 下载 gRPC-Gateway 所需的依赖 proto 文件到 GOPATH

chcp 65001 >nul

set "TOOLS_ONLY=false"
set "INJECT_TAG_ONLY=false"
set "NO_PAUSE=false"
set "FORCE=false"

:parse_args
if "%~1"=="" goto after_parse_args
if /i "%~1"=="--tools-only" set "TOOLS_ONLY=true" && shift && goto parse_args
if /i "%~1"=="--inject-tag-only" set "INJECT_TAG_ONLY=true" && shift && goto parse_args
if /i "%~1"=="--no-pause" set "NO_PAUSE=true" && shift && goto parse_args
if /i "%~1"=="--force" set "FORCE=true" && shift && goto parse_args
if /i "%~1"=="--help" goto show_help
if /i "%~1"=="-h" goto show_help
echo ❌ 未知选项: %~1
exit /b 1

:show_help
echo 用法: scripts\setup-dependencies.bat [--tools-only] [--inject-tag-only] [--no-pause] [--force]
echo   --tools-only  仅安装并校验 protoc 插件版本，不下载 proto include 依赖
echo   --inject-tag-only  仅安装并校验 protoc-go-inject-tag
echo   --no-pause    执行结束或失败时不暂停
echo   --force       依赖目录已存在时重新下载
exit /b 0

:after_parse_args

set "DEPENDENCIES_SCRIPT_DIR=%~dp0"
if not exist "%DEPENDENCIES_SCRIPT_DIR%setup-dependencies.bat" if exist "%CD%\setup-dependencies.bat" set "DEPENDENCIES_SCRIPT_DIR=%CD%\"
if not exist "%DEPENDENCIES_SCRIPT_DIR%setup-dependencies.bat" if exist "%CD%\scripts\setup-dependencies.bat" set "DEPENDENCIES_SCRIPT_DIR=%CD%\scripts\"
for %%i in ("%DEPENDENCIES_SCRIPT_DIR%..") do set "DEPENDENCIES_PROJECT_ROOT=%%~fi"
cd /d "%DEPENDENCIES_PROJECT_ROOT%"

if "%INJECT_TAG_ONLY%"=="true" (
    echo 🔐 安装并校验 protoc-go-inject-tag 版本...
) else if "%TOOLS_ONLY%"=="true" (
    echo 🔐 安装并校验 protoc 插件版本...
) else (
    echo 📦 下载 Google APIs 和 gRPC-Gateway 依赖到 GOPATH...
)

where go >nul 2>nul
if !errorlevel! neq 0 (
    echo ❌ Go 未安装，请先安装 Go 环境
    exit /b 1
)

:: 检查 GOPATH
if "%GOPATH%"=="" (
    echo ⚠️  GOPATH 未设置，使用默认值...
    for /f "tokens=*" %%i in ('go env GOPATH') do set "GOPATH=%%i"
    if "!GOPATH!"=="" (
        echo ❌ 无法获取 GOPATH，请手动设置
        if not "%NO_PAUSE%"=="true" pause
        exit /b 1
    )
)

:: 配置变量
set "GOOGLEAPIS_VERSION=master"
set "GRPC_GATEWAY_VERSION=v2.29.0"
set "REQUIRED_PROTOC_GEN_GO_VERSION=v1.36.11"
set "REQUIRED_PROTOC_GEN_GO_GRPC_VERSION=1.6.1"
set "REQUIRED_GRPC_GATEWAY_VERSION=%GRPC_GATEWAY_VERSION%"
set "REQUIRED_OPENAPIV2_VERSION=%GRPC_GATEWAY_VERSION%"
set "REQUIRED_INJECT_TAG_VERSION=1b80c07"
set "INJECT_TAG_MODULE=github.com/kamalyes/protoc-go-inject-tag@%REQUIRED_INJECT_TAG_VERSION%"
set "INJECT_TAG_LDFLAGS=-X github.com/kamalyes/protoc-go-inject-tag/bootstrap.Version=%REQUIRED_INJECT_TAG_VERSION%"
set "GOPATH_SRC_DIR=%GOPATH%\src\github.com"
set "GOOGLEAPIS_DIR=%GOPATH_SRC_DIR%\googleapis"
set "GRPC_GATEWAY_DIR=%GOPATH_SRC_DIR%\grpc-ecosystem\grpc-gateway"
set "KAMALYES_GO_GRPC_GATEWAY_DIR=%GOPATH_SRC_DIR%\kamalyes\go-rpc-gateway"

set "GO_BIN_DIR="
for /f "tokens=*" %%i in ('go env GOBIN 2^>nul') do set "GO_BIN_DIR=%%i"
if "%GO_BIN_DIR%"=="" set "GO_BIN_DIR=%GOPATH%\bin"
if not exist "%GO_BIN_DIR%" mkdir "%GO_BIN_DIR%" 2>nul
echo ;%PATH%; | find /i ";%GO_BIN_DIR%;" >nul
if errorlevel 1 set "PATH=%GO_BIN_DIR%;%PATH%"

echo 🔍 GOPATH: %GOPATH%
echo 🔍 Go bin: %GO_BIN_DIR%
echo 🎯 目标目录 1: %GOOGLEAPIS_DIR%
echo 🎯 目标目录 2: %GRPC_GATEWAY_DIR%
echo 🎯 目标目录 3: %KAMALYES_GO_GRPC_GATEWAY_DIR%

if "%INJECT_TAG_ONLY%"=="true" (
    echo 🔐 校验 protoc-go-inject-tag 版本...
    call :ensure_inject_tag_version
    if errorlevel 1 exit /b 1
) else (
    call :ensure_generation_tools
    if errorlevel 1 exit /b 1
)

if "%INJECT_TAG_ONLY%"=="true" (
    echo ✅ protoc-go-inject-tag 版本校验完成
    exit /b 0
)

if "%TOOLS_ONLY%"=="true" (
    echo ✅ protoc 插件版本校验完成
    exit /b 0
)

:: 创建目录
if not exist "%GOPATH_SRC_DIR%" (
    echo 📁 创建目录: %GOPATH_SRC_DIR%
    mkdir "%GOPATH_SRC_DIR%" 2>nul
)

if not exist "%GOPATH_SRC_DIR%\googleapis" (
    echo 📁 创建目录: %GOPATH_SRC_DIR%\googleapis
    mkdir "%GOPATH_SRC_DIR%\googleapis" 2>nul
)

if not exist "%GOPATH_SRC_DIR%\grpc-ecosystem" (
    echo 📁 创建目录: %GOPATH_SRC_DIR%\grpc-ecosystem
    mkdir "%GOPATH_SRC_DIR%\grpc-ecosystem" 2>nul
)

if not exist "%GOPATH_SRC_DIR%\kamalyes" (
    echo 📁 创建目录: %GOPATH_SRC_DIR%\kamalyes
    mkdir "%GOPATH_SRC_DIR%\kamalyes" 2>nul
)

:: 下载 Google APIs
echo 🚀 下载 Google APIs...
:: 检查是否已存在
if exist "%GOOGLEAPIS_DIR%" (
    if not "%FORCE%"=="true" (
        echo ✅ Google APIs 已存在，跳过下载
        goto download_grpc_gateway
    )
    echo ♻️  重新下载 Google APIs...
    rmdir /s /q "%GOOGLEAPIS_DIR%" 2>nul
)

:: 检查下载工具
where git >nul 2>nul
if !errorlevel! equ 0 (
    echo 📥 使用 Git 下载 googleapis...
    git clone --depth=1 --branch="%GOOGLEAPIS_VERSION%" https://github.com/googleapis/googleapis.git "%GOOGLEAPIS_DIR%"
    
    if !errorlevel! neq 0 (
        echo ❌ Git 下载 googleapis 失败
        goto error_exit
    )
) else (
    echo ❌ 需要 Git 来下载依赖，请安装 Git
    goto error_exit
)

:download_grpc_gateway
echo 🚀 下载 gRPC-Gateway...
:: 检查是否已存在
if exist "%GRPC_GATEWAY_DIR%" (
    if not "%FORCE%"=="true" (
        echo ✅ gRPC-Gateway 已存在，跳过下载
        goto download_kamalyes_go_rpc_gateway
    )
    echo ♻️  重新下载 gRPC-Gateway...
    rmdir /s /q "%GRPC_GATEWAY_DIR%" 2>nul
)

where git >nul 2>nul
if !errorlevel! equ 0 (
    echo 📥 使用 Git 下载 grpc-gateway...
    git clone --depth=1 --branch="%GRPC_GATEWAY_VERSION%" https://github.com/grpc-ecosystem/grpc-gateway.git "%GRPC_GATEWAY_DIR%"
    
    if !errorlevel! neq 0 (
        echo ❌ Git 下载 grpc-gateway 失败
        goto error_exit
    )
) else (
    echo ❌ 需要 Git 来下载依赖，请安装 Git
    goto error_exit
)

:download_kamalyes_go_rpc_gateway
echo 🚀 下载 kamalyes/go-rpc-gateway...
:: 检查是否已存在
if exist "%KAMALYES_GO_GRPC_GATEWAY_DIR%" (
    if not "%FORCE%"=="true" (
        echo ✅ kamalyes/go-rpc-gateway 已存在，跳过下载
        goto verify_downloads
    )
    echo ♻️  重新下载 kamalyes/go-rpc-gateway...
    rmdir /s /q "%KAMALYES_GO_GRPC_GATEWAY_DIR%" 2>nul
)

where git >nul 2>nul
if !errorlevel! equ 0 (
    echo 📥 使用 Git 下载 kamalyes/go-rpc-gateway...
    git clone --depth=1 https://github.com/kamalyes/go-rpc-gateway.git "%KAMALYES_GO_GRPC_GATEWAY_DIR%"
    
    if !errorlevel! neq 0 (
        echo ❌ Git 下载 kamalyes/go-rpc-gateway 失败
        goto error_exit
    )
) else (
    echo ❌ 需要 Git 来下载依赖，请安装 Git
    goto error_exit
)

:verify_downloads
:: 验证下载
echo 🔍 验证下载结果...

set "validation_failed=false"

if exist "%GOOGLEAPIS_DIR%\google\api\annotations.proto" (
    echo ✅ Google APIs annotations.proto 存在
) else (
    echo ❌ Google APIs annotations.proto 缺失
    set "validation_failed=true"
)

if exist "%GOOGLEAPIS_DIR%\google\api\http.proto" (
    echo ✅ Google APIs http.proto 存在
) else (
    echo ❌ Google APIs http.proto 缺失
    set "validation_failed=true"
)

if exist "%GRPC_GATEWAY_DIR%\protoc-gen-openapiv2\options\annotations.proto" (
    echo ✅ gRPC-Gateway openapiv2 annotations.proto 存在
) else (
    echo ❌ gRPC-Gateway openapiv2 annotations.proto 缺失
    set "validation_failed=true"
)

if "%validation_failed%"=="true" (
    echo ❌ 依赖验证失败，请检查下载
    goto error_exit
)

echo.
echo ✅ 所有依赖下载完成到 GOPATH！
echo.
echo 📁 已下载的关键文件：
echo   - %GOOGLEAPIS_DIR%\google\api\annotations.proto
echo   - %GOOGLEAPIS_DIR%\google\api\http.proto  
echo   - %GOOGLEAPIS_DIR%\google\protobuf\timestamp.proto
echo   - %GOOGLEAPIS_DIR%\google\protobuf\wrappers.proto
echo   - %GRPC_GATEWAY_DIR%\protoc-gen-openapiv2\options\annotations.proto
echo   - %KAMALYES_GO_GRPC_GATEWAY_DIR%\proto\common.proto
echo.
echo 🎉 现在可以使用 gRPC-Gateway 功能了！
echo 💡 提示：generate-modular.bat 将自动从 GOPATH 查找这些文件

echo.
echo ✅ 设置完成！
echo 💡 提示：
echo   - 依赖文件已放置在 GOPATH 下
echo   - 运行 scripts\generate-modular.bat 将自动从 GOPATH 使用这些依赖
echo   - 如需更新依赖，请重新运行此脚本

if not "%NO_PAUSE%"=="true" pause
exit /b 0

:check_command_version
set "check_cmd=%~1"
set "expected_version=%~2"
set "install_pkg=%~3"
set "actual_version="

for /f "tokens=*" %%v in ('%check_cmd% --version 2^>nul') do set "actual_version=%%v"
echo(!actual_version! | findstr /c:"%expected_version%" >nul
if not errorlevel 1 (
    echo ✅ %check_cmd% 版本符合要求: !actual_version!
    exit /b 0
)

echo ⚠️  %check_cmd% 版本不匹配，期望 %expected_version%，当前: !actual_version!
echo 📦 正在安装 %install_pkg%
go install %install_pkg%
if !errorlevel! neq 0 (
    echo ❌ 安装 %install_pkg% 失败
    exit /b 1
)

set "actual_version="
for /f "tokens=*" %%v in ('%check_cmd% --version 2^>nul') do set "actual_version=%%v"
echo(!actual_version! | findstr /c:"%expected_version%" >nul
if errorlevel 1 (
    echo ❌ %check_cmd% 版本校验失败，期望 %expected_version%，当前: !actual_version!
    exit /b 1
)

echo ✅ %check_cmd% 已切换到要求版本: !actual_version!
exit /b 0

:ensure_generation_tools
echo 🔐 校验 protoc 插件版本...
call :check_command_version protoc-gen-go %REQUIRED_PROTOC_GEN_GO_VERSION% google.golang.org/protobuf/cmd/protoc-gen-go@%REQUIRED_PROTOC_GEN_GO_VERSION%
if errorlevel 1 exit /b 1
call :check_command_version protoc-gen-go-grpc %REQUIRED_PROTOC_GEN_GO_GRPC_VERSION% google.golang.org/grpc/cmd/protoc-gen-go-grpc@v%REQUIRED_PROTOC_GEN_GO_GRPC_VERSION%
if errorlevel 1 exit /b 1
call :check_command_version protoc-gen-grpc-gateway %REQUIRED_GRPC_GATEWAY_VERSION% github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@%REQUIRED_GRPC_GATEWAY_VERSION%
if errorlevel 1 exit /b 1
call :check_command_version protoc-gen-openapiv2 %REQUIRED_OPENAPIV2_VERSION% github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2@%REQUIRED_OPENAPIV2_VERSION%
if errorlevel 1 exit /b 1
call :ensure_inject_tag_version
if errorlevel 1 exit /b 1
echo ✅ 所有必需插件可用
exit /b 0

:ensure_inject_tag_version
set "actual_version="
for /f "tokens=*" %%v in ('protoc-go-inject-tag --version 2^>nul') do set "actual_version=%%v"
echo(!actual_version! | findstr /c:"%REQUIRED_INJECT_TAG_VERSION%" >nul
if not errorlevel 1 (
    echo ✅ protoc-go-inject-tag 版本符合要求: !actual_version!
    exit /b 0
)

echo ⚠️  protoc-go-inject-tag 版本不匹配，期望 %REQUIRED_INJECT_TAG_VERSION%，当前: !actual_version!
echo 📦 正在安装 %INJECT_TAG_MODULE% 并注入版本号
go install -ldflags "%INJECT_TAG_LDFLAGS%" %INJECT_TAG_MODULE%
if !errorlevel! neq 0 (
    echo ❌ protoc-go-inject-tag 安装失败
    exit /b 1
)

set "actual_version="
for /f "tokens=*" %%v in ('protoc-go-inject-tag --version 2^>nul') do set "actual_version=%%v"
echo(!actual_version! | findstr /c:"%REQUIRED_INJECT_TAG_VERSION%" >nul
if errorlevel 1 (
    echo ❌ protoc-go-inject-tag 版本校验失败，期望 %REQUIRED_INJECT_TAG_VERSION%，当前: !actual_version!
    exit /b 1
)

echo ✅ protoc-go-inject-tag 已切换到要求版本: !actual_version!
exit /b 0

:error_exit
echo ❌ 依赖下载失败
if not "%NO_PAUSE%"=="true" pause
exit /b 1
