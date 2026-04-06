# OpenClaw 最新 release 打包目录

这个目录是独立的打包包，不会修改 `openclaw20260323/`。

## 它做什么

- 默认解析 GitHub Releases 的最新正式版本
- 用该版本构建 OpenClaw 镜像
- 将实际解析到的版本写入 `build-info.env`
- 导出镜像时复用同一版本，避免前后不一致
- 补齐本地启动与服务器部署所需文件

## 使用方法

### 1. 构建最新 release

```bash
cd openclaw-latest-release
./build.sh
```

### 2. 导出镜像

```bash
./export-image.sh
```

### 2.1 推送到阿里云 ACR

```bash
export ACR_USERNAME=你的阿里云镜像仓库用户名
export ACR_PASSWORD=你的阿里云镜像仓库密码
./push-acr.sh
```

脚本会同时推送：

- `registry.cn-shenzhen.aliyuncs.com/yihuzh/openclaw:<实际版本>`
- `registry.cn-shenzhen.aliyuncs.com/yihuzh/openclaw:latest`

建议把具体版本 tag 作为生产部署主路径，`latest` 作为便捷验证路径。

### 3. 本地部署

```bash
cp .env.example .env
docker compose --env-file .env --env-file build-info.env up -d
```

这里同时传入 `.env` 和 `build-info.env`：前者承载网关令牌、PinchTab、OpenSpace、Qwen 等运行时配置，后者承载本次构建解析出的镜像版本信息。

### 4. 服务器部署

把这些文件一起带到服务器：

- `docker-compose.prod.yml`
- `deploy.sh`
- `openclaw.json`
- `.env.example`
- `build-info.env`
- `openclaw-<版本>.tar.gz`

服务器上执行：

```bash
cp .env.example .env
gunzip -c openclaw-<版本>.tar.gz | docker load
./deploy.sh
```

> 注意：如果目标机器是 `192.168.101.245`，实际应使用 `deploy-bundle/` 目录里的 `deploy.sh` 和 `docker-compose.yml` 作为唯一线上入口，不要改用本目录下的 `docker-compose.prod.yml`。后者适合源码侧部署，不适合当前这台已验证服务器的部署结构。

## 网络配置

生产 compose 默认使用 `OPENCLAW_BIND=lan`，并暴露以下端口：`18889`、`18890`、`19222`。

仓库自带 `openclaw.json`，其中已经开启 `gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback=true`，用于支持非 loopback 模式下的 Control UI 启动。

如果你需要收回到更保守的本机监听模式，可以在 `.env` 中改成：

```bash
OPENCLAW_BIND=loopback
```

### PinchTab 集成示例

现在 compose 会同时启动 `openclaw-gateway` 和 `pinchtab` 两个容器。`pinchtab` 服务默认直接拉取阿里云镜像 `registry.cn-shenzhen.aliyuncs.com/yihuzh/pinchtab:latest`，也可以通过 `.env` 里的 `PINCHTAB_IMAGE_NAME` 固定到具体版本，例如：

```bash
PINCHTAB_IMAGE_NAME=registry.cn-shenzhen.aliyuncs.com/yihuzh/pinchtab:v0.8.6
```

OpenClaw 默认通过服务名访问 PinchTab：

```bash
PINCHTAB_URL=http://pinchtab:9867
```

如果你要切回外部 PinchTab，也可以直接把地址改成宿主机或远端服务：

```bash
PINCHTAB_URL=http://192.168.101.245:9867
```

这套目录里的 compose 和 `openclaw.json` 现在已经默认启用 `pinchtab` 插件，并关闭旧的 `browser` 路径；如果 PinchTab 开了鉴权，把 `PINCHTAB_TOKEN` 一并写进 `.env`。

注意：虽然 PinchTab 容器已经改为直接拉取镜像，但 `openclaw-gateway` 仍会通过 `../pinchtab/plugin` 挂载本地插件源码并在启动时执行 `plugins install`，因此这个插件目录当前仍需保留。

### OpenSpace 自进化引擎集成

Compose 现在同时启动 `openclaw-gateway`、`pinchtab` 和 `openspace` 三个容器。OpenSpace 作为 MCP 服务器接入 OpenClaw 的 `mcporter` 运行时，让 agent 获得**技能自进化**和**云端技能共享**能力。

**启动流程**（自动完成，无需手动操作）：
1. 容器启动时自动安装 OpenSpace Python 包
2. 复制 `delegate-task` 和 `skill-discovery` 两个 host skill 到 OpenClaw 技能目录
3. 通过 `mcporter config add openspace` 注册 MCP 服务器
4. 启动 OpenClaw 网关

**环境变量**（在 `.env` 中配置）：

