#!/bin/bash
# OpenClaw v2026.3.23 构建脚本

set -e

echo "🦞 开始构建 OpenClaw v2026.3.23..."
echo ""

# 检查 Docker
docker --version >/dev/null 2>&1 || { echo "❌ Docker 未安装"; exit 1; }

# 清理旧镜像（可选）
if [ "$1" == "--clean" ]; then
    echo "🧹 清理旧镜像..."
    docker rmi openclaw:v2026.3.23 2>/dev/null || true
fi

# 构建镜像
echo "🔨 构建 Docker 镜像..."
echo "这可能需要 10-30 分钟，取决于网络速度和机器性能..."
echo ""

docker build \
    --build-arg OPENCLAW_VERSION=v2026.3.23 \
    --build-arg OPENCLAW_INSTALL_BROWSER=1 \
    -t openclaw:v2026.3.23 \
    .

echo ""
echo "✅ 构建完成！"
echo ""
echo "镜像信息:"
docker images openclaw:v2026.3.23 --format "  名称: {{.Repository}}:{{.Tag}}\n  大小: {{.Size}}\n  创建: {{.CreatedAt}}"
echo ""
echo "启动命令:"
echo "  docker compose up -d"
