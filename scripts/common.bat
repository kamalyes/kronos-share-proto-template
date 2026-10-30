@echo off

if not defined SHARE_PROTO_SCRIPTS_COMMON_BAT (
    set "SHARE_PROTO_SCRIPTS_COMMON_BAT=1"
    set "ICON_SUCCESS=OK"
    set "ICON_ERROR=ERR"
    set "ICON_WARNING=WARN"
    set "ICON_INFO=INFO"
    set "REQUIRED_PROTOC_VERSION=libprotoc 24.3"
    set "SCRIPT_DIR=%~dp0"
    for %%i in ("%~dp0..") do set "PROJECT_ROOT=%%~fi"
)

if "%~1"=="" exit /b 0
if /i "%~1"=="project_root" goto project_root
if /i "%~1"=="log_info" goto log_info
if /i "%~1"=="log_success" goto log_success
if /i "%~1"=="log_warning" goto log_warning
if /i "%~1"=="log_error" goto log_error
if /i "%~1"=="ensure_go" goto ensure_go
if /i "%~1"=="ensure_gopath" goto ensure_gopath
if /i "%~1"=="ensure_go_bin_on_path" goto ensure_go_bin_on_path
if /i "%~1"=="ensure_protoc" goto ensure_protoc
if /i "%~1"=="require_script" goto require_script
set "LOG_MESSAGE=❌ 未知 common.bat 命令: %~1"
powershell -NoProfile -Command "Write-Host $env:LOG_MESSAGE -ForegroundColor Red"
exit /b 1

:project_root
cd /d "%PROJECT_ROOT%"
exit /b 0

:log_info
set "LOG_MESSAGE=ℹ️  %~2"
powershell -NoProfile -Command "Write-Host $env:LOG_MESSAGE -ForegroundColor Cyan"
exit /b 0

:log_success
set "LOG_MESSAGE=✅ %~2"
powershell -NoProfile -Command "Write-Host $env:LOG_MESSAGE -ForegroundColor Green"
exit /b 0

:log_warning
set "LOG_MESSAGE=⚠️  %~2"
powershell -NoProfile -Command "Write-Host $env:LOG_MESSAGE -ForegroundColor Yellow"
exit /b 0

:log_error
set "LOG_MESSAGE=❌ %~2"
powershell -NoProfile -Command "Write-Host $env:LOG_MESSAGE -ForegroundColor Red"
exit /b 0

:ensure_go
where go >nul 2>nul
if errorlevel 1 (
    call "%~f0" log_error "Go 未安装，请先安装 Go 环境"
    exit /b 1
)
call "%~f0" log_success "Go 环境已安装"
exit /b 0

:ensure_gopath
if not "%GOPATH%"=="" exit /b 0
for /f "tokens=*" %%i in ('go env GOPATH 2^>nul') do set "GOPATH=%%i"
if "%GOPATH%"=="" (
    call "%~f0" log_error "GOPATH 环境变量未设置"
    call "%~f0" log_warning "请设置 GOPATH 环境变量"
    exit /b 1
)
call "%~f0" log_success "GOPATH: %GOPATH%"
exit /b 0

:ensure_go_bin_on_path
call "%~f0" ensure_go
if errorlevel 1 exit /b 1
call "%~f0" ensure_gopath
if errorlevel 1 exit /b 1
set "GO_BIN_DIR="
for /f "tokens=*" %%i in ('go env GOBIN 2^>nul') do set "GO_BIN_DIR=%%i"
if "%GO_BIN_DIR%"=="" set "GO_BIN_DIR=%GOPATH%\bin"
if not exist "%GO_BIN_DIR%" mkdir "%GO_BIN_DIR%" 2>nul
echo ;%PATH%; | find /i ";%GO_BIN_DIR%;" >nul
if errorlevel 1 set "PATH=%GO_BIN_DIR%;%PATH%"
call "%~f0" log_success "Go bin 已加入 PATH: %GO_BIN_DIR%"
exit /b 0

:ensure_protoc
where protoc >nul 2>nul
if errorlevel 1 (
    call "%~f0" log_error "protoc 未安装，请先安装 Protocol Buffers"
    call "%~f0" log_warning "下载地址: https://github.com/protocolbuffers/protobuf/releases"
    call "%~f0" log_warning "或使用 chocolatey: choco install protoc"
    exit /b 1
)
set "actual_protoc_version="
for /f "tokens=*" %%v in ('protoc --version 2^>nul') do set "actual_protoc_version=%%v"
echo(%actual_protoc_version% | findstr /c:"%REQUIRED_PROTOC_VERSION%" >nul
if errorlevel 1 (
    call "%~f0" log_error "protoc 版本不匹配，期望 %REQUIRED_PROTOC_VERSION%，当前: %actual_protoc_version%"
    call "%~f0" log_warning "请运行 scripts\setup-all.bat --no-pause 自动安装固定版本"
    exit /b 1
)
call "%~f0" log_success "protoc 版本符合要求: %actual_protoc_version%"
exit /b 0

:require_script
set "required_script=%~2"
if not exist "%SCRIPT_DIR%%required_script%" (
    call "%~f0" log_error "未找到脚本: %SCRIPT_DIR%%required_script%"
    exit /b 1
)
exit /b 0
