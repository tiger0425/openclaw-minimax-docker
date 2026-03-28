#!/bin/bash
# OpenClaw 最新 release 部署脚本

set -euo pipefail

BUILD_INFO_FILE="build-info.env"
COMPOSE_FILE="docker-compose.prod.yml"

if [ ! -f "$BUILD_INFO_FILE" ]; then
    echo "❌ 未找到 ${BUILD_INFO_FILE}"
    echo "请先在打包机器执行 ./build.sh，并把 ${BUILD_INFO_FILE} 一起带到部署目录"
    exit 1
fi

if [ ! -f .env ]; then
    echo "❌ 未找到 .env"
    echo "请先执行: cp .env.example .env"
    exit 1
fi

docker --version >/dev/null 2>&1 || { echo "❌ Docker 未安装"; exit 1; }
if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
    echo "❌ Docker Compose 未安装"
    exit 1
fi

# shellcheck disable=SC1090
source "$BUILD_INFO_FILE"

if [ -z "${OPENCLAW_VERSION:-}" ] || [ -z "${IMAGE_NAME:-}" ]; then
    echo "❌ ${BUILD_INFO_FILE} 内容不完整"
    exit 1
fi

if ! grep -q '^OPENCLAW_GATEWAY_TOKEN=' .env; then
    echo "❌ .env 中缺少 OPENCLAW_GATEWAY_TOKEN"
    exit 1
fi

mkdir -p openclaw_data
mkdir -p openclaw_data/workspace
chmod 755 openclaw_data
chmod 755 openclaw_data/workspace

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "❌ 镜像 ${IMAGE_NAME} 不存在"
    echo "请先导入镜像，例如："
    echo "  gunzip -c openclaw-${OPENCLAW_VERSION}.tar.gz | docker load"
    exit 1
fi

export OPENCLAW_IMAGE_NAME="${OPENCLAW_IMAGE_NAME:-$IMAGE_NAME}"

echo "🦞 部署 OpenClaw ${OPENCLAW_VERSION}"
echo "镜像: ${OPENCLAW_IMAGE_NAME}"
echo ""

if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose -f "$COMPOSE_FILE")
else
    COMPOSE_CMD=(docker compose -f "$COMPOSE_FILE")
fi

"${COMPOSE_CMD[@]}" down 2>/dev/null || true
"${COMPOSE_CMD[@]}" up -d

echo ""
echo "✅ 部署完成"
echo "查看状态: ${COMPOSE_CMD[*]} ps"
echo "查看日志: docker logs -f openclaw-latest-prod-gateway"
