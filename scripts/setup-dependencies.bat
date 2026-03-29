@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo 📦 下载 Google APIs 和 gRPC-Gateway 依赖到 GOPATH...

if "%GOPATH%"=="" (
    echo ❌ GOPATH 未设置，请先设置 GOPATH 环境变量
    pause
    exit /b 1
)

set "GOOGLEAPIS_VERSION=master"
set "GRPC_GATEWAY_VERSION=v2.19.0"
set "GOPATH_SRC_DIR=%GOPATH%\src\github.com"
set "GOOGLEAPIS_DIR=%GOPATH_SRC_DIR%\googleapis"
set "GRPC_GATEWAY_DIR=%GOPATH_SRC_DIR%\grpc-ecosystem\grpc-gateway"

echo 🔍 GOPATH: %GOPATH%
echo 🎯 目标目录 1: %GOOGLEAPIS_DIR%
echo 🎯 目标目录 2: %GRPC_GATEWAY_DIR%

if not exist "%GOPATH_SRC_DIR%" mkdir "%GOPATH_SRC_DIR%" 2>nul
if not exist "%GOPATH_SRC_DIR%\googleapis" mkdir "%GOPATH_SRC_DIR%\googleapis" 2>nul
if not exist "%GOPATH_SRC_DIR%\grpc-ecosystem" mkdir "%GOPATH_SRC_DIR%\grpc-ecosystem" 2>nul

echo 🚀 下载 Google APIs...
if not exist "%GOOGLEAPIS_DIR%" (
    where git >nul 2>nul
    if !errorlevel! equ 0 (
        echo 📥 使用 Git 下载 googleapis...
        git clone --depth=1 --branch="%GOOGLEAPIS_VERSION%" https://github.com/googleapis/googleapis.git "%GOOGLEAPIS_DIR%"
        if !errorlevel! neq 0 (
            echo ❌ Git 下载 googleapis 失败
            pause
            exit /b 1
        )
    ) else (
        echo ❌ 需要 Git 来下载依赖，请安装 Git
        pause
        exit /b 1
    )
) else (
    echo ✅ Google APIs 已存在，跳过下载
)

echo 🚀 下载 gRPC-Gateway...
if not exist "%GRPC_GATEWAY_DIR%" (
    where git >nul 2>nul
    if !errorlevel! equ 0 (
        echo 📥 使用 Git 下载 grpc-gateway...
        git clone --depth=1 --branch="%GRPC_GATEWAY_VERSION%" https://github.com/grpc-ecosystem/grpc-gateway.git "%GRPC_GATEWAY_DIR%"
        if !errorlevel! neq 0 (
            echo ❌ Git 下载 grpc-gateway 失败
            pause
            exit /b 1
        )
    ) else (
        echo ❌ 需要 Git 来下载依赖，请安装 Git
        pause
        exit /b 1
    )
) else (
    echo ✅ gRPC-Gateway 已存在，跳过下载
)

echo 🔍 验证下载结果...
set "validation_failed=false"

if exist "%GOOGLEAPIS_DIR%\google\api\annotations.proto" (
    echo ✅ Google APIs annotations.proto 存在
) else (
    echo ❌ Google APIs annotations.proto 缺失
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
    pause
    exit /b 1
)

echo.
echo ✅ 所有依赖下载完成到 GOPATH！
pause
