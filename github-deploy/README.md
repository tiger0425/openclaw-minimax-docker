# OpenClaw v2026.3.23 云服务器部署包说明

这个目录用于存放 **云服务器部署所需的脚本、配置和说明文件**，适合配合 `openclaw20260323/` 导出的镜像一起交付或上传到服务器。

## 这个目录的用途

适用场景：
- 将 OpenClaw v2026.3.23 部署到云服务器
- 面向飞书 WebSocket 模式运行
- 将部署包交给其他人按文档执行

这个目录本身**不包含 Docker 镜像压缩包**，镜像文件需要从 `openclaw20260323/` 目录单独导出。

## 目录内容

当前目录包含：

- `.env.example`：环境变量模板
- `.gitignore`：忽略规则
- `docker-compose.yml`：服务器部署编排文件
- `deploy.sh`：部署脚本
- `export-image.sh`：镜像导出脚本（如在本目录维护镜像导出流程时使用）
- `openclaw.json`：OpenClaw 配置模板
- `README.md`：快速部署说明
- `DEPLOY-GUIDE.md`：完整部署指南

## 部署前需要准备什么

### 1. 本目录中的部署文件
也就是当前 `github-deploy/` 目录里的文件。

### 2. OpenClaw v2026.3.23 镜像压缩包
当前推荐先在 `openclaw20260323/` 目录中生成，与测试环境目录保持一致：

```bash
cd openclaw20260323
./export-image.sh
```

生成文件示例：

```bash
openclaw-v2026.3.23.tar.gz
```

## 快速部署流程

### 第一步：准备本地文件

在仓库根目录执行：

```bash
cd openclaw20260323
./export-image.sh
```

然后确认以下两部分内容都已准备好：

1. `github-deploy/` 目录
2. `openclaw-v2026.3.23.tar.gz` 镜像文件

### 第二步：上传到服务器

可将部署目录和镜像上传到服务器，例如：

```bash
scp -r github-deploy root@你的服务器IP:/root/openclaw-deploy
scp openclaw20260323/openclaw-v2026.3.23.tar.gz root@你的服务器IP:/root/openclaw-deploy/
```

### 第三步：在服务器上部署

登录服务器后执行：

```bash
cd /root/openclaw-deploy
cp .env.example .env
vim .env
```

至少需要填写：

- `OPENCLAW_GATEWAY_TOKEN`
- `LARK_APP_ID`
- `LARK_APP_SECRET`
- `MINIMAX_API_KEY`（如使用 MiniMax）

然后导入镜像并启动：

```bash
gunzip -c openclaw-v2026.3.23.tar.gz | docker load
chmod +x deploy.sh
./deploy.sh
```

## 最小必备文件

如果只按最精简方式部署，服务器上至少需要这些文件：

```text
openclaw-deploy/
├── .env.example
├── docker-compose.yml
├── deploy.sh
├── openclaw.json
└── openclaw-v2026.3.23.tar.gz
```

## 部署完成后如何验证

在服务器上执行：

```bash
docker ps
docker logs -f openclaw-gateway
```

正常情况下应看到：
- 容器已启动
- 飞书 WebSocket 已连接

## 安全说明

- 当前配置默认**不暴露公网端口**
- 飞书通过 WebSocket 主动连接服务
- 真实 `.env` 不要提交到仓库
- 私钥、运行数据目录、镜像压缩包不要提交到仓库

## 文档分工

- `README.md`：适合快速查看和直接执行
- `DEPLOY-GUIDE.md`：适合完整交付、排障和详细部署说明

如果你需要更完整的部署过程、故障排查和服务器操作说明，请继续看：

- `DEPLOY-GUIDE.md`
- `../openclaw20260323/DEPLOY.md`
