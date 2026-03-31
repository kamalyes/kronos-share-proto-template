name: PR Opened Notify

# PR 开启时机器人评论变更摘要并推送飞书（复用 deploy-pipeline 公共能力）
on:
  pull_request:
    types:
      - opened

permissions:
  contents: read
  pull-requests: write

jobs:
  summarize:
    name: Summarize & Notify
    uses: <% .PipelineRepo %>/.github/workflows/pr-opened-notify.yml@master
    secrets: inherit
