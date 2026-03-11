# MeshRelay IRC 集成示例 (本地移植版)

本示例展示了如何将NullClaw部署为IRC网络中的智能机器人，支持MeshRelay去中心化网络中的消息中继和用户服务。

## 功能特性
- ✅ 自动连接到IRC服务器，加入多个频道
- ✅ 支持TLS加密连接和SASL认证
- ✅ 网络诊断工具集成（ping、traceroute、mtr等）
- ✅ 消息持久化存储，支持历史查询
- ✅ 自动识别服务机器人消息，避免循环回复
- ✅ 纯文本输出，符合IRC使用习惯

## 快速开始

### 前置要求
- Docker 20.10+
- Docker Compose v2+
- weechat（可选，用于IRC控制台访问）

### 1. 配置API密钥
编辑`config.irc.local.json`，添加你的Anthropic API密钥:
```json
"models": {
  "providers": {
    "anthropic": {
      "api_key": "sk-ant-你的API密钥"
    }
  }
}
```

### 2. 启动服务
```bash
chmod +x run.sh
./run.sh start
```

### 3. 访问IRC网络
```bash
# 使用weechat连接（推荐）
./run.sh console

# 或者使用任意IRC客户端连接到：
# 服务器: localhost:6667 (明文) / localhost:6697 (TLS)
# 加入频道: #general, #tech, #support
```

### 4. 测试机器人
在频道中发送消息：
```
nullclaw-bot: 请ping一下baidu.com
```
机器人会自动执行ping命令并返回结果。

### 5. 查看日志
```bash
./run.sh logs
```

### 6. 停止服务
```bash
./run.sh stop
```

## 自定义配置

### 修改监听频道
编辑`config.irc.local.json`中的`channels`字段：
```json
"channels": ["#general", "#tech", "#support", "#your-channel"]
```

### 启用网络工具
默认已启用常用网络诊断工具，你可以在`security.allowed_commands`中添加更多允许执行的命令。

### 连接到公共IRC网络
修改`config.irc.local.json`中的服务器配置，连接到如OFTC、Libera Chat等公共IRC网络：
```json
"host": "irc.oftc.net",
"port": 6697,
"tls": true
```

## 性能指标
- 连接建立时间: <500ms
- 消息响应延迟: <200ms
- 内存占用: ~800KB RSS
- 支持同时加入频道数: 100+

## 安全特性
- 默认启用Firejail沙箱隔离
- 命令白名单机制，防止恶意命令执行
- 自动过滤服务机器人消息，避免循环触发
- TLS加密传输支持
- 消息内容扫描，防止敏感信息泄露
