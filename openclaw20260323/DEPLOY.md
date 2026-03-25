# OpenClaw v2026.3.23 生产环境部署指南（飞书专用）

## 🎯 部署概览

- **用途**：飞书机器人对接
- **环境**：4核4G 云服务器
- **安全**：不暴露公网端口，仅飞书可访问
- **镜像大小**：约 6GB

## 📋 前置要求

### 云服务器要求
- **系统**：Ubuntu 22.04+ / Debian 12 / CentOS 8+
- **配置**：4核4G 或以上
- **磁盘**：至少 20GB 可用空间
- **网络**：可访问飞书服务器（出站 443 端口）

### 本地要求
- Docker 已安装
- OpenClaw v2026.3.23 镜像已构建

## 🚀 部署步骤

### 第一步：准备文件

在本地执行：

```bash
cd openclaw20260323

# 1. 导出镜像
./export-image.sh
# 生成文件：openclaw-v2026.3.23.tar.gz（约 2-3GB）

# 2. 准备部署包
mkdir -p deploy-package
cp openclaw-v2026.3.23.tar.gz deploy-package/
cp docker-compose.prod.yml deploy-package/
cp deploy.sh deploy-package/
```

### 第二步：上传到云服务器

```bash
# 替换为你的服务器 IP
SERVER_IP=your-server-ip

# 上传部署包
scp -r deploy-package root@${SERVER_IP}:/root/

# 或者只上传关键文件
scp openclaw-v2026.3.23.tar.gz root@${SERVER_IP}:/root/
scp docker-compose.prod.yml root@${SERVER_IP}:/root/
scp deploy.sh root@${SERVER_IP}:/root/
```

### 第三步：在云服务器上部署

SSH 登录到服务器：

```bash
ssh root@your-server-ip

# 1. 安装 Docker（如未安装）
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# 2. 导入镜像
gunzip -c openclaw-v2026.3.23.tar.gz | docker load

# 3. 进入部署目录
cd /root

# 4. 运行部署脚本
chmod +x deploy.sh
./deploy.sh

# 第一次运行会提示编辑 .env 文件
# 按提示填入飞书 App ID 和 Secret
```

### 第四步：配置飞书

在飞书开发者后台：

1. **事件订阅方式**：选择「长连接（WebSocket）」
2. **IP 白名单**（可选）：添加你的服务器公网 IP
3. **权限**：确保有 `im:chat:readonly` 和 `im:message:send` 权限

### 第五步：验证部署

```bash
# 查看容器状态
docker ps

# 查看日志（检查飞书连接）
docker logs -f openclaw-gateway

# 应该看到：
# [feishu] feishu[default]: WebSocket client started
# [feishu] feishu[default]: bot open_id resolved: ou_xxxxx
```

## 🔒 安全配置

### 防火墙设置（UFW）

```bash
# 只允许 SSH（管理用）
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw enable

# 检查状态
ufw status
```

### 不暴露的端口

| 端口 | 用途 | 状态 |
|------|------|------|
| 18889 | OpenClaw Gateway | ❌ 不暴露 |
| 18890 | WebSocket | ❌ 不暴露 |
| 19222 | CDP | ❌ 不暴露 |

**飞书通过 WebSocket 主动连接，不需要你开放端口。**

## 📝 常用管理命令

```bash
# 查看状态
docker-compose -f docker-compose.prod.yml ps

# 查看日志
docker logs -f openclaw-gateway

# 重启服务
docker-compose -f docker-compose.prod.yml restart

# 停止服务
docker-compose -f docker-compose.prod.yml down

# 更新配置后重启
docker-compose -f docker-compose.prod.yml up -d

# 备份数据
tar czf openclaw-backup-$(date +%Y%m%d).tar.gz openclaw_data/
```

## 🌐 远程管理（SSH 隧道）

如需临时访问 Control UI：

```bash
# 在本地电脑执行
ssh -L 18889:localhost:18889 root@your-server-ip

# 保持 SSH 连接，然后在浏览器访问
http://localhost:18889/#token=你的TOKEN
```

## 🐛 故障排除

### 飞书连接失败

```bash
# 检查日志
docker logs openclaw-gateway | grep -i feishu

# 常见问题：
# 1. LARK_APP_ID 或 LARK_APP_SECRET 错误
# 2. 飞书后台未开启 WebSocket 模式
# 3. 网络不通（检查服务器能否访问 open.feishu.cn）
```

### 内存不足

```bash
# 查看内存使用
docker stats --no-stream

# 4G 内存完全够用，如果不够检查是否有其他程序
free -h
```

### 镜像导入失败

```bash
# 如果 gunzip 失败，尝试：
docker load -i openclaw-v2026.3.23.tar.gz
```

## 📊 性能监控

```bash
# 查看资源占用
docker stats --no-stream

# 查看磁盘使用
docker system df

# 清理旧日志
docker logs --tail 100 openclaw-gateway > /tmp/latest.log
docker system prune -f
```

## 🎉 完成

部署完成后，在飞书中 @你的机器人，测试是否能正常回复！
