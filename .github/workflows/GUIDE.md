# GitHub Actions Workflows 说明文档

## 📋 工作流概览

### 主流程编排

- **[pipeline.yml](pipeline.yml)** - 主 CI/CD 流程编排器，协调所有子工作流

### 子工作流（单一职责）

- **[code-quality.yml](code-quality.yml)** - 代码质量检查（格式化、静态分析、单元测试）
- **[build-binary.yml](build-binary.yml)** - 构建 Go 二进制文件（支持 UPX 压缩）
- **[test-connect-ssh.yml](test-connect-ssh.yml)** - SSH 连接测试（服务器诊断、权限检查）
- **[build-docker.yml](build-docker.yml)** - 构建并推送 Docker 镜像
- **[deploy-scp.yml](deploy-scp.yml)** - SCP 部署到远程 Linux 服务器（多环境支持）
- **[deploy-k8s.yml](deploy-k8s.yml)** - 部署到 Kubernetes 集群
- **[rollback.yml](rollback.yml)** - 版本回滚（从归档中恢复指定版本）

### 定时任务

- **[cleanup-images.yml](cleanup-images.yml)** - 清理旧版本镜像（每周日凌晨 2 点执行）

---

## 🚀 主流程说明

### Pipeline 执行流程

```mermaid
graph LR
    A[Setup<br/>环境准备] --> B[Code Quality<br/>代码检查]
    B --> C[Build Binary<br/>编译二进制]
    C --> D[Build Docker<br/>构建镜像]
    C --> E[Test SSH<br/>连接测试]
    E --> F[Deploy SCP<br/>远程部署]
    D --> G{Deploy K8s?<br/>部署}
    G -->|develop| H[Deploy Dev<br/>开发环境]
    G -->|<% .BaseBranch %>| I[Deploy Prod<br/>生产环境]
    
    style A fill:#fff3e0
    style B fill:#e3f2fd
    style C fill:#e3f2fd
    style D fill:#e1f5fe
    style E fill:#fff59d
    style F fill:#fff9c4
    style H fill:#c8e6c9
    style I fill:#ffcdd2
```

### 各阶段职责

#### 1️⃣ Setup（环境准备）

- ✅ Checkout 代码仓库
- ✅ 配置 Go 环境（1.25.1）
- ✅ 配置私有模块访问权限
- ✅ 缓存 Go 依赖
- ✅ 下载项目依赖
- ✅ **输出所有环境变量**（binary-name, version, ports, image-name 等）

#### 2️⃣ Code Quality（代码质量检查）

- ✅ 代码格式检查（`gofmt`）
- ✅ 静态分析（`go vet`）
- ✅ 单元测试（race detection）
- ✅ 生成测试覆盖率报告

#### 3️⃣ Build Binary（构建二进制）

- ✅ 编译 Go 二进制文件
- ✅ 嵌入版本信息（version, buildTime, gitCommit）
- ✅ 可选 UPX 压缩（通过 `UPX_COMPRESS` 变量控制）
- ✅ 上传 artifact 供后续步骤使用

#### 4️⃣ Test SSH（SSH 连接测试）

- ✅ 测试 SSH 连接可用性
- ✅ 获取服务器信息（系统、资源使用）
- ✅ 检查 sudo 权限和部署目录
- ✅ 在 SCP 部署前验证环境

#### 5️⃣ Build Docker（构建镜像）

- ✅ 下载编译好的二进制文件
- ✅ 生成多端口 Dockerfile（HTTP:8091, RPC:9091, WS:9092）
- ✅ 构建并推送镜像到镜像仓库（标签格式：`分支名-短commit`）

#### 6️⃣ Deploy SCP（SCP 远程部署）

- ✅ 下载编译好的二进制文件
- ✅ 创建部署包（包含二进制、配置、脚本）
- ✅ 通过 SCP 上传到远程服务器
- ✅ 支持多环境配置（dev/test/uat/prod）
- ✅ 自动归档部署包（用于回滚）
- ✅ 支持 systemd/supervisor 进程管理
- ✅ 部署完成后发送通知（飞书/Telegram）

