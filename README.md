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
旧的独立测试环境目录，**已归档**，保留作历史参考。

### `github-deploy/`
旧的云服务器部署包目录，**已弃用**，保留仅作历史参考。

## 如何选择

### 1. 继续使用当前主环境
进入：

```bash
cd openclaw-minimax-docker
```

然后按目录内现有配置运行。

### 2. 旧测试环境（归档）
如果你需要查看历史测试环境，可进入：

```bash
cd openclaw20260323
cp .env.example .env
docker compose up -d --build
```

历史说明见 `openclaw20260323/README.md`。

### 3. 部署到云服务器（推荐）
使用阿里云容器镜像服务，国内访问速度快，无需上传大文件。

**快速部署：**

```bash
# 1. 在服务器上克隆独立部署仓库
git clone https://github.com/tiger0425/github-deploy-latest.git /root/openclaw-deploy-latest

# 2. 在服务器上配置并启动
cd /root/openclaw-deploy-latest
cp .env.example .env
vim .env  # 填入配置
./deploy.sh  # 自动从阿里云拉取镜像并启动
```

**详细说明：**
- https://github.com/tiger0425/github-deploy-latest

**如需本地导出镜像（历史方案）：**
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
- 已归档的 v2026.3.23 测试环境
- 已弃用的旧部署包说明

如果下一步要继续推进，建议优先做：
1. 按文档完整跑一遍部署流程
2. 确认主环境与测试环境的升级关系
3. 根据实际上线要求继续收紧安全配置
