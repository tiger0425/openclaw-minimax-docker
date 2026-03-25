# OpenClaw v2026.3.23 云服务器部署包说明

这个目录用于存放 **云服务器部署所需的脚本、配置和说明文件**，配合阿里云容器镜像服务快速部署。

## 镜像来源

镜像已上传到阿里云容器镜像服务 ACR（深圳节点）：

```
registry.cn-shenzhen.aliyuncs.com/yihuzh/openclaw:v2026.3.23
```

**优势：**
- ✅ 国内访问速度快
- ✅ 无需手动导入 1.5GB 镜像文件
- ✅ 自动拉取，一键部署

## 这个目录的用途

适用场景：
- 将 OpenClaw v2026.3.23 部署到云服务器
- 面向飞书 WebSocket 模式运行
- 将部署包交给其他人按文档执行

## 目录内容

当前目录包含：

- `.env.example`：环境变量模板
- `.gitignore`：忽略规则
- `docker-compose.yml`：服务器部署编排文件
- `deploy.sh`：部署脚本（自动拉取镜像）
- `openclaw.json`：OpenClaw 配置模板
- `README.md`：快速部署说明
- `DEPLOY-GUIDE.md`：完整部署指南

## 快速部署流程

### 第一步：上传部署文件到服务器

```bash
scp -r github-deploy root@你的服务器IP:/root/openclaw-deploy
```

或者只上传必要文件：

```bash
scp -r github-deploy/.env.example github-deploy/docker-compose.yml github-deploy/deploy.sh github-deploy/openclaw.json root@你的服务器IP:/root/openclaw-deploy/
```

### 第二步：在服务器上部署

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

然后直接运行部署脚本：

```bash
chmod +x deploy.sh
./deploy.sh
```

脚本会自动：
1. 检查 Docker 环境
2. 检查配置
3. **从阿里云拉取镜像**（如果本地不存在）
4. 启动服务

### 第三步：验证部署

```bash
docker ps
docker logs -f openclaw-gateway
```

正常情况下应看到：
- 容器已启动
- 飞书 WebSocket 已连接

## 手动拉取镜像（可选）

如果想先单独拉取镜像：

```bash
docker pull registry.cn-shenzhen.aliyuncs.com/yihuzh/openclaw:v2026.3.23
```

使用 `latest` 标签获取最新版本：

```bash
docker pull registry.cn-shenzhen.aliyuncs.com/yihuzh/openclaw:latest
```

## 最小必备文件

服务器上至少需要这些文件：

```text
openclaw-deploy/
├── .env
├── docker-compose.yml
├── deploy.sh
└── openclaw.json
```

**注意：** 镜像不再需要手动上传，会自动从阿里云拉取。

## 镜像版本说明

| 标签 | 说明 |
|------|------|
| `v2026.3.23` | 固定版本，推荐生产环境使用 |
| `latest` | 最新版本，自动更新 |

如需使用特定版本，修改 `docker-compose.yml` 中的镜像标签：

```yaml
services:
  openclaw-gateway:
    image: registry.cn-shenzhen.aliyuncs.com/yihuzh/openclaw:v2026.3.23
    # 或
    # image: registry.cn-shenzhen.aliyuncs.com/yihuzh/openclaw:latest
```

## 安全说明

- 当前配置默认**不暴露公网端口**
- 飞书通过 WebSocket 主动连接服务
- 真实 `.env` 不要提交到仓库
- 私钥、运行数据目录不要提交到仓库

## 文档分工

- `README.md`：快速部署指南（本文档）
- `DEPLOY-GUIDE.md`：完整部署、排障和详细说明

如需更详细的部署过程、故障排查，请查看 `DEPLOY-GUIDE.md`。
