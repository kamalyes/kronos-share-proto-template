/*
 * @Author: [[ .AuthorName ]] [[ .AuthorEmail ]]
 * @Date: [[ nowFmt "2006-01-02" ]] 00:00:00
 * @LastEditors: [[ .AuthorName ]] [[ .AuthorEmail ]]
 * @LastEditTime: [[ nowFmt "2006-01-02" ]] 00:00:00
 * @FilePath: \[[ .ProjectName ]]\bootstrap\main.go
 * @Description: [[ .ProjectName ]] 网关启动器
 *
 * Copyright (c) [[ .Year ]] by [[ .AuthorName ]], All Rights Reserved.
 */
package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	gateway := NewGateway()

	if err := gateway.Start(); err != nil {
		fmt.Printf("启动网关失败: %v\n", err)
		os.Exit(1)
	}

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	fmt.Println("🚀 [[ .ProjectName ]] Gateway 已启动，按 Ctrl+C 优雅关闭...")
	<-c

	fmt.Println("🛑 正在关闭网关...")
	if err := gateway.Stop(); err != nil {
		fmt.Printf("关闭网关失败: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("✅ 网关已安全关闭")
}
