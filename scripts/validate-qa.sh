#!/usr/bin/env bash
# Q&A 结构合规验证 —— 知识库的"测试套件"
# 检查：文件名编号、5 段结构、元信息下沉、折叠块可渲染、正文无行内来源、篇幅、mermaid 图注
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOPICS=(01-心智与工具 02-上下文工程 03-需求与规划 \
        04-执行工作流 05-质量保证 06-工程协作 \
        07-效率与成本 08-团队与组织 09-工具可靠性)

REQUIRED_SECTIONS=("## 30 秒结论" "## 怎么做" "## 为什么" "## 别这么干" "## 延伸")
VISIBLE_LIMIT=140   # 折叠块之外的正文行数上限（超出只警告）
CAPTION_LIMIT=55    # mermaid 图注字数上限（去掉 markdown 标记后，超出只警告）
FIGURE_LIMIT=2      # 单篇 mermaid 图数上限：默认 1 张，独立判断维度才准加第 2 张
STALE_MONTHS=6      # 时效核实日期超过 N 个月即提醒复核（警告级）
NOW_MONTHS=$(( 10#$(date +%Y) * 12 + 10#$(date +%m) ))

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

    # 9. 时效超期扫描（警告级）：取文末时效行里最新的日期，超 STALE_MONTHS 个月提醒复核
    fresh_line=$(grep '<sub>\*\*时效\*\*' "$f" | head -1 || true)
    if [ -z "$fresh_line" ]; then
      echo "⚠ $id: 文末缺少 <sub>**时效**…</sub> 声明"; warns=$((warns + 1))
    else
      latest=$(printf '%s' "$fresh_line" | grep -oE '20[0-9]{2}-[0-9]{2}' | sort | tail -1 || true)
      if [ -z "$latest" ]; then
        echo "⚠ $id: 时效行里没有可解析的核实日期（YYYY-MM 或 YYYY-MM-DD）"; warns=$((warns + 1))
      else
        m=$(( 10#${latest:0:4} * 12 + 10#${latest:5:2} ))
        if [ $(( NOW_MONTHS - m )) -gt "$STALE_MONTHS" ]; then
          echo "⚠ $id: 时效核实日期 $latest 已超 ${STALE_MONTHS} 个月，建议复核易变项"
          warns=$((warns + 1))
        fi
      fi
    fi
    # 10. 每张 mermaid 图后都要有一句话图注，且是结论不是流程复述
    nfig=$(grep -c '^```mermaid' "$f" || true)
    if [ "$nfig" -gt 0 ]; then
      if [ "$nfig" -gt "$FIGURE_LIMIT" ]; then
        echo "✗ $id: 有 ${nfig} 张图（上限 ${FIGURE_LIMIT}），第三张说明这篇装了两个问题，该拆篇不该加图"
        errors=$((errors + 1))
      fi
      idx=0
      while IFS= read -r caption; do
        idx=$((idx + 1))
        if printf '%s' "$caption" | grep -qE '^(#|>|\||<|\* |- |\+ |[0-9]+\. )'; then
          echo "✗ $id: 第 ${idx} 张图后面是标题/引用/表格/列表，缺一句话图注"; errors=$((errors + 1))
        elif printf '%s' "$caption" | grep -qE '上图|该图|这张图|如图|图注|流程如下|如下图'; then
          echo "✗ $id: 第 ${idx} 张图的图注在复述流程，应改写成一句话结论"; errors=$((errors + 1))
        else
          clen=$(printf '%s' "$caption" | tr -d '*`_ ' | wc -m | tr -d ' ')
          if [ "$clen" -gt "$CAPTION_LIMIT" ]; then
            echo "⚠ $id: 第 ${idx} 张图的图注 ${clen} 字（建议 ≤ ${CAPTION_LIMIT}），超长通常是塞了不止一个论点"
            warns=$((warns + 1))
          fi
        fi
      done < <(awk '/^```mermaid/{blk=1;next} blk&&/^```/{blk=0;want=1;next} want&&NF{print;want=0}' "$f")
      if [ "$idx" -lt "$nfig" ]; then
        echo "✗ $id: 有 $((nfig - idx)) 张 mermaid 图后面没有任何内容，缺图注"; errors=$((errors + 1))
      fi
    fi
  fi
done

# 11. README 目录表与 llms.txt 必须是 gen-toc.sh 的生成产物（仅全库模式检查）
if [ "$#" -eq 0 ]; then
  if ! bash "$ROOT/scripts/gen-toc.sh" --check; then
    errors=$((errors + 1))
  fi
fi

echo "──"
echo "检查 $checked 篇：$errors 处错误，$warns 处提示"
if [ "$errors" -eq 0 ]; then echo "✅ 结构全部合规"; exit 0; else exit 1; fi
