/*
 * @Author: kamalyes example@qq.com
 * @Date: 2026-10-30 09:08:16
 * @LastEditors: kamalyes example@qq.com
 * @LastEditTime: 2026-10-30 09:08:16
 * @FilePath: \kronos-share-proto-template\bootstrap\main.go
 * @Description: 网关启动器 | Gateway launcher
 *
 * Copyright (c) 2026 by kamalyes, All Rights Reserved.
 */

package main

// 这个入口只负责把 proto 产出的 swagger 聚合成一个可浏览的文档站，
// 它不是业务服务：业务 gRPC 服务在各自仓库里实现，本仓库只提供协议与 pb 代码。
// 只需要协议产物、不需要文档站的项目，可以直接删掉整个 bootstrap 目录。
//
// [EN] This entry point only aggregates the generated swagger files into a
// browsable docs site. It is not a business service: business gRPC services live
// in their own repositories, this one ships contracts and pb code. Projects that
// only need the artifacts can delete the whole bootstrap directory.

func main() {
	// 多环境配置：注册额外环境前缀后，可按 resources/<prefix>-<env>.yaml 加载。
	// [EN] Multi-env: register extra prefixes to load resources/<prefix>-<env>.yaml
	// goconfig.RegisterEnvPrefixes("prod", "prod")

	gateway := NewGateway()
	if err := gateway.Start(); err != nil {
		panic(err)
	}
}
