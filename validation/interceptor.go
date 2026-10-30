/*
 * @Author: kamalyes example@qq.com
 * @Date: 2026-10-30 10:52:39
 * @LastEditors: kamalyes example@qq.com
 * @LastEditTime: 2026-10-30 10:52:39
 * @FilePath: \kronos-share-proto-template\validation\interceptor.go
 * @Description: gRPC 校验拦截器 | gRPC validation interceptor
 *
 * Copyright (c) 2026 by kamalyes, All Rights Reserved.
 */

package validation

import (
	"context"

	validator "github.com/kamalyes/go-argus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/peer"
	"google.golang.org/grpc/status"
)

// 为什么校验要放在拦截器里 | Why validation belongs in an interceptor
//
// 每个 handler 开头写一遍 if err := validate(req); err != nil 迟早会漏，
// 而漏掉的那个接口恰好就是被打的那个拦截器把校验变成默认行为：
// 新增 RPC 自动被覆盖，想跳过才需要显式声明。
//
// [EN] Hand-writing a validate call at the top of every handler eventually misses one,
// and the missed endpoint is the one that gets hit. An interceptor makes validation the
// default: new RPCs are covered automatically and skipping requires an explicit opt-out.

// 语言协商用的 metadata key | Metadata key used for locale negotiation
const localeMetadataKey = "accept-language"

// InterceptorOptions 拦截器配置 | Interceptor options
type InterceptorOptions struct {
	// SkipMethods 免校验的全名方法列表，格式为 "/<包名>.<模块>.<服务>Service/<方法>"
	// 典型用途是健康检查、探活这类不带业务参数的接口
	// [EN] Fully-qualified methods that skip validation
	SkipMethods []string

	// AllowedPeerCIDRs 调用方 IP 白名单，支持 CIDR 与通配符；为空表示不限制。
	// [EN] Caller IP allowlist, CIDR and wildcard supported; empty disables the check
	//
	// 内部协议中心常被要求「只允许集群内调用」，白名单在这里比在业务里判断更可靠。
	// [EN] A contract hub is often restricted to in-cluster callers; the allowlist
	// belongs here rather than in business code
	AllowedPeerCIDRs []string

	// Locale 固定错误消息语言；为空则按请求的 accept-language 协商。
	// [EN] Fixed locale for error messages; empty negotiates from accept-language
	Locale string
}

// UnaryServerInterceptor 返回自动校验请求的一元拦截器。
// [EN] UnaryServerInterceptor returns a unary interceptor that validates every request
//
// 校验失败返回 codes.InvalidArgument，IP 不在白名单返回 codes.PermissionDenied，
// 两者都带上本地化的、按字段聚合的消息，前端可以直接展示。
// [EN] Failures map to InvalidArgument, a blocked IP maps to PermissionDenied, and both
// carry localized per-field messages the frontend can display as-is
func UnaryServerInterceptor(opts InterceptorOptions) grpc.UnaryServerInterceptor {
	skip := make(map[string]struct{}, len(opts.SkipMethods))
	for _, method := range opts.SkipMethods {
		skip[method] = struct{}{}
	}

	return func(
		ctx context.Context,
		req any,
		info *grpc.UnaryServerInfo,
		handler grpc.UnaryHandler,
	) (any, error) {
		if len(opts.AllowedPeerCIDRs) > 0 {
			if err := checkPeer(ctx, opts.AllowedPeerCIDRs); err != nil {
				return nil, err
			}
		}

		if _, skipped := skip[info.FullMethod]; skipped {
			return handler(ctx, req)
		}

		if err := StructCtx(ctx, req); err != nil {
			locale := opts.Locale
			if locale == "" {
				locale = localeFromContext(ctx)
			}
			return nil, status.Error(codes.InvalidArgument, Summary(err, locale))
		}

		return handler(ctx, req)
	}
}

// checkPeer 校验调用方 IP 是否在白名单内。
// [EN] checkPeer verifies the caller IP against the allowlist
func checkPeer(ctx context.Context, allowed []string) error {
	remote, ok := peer.FromContext(ctx)
	if !ok {
		return status.Error(codes.PermissionDenied, "无法获取调用方地址 | caller address unavailable")
	}

	host := remote.Addr.String()
	// Addr 形如 "10.0.0.1:54321"，去掉端口再比对 | Addr looks like "10.0.0.1:54321"
	if idx := lastIndexByte(host, ':'); idx > 0 {
		host = host[:idx]
	}

	// go-argus 的 IP 工具支持 CIDR 与通配符两种写法 | CIDR and wildcard are both supported
	if !validator.IsIPAllowed(host, allowed) {
		return status.Errorf(codes.PermissionDenied, "调用方 %s 不在白名单内 | caller %s is not allowed", host, host)
	}
	return nil
}

// localeFromContext 从请求 metadata 协商错误消息语言。
// [EN] localeFromContext negotiates the error locale from request metadata
func localeFromContext(ctx context.Context) string {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return DefaultLocale
	}
	values := md.Get(localeMetadataKey)
	if len(values) == 0 || values[0] == "" {
		return DefaultLocale
	}
	return values[0]
}

// lastIndexByte 不引入 strings 包的轻量实现 | lightweight helper without importing strings
func lastIndexByte(s string, b byte) int {
	for i := len(s) - 1; i >= 0; i-- {
		if s[i] == b {
			return i
		}
	}
	return -1
}
