FROM crpi-a1liy20beodq2bdl.cn-beijing.personal.cr.aliyuncs.com/bujic/openclaw:v2026.3.12

USER root

RUN apt-get update \
  && apt-get install -y --no-install-recommends openssh-client chromium fonts-noto-cjk \
  && rm -rf /var/lib/apt/lists/*

USER node
