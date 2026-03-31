//go:build go1.16 && !swagger
// +build go1.16,!swagger

// swagger_embed_stub 在未启用 swagger 构建标签时提供空实现，
// 使根包仍可被 import 而不引入 1.58MB swagger YAML
// 需要真实 swagger 文件时使用 -tags swagger 构建（仅 access-control 等服务启用）。

package <% replace .ProjectName "-" "" %>

// SwaggerFiles 未启用 swagger 标签时为空 map，避免将 swagger YAML 嵌入二进制
var SwaggerFiles = map[string][]byte{}

// GetSwaggerFiles 返回全部 swagger 文件（未启用标签时为空）
func GetSwaggerFiles() map[string][]byte {
	return SwaggerFiles
}

// GetSwaggerFile 按名称获取 swagger 文件（未启用标签时始终返回 false）
func GetSwaggerFile(name string) ([]byte, bool) {
	return nil, false
}

// GetSwaggerFileNames 返回 swagger 文件名列表（未启用标签时为空）
func GetSwaggerFileNames() []string {
	return nil
}

// OpenAPIBundle 未启用 swagger 标签时为空，避免把聚合文档嵌进二进制
// [EN] Empty without the swagger build tag, so the bundle stays out of the binary
var OpenAPIBundle []byte

// GetOpenAPIBundle 返回聚合 OpenAPI 文档（未启用标签时为空）
// [EN] Return the aggregated OpenAPI document (empty without the build tag)
func GetOpenAPIBundle() []byte {
	return nil
}
