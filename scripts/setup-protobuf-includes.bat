@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

set "NO_PAUSE=false"
set "FORCE=false"
set "PROTOC_RELEASE_VERSION=24.3"
set "REQUIRED_PROTOC_DISPLAY_VERSION=4.24.3"
set "REQUIRED_PROTOC_VERSION=libprotoc 24.3"

:parse_args
if "%~1"=="" goto after_parse_args
if /i "%~1"=="--no-pause" set "NO_PAUSE=true" && shift && goto parse_args
if /i "%~1"=="--force" set "FORCE=true" && shift && goto parse_args
if /i "%~1"=="--help" goto show_help
if /i "%~1"=="-h" goto show_help
echo ❌ 未知选项: %~1
exit /b 1

:show_help
echo 用法: scripts\setup-protobuf-includes.bat [--no-pause] [--force]
echo   --no-pause  执行结束或失败时不暂停
echo   --force     即使 include 文件已存在也重新下载
exit /b 0

:after_parse_args

set "PROTOBUF_INCLUDES_SCRIPT_DIR=%~dp0"
if not exist "%PROTOBUF_INCLUDES_SCRIPT_DIR%setup-protobuf-includes.bat" if exist "%CD%\setup-protobuf-includes.bat" set "PROTOBUF_INCLUDES_SCRIPT_DIR=%CD%\"
if not exist "%PROTOBUF_INCLUDES_SCRIPT_DIR%setup-protobuf-includes.bat" if exist "%CD%\scripts\setup-protobuf-includes.bat" set "PROTOBUF_INCLUDES_SCRIPT_DIR=%CD%\scripts\"
for %%i in ("%PROTOBUF_INCLUDES_SCRIPT_DIR%..") do set "PROTOBUF_INCLUDES_PROJECT_ROOT=%%~fi"
cd /d "%PROTOBUF_INCLUDES_PROJECT_ROOT%"

echo 🔧 设置 Protobuf Include 文件...

call :ensure_go_bin_dir
if errorlevel 1 exit /b 1

call :ensure_protoc_version
if errorlevel 1 exit /b 1

REM 获取 protoc 路径
for /f "tokens=*" %%i in ('where protoc') do set "PROTOC_PATH=%%i"
for %%i in ("%PROTOC_PATH%") do set "PROTOC_DIR=%%~dpi"
set "PROTOC_ROOT=%PROTOC_DIR%.."
set "PROTOC_INCLUDE=%PROTOC_ROOT%\include"

echo 📁 Protoc 路径: %PROTOC_PATH%
echo 📁 Protoc 根目录: %PROTOC_ROOT%
echo 📁 Include 目录: %PROTOC_INCLUDE%
echo 🎯 固定版本: protoc v%REQUIRED_PROTOC_DISPLAY_VERSION% ^(%REQUIRED_PROTOC_VERSION%^)

if exist "%PROTOC_INCLUDE%\google\protobuf\timestamp.proto" if not "%FORCE%"=="true" (
    echo ✅ 标准 protobuf include 文件已存在，跳过下载
    if not "%NO_PAUSE%"=="true" pause
    exit /b 0
)

REM 创建 include 目录
if not exist "%PROTOC_INCLUDE%" (
    echo 📁 创建 include 目录...
    mkdir "%PROTOC_INCLUDE%"
)

REM 创建 google/protobuf 目录
if not exist "%PROTOC_INCLUDE%\google\protobuf" (
    echo 📁 创建 google\protobuf 目录...
    mkdir "%PROTOC_INCLUDE%\google\protobuf"
)

REM 下载标准 protobuf 文件
echo 📥 下载标准 protobuf 文件...

REM 定义需要下载的文件列表
set "PROTO_FILES=descriptor timestamp wrappers struct any empty duration field_mask"

REM 循环下载每个文件
for %%f in (%PROTO_FILES%) do (
    echo 📋 下载 %%f.proto...
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/protocolbuffers/protobuf/v%PROTOC_RELEASE_VERSION%/src/google/protobuf/%%f.proto' -OutFile '%PROTOC_INCLUDE%\google\protobuf\%%f.proto'"
    
    if !errorlevel! neq 0 (
        echo ❌ 下载 %%f.proto 失败
        if not "%NO_PAUSE%"=="true" pause
        exit /b 1
    )
)

REM 检查是否成功
if exist "%PROTOC_INCLUDE%\google\protobuf\timestamp.proto" (
    echo.
    echo ✅ 标准 protobuf 文件设置完成！
    echo 📁 Include 路径: %PROTOC_INCLUDE%
    echo.
    echo 📋 已下载的文件：
    for %%f in (%PROTO_FILES%) do (
        if exist "%PROTOC_INCLUDE%\google\protobuf\%%f.proto" (
            echo   ✓ %%f.proto
        ) else (
            echo   ✗ %%f.proto ^(缺失^)
        )
    )
) else (
    echo ❌ 设置失败，请手动下载 protobuf 文件
    echo 💡 请访问: https://github.com/protocolbuffers/protobuf
    if not "%NO_PAUSE%"=="true" pause
    exit /b 1
)

