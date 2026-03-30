@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

call "%~dp0common.bat"
call "%SCRIPT_DIR%common.bat" project_root

set "GO_MODULE=<% .ModuleName %>"
set "PROTO_BASE_MODULES=enums"
rem 业务模块列表：新增模块后必须加到这里，否则不会被生成。
rem Service module list: a new module must be registered here or it will not be generated
set "PROTO_SERVICE_MODULES=common <% .ExampleModule %> <% .SecondModule %> <% .MixedModule %>"
set "PROTO_ALL_MODULES=%PROTO_BASE_MODULES% %PROTO_SERVICE_MODULES%"

call "%SCRIPT_DIR%common.bat" log_info "生成 Protobuf 文件 (分模块结构)..."

call "%SCRIPT_DIR%common.bat" require_script "setup-all.bat"
if errorlevel 1 exit /b 1
call "%SCRIPT_DIR%setup-all.bat" --no-pause
if errorlevel 1 exit /b 1

call "%SCRIPT_DIR%common.bat" ensure_go
if errorlevel 1 exit /b 1
call "%SCRIPT_DIR%common.bat" ensure_gopath
if errorlevel 1 exit /b 1
call "%SCRIPT_DIR%common.bat" ensure_go_bin_on_path
if errorlevel 1 exit /b 1
call "%SCRIPT_DIR%common.bat" ensure_protoc
if errorlevel 1 exit /b 1

if not exist proto (
    call "%SCRIPT_DIR%common.bat" log_error "proto 目录不存在，请先创建 proto 目录并添加 .proto 文件"
    exit /b 1
)

call "%SCRIPT_DIR%common.bat" require_script "prepare-pb-output.bat"
if errorlevel 1 exit /b 1
call "%SCRIPT_DIR%prepare-pb-output.bat" --input pb
if errorlevel 1 exit /b 1

for /f "tokens=*" %%i in ('where protoc') do set "PROTOC_PATH=%%i"
if "%PROTOC_PATH%"=="" (
    call "%SCRIPT_DIR%common.bat" log_error "protoc 未安装，请先安装 Protocol Buffers"
    exit /b 1
)
for %%i in ("%PROTOC_PATH%") do set "PROTOC_DIR=%%~dpi"
set "PROTOC_INCLUDE=%PROTOC_DIR%..\include"

set "GOOGLEAPIS_PATH="
set "GRPC_GATEWAY_PATH="
if exist "%GOPATH%\src\github.com\googleapis" (
    set "GOOGLEAPIS_PATH=-I%GOPATH%\src\github.com\googleapis"
    call "%SCRIPT_DIR%common.bat" log_success "使用 GOPATH 中的 googleapis"
) else (
    call "%SCRIPT_DIR%common.bat" log_warning "GOPATH 中未找到 googleapis"
)

if exist "%GOPATH%\src\github.com\grpc-ecosystem\grpc-gateway" (
    set "GRPC_GATEWAY_PATH=-I%GOPATH%\src\github.com\grpc-ecosystem\grpc-gateway"
    call "%SCRIPT_DIR%common.bat" log_success "使用 GOPATH 中的 grpc-gateway"
) else (
    call "%SCRIPT_DIR%common.bat" log_warning "GOPATH 中未找到 grpc-gateway"
)

set "GO_OPT=--go_opt=module=%GO_MODULE%"
set "GO_GRPC_OPT=--go-grpc_opt=module=%GO_MODULE%"
set "GRPC_GATEWAY_OPT=--grpc-gateway_opt=module=%GO_MODULE%"

call :set_plugin_args
if errorlevel 1 exit /b 1

call :clean_proto_outputs

for %%m in (%PROTO_BASE_MODULES%) do (
    call :generate_go_module "%%m"
    if errorlevel 1 exit /b 1
)
for %%m in (%PROTO_SERVICE_MODULES%) do (
    call :generate_go_module "%%m"
    if errorlevel 1 exit /b 1
)
call :generate_root
if errorlevel 1 exit /b 1

for %%m in (%PROTO_SERVICE_MODULES%) do (
    call :generate_gateway_module "%%m"
    if errorlevel 1 exit /b 1
    call :generate_openapi_module "%%m"
    if errorlevel 1 exit /b 1
)

call "%SCRIPT_DIR%common.bat" require_script "inject-tags.bat"
if errorlevel 1 exit /b 1
call "%SCRIPT_DIR%inject-tags.bat" --force --skip-tool-check --input pb
if errorlevel 1 exit /b 1

call "%SCRIPT_DIR%common.bat" log_info "处理 Swagger 文件：清理 @inject_tag 污染并注入约束..."
set "PROTOC_GO_INJECT_TAG=%GO_BIN_DIR%\protoc-go-inject-tag.exe"
if not exist "%PROTOC_GO_INJECT_TAG%" (
    call "%SCRIPT_DIR%common.bat" log_error "未找到 protoc-go-inject-tag: %PROTOC_GO_INJECT_TAG%"
    exit /b 1
)

