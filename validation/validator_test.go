/*
 * @Author: kamalyes example@qq.com
 * @Date: 2026-10-30 09:08:16
 * @LastEditors: kamalyes example@qq.com
 * @LastEditTime: 2026-10-30 09:08:16
 * @FilePath: \kronos-share-proto-template\validation\validator_test.go
 * @Description: 校验层单测 | Unit tests for the validation layer
 *
 * Copyright (c) 2026 by kamalyes, All Rights Reserved.
 */

package validation

import (
	"context"
	"strings"
	"testing"

	validator "github.com/kamalyes/go-argus"
)

// 本地结构体镜像 inject-tags 注入后的 pb 形态，使本文件不依赖生成代码。
// [EN] A local struct mirroring the post-inject-tags pb shape, so this file needs no generated code
// 依赖真实 pb 的契约测试在 contract_pb_test.go（需 -tags pb）。
// [EN] The contract test against real pb lives in contract_pb_test.go (needs -tags pb)
type productCreateRequest struct {
	TenantId string          `json:"tenant_id" validate:"required,tenant_id"`
	Name     string          `json:"name" validate:"required,min=2,max=64"`
	Email    string          `json:"email" validate:"omitempty,email"`
	Price    int64           `json:"price" validate:"gte=0,lte=1000000"`
	Paging   *productPaging  `json:"paging" validate:"omitempty"`
	Contact  *productContact `json:"contact" validate:"omitempty"`
}

// 嵌套结构体镜像 common/ 下的公共消息（生成代码里是指针字段）。
// [EN] Nested structs mirror the shared messages under common/ (pointer fields in generated code)
type productPaging struct {
	Page int32 `json:"page" validate:"omitempty,gte=1"`
	Size int32 `json:"size" validate:"omitempty,gte=1,lte=200"`
}

type productContact struct {
	Email string `json:"email" validate:"omitempty,email"`
	Phone string `json:"phone" validate:"omitempty,e164"`
}

func validRequest() productCreateRequest {
	return productCreateRequest{
		TenantId: "acme-01",
		Name:     "Widget",
		Email:    "ops@example.com",
		Price:    1999,
	}
}

// ============================================================================
// 结构体校验 | Struct validation
// ============================================================================

func TestStruct_AcceptsValidRequest(t *testing.T) {
	if err := Struct(validRequest()); err != nil {
		t.Fatalf("合法请求不应报错 | valid request must pass: %v", err)
	}
}

func TestStruct_RejectsMissingRequiredFields(t *testing.T) {
	err := Struct(productCreateRequest{})
	if err == nil {
		t.Fatal("空请求必须被拦住 | an empty request must be rejected")
	}

	messages := Messages(err, "zh")
	if len(messages) == 0 {
		t.Fatal("必须给出字段级消息 | per-field messages are required")
	}

	fields := make(map[string]string, len(messages))
	for _, msg := range messages {
		fields[msg.Field] = msg.Message
	}
	for _, want := range []string{"tenant_id", "name"} {
		if _, ok := fields[want]; !ok {
			t.Fatalf("缺少字段 %s 的错误 | missing error for field %s, got %v", want, want, fields)
		}
	}
}

func TestStruct_RejectsOutOfRangeAndBadEmail(t *testing.T) {
	req := validRequest()
	req.Name = "W"                 // 短于 min=2 | shorter than min=2
	req.Email = "not-an-email"     // 不是邮箱 | not an email
	req.Price = -1                 // 小于 gte=0 | below gte=0

	err := Struct(req)
	if err == nil {
		t.Fatal("越界与格式错误必须被拦住 | out-of-range and malformed values must be rejected")
	}

	summary := Summary(err, "en")
	for _, want := range []string{"name", "email", "price"} {
		if !strings.Contains(summary, want) {
			t.Fatalf("摘要应包含字段 %s | summary should mention %s, got %q", want, want, summary)
		}
	}
}

