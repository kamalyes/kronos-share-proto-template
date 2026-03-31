name: Generate Protobuf

run-name: 🔧 [auto-generate-pb] by @${{ github.actor }} • ${{ github.sha }}

# PR 合并到 <% .BaseBranch %> 后自动重新生成 pb 并提交
# 仅 proto 目录变更时触发，生成结果无 diff 则不提交（幂等）
permissions:
  contents: write
  pull-requests: write

on:
  push:
    branches:
      - <% .BaseBranch %>
    paths:
      - 'proto/**'
  # PR 触发机器人：proto 变更时自动验证 pb 是否同步，结果评论到 PR
  pull_request:
    branches:
      - <% .BaseBranch %>
    types:
      - opened
      - synchronize
      - reopened
    paths:
      - 'proto/**'
  # 手动验证入口：默认仅生成并验证（不提交），勾选 push-changes 才推送
  workflow_dispatch:
    inputs:
      push-changes:
        description: '验证通过后将生成结果提交到 <% .BaseBranch %>（默认仅验证不提交）'
        required: false
        type: boolean
        default: false

jobs:
  generate-pb:
    name: Generate PB & Commit
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: ⬇️ Checkout Repository
        uses: actions/checkout@v6
        with:
          # 生成提交需要完整历史，避免 push 时落后远端
          fetch-depth: 0

      - name: 🐹 Setup Go
        uses: actions/setup-go@v6
        with:
          go-version-file: go.mod

      - name: 💾 Cache Protobuf Toolchain
        # 缓存 protoc + protoc 插件（~/go/bin）与 googleapis/gateway 克隆（~/go/src）
        # setup-all.sh 自带版本校验，缓存命中时跳过安装；脚本变更自动失效重装
        uses: actions/cache@v4
        with:
          path: |
            ~/go/bin
            ~/go/src
          key: pb-tools-${{ runner.os }}-${{ hashFiles('scripts/common.sh', 'scripts/setup-dependencies.sh', 'scripts/setup-protobuf-includes.sh') }}

      - name: 📥 Install Protobuf Dependencies
        run: |
          bash scripts/setup-all.sh --no-pause

      - name: 🔧 Generate Protobuf Files
        run: |
          bash scripts/generate-modular.sh

      - name: ✅ Verify Generated Code
        # 顺序固定：先 generate（上一步）再 tidy，pb/ 为空时 tidy 解析不到自身的 pb 包
        # go test 会跑 validation/contract_test.go，确认 @inject_tag 真的注入成了 struct tag
        # [EN] Fixed order: generate first, then tidy, because tidy cannot resolve pb/ while empty.
        # go test runs validation/contract_test.go to confirm @inject_tag really became struct tags.
        run: |
          go mod tidy
          go build ./...
          go test ./...

      - name: 🔍 Check For Changes
        id: changes
        run: |
          git add -A
          {
            echo "## 🔍 pb 生成验证结果"
            echo ""
          } >> $GITHUB_STEP_SUMMARY
          if git diff --cached --quiet; then
            echo "changed=false" >> $GITHUB_OUTPUT
            {
              echo "✅ 生成结果与当前分支一致，无差异"
              echo ""
              echo "**模式**：${{ github.event_name == 'push' && '自动提交（无 diff，跳过）' || (github.event_name == 'pull_request' && 'PR 验证（pb 已同步）' || '手动验证（无 diff）') }}"
            } >> $GITHUB_STEP_SUMMARY
            echo "✅ pb 生成结果与当前分支一致，无需提交"
          else
            echo "changed=true" >> $GITHUB_OUTPUT
            {
              echo "diff_stat<<GENERATE_PB_EOF"
              git diff --cached --stat
              echo "GENERATE_PB_EOF"
            } >> "$GITHUB_OUTPUT"
            {
              echo "diff_full<<GENERATE_PB_DIFF_EOF"
              git diff --cached
              echo "GENERATE_PB_DIFF_EOF"
            } >> "$GITHUB_OUTPUT"
            {
              echo "📋 生成结果存在差异，待提交文件："
              echo ""
              echo '```'
              git diff --cached --stat
              echo '```'
              echo ""
              echo "<details>"
              echo "<summary>📖 点击展开完整差异内容</summary>"
              echo ""
              echo '```diff'
              git diff --cached
              echo '```'
              echo ""
              echo "</details>"
              echo ""
              echo "**模式**：${{ github.event_name == 'push' && '自动提交' || (github.event_name == 'pull_request' && 'PR 验证（pb 未同步，待 PR 更新）' || (inputs.push-changes && '手动验证并提交' || '手动验证（未提交，仅查看）')) }}"
            } >> $GITHUB_STEP_SUMMARY
            echo "📋 待提交文件："
            git diff --cached --stat
            echo ""
            echo "📖 完整差异明细："
            echo "=================================================="
            git diff --cached
            echo "=================================================="
          fi

      - name: 💬 Report to PR
        # PR 模式：机器人把验证结果评论到 PR（幂等，更新同一条评论不刷屏）
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        env:
          CHANGED: ${{ steps.changes.outputs.changed }}
          DIFF_STAT: ${{ steps.changes.outputs.diff_stat }}
          DIFF_FULL: ${{ steps.changes.outputs.diff_full }}
        with:
          script: |
            const marker = '<!-- generate-pb-report -->';
            const changed = process.env.CHANGED === 'true';
            const stat = (process.env.DIFF_STAT || '').trim();
            const full = (process.env.DIFF_FULL || '').trim();
            let body = marker + '\n## 🔧 pb 生成验证报告\n\n';
            if (changed) {
              body += '⚠️ **proto 变更后 pb 未同步重新生成**，以下文件需要更新：\n\n'
                + '```\n' + stat + '\n```\n\n'
                + '<details>\n<summary>📖 点击展开完整差异内容</summary>\n\n'
                + '```diff\n' + full + '\n```\n\n</details>\n\n'
                + '💡 请在本地执行 `bash scripts/generate-modular.sh` 并将生成结果提交到本 PR；'
                + '或合并后由 <% .BaseBranch %> 的自动生成流程补齐（业务子服务引用新 hash 前请等待补齐）';
            } else {
              body += '✅ **pb 生成结果与 PR 分支一致**，proto 与 pb 已同步，可以合并';
            }
            const params = {
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
            };
            const { data: comments } = await github.rest.issues.listComments(params);
            const existing = comments.find(c => c.body && c.body.includes(marker));
            if (existing) {
              await github.rest.issues.updateComment({
                owner: params.owner,
                repo: params.repo,
                comment_id: existing.id,
                body,
              });
            } else {
              await github.rest.issues.createComment({ ...params, body });
            }

      - name: 🚀 Commit & Push Generated PB
        if: steps.changes.outputs.changed == 'true' && (github.event_name == 'push' || inputs.push-changes == true)
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git commit \
            -m "🔧 chore(ci): <% .BaseBranch %> 合并后自动生成 pb 代码 [ci skip]" \
            -m "- 🔄 proto 变更后自动重新生成 pb/gw/swagger 并提交（pb/、proto/*.swagger.yaml）"$'\n'"- ✅ 生成物经 go build 验证后推送"
          git pull --rebase origin "${{ github.ref_name }}"
          git push origin HEAD:"${{ github.ref_name }}"

      - name: 📢 Prepare Notify
        # PR 验证运行必发卡片（含 PR 直达链接）；push/手动模式仅差异或失败时发送
        id: notify-prep
        if: ${{ always() && (failure() || steps.changes.outputs.changed == 'true' || github.event_name == 'pull_request') }}
        env:
          CHANGED: ${{ steps.changes.outputs.changed }}
          DIFF_STAT: ${{ steps.changes.outputs.diff_stat }}
          PR_TITLE: ${{ github.event.pull_request.title }}
          PR_URL: ${{ github.event.pull_request.html_url }}
          PR_BRANCH: ${{ github.event.pull_request.head.ref }}
          PR_AUTHOR: ${{ github.event.pull_request.user.login }}
        run: |
          if [ "${{ job.status }}" != "success" ]; then
            echo "status=failure" >> $GITHUB_OUTPUT
            echo "title=❌ pb 生成流程运行失败" >> $GITHUB_OUTPUT
            {
              echo "message<<NOTIFY_MSG_EOF"
              echo "运行失败，请查看日志定位原因"
              echo "NOTIFY_MSG_EOF"
            } >> $GITHUB_OUTPUT
            exit 0
          fi
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            if [ "$CHANGED" = "true" ]; then
              echo "status=warning" >> $GITHUB_OUTPUT
              echo "title=⚠️ PR 的 pb 与 proto 未同步" >> $GITHUB_OUTPUT
            else
              echo "status=success" >> $GITHUB_OUTPUT
              echo "title=✅ PR 的 pb 已同步，可以合并" >> $GITHUB_OUTPUT
            fi
            {
              echo "message<<NOTIFY_MSG_EOF"
              echo "**PR**：[${PR_TITLE}](${PR_URL})"
              echo "**分支**：${PR_BRANCH} → <% .BaseBranch %>　**作者**：${PR_AUTHOR}"
              if [ "$CHANGED" = "true" ]; then
                echo "**差异文件**："
                echo '```'
                echo "${DIFF_STAT}"
                echo '```'
                echo "请在 PR 中更新 pb 后再合并（或合并后等待 <% .BaseBranch %> 自动补齐）"
              else
                echo "proto 与 pb 已同步，等待 review 合并"
              fi
              echo "NOTIFY_MSG_EOF"
            } >> $GITHUB_OUTPUT
          else
            echo "status=warning" >> $GITHUB_OUTPUT
            case "${{ github.event_name }}" in
              push) title="✅ pb 已自动生成并提交 <% .BaseBranch %>"; mode="<% .BaseBranch %> 合并后自动提交" ;;
              *)    title="📋 pb 生成验证发现差异";           mode="手动验证（未提交）" ;;
            esac
            echo "title=${title}" >> $GITHUB_OUTPUT
            {
              echo "message<<NOTIFY_MSG_EOF"
              echo "**模式**：${mode}"
              echo "**差异文件**："
              echo '```'
              echo "${DIFF_STAT:-无}"
              echo '```'
              echo "NOTIFY_MSG_EOF"
            } >> $GITHUB_OUTPUT
          fi

      - name: 📢 Notify Lark
        if: ${{ always() && (failure() || steps.changes.outputs.changed == 'true' || github.event_name == 'pull_request') }}
        uses: <% .PipelineRepo %>/.github/actions/notify@master
        env:
          FEISHU_WEBHOOK_URL: ${{ secrets.FEISHU_WEBHOOK_URL }}
        with:
          provider: feishu
          status: ${{ steps.notify-prep.outputs.status }}
          title: ${{ steps.notify-prep.outputs.title }}
          message: ${{ steps.notify-prep.outputs.message }}
