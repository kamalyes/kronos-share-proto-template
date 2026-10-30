/*
 * @Author: kamalyes example@qq.com
 * @Date: 2026-10-30 09:08:16
 * @LastEditors: kamalyes example@qq.com
 * @LastEditTime: 2026-10-30 09:08:16
 * @FilePath: \kronos-share-proto-template\validation\validator.go
 * @Description: 基于 go-argus 的请求校验层 | Request validation layer built on go-argus
 *
 * Copyright (c) 2026 by kamalyes, All Rights Reserved.
 */

// Package validation 把 proto 里声明的校验规则变成可执行的校验。
// [EN] Package validation turns the rules declared in proto into executable checks
//
// 规则是怎么从 proto 流到这里的 | How a rule flows from proto to here:
//
//	proto 字段注释   // 名称 | [EN] Name  @inject_tag: validate:"required,min=2,max=64"
//	      ↓ protoc 生成 pb.go（此时还没有 tag）
//	      ↓ scripts/inject-tags.sh 把 @inject_tag 注入成结构体 tag
//	pb.go 字段       Name string `json:"name" validate:"required,min=2,max=64"`
//	      ↓ 本包用 go-argus 读取这些 tag
//	运行时           validation.Struct(req) 返回带字段名与本地化消息的错误。
//
// 所以「改校验规则」只需要改 proto 注释，不需要动 Go 代码；反过来说，
// 漏写 @inject_tag 的必填字段在运行时不会被拦住 —— 这是 proto review 的重点。
//
// [EN] Changing a rule only means editing the proto comment, never Go code. The flip
// side: a required field missing its @inject_tag is NOT enforced at runtime, which is
// exactly what proto review must catch.
package validation

import (
	"context"
	"strings"
	"sync"

	validator "github.com/kamalyes/go-argus"
	argusvalidate "github.com/kamalyes/go-argus/validate"
)

// DefaultLocale 默认错误消息语言 | Default locale for error messages
// go-argus 内置 en/zh/zh-TW/ja/ko/fr/de/es/ru 九种语言。
// [EN] go-argus ships nine locales: en/zh/zh-TW/ja/ko/fr/de/es/ru
const DefaultLocale = "zh"

var (
	once     sync.Once
	instance *validator.Validate
)

// V 返回进程级共享的校验器。
// [EN] V returns the process-wide shared validator
//
// go-argus 的 Validate 是并发安全的，且会缓存每个结构体编译结果，
// 所以必须复用同一个实例：每次 New 都会丢掉缓存，白付一次反射解析的钱。
// [EN] Validate is concurrency safe and caches the compiled plan per struct, so the
// instance must be reused; calling New per request throws the cache away.
func V() *validator.Validate {
	once.Do(func() {
		instance = validator.New()
		validator.SetLocale(DefaultLocale)
		registerCustomRules(instance)
		registerExtraLocales()
	})
	return instance
}

// Struct 校验一个请求结构体，nil 表示通过。
// [EN] Struct validates a request struct; nil means it passed
func Struct(req any) error {
	return V().Struct(req)
}

// StructCtx 带上下文校验，自定义规则可以从 ctx 取租户、灰度等信息。
// [EN] StructCtx validates with a context so custom rules can read tenant or rollout info
func StructCtx(ctx context.Context, req any) error {
	return V().StructCtx(ctx, req)
}

// VarString 零反射快路径：只校验一个字符串，不走 reflect，无堆分配。
// [EN] VarString is the zero-reflection fast path for a single string: no reflect, no allocation
//
// 适合网关层对 path/query 参数做前置校验，比把参数塞进结构体再校验快 2~3 倍。
// [EN] Ideal for gateway-level checks on path/query params, 2-3x faster than wrapping them in a struct
func VarString(value, tag string) error {
	return V().VarString(value, tag)
}

// Messages 把校验错误翻译成可序列化消息，locale 为空时用默认语言。
// [EN] Messages translates validation errors into serializable messages
//
// 返回结构与 proto 里的 common.Error 对得上：Field 对应字段名，Message 已本地化，
// 服务端可以直接塞进 common.Error.details 回给前端。
// [EN] The shape lines up with common.Error in proto: Field is the field name and
// Message is localized, so a service can put them straight into common.Error.details
func Messages(err error, locale string) []validator.ValidationMessage {
	if err == nil {
		return nil
	}
	if locale == "" {
		locale = DefaultLocale
	}
	return validator.TranslateValidationErrors(err, locale)
}

// Summary 把校验错误拼成一行可读文本，用于日志与 gRPC status message
// [EN] Summary flattens validation errors into one readable line for logs and gRPC status
func Summary(err error, locale string) string {
	messages := Messages(err, locale)
	if len(messages) == 0 {
		if err == nil {
			return ""
		}
		return err.Error()
	}

	parts := make([]string, 0, len(messages))
	for _, msg := range messages {
		parts = append(parts, msg.Field+": "+msg.Message)
	}
	return strings.Join(parts, "; ")
}

// Enum 用枚举的合法取值构造一个类型安全的校验器。
// [EN] Enum builds a type-safe validator from the allowed enum values
//
// 直接把生成的枚举值传进来，不要在 tag 里手写 oneof 列表：
// proto 加了新枚举值时，手写的列表不会自动跟上。
// [EN] Pass the generated enum values instead of hand-writing an oneof list in a tag:
// a hand-written list silently goes stale when proto gains a new value
//
//	var statusEnum = validation.Enum(enums.CommonStatus_COMMON_STATUS_NORMAL, enums.CommonStatus_COMMON_STATUS_DISABLED)
//	ok := statusEnum.IsValid(req.Status)          // 布尔判断 | boolean check
//	err := statusEnum.MustBeValid(req.Status)     // 返回带 i18n 消息的错误 | localized error
func Enum[T comparable](values ...T) *argusvalidate.EnumValidator[T] {
	return validator.NewEnumValidator(values...)
}

// registerCustomRules 注册项目自有规则。
// [EN] registerCustomRules registers project-specific rules
//
// 这里放「内置 126 条规则覆盖不到」的业务约束，注册后即可在 proto 注释里使用，
// 例如 @inject_tag: validate:"required,tenant_id"
// [EN] Put business constraints the 126 built-in rules do not cover here; once
// registered they can be used from proto comments, e.g. validate:"required,tenant_id"
func registerCustomRules(v *validator.Validate) {
	// tenant_id：租户ID 必须是小写字母、数字和连字符，长度 2-64
	// [EN] tenant_id: lower-case letters, digits and hyphens, length 2-64
	_ = v.RegisterValidation("tenant_id", func(fl validator.FieldLevel) bool {
		value := fl.Field().String()
		if len(value) < 2 || len(value) > 64 {
			return false
		}
		for _, r := range value {
			switch {
			case r >= 'a' && r <= 'z':
			case r >= '0' && r <= '9':
			case r == '-':
			default:
				return false
			}
		}
		return true
	})
}

// registerExtraLocales 注册内置九种语言之外的语言。
// [EN] regsterExtraLocales adds languages beyond the nine built-in locales
func registerExtraLocales() {
	// 示例：葡萄牙语只需补齐用到的规则名，未覆盖的会回落到默认语言。
	// [EN] Example: Portuguese. Only the rules you use need entries; the rest fall back
	validator.RegisterI18nMessages("pt", map[string]string{
		"required": "{field} é obrigatório",
		"min":      "{field} deve ter no mínimo {param} caracteres",
		"max":      "{field} deve ter no máximo {param} caracteres",
		"email":    "{field} deve ser um e-mail válido",
	})
}