func TestStruct_ValidatesNestedMessages(t *testing.T) {
	// 生成代码里 common/ 的公共消息是指针字段，必须确认校验会递归进去，
	// 否则 Paging.size 这类「藏在子结构里的上限」等于没写。
	// [EN] Shared messages from common/ are pointer fields in generated code; validation
	// must recurse into them or a cap like Paging.size is silently unenforced
	req := validRequest()
	req.Paging = &productPaging{Page: 1, Size: 10000} // 超过 lte=200 | above lte=200

	err := Struct(req)
	if err == nil {
		t.Fatal("嵌套结构体里的越界值必须被拦住 | an out-of-range value inside a nested struct must be rejected")
	}
	if summary := Summary(err, "en"); !strings.Contains(summary, "size") {
		t.Fatalf("摘要应指向嵌套字段 size | summary should point at the nested size field, got %q", summary)
	}

	req.Paging = &productPaging{Page: 1, Size: 20}
	req.Contact = &productContact{Email: "not-an-email"}
	if err := Struct(req); err == nil {
		t.Fatal("嵌套结构体里的格式错误必须被拦住 | a malformed value inside a nested struct must be rejected")
	}

	req.Contact = &productContact{Email: "ops@example.com", Phone: "+8613800138000"}
	if err := Struct(req); err != nil {
		t.Fatalf("合法嵌套结构体不应报错 | valid nested structs must pass: %v", err)
	}
}

func TestStructCtx_PassesContext(t *testing.T) {
	ctx := context.Background()
	if err := StructCtx(ctx, validRequest()); err != nil {
		t.Fatalf("带上下文校验不应报错 | context-aware validation must pass: %v", err)
	}
}

// ============================================================================
// 国际化 | Internationalization
// ============================================================================

func TestMessages_LocaleChangesText(t *testing.T) {
	err := Struct(productCreateRequest{})

	zh := Messages(err, "zh")
	en := Messages(err, "en")
	if len(zh) == 0 || len(en) == 0 {
		t.Fatal("两种语言都应返回消息 | both locales must return messages")
	}
	if zh[0].Message == en[0].Message {
		t.Fatalf("中英消息不应相同 | zh and en messages must differ: %q", zh[0].Message)
	}
}

func TestMessages_RegisteredExtraLocale(t *testing.T) {
	V() // 触发初始化，注册额外语言 | trigger init so extra locales are registered
	err := Struct(productCreateRequest{})

	pt := Messages(err, "pt")
	if len(pt) == 0 {
		t.Fatal("注册过的语言必须可用 | a registered locale must be usable")
	}
	if !strings.Contains(pt[0].Message, "obrigatório") {
		t.Fatalf("应命中葡萄牙语翻译 | expected the Portuguese message, got %q", pt[0].Message)
	}
}

func TestMessages_NilErrorReturnsNothing(t *testing.T) {
	if msgs := Messages(nil, "zh"); msgs != nil {
		t.Fatalf("nil 错误应返回 nil | nil error must yield nil, got %v", msgs)
	}
	if summary := Summary(nil, "zh"); summary != "" {
		t.Fatalf("nil 错误摘要应为空 | nil error summary must be empty, got %q", summary)
	}
}

// ============================================================================
// 自定义规则 | Custom rules
// ============================================================================

func TestCustomRule_TenantID(t *testing.T) {
	cases := []struct {
		tenant string
		valid  bool
		reason string
	}{
		{"acme-01", true, "小写字母数字连字符 | lower-case, digits, hyphen"},
		{"a", false, "短于 2 个字符 | shorter than 2 chars"},
		{"ACME", false, "包含大写字母 | contains upper-case"},
		{"acme_01", false, "包含下划线 | contains underscore"},
	}

	for _, c := range cases {
		req := validRequest()
		req.TenantId = c.tenant
		err := Struct(req)
		if c.valid && err != nil {
			t.Fatalf("%s 应通过（%s）| %q should pass: %v", c.tenant, c.reason, c.tenant, err)
		}
		if !c.valid && err == nil {
			t.Fatalf("%s 应被拒（%s）| %q should be rejected", c.tenant, c.reason, c.tenant)
		}
	}
}

