/*
 * @Author: <% .AuthorName %> <% .AuthorEmail %>
 * @Date: <% nowFmt "2006-01-02 15:04:05" %>
 * @LastEditors: <% .AuthorName %> <% .AuthorEmail %>
 * @LastEditTime: <% nowFmt "2006-01-02 15:04:05" %>
 * @FilePath: \<% .ProjectName %>\validation\contract_test.go
 * @Description: proto -> inject-tags -> 校验的契约测试 | Contract test for proto -> inject-tags -> validation
 *
 * Copyright (c) <% .Year %> by <% .AuthorName %>, All Rights Reserved.
 */

// 运行前提 | Prerequisite
//
// 本文件 import 生成代码，所以必须先跑过 scripts/generate-modular.sh。
// 刚 kopy new 出来的项目 pb/ 还是空的，此时 go mod tidy 会失败 —— 这不是模板的缺陷，
// 而是「协议仓库先生成、再解析依赖」的固有顺序：
//
//	setup-all.sh -> generate-modular.sh -> go mod tidy -> go build/test
//
// 加 build tag 也救不了：go mod tidy 会忽略 build tag，照样去解析这里的 import。
//
// [EN] This file imports generated code, so scripts/generate-modular.sh must run first.
// A freshly scaffolded project has an empty pb/ and go mod tidy fails there — not a
// template defect but the inherent order of a contract repository:
// setup-all.sh -> generate-modular.sh -> go mod tidy -> go build/test.
// A build tag would not help: go mod tidy ignores build tags and resolves these imports anyway.
//
// 它守住的是一条容易悄悄断掉的链路：proto 注释里的 @inject_tag 必须真的被
// inject-tags.sh 注入成结构体 tag，否则校验层对着没有 tag 的结构体永远返回 nil，
// 线上就是「校验看起来在跑，实际什么都没拦住」。
//
// [EN] It guards a chain that breaks silently: @inject_tag in proto comments must really
// be injected as struct tags by inject-tags.sh, otherwise the validation layer sees
// untagged structs, always returns nil, and production validates nothing at all.

package validation_test

import (
	"strings"
	"testing"

	"<% .ModuleName %>/pb/<% .ExampleModule %>"
	"<% .ModuleName %>/pb/enums"
	"<% .ModuleName %>/pb/<% .MixedModule %>"
	"<% .ModuleName %>/pb/<% .SecondModule %>"
	"<% .ModuleName %>/validation"
)

func TestInjectedTags_EnforceRequiredFieldsOf<% .ExampleService | pascal %>(t *testing.T) {
	err := validation.Struct(&<% .ExampleModule %>.<% .ExampleService | pascal %>CreateRequest{})
	if err == nil {
		t.Fatal("空的创建请求必须被拦住，若通过说明 @inject_tag 没有被注入 | an empty create request must be rejected; passing means @inject_tag was not injected")
	}

	fields := map[string]bool{}
	for _, msg := range validation.Messages(err, "zh") {
		fields[msg.Field] = true
	}

	// 字段名取的是 json tag，和 HTTP 请求体里的字段名一致，可直接回给前端。
	// [EN] Field names come from the json tag, matching the HTTP body, so they can be returned as-is
	for _, want := range []string{"tenant_id", "name", "code"} {
		if !fields[want] {
			t.Fatalf("缺少 %s 的校验错误 | missing validation error for %s, got %v", want, want, fields)
		}
	}
}

func TestInjectedTags_AcceptValid<% .ExampleService | pascal %>Request(t *testing.T) {
	req := &<% .ExampleModule %>.<% .ExampleService | pascal %>CreateRequest{
		TenantId: "acme-01",
		Name:     "<% .ExampleService | pascal %> A",
		Code:     "code-a",
	}
	if err := validation.Struct(req); err != nil {
		t.Fatalf("合法请求不应报错 | a valid request must pass: %v", err)
	}
}

func TestInjectedTags_EnforceRequiredFieldsOf<% .SecondService | pascal %>(t *testing.T) {
	err := validation.Struct(&<% .SecondModule %>.<% .SecondService | pascal %>CreateRequest{})
	if err == nil {
		t.Fatal("空的创建请求必须被拦住 | an empty create request must be rejected")
	}
	if summary := validation.Summary(err, "en"); !strings.Contains(summary, "name") {
		t.Fatalf("摘要应包含 name 字段 | summary should mention name, got %q", summary)
	}
}

func TestInjectedTags_RejectMalformedIdentifiers(t *testing.T) {
	// tenant_id 用的是本项目注册的自定义规则，大写与下划线都不合法。
	// [EN] tenant_id uses this project's custom rule: upper-case and underscores are invalid
	req := &<% .ExampleModule %>.<% .ExampleService | pascal %>CreateRequest{
		TenantId: "ACME_01",
		Name:     "<% .ExampleService | pascal %> A",
		Code:     "code-a",
	}
	err := validation.Struct(req)
	if err == nil {
		t.Fatal("非法 tenant_id 必须被拦住 | a malformed tenant_id must be rejected")
	}
}

// 混合模块：同一个 Go 包里有两个 service，两边的请求都要被校验覆盖
// [EN] Mixed module: one Go package hosts two services and requests on both must be covered
func TestInjectedTags_CoverBothServicesOf<% .MixedService | pascal %>Module(t *testing.T) {
	// 聚合根的创建请求 | the aggregate root's create request
	rootErr := validation.Struct(&<% .MixedModule %>.<% .MixedService | pascal %>CreateRequest{})
	if rootErr == nil {
		t.Fatal("聚合根的空创建请求必须被拦住 | an empty create request on the aggregate root must be rejected")
	}

	// 同模块第二个 service 的批量请求 | the batch request of the module's second service
	memberErr := validation.Struct(&<% .MixedModule %>.<% .MixedService | pascal %>MemberBatchInviteRequest{})
	if memberErr == nil {
		t.Fatal("成员批量邀请的空请求必须被拦住 | an empty batch-invite request must be rejected")
	}

	fields := map[string]bool{}
	for _, msg := range validation.Messages(memberErr, "zh") {
		fields[msg.Field] = true
	}
	for _, want := range []string{"<% .MixedService | snake %>_id", "emails", "roles"} {
		if !fields[want] {
			t.Fatalf("缺少 %s 的校验错误 | missing validation error for %s, got %v", want, want, fields)
		}
	}
}

func TestInjectedTags_EnforceBatchSizeCap(t *testing.T) {
	// 批量接口的上限写在 proto 注释里（max=50），这里确认它真的生效
	// [EN] The batch cap is declared in the proto comment (max=50); this checks it is enforced
	emails := make([]string, 0, 51)
	for i := 0; i < 51; i++ {
		emails = append(emails, "user@example.com")
	}

	req := &<% .MixedModule %>.<% .MixedService | pascal %>MemberBatchInviteRequest{
		<% .MixedService | pascal %>Id: "t-1",
		Emails:        emails,
		Roles:         []enums.<% .MixedService | pascal %>MemberRole{enums.<% .MixedService | pascal %>MemberRole_<% .MixedService | snake | upper %>_MEMBER_ROLE_VIEWER},
	}
	if err := validation.Struct(req); err == nil {
		t.Fatal("超过批量上限必须被拦住 | exceeding the batch cap must be rejected")
	}
}
