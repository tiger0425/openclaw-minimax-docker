#!/bin/bash
# OpenClaw 镜像上传到阿里云容器镜像服务 (ACR)
# 使用前请先替换下面的变量

# ============================================
# 配置信息（请修改）
# ============================================

# 阿里云账号信息
ALIYUN_REGISTRY="registry.cn-hangzhou.aliyuncs.com"  # 根据你的地域修改
ALIYUN_NAMESPACE="your-namespace"                    # 你的命名空间
ALIYUN_REPO="openclaw"                               # 仓库名称
ALIYUN_TAG="v2026.3.23"                              # 镜像标签

# 镜像名称
LOCAL_IMAGE="openclaw:v2026.3.23"
REMOTE_IMAGE="${ALIYUN_REGISTRY}/${ALIYUN_NAMESPACE}/${ALIYUN_REPO}:${ALIYUN_TAG}"

echo "========================================"
echo "OpenClaw 镜像上传到阿里云"
echo "========================================"
echo ""

# ============================================
# 第一步：登录阿里云
# ============================================
echo "🔐 登录阿里云容器镜像服务..."
echo "提示：密码是阿里云账号的登录密码，或者容器镜像服务的独立密码"
echo ""
docker login ${ALIYUN_REGISTRY}

if [ $? -ne 0 ]; then
    echo "❌ 登录失败"
    exit 1
fi

echo "✅ 登录成功"
echo ""

# ============================================
# 第二步：标记镜像
# ============================================
echo "🏷️  标记镜像..."
echo "本地镜像: ${LOCAL_IMAGE}"
echo "远程镜像: ${REMOTE_IMAGE}"
docker tag ${LOCAL_IMAGE} ${REMOTE_IMAGE}

if [ $? -ne 0 ]; then
    echo "❌ 标记失败"
    exit 1
fi

echo "✅ 标记成功"
echo ""

# ============================================
# 第三步：推送镜像
# ============================================
echo "📤 推送镜像到阿里云..."
echo "这可能需要几分钟，取决于网络速度..."
docker push ${REMOTE_IMAGE}

if [ $? -ne 0 ]; then
    echo "❌ 推送失败"
    exit 1
fi

echo "✅ 推送成功"
echo ""

# ============================================
# 完成
# ============================================
echo "========================================"
echo "🎉 镜像上传完成！"
echo "========================================"
echo ""
echo "镜像地址: ${REMOTE_IMAGE}"
echo ""
echo "在服务器上拉取命令:"
echo "  docker pull ${REMOTE_IMAGE}"
echo ""

# 可选：登出
docker logout ${ALIYUN_REGISTRY}
