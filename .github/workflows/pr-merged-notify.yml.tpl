name: PR Merged Notify

# PR 合并后飞书机器人推送（复用 deploy-pipeline 公共能力，secrets: inherit 传递 webhook）
on:
  pull_request:
    types:
      - closed

jobs:
  notify:
    name: Notify Lark
    if: github.event.pull_request.merged == true
    uses: <% .PipelineRepo %>/.github/workflows/pr-merged-notify.yml@master
    secrets: inherit
