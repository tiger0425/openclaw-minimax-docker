#!/bin/bash
# 将本地构建的 OpenClaw 镜像推送到阿里云 ACR

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
    echo "❌ ${BUILD_INFO_FILE} 内容不完整"
    exit 1
fi

ACR_REGISTRY="${ACR_REGISTRY:-registry.cn-shenzhen.aliyuncs.com}"
ACR_NAMESPACE="${ACR_NAMESPACE:-yihuzh}"
ACR_REPOSITORY="${ACR_REPOSITORY:-openclaw}"
ACR_USERNAME="${ACR_USERNAME:-}"
ACR_PASSWORD="${ACR_PASSWORD:-}"

REMOTE_IMAGE_BASE="${ACR_REGISTRY}/${ACR_NAMESPACE}/${ACR_REPOSITORY}"
REMOTE_VERSION_IMAGE="${REMOTE_IMAGE_BASE}:${OPENCLAW_VERSION}"
REMOTE_LATEST_IMAGE="${REMOTE_IMAGE_BASE}:latest"

login_if_needed() {
    if [ -n "$ACR_USERNAME" ] && [ -n "$ACR_PASSWORD" ]; then
        echo "🔐 使用环境变量登录阿里云 ACR: ${ACR_REGISTRY}"
        printf '%s' "$ACR_PASSWORD" | docker login "$ACR_REGISTRY" --username "$ACR_USERNAME" --password-stdin
        return
    fi

    echo "🔐 未提供 ACR_USERNAME/ACR_PASSWORD，尝试复用本机已有 Docker 登录态"
    if [ -f "$HOME/.docker/config.json" ] || [ -f "${USERPROFILE:-}/.docker/config.json" ]; then
        echo "   已检测到 Docker 配置文件，将直接尝试 push"
    else
        echo "   未检测到 Docker 配置文件，将直接尝试 push"
    fi
}

push_or_fail() {
    local image="$1"
    local label="$2"

    echo "📤 推送${label}: ${image}"
    if docker push "$image"; then
        return
    fi

    echo "❌ 推送失败：${image}"
    echo "如果你尚未登录阿里云 ACR，请执行："
    echo "  export ACR_USERNAME=your-aliyun-username"
    echo "  export ACR_PASSWORD=your-aliyun-password"
    echo "  docker login ${ACR_REGISTRY}"
    exit 1
}

docker --version >/dev/null 2>&1 || { echo "❌ Docker 未安装"; exit 1; }

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "❌ 本地镜像 ${IMAGE_NAME} 不存在"
    echo "请先运行 ./build.sh"
    exit 1
fi

login_if_needed

echo "🏷️  打标签..."
docker tag "$IMAGE_NAME" "$REMOTE_VERSION_IMAGE"
docker tag "$IMAGE_NAME" "$REMOTE_LATEST_IMAGE"

push_or_fail "$REMOTE_VERSION_IMAGE" "版本镜像"
push_or_fail "$REMOTE_LATEST_IMAGE" "latest 镜像"

cat > "$BUILD_INFO_FILE" <<EOF
OPENCLAW_VERSION=${OPENCLAW_VERSION}
IMAGE_NAME=${IMAGE_NAME}
OPENCLAW_IMAGE_NAME=${IMAGE_NAME}
REPO=${REPO}
ACR_REGISTRY=${ACR_REGISTRY}
ACR_NAMESPACE=${ACR_NAMESPACE}
ACR_REPOSITORY=${ACR_REPOSITORY}
ACR_VERSION_IMAGE=${REMOTE_VERSION_IMAGE}
ACR_LATEST_IMAGE=${REMOTE_LATEST_IMAGE}
EOF

echo ""
echo "✅ 推送完成"
echo "版本镜像: ${REMOTE_VERSION_IMAGE}"
echo "最新镜像: ${REMOTE_LATEST_IMAGE}"
