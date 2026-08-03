#!/usr/bin/env bash
# Q&A 结构合规验证 —— 知识库的"测试套件"
# 检查：文件名编号、元信息头、核心 5 段、来源链接
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOPICS=(01-心智与工具 02-上下文工程 03-需求与规划 \
        04-执行工作流 05-质量保证 06-工程协作 \
        07-效率与成本 08-团队与组织 09-工具可靠性)

REQUIRED_META=("难度" "主题" "工具" "题型")
REQUIRED_SECTIONS=("## TL;DR" "## 为什么" "## 怎么做" "## 反模式" "## 延伸")

errors=0
checked=0

for topic in "${TOPICS[@]}"; do
  dir="$ROOT/$topic"
  [ -d "$dir" ] || continue
  shopt -s nullglob
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    checked=$((checked + 1))
    fname="$(basename "$f")"

    # 1. 文件名 NNN-slug.md
    if ! [[ "$fname" =~ ^[0-9]{3}-.+\.md$ ]]; then
      echo "✗ $topic/$fname: 文件名不符合 NNN-slug.md"; errors=$((errors + 1))
    fi

    # 2. 元信息头（行首 > 字段）
    for m in "${REQUIRED_META[@]}"; do
      if ! grep -q "^> $m" "$f"; then
        echo "✗ $topic/$fname: 缺少元信息字段 [$m]"; errors=$((errors + 1))
      fi
    done

    # 3. 核心 5 段
    for s in "${REQUIRED_SECTIONS[@]}"; do
      if ! grep -qF "$s" "$f"; then
        echo "✗ $topic/$fname: 缺少段落 [$s]"; errors=$((errors + 1))
      fi
    done

    # 4. 来源链接（可追溯）
    if ! grep -qE "https?://" "$f"; then
      echo "✗ $topic/$fname: 延伸段缺少来源链接"; errors=$((errors + 1))
    fi
  done
done

echo "──"
echo "检查 $checked 篇，发现 $errors 处问题"
if [ "$errors" -eq 0 ]; then echo "✅ 全部合规"; exit 0; else exit 1; fi
