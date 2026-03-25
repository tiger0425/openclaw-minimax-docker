#!/bin/bash
# OpenClaw v2026.3.23 生产环境部署脚本（飞书专用）
# 使用方法：./deploy.sh

set -e

echo "🦞 OpenClaw v2026.3.23 生产环境部署（飞书专用）"
echo "================================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否 root
if [ "$EUID" -eq 0 ]; then 
   echo -e "${RED}❌ 请不要以 root 用户运行此脚本${NC}"
   exit 1
fi

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker 未安装${NC}"
    echo "请安装 Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker 环境检查通过${NC}"
echo ""

# 检查 .env 文件
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  .env 文件不存在，创建模板...${NC}"
    
    # 生成强 Token
    STRONG_TOKEN=$(openssl rand -hex 32)
    
    cat > .env << EOF
# OpenClaw 生产环境配置
# 生成时间: $(date)

# ✅ 强 Token（已自动生成）
OPENCLAW_GATEWAY_TOKEN=${STRONG_TOKEN}

# 飞书应用配置（必需）
LARK_APP_ID=cli_xxxxx
LARK_APP_SECRET=xxxxx

# MiniMax API Key（可选）
MINIMAX_API_KEY=

# 其他模型 API Key（可选）
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
EOF
    
    echo -e "${RED}⚠️  请编辑 .env 文件，填入你的飞书 App ID 和 Secret${NC}"
    echo ""
    echo "步骤："
    echo "  1. vim .env"
    echo "  2. 修改 LARK_APP_ID 和 LARK_APP_SECRET"
    echo "  3. 保存后重新运行此脚本"
    echo ""
    exit 1
fi

# 检查关键配置
if ! grep -q "LARK_APP_ID=" .env || grep -q "LARK_APP_ID=cli_xxxxx" .env; then
    echo -e "${RED}❌ 请配置 LARK_APP_ID${NC}"
    exit 1
fi

if ! grep -q "LARK_APP_SECRET=" .env || grep -q "LARK_APP_SECRET=xxxxx" .env; then
    echo -e "${RED}❌ 请配置 LARK_APP_SECRET${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 配置检查通过${NC}"
echo ""

# 创建数据目录
echo "📁 创建数据目录..."
mkdir -p openclaw_data
chmod 755 openclaw_data

# 复制配置文件（如果不存在）
if [ ! -f openclaw_data/openclaw.json ]; then
    echo "📄 复制 OpenClaw 配置文件..."
    cp openclaw.json openclaw_data/
    echo -e "${GREEN}✅ 配置文件已复制${NC}"
else
    echo -e "${YELLOW}⚠️  openclaw.json 已存在，跳过复制${NC}"
    echo "   如需更新配置，请手动替换 openclaw_data/openclaw.json"
fi
echo ""

# 检查镜像是否存在
if ! docker image inspect openclaw:v2026.3.23 &> /dev/null; then
    echo -e "${YELLOW}⚠️  镜像 openclaw:v2026.3.23 不存在${NC}"
    echo "请在本地构建后上传，或从其他服务器导入："
    echo "  docker save openclaw:v2026.3.23 | gzip > openclaw-v2026.3.23.tar.gz"
    echo "  # 上传到服务器后"
    echo "  gunzip -c openclaw-v2026.3.23.tar.gz | docker load"
    exit 1
fi

echo -e "${GREEN}✅ 镜像已存在${NC}"
echo ""

# 停止旧容器（如果存在）
echo "🛑 停止旧容器（如果存在）..."
docker-compose down 2>/dev/null || true

# 启动服务
echo "🚀 启动 OpenClaw 服务..."
docker-compose up -d

echo ""
echo "⏳ 等待服务启动..."
sleep 5

# 检查健康状态
echo ""
echo "🔍 检查服务状态..."
if docker ps | grep -q "openclaw-gateway"; then
    echo -e "${GREEN}✅ 容器运行正常${NC}"
else
    echo -e "${RED}❌ 容器启动失败${NC}"
    docker logs openclaw-gateway 2>&1 | tail -20
    exit 1
fi

# 检查飞书连接
echo ""
echo "🔍 检查飞书连接..."
sleep 3
if docker logs openclaw-gateway 2>&1 | grep -q "feishu\[default\]: WebSocket client started"; then
    echo -e "${GREEN}✅ 飞书 WebSocket 已连接${NC}"
else
    echo -e "${YELLOW}⚠️  飞书连接可能需要更长时间，请稍后检查日志${NC}"
fi

echo ""
echo "================================================"
echo -e "${GREEN}🎉 部署完成！${NC}"
echo "================================================"
echo ""
echo "📊 服务状态："
docker-compose ps

echo ""
echo "📝 常用命令："
echo "  查看日志:    docker logs -f openclaw-gateway"
echo "  重启服务:    docker-compose restart"
echo "  停止服务:    docker-compose down"
echo "  进入容器:    docker exec -it openclaw-gateway sh"
echo ""
echo "🔒 安全提示："
echo "  - 未暴露公网端口，仅飞书可访问"
echo "  - 如需管理，请使用 SSH 隧道:"
echo "    ssh -L 18889:localhost:18889 你的服务器IP"
echo "    然后访问 http://localhost:18889"
echo ""
