# OpenClaw v2026.3.23 独立测试环境

## 目录说明

这个目录是完全独立的 OpenClaw 测试环境，与 `openclaw-minimax-docker` 互不干扰：
- 独立的端口（18889/18890/19222）
- 独立的容器名称
- 独立的 Docker 卷
- 使用 OpenClaw v2026.3.23 版本

## 快速开始

1. 复制环境变量模板：
   ```bash
   cp .env.example .env
   ```

2. 编辑 `.env`，填入你的配置

3. 启动服务：
   ```bash
   docker compose up -d --build
   ```

4. 访问 Control UI：
   ```
   http://localhost:18889/#token=你的OPENCLAW_GATEWAY_TOKEN
   ```

## 与主环境的区别

| 项目 | 主环境 (openclaw-minimax-docker) | 测试环境 (openclaw20260323) |
|------|----------------------------------|----------------------------|
| 端口 | 18789/18790/9222 | 18889/18890/19222 |
| 容器名 | openclaw-main | openclaw-test |
| 版本 | v2026.3.12 | v2026.3.23 |
| 数据目录 | ./openclaw_data | ./openclaw_data |

## 停止并清理

```bash
# 停止服务
docker compose down

# 完全清理（包括数据卷）
docker compose down -v
```

## 版本测试说明

这个环境专门用于测试 OpenClaw v2026.3.23 的新功能和修复：
- 新的 Qwen DashScope endpoint
- UI 改进
- 大量 bug 修复

测试完成后，可以决定是否将主环境升级到此版本。
