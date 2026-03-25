#!/bin/bash
# 导出 OpenClaw 镜像用于上传到云服务器

set -e

echo "📦 导出 OpenClaw v2026.3.23 镜像..."
echo ""

# 检查镜像是否存在
if ! docker image inspect openclaw:v2026.3.23 &> /dev/null; then
    echo "❌ 镜像 openclaw:v2026.3.23 不存在"
    echo "请先构建镜像:"
    echo "  docker build -t openclaw:v2026.3.23 ."
    exit 1
fi

# 导出镜像
echo "正在导出镜像（可能需要几分钟）..."
docker save openclaw:v2026.3.23 | gzip > openclaw-v2026.3.23.tar.gz

echo ""
echo "✅ 导出完成！"
echo ""
echo "文件信息："
ls -lh openclaw-v2026.3.23.tar.gz

echo ""
echo "📤 上传到云服务器的命令："
echo "  scp openclaw-v2026.3.23.tar.gz root@你的服务器IP:/root/"
echo ""
echo "📝 在服务器上导入："
echo "  gunzip -c openclaw-v2026.3.23.tar.gz | docker load"
echo ""
