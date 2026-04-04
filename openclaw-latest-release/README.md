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
docker compose --env-file build-info.env up -d
```

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

### 常见问题

- 宿主机无法访问服务：先确认 `docker-compose.prod.yml` 已暴露 `18889`，再检查系统防火墙。
- 容器无法解析宿主机：优先确认 Docker 版本是否支持 `host-gateway`，不行就设置 `HOST_IP`。
- 想临时收紧访问范围：把 `OPENCLAW_BIND` 改成 `loopback`，再重启容器。

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
