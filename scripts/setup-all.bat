@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

set "NO_PAUSE=false"

:parse_args
if "%~1"=="" goto after_parse_args
if /i "%~1"=="--no-pause" set "NO_PAUSE=true" && shift && goto parse_args
if /i "%~1"=="--help" goto show_help
if /i "%~1"=="-h" goto show_help
echo ❌ 未知选项: %~1
exit /b 1

:show_help
echo 用法: scripts\setup-all.bat [--no-pause]
echo   --no-pause  子脚本和结束时不暂停，适合生成脚本调用
exit /b 0

:after_parse_args

set "SETUP_ALL_SCRIPT_DIR=%~dp0"
if not exist "%SETUP_ALL_SCRIPT_DIR%setup-protobuf-includes.bat" if exist "%CD%\setup-protobuf-includes.bat" set "SETUP_ALL_SCRIPT_DIR=%CD%\"
if not exist "%SETUP_ALL_SCRIPT_DIR%setup-protobuf-includes.bat" if exist "%CD%\scripts\setup-protobuf-includes.bat" set "SETUP_ALL_SCRIPT_DIR=%CD%\scripts\"
for %%i in ("%SETUP_ALL_SCRIPT_DIR%..") do set "SETUP_ALL_PROJECT_ROOT=%%~fi"

echo ========================================
echo 🚀 一键安装所有依赖
echo ========================================
echo.

REM 获取项目根目录
cd /d "%SETUP_ALL_PROJECT_ROOT%"

echo.
echo ========================================
echo 📥 安装依赖文件
echo ========================================
echo.

REM 设置 Protobuf Include 文件
echo [1/2] 设置 Protobuf Include 文件...
if exist "%SETUP_ALL_SCRIPT_DIR%setup-protobuf-includes.bat" (
    call "%SETUP_ALL_SCRIPT_DIR%setup-protobuf-includes.bat" --no-pause
    if !errorlevel! neq 0 (
        echo ❌ Protobuf Include 文件设置失败
        if not "%NO_PAUSE%"=="true" pause
        exit /b 1
    )
) else (
    echo ❌ 未找到 %SETUP_ALL_SCRIPT_DIR%setup-protobuf-includes.bat
    if not "%NO_PAUSE%"=="true" pause
    exit /b 1
)
echo.

REM 安装 protoc 插件并下载 Google APIs 和 gRPC-Gateway 依赖
echo [2/2] 安装 protoc 插件并下载 Google APIs 和 gRPC-Gateway 依赖...
if exist "%SETUP_ALL_SCRIPT_DIR%setup-dependencies.bat" (
    call "%SETUP_ALL_SCRIPT_DIR%setup-dependencies.bat" --no-pause
    if !errorlevel! neq 0 (
        echo ❌ protoc 插件安装或依赖下载失败
        if not "%NO_PAUSE%"=="true" pause
        exit /b 1
    )
) else (
    echo ❌ 未找到 %SETUP_ALL_SCRIPT_DIR%setup-dependencies.bat
    if not "%NO_PAUSE%"=="true" pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ 所有依赖安装完成！
echo ========================================
echo.
echo 📝 下一步：
echo   1. 运行 scripts\generate-modular.bat 生成 protobuf 代码
echo   2. 运行 go mod tidy 更新 Go 模块依赖
echo   3. 运行 go run ./bootstrap 启动服务
echo.

if not "%NO_PAUSE%"=="true" pause
