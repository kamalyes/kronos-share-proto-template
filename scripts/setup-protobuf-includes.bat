@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo 🔧 设置 Protobuf Include 文件...

for /f "tokens=*" %%i in ('where protoc') do set "PROTOC_PATH=%%i"
for %%i in ("%PROTOC_PATH%") do set "PROTOC_DIR=%%~dpi"
set "PROTOC_ROOT=%PROTOC_DIR%.."
set "PROTOC_INCLUDE=%PROTOC_ROOT%\include"

echo 📁 Protoc 路径: %PROTOC_PATH%
echo 📁 Include 目录: %PROTOC_INCLUDE%

if not exist "%PROTOC_INCLUDE%" mkdir "%PROTOC_INCLUDE%"
if not exist "%PROTOC_INCLUDE%\google\protobuf" mkdir "%PROTOC_INCLUDE%\google\protobuf"

echo 📥 下载标准 protobuf 文件...

set "PROTO_FILES=descriptor timestamp wrappers struct any empty duration field_mask"

for %%f in (%PROTO_FILES%) do (
    echo 📋 下载 %%f.proto...
    powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/protocolbuffers/protobuf/main/src/google/protobuf/%%f.proto' -OutFile '%PROTOC_INCLUDE%\google\protobuf\%%f.proto'"
    if !errorlevel! neq 0 (
        echo ❌ 下载 %%f.proto 失败
        pause
        exit /b 1
    )
)

if exist "%PROTOC_INCLUDE%\google\protobuf\timestamp.proto" (
    echo.
    echo ✅ 标准 protobuf 文件设置完成！
) else (
    echo ❌ 设置失败，请手动下载 protobuf 文件
    pause
    exit /b 1
)

pause
