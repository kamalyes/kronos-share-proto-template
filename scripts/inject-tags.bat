@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo 🏷️ 注入结构体标签...

cd /d %~dp0..

set "INPUT_DIR=pb"

if "%~1"=="--force" set "FORCE=true"
if "%~1"=="-f" set "FORCE=true"
if "%~1"=="--input" set "INPUT_DIR=%~2"
if "%~1"=="-i" set "INPUT_DIR=%~2"

where protoc-go-inject-tag >nul 2>nul
if !errorlevel! neq 0 (
    echo 📦 安装 protoc-go-inject-tag...
    go install github.com/kamalyes/protoc-go-inject-tag@c54ecfe
    if !errorlevel! neq 0 (
        echo ❌ protoc-go-inject-tag 安装失败
        pause
        exit /b 1
    )
)

if not exist "%INPUT_DIR%" (
    echo ❌ 输入目录不存在: %INPUT_DIR%
    echo 请先运行 scripts\generate-modular.bat 生成 protobuf 代码
    pause
    exit /b 1
)

echo 🏷️ 开始注入结构体标签...

if exist "%INPUT_DIR%\*.pb.go" (
    protoc-go-inject-tag --input="%INPUT_DIR%\*.pb.go"
    if !errorlevel! neq 0 (
        echo ⚠️ 根目录标签注入失败，跳过...
    ) else (
        echo ✅ 根目录标签注入完成
    )
)

for /d %%d in ("%INPUT_DIR%\*") do (
    set "module_name=%%~nd"
    if exist "%%d\*.pb.go" (
        echo 🏷️ 注入 !module_name! 模块标签...
        protoc-go-inject-tag --input="%%d\*.pb.go"
        if !errorlevel! neq 0 (
            echo ⚠️ !module_name! 模块标签注入失败，跳过...
        ) else (
            echo ✅ !module_name! 模块标签注入完成
        )
    )
)

echo ✅ 所有模块标签注入完成
pause
