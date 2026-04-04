# OpenClaw 远程部署包

这个目录包含在另一台服务器上部署 OpenClaw + PinchTab + OpenSpace 所需的全部文件。

## 目录结构

```
deploy-bundle/
├── docker-compose.yml          # 生产环境配置（从 ACR 拉取镜像）
├── deploy.sh                   # 一键部署脚本
├── .env                        # 环境变量配置（需编辑）
├── openclaw.json               # OpenClaw 网关配置
├── build-info.env              # 构建信息
├── pinchtab-plugin/            # PinchTab OpenClaw 插件
└── openspace-host-skills/      # OpenSpace 宿主技能
```

## 部署步骤

### 1. 传输到目标服务器

把整个 `deploy-bundle` 目录复制到目标服务器：

```bash
# 方法 1: scp
scp -r deploy-bundle/ user@目标服务器:/path/to/

# 方法 2: rsync
rsync -avz deploy-bundle/ user@目标服务器:/path/to/deploy-bundle/
```

### 2. 登录目标服务器并配置

```bash
ssh user@目标服务器
cd /path/to/deploy-bundle

# 编辑 .env，填入必要配置
nano .env
```

**必须配置的变量**：

```bash
OPENCLAW_GATEWAY_TOKEN=生成一个强随机令牌
```

**可选配置**：

```bash
# OpenSpace 云端技能库（可选，不填则仅使用本地技能）
OPENSPACE_API_KEY=sk-xxx

# 让 OpenClaw 通过 OpenSpace 使用阿里百炼 qwen3.6-plus
OPENSPACE_MODEL=openai/qwen3.6-plus
OPENSPACE_LLM_API_KEY=sk-xxx
OPENSPACE_LLM_API_BASE=https://dashscope.aliyuncs.com/compatible-mode/v1

# 如果需要指定具体版本而非 latest
PINCHTAB_IMAGE_NAME=registry.cn-shenzhen.aliyuncs.com/yihuzh/pinchtab:v0.8.6
OPENSPACE_IMAGE_NAME=registry.cn-shenzhen.aliyuncs.com/yihuzh/openspace:0.1.0
```

说明：
- `openai/qwen3.6-plus` 是 LiteLLM 在自定义 OpenAI-compatible endpoint 下更稳妥的模型写法。
- 上面的 `OPENSPACE_LLM_API_BASE` 默认指向阿里百炼北京站兼容接口；如果你使用国际站或美国站，请改成对应区域地址。
- 这条接法下通常不需要再填 `OPENAI_API_KEY`；把阿里百炼的 Key 写入 `OPENSPACE_LLM_API_KEY` 即可。
- 若要追加自定义请求头或 LiteLLM 参数，可继续在 `.env` 中补 `OPENSPACE_LLM_EXTRA_HEADERS`、`OPENSPACE_LLM_CONFIG`。

### 3. 执行部署

```bash
chmod +x deploy.sh
./deploy.sh
```

脚本会自动：
1. 检查前置条件（Docker、.env、必要目录）
2. 从阿里云 ACR 拉取最新镜像
3. 启动所有服务

### 4. 验证部署

```bash
# 查看服务状态
docker compose ps

# 查看 OpenClaw 日志
docker logs -f openclaw-gateway

# 查看 PinchTab 日志
docker logs -f openclaw-pinchtab

# 查看 OpenSpace 日志
docker logs -f openclaw-openspace
```

## 服务说明

| 服务 | 容器名 | 端口 | 说明 |
|------|--------|------|------|
| OpenClaw Gateway | openclaw-gateway | 18889, 18890, 19222 | AI 网关 |
| PinchTab | openclaw-pinchtab | 9867 | 浏览器自动化 |
| OpenSpace | openclaw-openspace | - | AI 自进化引擎（MCP） |

## 访问地址

- **OpenClaw Control UI**: `http://<服务器IP>:18889`
- **PinchTab API**: `http://<服务器IP>:9867`

## 更新服务

```bash
cd /path/to/deploy-bundle

# 拉取最新镜像
docker compose pull

# 重启服务
docker compose up -d
```

## 常见问题

### 镜像拉取失败

```bash
# 手动登录阿里云 ACR
docker login registry.cn-shenzhen.aliyuncs.com

# 然后重新部署
./deploy.sh
```

### 端口被占用

编辑 `docker-compose.yml`，修改 `ports` 映射：

```yaml
ports:
  - "18889:18889"  # 改为其他端口，如 "28889:18889"
```

### 不需要 OpenSpace

编辑 `docker-compose.yml`，注释掉 `openspace` 服务块和 `openclaw-gateway` 中对 `openspace` 的依赖。
