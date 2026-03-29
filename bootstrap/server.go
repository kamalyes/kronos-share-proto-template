/*
 * @Author: [[ .AuthorName ]] [[ .AuthorEmail ]]
 * @Date: [[ nowFmt "2006-01-02" ]] 00:00:00
 * @LastEditors: [[ .AuthorName ]] [[ .AuthorEmail ]]
 * @LastEditTime: [[ nowFmt "2006-01-02" ]] 00:00:00
 * @FilePath: \[[ .ProjectName ]]\bootstrap\server.go
 * @Description: [[ .ProjectName ]] 网关实现
 *
 * Copyright (c) [[ .Year ]] by [[ .AuthorName ]], All Rights Reserved.
 */
package main

import (
	"fmt"

	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	goconfig "github.com/kamalyes/go-config"
	gateway "github.com/kamalyes/go-rpc-gateway"
	"google.golang.org/grpc"
)

type Gateway struct {
	gateway     *gateway.Gateway
	grpcClients map[string]*grpc.ClientConn
	mux         *runtime.ServeMux
}

func NewGateway() *Gateway {
	return &Gateway{
		grpcClients: make(map[string]*grpc.ClientConn),
	}
}

func (g *Gateway) Start() error {
	gw, err := gateway.NewGateway().
		WithSearchPath("resources").
		WithEnvironment(goconfig.GetEnvironment()).
		WithPrefix("gateway").
		WithHotReload(nil).
		Build()
	if err != nil {
		return fmt.Errorf("创建网关失败: %v", err)
	}
	g.gateway = gw

	g.registerCustomRoutes()

	return g.gateway.Start()
}

func (g *Gateway) registerCustomRoutes() {
	g.gateway.RegisterHTTPRoute("/api/generate", GenerateHandler)
}

func (g *Gateway) Stop() error {
	for serviceName, conn := range g.grpcClients {
		if err := conn.Close(); err != nil {
			fmt.Printf("关闭gRPC连接 %s 失败: %v\n", serviceName, err)
		}
	}

	if g.gateway != nil {
		return g.gateway.Stop()
	}

	return nil
}

func (g *Gateway) WaitForShutdown() {
	if g.gateway != nil {
		g.gateway.WaitForShutdown()
	}
}
