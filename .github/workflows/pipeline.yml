name: CI/CD Pipeline

run-name: 🚀 [${{ inputs.environment || github.ref_name }}] by @${{ github.actor }} • ${{ github.sha }}

# 全局环境变量 - 仅保留动态/项目特有配置
# 静态配置（端口、K8s 资源限制等）由 deploy-pipeline 的 reusable workflow 自动读取 vars
# 注意：gateway 服务无 gRPC 端口，RPC_PORT 设为 none
# 注意：本项目入口为 ./bootstrap 而非 ./main.go，构建入口通过 BINARY_BUILD_DIR 指定
env:
  BINARY_NAME: ${{ vars.BINARY_NAME || github.event.repository.name }}
  BINARY_SOURCE_DIR: ${{ vars.BINARY_SOURCE_DIR || 'deployments' }}
  DOCKER_K8S_ALLOWED_ENVS: ${{ vars.DOCKER_K8S_ALLOWED_ENVS || 'dev,test,uat,prod' }}

permissions:
  contents: write # release-note job 创建 GitHub Release 需要（tag 发布模式）
  packages: write
  pull-requests: read # release-note job 收集 PR 明细需要（tag 发布模式）

on:
  push:
    branches:
      - dev
    tags:
      - 'v*' # 打 tag 触发发布模式：仅构建推送镜像不部署
      - 'prod-*' # prod- 前缀 tag 同样触发发布模式
    paths-ignore:
      - '**/*.md'
  workflow_dispatch:
    inputs:
      environment:
        description: '部署环境'
        required: true
        type: choice
        options:
          - dev
          - test
          - uat
          - prod
        default: dev
      code-quality:
        description: '是否进行代码质量检查'
        required: false
        type: boolean
        default: false
      notification-provider:
        description: '通知提供商 (none/feishu/telegram/all)'
        required: false
        type: choice
        options:
          - none
          - feishu
          - telegram
          - all
        default: feishu
      build-docker:
        description: '是否构建 Docker 镜像推送仓库'
        required: false
        type: boolean
        default: true
      deploy-k8s:
        description: '是否部署到 K8s (需要Docker镜像,会自动构建)'
        required: false
        type: boolean
        default: true
      enable-hpa:
        description: '是否启用 HPA (水平自动扩缩容)'
        required: false
        type: boolean
        default: false

