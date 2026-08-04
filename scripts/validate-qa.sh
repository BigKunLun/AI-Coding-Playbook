#!/usr/bin/env bash
# Q&A 结构合规验证 —— 知识库的"测试套件"
# 检查：文件名编号、5 段结构、元信息下沉、折叠块可渲染、正文无行内来源、篇幅
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOPICS=(01-心智与工具 02-上下文工程 03-需求与规划 \
        04-执行工作流 05-质量保证 06-工程协作 \
        07-效率与成本 08-团队与组织 09-工具可靠性)

REQUIRED_SECTIONS=("## 30 秒结论" "## 怎么做" "## 为什么" "## 别这么干" "## 延伸")
VISIBLE_LIMIT=140   # 折叠块之外的正文行数上限（超出只警告）

errors=0
warns=0
checked=0

# 无参数=全库；带参数=只校验指定文件（供单篇改造时自查）
FILES=()
if [ "$#" -gt 0 ]; then
  FILES=("$@")
else
  shopt -s nullglob
  for topic in "${TOPICS[@]}"; do
    [ -d "$ROOT/$topic" ] || continue
    for f in "$ROOT/$topic"/*.md; do FILES+=("$f"); done
  done
fi

for f in "${FILES[@]}"; do
  if true; then
    [ -f "$f" ] || { echo "✗ 找不到文件：$f"; errors=$((errors + 1)); continue; }
    checked=$((checked + 1))
    fname="$(basename "$f")"
    id="$(basename "$(dirname "$f")")/$fname"

    # 1. 文件名 NNN-中文简述.md
    if ! [[ "$fname" =~ ^[0-9]{3}-.+\.md$ ]]; then
      echo "✗ $id: 文件名不符合 NNN-中文简述.md"; errors=$((errors + 1))
    fi

    # 2. 五段结构
    for s in "${REQUIRED_SECTIONS[@]}"; do
      if ! grep -qF "$s" "$f"; then
        echo "✗ $id: 缺少段落 [$s]"; errors=$((errors + 1))
      fi
    done

    # 3. 开头一句话结论
    if ! grep -q '^\*\*一句话\*\*' "$f"; then
      echo "✗ $id: 标题下缺少 **一句话** 结论"; errors=$((errors + 1))
    fi

    # 4. 元信息必须下沉，正文开头不许有 > 难度 / > 题型 块
    if grep -q '^> \(难度\|主题\|工具\|题型\)' "$f"; then
      echo "✗ $id: 元信息仍在正文开头，应下沉到文末 <sub> 小字"; errors=$((errors + 1))
    fi
    if ! grep -q '^<sub>难度' "$f"; then
      echo "✗ $id: 文末缺少 <sub>难度 …</sub> 元信息行"; errors=$((errors + 1))
    fi

    # 5. <summary> 后必须空行，否则 GitHub 不渲染块内 Markdown
    if awk '/^<summary>/{getline nxt; if (nxt != "") exit 1}' "$f"; then :; else
      echo "✗ $id: 有 <summary> 后面没空行，GitHub 上折叠块内容会渲染失败"; errors=$((errors + 1))
    fi

    # 6. 正文不许有行内来源标注。表格里的 ✅ 是「支持/不支持」语义，放行
    inline_ok=$(grep -v '^\s*|' "$f" | grep -c '✅' || true)
    if [ "$inline_ok" -gt 0 ]; then
      echo "✗ $id: 正文有 $inline_ok 处 ✅ 来源标记，应改为脚注或文末参考资料"; errors=$((errors + 1))
    fi

    # 7. 来源可追溯
    if ! grep -qE "https?://" "$f"; then
      echo "✗ $id: 延伸段缺少来源链接"; errors=$((errors + 1))
    fi

    # 8. 折叠块外的正文篇幅（警告级）
    visible=$(awk '/^<details/{d=1} /^<\/details>/{d=0;next} !d' "$f" | grep -c . || true)
    if [ "$visible" -gt "$VISIBLE_LIMIT" ]; then
      echo "⚠ $id: 默认可见正文 ${visible} 行（建议 ≤ ${VISIBLE_LIMIT}），深水区可折进 <details>"
      warns=$((warns + 1))
    fi
  fi
done

echo "──"
echo "检查 $checked 篇：$errors 处错误，$warns 处提示"
if [ "$errors" -eq 0 ]; then echo "✅ 结构全部合规"; exit 0; else exit 1; fi
