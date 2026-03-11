# 部署最佳实践指南

## 系统要求

### 最低配置
- CPU: 1 核心
- 内存: 128 MB
- 存储: 1 GB 可用空间
- 网络: 1 Mbps 带宽

### 推荐配置
- CPU: 2+ 核心
- 内存: 512 MB
- 存储: 10 GB SSD
- 网络: 10 Mbps 带宽

## 部署模式

### 1. 单机部署
适合开发测试和小型场景：
```bash
# 编译二进制
zig build -Doptimize=ReleaseSmall

# 安装到系统路径
sudo cp zig-out/bin/nullclaw /usr/local/bin/

# 生成配置文件
nullclaw config generate > ~/.nullclaw/config.json

# 编辑配置，添加API密钥
vim ~/.nullclaw/config.json

# 启动服务
nullclaw service start
```

### 2. Docker部署
推荐生产环境使用：
```bash
# 拉取镜像
docker pull ghcr.io/anthropics/nullclaw:latest

# 运行容器
docker run -d \
  --name nullclaw \
  -v ./config.json:/root/.nullclaw/config.json:ro \
  -v ./data:/root/.nullclaw \
  -p 8080:8080 \
  --restart unless-stopped \
  ghcr.io/anthropics/nullclaw:latest gateway
```

### 3. Docker Compose部署
多组件部署推荐：
```yaml
version: "3.8"
services:
  nullclaw:
    image: ghcr.io/anthropics/nullclaw:latest
    restart: unless-stopped
    volumes:
      - ./config.json:/root/.nullclaw/config.json:ro
      - ./data:/root/.nullclaw
    ports:
      - "8080:8080"
    environment:
      - NULLCLAW_GATEWAY_ENABLED=true
      - NULLCLAW_SECURITY_SANDBOX=firejail

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - ./redis:/data

  postgres:
    image: postgres:15-alpine
    restart: unless-stopped
    volumes:
      - ./postgres:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=nullclaw
      - POSTGRES_PASSWORD=nullclaw_password
      - POSTGRES_DB=nullclaw
```

### 4. Kubernetes部署
大规模集群部署：
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nullclaw
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nullclaw
  template:
    metadata:
      labels:
        app: nullclaw
    spec:
      containers:
      - name: nullclaw
        image: ghcr.io/anthropics/nullclaw:latest
        ports:
        - containerPort: 8080
        resources:
          limits:
            memory: "128Mi"
            cpu: "500m"
          requests:
            memory: "64Mi"
            cpu: "100m"
        volumeMounts:
        - name: config
          mountPath: /root/.nullclaw/config.json
          subPath: config.json
          readOnly: true
        - name: data
          mountPath: /root/.nullclaw
      volumes:
      - name: config
        configMap:
          name: nullclaw-config
      - name: data
        persistentVolumeClaim:
          claimName: nullclaw-data
---
apiVersion: v1
kind: Service
metadata:
  name: nullclaw-service
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: nullclaw
```

## 配置优化

### 性能优化
```json
{
  "runtime": {
    "max_concurrent_sessions": 100,
    "session_timeout_seconds": 3600,
    "enable_jemalloc": true
  },
  "memory": {
    "engine": "sqlite",
    "cache_size_mb": 64,
    "async_write": true
  },
  "gateway": {
    "workers": 4,
    "keep_alive_timeout": 300,
    "enable_compression": true
  }
}
```

### 安全配置
```json
{
  "security": {
    "sandbox": "firejail",
    "allow_remote_code_execution": false,
    "allowed_tools": ["memory", "websearch"],
    "max_tool_execution_time_seconds": 30,
    "enable_audit_log": true,
    "audit_log_path": "/var/log/nullclaw/audit.log"
  },
  "autonomy": {
    "level": "manual",
    "require_human_approval": ["bash", "file_write"],
    "max_autonomous_actions": 10
  }
}
```

## 高可用部署

### 负载均衡配置
使用Nginx作为反向代理：
```nginx
http {
    upstream nullclaw {
        server 10.0.0.1:8080;
        server 10.0.0.2:8080;
        server 10.0.0.3:8080;
        keepalive 64;
    }

    server {
        listen 80;
        server_name nullclaw.example.com;

        location / {
            proxy_pass http://nullclaw;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

            # 超时配置
            proxy_connect_timeout 10s;
            proxy_send_timeout 300s;
            proxy_read_timeout 300s;

            # 缓存配置
            proxy_cache static_cache;
            proxy_cache_valid 200 10m;
        }

        # SSL配置
        listen 443 ssl;
        ssl_certificate /etc/ssl/certs/nullclaw.example.com.crt;
        ssl_certificate_key /etc/ssl/private/nullclaw.example.com.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
    }
}
```

### 监控配置
使用Prometheus + Grafana监控：
```yaml
scrape_configs:
  - job_name: 'nullclaw'
    static_configs:
      - targets: ['nullclaw:8080']
    metrics_path: '/metrics'
```

关键监控指标：
- `nullclaw_session_count`：活跃会话数
- `nullclaw_request_total`：总请求数
- `nullclaw_request_duration_seconds`：请求延迟
- `nullclaw_memory_usage_bytes`：内存使用
- `nullclaw_tool_calls_total`：工具调用次数
- `nullclaw_error_total`：错误次数

## 备份与恢复

### 数据备份
```bash
# 备份配置文件
cp ~/.nullclaw/config.json /backup/config-$(date +%Y%m%d).json

# 备份SQLite数据库
sqlite3 ~/.nullclaw/memory.db ".backup /backup/memory-$(date +%Y%m%d).db"

# 备份全部数据
tar -czf /backup/nullclaw-$(date +%Y%m%d).tar.gz ~/.nullclaw/
```

### 自动备份脚本
```bash
#!/bin/bash
BACKUP_DIR="/backup"
KEEP_DAYS=7

mkdir -p $BACKUP_DIR

# 备份
tar -czf $BACKUP_DIR/nullclaw-$(date +%Y%m%d).tar.gz /root/.nullclaw/

# 删除旧备份
find $BACKUP_DIR -name "nullclaw-*.tar.gz" -mtime +$KEEP_DAYS -delete

# 上传到对象存储（可选）
# aws s3 cp $BACKUP_DIR/nullclaw-$(date +%Y%m%d).tar.gz s3://backup-bucket/nullclaw/
```

## 升级流程

### 零停机升级
1. 拉取新版本镜像
2. 启动新版本容器
3. 健康检查通过后，切换流量到新版本
4. 停止旧版本容器

### 降级方案
如果新版本出现问题，直接回滚到上一个版本：
```bash
docker stop nullclaw-new
docker start nullclaw-old
```

## 生产环境检查清单
- [ ] 配置文件权限设置为600
- [ ] API密钥等敏感信息未硬编码
- [ ] 启用TLS加密传输
- [ ] 配置防火墙规则，只开放必要端口
- [ ] 启用审计日志
- [ ] 配置定期备份
- [ ] 设置监控告警
- [ ] 配置自动重启策略
- [ ] 测试故障恢复流程
- [ ] 文档记录部署拓扑和配置
