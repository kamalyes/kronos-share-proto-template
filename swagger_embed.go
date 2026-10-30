//go:build go1.16 && swagger
// +build go1.16,swagger

/*
 * @Author: kamalyes example@qq.com
 * @Date: 2026-10-30 10:10:16
 * @LastEditors: kamalyes example@qq.com
 * @LastEditTime: 2026-10-30 10:10:16
 * @FilePath: \kronos-share-proto-template\swagger_embed.go
 * @Description: swagger 文件嵌入（仅 -tags swagger 时编译） | Swagger embedding (only built with -tags swagger)
 *
 * Copyright (c) 2026 by kamalyes, All Rights Reserved.
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

package kronosshareprototemplate

import (
	_ "embed"
)

//go:embed proto/catalog/product_service.swagger.yaml
var ProductServiceSwagger []byte

//go:embed proto/inventory/warehouse_service.swagger.yaml
var WarehouseServiceSwagger []byte

//go:embed proto/tenant/tenant_service.swagger.yaml
var TenantServiceSwagger []byte

//go:embed proto/tenant/tenant_member_service.swagger.yaml
var TenantMemberServiceSwagger []byte

//go:embed proto/key/temp_key_service.swagger.yaml
var TempKeyServiceSwagger []byte

//go:embed proto/key/id_block_service.swagger.yaml
var IdBlockServiceSwagger []byte

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
	"proto/catalog/product_service.swagger.yaml": ProductServiceSwagger,
	"proto/inventory/warehouse_service.swagger.yaml":   WarehouseServiceSwagger,
	"proto/tenant/tenant_service.swagger.yaml":        TenantServiceSwagger,
	"proto/tenant/tenant_member_service.swagger.yaml": TenantMemberServiceSwagger,
	"proto/key/temp_key_service.swagger.yaml":                                          TempKeyServiceSwagger,
	"proto/key/id_block_service.swagger.yaml":                                          IdBlockServiceSwagger,
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
