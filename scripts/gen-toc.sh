#!/usr/bin/env bash
# 目录生成器 —— README「完整目录」段与 llms.txt 都是本脚本的生成产物，不再人肉维护
# 用法：
#   scripts/gen-toc.sh          重新生成（写回 README.md 与 llms.txt）
#   scripts/gen-toc.sh --check  只比对不写回，不一致时退出码 1（供 validate-qa.sh 调用）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
README="$ROOT/README.md"
LLMS="$ROOT/llms.txt"

# 主题目录 → 折叠标题（层标注改这里，README 会跟着重生成）
TOPICS=(01-心智与工具 02-上下文工程 03-需求与规划 \
        04-执行工作流 05-质量保证 06-工程协作 \
        07-效率与成本 08-团队与组织 09-工具可靠性)
LABELS=("01 · 心智与工具（L0）" "02 · 上下文工程（L1）" "03 · 需求与规划（L1）" \
        "04 · 执行工作流（L2）" "05 · 质量保证（L3）" "06 · 工程协作（L4）" \
        "07 · 效率与成本（横切）" "08 · 团队与组织（L5）" "09 · 工具可靠性与供应商风险（横切）")

# 从单篇取 H1 标题（去掉「# NNN. 」前缀）；文件名取编号
title_of() { head -1 "$1" | sed -E 's/^# [0-9]{3}\. //'; }
num_of()   { basename "$1" | cut -c1-3; }

# ---- 生成 README 目录段（含节标题行）----
gen_readme_section() {
  echo "## 📖 完整目录"
  for i in "${!TOPICS[@]}"; do
    topic="${TOPICS[$i]}"
    echo ""
    echo "<details open>"
    echo "<summary><b>${LABELS[$i]}</b></summary>"
    echo ""
    echo "| # | 问题 |"
    echo "|---|------|"
    for f in "$ROOT/$topic"/*.md; do
      echo "| $(num_of "$f") | [$(title_of "$f")]($topic/$(basename "$f")) |"
    done
    echo ""
    echo "</details>"
  done
  echo ""
}

# ---- 生成 llms.txt（llmstxt.org 格式，供读者把整库挂给 AI 当参考源）----
gen_llms() {
  echo "# AI-Coding-Playbook"
  echo ""
  echo "> 中文 AI 编程实战问答集：沿「用 AI 完成一个开发任务」的能力栈分 9 层，每篇回答一个开发者实际会撞上的高频问题，给可操作步骤和「怎么确认做对了」的验证方法。主线工具 Claude Code。"
  echo ""
  for i in "${!TOPICS[@]}"; do
    topic="${TOPICS[$i]}"
    echo "## ${LABELS[$i]}"
    echo ""
    for f in "$ROOT/$topic"/*.md; do
      echo "- [$(title_of "$f")]($topic/$(basename "$f"))"
    done
    echo ""
  done
}

# ---- 把新目录段拼回 README（段落边界：## 📖 完整目录 起，到下一个 ## 止）----
gen_full_readme() {
  awk '/^## 📖 完整目录/{exit} {print}' "$README"
  gen_readme_section
  awk 'found{print; next} /^## 📖 完整目录/{seen=1} seen && /^## / && !/^## 📖/{found=1; print}' "$README"
}

shopt -s nullglob
NEW_README="$(gen_full_readme)"
NEW_LLMS="$(gen_llms)"

if [ "${1:-}" = "--check" ]; then
  fail=0
  if ! diff -q <(printf '%s\n' "$NEW_README") "$README" >/dev/null 2>&1; then
    echo "✗ README 完整目录与实际文章不一致，跑 scripts/gen-toc.sh 重新生成"
    diff <(printf '%s\n' "$NEW_README") "$README" | head -10 || true
    fail=1
  fi
  if [ ! -f "$LLMS" ] || ! diff -q <(printf '%s\n' "$NEW_LLMS") "$LLMS" >/dev/null 2>&1; then
    echo "✗ llms.txt 与实际文章不一致，跑 scripts/gen-toc.sh 重新生成"
    fail=1
  fi
  exit "$fail"
fi

printf '%s\n' "$NEW_README" > "$README"
printf '%s\n' "$NEW_LLMS" > "$LLMS"
echo "✅ 已重新生成 README 完整目录段与 llms.txt"
