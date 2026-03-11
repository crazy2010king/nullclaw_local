# Edge Worker 边缘计算示例 (本地移植版)

本示例展示了如何在本地环境中运行NullClaw边缘计算节点，使用WASM核心实现低延迟策略决策，替代Cloudflare Worker云服务。

## 架构说明
```
┌─────────────────┐
│   HTTP Client   │
└─────────────────┘
         ↓
┌─────────────────┐
│ Fastify Server  │  (Node.js 主机环境)
│  - KV存储       │
│  - 特征提取     │
│  - API路由      │
└─────────────────┘
         ↓
┌─────────────────┐
│ WASM Core       │  (Zig编译的WASM决策引擎)
│  - 策略选择     │
│  - 低延迟执行   │
│  - <100KB大小   │
└─────────────────┘
```

## 功能特性
- ✅ 纯本地运行，无需依赖Cloudflare服务
- ✅ WASM核心大小 < 100KB，启动时间 < 1ms
- ✅ 内置SQLite KV存储，支持TTL过期
- ✅ 可选Redis缓存，支持高并发场景
- ✅ 符合Cloudflare Worker API规范，易于迁移
- ✅ 资源占用极低：< 64MB内存，< 0.5 CPU核心

## 快速开始

### 前置要求
- Node.js 18+ 或 Docker
- Zig 0.15.2 (用于编译WASM核心，可选，已提供预编译版本)

### 方式一：Node.js直接运行

#### 1. 安装依赖
```bash
npm install
```

#### 2. 启动服务
```bash
npm start
```
服务将在 http://localhost:8787 启动

### 方式二：Docker运行
```bash
docker-compose up -d
```

### 测试API

#### 健康检查
```bash
curl http://localhost:8787/health
```

#### 策略推理测试
```bash
curl -X POST http://localhost:8787/api/infer \
  -H "Content-Type: application/json" \
  -d '{"text": "紧急！服务器CPU占用率100%，怎么处理？"}'
```

#### KV存储测试
```bash
# 写入KV
curl -X PUT http://localhost:8787/kv/test_key \
  -H "Content-Type: application/json" \
  -d '{"value": "test_value", "ttl": 3600}'

# 读取KV
curl http://localhost:8787/kv/test_key

# 删除KV
curl -X DELETE http://localhost:8787/kv/test_key
```

### 启用Redis缓存（可选）
```bash
docker-compose --profile with-redis up -d
```

## 策略规则
WASM核心根据以下规则自动选择响应策略：

| 策略类型 | 触发条件 | 响应风格 |
|---------|---------|---------|
| urgent  | 包含紧急关键词 或 长文本 + 高优先级 | 优先响应，简洁紧急 |
| detailed | 包含问题/代码片段 或 长文本 | 详细解答，步骤清晰 |
| concise | 短文本，无特殊标记 | 简洁回复，快速响应 |

## 性能测试
```bash
# 安装压测工具
npm install -g autocannon

# 压测推理接口
autocannon -c 100 -d 30 -m POST -H "Content-Type: application/json" \
  -b '{"text": "测试请求"}' http://localhost:8787/api/infer
```

典型性能指标：
- 吞吐量: > 10,000 QPS
- 平均延迟: < 5ms
- P99延迟: < 20ms
- 内存占用: ~64MB

## 自定义开发

### 修改WASM核心逻辑
编辑`../../../examples/edge/cloudflare-worker/agent_core.zig`，然后重新编译：
```bash
cd ../../../examples/edge/cloudflare-worker
zig build -Doptimize=ReleaseSmall -Dtarget=wasm32-wasi
cp zig-out/bin/agent_core.wasm ../../../local/examples/edge-worker/
```

### 添加新的API接口
编辑`local-worker.js`添加新的路由和业务逻辑。

### 扩展KV存储
支持替换为Redis、PostgreSQL等其他存储后端，只需要修改KV操作相关代码。

## 部署最佳实践
- 使用Docker容器化部署
- 配置Nginx反向代理和负载均衡
- 启用Gzip压缩和缓存
- 配置HTTPS证书
- 监控内存和CPU使用率
