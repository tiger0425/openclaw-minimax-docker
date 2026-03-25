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
云服务器部署包目录，适合把部署文件单独上传到服务器使用。

适用场景：
- 服务器部署
- 飞书专用生产环境
- 将镜像文件与部署脚本一起交付他人

目录内主要文件：
- `README.md`：快速部署说明
- `DEPLOY-GUIDE.md`：完整部署指南
- `.env.example`：环境变量模板
- `docker-compose.yml`：生产部署编排
- `deploy.sh`：部署脚本
- `export-image.sh`：镜像导出脚本
- `openclaw.json`：运行配置模板

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

### 3. 部署到云服务器
优先参考：

- `github-deploy/README.md`
- `github-deploy/DEPLOY-GUIDE.md`
- `openclaw20260323/DEPLOY.md`

如果需要导出 v2026.3.23 镜像，先进入：

```bash
cd openclaw20260323
./export-image.sh
```

然后再结合 `github-deploy/` 中的部署文件上传到服务器。

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
