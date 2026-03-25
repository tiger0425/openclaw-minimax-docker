# OpenClaw 部署仓库说明

这个仓库现在包含 3 套不同用途的 OpenClaw 部署内容，分别用于主环境运行、独立版本测试，以及云服务器部署。

## 目录总览

### `openclaw-minimax-docker/`
当前主运行目录。

适用场景：
- 本地或现有环境持续运行
- 已完成 MiniMax、飞书、浏览器能力验证
- 继续沿用当前主环境配置

目录内主要文件：
- `.env.example`：环境变量模板
- `docker-compose.yml`：主环境容器编排
- `Dockerfile`：镜像构建文件
- `交付文档.md`：交付说明
- `ssh密钥连接配置指南.md`：SSH 使用说明

### `openclaw20260323/`
独立测试环境目录，用于测试 OpenClaw v2026.3.23。

适用场景：
- 验证新版本
- 与主环境隔离运行
- 测试新配置、新功能或升级方案

特点：
- 独立端口
- 独立容器名
- 独立 Docker 卷
- 不影响主环境

目录内主要文件：
- `README.md`：测试环境说明
- `DEPLOY.md`：生产部署说明
- `.env.example`：环境变量模板
- `docker-compose.yml`：测试环境编排
- `docker-compose.prod.yml`：生产部署编排
- `deploy.sh`：部署脚本
- `export-image.sh`：导出镜像脚本

### `github-deploy/`
云服务器部署包目录，配合阿里云容器镜像服务快速部署到国内服务器。

适用场景：
- 服务器部署（国内推荐）
- 飞书专用生产环境
- 无需上传大文件，自动从阿里云拉取镜像

镜像地址：
```
registry.cn-shenzhen.aliyuncs.com/yihuzh/openclaw:v2026.3.23
```

目录内主要文件：
- `README.md`：快速部署说明
- `DEPLOY-GUIDE.md`：完整部署指南
- `.env.example`：环境变量模板
- `docker-compose.yml`：生产部署编排（使用阿里云镜像）
- `deploy.sh`：部署脚本（自动拉取镜像）
- `openclaw.json`：OpenClaw 配置模板

## 如何选择

### 1. 继续使用当前主环境
进入：

```bash
cd openclaw-minimax-docker
```

然后按目录内现有配置运行。

### 2. 测试 v2026.3.23 独立环境
进入：

```bash
cd openclaw20260323
cp .env.example .env
docker compose up -d --build
```

测试环境说明见：

- `openclaw20260323/README.md`

### 3. 部署到云服务器（推荐）
使用阿里云容器镜像服务，国内访问速度快，无需上传大文件。

**快速部署：**

```bash
# 1. 上传部署文件到服务器
scp -r github-deploy root@你的服务器IP:/root/openclaw-deploy

# 2. 在服务器上配置并启动
ssh root@你的服务器IP
cd /root/openclaw-deploy
cp .env.example .env
vim .env  # 填入配置
./deploy.sh  # 自动从阿里云拉取镜像并启动
```

**详细说明：**
- `github-deploy/README.md` - 快速部署指南
- `github-deploy/DEPLOY-GUIDE.md` - 完整部署和排障指南

**如需本地导出镜像（备用方案）：**
在 `openclaw20260323/` 目录中使用 `export-image.sh` 导出后上传。

## 环境变量说明

不同目录下的 `.env.example` 用途不同，使用时请在对应目录中复制：

```bash
cp .env.example .env
```

常见变量包括：
- `OPENCLAW_GATEWAY_TOKEN`
- `MINIMAX_API_KEY`
- `LARK_APP_ID`
- `LARK_APP_SECRET`

请不要把真实 `.env`、私钥、运行数据目录提交到仓库。

## 当前仓库状态

当前仓库已经包含：
- 主运行环境目录
- v2026.3.23 独立测试环境
- 云服务器部署包目录

如果下一步要继续推进，建议优先做：
1. 按文档完整跑一遍部署流程
2. 确认主环境与测试环境的升级关系
3. 根据实际上线要求继续收紧安全配置