jobs:
  # 准备环境 - 仅计算动态值和部署决策
  setup:
    name: Setup Environment
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'dev' }}
    outputs:
      binary-name: ${{ steps.setup-vars.outputs.binary-name }}
      binary-source-dir: ${{ steps.setup-vars.outputs.binary-source-dir }}
      binary-output: ${{ steps.setup-vars.outputs.binary-output }}
      version: ${{ steps.setup-vars.outputs.version }}
      build-time: ${{ steps.setup-vars.outputs.build-time }}
      git-commit: ${{ steps.setup-vars.outputs.git-commit }}
      short-commit: ${{ steps.setup-vars.outputs.short-commit }}
      image-base: ${{ steps.setup-vars.outputs.image-base }}
      image-name: ${{ steps.setup-vars.outputs.image-name }}
      release-mode: ${{ steps.setup-vars.outputs.release-mode }}
      should-build-docker: ${{ steps.setup-vars.outputs.should-build-docker }}
      should-deploy-k8s: ${{ steps.setup-vars.outputs.should-deploy-k8s }}
      code-quality: ${{ steps.setup-vars.outputs.code-quality }}
      deploy-environment: ${{ steps.setup-vars.outputs.deploy-environment }}
      notification-provider: ${{ steps.setup-vars.outputs.notification-provider }}
      k8s-config-yaml: ${{ steps.setup-vars.outputs.k8s-config-yaml }}
      k8s-configmap-name: ${{ steps.setup-vars.outputs.k8s-configmap-name }}
      k8s-enable-hpa: ${{ steps.setup-vars.outputs.k8s-enable-hpa }}
    steps:
      - name: ⬇️ Checkout Repository
        uses: actions/checkout@v6

      - name: ⚙️ Setup Variables
        id: setup-vars
        run: |
          SHORT_COMMIT=$(git rev-parse --short HEAD)
          BRANCH="${{ github.ref_name }}"
          TIMESTAMP=$(date -u '+%Y%m%d%H%M%S')

          BINARY_NAME="${{ env.BINARY_NAME }}"
          BINARY_SOURCE_DIR="${{ env.BINARY_SOURCE_DIR }}"
          DEPLOY_ENV="${{ inputs.environment || 'dev' }}"

          # 从 vars 读取 Docker 仓库配置（用于构建 image 名称）。
          DOCKER_REGISTRY="${{ vars.DOCKER_REGISTRY || 'ghcr.io' }}"
          DOCKER_NAMESPACE="${{ vars.DOCKER_NAMESPACE || '<% .OrgName | lower %>' }}"

          # 检查当前环境是否允许 Docker 和 K8s 部署。
          ALLOWED_ENVS=$(echo "${{ env.DOCKER_K8S_ALLOWED_ENVS }}" | tr ',;' ' ')
          IS_DOCKER_K8S_ALLOWED="false"
          for env in ${ALLOWED_ENVS}; do
            env=$(echo "$env" | xargs)
            if [ "$env" = "${DEPLOY_ENV}" ]; then
              IS_DOCKER_K8S_ALLOWED="true"
              break
            fi
          done

          # 配置文件路径（项目特有）
          K8S_CONFIG_YAML="resources/gateway-${DEPLOY_ENV}.yaml"
          K8S_CONFIGMAP_NAME="${BINARY_NAME}-config-${DEPLOY_ENV}"

          # HPA 配置
          if [ "${{ inputs.enable-hpa }}" == "true" ]; then
            ENABLE_HPA="true"
          elif [ "${{ inputs.enable-hpa }}" == "false" ]; then
            ENABLE_HPA="false"
          else
            ENABLE_HPA="${{ vars.K8S_ENABLE_HPA || 'true' }}"
          fi

          # 部署决策。
          SHOULD_BUILD_DOCKER="${{ inputs.build-docker }}"
          SHOULD_DEPLOY_K8S="${{ inputs.deploy-k8s }}"
          # tag 推送进入发布模式：仅构建推送镜像，镜像 tag 即 git tag 名
          IS_TAG_PUSH="false"
          if [[ "${GITHUB_REF}" == refs/tags/* ]]; then
            IS_TAG_PUSH="true"
          fi
          # push 事件无 dispatch 输入，默认构建镜像并部署
          if [ "${{ github.event_name }}" = "push" ]; then
            SHOULD_BUILD_DOCKER="true"
            SHOULD_DEPLOY_K8S="true"
          fi
          if [ "${IS_DOCKER_K8S_ALLOWED}" = "false" ]; then
            SHOULD_BUILD_DOCKER="false"
            SHOULD_DEPLOY_K8S="false"
          elif [ "${SHOULD_DEPLOY_K8S}" = "true" ]; then
            SHOULD_BUILD_DOCKER="true"
          fi
          # 发布模式：仅构建镜像，跳过 K8s 部署
          if [ "${IS_TAG_PUSH}" = "true" ]; then
            SHOULD_BUILD_DOCKER="true"
            SHOULD_DEPLOY_K8S="false"
          fi

          # 输出动态值
          echo "binary-name=${BINARY_NAME}" >> $GITHUB_OUTPUT
          echo "binary-source-dir=${BINARY_SOURCE_DIR}" >> $GITHUB_OUTPUT
          echo "binary-output=${BINARY_SOURCE_DIR}/${BINARY_NAME}" >> $GITHUB_OUTPUT
          echo "build-time=$(date -u '+%Y-%m-%d_%H:%M:%S')" >> $GITHUB_OUTPUT
          echo "git-commit=${SHORT_COMMIT}" >> $GITHUB_OUTPUT
          echo "short-commit=${SHORT_COMMIT}" >> $GITHUB_OUTPUT
          echo "image-base=${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${BINARY_NAME}" >> $GITHUB_OUTPUT
          echo "release-mode=${IS_TAG_PUSH}" >> $GITHUB_OUTPUT
          # 发布模式版本与镜像 tag 即 git tag 名，分支模式保持 分支-短哈希-时间戳 命名
          if [ "${IS_TAG_PUSH}" = "true" ]; then
            echo "version=${BRANCH}" >> $GITHUB_OUTPUT
            echo "image-name=${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${BINARY_NAME}:${BRANCH}" >> $GITHUB_OUTPUT
          else
            echo "version=${BRANCH}-${SHORT_COMMIT}" >> $GITHUB_OUTPUT
            echo "image-name=${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${BINARY_NAME}:${BRANCH}-${SHORT_COMMIT}-${TIMESTAMP}" >> $GITHUB_OUTPUT
          fi
          echo "deploy-environment=${DEPLOY_ENV}" >> $GITHUB_OUTPUT
          echo "should-build-docker=${SHOULD_BUILD_DOCKER}" >> $GITHUB_OUTPUT
          echo "should-deploy-k8s=${SHOULD_DEPLOY_K8S}" >> $GITHUB_OUTPUT
          echo "code-quality=${{ inputs.code-quality }}" >> $GITHUB_OUTPUT
          echo "notification-provider=${{ inputs.notification-provider }}" >> $GITHUB_OUTPUT
          echo "k8s-config-yaml=${K8S_CONFIG_YAML}" >> $GITHUB_OUTPUT
          echo "k8s-configmap-name=${K8S_CONFIGMAP_NAME}" >> $GITHUB_OUTPUT
          echo "k8s-enable-hpa=${ENABLE_HPA}" >> $GITHUB_OUTPUT

      - name: 📋 Print Summary
        run: |
          echo "========================================"
          echo "        Setup Job Outputs Summary       "
          echo "========================================"
          echo ""
          echo "📦 Binary: ${{ steps.setup-vars.outputs.binary-name }}"
          echo "🏷️ Version: ${{ steps.setup-vars.outputs.version }}"
          echo "🖼️ Image: ${{ steps.setup-vars.outputs.image-name }}"
          echo "�️ Release: ${{ steps.setup-vars.outputs.release-mode }}"
          echo "�� Environment: ${{ steps.setup-vars.outputs.deploy-environment }}"
          echo "🐳 Build Docker: ${{ steps.setup-vars.outputs.should-build-docker }}"
          echo "☸️ Deploy K8s: ${{ steps.setup-vars.outputs.should-deploy-k8s }}"
          echo "🔍 Code Quality: ${{ steps.setup-vars.outputs.code-quality }}"
          echo "📊 HPA: ${{ steps.setup-vars.outputs.k8s-enable-hpa }}"
          echo "⚠️ No RPC port (gateway service)"
          echo "⚠️ Build entry: ./bootstrap (not ./main.go)"
          echo "========================================"

  # 第一步：代码质量检查（静态配置由 reusable workflow 自动读取 vars）
  code-quality:
    name: Code Quality Check
    needs: setup
    if: ${{ needs.setup.outputs.code-quality == 'true' }}
    uses: <% .PipelineRepo %>/.github/workflows/code-quality.yml@master
    secrets:
      APP_ID: ${{ secrets.OPS_CLI_APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.OPS_CLI_APP_PRIVATE_KEY }}
      GIT_SSH_PRIVATE_KEY: ${{ secrets.GIT_SSH_PRIVATE_KEY }}

  # 第二步：构建二进制文件（静态配置由 reusable workflow 自动读取 vars）
  # 注意：本项目入口为 ./bootstrap，通过 BINARY_BUILD_DIR vars 指定
  build-binary:
    name: Build Binary
    needs: setup
    uses: <% .PipelineRepo %>/.github/workflows/backend-build-binary.yml@master
    with:
      binary-name: ${{ needs.setup.outputs.binary-name }}
      binary-source-dir: ${{ needs.setup.outputs.binary-source-dir }}
      binary-output: ${{ needs.setup.outputs.binary-output }}
      version: ${{ needs.setup.outputs.version }}
      build-time: ${{ needs.setup.outputs.build-time }}
      git-commit: ${{ needs.setup.outputs.git-commit }}
      binary-build-dir: './bootstrap'
      build-tags: swagger  # 嵌入 swagger 文档（swagger_embed.go 需要 -tags swagger 编译）
    secrets:
      APP_ID: ${{ secrets.OPS_CLI_APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.OPS_CLI_APP_PRIVATE_KEY }}
      GIT_SSH_PRIVATE_KEY: ${{ secrets.GIT_SSH_PRIVATE_KEY }}

  # 第三步：构建并推送 Docker 镜像（静态配置由 reusable workflow 自动读取 vars）
  # 注意：gateway 无 RPC 端口，通过 vars.RPC_PORT=none 告知 workflow 跳过
  build-docker:
    name: Build Docker Image
    needs: [setup, build-binary]
    if: ${{ needs.setup.outputs.should-build-docker == 'true' }}
    uses: <% .PipelineRepo %>/.github/workflows/backend-build-docker.yml@master
    with:
      binary-name: ${{ needs.setup.outputs.binary-name }}
      binary-source-dir: ${{ needs.setup.outputs.binary-source-dir }}
      version: ${{ needs.setup.outputs.version }}
      image-base: ${{ needs.setup.outputs.image-base }}
      image-name: ${{ needs.setup.outputs.image-name }}
      environment: ${{ needs.setup.outputs.deploy-environment }}
      rpc-port: 'none'
      extra-copy-dirs: 'proto'
    secrets: inherit

  # 第四步：部署到 Kubernetes（静态配置由 reusable workflow 自动读取 vars）
  # 注意：gateway 无 RPC 端口，通过 vars.RPC_PORT=none 告知 workflow 跳过
  deploy-k8s:
    name: Deploy to ${{ needs.setup.outputs.deploy-environment }}
    needs: [setup, build-docker]
    if: ${{ needs.setup.outputs.should-deploy-k8s == 'true' }}
    uses: <% .PipelineRepo %>/.github/workflows/backend-deploy-k8s.yml@master
    with:
      environment: ${{ needs.setup.outputs.deploy-environment }}
      image-name: ${{ needs.setup.outputs.image-name }}
      binary-name: ${{ needs.setup.outputs.binary-name }}
      binary-source-dir: ${{ needs.setup.outputs.binary-source-dir }}
      config-yaml: ${{ needs.setup.outputs.k8s-config-yaml }}
      configmap-name: ${{ needs.setup.outputs.k8s-configmap-name }}
      enable-hpa: ${{ needs.setup.outputs.k8s-enable-hpa }}
      rpc-port: 'none'
      notification-provider: ${{ needs.setup.outputs.notification-provider }}
    secrets:
      KUBECONFIG: ${{ secrets.KUBECONFIG }}
      FEISHU_WEBHOOK_URL: ${{ secrets.FEISHU_WEBHOOK_URL }}
      TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN }}
      TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID }}
