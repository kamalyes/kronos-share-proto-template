---
alwaysApply: true
scene: git_message
---

# Commit Message 规范 | Commit message conventions

本仓库的唯一提交规范两份旧文（Trae 的 `rules/git-commit-message.md` 与
`.github/copilot-instructions.md`）曾各自定义了一套 emoji，feat 一个 ✨ 一个 🔥，
refactor 一个 🧹 一个 ♻️，同一个仓库会产出两种风格现以实际在用的那一套为准

[EN] The single commit convention for this repository. Two earlier copies each defined their
own emoji set, so the same repository produced two styles; this merges them onto the set
actually in use

---

## 1. 标题格式 | Subject line

```text
<emoji> <type>(<scope 可选>): <简短描述>
```

- 语言：简体中文 | Simplified Chinese
- 长度：不超过 50 字 | at most 50 characters
- `scope` 可选，填模块名或目录名，如 `feat(i18n)`、`fix(gateway)`

## 2. Emoji 与类型对照 | Emoji and type table

| 改动类型 \| Kind | Emoji | `type` | 示例 \| Example |
| --- | --- | --- | --- |
| 新功能 / 重要更新 | 🔥 | `feat` | `🔥 feat: 新增租户地区分配接口` |
| Bug 修复 | 🐛 | `fix` | `🐛 fix: 修复分页 total 未回填` |
| 依赖更新 | 📦 | `chore` | `📦 chore: 升级 protoc-gen-go v1.36.4` |
| 代码重构 | ♻️ | `refactor` | `♻️ refactor: 公共分页消息提到 common/` |
| 国际化 | 🌍 | `feat(i18n)` | `🌍 feat(i18n): 校验错误补齐九种语言` |
| 性能优化 | ⚡ | `perf` | `⚡ perf: 校验层改走零反射路径` |
| 文档 / 注释 | 📝 | `docs` | `📝 docs: 补充 proto 规范第 8 节` |
| CI / 流水线 | 👷 | `ci` | `👷 ci: 发版流水线联动下游仓库` |
| 测试 | ✅ | `test` | `✅ test: 补齐网关聚合一致性用例` |
| 删除 / 清理 | 🗑️ | `chore` | `🗑️ chore: 删除未使用的预编译正则` |
| 安全相关 | 🛡️ | `fix` | `🛡️ fix: 密钥不再进日志` |
| 基础设施 / 配置 | 🔧 | `chore` | `🔧 chore: 固定 protoc 版本` |
| 新建服务 / 模块 | 🏗️ | `feat` | `🏗️ feat: 新增计费模块 proto` |

## 3. 正文 | Body

小改动只给标题即可大改动在标题下用小项逐条列出，每条以 `- <emoji>` 开头，
中文描述 + 括号内注明涉及文件

[EN] A small change needs only a subject. A larger one lists each change as `- <emoji>` with a
Chinese description and the files involved in parentheses

```text
🔥 feat: 新增租户地区分配接口

- ✨ 新增 TenantRegionAssign / TenantRegionUnassign 两个 rpc（tenant/tenant_service.proto）
- 🔧 登记模块到生成脚本（scripts/generate-modular.sh、.bat）
- 📝 补充子资源 URL 约定示例（.trae/skills/kronos-proto-style/SKILL.md）

极简版：🔥 feat: 新增租户地区分配接口
```

末尾附一个极简一行版本，方便需要单行提交时直接取用
[EN] End with a one-line version, ready to use when a single-line commit is wanted

## 4. 硬性要求 | Hard rules

| # | 要求 \| Rule | 说明 \| Why |
| --- | --- | --- |
| 1 | 仅输出 commit message，不要额外解释 | 输出会被直接粘进 `git commit` |
| 2 | 一个提交只做一件逻辑改动 | 便于 revert 与 review，不要把格式化和功能混在一起 |
| 3 | 不添加任何 AI 署名行 | 不要 `Co-Authored-By` 之类的尾注 |
| 4 | 生成前先看暂存区 | 按 `git diff --cached` 的真实内容写，不要凭文件名猜 |

## 5. 触发词 | Trigger phrases

下列任一输入都应套用本规范：`生成 commit`、`commit message`、`分析改动`、`git diff`、`@commit`

[EN] Any of these inputs applies this convention
