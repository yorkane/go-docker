# yourapp

生产级 Go 应用，使用 `debian:stable-slim` + `s6-overlay` 容器化，实现非 root 进程管理。

## 特性

- **非 Root 运行**: 应用以 UID 10001 的 `appuser` 运行
- **s6-overlay 进程管理**: 信号处理、僵尸回收、日志管理
- **多阶段构建**: 减小镜像体积，优化构建缓存
- **健康检查**: 内置 healthcheck + s6-svstat 集成
- **跨平台构建**: 支持 Linux/macOS/Windows，多架构 (amd64/arm64)
- **CI/CD 集成**: GitHub Actions 自动测试、构建、推送、安全扫描

## 目录结构

```
yourapp/
├── cmd/server/          # 主程序入口
│   └── main.go
├── etc/
│   └── services.d/      # s6-overlay 服务定义
│       └── yourapp/
│           ├── run      # 启动脚本
│           └── finish   # 停止回调
├── Dockerfile           # 多阶段构建
├── docker-compose.yml   # 本地开发/生产测试
├── Makefile            # 构建脚本
├── config.yaml         # 默认配置
└── .github/workflows/  # CI/CD
```

## 快速开始

### 本地开发

```bash
# 启动开发环境 (带有调试工具)
make dev

# 查看日志
make logs

# 进入容器 shell
make shell
```

### 构建

```bash
# 构建本地二进制
make build

# 构建所有平台
make build-all

# 构建 Docker 镜像
make docker-build
```

### 生产部署

```bash
# 启动生产容器
make up

# 重启
make restart

# 停止
make down
```

## 常用命令

| 命令 | 说明 |
|------|------|
| `make dev` | 启动开发环境 |
| `make build` | 构建 Linux 二进制 |
| `make docker-build` | 构建生产镜像 |
| `make test` | 运行测试 |
| `make lint` | 运行代码检查 |
| `make up` | 启动生产容器 |
| `make clean` | 清理构建产物 |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `APP_LOG_LEVEL` | `info` | 日志级别 (debug/info/warn/error) |
| `TZ` | `Asia/Shanghai` | 时区 |
| `UID` | `10001` | 运行用户 UID |
| `GID` | `10001` | 运行用户 GID |

## 容器架构

```
┌─────────────────────────────────────────────────────────┐
│                    debian:stable-slim                   │
│  ┌───────────────────────────────────────────────────┐  │
│  │                   s6-overlay                      │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │              yourapp (PID 1 replaced)        │  │  │
│  │  │  ┌─────────────────────────────────────┐   │  │  │
│  │  │  │   /app/yourapp (appuser:appgroup)   │   │  │  │
│  │  │  └─────────────────────────────────────┘   │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### s6-overlay 职责

- **PID 1**: 替换容器中的 PID 1，接收所有信号
- **信号转发**: 将 SIGTERM/SIGINT 正确转发给应用
- **僵尸回收**: 自动回收已终止的子进程
- **日志管理**: 通过 s6-log 处理日志轮转
- **进程监控**: 监控应用状态，支持自动重启

## API

- `GET /` - 返回服务状态
- `GET /health` - 健康检查 (liveness)
- `GET /ready` - 就绪检查 (readiness)

## 版本

- Go: 1.22+
- s6-overlay: latest
- Debian: stable-slim

## License

MIT
