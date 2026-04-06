#!/bin/bash
# OpenClaw 远程部署脚本
# 所有镜像从阿里云 ACR 拉取，无需本地构建或导入镜像

set -euo pipefail

COMPOSE_FILE="docker-compose.yml"

echo "🦞 OpenClaw 远程部署"
echo "===================="
echo ""

# ── 检查前置条件 ─────────────────────────────────────────────
if [ ! -f .env ]; then
    echo "❌ 未找到 .env"
    echo "请先执行: cp .env.example .env"
    echo "然后编辑 .env 填入必要配置"
    exit 1
fi

if [ ! -f openclaw.json ]; then
    echo "❌ 未找到 openclaw.json"
    exit 1
fi

docker --version >/dev/null 2>&1 || { echo "❌ Docker 未安装"; exit 1; }
if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
    echo "❌ Docker Compose 未安装"
    exit 1
fi

# ── 检查必要目录 ─────────────────────────────────────────────
for dir in pinchtab-plugin openspace-host-skills; do
    if [ ! -d "$dir" ]; then
        echo "❌ 缺少必要目录: $dir"
        echo "请确认部署包完整"
        exit 1
    fi
done

# ── 检查环境变量 ─────────────────────────────────────────────
if ! grep -q '^OPENCLAW_GATEWAY_TOKEN=' .env; then
    echo "❌ .env 中缺少 OPENCLAW_GATEWAY_TOKEN"
    exit 1
fi

# ── 创建数据目录 ─────────────────────────────────────────────
mkdir -p openclaw_data
mkdir -p openclaw_data/workspace
chmod 755 openclaw_data
chmod 755 openclaw_data/workspace

# ── 拉取最新镜像 ─────────────────────────────────────────────
echo "📥 拉取最新镜像..."
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose -f "$COMPOSE_FILE")
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose -f "$COMPOSE_FILE")
else
    echo "❌ Docker Compose 未安装"
    exit 1
fi

"${COMPOSE_CMD[@]}" pull || {
    echo ""
    echo "⚠️  镜像拉取失败，请检查："
    echo "   1. 网络连接是否正常"
    echo "   2. 阿里云 ACR 是否需要登录（docker login registry.cn-shenzhen.aliyuncs.com）"
    echo "   3. .env 中的镜像地址是否正确"
    exit 1
}

# ── 启动服务 ─────────────────────────────────────────────────
echo ""
echo "🚀 启动服务..."
"${COMPOSE_CMD[@]}" down 2>/dev/null || true
"${COMPOSE_CMD[@]}" up -d

echo ""
echo "✅ 部署完成"
echo ""
echo "查看状态: ${COMPOSE_CMD[*]} ps"
echo "查看日志: docker logs -f openclaw-gateway"
echo ""
echo "服务端口:"
echo "  OpenClaw Gateway: http://<服务器IP>:18889"
echo "  PinchTab:         http://<服务器IP>:9867"
