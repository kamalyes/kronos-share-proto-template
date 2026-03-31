//go:build go1.16 && swagger
// +build go1.16,swagger

/*
 * @Author: <% .AuthorName %> <% .AuthorEmail %>
 * @Date: <% nowFmt "2006-01-02 15:04:05" %>
 * @LastEditors: <% .AuthorName %> <% .AuthorEmail %>
 * @LastEditTime: <% nowFmt "2006-01-02 15:04:05" %>
 * @FilePath: \<% .ProjectName %>\swagger_embed.go
 * @Description: swagger 文件嵌入（仅 -tags swagger 时编译） | Swagger embedding (only built with -tags swagger)
 *
 * Copyright (c) <% .Year %> by <% .AuthorName %>, All Rights Reserved.
 */

// 为什么要 build tag | Why the build tag
//
// swagger YAML 会随接口数量线性膨胀，几十个服务就是 MB 级。只有需要对外暴露
// 文档的服务才用 -tags swagger 构建，其它服务引用本仓库时走 swagger_embed_stub.go，
// 二进制里不会多出一行 YAML。
//
// [EN] Swagger YAML grows linearly with the API surface and reaches megabytes.
// Only services that expose docs build with -tags swagger; everyone else links
// swagger_embed_stub.go and carries no YAML in the binary.
//
// 新增服务后记得在这里补一条 embed 与 SwaggerFiles 映射，否则文档站看不到它。
// [EN] Register new services here and in SwaggerFiles, otherwise the docs site misses them

package <% replace .ProjectName "-" "" %>

import (
	_ "embed"
)

//go:embed proto/<% .ExampleModule %>/<% .ExampleService | snake %>_service.swagger.yaml
var <% .ExampleService | pascal %>ServiceSwagger []byte

//go:embed proto/<% .SecondModule %>/<% .SecondService | snake %>_service.swagger.yaml
var <% .SecondService | pascal %>ServiceSwagger []byte

//go:embed proto/<% .MixedModule %>/<% .MixedService | snake %>_service.swagger.yaml
var <% .MixedService | pascal %>ServiceSwagger []byte

//go:embed proto/<% .MixedModule %>/<% .MixedService | snake %>_member_service.swagger.yaml
var <% .MixedService | pascal %>MemberServiceSwagger []byte

// 聚合 OpenAPI 文档 | Aggregated OpenAPI document
//
// 它不进 SwaggerFiles：那张表是「按服务拆分」的文档，网关据此做分页聚合；
// 这份是已经合并好的单文件，给只想要一个 /openapi.json 端点的服务用。
// 两者内容重叠，同时暴露没有坏处，但不要把它当成第五个服务塞进聚合列表。
//
// [EN] Deliberately not part of SwaggerFiles: that map holds the per-service documents the
// gateway aggregates itself. This is the pre-merged single file, for services that only want
// to expose one /openapi.json endpoint. The two overlap in content, which is harmless, but
// do not add this one to the aggregation list as if it were a fifth service.
//go:embed docs/openapi.swagger.yaml
var OpenAPIBundle []byte

// SwaggerFiles 全部 swagger 文件，键为相对仓库根的路径。
// [EN] All swagger files, keyed by repository-relative path
var SwaggerFiles = map[string][]byte{
	"proto/<% .ExampleModule %>/<% .ExampleService | snake %>_service.swagger.yaml": <% .ExampleService | pascal %>ServiceSwagger,
	"proto/<% .SecondModule %>/<% .SecondService | snake %>_service.swagger.yaml":   <% .SecondService | pascal %>ServiceSwagger,
	"proto/<% .MixedModule %>/<% .MixedService | snake %>_service.swagger.yaml":        <% .MixedService | pascal %>ServiceSwagger,
	"proto/<% .MixedModule %>/<% .MixedService | snake %>_member_service.swagger.yaml": <% .MixedService | pascal %>MemberServiceSwagger,
}

// GetSwaggerFiles 返回全部 swagger 文件 | Return all swagger files
func GetSwaggerFiles() map[string][]byte {
	return SwaggerFiles
}

// GetSwaggerFile 按名称获取 swagger 文件 | Get one swagger file by name
func GetSwaggerFile(name string) ([]byte, bool) {
	content, exists := SwaggerFiles[name]
	return content, exists
}

// GetSwaggerFileNames 返回 swagger 文件名列表 | Return swagger file names
func GetSwaggerFileNames() []string {
	names := make([]string, 0, len(SwaggerFiles))
	for name := range SwaggerFiles {
		names = append(names, name)
	}
	return names
}

// GetOpenAPIBundle 返回聚合 OpenAPI 文档 | Return the aggregated OpenAPI document
func GetOpenAPIBundle() []byte {
	return OpenAPIBundle
}
