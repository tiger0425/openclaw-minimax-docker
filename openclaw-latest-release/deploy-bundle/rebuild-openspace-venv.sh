#!/bin/bash

set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$BASE_DIR/openspace" ]; then
  echo "❌ 未找到 openspace 源码目录: $BASE_DIR/openspace"
  exit 1
fi

echo "🐍 Rebuilding OpenSpace venv via python:3.12-bookworm ..."

docker run --rm -u root \
  -v "$BASE_DIR:$BASE_DIR" \
  -w "$BASE_DIR/openspace" \
  python:3.12-bookworm \
  bash -lc '
    set -euo pipefail
    rm -rf "'$BASE_DIR'/.venv-openspace"
    python -m venv --copies "'$BASE_DIR'/.venv-openspace"
    "'$BASE_DIR'/.venv-openspace/bin/pip" install -U pip >/dev/null
    "'$BASE_DIR'/.venv-openspace/bin/pip" install . >/dev/null
    cp -f /usr/local/lib/libpython3.12.so.1.0 "'$BASE_DIR'/.venv-openspace/lib/"
    mkdir -p "'$BASE_DIR'/.venv-openspace/lib/python3.12"
    cp -a /usr/local/lib/python3.12/* "'$BASE_DIR'/.venv-openspace/lib/python3.12/"
    mkdir -p "'$BASE_DIR'/.venv-openspace/lib/python3.12/site-packages/logs"
    chown -R 1000:1000 "'$BASE_DIR'/.venv-openspace"
    head -n 1 "'$BASE_DIR'/.venv-openspace/bin/openspace-mcp"
    "'$BASE_DIR'/.venv-openspace/bin/python" -c "import openspace; print(openspace.__file__)"
  '

echo "✅ OpenSpace venv rebuilt: $BASE_DIR/.venv-openspace"
