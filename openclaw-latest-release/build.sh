#!/bin/bash
# OpenClaw 最新 release 构建脚本

set -euo pipefail

REPO="openclaw/openclaw"
TARGET_VERSION="${1:-latest}"
BUILD_INFO_FILE="build-info.env"

if [ "${1:-}" = "--clean" ]; then
    TARGET_VERSION="${2:-latest}"
    CLEAN=true
else
    CLEAN=false
fi

resolve_latest_release() {
    if command -v gh >/dev/null 2>&1; then
        gh release view --repo "$REPO" --json tagName -q .tagName
        return
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo "❌ 缺少 gh 或 curl，无法解析 latest release"
        exit 1
    fi

    local response tag_name
    response=$(curl -fsSL -H "Accept: application/vnd.github+json" "https://api.github.com/repos/${REPO}/releases/latest")
    tag_name=$(printf '%s\n' "$response" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | cut -d'"' -f4)

    if [ -z "${tag_name:-}" ]; then
        echo "❌ 无法从 GitHub Releases 解析最新版本"
        exit 1
    fi

    printf '%s\n' "$tag_name"
}

validate_docker_tag() {
    local tag="$1"

    if [ -z "$tag" ]; then
        echo "❌ 版本号不能为空"
        exit 1
    fi

    if ! printf '%s' "$tag" | grep -Eq '^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$'; then
        echo "❌ 版本号 '${tag}' 不能直接作为 Docker tag 使用"
        echo "请使用仅包含字母、数字、下划线、点、中划线的 release tag"
        exit 1
    fi
}

if [ "$TARGET_VERSION" = "latest" ]; then
    OPENCLAW_VERSION="$(resolve_latest_release)"
else
    OPENCLAW_VERSION="$TARGET_VERSION"
fi

validate_docker_tag "$OPENCLAW_VERSION"

IMAGE_NAME="openclaw:${OPENCLAW_VERSION}"

echo "🦞 开始构建 OpenClaw ${OPENCLAW_VERSION}..."
echo "仓库: ${REPO}"
echo "镜像: ${IMAGE_NAME}"
echo ""

if [ "$CLEAN" = true ]; then
    echo "🧹 清理旧镜像..."
    docker rmi "$IMAGE_NAME" 2>/dev/null || true
fi

docker --version >/dev/null 2>&1 || { echo "❌ Docker 未安装"; exit 1; }

echo "🔨 构建 Docker 镜像..."
echo "这可能需要 10-30 分钟，取决于网络速度和机器性能..."
echo ""

docker build \
    --build-arg OPENCLAW_VERSION="$OPENCLAW_VERSION" \
    --build-arg OPENCLAW_INSTALL_BROWSER=1 \
    -t "$IMAGE_NAME" \
    .

cat > "$BUILD_INFO_FILE" <<EOF
OPENCLAW_VERSION=${OPENCLAW_VERSION}
IMAGE_NAME=${IMAGE_NAME}
OPENCLAW_IMAGE_NAME=${IMAGE_NAME}
REPO=${REPO}
EOF

echo ""
echo "✅ 构建完成！"
echo ""
echo "镜像信息:"
docker images "$IMAGE_NAME" --format "  名称: {{.Repository}}:{{.Tag}}\n  大小: {{.Size}}\n  创建: {{.CreatedAt}}"
echo ""
echo "已写入构建信息: ${BUILD_INFO_FILE}"
echo "导出命令:"
echo "  ./export-image.sh"