for %%m in (%PROTO_SERVICE_MODULES%) do (
    if exist "proto\%%m\*.swagger.yaml" (
        call "%SCRIPT_DIR%common.bat" log_info "处理 %%m 模块的 Swagger 文件..."
        "%PROTOC_GO_INJECT_TAG%" swagger --proto-dir="proto\%%m" -v
        if errorlevel 1 (
            call "%SCRIPT_DIR%common.bat" log_error "%%m 模块 Swagger 处理失败"
            exit /b 1
        )
    )
)

if exist "proto\*.swagger.yaml" (
    call "%SCRIPT_DIR%common.bat" log_info "处理根目录的 Swagger 文件..."
    "%PROTOC_GO_INJECT_TAG%" swagger --input="proto\*.proto" -v
    if errorlevel 1 (
        call "%SCRIPT_DIR%common.bat" log_error "根目录 Swagger 处理失败"
        exit /b 1
    )
)

call "%SCRIPT_DIR%common.bat" log_success "Protobuf 文件生成完成"
call "%SCRIPT_DIR%common.bat" log_success "结构体标签注入完成"
call "%SCRIPT_DIR%common.bat" log_success "Swagger 文件处理完成"
echo.
echo 生成的 Go 文件：
for %%m in (%PROTO_ALL_MODULES%) do (
    if exist pb\%%m\*.pb.go (
        echo   %%m:
        dir /b pb\%%m\*.pb.go 2>nul
        dir /b pb\%%m\*.gw.go 2>nul
    )
)
if exist pb\*.pb.go (
    echo   root:
    dir /b pb\*.pb.go 2>nul
    dir /b pb\*.gw.go 2>nul
)
echo.
echo 下一步：
echo   1. go mod tidy
echo   2. go run bootstrap
exit /b 0

:clean_proto_outputs
call "%SCRIPT_DIR%common.bat" log_info "清理旧的 proto 目录生成文件..."
del /q proto\*.pb.go 2>nul
del /q proto\*_grpc.pb.go 2>nul
del /q proto\*.gw.go 2>nul
del /q proto\*.swagger.json 2>nul
del /q proto\*.swagger.yaml 2>nul
for /d %%d in (proto\*) do (
    del /q "%%d\*.pb.go" 2>nul
    del /q "%%d\*_grpc.pb.go" 2>nul
    del /q "%%d\*.gw.go" 2>nul
    del /q "%%d\*.swagger.json" 2>nul
    del /q "%%d\*.swagger.yaml" 2>nul
)
exit /b 0

:set_plugin_args
set "PROTOC_GEN_GO=%GO_BIN_DIR%\protoc-gen-go.exe"
set "PROTOC_GEN_GO_GRPC=%GO_BIN_DIR%\protoc-gen-go-grpc.exe"
set "PROTOC_GEN_GRPC_GATEWAY=%GO_BIN_DIR%\protoc-gen-grpc-gateway.exe"
set "PROTOC_GEN_OPENAPIV2=%GO_BIN_DIR%\protoc-gen-openapiv2.exe"

if not exist "%PROTOC_GEN_GO%" (
    call "%SCRIPT_DIR%common.bat" log_error "未找到 protoc-gen-go: %PROTOC_GEN_GO%"
    exit /b 1
)
if not exist "%PROTOC_GEN_GO_GRPC%" (
    call "%SCRIPT_DIR%common.bat" log_error "未找到 protoc-gen-go-grpc: %PROTOC_GEN_GO_GRPC%"
    exit /b 1
)
if not exist "%PROTOC_GEN_GRPC_GATEWAY%" (
    call "%SCRIPT_DIR%common.bat" log_error "未找到 protoc-gen-grpc-gateway: %PROTOC_GEN_GRPC_GATEWAY%"
    exit /b 1
)
if not exist "%PROTOC_GEN_OPENAPIV2%" (
    call "%SCRIPT_DIR%common.bat" log_error "未找到 protoc-gen-openapiv2: %PROTOC_GEN_OPENAPIV2%"
    exit /b 1
)

set "PLUGIN_GO=--plugin=protoc-gen-go=%PROTOC_GEN_GO%"
set "PLUGIN_GO_GRPC=--plugin=protoc-gen-go-grpc=%PROTOC_GEN_GO_GRPC%"
set "PLUGIN_GRPC_GATEWAY=--plugin=protoc-gen-grpc-gateway=%PROTOC_GEN_GRPC_GATEWAY%"
set "PLUGIN_OPENAPIV2=--plugin=protoc-gen-openapiv2=%PROTOC_GEN_OPENAPIV2%"
exit /b 0

