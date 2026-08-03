# 021. 动手前到底要不要先写 PRD / 需求文档？写多详细才够？

> 难度：中级
> 主题：需求与规划
> 工具：Claude Code · 横向(Cursor / Copilot / Gemini CLI)
> 题型：决策题

> ⏰ 时效声明：本文事实性内容于 **2026-07-18** 巡检复核。官方引用（best-practices / memory / feature-dev 与 agent-sdk-dev plugin / spec-kit）链接全部存活。medium.com 返回 403 是反爬，不是死链。Reddit 各帖是反爬站点，文中已逐条标注 ⚠️。「验收标准优先」的决策框架与最小 PRD 模板不依赖具体版本，长期有效。文中提到的 Spec Kit `/speckit.*` 命令名是 2025-2026 快照，会随版本变化，以官方仓库为准。

> 说明：PRD 指产品需求文档（Product Requirements Document），即动手前写清「要做什么、做成什么样算完」的文档。spec 指需求规格说明，本文与 PRD 大体同义。

## TL;DR

先给结论：不要纠结「PRD 该不该写」，要纠结「验收标准够不够明确」。一份能让 AI 自己判断「做完没」的需求描述，就是合格的；写得再长但没法验证，等于没写。

社区最常见的劝告是「先写份 PRD 再动手」（just write a PRD）。但这句话本身有坑。它默认你已经清楚知道自己要什么，只是还没写下来。现实往往相反。

r/ClaudeAI 上有一篇帖子标题就叫《"Just write a PRD" - How does this actually work for AI coding?》。高赞评论一针见血：这个建议的问题在于，它假设你已经足够清楚自己想要什么、能把它写成规格（"the problem with 'just write a PRD' advice is it assumes you already know what you want well enough to specify it"，r/ClaudeAI 1so45i3）。

所以 PRD 不是把脑子里的想法誊到纸上，而是把模糊想法收敛成明确契约的过程。这个过程在 AI coding 里有一个被低估的用法：让 AI 反过来访谈你，把你没想清的地方逼问出来。

「要不要写 / 写多详细」的决策：

| 任务类型 | 需求文档形态 | 仪式感 |
|---------|------------|--------|
| 一次性脚本 / 探索性 POC | ❌ 不写文档，一句 prompt 够 | 零 |
| 单个功能、0.5–2 天 | ⚠️ 口头或 plan mode 内对齐，`SPEC.md` 轻量写 | 低 |
| 中型功能、3 天–2 周 | ✅ 写最小 PRD（5 要素），进 git | 中 |
| 新项目 0→1 / 大重构 | ✅ 写 PRD + 架构文档，配合 `/init` 生成 CLAUDE.md；再往上加码就是 SDD | 中-高 |

三条结论：