echo.
echo 🎉 完成！
echo 💡 提示：如果需要 Google APIs 和 gRPC-Gateway 依赖，
echo    generate-modular.bat 会自动调用 setup-dependencies.bat 下载

if not "%NO_PAUSE%"=="true" pause
exit /b 0

:ensure_go_bin_dir
where go >nul 2>nul
if errorlevel 1 (
    echo ❌ Go 未安装，无法确定 protoc 安装目录
    if not "%NO_PAUSE%"=="true" pause
    exit /b 1
)
if "%GOPATH%"=="" for /f "tokens=*" %%i in ('go env GOPATH 2^>nul') do set "GOPATH=%%i"
if "%GOPATH%"=="" (
    echo ❌ 无法获取 GOPATH，请手动设置
    if not "%NO_PAUSE%"=="true" pause
    exit /b 1
)
for /f "tokens=*" %%i in ('go env GOBIN 2^>nul') do set "GO_BIN_DIR=%%i"
if "%GO_BIN_DIR%"=="" set "GO_BIN_DIR=%GOPATH%\bin"
if not exist "%GO_BIN_DIR%" mkdir "%GO_BIN_DIR%" 2>nul
echo ;%PATH%; | find /i ";%GO_BIN_DIR%;" >nul
if errorlevel 1 set "PATH=%GO_BIN_DIR%;%PATH%"
exit /b 0

:ensure_protoc_version
set "actual_protoc_version="
for /f "tokens=*" %%v in ('protoc --version 2^>nul') do set "actual_protoc_version=%%v"
echo(!actual_protoc_version! | findstr /c:"%REQUIRED_PROTOC_VERSION%" >nul
if not errorlevel 1 (
    echo ✅ protoc 版本符合要求: !actual_protoc_version!
    exit /b 0
)

if not "!actual_protoc_version!"=="" (
    echo ⚠️  protoc 版本不匹配，期望 %REQUIRED_PROTOC_VERSION%，当前: !actual_protoc_version!
) else (
    echo ⚠️  protoc 未安装，将自动安装固定版本 v%REQUIRED_PROTOC_DISPLAY_VERSION% ^(%REQUIRED_PROTOC_VERSION%^)
)

set "PROTOC_ZIP=%TEMP%\protoc-%PROTOC_RELEASE_VERSION%-win64.zip"
set "PROTOC_EXTRACT_DIR=%TEMP%\protoc-%PROTOC_RELEASE_VERSION%-win64"
if exist "%PROTOC_EXTRACT_DIR%" rmdir /s /q "%PROTOC_EXTRACT_DIR%" 2>nul
if exist "%PROTOC_ZIP%" del /q "%PROTOC_ZIP%" 2>nul

echo 📦 正在下载 protoc v%REQUIRED_PROTOC_DISPLAY_VERSION%...
powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://github.com/protocolbuffers/protobuf/releases/download/v%PROTOC_RELEASE_VERSION%/protoc-%PROTOC_RELEASE_VERSION%-win64.zip' -OutFile '%PROTOC_ZIP%'"
if errorlevel 1 (
    echo ❌ protoc 下载失败
    if not "%NO_PAUSE%"=="true" pause
    exit /b 1
)

echo 📦 正在安装 protoc 到 %GO_BIN_DIR%...
powershell -NoProfile -Command "Expand-Archive -Path '%PROTOC_ZIP%' -DestinationPath '%PROTOC_EXTRACT_DIR%' -Force"
if errorlevel 1 (
    echo ❌ protoc 解压失败
    if not "%NO_PAUSE%"=="true" pause
    exit /b 1
)

copy /y "%PROTOC_EXTRACT_DIR%\bin\protoc.exe" "%GO_BIN_DIR%\protoc.exe" >nul
if errorlevel 1 (
    echo ❌ protoc 安装失败
    if not "%NO_PAUSE%"=="true" pause
    exit /b 1
)

if not exist "%GO_BIN_DIR%\include" mkdir "%GO_BIN_DIR%\include" 2>nul
xcopy /e /i /y "%PROTOC_EXTRACT_DIR%\include\google" "%GO_BIN_DIR%\include\google" >nul
if errorlevel 1 (
    echo ❌ protoc include 安装失败
    if not "%NO_PAUSE%"=="true" pause
    exit /b 1
)

set "actual_protoc_version="
for /f "tokens=*" %%v in ('"%GO_BIN_DIR%\protoc.exe" --version 2^>nul') do set "actual_protoc_version=%%v"
echo(!actual_protoc_version! | findstr /c:"%REQUIRED_PROTOC_VERSION%" >nul
if errorlevel 1 (
    echo ❌ protoc 版本校验失败，期望 %REQUIRED_PROTOC_VERSION%，当前: !actual_protoc_version!
    if not "%NO_PAUSE%"=="true" pause
    exit /b 1
)

echo ✅ protoc 已切换到固定版本: !actual_protoc_version!
exit /b 0
