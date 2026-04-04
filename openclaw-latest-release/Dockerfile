# OpenClaw 最新 release 构建脚本
# 基于官方仓库源码构建，添加了 SSH 和中文字体支持

# syntax=docker/dockerfile:1.7

ARG OPENCLAW_EXTENSIONS=""
ARG OPENCLAW_VARIANT=default
ARG OPENCLAW_DOCKER_APT_UPGRADE=1
ARG OPENCLAW_NODE_BOOKWORM_IMAGE="node:24-bookworm@sha256:3a09aa6354567619221ef6c45a5051b671f953f0a1924d1f819ffb236e520e6b"
ARG OPENCLAW_NODE_BOOKWORM_DIGEST="sha256:3a09aa6354567619221ef6c45a5051b671f953f0a1924d1f819ffb236e520e6b"

# ═══════════════════════════════════════════════════════════════
# Stage 1: 从 GitHub 克隆指定 release 的 OpenClaw 源码
# ═══════════════════════════════════════════════════════════════
FROM alpine/git:latest AS source
ARG OPENCLAW_VERSION
WORKDIR /source
RUN test -n "${OPENCLAW_VERSION}" && git clone --depth 1 --branch ${OPENCLAW_VERSION} https://github.com/openclaw/openclaw.git .

# ═══════════════════════════════════════════════════════════════
# Stage 2: 提取扩展依赖
# ═══════════════════════════════════════════════════════════════
FROM ${OPENCLAW_NODE_BOOKWORM_IMAGE} AS ext-deps
ARG OPENCLAW_EXTENSIONS
COPY --from=source /source/extensions /tmp/extensions
RUN mkdir -p /out && \
    for ext in $OPENCLAW_EXTENSIONS; do \
      if [ -f "/tmp/extensions/$ext/package.json" ]; then \
        mkdir -p "/out/$ext" && \
        cp "/tmp/extensions/$ext/package.json" "/out/$ext/package.json"; \
      fi; \
    done

# ═══════════════════════════════════════════════════════════════
# Stage 3: 构建
# ═══════════════════════════════════════════════════════════════
FROM ${OPENCLAW_NODE_BOOKWORM_IMAGE} AS build

RUN set -eux; \
    for attempt in 1 2 3 4 5; do \
      if curl --retry 5 --retry-all-errors --retry-delay 2 -fsSL https://bun.sh/install | bash; then \
        break; \
      fi; \
      if [ "$attempt" -eq 5 ]; then \
        exit 1; \
      fi; \
      sleep $((attempt * 2)); \
    done
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

COPY --from=source /source/package.json /source/pnpm-lock.yaml /source/pnpm-workspace.yaml /source/.npmrc ./
COPY --from=source /source/ui/package.json ./ui/package.json
COPY --from=source /source/patches ./patches
COPY --from=source /source/scripts ./scripts
COPY --from=ext-deps /out/ ./extensions/

RUN --mount=type=cache,id=openclaw-pnpm-store,target=/root/.local/share/pnpm/store,sharing=locked \
    NODE_OPTIONS=--max-old-space-size=2048 pnpm install --frozen-lockfile

COPY --from=source /source/ .

RUN for dir in /app/extensions /app/.agent /app/.agents; do \
      if [ -d "$dir" ]; then \
        find "$dir" -type d -exec chmod 755 {} +; \
        find "$dir" -type f -exec chmod 644 {} +; \
      fi; \
    done

RUN pnpm canvas:a2ui:bundle || \
    (echo "A2UI bundle: creating stub (non-fatal)" && \
     mkdir -p src/canvas-host/a2ui && \
     echo "/* A2UI bundle unavailable in this build */" > src/canvas-host/a2ui/a2ui.bundle.js && \
     echo "stub" > src/canvas-host/a2ui/.bundle.hash && \
     rm -rf vendor/a2ui apps/shared/OpenClawKit/Tools/CanvasA2UI)

RUN pnpm build:docker

ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# ═══════════════════════════════════════════════════════════════
# Stage 4: 准备运行时资源
# ═══════════════════════════════════════════════════════════════
FROM build AS runtime-assets
RUN CI=true pnpm prune --prod && \
    find dist -type f \( -name '*.d.ts' -o -name '*.d.mts' -o -name '*.d.cts' -o -name '*.map' \) -delete

# ═══════════════════════════════════════════════════════════════
# Stage 5: 运行时镜像（添加 SSH 和中文字体支持）
# ═══════════════════════════════════════════════════════════════
FROM ${OPENCLAW_NODE_BOOKWORM_IMAGE}
ARG OPENCLAW_NODE_BOOKWORM_DIGEST
ARG OPENCLAW_VERSION

LABEL org.opencontainers.image.source="https://github.com/openclaw/openclaw" \
  org.opencontainers.image.url="https://openclaw.ai" \
  org.opencontainers.image.documentation="https://docs.openclaw.ai/install/docker" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.title="OpenClaw latest release" \
  org.opencontainers.image.version="${OPENCLAW_VERSION}" \
  org.opencontainers.image.description="OpenClaw gateway with SSH and Chinese fonts"

WORKDIR /app

# 安装系统工具 + SSH + Chromium + 中文字体
RUN --mount=type=cache,id=openclaw-bookworm-apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=openclaw-bookworm-apt-lists,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      procps hostname curl git lsof openssl \
      openssh-client \
      fonts-noto-cjk \
      fonts-wqy-zenhei \
      fonts-noto \
      xvfb || true && \
    for attempt in 1 2 3; do \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends chromium && break || sleep 10; \
    done && \
    rm -rf /var/lib/apt/lists/*

RUN chown node:node /app

COPY --from=runtime-assets --chown=node:node /app/dist ./dist
COPY --from=runtime-assets --chown=node:node /app/node_modules ./node_modules
COPY --from=runtime-assets --chown=node:node /app/package.json .
COPY --from=runtime-assets --chown=node:node /app/openclaw.mjs .
COPY --from=runtime-assets --chown=node:node /app/extensions ./extensions
COPY --from=runtime-assets --chown=node:node /app/skills ./skills
COPY --from=runtime-assets --chown=node:node /app/docs ./docs

# 安装 Chromium 到 Playwright 目录
RUN mkdir -p /home/node/.cache/ms-playwright && \
    PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
    node /app/node_modules/playwright-core/cli.js install --with-deps chromium || true && \
    chown -R node:node /home/node/.cache/ms-playwright 2>/dev/null || true

ENV OPENCLAW_BUNDLED_PLUGINS_DIR=/app/extensions
ENV COREPACK_HOME=/usr/local/share/corepack
ENV NODE_ENV=production
ENV PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright

RUN install -d -m 0755 "$COREPACK_HOME" && \
    corepack enable && \
    corepack prepare pnpm --activate && \
    chmod -R a+rX "$COREPACK_HOME"

RUN ln -sf /app/openclaw.mjs /usr/local/bin/openclaw && \
    chmod 755 /app/openclaw.mjs

USER node

HEALTHCHECK --interval=3m --timeout=10s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
