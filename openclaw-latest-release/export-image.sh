#!/bin/bash
# 导出最新 release 的 OpenClaw 镜像

set -euo pipefail

BUILD_INFO_FILE="build-info.env"

if [ ! -f "$BUILD_INFO_FILE" ]; then
    echo "❌ 未找到 ${BUILD_INFO_FILE}"
    echo "请先运行 ./build.sh"
    exit 1
fi

# shellcheck disable=SC1090
source "$BUILD_INFO_FILE"

if [ -z "${OPENCLAW_VERSION:-}" ] || [ -z "${IMAGE_NAME:-}" ]; then
    echo "❌ 构建信息不完整"
    exit 1
fi

TARBALL="openclaw-${OPENCLAW_VERSION}.tar.gz"

echo "📦 导出 OpenClaw ${OPENCLAW_VERSION} 镜像..."
echo "镜像: ${IMAGE_NAME}"
echo "输出: ${TARBALL}"
echo ""

if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo "❌ 镜像 ${IMAGE_NAME} 不存在"
    echo "请先运行 ./build.sh"
    exit 1
fi

echo "正在导出镜像（可能需要几分钟）..."
docker save "$IMAGE_NAME" | gzip > "$TARBALL"

echo ""
echo "✅ 导出完成！"
echo ""
echo "文件信息："
ls -lh "$TARBALL"
echo ""
echo "📤 上传到云服务器的命令："
echo "  scp ${TARBALL} root@你的服务器IP:/root/"
echo ""
echo "📝 在服务器上导入："
echo "  gunzip -c ${TARBALL} | docker load"
echo ""
