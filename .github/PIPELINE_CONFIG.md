# CI/CD Pipeline 配置说明

## 配置优先级

所有配置采用三级优先级：**`input`（手动触发） > `vars`（仓库变量） > 硬编码默认值**

> 不配置 vars 时使用默认值，pipeline 可正常运行仅在需要覆盖默认值时才需配置。

---

## 本项目需配置的 Variables

在 GitHub 仓库 **Settings > Secrets and variables > Actions > Variables** 中配置。

### 必须配置

| 变量名 | 值 | 说明 |
|--------|-----|------|
| `GOPRIVATE` | `github.com/<% .OrgName %>/*` | Go 私有模块路径 |
| `GO_AUTH_METHOD` | `app-token` | 私有模块认证方式 |
| `RPC_PORT` | `none` | **Gateway 无 gRPC 端口，必须设为 none** |

### Go 构建（build-binary）

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `GO_VERSION` | `1.25.1` | Go 版本 |
| `GOPROXY` | `https://goproxy.cn,direct` | Go 模块代理 |
| `UPX_COMPRESS` | `false` | 启用 UPX 压缩 |

### Docker 构建（build-docker）

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `DOCKER_REGISTRY` | `ghcr.io` | Docker 仓库地址 |
| `DOCKER_NAMESPACE` | `<% .OrgName | lower %>` | Docker 仓库命名空间 |
| `DOCKER_RUN_WORKDIR` | `/usr/local/services/<% .ProjectName %>` | 容器工作目录 |

### 端口配置（build-docker + deploy-k8s）

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `HTTP_PORT` | `18080` | HTTP 端口 |
| `RPC_PORT` | `none` | **无 gRPC 端口** |

### Kubernetes 部署（deploy-k8s）

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `K8S_NAMESPACE` | `default` | K8s 命名空间 |
| `K8S_IMAGE_PULL_SECRETS` | `ghcr.io` | 镜像拉取密钥 |
| `K8S_READINESS_DELAY_SECONDS` | `5` | 就绪探针初始延迟(秒) |
| `K8S_READINESS_PERIOD_SECONDS` | `10` | 就绪探针检测周期(秒) |
| `K8S_LIVENESS_DELAY_SECONDS` | `15` | 存活探针初始延迟(秒) |
| `K8S_LIVENESS_PERIOD_SECONDS` | `20` | 存活探针检测周期(秒) |
| `K8S_CPU_REQUEST` | `100m` | CPU 请求 |
| `K8S_MEMORY_REQUEST` | `128Mi` | 内存请求 |
| `K8S_CPU_LIMIT` | `300m` | CPU 限制 |
| `K8S_MEMORY_LIMIT` | `256Mi` | 内存限制 |
| `K8S_MIN_REPLICAS` | `2` | HPA 最小副本数 |
| `K8S_MAX_REPLICAS` | `10` | HPA 最大副本数 |
| `K8S_DEPLOYMENT_REPLICAS` | `2` | 部署副本数 |
| `K8S_TARGET_CPU_UTILIZATION` | `80` | CPU 目标利用率(%) |
| `K8S_TARGET_MEMORY_UTILIZATION` | `80` | 内存目标利用率(%) |
| `K8S_SCALE_UP_PERCENT` | `100` | 扩容最大百分比(%) |
| `K8S_SCALE_DOWN_PERCENT` | `50` | 缩容最大百分比(%) |
| `K8S_SCALE_DOWN_STABILIZATION_SECONDS` | `300` | 缩容稳定窗口(秒) |
| `K8S_ENABLE_HPA` | `true` | 启用 HPA |

---

## 本项目需配置的 Secrets

| Secret 名 | 说明 | 必填 |
|-----------|------|------|
| `KUBECONFIG` | Kubernetes 配置文件内容 | 是 |
| `OPS_CLI_APP_ID` | GitHub App ID（app-token 认证） | 是 |
| `OPS_CLI_APP_PRIVATE_KEY` | GitHub App 私钥 | 是 |
| `GIT_SSH_PRIVATE_KEY` | Git SSH 私钥（私有模块） | 是 |
| `FEISHU_WEBHOOK_URL` | 飞书通知 Webhook | 否 |
| `TELEGRAM_BOT_TOKEN` | Telegram Bot Token | 否 |
| `TELEGRAM_CHAT_ID` | Telegram Chat ID | 否 |

---

## 项目特有配置

- **配置文件路径**: `resources/gateway-${env}.yaml`
- **ConfigMap 名称**: `<% .ProjectName %>-config-${env}`
- **无 gRPC 端口**: pipeline.yml 中已通过 `rpc-port: 'none'` 跳过 RPC 端口配置
- **构建入口**: `./bootstrap`（非 `./main.go`），pipeline.yml 中已通过 `binary-build-dir: './bootstrap'` 指定