#### 7️⃣ Deploy K8s（部署到 Kubernetes）

- ✅ 生成 K8s 资源清单（Deployment, Service, HPA, Ingress）
- ✅ 应用到指定环境的命名空间（im-dev / im-prod）
- ✅ 验证清单文件生成（`ls -lh ../deployments/*.yaml`）
- ✅ 等待部署完成并验证 Pod 状态

---

## 🔐 所需 Secrets 配置

在 **仓库 Settings → Secrets and variables → Actions** 中配置：

### 必需配置

| Secret 名称 | 用途 | 获取方式 | 使用位置 |
|------------|------|---------|---------|
| `GIT_SSH_PRIVATE_KEY` | 访问私有 Go 模块（SSH 方式） | 见下方 SSH 密钥生成步骤 | [pipeline.yml#L137](pipeline.yml#L137) |
| `KUBECONFIG` | Kubernetes 集群访问凭证 | `cat ~/.kube/config \| base64` | [deploy-k8s.yml#L47](deploy-k8s.yml#L47) |

### 多环境 SCP 部署配置（使用 GitHub Environments）

项目支持多环境部署（dev/test/uat/prod），使用 **GitHub Environments** 功能管理环境特定配置。

#### 配置方式

在 **仓库 Settings → Environments** 中为每个环境（dev/test/uat/prod）创建独立配置：

**Secrets（每个环境独立配置）：**

| Secret 名称 | 用途 | 默认值 | 说明 |
|------------|------|--------|------|
| `REMOTE_DEPLOY_HOST` | 服务器地址 | _(必需)_ | 各环境独立配置不同服务器 |
| `REMOTE_DEPLOY_USER` | SSH 用户名 | `deploy` | 各环境可使用不同用户 |
| `REMOTE_DEPLOY_SSH_PRIVATE_KEY` | SSH 私钥 | _(必需)_ | 各环境可使用不同密钥 |
| `FEISHU_WEBHOOK_URL` | 飞书机器人 Webhook | _(可选)_ | 部署通知 |
| `TELEGRAM_BOT_TOKEN` | Telegram Bot Token | _(可选)_ | 部署通知 |
| `TELEGRAM_CHAT_ID` | Telegram Chat ID | _(可选)_ | 部署通知 |

**Variables（每个环境独立配置）：**

| 变量名称 | 用途 | 默认值 | 说明 |
|----------|------|--------|------|
| `REMOTE_DEPLOY_PATH` | 部署路径 | `/opt/{binary-name}` | 各环境可配置不同路径 |
| `REMOTE_ARCHIVES_DIR` | 归档目录 | `/opt/{binary-name}/archives` | 存储历史版本用于回滚 |
| `PROCESS_MANAGER` | 进程管理器 | `systemd` | 可选：`systemd` 或 `supervisor` |
| `UPX_COMPRESS` | 是否启用 UPX 压缩 | `false` | 设置为 `true` 可将二进制文件压缩 60-70% |

### 可选配置（Docker Registry）

默认使用 GitHub Container Registry (GHCR)，无需额外配置如需使用其他镜像仓库（如 Docker Hub），需配置：

**Variables（非敏感配置，在 Settings → Secrets and variables → Actions → Variables 配置）：**

| 变量名称 | 用途 | 默认值 | 说明 |
|----------|------|--------|------|
| `DOCKER_REGISTRY` | 镜像仓库地址 | `ghcr.io` | 例如：`docker.io`（Docker Hub）、`registry.cn-hangzhou.aliyuncs.com`（阿里云） |
| `DOCKER_NAMESPACE` | 镜像命名空间 | `larkgame` | 镜像组织/用户名 |
| `BINARY_SOURCE_DIR` | 二进制文件存放目录 | `deployments` | 构建产物存放路径，通常不需要修改 |

**Secrets（敏感信息，在 Settings → Secrets and variables → Actions → Secrets 配置）：**

| Secret 名称 | 用途 | 默认值 | 使用位置 |
|------------|------|--------|----------|
| `DOCKER_USERNAME` | 镜像仓库用户名 | `github.actor` | [build-docker.yml#L56](build-docker.yml#L56) |
| `DOCKER_PASSWORD` | 镜像仓库密码/令牌 | `GITHUB_TOKEN` | [build-docker.yml#L57](build-docker.yml#L57) |

> **说明**：GHCR 自动使用 `github.actor` 作为用户名和 `GITHUB_TOKEN` 作为密码，无需额外配置。Docker Hub 需配置 Access Token

**使用 Docker Hub 示例：**

```yaml
DOCKER_REGISTRY: docker.io
DOCKER_NAMESPACE: namespace
DOCKER_USERNAME: username
DOCKER_PASSWORD: dckr_pat_xxxxxxxxxxxx  # Docker Hub Access Token
```

> **获取 Docker Hub Access Token**：访问 <https://hub.docker.com/settings/security> → **New Access Token**

**配置步骤：**

1. 进入 **仓库 Settings → Environments**
2. 创建环境：`dev`、`test`、`uat`、`prod`
3. 为每个环境配置相同名称的变量，但值不同：

```yaml
# Environment: dev
Secrets:
  REMOTE_DEPLOY_HOST: 192.168.1.100
  REMOTE_DEPLOY_USER: deployer
  REMOTE_DEPLOY_SSH_PRIVATE_KEY: -----BEGIN OPENSSH PRIVATE KEY-----...
  FEISHU_WEBHOOK_URL: https://open.feishu.cn/open-apis/bot/v2/hook/xxx

Variables:
  REMOTE_DEPLOY_PATH: /opt/services/dev/im-service
  REMOTE_ARCHIVES_DIR: /opt/services/dev/im-service/archives
  PROCESS_MANAGER: systemd

# Environment: prod
Secrets:
  REMOTE_DEPLOY_HOST: 10.0.1.100
  REMOTE_DEPLOY_USER: deployer
  REMOTE_DEPLOY_SSH_PRIVATE_KEY: -----BEGIN OPENSSH PRIVATE KEY-----...
  FEISHU_WEBHOOK_URL: https://open.feishu.cn/open-apis/bot/v2/hook/yyy

Variables:
  REMOTE_DEPLOY_PATH: /opt/services/prod/im-service
  REMOTE_ARCHIVES_DIR: /opt/services/prod/im-service/archives
  PROCESS_MANAGER: systemd
  UPX_COMPRESS: true
```

> **优势**：通过 GitHub Environments 可以为不同环境设置不同的审批流程和访问权限。

#### SSH 密钥生成与配置步骤

##### 1. 生成 SSH 密钥对

```bash
# 生成 ED25519 密钥（推荐，更安全且体积小）
ssh-keygen -t ed25519 -C "github-actions@your-company.com" -f ~/.ssh/github_actions_key -N ""

# 或使用 RSA 密钥（兼容性更好）
ssh-keygen -t rsa -b 4096 -C "github-actions@your-company.com" -f ~/.ssh/github_actions_key -N ""
```

这将生成两个文件：

- `~/.ssh/github_actions_key` - **私钥**（配置到 GitHub Secrets）
- `~/.ssh/github_actions_key.pub` - **公钥**（添加到 GitHub SSH Keys）

##### 2. 添加公钥到 GitHub

```bash
# 查看并复制公钥内容
cat ~/.ssh/github_actions_key.pub
```

登录 GitHub 账号，进入以下页面之一：

**方式 A：个人账号访问权限（推荐）**

- 访问 <https://github.com/settings/keys>
- 点击 **"New SSH key"**
- Title: `GitHub Actions - Engine IM Service`
- Key type: `Authentication Key`
- Key: 粘贴公钥内容（ssh-ed25519 AAAA...）
- 点击 **"Add SSH key"**

**方式 B：特定仓库部署密钥**

- 访问私有仓库（如 `https://github.com/<% .OrgName %>/your-private-module`）
- 进入 **Settings → Deploy keys**
- 点击 **"Add deploy key"**
- Title: `GitHub Actions Read Access`
- Key: 粘贴公钥内容
- ✅ 勾选 **"Allow read access"**（如需写权限则勾选 write access）
- 点击 **"Add key"**

> **注意**：如果有多个私有仓库，建议使用方式 A（个人 SSH Keys），这样一个密钥对即可访问所有仓库。

##### 3. 配置私钥到 GitHub Secrets

```bash
# 查看并复制私钥内容
cat ~/.ssh/github_actions_key
```

进入项目仓库的 Secrets 配置页面：

- 访问 `https://github.com/<% .OrgName | lower %>/<% .ProjectName %>/settings/secrets/actions`
- 点击 **"New repository secret"**
- Name: `GIT_SSH_PRIVATE_KEY`
- Secret: 粘贴**完整私钥内容**（包括 `-----BEGIN ... PRIVATE KEY-----` 和 `-----END ... PRIVATE KEY-----`）
- 点击 **"Add secret"**

##### 4. 验证配置

手动触发 Pipeline workflow 或推送代码，查看 Setup 步骤的日志：

```log
✅ Setup SSH Key for Private Modules
   Adding SSH key to agent...
   Identity added: (stdin) (github-actions@your-company.com)

✅ Configure Git to use SSH for Private Repos
   url.git@github.com:.insteadof=https://github.com/

✅ Download Dependencies
   go: downloading <% .ModuleName %> v0.0.0-20251216022211-90211dfc0b26
```

如果看到 `ssh: connect to host github.com port 22: Connection refused` 或 `Permission denied`，请检查：

- 私钥是否完整复制（包括首尾标记行）
- 公钥是否已添加到 GitHub SSH Keys
- GitHub SSH 服务是否可访问（测试：`ssh -T git@github.com`）

### 自动提供（无需配置）

| Secret 名称 | 用途 | 说明 |
|------------|------|------|
| `GITHUB_TOKEN` | GHCR 镜像推送 & 清理 | GitHub Actions 自动注入，权限：packages:write |

---

## 🎯 触发条件

### 自动触发

| 工作流 | 触发事件 | 分支 | 说明 |
|--------|---------|------|------|
| **pipeline.yml** | `push` | develop, <% .BaseBranch %> | 推送代码自动执行完整流程 |
| **pipeline.yml** | `pull_request` | develop, <% .BaseBranch %> | PR 仅执行代码检查和构建 |
| **cleanup-images.yml** | `schedule` | - | 每周日凌晨 2 点清理旧镜像 |

### 手动触发

可以在 GitHub Actions 页面手动触发：

#### Pipeline（主流程）

- **environment**: 部署环境选择（dev/test/uat/prod，默认 `dev`）
- **code-quality**: 是否进行代码质量检查（默认 `true`）
- **test-ssh-connect**: 是否测试 SSH 连接（默认 `true`）
- **deploy-scp**: 是否 SCP 部署（默认 `true`）
- **notification-provider**: 通知提供商（none/feishu/telegram/all，默认 `feishu`）
- **build-docker**: 是否构建 Docker 镜像（默认 `false`）
- **deploy-k8s**: 是否部署到 K8s（默认 `false`）

#### Rollback（版本回滚）

- **git-commit**: 要回滚到的 Git commit hash（短 hash）
- **environment**: 回滚环境（dev/test/uat/prod）
- **binary-name**: 二进制文件名（默认 `<% .ProjectName %>`）
- **process-manager**: 进程管理器（systemd/supervisor，默认 `systemd`）
- **notification-provider**: 通知提供商（none/feishu/telegram/all，默认 `feishu`）

#### Cleanup（镜像清理）

- **keep_count**: 保留的镜像版本数量（默认 `5`）

---

## ⚙️ 环境配置

### 配置架构说明

项目采用**分层配置架构**，区分敏感信息和非敏感配置：

- **Variables（vars）** - 非敏感配置，在 [pipeline.yml](pipeline.yml) 的 `env` 中集中管理，可通过 outputs 传递给子 workflow
- **Secrets** - 敏感信息（密码、密钥），在各子 workflow 的 `env` 中直接从 `secrets` 读取，**不通过 outputs 传递**（避免 GitHub Actions 自动掩码导致值被清空）

### Variables 配置（pipeline.yml）

所有非敏感配置集中在 [pipeline.yml](pipeline.yml) 的全局 `env` 中：

```yaml
env:
  # 基础构建配置
  BINARY_NAME: ${{ vars.BINARY_NAME || github.event.repository.name }}
  BINARY_SOURCE_DIR: ${{ vars.BINARY_SOURCE_DIR || 'deployments' }}
  
  # Go 语言环境配置
  GO_VERSION: ${{ vars.GO_VERSION || '1.25.1' }}
  GOTESTSUM_VERSION: ${{ vars.GOTESTSUM_VERSION || 'v1.13.0' }}
  GOPROXY: ${{ vars.GOPROXY || 'https://goproxy.cn,direct' }}
  GOPRIVATE: ${{ vars.GOPRIVATE || 'github.com/<% .OrgName %>' }}
  
  # 服务端口（三端口架构）
  HTTP_PORT: ${{ vars.HTTP_PORT || '8091' }}   # REST API + Health Check
  RPC_PORT: ${{ vars.RPC_PORT || '9091' }}     # gRPC 内部调用
  WS_PORT: ${{ vars.WS_PORT || '9092' }}       # WebSocket 实时推送
  
  # Docker 配置
  DOCKER_REGISTRY: ${{ vars.DOCKER_REGISTRY || 'ghcr.io' }}
  DOCKER_NAMESPACE: ${{ vars.DOCKER_NAMESPACE || 'larkgame' }}
  
  # SCP 部署配置
  REMOTE_DEPLOY_PATH: ${{ vars.REMOTE_DEPLOY_PATH || format('/opt/{0}', github.event.repository.name) }}
  REMOTE_AUTO_RESTART: ${{ vars.REMOTE_AUTO_RESTART || 'false' }}
  REMOTE_ARCHIVES_DIR: ${{ vars.REMOTE_ARCHIVES_DIR || format('/opt/{0}/archives', github.event.repository.name) }}
  
  # 构建优化配置
  UPX_COMPRESS: ${{ vars.UPX_COMPRESS || 'false' }}
  
  # 进程管理器
  PROCESS_MANAGER: ${{ vars.PROCESS_MANAGER || 'systemd' }}
```

### Secrets 配置（各子 workflow）

敏感信息在各子 workflow 的 `env` 中独立配置：

**build-docker.yml：**

```yaml
env:
  DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME || github.actor }}
  DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD || secrets.GITHUB_TOKEN }}
```

**deploy-scp.yml：**

```yaml
env:
  REMOTE_DEPLOY_HOST: ${{ secrets.REMOTE_DEPLOY_HOST }}
  REMOTE_DEPLOY_USER: ${{ secrets.REMOTE_DEPLOY_USER || 'deploy' }}
  REMOTE_DEPLOY_SSH_PRIVATE_KEY: ${{ secrets.REMOTE_DEPLOY_SSH_PRIVATE_KEY }}
```

> **为什么这样设计？**  
> GitHub Actions 会自动掩码 secrets，当 secrets 通过 job outputs 传递时会被清空为空字符串因此 secrets 必须在各自 workflow 中直接读取，不能跨 workflow 传递。

---

## 🐳 Docker 镜像标签策略

项目使用 **分支名-短commit** 格式的镜像标签：

```bash
# 镜像标签格式
{registry}/{namespace}/{binary}:{branch}-{short-commit}

# 示例
ghcr.io/<% .OrgName | lower %>/<% .ProjectName %>:<% .BaseBranch %>-2932c78
ghcr.io/<% .OrgName | lower %>/<% .ProjectName %>:develop-abc1234
registry.example.com/<% .OrgName | lower %>/<% .ProjectName %>:<% .BaseBranch %>-2932c78
```

**生成逻辑（pipeline.yml Setup 步骤）：**

```bash
# 获取短 commit hash（前 7 位）
SHORT_COMMIT=$(git rev-parse --short HEAD)

# 拼接完整镜像名称
image-name=${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${BINARY_NAME}:${BRANCH}-${SHORT_COMMIT}

# 传递给子 workflows
echo "image-name=${image-name}" >> $GITHUB_OUTPUT
```

**优势：**

- ✅ 唯一性：每个 commit 对应唯一镜像
- ✅ 可追溯：通过短 hash 快速定位代码版本
- ✅ 简洁性：7 位短 hash 足够区分，避免冗长
- ✅ 一致性：version、git-commit、image-name 复用同一变量

---

## 🚀 部署流程

### 开发环境部署（develop 分支）

```bash
# Push 到 develop 分支自动触发
git push origin develop

# 自动执行流程：
# 1. 代码质量检查 + 单元测试
# 2. 编译 Linux amd64 二进制文件
# 3. 构建 Docker 镜像并推送到镜像仓库
# 4. SCP 部署到开发服务器（如果配置了 REMOTE_DEPLOY_HOST）
# 5. 部署到 Dev Kubernetes 集群（如果配置了 KUBECONFIG_DEV）
```

### 生产环境部署（<% .BaseBranch %> 分支）

```bash
# Push 到 <% .BaseBranch %> 分支自动触发
git push origin <% .BaseBranch %>

# 自动执行流程：
# 1. 代码质量检查 + 单元测试
# 2. 编译 Linux amd64 二进制文件
# 3. 构建 Docker 镜像并推送到镜像仓库
# 4. 等待手动触发部署到 Prod Kubernetes 集群
```

### 手动触发部署

在 GitHub Actions 页面点击 **Actions → Pipeline → Run workflow**：

**可配置参数：**

- `environment`: 部署环境（dev/test/uat/prod）
- `code-quality`: 是否进行代码质量检查
- `deploy-scp`: 是否 SCP 部署
- `build-docker`: 是否构建 Docker 镜像
- `deploy-k8s`: 是否部署到 Kubernetes
- `notification-provider`: 通知提供商（none/feishu/telegram/all）

### 版本回滚

当需要回滚到历史版本时，在 GitHub Actions 页面点击 **Actions → Rollback Deployment → Run workflow**：

```bash
# 回滚步骤：
# 1. 选择环境（dev/test/uat/prod）
# 2. 输入要回滚到的 Git commit hash（短 hash，如：2932c78）
# 3. 选择进程管理器（systemd/supervisor）
# 4. 选择通知方式
# 5. 点击 Run workflow

# 回滚流程：
# 1. 从归档目录中查找对应版本的部署包
# 2. 停止当前服务
# 3. 解压并恢复历史版本
# 4. 重启服务
# 5. 发送回滚通知
```

**注意事项：**

- 只能回滚到已归档的版本（deploy-scp 步骤会自动归档每次部署）
- 回滚前会先列出可用的归档版本
- 回滚不会影响数据库，需要单独处理数据兼容性

---

## 🔧 代码质量检查

### golangci-lint 配置

项目使用 **golangci-lint v1.60+** 进行代码质量检查：

```bash
# 本地运行（makefile.sh 会自动安装 golangci-lint）
bash scripts/makefile.sh lint

# CI/CD 自动运行
# 每次 push 或 PR 都会触发代码质量检查
```

**配置文件**: `.golangci.yml`

- ✅ 统一换行符: LF（通过 `.gitattributes` 强制）
- ✅ 放宽部分检查: `errcheck`（Unlock/Delete 等）、`unused`
- ✅ 自动格式化: `gofmt -s -w .`

---

## 📦 Kubernetes 部署

### 生成部署清单

使用 `scripts/generate_deployment.sh` 脚本自动生成 K8s 部署配置：

```bash
bash scripts/generate_deployment.sh \
  --namespace="im-service" \
  --app_name="<% .ProjectName %>" \
  --binary_name="<% .ProjectName %>" \
  --image="registry.example.com/<% .OrgName | lower %>/<% .ProjectName %>:<% .BaseBranch %>-2932c78" \
  --http_port="8091" \
  --rpc_port="9091" \
  --ws_port="9092" \
  --replicas="3" \
  --env="dev"

# 输出文件: deployments/k8s-deployment-dev.yaml
# 包含资源: Deployment + Service(三端口) + HPA + Ingress(Traefik)
```

### 部署清单内容

生成的 K8s 清单包含以下资源：

1. **Deployment**:
   - 容器端口: HTTP(8091), RPC(9091), WebSocket(9092)
   - 探针: Liveness & Readiness（HTTP 8091/health）
   - 资源限制: CPU/Memory requests & limits

2. **Service**:
   - 三端口配置: http, rpc, websocket
   - ClusterIP 类型

3. **HorizontalPodAutoscaler**:
   - CPU 使用率触发（80%）
   - 副本数: 3-10

4. **Ingress (Traefik)**:
   - HTTP 路由配置
   - Middleware 支持

---

## 📊 构建产物管理

### 产物存储

| 产物类型 | 存储位置 | 保留策略 | 访问方式 |
|---------|---------|---------|---------|
| **Linux 二进制** | GitHub Actions Artifacts | 30 天自动删除 | Actions 页面下载 |
| **Docker 镜像** | Docker Registry | 永久（手动清理） | `docker pull` |
| **K8s 部署清单** | 代码仓库 `deployments/` | 永久（版本控制） | Git 访问 |

### 镜像清理策略

定时任务 `cleanup-images.yml` 每周日凌晨 2 点自动清理旧镜像：

- **默认保留**: 最新 5 个版本
- **清理目标**: untagged 镜像和旧版本镜像
- **手动触发**: 可在 Actions 页面手动执行，自定义保留数量

---

## 🔍 故障排查指南

### 1. GitHub Actions 构建失败

```bash
# 查看构建日志
# GitHub → Actions → 选择失败的 workflow run → 查看具体步骤日志

# 常见问题：
# - Go 依赖下载失败: 检查 GIT_SSH_PRIVATE_KEY 配置
# - 代码质量检查失败: 运行 bash scripts/makefile.sh lint 本地检查
# - 测试失败: 运行 go test -v ./... 本地调试
```

### 2. Docker 镜像推送失败

```bash
# 检查镜像仓库认证
# 1. 验证 DOCKER_USERNAME 和 DOCKER_PASSWORD 是否正确
# 2. 测试本地登录
docker login ${DOCKER_REGISTRY} -u ${DOCKER_USERNAME} -p ${DOCKER_PASSWORD}

# 3. 手动推送测试
docker tag local-image ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/<% .ProjectName %>:test
docker push ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/<% .ProjectName %>:test
```

### 3. Kubernetes 部署失败

```bash
# 检查部署状态
kubectl get pods -n im-service
kubectl describe pod <pod-name> -n im-service
kubectl logs <pod-name> -n im-service

# 检查镜像拉取
kubectl get events -n im-service --sort-by='.lastTimestamp'

# 验证 KUBECONFIG
kubectl config view
kubectl cluster-info
```

### 4. SCP 部署失败

```bash
# 测试 SSH 连接
ssh ${REMOTE_DEPLOY_USER}@${REMOTE_DEPLOY_HOST}

# 检查私钥权限
# 确保 DEPLOY_SSH_PRIVATE_KEY 包含完整私钥（包括首尾标记行）

# 检查远程路径权限
ssh ${REMOTE_DEPLOY_USER}@${REMOTE_DEPLOY_HOST} "ls -la ${REMOTE_DEPLOY_PATH}"
```

### 5. 常见错误码

| 错误 | 原因 | 解决方案 |
|------|------|---------|
| `Permission denied (publickey)` | SSH 密钥配置错误 | 检查私钥完整性和公钥是否添加 |
| `go: module not found` | 私有模块访问失败 | 配置 GIT_SSH_PRIVATE_KEY |
| `unauthorized: authentication required` | Docker 认证失败 | 检查 DOCKER_USERNAME/PASSWORD |
| `ImagePullBackOff` | K8s 拉取镜像失败 | 检查镜像是否存在，KUBECONFIG 是否正确 |

---

## 📁 文件结构

```
.github/
├── workflows/
│   ├── README.md                 # 本文档
│   ├── pipeline.yml              # 主流程编排
│   ├── code-quality.yml          # 代码质量检查
│   ├── build-binary.yml          # 二进制构建（UPX 压缩）
│   ├── test-connect-ssh.yml      # SSH 连接测试
│   ├── build-docker.yml          # Docker 镜像构建
│   ├── deploy-scp.yml            # SCP 远程部署（多环境）
│   ├── deploy-k8s.yml            # Kubernetes 部署
│   ├── rollback.yml              # 版本回滚
│   └── cleanup-images.yml        # 镜像清理
```

---

## 🔧 本地测试

### 使用 makefile.sh 快速构建

项目提供了 `scripts/makefile.sh` 脚本，简化本地开发流程：

```bash
# 进入 scripts 目录
cd scripts

# 1. 构建应用（调用 build-linux.sh）
bash makefile.sh build

# 2. 清理构建产物
bash makefile.sh clean

# 3. 格式化代码
bash makefile.sh fmt

# 4. 运行代码检查（会自动安装 golangci-lint）
bash makefile.sh lint
```

**各命令说明：**

| 命令 | 功能 | 说明 |
|------|------|------|
| `build` | 构建二进制 | 调用 `build-linux.sh`，输出到 `deployments/<% .ProjectName %>` |
| `clean` | 清理构建产物 | 删除 `deployments` 目录 |
| `fmt` | 代码格式化 | 使用 `gofmt -s -w .` 格式化代码 |
| `lint` | 代码检查 | 使用 `golangci-lint run` 检查代码质量 |

### 测试代码质量检查

```bash
# 格式检查
gofmt -l .

# 静态分析
go vet ./...

# 运行测试
go test -v -race -cover ./...
```

### 测试二进制构建

```bash
# 编译二进制
go build -o <% .ProjectName %> \
  -ldflags "-X main.version=test -X main.buildTime=$(date -u '+%Y-%m-%d_%H:%M:%S')" \
  main.go
```

### 测试 Docker 构建

```bash
# 生成 Dockerfile
cd scripts
export BUILD_APP_NAME="<% .ProjectName %>"
export BINARY_SOURCE_DIR="deployments"
export ADDITIONAL_PORTS="9091, 9092"  # RPC 和 WebSocket 端口
bash generate_dockerfile.sh

# 注：HTTP 端口 8091 作为默认端口自动暴露

# 构建镜像
cd ..
docker build -t <% .ProjectName %>:local -f deployments/Dockerfile .
```

### 测试 K8s 部署清单生成

```bash
cd scripts
bash generate_deployment.sh \
  --namespace="im-dev" \
  --app_name="<% .ProjectName %>" \
  --binary_name="<% .ProjectName %>" \
  --image="ghcr.io/<% .OrgName | lower %>/<% .ProjectName %>:<% .BaseBranch %>-2932c78" \
  --http_port="8091" \
  --rpc_port="9091" \
  --ws_port="9092" \
  --replicas="3" \
  --env="dev"

# 输出文件: deployments/k8s-deployment-dev.yaml
# 包含: Deployment + Service(三端口) + HPA + Ingress(Traefik)
```

---
