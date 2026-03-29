//go:build go1.16
// +build go1.16

/*
 * @Author: [[ .AuthorName ]] [[ .AuthorEmail ]]
 * @Date: [[ nowFmt "2006-01-02" ]] 00:00:00
 * @LastEditors: [[ .AuthorName ]] [[ .AuthorEmail ]]
 * @LastEditTime: [[ nowFmt "2006-01-02" ]] 00:00:00
 * @FilePath: \[[ .ProjectName ]]\swagger_embed.go
 * @Description: 嵌入所有 Swagger YAML 文件，供外部项目使用
 *
 * Copyright (c) [[ .Year ]] by [[ .AuthorName ]], All Rights Reserved.
 */
package [[ .OrgPrefix ]]shareproto

import (
	_ "embed"
)

//go:embed proto/[[ .ExampleServiceName | snake ]]/[[ .ExampleServiceName | snake ]]_service.swagger.yaml
var [[ .ExampleServiceName ]]ServiceSwagger []byte

// SwaggerFiles 所有嵌入的 Swagger 文件映射
var SwaggerFiles = map[string][]byte{
	"proto/[[ .ExampleServiceName | snake ]]/[[ .ExampleServiceName | snake ]]_service.swagger.yaml": [[ .ExampleServiceName ]]ServiceSwagger,
}

// GetSwaggerFiles 获取所有嵌入的 Swagger 文件
func GetSwaggerFiles() map[string][]byte {
	return SwaggerFiles
}

// GetSwaggerFile 获取指定的 Swagger 文件内容
func GetSwaggerFile(name string) ([]byte, bool) {
	content, exists := SwaggerFiles[name]
	return content, exists
}

// GetSwaggerFileNames 获取所有可用的 Swagger 文件名
func GetSwaggerFileNames() []string {
	names := make([]string, 0, len(SwaggerFiles))
	for name := range SwaggerFiles {
		names = append(names, name)
	}
	return names
}
