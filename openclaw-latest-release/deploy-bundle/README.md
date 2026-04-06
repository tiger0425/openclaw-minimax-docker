# OpenClaw 远程部署包

这个目录包含在另一台服务器上部署 OpenClaw + PinchTab，并通过宿主机挂载的 OpenSpace venv 把 `openspace-mcp` 直接接入 Gateway 所需的全部文件。

## 目录结构

```
deploy-bundle/
├── docker-compose.yml          # 生产环境配置（从 ACR 拉取镜像）
├── deploy.sh                   # 一键部署脚本
├── .env                        # 环境变量配置（需编辑）
├── openclaw.json               # OpenClaw 网关配置
├── build-info.env              # 构建信息
├── pinchtab-plugin/            # PinchTab OpenClaw 插件
├── skill/                      # PinchTab agent skill（部署排障时可能会用到）
├── openspace-host-skills/      # OpenSpace 宿主技能
└── .venv-openspace/            # 需在宿主机准备的 OpenSpace Python venv（不随仓库提交）
```

## 部署步骤

## 当前生产部署约定（重要）

这套目录已经在 `192.168.101.245` 验证通过。后续所有会话都应默认遵守下面这套约定，不要再混用另一套 compose：

- **线上正确入口是 `deploy-bundle/` 这一套文件**
- **执行部署时使用 `deploy-bundle/deploy.sh` + `deploy-bundle/docker-compose.yml`**
- **不要在这台服务器上改用 `openclaw-latest-release/docker-compose.prod.yml`**

原因：

- `deploy-bundle/docker-compose.yml` 会挂载 `./pinchtab-plugin`、`./skill`、`./openspace-host-skills`
- `deploy-bundle/docker-compose.yml` 适配的是部署包目录本身，不依赖 `../pinchtab/plugin`、`../openspace` 这类源码相对路径
- `deploy-bundle/deploy.sh` 才是这台服务器的正确启动脚本

如果误用了 `docker-compose.prod.yml`，常见后果是：

- PinchTab skill 路径缺失
- 网关日志出现 `plugin skill path not found (pinchtab)`
- 飞书侧误报“PinchTab 连接不上”
- OpenSpace host skills 没有按部署包方式挂进去

当前这台服务器的已验证信息：

- 服务器：`192.168.101.245`
- 用户：`yihu`
- SSH key：`~/.ssh/openclaw_deploy`
- 部署目录：`/data/openclaw-deploy-latest`

### 标准操作

```bash
ssh -i ~/.ssh/openclaw_deploy yihu@192.168.101.245
cd /data/openclaw-deploy-latest
./deploy.sh
```

### 标准验证

```bash
docker compose -f docker-compose.yml ps
docker logs --tail 80 openclaw-gateway
docker logs --tail 80 openclaw-pinchtab
docker logs --tail 80 openclaw-openspace
```

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

### 2.1 在宿主机准备 OpenSpace venv

这套部署不再启动独立 `openclaw-openspace` 容器，而是让 `openclaw-gateway` 通过挂载宿主机 venv 直接执行 `openspace-mcp`。

必须先在部署目录准备：

```bash
cd /data/openclaw-deploy-latest

# 需要一个和 gateway 容器兼容的 Python 运行时
# 然后在部署目录创建 venv，并安装 openspace
./rebuild-openspace-venv.sh
```

要求：

- `.venv-openspace/bin/openspace-mcp` 必须存在且可执行
- `.venv-openspace/bin/python3` 不应是指向宿主机 `/usr/bin/python3.x` 的外部 symlink，推荐直接使用 `--copies`
- venv 的 Python 版本应与 `openclaw-gateway` 容器兼容
- 运行库目录 `.venv-openspace/lib/python3.12` 和 `libpython3.12.so.1.0` 也必须一并准备好

推荐直接使用仓库内脚本：

```bash
chmod +x rebuild-openspace-venv.sh
./rebuild-openspace-venv.sh
```

这会使用 `python:3.12-bookworm` 临时容器在当前部署目录中生成与 Gateway 挂载路径一致的 `.venv-openspace`，避免宿主机 Python 版本、`python3-venv` 缺失、以及 shebang 指向错误的问题。

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

