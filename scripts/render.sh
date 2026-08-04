#!/usr/bin/env bash
# Markdown → 单文件 HTML 本地预览
#
#   scripts/render.sh 02-上下文工程/012-上下文窗口要爆了.md
#   scripts/render.sh --all
#
# 依赖装在项目内 .venv，不污染系统 Python。HTML 产物已被 .gitignore 忽略。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$ROOT/.venv"

if [ ! -x "$VENV/bin/python" ]; then
  echo "首次运行，创建 .venv 并安装依赖……"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --upgrade pip
  "$VENV/bin/pip" install --quiet markdown
fi

"$VENV/bin/python" "$ROOT/scripts/render.py" "$@"
