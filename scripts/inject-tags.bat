@echo off
setlocal enabledelayedexpansion

:: {{.ProjectName}} 标签注入脚本
:: 使用 protoc-go-inject-tag 为生成的 Go 结构体注入标签

chcp 65001 >nul

:: 获取项目根目录
set "INJECT_TAGS_SCRIPT_DIR=%~dp0"
if not exist "%INJECT_TAGS_SCRIPT_DIR%setup-dependencies.bat" if exist "%CD%\setup-dependencies.bat" set "INJECT_TAGS_SCRIPT_DIR=%CD%\"
if not exist "%INJECT_TAGS_SCRIPT_DIR%setup-dependencies.bat" if exist "%CD%\scripts\setup-dependencies.bat" set "INJECT_TAGS_SCRIPT_DIR=%CD%\scripts\"
for %%i in ("%INJECT_TAGS_SCRIPT_DIR%..") do set "INJECT_TAGS_PROJECT_ROOT=%%~fi"
cd /d "%INJECT_TAGS_PROJECT_ROOT%"

set "VERBOSE="
set "FORCE="
set "INPUT_DIR=pb"
set "SKIP_TOOL_CHECK="

:: 解析命令行参数
:parse_args
if "%~1"=="" goto main
if /i "%~1"=="--verbose" set "VERBOSE=true" && shift && goto parse_args
if /i "%~1"=="-v" set "VERBOSE=true" && shift && goto parse_args
if /i "%~1"=="--force" set "FORCE=true" && shift && goto parse_args
if /i "%~1"=="-f" set "FORCE=true" && shift && goto parse_args
if /i "%~1"=="--skip-tool-check" set "SKIP_TOOL_CHECK=true" && shift && goto parse_args
if /i "%~1"=="--input" set "INPUT_DIR=%~2" && shift && shift && goto parse_args
if /i "%~1"=="-i" set "INPUT_DIR=%~2" && shift && shift && goto parse_args
if /i "%~1"=="--help" goto show_help
if /i "%~1"=="-h" goto show_help

call :log_error "未知选项: %~1"
echo 使用 --help 查看帮助信息
exit /b 1

:show_help
echo 标签注入脚本使用说明
echo.
echo 用法:
echo   scripts\inject-tags.bat [选项]
echo.
echo 选项:
echo   --verbose, -v     显示详细输出
echo   --force, -f       强制执行
echo   --skip-tool-check 跳过 protoc-go-inject-tag 版本检查
echo   --input, -i DIR   指定输入目录，默认 pb
echo   --help, -h        显示帮助信息
echo.
echo 功能:
echo   自动安装 protoc-go-inject-tag 工具
echo   为生成的 .pb.go 文件注入结构体标签
exit /b 0

:log_info
call "%INJECT_TAGS_SCRIPT_DIR%common.bat" log_info "%~1"
exit /b 0

:log_success
call "%INJECT_TAGS_SCRIPT_DIR%common.bat" log_success "%~1"
exit /b 0

:log_warning
call "%INJECT_TAGS_SCRIPT_DIR%common.bat" log_warning "%~1"
exit /b 0

:log_error
call "%INJECT_TAGS_SCRIPT_DIR%common.bat" log_error "%~1"
exit /b 0

:log_verbose
if "%VERBOSE%"=="true" call "%INJECT_TAGS_SCRIPT_DIR%common.bat" log_info "DEBUG %~1"
exit /b 0

:check_go
where go >nul 2>nul
if !errorlevel! neq 0 (
    call :log_error "Go 未安装，请先安装 Go 环境"
    exit /b 1
)

if "%VERBOSE%"=="true" (
    for /f "tokens=*" %%i in ('go version') do call :log_verbose "Go 版本: %%i"
)
exit /b 0

:install_protoc_go_inject_tag
if "%SKIP_TOOL_CHECK%"=="true" (
    call :log_verbose "跳过 protoc-go-inject-tag 版本检查"
    exit /b 0
)

if exist "%INJECT_TAGS_SCRIPT_DIR%setup-dependencies.bat" (
    call "%INJECT_TAGS_SCRIPT_DIR%setup-dependencies.bat" --inject-tag-only --no-pause
    if !errorlevel! neq 0 exit /b 1
) else (
    call :log_error "未找到依赖设置脚本: %INJECT_TAGS_SCRIPT_DIR%setup-dependencies.bat"
    exit /b 1
)
exit /b 0

:check_input_dir
if not exist "%INPUT_DIR%" (
    call :log_error "输入目录不存在: %INPUT_DIR%"
    call :log_error "请先运行生成脚本或指定正确的目录"
    exit /b 1
)

