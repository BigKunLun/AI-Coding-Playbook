#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把本库的 Q&A Markdown 渲染成单文件 HTML（本地预览用，不入库）。

用法：
    scripts/render.sh 02-上下文工程/012-上下文窗口要爆了.md
    scripts/render.sh --all

设计前提：源文件是 .md，GitHub 直接渲染就能读。HTML 只是本地预览/分享的
可再生产物，所以这里做的是机械转换，不做人工排版。
"""
import io
import os
import re
import sys

import markdown

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.expanduser("~/.claude/skills/md2html/template.html")

TOPICS = [
    "01-心智与工具", "02-上下文工程", "03-需求与规划",
    "04-执行工作流", "05-质量保证", "06-工程协作",
    "07-效率与成本", "08-团队与组织", "09-工具可靠性",
]

# 题型 → md2html 模板的 doc-type eyebrow
DOC_TYPE = {
    "排错题": "RUNBOOK",
    "配置题": "RUNBOOK",
    "流程题": "PLAN",
    "决策题": "BRAINSTORM",
    "场景题": "NOTES",
}


def slugify(text, sep="-"):
    """保留中文的 slug，去掉 markdown 行内标记和标点。"""
    text = re.sub(r"[`*_\[\]()#]", "", text).strip()
    text = re.sub(r"[\s:：，、。？！/\\]+", sep, text)
    return text.strip(sep).lower()


def read_meta(src_text):
    """从正文抽取标题、副标题、题型、字数。"""
    title = "未命名"
    m = re.search(r"^#\s+(.+?)\s*$", src_text, re.M)
    if m:
        title = m.group(1)

    subtitle = ""
    m = re.search(r"^\*\*一句话\*\*[：:]\s*(.+?)$", src_text, re.M)
    if m:
        subtitle = re.sub(r"[`*]", "", m.group(1))
    if len(subtitle) > 200:
        subtitle = subtitle[:197] + "…"

    doc_type = "NOTES"
    m = re.search(r"(排错题|配置题|流程题|决策题|场景题)", src_text)
    if m:
        doc_type = DOC_TYPE[m.group(1)]

    # 中文按 500 字/分钟估算
    cjk = len(re.findall(r"[一-鿿]", src_text))
    minutes = max(1, round(cjk / 500.0))
    return title, subtitle, doc_type, "~%d 分钟阅读" % minutes


def preprocess(text):
    """让 <details> 里的 Markdown 能被渲染，并套上模板的 class。"""
    text = text.replace(
        "<details>",
        '<details class="collapsible" markdown="1">',
    )
    # summary 之后的内容包一层 collapsible-body，匹配模板 CSS
    text = re.sub(
        r"(</summary>\n)",
        r'\1\n<div class="collapsible-body" markdown="1">\n',
        text,
    )
    text = text.replace("</details>", "</div>\n</details>")
    return text


def postprocess(html):
    """把 markdown 库的产出对齐到 md2html 模板的组件 class。"""
    # 1. mermaid 代码块 → <figure class="diagram"><pre class="mermaid">
    def mermaid_sub(m):
        return (
            '<figure class="diagram"><pre class="mermaid">\n'
            + m.group(1)
            + '\n</pre></figure>'
        )

    html = re.sub(
        r'<pre><code class="language-mermaid">(.*?)</code></pre>',
        mermaid_sub,
        html,
        flags=re.S,
    )

    # 2. 脚注容器对齐模板 CSS
    html = html.replace('<div class="footnote">', '<div class="footnote-block">')
    html = re.sub(
        r'(<div class="footnote-block">\s*<hr\s*/?>\s*)<ol>',
        r'\1<ol class="footnotes">',
        html,
    )

    # 3. 宽表格（≥4 列）包 .table-wrap，方便窄屏横向滚动
    def wrap_table(m):
        table = m.group(0)
        cols = len(re.findall(r"<th[ >]", table.split("</thead>")[0]))
        if cols >= 4:
            return '<div class="table-wrap">' + table + "</div>"
        return table

    html = re.sub(r"<table>.*?</table>", wrap_table, html, flags=re.S)
    return html


def build_toc(toc_tokens):
    """递归取 H2/H3，生成模板侧栏需要的扁平链接。H1 已经是 doc-title，跳过。"""
    lines = []

    def walk(tokens):
        for t in tokens:
            if t["level"] in (2, 3):
                lines.append(
                    '        <a href="#%s" class="lvl-%d">%s</a>'
                    % (t["id"], t["level"], t["name"])
                )
            walk(t.get("children", []))

    walk(toc_tokens)
    return "\n".join(lines)


def render(md_path, tpl):
    with io.open(md_path, encoding="utf-8") as f:
        src = f.read()

    title, subtitle, doc_type, read_time = read_meta(src)
    rel = os.path.relpath(md_path, ROOT)

    md = markdown.Markdown(
        extensions=["tables", "fenced_code", "footnotes", "md_in_html", "toc", "sane_lists"],
        extension_configs={
            "toc": {"slugify": slugify},
            "footnotes": {"BACKLINK_TEXT": "↩"},
        },
    )
    body = postprocess(md.convert(preprocess(src)))
    toc = build_toc(md.toc_tokens)

    out = tpl
    for key, val in {
        "{{LANG}}": "zh",
        "{{REC_LABEL}}": "★ 推荐",
        "{{TITLE}}": title,
        "{{SUBTITLE}}": subtitle,
        "{{DOC_TYPE}}": doc_type,
        "{{SOURCE_FILE}}": os.path.basename(md_path),
        "{{DATE}}": "AI Coding Playbook",
        "{{READ_TIME}}": read_time,
        "{{BRAND_LABEL}}": "AI Coding Playbook",
        "{{TOC_TITLE}}": "目录",
        "{{PRINT_TOOLTIP}}": "打印 / 保存 PDF",
        "{{THEME_TOOLTIP}}": "切换主题",
        "{{CLOSE_LABEL}}": "关闭",
        "{{SKIP_LINK_LABEL}}": "跳到正文",
        "{{FOOTER_NOTE}}": "来源: " + rel,
    }.items():
        out = out.replace(key, val)

    out = out.replace("<!-- TOC_ENTRIES -->", toc)
    start = out.index("<!-- CONTENT_START -->") + len("<!-- CONTENT_START -->")
    end = out.index("<!-- CONTENT_END -->")
    out = out[:start] + "\n" + body + "\n      " + out[end:]

    # 正文里的 .md 交叉引用改指向同名 .html，预览时可点
    out = re.sub(r'(href="[^"]*?)\.md"', r'\1.html"', out)

    dst = os.path.splitext(md_path)[0] + ".html"
    with io.open(dst, "w", encoding="utf-8") as f:
        f.write(out)
    return dst


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 1

    if not os.path.exists(TEMPLATE):
        print("✗ 找不到模板：%s" % TEMPLATE)
        print("  需要先安装 md2html skill。")
        return 1

    with io.open(TEMPLATE, encoding="utf-8") as f:
        tpl = f.read()

    if args[0] == "--all":
        targets = []
        for topic in TOPICS:
            d = os.path.join(ROOT, topic)
            if not os.path.isdir(d):
                continue
            for name in sorted(os.listdir(d)):
                if name.endswith(".md"):
                    targets.append(os.path.join(d, name))
    else:
        targets = [os.path.abspath(a) for a in args]

    for t in targets:
        dst = render(t, tpl)
        print("✓ %s" % os.path.relpath(dst, ROOT))
    print("──\n渲染 %d 篇" % len(targets))
    return 0


if __name__ == "__main__":
    sys.exit(main())
