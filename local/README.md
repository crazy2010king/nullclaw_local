# NullClaw 本地示例集

本项目是NullClaw框架的本地化示例集合，包含完整的可运行示例、详细文档和统一工具脚本，帮助用户快速上手NullClaw开发。

## 🚀 快速开始

### 前置要求
- Linux x86_64 系统 (Ubuntu 20.04+, Alpine 3.18+)
- Zig 0.15.2 (用于编译NullClaw核心)
- Docker 20.10+ 和 Docker Compose v2+ (用于运行容器化示例)
- Node.js 18+ (用于边缘计算示例)

### 1. 克隆仓库
```bash
git clone https://github.com/anthropics/nullclaw.git
cd nullclaw/local
```

### 2. 构建所有示例
```bash
./scripts/build.sh --all
```

### 3. 运行所有示例
```bash
./scripts/run-all.sh start
```

### 4. 运行测试
```bash
./scripts/test-all.sh --all
```

## 📦 示例列表

| 示例名称 | 描述 | 端口 |
|---------|------|------|
| [modal-matrix](./examples/modal-matrix/) | 多代理协作系统，基于Matrix消息队列 | 8008 (Matrix) |
| [meshrelay-irc](./examples/meshrelay-irc/) | IRC智能机器人，支持MeshRelay网络 | 6667/6697 (IRC) |
| [edge-worker](./examples/edge-worker/) | 边缘计算节点，WASM低延迟策略引擎 | 8787 (HTTP API) |

## 📚 文档

- [架构说明](./docs/architecture.md) - 整体架构设计和技术选型
- [部署指南](./docs/deployment-guide.md) - 生产环境部署最佳实践
- [故障排除](./docs/troubleshooting.md) - 常见问题和解决方案
- [社区实践](./docs/community-practices.md) - 社区优秀使用案例和经验分享

## 🛠️ 统一脚本

| 脚本 | 功能 |
|------|------|
| `scripts/build.sh` | 统一构建脚本，支持按需编译单个或所有示例 |
| `scripts/run-all.sh` | 统一运行脚本，支持启停、状态查看、日志查看 |
| `scripts/test-all.sh` | 统一测试脚本，包含单元测试、集成测试、性能测试 |
| `scripts/utils.sh` | 通用工具函数库，被其他脚本引用 |

## 🎯 核心特性

### 极致性能
- 所有二进制大小 < 1MB
- 启动时间 < 2ms
- 内存峰值 < 1MB RSS
- 支持musl和glibc环境

### 高度可移植
- 支持Docker容器化和非容器化部署
- 兼容Ubuntu 20.04/22.04/24.04 和 Alpine 3.18+
- 支持x86_64、ARM64等多种架构
- 无外部依赖，单二进制分发

### 安全可靠
- 默认启用沙箱隔离
- 最小权限原则
- 7x24小时稳定运行
- 零内存泄漏

## 📋 快速导航

### 多代理协作示例
```bash
# 启动Matrix多代理系统
cd examples/modal-matrix
./deploy.local.sh init
./deploy.local.sh start
```

### IRC机器人示例
```bash
# 启动IRC智能机器人
cd examples/meshrelay-irc
./run.sh start
./run.sh console
```

### 边缘计算示例
```bash
# 启动边缘计算节点
cd examples/edge-worker
npm install
npm start
# 测试API
curl -X POST http://localhost:8787/api/infer -d '{"text":"紧急问题"}' -H "Content-Type: application/json"
```

## 🤝 贡献
欢迎提交Issue和PR来完善示例集！请参考[贡献指南](../CONTRIBUTING.md)了解更多信息。

## 📄 许可证
MIT License，详见[LICENSE](../LICENSE)文件。
