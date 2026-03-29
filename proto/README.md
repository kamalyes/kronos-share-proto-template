# Proto 目录

> 本目录包含 [[ .OrgPrefix ]] 微服务生态系统的所有 Protobuf 定义文件
> 所有服务共享的接口定义、消息类型和枚举都集中管理在此

## 📂 目录结构

```bash
proto/
├── common/               # 公共消息定义
│   └── common.proto          # 通用消息（StatusCode、Error、Paging 等）
├── enums/                # 枚举类型定义
│   └── enums.proto           # 全局枚举（CommonStatus、UserStatus 等）
└── [[ .ExampleServiceName | snake ]]/  # 示例服务定义
    └── [[ .ExampleServiceName | snake ]]_service.proto  # 示例 gRPC 服务
```

## 📋 模块说明

### `common/` - 公共消息定义

包含所有服务共用的基础消息类型，例如：

| 消息类型 | 说明 | Description |
|---------|------|-------------|
| `StatusCode` | 状态码枚举 | Status code enum |
| `Result` | 通用处理结果 | General processing result |
| `Paging` | 分页信息 | Paging information |
| `Sorting` | 排序信息 | Sorting information |
| `TimeRange` | 时间区间 | Time range |
| `Error` | 错误信息结构 | Error information structure |
| `LocalizedText` | 多语言文本 | Multilingual text |

### `enums/` - 枚举类型定义

包含所有服务共用的枚举类型，例如：

| 枚举类型 | 说明 | Description |
|---------|------|-------------|
| `CommonStatus` | 通用状态 | Common status |
| `UserStatus` | 用户状态 | User status |
| `TenantStatus` | 租户状态 | Tenant status |
| `MenuType` | 菜单/权限节点类型 | Menu / permission node type |
| `AuditAction` | 审计操作类型 | Audit action type |

### `[[ .ExampleServiceName | snake ]]/` - 示例服务定义

示例 gRPC 服务定义，包含基本的 CRUD 操作接口。

## 📝 注释规范

本项目的 `.proto` 文件采用**中英文双语注释**，格式如下：

```protobuf
// 中文注释
// [EN] English comment
enum CommonStatus {
  COMMON_STATUS_UNSPECIFIED = 0;  // 未指定 | [EN] Unspecified
  COMMON_STATUS_NORMAL = 1;       // 正常 | [EN] Normal
}
```

### 规则

1. **文件级注释**：中文在上，英文在下，使用 `[EN]` 前缀标记英文
2. **行内注释**：中文与英文在同一行，使用 `|` 分隔，英文以 `[EN]` 开头
3. **分隔线**：使用 `//===========================  中文标题 | English Title  ==========================//` 格式

## 🔄 代码生成

修改 `.proto` 文件后，运行以下命令重新生成代码：

```bash
# Windows
scripts\generate-modular.bat

# Linux/Mac
./scripts/generate-modular.sh
```

生成的代码输出到 `pb/` 目录，按模块划分。

## ➕ 添加新模块

1. 在 `proto/` 下创建新的子目录（使用 `snake_case` 命名）
2. 创建 `.proto` 文件，遵循中英文双语注释规范
3. 在 `scripts/generate-modular.bat` (或 `.sh`) 的 `PROTO_MODULES` 变量中添加模块名
4. 运行代码生成脚本
5. 运行 `go mod tidy` 更新依赖