call :log_verbose "检查输入目录: %INPUT_DIR%"
exit /b 0

:find_pb_files
set "pb_file_count=0"

for %%f in ("%INPUT_DIR%\*.pb.go") do (
    if exist "%%f" (
        if not "%%~nf"=="%%~nf_grpc" (
            set /a pb_file_count+=1
            if "%VERBOSE%"=="true" call :log_verbose "  - %%f"
        )
    )
)

for /d %%d in ("%INPUT_DIR%\*") do (
    set "module_name=%%~nd"
    if /i not "!module_name:~0,7!"=="backup_" (
        for %%f in ("%%d\*.pb.go") do (
            if exist "%%f" (
                if not "%%~nf"=="%%~nf_grpc" (
                    set /a pb_file_count+=1
                    if "%VERBOSE%"=="true" call :log_verbose "  - %%f"
                )
            )
        )
    )
)

if !pb_file_count! equ 0 (
    call :log_warning "在 %INPUT_DIR% 目录中没有找到 .pb.go 文件"
    call :log_warning "请先运行 scripts\generate-modular.bat 生成 protobuf 代码"
    exit /b 1
)

call :log_info "找到 !pb_file_count! 个 .pb.go 文件"
exit /b 0

:inject_tags
call :log_info "开始注入结构体标签..."

if exist "%INPUT_DIR%\*.pb.go" (
    set "input_pattern=%INPUT_DIR%\*.pb.go"
    if "%VERBOSE%"=="true" call :log_verbose "执行命令: protoc-go-inject-tag --input=!input_pattern!"
    protoc-go-inject-tag --input="!input_pattern!"
    if !errorlevel! neq 0 (
        call :log_error "根目录标签注入失败，已中断"
        exit /b 1
    ) else (
        call :log_success "根目录标签注入完成"
    )
)

for /d %%d in ("%INPUT_DIR%\*") do (
    set "module_name=%%~nd"
    if /i not "!module_name:~0,7!"=="backup_" (
        if exist "%%d\*.pb.go" (
            set "module_pattern=%%d\*.pb.go"
            if "%VERBOSE%"=="true" call :log_verbose "执行命令: protoc-go-inject-tag --input=!module_pattern!"
            protoc-go-inject-tag --input="!module_pattern!"
            if !errorlevel! neq 0 (
                call :log_error "!module_name! 模块标签注入失败，已中断"
                exit /b 1
            ) else (
                call :log_success "!module_name! 模块标签注入完成"
            )
        )
    )
)

call :log_success "所有模块标签注入完成"
exit /b 0

:verify_injection
call :log_info "验证标签注入结果..."
set "has_tags="

for %%f in ("%INPUT_DIR%\*.pb.go") do (
    if exist "%%f" (
        if not "%%~nf"=="%%~nf_grpc" (
            findstr /c:"json:" /c:"gorm:" /c:"validate:" "%%f" >nul 2>nul
            if !errorlevel! equ 0 set "has_tags=true"
        )
    )
)

for /d %%d in ("%INPUT_DIR%\*") do (
    set "module_name=%%~nd"
    if /i not "!module_name:~0,7!"=="backup_" (
        for %%f in ("%%d\*.pb.go") do (
            if exist "%%f" (
                if not "%%~nf"=="%%~nf_grpc" (
                    findstr /c:"json:" /c:"gorm:" /c:"validate:" "%%f" >nul 2>nul
                    if !errorlevel! equ 0 set "has_tags=true"
                )
            )
        )
    )
)

if "%has_tags%"=="true" (
    call :log_success "标签注入验证通过"
) else (
    call :log_warning "未发现注入的标签，请检查 proto 文件中的 @gotags 注释"
)
exit /b 0

:show_usage_tips
echo.
call :log_info "使用提示："
echo   1. 在 proto 文件中使用 @gotags 注释定义标签
echo   2. 运行 scripts\generate-modular.bat 生成代码
echo   3. 运行此脚本注入结构体标签
exit /b 0

:main
call :log_info "标签注入工具启动..."
echo.

call :check_go
if errorlevel 1 exit /b 1

call :install_protoc_go_inject_tag
if errorlevel 1 exit /b 1

call :check_input_dir
if errorlevel 1 exit /b 1

call :find_pb_files
if errorlevel 1 (
    if not "%FORCE%"=="true" (
        call :show_usage_tips
        exit /b 1
    )
)

call :inject_tags
if errorlevel 1 exit /b 1

call :verify_injection
call :log_success "标签注入流程完成"

call :show_usage_tips
exit /b 0
