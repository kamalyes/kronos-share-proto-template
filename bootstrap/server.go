/*
 * @Author: <% .AuthorName %> <% .AuthorEmail %>
 * @Date: <% nowFmt "2006-01-02 15:04:05" %>
 * @LastEditors: <% .AuthorName %> <% .AuthorEmail %>
 * @LastEditTime: <% nowFmt "2006-01-02 15:04:05" %>
 * @FilePath: \<% .ProjectName %>\bootstrap\server.go
 * @Description: 网关实现 | Gateway implementation
 *
 * Copyright (c) <% .Year %> by <% .AuthorName %>, All Rights Reserved.
 */

package main

import (
	"fmt"

	goconfig "github.com/kamalyes/go-config"
	gateway "github.com/kamalyes/go-rpc-gateway"
)

// Gateway 文档网关 | Documentation gateway
type Gateway struct {
	gateway *gateway.Gateway
}

// NewGateway 创建新的网关 | Create a new gateway
func NewGateway() *Gateway {
	return &Gateway{}
}

// Start 启动网关 | Start the gateway
//
// 配置从 resources/ 下按 <前缀>-<环境别名>.yaml 加载，前缀由 WithPrefix 指定，
// 所以前缀必须和 resources/ 下的文件名一致。
//
// 前缀和文件名都由 ProjectName 渲染，不是两个独立变量——各写一个的话，
// 改了一处忘了另一处就是启动即崩：
//   ❌ 未找到前缀为 'xxx' 的配置文件
// 而这个报错只在真正启动时出现，编译期毫无提示。同源之后结构上不可能分叉。
//
// [EN] Config is loaded from resources/<prefix>-<env alias>.yaml with the prefix given to
// WithPrefix, so it must match the file name under resources/. Both are rendered from
// ProjectName rather than from two independent variables: with a literal in each place,
// changing one and forgetting the other fails at startup with "config file with prefix not
// found" and nothing at compile time. One source makes divergence structurally impossible.
func (g *Gateway) Start() error {
	gw, err := gateway.NewGateway().
		WithSearchPath("resources").
		WithEnvironment(goconfig.GetEnvironment()).
		WithPrefix("<% .ProjectName %>").
		WithHotReload(nil).
		Build()
	if err != nil {
		return fmt.Errorf("创建网关失败 | failed to create gateway: %w", err)
	}
	g.gateway = gw

	return g.gateway.Run()
}