:generate_go_module
set "module=%~1"
if not exist "proto\%module%\*.proto" exit /b 0
if not exist "pb\%module%" mkdir "pb\%module%"
call "%SCRIPT_DIR%common.bat" log_info "生成 %module% 模块 Go/gRPC 代码..."
protoc "%PLUGIN_GO%" "%PLUGIN_GO_GRPC%" -I"%PROTOC_INCLUDE%" %GOOGLEAPIS_PATH% %GRPC_GATEWAY_PATH% -I. --go_out=. %GO_OPT% --go-grpc_out=. %GO_GRPC_OPT% proto\%module%\*.proto
if errorlevel 1 exit /b 1
exit /b 0

:generate_gateway_module
set "module=%~1"
if not exist "proto\%module%\*.proto" exit /b 0
findstr /c:"google.api.http" "proto\%module%\*.proto" >nul 2>nul
if errorlevel 1 exit /b 0
call "%SCRIPT_DIR%common.bat" log_info "生成 %module% 模块 gRPC-Gateway 代码..."
protoc "%PLUGIN_GRPC_GATEWAY%" -I"%PROTOC_INCLUDE%" %GOOGLEAPIS_PATH% %GRPC_GATEWAY_PATH% -I. --grpc-gateway_out=. %GRPC_GATEWAY_OPT% --grpc-gateway_opt=generate_unbound_methods=true proto\%module%\*.proto
if errorlevel 1 (
    call "%SCRIPT_DIR%common.bat" log_error "%module% 模块 gRPC-Gateway 代码生成失败，已中断"
    exit /b 1
)
exit /b 0

:generate_openapi_module
set "module=%~1"
if not exist "proto\%module%\*.proto" exit /b 0
set "has_openapi_proto="
for %%f in (proto\%module%\*.proto) do (
    findstr /c:"openapiv2_swagger" /c:"google.api.http" "%%f" >nul 2>nul
    if not errorlevel 1 (
        set "has_openapi_proto=true"
        call "%SCRIPT_DIR%common.bat" log_info "生成 %%~nf OpenAPI 文档..."
        protoc "%PLUGIN_OPENAPIV2%" -I"%PROTOC_INCLUDE%" %GOOGLEAPIS_PATH% %GRPC_GATEWAY_PATH% -I. --openapiv2_out=. --openapiv2_opt=logtostderr=true --openapiv2_opt=json_names_for_fields=false --openapiv2_opt=output_format=yaml "%%f"
        if errorlevel 1 (
            call "%SCRIPT_DIR%common.bat" log_error "%%~nf OpenAPI 文档生成失败，已中断"
            exit /b 1
        )
    )
)
if "!has_openapi_proto!"=="" exit /b 0
exit /b 0

:generate_root
if not exist proto\*.proto exit /b 0
call "%SCRIPT_DIR%common.bat" log_info "生成根目录 proto Go/gRPC 代码..."
protoc "%PLUGIN_GO%" "%PLUGIN_GO_GRPC%" -I"%PROTOC_INCLUDE%" %GOOGLEAPIS_PATH% %GRPC_GATEWAY_PATH% -I. --go_out=. %GO_OPT% --go-grpc_out=. %GO_GRPC_OPT% proto\*.proto
if errorlevel 1 exit /b 1

findstr /c:"google.api.http" proto\*.proto >nul 2>nul
if not errorlevel 1 (
    call "%SCRIPT_DIR%common.bat" log_info "生成根目录 gRPC-Gateway 代码..."
    protoc "%PLUGIN_GRPC_GATEWAY%" -I"%PROTOC_INCLUDE%" %GOOGLEAPIS_PATH% %GRPC_GATEWAY_PATH% -I. --grpc-gateway_out=. %GRPC_GATEWAY_OPT% --grpc-gateway_opt=generate_unbound_methods=true proto\*.proto
    if errorlevel 1 (
        call "%SCRIPT_DIR%common.bat" log_error "根目录 gRPC-Gateway 代码生成失败，已中断"
        exit /b 1
    )
)

set "root_has_openapi_proto="
for %%f in (proto\*.proto) do (
    findstr /c:"openapiv2_swagger" /c:"google.api.http" "%%f" >nul 2>nul
    if not errorlevel 1 (
        set "root_has_openapi_proto=true"
        call "%SCRIPT_DIR%common.bat" log_info "生成根目录 %%~nf OpenAPI 文档..."
        protoc "%PLUGIN_OPENAPIV2%" -I"%PROTOC_INCLUDE%" %GOOGLEAPIS_PATH% %GRPC_GATEWAY_PATH% -I. --openapiv2_out=. --openapiv2_opt=logtostderr=true --openapiv2_opt=json_names_for_fields=false --openapiv2_opt=output_format=yaml "%%f"
        if errorlevel 1 (
            call "%SCRIPT_DIR%common.bat" log_error "根目录 %%~nf OpenAPI 文档生成失败，已中断"
            exit /b 1
        )
    )
)
if "!root_has_openapi_proto!"=="" exit /b 0
exit /b 0
