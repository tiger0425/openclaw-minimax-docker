# OpenClaw v2026.3.23 云服务器部署完整指南

## 📦 准备部署包

### 1. 在本地导出镜像

```bash
cd openclaw20260323

# 导出镜像（约 2-3GB）
docker save openclaw:v2026.3.23 | gzip > openclaw-v2026.3.23.tar.gz

# 检查文件
ls -lh openclaw-v2026.3.23.tar.gz
```

### 2. 复制部署文件

```bash
# 部署包已准备好在 github-deploy/ 目录
cd ../github-deploy

# 查看文件
ls -la
```

## 🚀 上传到云服务器

### 方法一：我帮你自动部署（推荐）

提供 SSH 信息后，我自动执行：

```bash
# 1. 上传部署文件
scp -r github-deploy root@你的服务器IP:/root/
scp openclaw20260323/openclaw-v2026.3.23.tar.gz root@你的服务器IP:/root/github-deploy/

# 2. SSH 登录并部署
ssh root@你的服务器IP
./deploy.sh
```

### 方法二：手动上传

**步骤 1：上传文件到服务器**

使用 SCP、SFTP 或宝塔面板上传以下文件到服务器 `/root/openclaw-deploy/`：

```
github-deploy/
├── docker-compose.yml      ← 必需
├── deploy.sh              ← 必需
├── .env.example           ← 重命名为 .env 后编辑
└── openclaw-v2026.3.23.tar.gz  ← 镜像文件（2-3GB）
```

**步骤 2：在服务器上执行**

```bash
# SSH 登录
ssh root@你的服务器IP

# 进入目录
cd /root/openclaw-deploy

# 编辑环境变量
cp .env.example .env
vim .env
# 填入：LARK_APP_ID, LARK_APP_SECRET

# 导入镜像
gunzip -c openclaw-v2026.3.23.tar.gz | docker load

# 启动服务
chmod +x deploy.sh
./deploy.sh
```

## ⚡ 快速命令参考

```bash
# 一键部署（假设已在服务器上）
cd /root/openclaw-deploy && ./deploy.sh

# 查看状态
docker ps

# 查看日志
docker logs -f openclaw-gateway

# 重启
docker-compose restart

# 停止
docker-compose down
```

## 🔒 防火墙配置

```bash
# 只允许 SSH（OpenClaw 不需要暴露端口）
ufw default deny incoming
ufw allow 22/tcp
ufw enable

# 检查状态
ufw status
```

## ✅ 验证部署

```bash
# 1. 容器运行正常
docker ps
# 应看到 openclaw-gateway 和 openclaw-headless-shell

# 2. 飞书已连接
docker logs openclaw-gateway | grep feishu
# 应看到 "WebSocket client started"

# 3. 在飞书中 @机器人测试
```

## 🐛 故障排除

### 镜像导入失败
```bash
# 如果 gunzip 失败，尝试不压缩传输
docker load -i openclaw-v2026.3.23.tar
```

### 飞书连接失败
```bash
# 检查日志
docker logs openclaw-gateway | tail -50

# 检查 .env 配置
cat .env | grep LARK
```

### 内存不足
```bash
# 4G 应该够用，检查其他程序
free -h
docker stats --no-stream
```
