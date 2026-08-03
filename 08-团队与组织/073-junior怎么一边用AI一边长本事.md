# 073. 天天用 AI 写代码，我是不是在越用越不会写？junior 怎么一边用 AI 一边真长本事

> 难度：高级
> 主题：团队与组织
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：场景题 + 决策题

> ⏰ 时效声明：本文事实性内容于 **2026-08-03** 复核。Anthropic RCT（Shen & Tamkin，arXiv:2601.20245）与 MIT Sloan 研究均无更新版或后续发表，文中数据即当前最新；METR / Fastly / Stack Overflow 数据出处链接全部存活。Claude Code subagent 的文件位置与 frontmatter 字段按 [官方 subagents 文档](https://code.claude.com/docs/en/sub-agents) 2026-08 版核对。各研究测的时代背景不同（MIT=补全时代 2024、Fastly/METR=agentic 时代 2025），文中已按此区分。

## TL;DR

会。但不是因为你用了 AI，是因为你**用错了方式**——决定你成长还是退化的，不是用不用 AI，是你对 AI 说什么。

Anthropic 做过一个 52 人的随机对照实验：用 AI 写代码的那组，对自己几分钟前刚写的代码做测验，平均分 50%；手写组 67%。但同一批数据里还有个分岔——**拿 AI 追问概念、要解释、自己动手实现的人，得分 65% 以上；把整段活甩给 AI 生成和 debug 的人，跌破 40%**。差距不在工具，在提示词。

三点速记：

1. **提效不等于成长。** 你用 AI 后当周产出确实涨得比老手多（MIT：junior +27~39%，senior +8~13%），但对代码的掌握度反而掉。产出涨不能当成"我在进步"的证据。
2. **你自己感觉不出来。** METR 测 16 名资深开发者，用 AI 后实际慢了 19%，自评却是"快了 20%"。连老手都误判，你更没有内部信号能纠偏——所以必须用外部测验，见下面第 3 节。
3. **老手被 AI 放大，是因为他们有判断力。** Fastly 调查 791 人：10 年以上经验的人里约 1/3 说自己上线代码过半是 AI 生成的，0~2 年的只有 13%。差的不是打字速度，是"一眼看出 AI 哪里看着对其实错"的能力，而这个能力只能靠自己磕出来。

---

## 今天就能改的 5 句提示词

这是全篇唯一的实测分水岭，直接复制换掉你常说的那句。左列是跌破 40 分的说法，右列是 65 分以上的说法。

| 你常说的（反成长，<40 分） | 换成这句（促成长，>65 分） | 说完怎么自检 |
|---|---|---|
| "帮我把这个功能写完" | "先解释这里为什么要用 async 而不是线程池，讲完别写代码，我自己写第一版，你再挑错" | 合上 AI 窗口，能不能口述这段代码的执行顺序（谁先跑、在哪儿挂起、谁唤醒） |
| "报错了，你直接改" | "别改。告诉我这个报错的根因假设有哪几种、分别怎么验证，我来定位" | 能不能自己说出"如果是原因 A，我该看哪个日志/加哪句打印" |
| "行，就这么改吧"（然后直接 accept 整个 diff） | "逐段讲这个 diff 改了什么、有什么副作用、哪一处最可能出问题，我来决定收哪些" | 能不能指出 diff 里你**主动拒绝**的至少一处改动，并说出拒绝理由 |
| "这个库怎么用，给我示例" | "给我这个库的核心心智模型：它解决什么问题、有哪三个必须记住的约束，示例先不要" | 不看文档能不能说出这三个约束，以及违反后会出什么症状 |
| "帮我优化一下性能" | "先告诉我怎么测出瓶颈在哪，我跑完把数据给你，再一起决定改哪儿" | 手里有没有一组"改前 / 改后"的真实数字，而不是"感觉快了" |

判据很简单：**AI 说完之后，如果你的下一个动作是 Ctrl+C / accept，那这次交互对你的成长贡献是零。** 右列每一句的共同点，都是逼出你自己的一个动作。

上面这条分水岭出自 Anthropic RCT（2026-01，✅ 官方研究）：

> "the AI group averaged 50% on the quiz, compared to 67% in the hand-coding group—or the equivalent of nearly two letter grades"
> — [Anthropic: How AI assistance impacts the formation of coding skills](https://www.anthropic.com/research/AI-assistance-coding-skills)

一句话切边界：本篇回答"个人怎么用 AI 才不退化 + 团队人才结构怎么变"。团队的 AI coding 规范怎么立见 [#075](./074-团队AI-coding规范怎么立.md)；效能怎么度量见 [#071](./071-AI-coding效能怎么度量.md)；"谁来验证 AI 代码"的体系见 [#040](../05-质量保证/040-怎么验证AI代码是真的对.md)。

---

## 为什么

### 1. 两个方向相反的数据，必须同时看

关于 junior 用 AI，市面上流传两组看似打架的结论。它们其实不矛盾，因为量的是不同的东西。

**第一组：论当周产出，junior 增益更大。**

MIT Sloan 对三家公司做了 GitHub Copilot 实验，结论是经验少、入职短的开发者更爱用这个工具，而且他们的产出涨得更多。

> "Inexperienced and short-tenured software developers were more likely to use the tool, and, moreover, their productivity increased a lot more."
> — [MIT Sloan: How generative AI affects highly skilled workers](https://mitsloan.mit.edu/ideas-made-to-matter/how-generative-ai-affects-highly-skilled-workers)（Dylan Walsh，研究，2024-11）✅

具体数字：junior 完成任务量 +27~39%，senior 只 +8~13%。这是"提效"维度。

**第二组：论对代码的掌握度，junior 反而受损。**

Anthropic 的 RCT：52 名工程师，多为 junior，学一个没用过的异步库 Trio。AI 组测验 50%，手写组 67%。值得注意的是，用 AI 干活速度只快了一点点，还没到统计显著；但对几分钟前刚写的代码的理解，掉了 17 个百分点。这是"成长"维度。

并排看这两组数据，第一条结论就出来了：**AI 让你出活更快，但不自动让你长本事。** 混为一谈就会出现最危险的误判——看着产出涨了，以为人也在成长。

### 2. 为什么老手在被放大、新手在被腐蚀

同一个工具，对两类人作用相反，根子在于判断力谁有谁没有。

Fastly 在 2025-07 调查了 791 名开发者。约三分之一的 senior（10 年以上经验）说自己上线的代码里过半是 AI 生成的，是 junior（0~2 年，13%）的约 2.5 倍。

> "they can more quickly identify when AI-generated code is incorrect, insecure, or poorly suited to the problem being solved… senior developers are simply better equipped to catch and correct AI's mistakes."
> — [Fastly: Senior Developers Ship 2.5x More AI Code](https://www.fastly.com/blog/senior-developers-ship-more-ai-code)（调查，2025-07）✅（两句均为原文，出自同一段落，中间以"…"标注省略）

这跟 MIT 的"junior 提效更大"不打架。MIT 量的是自动补全时代（2024）的任务完成量；Fastly 量的是 agentic 时代（2025，指 AI 能自主执行多步任务）敢把多少 AI 代码放进生产。敢放靠的是审查判断力，而判断力恰恰是 senior 有、junior 还没长出来的。

新手被腐蚀的机制，Anthropic 点破了：不是用 AI 就掉分，是"卡住—硬磕—搞懂"这段最长本事的过程被跳过了。

> Anthropic 给管理者的建议是：让工程师"continue to learn as they work—and are thus able to exercise meaningful oversight"（在工作中持续学习，从而能做有意义的监督），并且"Cognitive effort—and even getting painfully stuck—is likely important for fostering mastery"（认知上的努力，甚至是痛苦地卡住，很可能是培养精通的关键）。✅

**最麻烦的是这种腐蚀是隐形的。** METR 对 16 名资深开发者的 RCT 发现，用 AI 后实际慢了 19%，自评"快了 20%"（[METR, 2025-07](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/)✅）。用社区的话说，当你"感觉更快、实际更慢时，你没有任何内部信号能自我修正"（"feel faster while getting slower, you have no internal signal to course-correct"，[TianPan, 2026-04](https://tianpan.co/blog/2026-04-19-skill-atrophy-ai-augmented-engineering)，社区）⚠️。

### 3. 岗位这一层：入门岗在缩，但只留 senior 的结构撑不住

Stack Overflow 博客援引 Stanford 数字经济研究：到 2025-07，22–25 岁软件开发者的就业相比 2022 年末的峰值降了约 20%；入门级技术招聘在 2024 年同比降了 25%。

> "if you don't hire junior developers, you'll someday never have senior developers."（如果你不招 junior，总有一天你会没有 senior。）
> — [Stack Overflow Blog: AI vs Gen Z](https://stackoverflow.blog/2025/12/26/ai-vs-gen-z/)（Eira May，社区，2025-12）⚠️（具体数字经 SO 转引 Stanford，单链路）

这就是团队结构的核心张力。短期看，senior + AI 能吃掉过去交给 junior 的活，砍掉入门岗省钱很诱人。长期看，senior 只有一个来源——从 junior 长出来。停招 junior，就是把未来几年的 senior 供给一起关掉，而现有 senior 会老去、会跳槽。这不是道德问题，是补给问题。

HN 上「AI is making junior devs useless」的讨论把成长路径重构成三段：先不用 AI 直到建立起直觉（No AI until intuition），再有意识地用 AI 去观察它在哪里失灵，最后成为 AI-native expert。讨论还点出真正的难点：AI 是超个性化的家教，但同时也是逃避动手练习的、几乎不可抗拒的诱惑（[HN 47206663](https://news.ycombinator.com/item?id=47206663)，社区，2026-03）⚠️。

---

## 怎么做

### A. 你自己就能做的（不需要任何人批准）

1. **换提示词。** 就是上面那张表，今天就能改。这是投入产出比最高的一条。
2. **每周留一个"裸写任务"。** 挑一个小任务（半天以内、非紧急），全程不开 AI，卡住了先自己顶 30 分钟再问。目的不是效率，是把"痛苦地卡住"这段过程留下来——Anthropic 明确说这是培养精通的关键。✅
3. **给自己做延迟测验，别信感觉。** 这是唯一能戳破"感觉更快"错觉的办法。具体做法：

   > **48 小时回读测验**
   > 从上周合并的 PR 里随机挑一个自己提的，**关掉编辑器和 AI**，只看 PR 标题，在纸上/空文档里回答四题：
   > 1. 这段代码的执行顺序是什么？（关键分支、异步点各在哪）
   > 2. 为什么选了这个方案，被否掉的备选是什么？
   > 3. 哪一处最可能出线上问题？为什么当时觉得可以接受？
   > 4. 如果要加一个相邻需求，改哪几个文件？
   >
   > **判据**：四题里答不上 2 题以上，说明这个 PR 你没真正拥有。
   > **频率**：每周一次，连续 4 周记录得分。得分不上升就说明"提效"没换来"成长"，该调整用法了。

4. **建一个"欠账清单"。** 每次因为赶时间直接 accept 了看不懂的 diff，在一个文件（比如 `skill-debt.md`）里记一行：日期 + PR 链接 + 哪儿没看懂。每周挑一条补掉。这条来自社区的 skill-debt tracking 实践（[TianPan, 2026-04](https://tianpan.co/blog/2026-04-19-skill-atrophy-ai-augmented-engineering)，社区）⚠️。
5. **PR 描述里必须有一段"我验证了什么"。** 不是走流程，是逼自己在提交前把理解补上。写不出来就说明还没懂。

### B. 带人者 / 团队侧（三条，其余靠上面的个人动作）

6. **提效和成长分开度量。** 产出量走 [#071](./071-AI-coding效能怎么度量.md) 的那套；成长用上面第 3 条的延迟测验，每月记一次分。别用产出涨来推断人在成长。
7. **立"用法红线"，不是"用量红线"。** 要禁的不是用 AI，是整块委托（wholesale delegation）不求理解。把上面那张提示词表塞进团队的 onboarding 和 `CLAUDE.md`（见 [#010](../02-上下文工程/010-CLAUDE-md怎么写才生效.md)）。
8. **把资深判断力沉淀成可分发的资产，别靠口头带。** 具体怎么做见下一节的 subagent 文件。senior 一忙，junior 就只剩裸 AI。

---

## Claude Code 实战

Claude Code 在这个话题上的主场，是用它的机制把资深判断力沉淀成 junior 能随时调用的东西。

### 1. 把"资深 reviewer"写成一个可提交进 git 的 subagent

subagent 是带独立上下文和专属系统提示词的专职助手。官方文档明确它能"Enforce constraints by limiting which tools a subagent can use"（通过限制工具强制约束），并且项目级 subagent 放在 `.claude/agents/` 里、建议提交进版本控制供全队使用（[CC Docs: subagents](https://code.claude.com/docs/en/sub-agents)，官方，2026-08 核对）✅。

新建 `.claude/agents/growth-reviewer.md`，内容直接抄：

```markdown
---
name: growth-reviewer
description: 审查 junior 提交的代码改动，同时输出"你需要补的理解点"。在提 PR 前主动使用。
tools: Read, Grep, Glob
model: sonnet
color: orange
---

你是本仓库的资深 reviewer。你的输出分成固定两段，缺一不可。

## 第一段：代码问题
按严重度倒序列出，每条给出 文件:行号 + 问题 + 建议改法。
重点看：边界条件、错误处理、并发/异步的执行顺序、与本仓库既有约定不一致的地方。

## 第二段：理解检查（必须有）
针对本次改动出 3 个问题，考察作者是否真的理解自己提交的代码：
1. 一个关于执行顺序的问题
2. 一个关于"为什么不用另一种方案"的问题
3. 一个关于"这段代码在什么输入下会挂"的问题
只出题，不给答案。作者答不上来的，说明这段代码他还没拥有。

约束：你只读代码，不修改任何文件。
```

关键点说明：
- `tools: Read, Grep, Glob` 是刻意的——只给只读工具，它就物理上改不了代码，只能给意见。官方文档说明 `tools` 省略时会继承全部工具，所以这一行必须写。
- `model: sonnet` 可选值为 `sonnet` / `opus` / `haiku` / `fable` / 完整模型 ID（如 `claude-opus-5`）/ `inherit`，省略时默认 `inherit`（跟随主会话）。
- `name` 只能用小写字母和连字符，不能含 `:`（`:` 保留给插件作用域名）。
- 只有 `name` 和 `description` 是必填。

**怎么判断做对了：**

```bash
# 1. 确认文件在正确位置
ls -1 .claude/agents/
# 预期输出包含：growth-reviewer.md

# 2. 确认 frontmatter 能被解析（YAML 头闭合、字段拼写正确）
head -8 .claude/agents/growth-reviewer.md
# 预期：第 1 行和第 7 行都是 ---，中间是 name/description/tools/model/color

# 3. 提交进 git，让全队共享
git add .claude/agents/growth-reviewer.md && git commit -m "chore: 加 growth-reviewer subagent"
```

然后在 Claude Code 会话里显式调用（`@agent-<名字>` 是官方支持的手写形式）：

```
@agent-growth-reviewer 看一下我这次的改动
```

预期：Claude 委派给该 subagent，返回的结果是**两段结构**——先代码问题，再三个理解检查问题。如果只返回了代码问题没有第二段，说明系统提示词没生效，检查 YAML 头是否闭合。

如果 Claude 找不到这个 subagent：`.claude/agents/` 目录如果是本次会话开始后才新建的，需要重启 Claude Code 才能被发现（官方文档明确说明了这一点）。文件已存在时的后续编辑则会被自动监听，几秒内生效，不用重启。

机制详解见 [#032](../04-执行工作流/032-SubAgent并行开几个.md)。

### 2. 把提示词红线写进 CLAUDE.md

在项目 `CLAUDE.md` 里加一段，让默认交互方式就是促成长的那种：

```markdown
## 与本仓库协作的默认约定

- 解释优先：被要求实现一个不熟悉的机制时，先用 5 行以内讲清心智模型和关键约束，再问对方要不要你写代码。
- 不主动整段生成：单次改动超过 50 行时，先给方案要点让对方确认，不要直接铺代码。
- diff 必须可复述：给出改动后，附一句"这次改动最可能出问题的地方是 X"。
```

**怎么判断做对了**：新开一个会话，问一个你不熟的库怎么用。预期它先给心智模型和约束、并反问要不要写代码，而不是直接吐一大段实现。如果直接吐代码了，说明 `CLAUDE.md` 没被加载——用 `/context` 确认当前上下文里有没有这个文件。

### 3. 用"读懂才 merge"当成长闸

结合 [#040](../05-质量保证/040-怎么验证AI代码是真的对.md) 的"人最终 accountable（担责）"原则：提 PR 时要能口头讲清"AI 为什么这么写、你验证了什么"。这一步既挡住了走过场的橡皮图章式审查，也强制把理解补回来。上面 subagent 输出的第二段三个问题，正好可以当这一关的题库。

---

## 横向对比

### 决策：面对"junior 怎么办"，三条组织路线

| 路线 | 做法 | 后果 |
|------|------|------|
| **停招入门岗**（省钱派） | 只留 senior + AI，不招 junior | 账面短期变好；2~5 年后 senior 无来源可补，现有 senior 一流失就补不上（HN/SO ⚠️）。**不推荐** |
| **放养提效**（乐观派） | 照招 junior，随便用 AI 冲产出 | 产出涨、掌握度掉（Anthropic −17% ✅），养出"永久新手"，且腐蚀是隐形的（METR ✅） |
| **刻意培养**（推荐） | 招 junior，配"用法红线 + 每周裸写任务 + 延迟测验 + 读懂才 merge" | 提效与成长兼得；短期带教成本高，长期唯一可持续 |

### 工具：谁承载资深判断力给 junior 用

| 工具 | 承载物 | 差异 |
|------|--------|------|
| **Claude Code** | 可版本化 subagent（`.claude/agents/`）+ 多层 `CLAUDE.md` + `.claude/rules/` | 层级最丰富，判断力可拆成"专职 reviewer agent"分发全队，且能用 `tools` 白名单强制只读 |
| **Cursor** | `.cursor/rules/*.mdc`（按文件匹配条件加载） | 规则可按文件类型注入，但没有独立 reviewer agent 的概念 |
| **GitHub Copilot** | `.github/copilot-instructions.md`（单文件） | 无多层级、无条件加载，承载资深判断的粒度最粗 |

核心差异：Claude Code 能把"资深 reviewer"做成一个独立、可复用、进 git 的 agent，等于给每个 junior 配了个随叫随到的把关人。

---

## 反模式

- ❌ **看产出涨就断定"我在成长"。** 提效和成长是两根轴，产出涨的同时掌握度可能在掉（MIT +27~39% 产出 vs Anthropic −17% 理解）✅。用延迟测验测，别用感觉测。
- ❌ **信自己"感觉更快了"的自评。** 连 senior 都被 METR 测出"自评 +20%、实则 −19%"✅。
- ❌ **整段甩给 AI 生成加 debug。** 这是跌破 40 分的用法。该甩给 AI 的不是理解，是重复劳动（Anthropic ✅）。
- ❌ **为省时间取消所有"自己磕"的机会。** 卡住（getting painfully stuck）是长本事的必要成本，全给 AI 兜底就没有成长了（Anthropic ✅）。
- ❌ **团队"AI 能顶活，停招 junior 省钱"。** senior 只有一个来源，就是长大的 junior；停招等于关掉未来几年的供给（HN/SO 社区共识）⚠️。
- ❌ **资深判断力只留在 senior 脑子里、靠口头带。** senior 一忙 junior 就裸奔。要用 subagent、`CLAUDE.md`、rules 把标准固化下来（[#010](../02-上下文工程/010-CLAUDE-md怎么写才生效.md) / [#032](../04-执行工作流/032-SubAgent并行开几个.md)）。

---

## 延伸

**交叉引用：**
- [#075 团队的 AI coding 规范怎么立？哪些该强制、哪些该自由？](./074-团队AI-coding规范怎么立.md) —— 本篇讲人才结构怎么变，075 讲团队规矩写什么、哪些该强制。
- [#071 AI coding 的效能到底怎么度量？DORA / SPACE / 代码量 / AI 生码率，哪个不是 vanity metric？](./071-AI-coding效能怎么度量.md) —— 本篇"提效≠成长"的度量落地在这。
- [#040 AI 说"做完了"、测试也全绿，怎么知道代码是真的对？](../05-质量保证/040-怎么验证AI代码是真的对.md) —— 本篇"读懂才 merge"成长闸的质量体系版。
- [#010 CLAUDE.md 怎么写才真的生效？](../02-上下文工程/010-CLAUDE-md怎么写才生效.md) —— 把资深判断力固化进上下文的载体。
- [#032 开几个 agent 并行跑，结果互相踩、被限流、token 指数级炸开——并行到底该开几个？](../04-执行工作流/032-SubAgent并行开几个.md) —— 把"资深 reviewer"做成可复用 agent 的机制。

**参考资料：**
- [How AI assistance impacts the formation of coding skills — Anthropic](https://www.anthropic.com/research/AI-assistance-coding-skills) —— RCT：AI 组理解 50% vs 手写 67%，用法（追问 vs 甩给）决定成长（官方研究，Shen & Tamkin，arXiv:2601.20245，2026-01）✅
- [How generative AI affects highly skilled workers — MIT Sloan](https://mitsloan.mit.edu/ideas-made-to-matter/how-generative-ai-affects-highly-skilled-workers) —— junior +27~39%、senior +8~13% 产出增益（研究，2024-11）✅
- [Measuring the Impact of Early-2025 AI on Experienced OS Developers — METR](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/) —— 实际慢 19%、自评快 20% 的感知落差（研究，2025-07）✅
- [Senior Developers Ship 2.5x More AI Code — Fastly](https://www.fastly.com/blog/senior-developers-ship-more-ai-code) —— 791 人调查，senior 敢放进生产的 AI 代码是 junior 的 2.5 倍（调查，2025-07）✅
- [AI vs Gen Z — Stack Overflow Blog](https://stackoverflow.blog/2025/12/26/ai-vs-gen-z/) —— 22–25 岁开发者就业降约 20%、入门招聘降 25%，"no junior → someday no senior"（社区，2025-12）⚠️
- [Create custom subagents — Claude Code Docs](https://code.claude.com/docs/en/sub-agents) —— subagent 文件位置、frontmatter 字段（`name`/`description`/`tools`/`model`/`color`）、`@agent-<name>` 显式调用、新建目录需重启（官方，2026-08 核对）✅
- [AI is making junior devs useless — HN 47206663](https://news.ycombinator.com/item?id=47206663) —— 成长路径重构、AI 家教 vs 逃避练习的诱惑（社区，2026-03）⚠️
- [The Skill Atrophy Trap — TianPan.co](https://tianpan.co/blog/2026-04-19-skill-atrophy-ai-augmented-engineering) —— 隐形腐蚀、skill-debt tracking（社区，2026-04）⚠️

> 本篇个人实践（L4）：`[待补：BOSS 带 junior 的真实组合 / 哪条红线最有效 / 保护区怎么留 / 有没有养出永久新手的教训]`
