@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

call "%~dp0common.bat"
call "%SCRIPT_DIR%common.bat" project_root

set "INPUT_DIR=pb"

:parse_args
if "%~1"=="" goto main
if /i "%~1"=="--input" goto set_input
if /i "%~1"=="-i" goto set_input
if /i "%~1"=="--help" goto show_help
if /i "%~1"=="-h" goto show_help
call "%SCRIPT_DIR%common.bat" log_error "未知选项: %~1"
exit /b 1

:set_input
if "%~2"=="" (
	call "%SCRIPT_DIR%common.bat" log_error "%~1 需要指定目录"
	exit /b 1
)
set "INPUT_DIR=%~2"
shift
shift
goto parse_args

:show_help
echo 用法: scripts\prepare-pb-output.bat [--input DIR]
echo   清空并重建 DIR，确保生成前没有旧产物残留
exit /b 0

:main
if "%INPUT_DIR%"=="" (
	call "%SCRIPT_DIR%common.bat" log_error "输出目录不能为空"
	exit /b 1
)
if "%INPUT_DIR%"=="." (
	call "%SCRIPT_DIR%common.bat" log_error "拒绝清空项目根目录"
	exit /b 1
)
if "%INPUT_DIR%"==".." (
	call "%SCRIPT_DIR%common.bat" log_error "拒绝清空项目父目录"
	exit /b 1
)

call "%SCRIPT_DIR%common.bat" log_info "清空 %INPUT_DIR% 输出目录..."
if exist "%INPUT_DIR%" rmdir /s /q "%INPUT_DIR%"
mkdir "%INPUT_DIR%"
exit /b 0