# 验证 openspace-mcp 能在 gateway 容器里执行
docker exec openclaw-gateway /data/openclaw-deploy-latest/.venv-openspace/bin/openspace-mcp --help
```

## 服务说明

| 服务 | 容器名 | 端口 | 说明 |
|------|--------|------|------|
| OpenClaw Gateway | openclaw-gateway | 18889, 18890, 19222 | AI 网关 |
| PinchTab | openclaw-pinchtab | 9867 | 浏览器自动化 |
| OpenSpace MCP | 复用 openclaw-gateway 进程环境 | - | 通过宿主机 `.venv-openspace` 挂载进 Gateway |

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

### OpenSpace 挂载式部署的注意事项

- 当前 `deploy-bundle` **没有独立 `openspace` 容器**
- `openspace-mcp` 由 `openclaw-gateway` 通过挂载的 `.venv-openspace` 直接执行
- 如果 `openspace-mcp` 起不来，优先检查：
  - `.venv-openspace/bin/openspace-mcp` 是否存在
  - shebang / Python 小版本是否与 gateway 容器兼容
  - 挂载目录是否可读可执行

## 部署排障速查

下面这些问题都是真实部署 `OpenClaw + Feishu + PinchTab + OpenSpace` 时遇到过的，优先按“现象 → 处理”排查。

### 0. 宿主机 OpenSpace venv 不可用

**现象：**
- `deploy.sh` 提示找不到 `.venv-openspace/bin/openspace-mcp`
- 或 gateway 启动后 `mcporter` 注册成功，但实际调用失败

**处理：**
- 先在宿主机创建 `.venv-openspace`
- 确认 `openspace-mcp --help` 能执行
- 确认该 venv 使用的 Python 版本与 gateway 容器兼容
- 不要把一个与容器 Python 小版本不兼容的 venv 直接挂进去

### 1. 服务器上的 `docker-compose` 太旧

**现象：**
- `./deploy.sh` 能跑到 compose 阶段，但旧版 `docker-compose` Python 入口直接异常。
- 常见表现是缺少 Python 依赖，比如 `distutils`，导致服务根本起不来。

**处理：**
- 服务器优先使用 `docker compose` 插件版，不要依赖过旧的 `docker-compose`。
- 如果系统里同时存在两套命令，优先确认 `docker compose version` 可正常执行。

### 2. 飞书凭证或根配置不一致，导致飞书不回复

**现象：**
- 飞书机器人突然不回复。
- 日志里没有新的消息分发，或者网关启动后根本没有 `feishu[default]: WebSocket client started`。

**处理：**
- 先核对 `.env` 中的 `LARK_APP_ID`、`LARK_APP_SECRET` 是否是当前生效的一组。
- 再确认根目录 `openclaw.json` 里保留了完整的 `models`、`channels.feishu`、`gateway`、`plugins` 配置。
- **不要**用只包含 `plugins` / `agents` 的精简版 `openclaw.json` 直接覆盖线上根配置。

### 3. PinchTab 插件被安全扫描拦截

**现象：**
- 网关启动时插件安装失败，或者浏览器能力一直不可用。
- 日志可能出现插件安全扫描相关拦截提示。

**处理：**
- 避免在 PinchTab 插件里直接读取 `process.env` 这类容易被安全扫描判定为高风险的实现。
- 这套部署最终采用的是：让插件从 `openclaw.json` 读取 `baseUrl` / `token` / `timeout`，而不是从环境变量直接读。

### 4. `pinchtab` 插件已加载，但 agent 仍说“我没有这个能力”

**现象：**
- 飞书能回复，但一遇到“打开网页”“打开淘宝登录页”这类请求，就回“我没法控制浏览器”。
- 日志里看得到插件已加载，但模型仍然认为自己没有浏览器工具。

**处理：**
- 确认根目录 `openclaw.json` 中显式加入：

```json
{
  "agents": {
    "list": [
      {
        "id": "main",
        "tools": {
          "allow": ["pinchtab"]
        }
      }
    ]
  }
}
```

- 同时确认：
  - `plugins.allow` 包含 `pinchtab`
  - `plugins.entries.pinchtab.enabled` 为 `true`

### 5. PinchTab token 不一致，导致 401 unauthorized

**现象：**
- PinchTab 服务本身是健康的，但 OpenClaw 调用它时返回 401。
- 常见报错是 `bad_token` 或 `missing_token`。

**处理：**
- 确认这三处使用的是同一个 token：
  - `.env` 里的 `PINCHTAB_TOKEN`
  - PinchTab 自己的 `config.json`
  - `openclaw.json -> plugins.entries.pinchtab.config.token`
- 如果其中一处为空或旧值没更新，浏览器动作就会失败。

### 6. `login.taobao.com` 被 PinchTab 域名策略拦截

**现象：**
- 飞书回复明确提示：`login.taobao.com 不在允许打开的域名列表里`。
- 或者 PinchTab 日志里出现 `/navigate status=403`。

**处理：**
- 到 PinchTab 的 `config.json` 中检查：

```json
{
  "security": {
    "idpi": {
      "allowedDomains": [
        "login.taobao.com",
        "taobao.com",
        "www.taobao.com"
      ]
    }
  }
}
```

- 改完后重建 `openclaw-pinchtab`。

### 7. PinchTab `config.json` 被写成带 BOM 的 UTF-8，容器会反复重启

**现象：**
- `openclaw-pinchtab` 一直 restart。
- 日志报错：`failed to parse config: invalid character 'ï' looking for beginning of value`。

**处理：**
- 说明 `config.json` 文件头被写成了 UTF-8 BOM。
- 需要把 BOM 去掉，保存成**无 BOM** 的标准 UTF-8 JSON，再重启 PinchTab。

### 8. 关于外挂 PinchTab skill 的说明

**现象：**
- 日志里可能出现：`plugin skill path not found` 或 `plugin skill path escapes plugin root`。

**处理：**
- 这类外挂 skill 路径并不稳定，不要把它当成主要修复手段。
- 这次最终有效的做法是：
  - 保证 `pinchtab` 插件已正常 loaded
  - 显式给 `main` agent 加 `tools.allow: ["pinchtab"]`
  - 让 PinchTab 的 token 与域名策略配置正确