// ============================================================================
// 枚举校验 | Enum validation
// ============================================================================

func TestEnum_ValidatesAllowedValues(t *testing.T) {
	// 生成的枚举底层是 int32，这里用 int32 模拟 | generated enums are int32 underneath
	const (
		statusNormal   int32 = 1
		statusDisabled int32 = 2
		statusUnknown  int32 = 99
	)

	allowed := Enum(statusNormal, statusDisabled)

	if !allowed.IsValid(statusNormal) {
		t.Fatal("合法枚举值应通过 | an allowed value must pass")
	}
	if allowed.IsValid(statusUnknown) {
		t.Fatal("未定义枚举值应被拒 | an undefined value must be rejected")
	}
	if err := allowed.MustBeValid(statusUnknown); err == nil {
		t.Fatal("MustBeValid 应返回错误 | MustBeValid must return an error")
	}
	if got := len(allowed.GetValidValues()); got != 2 {
		t.Fatalf("合法取值应为 2 个 | expected 2 allowed values, got %d", got)
	}
}

// ============================================================================
// 零反射快路径 | Zero-reflection fast path
// ============================================================================

func TestVarString_FastPath(t *testing.T) {
	if err := VarString("ops@example.com", "email"); err != nil {
		t.Fatalf("合法邮箱应通过 | a valid email must pass: %v", err)
	}
	if err := VarString("nope", "email"); err == nil {
		t.Fatal("非法邮箱应被拒 | an invalid email must be rejected")
	}
	if err := VarString("550e8400-e29b-41d4-a716-446655440000", "uuid4"); err != nil {
		t.Fatalf("合法 UUID 应通过 | a valid UUID must pass: %v", err)
	}
}

func BenchmarkVarString(b *testing.B) {
	// 零反射路径：期望 0 allocs/op | the zero-reflection path should report 0 allocs/op
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = VarString("ops@example.com", "email")
	}
}

// ============================================================================
// JSON Schema 与网关工具 | JSON Schema and gateway helpers
// ============================================================================

func TestJSONSchema_ValidatesWebhookPayload(t *testing.T) {
	// 第三方回调往往没有 proto 契约，只能按 JSON Schema 校验。
	// [EN] Third-party callbacks have no proto contract, so JSON Schema is the fallback
	schema := validator.QuickSchema(map[string]string{
		"event_id": "string",
		"type":     "string",
	}, "event_id", "type")

	ok := validator.ValidateJSONSchema(map[string]any{"event_id": "evt_1", "type": "order.paid"}, schema)
	if !ok.Success {
		t.Fatalf("合法载荷应通过 | a valid payload must pass: %s", ok.Message)
	}

	missing := validator.ValidateJSONSchema(map[string]any{"event_id": "evt_1"}, schema)
	if missing.Success {
		t.Fatal("缺少必填字段应失败 | a missing required field must fail")
	}
}

func TestIPAllowlist_GuardsInternalCallers(t *testing.T) {
	allowed := []string{"10.0.0.0/8", "192.168.1.*"}

	if !validator.IsIPAllowed("10.3.4.5", allowed) {
		t.Fatal("CIDR 内的 IP 应放行 | an IP inside the CIDR must be allowed")
	}
	if !validator.IsIPAllowed("192.168.1.77", allowed) {
		t.Fatal("通配符匹配的 IP 应放行 | a wildcard match must be allowed")
	}
	if validator.IsIPAllowed("8.8.8.8", allowed) {
		t.Fatal("白名单外的 IP 应拦截 | an IP outside the allowlist must be blocked")
	}
}
