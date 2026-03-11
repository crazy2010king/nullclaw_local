# 常见问题排查指南

## 构建相关问题

### 问题1：Zig版本不兼容
**错误信息**：
```
error: Zig version 0.14.0 is not supported, please use 0.15.2
```

**解决方案**：
1. 下载并安装Zig 0.15.2：
   ```bash
   wget https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz
   tar -xf zig-linux-x86_64-0.15.2.tar.xz
   sudo mv zig-linux-x86_64-0.15.2 /usr/local/zig
   sudo ln -s /usr/local/zig/zig /usr/local/bin/zig
   ```
2. 验证版本：
   ```bash
   zig version
   # 输出应该是 0.15.2
   ```

### 问题2：构建失败，缺少依赖
**错误信息**：
```
error: could not find 'sqlite3.h'
```

**解决方案**：
NullClaw使用vendored SQLite，不需要系统安装SQLite。如果出现这个错误，检查是否正确克隆了子模块：
```bash
git submodule update --init --recursive
```

### 问题3：构建后的二进制过大
**预期**：二进制大小应该 < 1MB
**解决方案**：
使用ReleaseSmall优化级别构建：
```bash
zig build -Doptimize=ReleaseSmall
```
检查构建输出：
```bash
ls -lh zig-out/bin/nullclaw
# 应该显示 ~600-800KB
```

## 运行时问题

### 问题1：启动失败，配置文件错误
**错误信息**：
```
error: invalid config: missing 'models.providers.anthropic.api_key'
```

**解决方案**：
1. 生成默认配置文件：
   ```bash
   nullclaw config generate > ~/.nullclaw/config.json
   ```
2. 编辑配置文件，添加API密钥：
   ```json
   "models": {
     "providers": {
       "anthropic": {
         "api_key": "sk-ant-你的API密钥"
       }
     }
   }
   ```
3. 验证配置：
   ```bash
   nullclaw config validate
   ```

### 问题2：无法连接到消息渠道
**错误信息**：
```
error: failed to connect to matrix server: connection refused
```

**解决方案**：
1. 检查网络连接：
   ```bash
   ping matrix.org
   ```
2. 检查代理配置（如果使用代理）：
   ```bash
   export HTTP_PROXY=http://proxy:port
   export HTTPS_PROXY=http://proxy:port
   ```
3. 检查防火墙设置，确保出站端口开放：
   - Matrix: 443 (HTTPS)
   - IRC: 6667 (明文), 6697 (TLS)
   - Telegram: 443, 80, 88, 8443

### 问题3：内存泄漏
**现象**：内存使用持续增长
**解决方案**：
1. 确认使用了leak检测模式运行测试：
   ```bash
   zig build test --summary all
   ```
2. 检查是否有未释放的资源，所有分配都应该有对应的defer释放
3. 如果使用SQLite内存引擎，检查是否配置了正确的缓存大小：
   ```json
   "memory": {
     "engine": "sqlite",
     "cache_size_mb": 64,
     "max_entries": 10000
   }
   ```

## 渠道相关问题

### Matrix渠道问题
**问题**：无法发送消息，权限错误
**解决方案**：
1. 检查access_token是否正确
2. 检查机器人是否已经加入对应的房间
3. 检查房间权限设置，确保机器人有发送消息的权限

### IRC渠道问题
**问题**：频繁掉线
**解决方案**：
1. 检查是否启用了TLS，某些IRC服务器强制要求TLS连接
2. 配置ping_timeout参数：
   ```json
   "channels": {
     "irc": {
       "ping_timeout_seconds": 300,
       "reconnect_interval_seconds": 10
     }
   }
   ```
3. 检查是否被服务器封禁，更换昵称或IP

### 边缘Worker问题
**问题**：WASM模块加载失败
**解决方案**：
1. 确认WASM是为wasm32-wasi目标编译的：
   ```bash
   zig build -Doptimize=ReleaseSmall -Dtarget=wasm32-wasi
   ```
2. 检查Node.js版本 >= 18，支持WASI
3. 启用WASM实验性功能（如果需要）：
   ```bash
   node --experimental-wasi-unstable-preview1 local-worker.js
   ```

## 性能问题

### 问题1：响应延迟高
**解决方案**：
1. 检查模型API响应时间，选择延迟更低的提供商
2. 启用本地缓存，减少重复请求：
   ```json
   "cache": {
     "enabled": true,
     "ttl_seconds": 3600,
     "max_size_mb": 128
   }
   ```
3. 调整并发设置：
   ```json
   "runtime": {
     "max_concurrent_requests": 50,
     "request_timeout_seconds": 60
   }
   ```

### 问题2：CPU占用过高
**解决方案**：
1. 检查是否有无限循环的工具调用，配置max_tool_iterations：
   ```json
   "agents": {
     "default": {
       "max_tool_iterations": 100
     }
   }
   ```
2. 启用异步IO：
   ```json
   "runtime": {
     "async_io": true,
     "worker_threads": 2
   }
   ```
3. 调整日志级别，减少日志输出：
   ```json
   "logging": {
     "level": "warn"
   }
   ```

## 安全相关问题

### 问题1：沙箱启动失败
**错误信息**：
```
error: failed to initialize firejail sandbox: permission denied
```

**解决方案**：
1. 确认firejail已安装：
   ```bash
   sudo apt install firejail
   ```
2. 配置firejail SUID权限：
   ```bash
   sudo chmod u+s /usr/bin/firejail
   ```
3. 或临时禁用沙箱（仅用于测试）：
   ```json
   "security": {
     "sandbox": "none"
   }
   ```

### 问题2：工具执行被拒绝
**错误信息**：
```
error: tool 'bash' is not allowed by security policy
```

**解决方案**：
1. 在配置中添加工具到白名单：
   ```json
   "security": {
     "allowed_tools": ["memory", "websearch", "bash"]
   }
   ```
2. 或调整自主级别：
   ```json
   "autonomy": {
     "level": "full",
     "require_human_approval": []
   }
   ```
⚠️ 注意：允许bash工具会带来安全风险，请谨慎配置。

## 日志排查

### 查看运行日志
```bash
# 系统服务日志
journalctl -u nullclaw.service -f

# Docker日志
docker logs -f nullclaw

# 自定义日志路径
tail -f /var/log/nullclaw/nullclaw.log
```

### 启用调试日志
在配置文件中设置日志级别为debug：
```json
"logging": {
  "level": "debug",
  "file": "/var/log/nullclaw/debug.log"
}
```

### 常见错误码
| 错误码 | 含义 | 解决方案 |
|--------|------|----------|
| 401 | API密钥无效 | 检查API密钥是否正确 |
| 403 | 权限不足 | 检查账号权限和配置 |
| 429 | 请求频率超限 | 降低请求频率，配置重试策略 |
| 500 | 服务端错误 | 联系API提供商支持 |
| 503 | 服务不可用 | 等待恢复，或切换备用提供商 |

## 社区支持
如果以上方案无法解决你的问题：
1. 查看[GitHub Issues](https://github.com/anthropics/nullclaw/issues)是否有相关问题
2. 提交新的Issue，包含以下信息：
   - NullClaw版本
   - 操作系统版本
   - 错误日志和复现步骤
   - 配置文件（脱敏后）
3. 加入社区Discord/Slack频道寻求帮助