```bash
# OpenSpace 云端技能库 Key（可选，不填则仅使用本地技能）
OPENSPACE_API_KEY=sk-xxx

# 镜像地址（默认已指向阿里云 ACR）
OPENSPACE_IMAGE_NAME=registry.cn-shenzhen.aliyuncs.com/yihuzh/openspace:0.1.0
```

### Qwen 3.6 Plus（阿里百炼 / DashScope）接入

这套发布目录现在支持通过 OpenSpace 的 LiteLLM 配置把 `qwen3.6-plus` 接进 OpenClaw。最小配置方式是在 `.env` 中填写 OpenSpace 的 LLM 覆盖变量：

```bash
# 推荐：通过 DashScope OpenAI-compatible 接口使用 qwen3.6-plus
OPENSPACE_MODEL=openai/qwen3.6-plus
OPENSPACE_LLM_API_KEY=sk-xxx
OPENSPACE_LLM_API_BASE=https://dashscope.aliyuncs.com/compatible-mode/v1
```

说明：
- `openai/` 前缀是 LiteLLM 在自定义 OpenAI-compatible endpoint 下的保守写法；默认示例已按这个格式提供。
- 上面这个北京站点地址来自阿里百炼官方文档；如果你使用国际站或美国站，请把 `OPENSPACE_LLM_API_BASE` 改成对应区域的兼容接口地址。
- 这条路径下通常**不需要**再填写 `OPENAI_API_KEY`；直接把阿里百炼的 Key 写到 `OPENSPACE_LLM_API_KEY` 即可。
- 如果后续需要自定义请求头或 LiteLLM 参数，可以再补：`OPENSPACE_LLM_EXTRA_HEADERS`、`OPENSPACE_LLM_CONFIG`（都填 JSON 字符串）。

更新 `.env` 后，重新执行 `docker compose --env-file build-info.env up -d`，OpenClaw 在启动时会把这些变量一并透传给 OpenSpace MCP。

**集成效果**：
- OpenClaw agent 可自动搜索、复用和进化技能
- 成功的工作流会被捕获为可复用技能
- 失败的技能会自动修复（FIX / DERIVED / CAPTURED）
- 通过云端社区可共享和发现其他 agent 进化的技能

**前置条件**：
- 需要 `../openspace` 目录存在 OpenSpace 源码（用于启动时安装 Python 包）
- 如果不需要 OpenSpace 集成，可以注释掉 compose 中的 `openspace` 服务块

### 常见问题

- 宿主机无法访问服务：先确认 `docker-compose.prod.yml` 已暴露 `18889`，再检查系统防火墙。
- 容器无法解析宿主机：优先确认 Docker 版本是否支持 `host-gateway`，不行就设置 `HOST_IP`。
- 想临时收紧访问范围：把 `OPENCLAW_BIND` 改成 `loopback`，再重启容器。

## 部署问题速记

这套目录在真实服务器部署时踩过的坑，已经在 `deploy-bundle/README.md` 里整理成完整排障清单。这里先记最关键的几条：

- **服务器优先用 `docker compose` 插件版**：旧的 `docker-compose` Python 入口在某些机器上会因为缺少 `distutils` 直接失败。
- **不要用精简版 `openclaw.json` 覆盖线上根配置**：根目录 `openclaw.json` 是网关真正 bind mount 进去的配置，里面必须保留 `models`、`channels.feishu`、`plugins` 等完整段。
- **PinchTab 相关问题通常集中在三处**：插件是否被安全扫描拦截、`PINCHTAB_TOKEN` 是否一致、目标域名是否在 PinchTab 的 `security.idpi.allowedDomains` 里。
- **如果 PinchTab 容器反复重启**：先检查 `/data/.config/pinchtab/config.json` 是否被写成带 BOM 的 UTF-8；PinchTab 读取 BOM JSON 会直接报 `invalid character 'ï'`。

### 5. 生成的文件

- `build-info.env`：本次构建解析到的版本
- `openclaw-<版本>.tar.gz`：导出的镜像包
- `ACR_VERSION_IMAGE` / `ACR_LATEST_IMAGE`：推送到阿里云后的镜像地址（执行 `push-acr.sh` 后写入）

## 版本来源

这里的“最新版”指 GitHub Releases 的 `latest` release，不是 `main` 分支 HEAD。

## 依赖

- Docker
- `curl` 或 `gh`
- 阿里云 ACR 账号与密码（推送镜像时）

## 快速校验

```bash
./build.sh
docker inspect --format='{{index .Config.Labels "org.opencontainers.image.version"}}' openclaw:<版本>
./export-image.sh
```

## 说明

- 如果你传入 `--clean`，会先删除对应镜像再构建
- 如果需要构建指定版本，也可以直接传 tag，例如 `./build.sh v2026.3.23`
- 本地 compose 和生产 compose 都通过 `OPENCLAW_IMAGE_NAME` 读取实际镜像名，不依赖硬编码版本