**第一，官方的答案不是「写份 PRD」，而是一条行为链：先读代码 → 反向访谈澄清 → 出方案经你批准 → 才写。** Claude Code 官方 plugin（feature-dev）把这条固化成七个阶段：Discovery（发现）→ Codebase Exploration（读代码）→ Clarifying Questions（澄清提问）→ Architecture Design（架构设计）→ Implementation（实现）→ Quality Review（质量评审）→ Summary（总结）。核心原则的原话是：实现前先等用户回答（"Wait for user answers before proceeding with implementation"，官方 plugin，[feature-dev](https://github.com/anthropics/claude-code/blob/main/plugins/feature-dev/README.md)）✅。

**第二，PRD 的核心是验收标准，不是篇幅。** 官方说：最有用的 spec 是自包含的（self-contained），会点名涉及哪些文件和接口，会声明什么不在范围内，最后用一个端到端的验证步骤收尾（"The most useful specs are self-contained: they name the files and interfaces involved, state what is out of scope, and end with an end-to-end verification step"，[Best practices](https://code.claude.com/docs/en/best-practices)，官方）✅。社区表达同一个意思：PRD 不是一句 prompt，而是一组文档，各部分由代码可验证的测试隔开（"The PRD is not a prompt. It's a set of documents with pieces of the plan that are separated by code-bound tests"，r/ClaudeAI 1so45i3）⚠️（本轮 reddit 反爬，无法实访复核）。

**第三，`/init` 不是写 PRD 的入口。** `/init` 产出的是 `CLAUDE.md`，属于「环境层」，记录项目架构、命令、约定。PRD 属于「需求层」，记录这次要做什么。两者别混。新项目第一件事是 `/init`（搭环境）加 brainstorm 或 PRD（定需求），而不是把 PRD 塞进 CLAUDE.md。

---

## 为什么

### 1. 先写需求会让 AI 停止瞎猜

这是官方和社区的共识。

Anthropic 官方在 Claude Code 最佳实践里把「先探索、再规划、再写代码」列为推荐工作流的第一条（[Best practices: Explore first, then plan, then code](https://code.claude.com/docs/en/best-practices)，官方，2026-06）✅：

> "Letting Claude jump straight to coding can produce code that solves the wrong problem. Use plan mode to separate exploration from execution."
>
> （让 Claude 直接开写，可能产出「解错了问题」的代码。用 plan mode 把探索和执行分开。）

官方 plugin 仓库（feature-dev）把这条落成了硬性流程约束。Core Principles 的原话是（[feature-dev](https://github.com/anthropics/claude-code/blob/main/plugins/feature-dev/commands/feature-dev.md)，官方 plugin）✅：

> "Ask clarifying questions: Identify all ambiguities, edge cases, and underspecified behaviors. Ask specific, concrete questions rather than making assumptions. **Wait for user answers before proceeding with implementation.**"
>
> （提澄清问题：找出所有模糊点、边界情况和没说清的行为。问具体的问题，而不是自己假设。实现前先等用户回答。）

社区的实证同样一致。r/ClaudeAI 上有篇《I forced Claude to reject my code until I wrote a PRD》记录了一个月的强制实验：强制先写 PRD 之后，Claude 不再瞎猜，用户也不再反复返工（"stopped guessing"、"stopped living in re-prompt mode"，r/ClaudeAI 1qwgpfl）。r/ClaudeCode 上一位数据工程师被「打脸」后总结教训：成功的关键是先写好 PRD，再和 Claude 一起写 SPEC，然后让 Claude 写出详细计划，最后才动手（r/ClaudeCode 1rx1l7d）。

小结：这一论断以官方 best-practices 为主锚，其中「solves the wrong problem」已实访核实 ✅；社区帖 1qwgpfl 和 1rx1l7d 是佐证，但本轮 reddit 反爬无法实访复核 ⚠️。

### 2. 「just write a PRD」为什么是坑

因为它默认你已经知道自己要什么。现实恰恰相反。

「写 PRD」这个建议预设了一个前提：你脑子里已经清楚要什么，只是没写下来。r/ClaudeAI 的高赞帖戳穿了这点（r/ClaudeAI 1so45i3）：

> "the problem with 'just write a PRD' advice is it assumes you already know what you want well enough to specify it."
>
> （「先写 PRD」这个建议的问题是，它假设你已经足够清楚自己想要什么、能把它写成规格。）

所以在 AI coding 时代，写 PRD 的正确姿势不是「人写完丢给 AI」，而是让 AI 帮你把模糊想法逼问成明确契约。官方推荐的做法叫「让 Claude 访谈你」（"Let Claude interview you"，[Best practices](https://code.claude.com/docs/en/best-practices)，官方）✅。具体是：进入 plan mode，让 Claude 用 AskUserQuestion 工具反问你，把技术实现、UI/UX、边界情况、权衡都问清楚，再写 spec 到 `SPEC.md`。

官方 plugin 仓库里的 agent-sdk-dev 把这种「一次只问一个问题、等回答再继续」的节奏也写进了规范（[new-sdk-app.md](https://github.com/anthropics/claude-code/blob/main/plugins/agent-sdk-dev/commands/new-sdk-app.md)，官方 plugin）✅：

> "IMPORTANT: **Ask these questions one at a time. Wait for the user's response before asking the next question.** This makes it easier for the user to respond."
>
> （重要：这些问题一次只问一个。问下一个之前，先等用户回答。这样用户更容易回应。）

这就是 PRD 在 AI 时代的新角色：它是人和 AI 共同产出、互相逼问出来的契约，不是人单方面誊写的文档。

有两个对照的做法。一是面对庞大需求文档：r/ClaudeAI 上有人面对 100+ 页的需求文档，有效做法是让 Claude 逐一列出每一个需求，再结构化（r/ClaudeAI 1qg78ev）。二是面对「要不要先写大 PRD」这个更上层的问题：Chris Dunlop 提出「先落地再扩展」（Land then Expand）——先做最小可跑版本，再逐节扩展，而不是一上来就堆一份大 PRD（[Chris Dunlop · Medium](https://medium.com/realworld-ai-use-cases/claude-code-tip-land-then-expand-dont-start-with-a-big-prd-d0f982704845)，2025-09）。

小结：这一论断有官方 best-practices（interview）、官方 plugin（一次一问）、r/ClaudeAI 1qg78ev（列需求）、Chris Dunlop（Land then Expand）多源支撑，≥2 源 ✅。

### 3. PRD 该回答哪几个问题

答案是：自包含，且验收标准优先。

官方给了一个精炼的标准（[Best practices](https://code.claude.com/docs/en/best-practices)，官方）✅：

> "The most useful specs are self-contained: they name the files and interfaces involved, state what is out of scope, and end with an end-to-end verification step that proves the feature works. **Time spent making the spec precise pays off more than time spent watching the implementation.**"
>
> （最有用的 spec 是自包含的：点名涉及的文件和接口，声明什么不在范围内，最后用一个端到端的验证步骤证明功能能跑。把 spec 写精确花的时间，比盯着 AI 实现花的时间更值。）

这里有三个关键词。self-contained 是自包含，一份文档看完就够，不用四处翻。out of scope 是显式排除，明确写清这次不做什么。verification step 是验收步骤，给出能证明功能能跑的验证方式。最后一句尤其值得记住：把 spec 写精确花的每一分钟，比盯着 AI 实现花的每一分钟更划算。

社区对「PRD 该是什么形态」有更直白的说法（r/ClaudeAI 1so45i3）⚠️（本轮 reddit 反爬，无法实访复核）：

> "The PRD is not a prompt. It's a set of documents with pieces of the plan that are separated by code-bound tests to see if each piece works."
>
> （PRD 不是一句 prompt。它是一组文档，计划被拆成若干部分，各部分用代码可验证的测试隔开，用来检查每一部分是否能跑。）

这句话和 020 篇引用的 HN 金句同源：spec 不是一句 prompt，而是「怎么判断某个东西是否按预期工作」的定义（"A spec is not a prompt. It's an actual definition of how to tell if something is behaving as intended"）。PRD 的本质是「怎么判断做完了」，不是「描述愿望」。

把官方标准和社区共识合并，PRD 至少要回答这 5 个问题（详细模板见「怎么做」）：

1. **做什么（what & why）**：用户故事，解决什么问题。
2. **输入输出契约**：接口、API、数据模型。
3. **验收标准**：可执行的 pass/fail 条件，最关键。
4. **约束与边界**：✅ 必做 / ⚠️ 先问 / 🚫 别碰。
5. **out of scope**：显式声明不在本次范围内的事。

小结：这一论断有官方 best-practices（self-contained / out-of-scope / verification）、r/ClaudeAI 1so45i3、GitHub Spec Kit（specify 阶段）多源支撑，≥2 源 ✅。

---

## 怎么做

### 「写不写 PRD / 写多详细」的决策框架

这是本篇的核心：给可操作的判断，而不是泛泛地说「写个 PRD」。

**维度一：任务复杂度与失败成本**

| 任务规模 | 写不写 | 形态 | 理由 |
|---------|-------|------|------|
| 一次性脚本、探索性 POC | ❌ 不写 | 一句 prompt | 返工成本≈0，PRD 是纯开销。vibe coding 更快。 |
| 单功能、0.5–2 天 | ⚠️ 轻量 | plan mode 内口头对齐 + 可选 `SPEC.md` | plan mode 的只读探索已能收敛大部分歧义，不必单独写文档。 |
| 中型功能、3 天–2 周 | ✅ 写 | 最小 PRD（下方 5 要素），进 git | 这个量级最容易半路跑偏，PRD 的验收标准是返工的刹车。 |
| 新项目 0→1 / 大重构 | ✅ 必写 | PRD + 架构文档 + `/init` 生成 CLAUDE.md | 没有契约全靠 agent 自由发挥，必崩。 |

**维度二：你是新项目还是迭代**

新项目（greenfield，从零起步）的顺序：先 `/init` 搭项目记忆 CLAUDE.md，再 brainstorm 产出 PRD，再让 AI 访谈你补全，再写架构文档，最后进 plan mode 开干。r/ClaudeAI 上专门有帖讨论新项目「冷启动」的顺序（r/ClaudeAI 1l8s5zd）。

既有项目迭代（brownfield，在已有代码上改）的顺序：先让 AI 在 plan mode 只读探索相关代码，再基于理解写「这次改动」的最小 spec，在 out of scope 里写清别碰什么，最后执行。不必为每次迭代都重写整个项目的 PRD。

**维度三：写多详细的铁律——能写出验收测试就是终点**

PRD 不是越详细越好。核心原则（与 020 同源）：写行为，不写实现。

- ✅ 详到「能据此写出验收测试或验证步骤」，就停。
- ❌ 细到伪代码、具体函数实现，就过头了。一旦 PRD 细到代码层，评审 PRD 就等于评审伪代码，人会懒得看；而且 PRD 和代码越容易脱节（drift），维护成本越高。

官方的表述更精炼：找出信号量最高的最小 token 集合，让它最大概率导向你想要的结果（"find the smallest set of high-signal tokens that maximize the likelihood of your desired outcome"，[Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)，官方，2025-09）。PRD 也是上下文，越精炼越有效。

### 最小可用 PRD 模板（5 要素）

综合官方的 self-contained 标准和社区的「代码可验证测试」共识，一份「够用」的 PRD 长这样。可以直接存为 `SPEC.md` 进 git：

```markdown
# [功能名] PRD

## 1. 做什么 & 为什么
- 用户故事：作为 X，我想 Y，以便 Z
- 解决的问题：[一句话]

## 2. 输入输出契约
- 输入：[数据结构 / API 入参]
- 输出：[返回结构 / 副作用]
- 涉及的文件/接口：[列出，做到 self-contained]

## 3. 验收标准（最关键，可执行）
- [ ] 场景 A：输入 X → 期望输出 Y（附测试命令）
- [ ] 场景 B：边界情况 → 期望行为
- [ ] 端到端验证：[一条能跑的命令/脚本]

## 4. 约束与边界
- ✅ 必做：...
- ⚠️ 先问：...
- 🚫 别碰：[显式列出不要动的文件/模块]

## 5. Out of scope（显式排除）
- 本次不做 X、Y、Z
```

> 个人观点（小C）：第 3 节「验收标准」是这份模板的灵魂。如果你的 PRD 删到只剩一节，就留这一节。前 4 节都可以让 AI 在访谈阶段帮你补，但验收标准最好由你自己定，因为它是「你对结果负责」的锚点。

### PRD 写完之后：进 04 执行

PRD 定了之后怎么一轮轮执行、怎么验收、怎么派 SubAgent，是 [#031 plan→execute→review](../04-execution-workflow/031-plan-execute-review-loop.md) 的职责。本篇只讲 PRD 怎么产出，不讲执行循环。

---

## Claude Code 实战

### 四档「写需求」姿势：从轻到重

| 档位 | 怎么做 | 适用 | 花的时间 |
|------|-------|------|---------|
| **零文档** | 一句 prompt 直接开干 | 探索性脚本、demo | 0 |
| **plan mode + 访谈** | 进 plan mode，让 Claude 访谈你，产出 `SPEC.md` | 绝大多数中型任务 | 15–30 min |
| **brainstorming skill** | superpowers 的 `brainstorming` skill 引导式收敛 | 想法还很模糊 | 30–60 min |
| **全流程 SDD** | GitHub Spec Kit 的 `/speckit.*` 命令链，spec/plan/tasks 分阶段进 git | 新项目 0→1、团队协作、大重构 | 数小时起 |

**推荐姿势：plan mode + 访谈，覆盖 80% 场景。**

第一步，进入 plan mode（按两次 `Shift+Tab`，或用 `claude --permission-mode plan`）。

第二步，用官方推荐的访谈 prompt（[Best practices](https://code.claude.com/docs/en/best-practices)，官方）✅：

```
我想做 [简要描述]。用 AskUserQuestion 工具详细地访谈我。
问技术实现、UI/UX、边界情况、顾虑和权衡。别问显而易见的问题，
挖那些我可能没考虑到的难点。
一直问到把所有点覆盖完，然后写一份完整的 spec 到 SPEC.md。
```

第三步，Claude 写完 `SPEC.md` 后，开一个新 session 执行。官方推荐这样做：新 session 有干净的上下文，加上书面 spec 作参照，可以避免长会话里累积的失败尝试干扰。

这就是 020 篇说的「轻量单次 spec」：零额外工具，仪式感最低。

### 最重的一档：文档写到头就是 SDD

前三档都是「你自己写一份 PRD/`SPEC.md`」。如果把这件事继续加码——需求文档不再是一次性的，而是全程维护、驱动实现、跟着项目一起改——它就有了名字：Spec-Driven Development（SDD，规范驱动开发）。

SDD 是什么，一句话：先把「要做什么、做到什么程度」写成能读、能测、能改的规范文档（spec），再让 AI agent 照着 spec 生成代码。它和本篇前面讲的 PRD 是同一个东西的两个刻度——PRD 是「这次任务的契约」，SDD 是「把这份契约变成项目的事实来源，并持续维护」。GitHub 在发布 Spec Kit 时的定义是：spec 不是静态文档，而是随项目一起演进的、活的、可执行的产物（"living, executable artifacts that evolve with the project"，[GitHub Blog](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/)，官方，2025-09）。

它不是瀑布流复活。瀑布流的问题是 spec 一锁死就改不动、反馈周期以月计；SDD 的反馈周期是小时到天，spec 随时能改。

**什么时候值得上到这一档？** 判断标准和本篇前面的三档决策表是同一条线，只是刻度更靠右：

| 场景 | 上不上 SDD |
|------|-----------|
| 探索性原型、一次性脚本 | ❌ 不上。plan mode 就够，SDD 流程纯属负担 |
| 单功能、中型迭代 | ⚠️ 不必上全流程，写最小 PRD（前面 5 要素）即可 |
| 新项目 0→1（greenfield） | ✅ 最适合。少量前期 spec 换来大幅减少返工 |
| 既有项目加新功能（brownfield） | ✅ 适合，但要先让 agent 只读探索代码库 |
| 大型既有库（10 万行以上）做全量 spec | ⚠️ 维护成本陡增，建议只为单次任务写轻量 spec |
| 正式生产代码、要对结果负责 | ✅ 强烈建议 |

**代价要先认下来。** SDD 的主要成本不是写 spec，而是维护 spec：每次改动都要同步回写，否则 spec 和代码逐渐脱节（drift，漂移），文件会变成一堆过时规则的坟场。所以团队上 SDD 前先回答一个问题：愿不愿意把「维护 spec」纳入日常流程？不愿意，就停在第二档，每次任务写一份 `SPEC.md`、用完即弃。

具体怎么跑 Spec Kit 的 `/speckit.*` 命令链，以官方仓库 [github/spec-kit](https://github.com/github/spec-kit) 为准（命令名会随版本变）；spec 里写什么，直接复用本篇前面那份 5 要素 PRD 模板即可。

### `/init` 的正确用法：别和 PRD 混

`/init` 的产物是 `CLAUDE.md`（项目记忆），不是 PRD。官方定位（[memory docs](https://code.claude.com/docs/en/memory)，官方）✅：

> "Run `/init` to generate a starting CLAUDE.md automatically. Claude analyzes your codebase and creates a file with build commands, test instructions, and project conventions it discovers."
>
> （运行 `/init` 自动生成一份起步用的 CLAUDE.md。Claude 分析你的代码库，生成一个包含构建命令、测试说明和它发现的项目约定的文件。）

`/init` 会分析代码库，自动生成包含项目架构、构建命令、编码约定的 CLAUDE.md。它回答的是「这个项目长什么样、怎么跑」。PRD 回答的是「这次要做什么、做成什么样算完」。两者分工不同。

新项目的正确顺序：`/init`（环境层）→ PRD（需求层）→ 执行。

把 PRD 内容塞进 CLAUDE.md 是常见误用。CLAUDE.md 是「每次会话都加载」的长期记忆，塞进一次性需求会污染上下文（见 [#010](../02-context-engineering/010-claude-md-how-to-make-it-work.md) 和 [#012](../02-context-engineering/012-context-window-exploding.md)）。

### 让 AI 帮你把模糊想法转成 PRD

面对一个大而模糊的需求，不要自己硬写。社区验证有效的流程如下（r/ClaudeAI 1qg78ev + Chris Dunlop「Land then Expand」）：

1. **先让 AI 列出它从需求里识别出的所有点**（"list every requirement you found before writing"）。
2. **你逐条确认、否决或补充。** 这一步往往能暴露你自己都没想清楚的点。
3. **先落地再扩展（Land then Expand）：** 先让 AI 产出 PRD 骨架（5 要素标题），再逐节填充。这个「先搭框架再扩展、别一上来堆大 PRD」的策略由 Chris Dunlop 命名（[Chris Dunlop · Medium](https://medium.com/realworld-ai-use-cases/claude-code-tip-land-then-expand-dont-start-with-a-big-prd-d0f982704845)，2025-09）。
4. **（可选）多模型交叉验证：** 把 PRD 分别丢给 Claude、ChatGPT、Gemini，让它们各自挑盲区。r/vibecoding 上一位开发者把这叫「我在任何项目上花得最值的一小时」（"the best hour I spend on any project"，r/vibecoding 1sfyjmo）⚠️（此为单源经验帖；多模型对抗式评审的思路在 020 引用的 HN 46864948 也有印证）。

> 注意边界：多模型评审 PRD 属于「需求阶段找盲区」的技巧，和本篇主题相关；但它更系统的讨论（对抗式 spec 评审）可以独立成篇，本篇点到为止。

---

## 横向对比

| 维度 | Claude Code | Cursor | GitHub Copilot | Gemini CLI |
|------|------------|--------|----------------|------------|
| **原生「写需求」入口** | plan mode（只读强制）+ 访谈 prompt + `SPEC.md` | `.cursor/rules` + chat 引导，无原生受控流程 | `agents.md` + Spec Kit 的 `/speckit.specify` | 支持 Spec Kit 集成 |
| **反向访谈** | 「Let Claude interview you」+ AskUserQuestion 工具（官方推荐） | 依赖人工 prompt 引导 | Spec Kit 的 `/speckit.clarify` | Spec Kit 的 `/speckit.clarify` |
| **项目记忆初始化** | `/init` 生成 CLAUDE.md | 无原生等价（靠 rules） | agents.md 手写 | 无原生等价 |
| **最小 PRD 产物** | `SPEC.md`（官方文档示例就用这个名字） | 用户自定 | `specs/xxx/spec.md`（Spec Kit 结构） | Spec Kit 结构 |

共性观察：「写 PRD」是工具无关的实践，差异在于「原生引导的成熟度」。Claude Code 的 plan mode（只读强制）加访谈机制，把「需求先行」做得最顺手。Copilot 通过 Spec Kit 拿到受控工作流。Cursor 更多依赖人工纪律。来源：[Best practices](https://code.claude.com/docs/en/best-practices)（官方）、[github/spec-kit](https://github.com/github/spec-kit)（官方 / 开源）。

---

## 反模式

❌ **把「just write a PRD」当字面指令。** 这句话假设你已知道想要什么。正确姿势是让 AI 访谈你，把模糊想法逼问成契约。（此建议本身经官方访谈机制印证；批评出处 r/ClaudeAI 1so45i3 ⚠️ 本轮 reddit 反爬无法实访复核）

❌ **把 PRD 写成愿望清单，没有验收标准。** 官方明确要求 spec 要「以一个端到端的验证步骤收尾」。没有验收标准的 PRD 等于没写，AI 依然在瞎猜。✅（官方 best-practices + r/ClaudeAI 1so45i3）

❌ **PRD 写到伪代码 / 具体实现细节。** 一旦细到代码层，评审 PRD 就等于评审伪代码，人会懒得看；而且和代码脱节的成本剧增。详到「能写验收测试」即停。⚠️（V2EX，020 篇已验证多帖共识）

❌ **把 PRD 塞进 CLAUDE.md。** CLAUDE.md 是每次会话都加载的长期项目记忆，塞进一次性需求会污染上下文、触发上下文腐化（context rot，无关信息越堆越多导致模型注意力涣散）。PRD 用 `SPEC.md` 单独存。✅（官方 best-practices + [#010](../02-context-engineering/010-claude-md-how-to-make-it-work.md)）

❌ **小任务 / 探索脚本强行写 PRD。** 返工成本≈0 的任务，PRD 是纯开销。一句 prompt 直接开干更快。✅（社区共识）

❌ **PRD 写完就锁死不再更新。** 执行中发现的需求变更要回写 PRD，否则 PRD 和实现脱节，PRD 沦为「过时规则的坟场」（OpenAI harness 博客语）。✅（020 篇已验证：OpenAI + V2EX）

❌ **把 `/init` 当成写 PRD 的入口。** `/init` 产的是 CLAUDE.md（项目记忆 / 环境层），不是 PRD（需求层）。混用会导致需求散落在项目记忆里，难以维护。✅（官方 memory docs）

---

## 延伸

**交叉引用：**
- [#022 怎么把一个大需求拆成 AI 能一次做对的子任务？](./022-task-decomposition-for-ai.md) —— 本篇产出 PRD/spec，022 讲怎么把它拆成一条条可执行任务。
- [#031 plan → execute → review 的正确循环怎么做？](../04-execution-workflow/031-plan-execute-review-loop.md) —— 本篇讲 PRD 怎么产出（需求层），031 讲 PRD 定了之后如何一轮轮执行（执行层）。本篇是 031 的上游。
- [#010 CLAUDE.md 怎么写才真的生效？](../02-context-engineering/010-claude-md-how-to-make-it-work.md) —— 010 讲长期全局约定（CLAUDE.md），本篇讲单次任务的需求契约（PRD/SPEC）。两者同源：都是明确契约，但时间尺度和加载方式不同。
- [#012 上下文窗口要爆了怎么办？](../02-context-engineering/012-context-window-exploding.md) —— 012 讲上下文塞满的机制与处置；本篇讲主动产出的需求文档。区别：012 是「被动塞进去的上下文」，021 是「主动产出的需求产物」。
- [#023 Vibe coding 为什么会翻车？什么时候必须停下来规划？](./023-vibe-coding-when-to-stop-and-plan.md) —— 023 是「问题」（不规划就开干会崩），本篇是「方案」（怎么规划）。

**参考资料：**
- [Best practices for Claude Code — Claude Code Docs](https://code.claude.com/docs/en/best-practices) — 官方：「Explore first, then plan, then code」「Let Claude interview you」「self-contained spec: name files/interfaces, state out of scope, end with verification step」「Time spent making the spec precise pays off more than time spent watching the implementation」（官方，2026-06）✅
- [Effective context engineering for AI agents — Anthropic](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — 官方：「find the smallest set of high-signal tokens that maximize the likelihood of your desired outcome」、context rot、attention budget（官方，2025-09）✅
- [feature-dev plugin — anthropics/claude-code](https://github.com/anthropics/claude-code/blob/main/plugins/feature-dev/README.md) — 官方 plugin：七阶段（Discovery→Codebase Exploration→Clarifying Questions→Architecture Design→Implementation→Quality Review→Summary）、「Ask clarifying questions... Wait for user answers before proceeding」、Discovery 阶段 interview 示例（官方 plugin，2026）✅
- [feature-dev Core Principles — anthropics/claude-code](https://github.com/anthropics/claude-code/blob/main/plugins/feature-dev/commands/feature-dev.md) — 官方 plugin：「Understand before acting」「Ask specific, concrete questions rather than making assumptions」（官方 plugin，2026）✅
- [new-sdk-app.md — anthropics/claude-code](https://github.com/anthropics/claude-code/blob/main/plugins/agent-sdk-dev/commands/new-sdk-app.md) — 官方 plugin：「Ask these questions one at a time. Wait for the user's response before asking the next question」（官方 plugin，2026）✅
- [How Claude remembers your project — Claude Code Docs](https://code.claude.com/docs/en/memory) — 官方：`/init` 生成 starting CLAUDE.md、项目记忆四层级（CLAUDE.md 是 team-shared 约定，非需求文档）（官方，2026）✅
- [I forced Claude to reject my code until I wrote a PRD — r/ClaudeAI 1qwgpfl](https://www.reddit.com/r/ClaudeAI/comments/1qwgpfl/i_forced_claude_to_reject_my_code_until_i_wrote_a/) — 社区：强制先写 PRD 一个月实验，Claude stopped guessing、用户 stopped re-prompt mode（社区，2025-11）⚠️（本轮环境 reddit 反爬，无法实访复核）
- ["Just write a PRD" - How does this actually work for AI coding? — r/ClaudeAI 1so45i3](https://www.reddit.com/r/ClaudeAI/comments/1so45i3/just_write_a_prd_how_does_this_actually_work_for/) — 社区：「the problem with 'just write a PRD' advice is it assumes you already know what you want」「The PRD is not a prompt. It's a set of documents with pieces of the plan that are separated by code-bound tests」（社区，2026）⚠️（本轮环境 reddit 反爬，无法实访复核）
- [How to get a PRD from a huge project requirement — r/ClaudeAI 1qg78ev](https://www.reddit.com/r/ClaudeAI/comments/1qg78ev/how_to_get_prd_from_a_huge_project_requirement/) — 社区：100+ 页需求文档先让 Claude 逐一列出需求再结构化（社区，2025）⚠️（本轮环境 reddit 反爬，无法实访复核）
- [Claude Code Tip: Land then Expand — Don't start with a big PRD — Chris Dunlop · Medium](https://medium.com/realworld-ai-use-cases/claude-code-tip-land-then-expand-dont-start-with-a-big-prd-d0f982704845) — 社区：AI coding meta 已变，先做最小可跑版本再逐节扩展，比一上来堆大 PRD 更有效，「Land then Expand」命名出处（Chris Dunlop，2025-09）✅
- [Claude Code: What do you do when starting a brand new project? — r/ClaudeAI 1l8s5zd](https://www.reddit.com/r/ClaudeAI/comments/1l8s5zd/claude_code_what_do_you_do_when_starting_a_brand/) — 社区：新项目 cold start 该先做什么的讨论（`/init`、CLAUDE.md、PRD 三者的先后顺序；本篇正文采用 `/init` → PRD 的顺序，理由见「`/init` 的正确用法」一节）（社区，2025）⚠️（本轮环境 reddit 反爬，无法实访复核）
- [So I tried using Claude Code to build actual software and it humbled me — r/ClaudeCode 1rx1l7d](https://www.reddit.com/r/ClaudeCode/comments/1rx1l7d/so_i_tried_using_claude_code_to_build_actual/) — 社区：教训——成功关键是 PRD → SPEC → detailed plan before coding（社区，2026）⚠️（本轮环境 reddit 反爬，无法实访复核）
- [I run every PRD through Claude, ChatGPT, and Gemini before coding — r/vibecoding 1sfyjmo](https://www.reddit.com/r/vibecoding/comments/1sfyjmo/i_run_every_prd_through_claude_chatgpt_and_gemini/) — 社区：多模型 review PRD pipeline、「the best hour I spend on any project」（社区，2026）⚠️（单源经验，多模型 adversarial review 思路见 020 引用的 HN 46864948）
- [How I write PRDs and Tech Specs with AI — r/agile 1nek7ai](https://www.reddit.com/r/agile/comments/1nek7ai/how_i_write_prds_and_tech_specs_with_ai_saving/) — 社区：用 AI 写 PRD/Tech Spec 省 sprint 工时、保留战略思考（社区，2025）⚠️（本轮环境 reddit 反爬，无法实访复核）
- [Spec-driven development with AI — GitHub Blog](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/) — 官方：Spec Kit 发布，spec 是「living, executable artifacts that evolve with the project」，三个最佳适用场景（官方，2025-09）✅
- [github/spec-kit — GitHub](https://github.com/github/spec-kit) — 官方/开源：`/speckit.specify`（what & why）/ `/speckit.clarify`（反向澄清）命令链，specify 阶段即 PRD 产出（官方/开源，2025-2026）✅

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验——你写 PRD 吗？什么量级会写？用 plan mode + interview 还是直接手写？有没有遇到 PRD 写太细反而 review 不动的情况？]`
