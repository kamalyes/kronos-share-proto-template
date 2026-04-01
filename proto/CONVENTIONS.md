# proto 目录规范 | Proto directory conventions

完整规范（含校验规则速查）见 [`<% .AiAssistant %>/skills/<% .OrgPrefix %>-proto-style/SKILL.md`](../<% .AiAssistant %>/skills/<% .OrgPrefix %>-proto-style/SKILL.md)
本文件只讲目录分工。

[EN] The full style guide and the validation rule reference live in the files linked above;
this file only covers how the directories divide responsibility

## 目录分工 | Directory responsibilities

| 目录 \| Directory | 放什么 \| Contains | 不放什么 \| Does not contain |
| --- | --- | --- |
| `common/` | 两个以上模块引用的消息实体 | 只有一个模块用的消息 |
| `enums/` | 所有枚举，无论被几个模块引用 | 任何消息定义 |
| `<module>/` | 该模块的服务定义与请求/响应消息 | 公共实体、枚举 |
| `<% .MixedModule %>/` | 混合模块示例：同一模块下多个 service 文件 | 跨模块复用的实体 |

枚举一律进 `enums/`，哪怕只有一个模块用：枚举是最容易被第二个模块需要的东西，
放在业务文件里等于埋一次将来的搬迁。

[EN] Every enum goes into `enums/` even when a single module uses it: enums are the type
most likely to be needed by a second module, and keeping one in a service file just
schedules a future migration

## 聚合文件 | Aggregation files

`common/common.proto` 与 `enums/enums.proto` 只做一件事：用 `import public` 把子文件串起来。

```protobuf
import public "proto/common/<% .ExampleModule %>.proto";
```

业务模块只 import 这两个聚合文件，不直接 import 子文件：
子文件拆分或改名时，业务模块不用动。

[EN] Business modules import only these two aggregation files, never the sub-files, so
splitting or renaming a sub-file leaves them untouched

**新增子文件必须注册到聚合文件**，否则别的模块 import 不到它。
[EN] A new sub-file must be registered in the aggregation file or other modules cannot see it

## 命名 | Naming

```text
proto/<module>/<service>_service.proto     服务文件 | service file
proto/common/<module>.proto                该模块的公共实体 | shared entities
proto/enums/<module>.proto                 该模块的枚举 | enums
```

模块目录名用小写蛇形（`<% .ExampleModule %>`），服务名用 PascalCase（`<% .ExampleService | pascal %>`），
生成的 Go 包名就是模块目录名。

[EN] Module directories are lower_snake_case, service names are PascalCase, and the
generated Go package name is the module directory name

## 依赖方向 | Dependency direction

```text
enums/   ←── common/   ←── <module>/
  ↑                           │
  └───────────────────────────┘
```

- `enums/` 不依赖任何东西
- `common/` 只依赖 `enums/`
- 业务模块依赖 `common/` 与 `enums/`
- **业务模块之间不互相 import**：需要共享就把类型提到 `common/`

最后一条是硬约束：模块间直接 import 会让两个限界上下文焊死在一起，
一方改字段另一方必须同步发版。

[EN] The last rule is hard: importing one business module from another welds two bounded
contexts together, so a field change on one side forces a release on the other
