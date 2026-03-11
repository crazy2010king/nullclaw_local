# Modal + Matrix 多代理部署示例 (本地移植版)

本示例展示了如何在本地环境中部署NullClaw多代理系统，无需依赖Modal云服务。使用Docker Compose启动本地Matrix homeserver和两个协作的NullClaw代理。

## 架构说明
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Coordinator Agent │ ←→ │ Matrix Homeserver │ ←→ │ Worker Agent    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         ↓                        ↓                        ↓
    任务分发、结果聚合       消息中转、同步            任务执行、工具调用
```

## 快速开始

### 前置要求
- Docker 20.10+
- Docker Compose v2+
- jq (用于解析JSON)

### 1. 初始化环境
```bash
chmod +x deploy.local.sh
./deploy.local.sh init
```
这将:
- 启动本地Matrix Synapse homeserver
- 创建coordinator和worker用户
- 创建公共聊天室
- 生成访问令牌并保存到.env文件

### 2. 配置API密钥
编辑`config.matrix.local.json`，在`models.providers`中添加你的Anthropic API密钥:
```json
"models": {
  "providers": {
    "anthropic": {
      "api_key": "sk-ant-你的API密钥"
    }
  }
}
```

### 3. 启动所有服务
```bash
./deploy.local.sh start
```

### 4. 查看状态
```bash
./deploy.local.sh status
```

### 5. 查看日志
```bash
./deploy.local.sh logs
```

### 6. 停止服务
```bash
./deploy.local.sh stop
```

## 使用方法

### 测试多代理协作
1. 使用Matrix客户端连接到`http://localhost:8008`，使用admin用户登录(密码: admin_password)
2. 加入`#general:matrix.local`房间
3. 发送消息：`@coordinator 请计算10个斐波那契数列，让worker执行计算`
4. 观察两个代理之间的协作过程

### 自定义代理配置
- 编辑`config.matrix.local.json`修改代理的系统提示词、工具权限、模型参数等
- 在`docker-compose.yml`中可以添加更多代理实例

## 性能指标
- 单个代理启动时间: <2ms
- 内存占用: ~1MB RSS
- 消息延迟: <100ms (本地网络)
- 二进制大小: <1MB

## 故障排除
- 如果Synapse启动失败，检查`data/synapse/homeserver.yaml`配置
- 如果代理无法连接到Matrix，检查.env文件中的访问令牌是否正确
- 所有数据保存在`data/`目录下，删除后将重置整个环境
