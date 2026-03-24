# OpenClaw Minimax Docker

这是一个基于 Docker 的 OpenClaw 部署目录，已完成以下功能验证：

- MiniMax 模型接入：`MiniMax-M2.7-highspeed`
- 飞书私聊回复
- 自动启动浏览器并打开网页
- 中文字体支持
- SSH 使用说明

## 目录说明

- `openclaw-minimax-docker/`：OpenClaw Docker 运行目录
- `openclaw-minimax-docker/交付文档.md`：当前交付总结与下一步计划
- `openclaw-minimax-docker/ssh-usage-guide.md`：容器里使用 SSH 的说明

## 启动方式

进入目录后执行：

```bash
docker compose up -d --build
```

浏览器和飞书功能会随容器一起启动。

## 主要配置

- `.env`：存放 MiniMax、飞书和 OpenClaw Token
- `docker-compose.yml`：容器编排
- `Dockerfile`：补齐 SSH、Chromium 和中文字体
- `openclaw_data/openclaw.json`：OpenClaw 配置

## SSH 访问说明

如果要让容器通过 SSH 访问别的电脑，先看：

`openclaw-minimax-docker/ssh-usage-guide.md`

核心原则：

- `ssh-keygen` 在发起连接的一侧执行
- 公钥放到被访问电脑的 `~/.ssh/authorized_keys`
- 私钥留在发起侧，不要放进镜像

## 当前状态

这套环境已完成功能测试，可以正常使用。

## 下一步计划：安全收紧

建议后续依次收紧：

1. 关闭不必要的危险控制台开关
2. 收紧浏览器 SSRF 和私网访问策略
3. 将飞书通道从开放模式改为白名单
4. 清理不再使用的旧 profile 和残留配置
5. 优化 SSH 私钥保存方式

## 备注

如果后续要对外开放，请先补充正式认证和访问控制，再放开网络入口。
