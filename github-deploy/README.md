# OpenClaw v2026.3.23 生产部署仓库（飞书专用）

## 🚀 快速部署

### 1. 服务器准备

```bash
# 安装 Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker && systemctl start docker

# 安装 Docker Compose
docker compose version || apt-get install -y docker-compose-plugin
```

### 2. 下载部署文件

```bash
# 克隆仓库
git clone https://github.com/YOUR_USERNAME/openclaw-deploy.git
cd openclaw-deploy

# 创建环境变量文件
cp .env.example .env
vim .env  # 编辑你的配置
```

### 3. 导入镜像（需要提前上传）

```bash
# 从本地上传镜像到服务器
# scp openclaw-v2026.3.23.tar.gz root@服务器IP:/root/openclaw-deploy/

# 在服务器上导入
gunzip -c openclaw-v2026.3.23.tar.gz | docker load
```

### 4. 启动服务

```bash
chmod +x deploy.sh
./deploy.sh
```

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `docker-compose.yml` | 生产环境配置 |
| `deploy.sh` | 自动部署脚本 |
| `.env.example` | 环境变量模板 |
| `setup-firewall.sh` | 防火墙配置 |

## 🔒 安全说明

- 不暴露任何公网端口
- 飞书通过 WebSocket 主动连接
- Token 通过 .env 传入，不提交到 GitHub

## 📝 配置说明

编辑 `.env` 文件：

```bash
# 自动生成强 Token
OPENCLAW_GATEWAY_TOKEN=xxx...

# 飞书配置（必填）
LARK_APP_ID=cli_xxx
LARK_APP_SECRET=xxx

# MiniMax（可选）
MINIMAX_API_KEY=xxx
```
