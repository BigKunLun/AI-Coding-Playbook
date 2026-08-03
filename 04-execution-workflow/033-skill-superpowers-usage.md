# 033. Skill / superpowers 怎么用、怎么写？

> 难度：高级
> 主题：执行工作流
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：配置题

> ⏰ 时效声明：本篇的机制数字（metadata ~100 tokens、正文 <500 行、description+when_to_use 合并 1536 字符截断、compact 重挂载每技能 5000/合计 25000 tokens）与 frontmatter 字段、`skillListingBudgetFraction`/`"name-only"` 设置、"custom commands 已并入 skills"均已于 **2026-07-18** 对照官方 [skills 文档](https://code.claude.com/docs/en/skills)逐项核实无误。Claude Code 迭代快，预算类数字请以官方为准。

## TL;DR

Skill 是 Claude Code 里的一种能力封装机制：把你反复用到的多步工作流，打包成 Claude 能自动发现、按需调用的资源。

它的物理形态很简单，就是一个文件夹加一个 `SKILL.md` 文件。这个文件分两部分：开头的 YAML frontmatter（一段结构化的元数据，主要是 `name` 和 `description` 两个字段），以及下面的正文（Markdown 写的操作指令）。

它的加载分三步走。启动时，Claude Code 只把 frontmatter 预加载进 system prompt（每个会话开头那段固定的系统指令）。只有当 Claude 判断「当前任务和这个 skill 相关」时，才把正文读进来。正文里引用的脚本和参考文档，再延后到真正用到时才读。

这套「用多少加载多少」的机制，官方叫 progressive disclosure（渐进披露）。它正是 skill 和另外两种机制的分野所在：CLAUDE.md 是每轮都占 token 的常驻内容，slash command 靠你手动触发。而 skill 因为渐进披露，哪怕装 100 个也几乎不占常驻 token。

三条结论，值得记牢：

1. **skill 的第一性原理是渐进披露。** 官方把它比作一本有目录、章节、附录的手册，让 Claude 按需读取信息。token 分三层：元数据先进系统提示（约 100 tokens），匹配上才读 `SKILL.md` 正文（<5k tokens），附属文件和脚本再按需加载。这也决定了长篇参考材料该放 skill，而不是常驻的 CLAUDE.md。
2. **该不该封装成 skill，看你有没有在「重复粘贴同一段指令、检查清单或多步流程」。** 官方创建指引开篇第一句就是这个信号。反过来，一次性任务别封装，项目特定的约定放 CLAUDE.md。
3. **description 决定一个 skill 的生死。** Claude 就是靠这个字段，在上百个 skill 里判断「当前任务该不该加载它」。写得太抽象、太宽泛，或者把流程摘要写进去，skill 就会该触发时不触发、不该触发时乱触发。

---

## 为什么

### 1. 官方定调：skill 是「按需加载的专长」，靠渐进披露省上下文

Anthropic 在介绍 Agent Skills 的工程博客里，把设计哲学讲得很清楚。skill 不是「又一种 prompt」，而是把人类专家的流程化经验，打包成 agent 能发现的资源。核心机制就是渐进披露。

> "Progressive disclosure is the core design principle that makes Agent Skills flexible and scalable. Like a well-organized manual that starts with a table of contents, then specific chapters, and finally a detailed appendix, skills let Claude load information only as needed… the amount of context that can be bundled into a skill is effectively unbounded."
>
> 大意：渐进披露是让 Agent Skills 既灵活又可扩展的核心设计原则。就像一本组织良好的手册，先给目录，再到具体章节，最后是详细附录，skill 让 Claude 只在需要时加载信息。因此一个 skill 能塞进的内容量几乎没有上限。
>
> —— [Anthropic: Equipping agents for the real world with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)（官方，2025-10）✅

加载分三层，官方博客与 skills 博客两处均有印证：

| 层级 | 何时加载 | 大小 |
|------|---------|------|
| **第 1 层**：`name` + `description` frontmatter | 启动时预加载进每个会话的 system prompt | ~100 tokens / skill |
| **第 2 层**：`SKILL.md` 正文 | Claude 判断「相关」时才读进来 | 通常 <500 行（<5k tokens） |
| **第 3 层**：附属文件（reference.md / scripts/） | 正文指向它、且当前任务真需要时才读 | 无上限 |

> "metadata loads first (~100 tokens), providing just enough information for Claude to know when a Skill is relevant. Full instructions load when needed (<5k tokens), and bundled files or scripts load only as required."
>
> 大意：元数据最先加载（约 100 tokens），给 Claude 刚好够用的信息去判断某个 skill 是否相关。完整指令在需要时加载（<5k tokens），附带的文件或脚本只在真正用到时才加载。
>
> —— [Claude blog: Skills explained](https://claude.com/blog/skills-explained)（官方，2026-03）✅

这套机制也解释了 skill 和 CLAUDE.md 的根本区别。CLAUDE.md 是「常驻税」，每一轮对话都占 token。skill 是「按需调用」，不用就不花 token。

官方在文档里给了一条明确的判断线：当 CLAUDE.md 里的某一节，从「一条事实」长成了「一套流程」，就该把它抽成 skill（[CC Docs: skills](https://code.claude.com/docs/en/skills)，官方）✅。

### 2. Skill vs Slash Command vs MCP：三个机制解决三类问题

这三者是社区最容易混淆的地方，官方专门写了一篇博客来厘清边界（[Skills explained](https://claude.com/blog/skills-explained)，官方，2026-03）✅。

一句话概括官方的核心区分：

> "MCP connects Claude to data; Skills teach Claude what to do with that data… Skills are proactive—Claude knows when to apply them."
>
> 大意：MCP 负责把 Claude 连到数据上，skill 负责教 Claude 拿到数据后该做什么。而且 skill 是主动的，Claude 自己知道何时该用它。

四种机制的定位对比如下：

| 机制 | 本质 | 触发方式 | 适合 | 不适合 |
|------|------|---------|------|--------|
| **CLAUDE.md** | 常驻上下文（事实/约定） | 始终在上下文 | 项目事实、命名约定、不可遗忘的硬规则 | 流程化指令（该抽成 skill） |
| **Skill** | 按需加载的专长（指令+脚本+资源） | Claude 自动发现 **或** `/skill-name` 手动 | 重复出现的多步流程、领域专长、可复用检查清单 | 一次性任务、项目特定约定 |
| **Slash Command** | prompt 模板 | **只**你手动 `/name` | 你想完全掌控触发时机的动作（已并入 skill 体系） | 需要自动触发的场景 |
| **MCP** | 外部数据/工具连接器 | 始终可用 | 连数据库、Slack、GitHub、内部 API | 教 Claude「怎么用」这些数据（那是 skill 的活） |
| **SubAgent** | 独立上下文窗口的专精 agent | 委派 | 隔离上下文、对抗式 review（见 [#032](./032-subagent-when-and-how.md)） | 跨会话复用的专长（那该是 skill） |

这里有一个重要演进要注意：Claude Code 已经把 custom commands 并入了 skill 体系。官方原话是，一个放在 `.claude/commands/deploy.md` 的命令文件，和一个放在 `.claude/skills/deploy/SKILL.md` 的 skill，都会创建出 `/deploy`，用法完全一样（[CC Docs: skills](https://code.claude.com/docs/en/skills)，官方，2026-06）✅。

换句话说，skill 是 command 的超集，多出了三个能力：可以在目录里放附属文件，可以用 frontmatter 控制谁能触发，可以让 Claude 自动加载。所以新项目一律用 skill，别再新建 `.claude/commands/` 目录了（旧文件仍然兼容）。

社区也有一致的总结。MindStudio 用一句话概括了 command 和 skill 的区别：command 关乎「Claude 怎么想」，skill 关乎「Claude 能做什么」。他们还指出，skill 可以由 Claude 在相关时自主调用，而 command 需要你显式触发（[MindStudio: Skills vs Slash Commands](https://www.mindstudio.ai/blog/claude-code-skills-vs-slash-commands-2)，社区，2026-04）⚠️。

需要提醒的是，该文把 skill 等同于「可调用的函数或 MCP 工具」，这个说法窄化了。官方的 skill 既支持纯指令型，也支持带脚本型。「skill vs command vs MCP 边界」这个论断，有官方博客加官方文档两个来源支撑 ✅。

### 3. 什么时候该封装成 skill？——官方与社区趋同的判断线

这是配置题最常被问到的决策。官方在文档里给了最直接的信号（[CC Docs: skills](https://code.claude.com/docs/en/skills)，官方，2026-06）✅：

> "Create a skill when you keep pasting the same instructions, checklist, or multi-step procedure into chat, or when a section of CLAUDE.md has grown into a procedure rather than a fact."
>
> 大意：当你不断把同一段指令、检查清单或多步流程粘进对话，或者 CLAUDE.md 里某一节从「一条事实」长成了「一套流程」时，就该建一个 skill。

社区的 superpowers 项目在它的 `writing-skills` skill 里，独立给出了一份几乎一致的判断标准（[obra/superpowers: writing-skills SKILL.md](https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md)，社区/开源，2025-2026）✅。

**该封装成 skill 的情况：**

- 这个技巧不是靠直觉就能想到的
- 你会跨项目重复引用它
- 这个模式适用面广，不是某个项目特有的
- 别人也会从中受益

**不该封装（放 CLAUDE.md 或干脆不封装）的情况：**

- 一次性的解决方案
- 别处已有充分文档的标准实践
- 项目特定的约定（应放该项目的 CLAUDE.md 或 instructions 文件）
- 能用正则或校验脚本强制的机械约束（直接自动化，别浪费文档）

「何时封装成 skill」这个论断，有官方文档加社区 superpowers 两个来源，且结论高度一致 ✅。核心信号就三个：重复出现、跨场景复用、属于需要判断的知识。

> 个人观点（小C）：很多人把 skill 理解成「把 prompt 存成一个文件」，这其实是把 skill 降级成了 command。skill 真正的价值有两点：一是渐进披露带来的「装 100 个也不爆上下文」，二是 Claude 会自动发现并触发。判断要不要封装，最好的测试是：如果你发现自己在第三个项目里，又把同一段流程手敲了一遍，那就是信号。把它抽成个人 skill（放 `~/.claude/skills/`），以后所有项目自动可用。

---

## 怎么做

### 第一步：判断「这到底该不该是 skill」

过一遍这张三问决策表（综合官方与 superpowers）：

| 问题 | 答 Yes → | 答 No → |
|------|---------|---------|
| 你是否**重复**粘贴过这段指令/流程 ≥3 次？ | 可能该封装 | 别封装，直接用 prompt |
| 它是**流程/专长**（怎么做），还是**事实/约定**（是什么）？ | 流程 → skill | 事实 → CLAUDE.md |
| 它是否**跨项目/跨场景**可复用？ | 是 → 放 `~/.claude/skills/`（个人） | 否 → 放 `.claude/skills/`（项目） |
| 它是**判断类知识**，还是能用正则/校验脚本强制？ | 判断类 → skill | 机械约束 → 写 hook / 校验脚本 |

有一个反直觉的关键点：别把一次性任务封装成 skill。官方和 superpowers 都点名这是反模式（详见「反模式」一节）。skill 的价值来自复用产生的复利，一次性封装只会增加噪音。

### 第二步：建目录结构

skill 的物理形态就是一个文件夹加一个 `SKILL.md`：

```
my-skill/
├── SKILL.md           # 主指令（必需）
├── reference.md       # 详细参考（按需加载）
├── examples/
│   └── sample.md      # 输出示例（按需加载）
└── scripts/
    └── validate.sh    # 可执行脚本（执行，不读进上下文）
```

放在哪里，决定它的作用范围（官方，[CC Docs: skills](https://code.claude.com/docs/en/skills)，2026-06）✅：

| 位置 | 路径 | 作用于 |
|------|------|--------|
| 个人 | `~/.claude/skills/<name>/SKILL.md` | 你的所有项目 |
| 项目 | `.claude/skills/<name>/SKILL.md` | 仅本项目（可进版本控制，团队共享） |
| 插件 | `<plugin>/skills/<name>/SKILL.md` | 启用该插件处 |
| 企业 | managed settings | 组织全员 |

同名时的优先级是：企业 > 个人 > 项目 > 内置。插件 skill 用 `plugin-name:skill-name` 的命名空间，所以不会冲突。

### 第三步：写 SKILL.md（frontmatter 是成败关键）

一个 `SKILL.md` 由两部分组成：YAML frontmatter（元数据）加 Markdown 正文（指令）。官方对 frontmatter 字段有明确约束（[CC Docs](https://code.claude.com/docs/en/skills) 与 [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)，官方，2026）✅。

**两个核心字段：**

| 字段 | 必需 | 说明 |
|------|------|------|
| `name` | 否（默认取目录名） | 显示名。**仅小写字母、数字、连字符**，≤64 字符，禁含 `anthropic`/`claude` 保留词 |
| `description` | **推荐**（事实上的必需） | 写清「做什么 + 什么时候用」，用第三人称。这是 Claude 决定要不要加载 skill 的唯一依据。字段本身上限 1024 字符；进入 skill 列表后，`description` + `when_to_use` 的合并文本会在 1536 字符处截断 |

上述 description 的字符预算，出处为官方 [best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) 与 [CC Docs](https://code.claude.com/docs/en/skills)，均属官方 ✅。

**description 的写法要点**（官方 best practices 与 superpowers 实测趋同，两个来源 ✅）：

- **用第三人称**，因为它会被注入 system prompt。正确写法是 `Processes PDF files...`，错误写法是 `I can help you...` 或 `You can use this...`。
- **同时写清「做什么」和「什么时候用」，并含关键词。** 例如：`Extract text and tables from PDF files, fill forms. Use when working with PDFs or when the user mentions PDFs, forms, or document extraction.`
- **以 "Use when..." 开头**，聚焦触发条件（superpowers 的实测建议）。
- **别在 description 里概括 skill 的流程。** superpowers 实测发现，agent 会把 description 里的流程摘要当成捷径，直接跳过读正文。所以 description 只写「何时用」，流程留给正文（[writing-skills SKILL.md](https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md)，社区）✅。

**常用可选字段（控制触发与执行）：**

| 字段 | 作用 |
|------|------|
| `disable-model-invocation: true` | 禁止 Claude 自动触发，只能你 `/name` 手动（适合 deploy/commit 等有副作用的动作） |
| `user-invocable: false` | 从 `/` 菜单隐藏，只让 Claude 自动用（适合背景知识型 skill） |
| `allowed-tools: Bash(git add *)` | skill 激活时预批准这些工具（免逐次确认） |
| `disallowed-tools: AskUserQuestion` | skill 激活时移除这些工具（适合后台循环 skill） |
| `context: fork` + `agent: Explore` | 在 fork 出的 subagent 里跑（隔离上下文，见 [#032](./032-subagent-when-and-how.md)） |
| `paths: src/**/*.ts` | 仅当工作文件匹配 glob 时自动激活 |
| `argument-hint` / `arguments` | 声明位置参数，配合 `$0`/`$ARGUMENTS` 替换 |

### 第四步：写正文（精简是第一原则）

官方 best practices 开篇第一条就是「Concise is key」，也就是精简至上（[Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)，官方，2026）✅。

> "The context window is a public good… once Claude loads it, every token competes with conversation history and other context."
>
> 大意：上下文窗口是一种公共资源。一旦 Claude 把 skill 加载进来，它的每一个 token 都在和对话历史、其他上下文抢占空间。

官方给的默认假设是：Claude 本来就很聪明，你只需要补充它不知道的东西。每加一段，都自问一句：Claude 真的需要这段解释吗？这段内容配得上它占用的 token 成本吗？

正文的几条约束（官方与 superpowers 趋同）：

- **正文控制在 500 行以内。** 超了就拆成附属文件，正文只留导航（官方 best practices 与 CC Docs，两个来源 ✅）。
- **附属引用只深一层。** 即 `SKILL.md → reference.md`，不要再 `reference.md → details.md` 套娃。因为 Claude 预览深层文件时可能只 `head -100` 读取一部分，导致信息丢失（官方 best practices）✅。
- **超过 100 行的参考文件要加目录**，方便 Claude 预览时看到全貌（官方 best practices）✅。
- **正文是「常驻指令」，不是一次性步骤。** skill 一旦被调用，正文会在后续每一轮都留在上下文里（官方 CC Docs: Skill content lifecycle）✅。

### 第五步：测它（不测等于没写）

官方反复强调：看到一个 skill 被触发，只能说明 Claude 找到了它，不能说明它做对了你想要的事（[CC Docs: skills: Evaluate and iterate](https://code.claude.com/docs/en/skills)，官方，2026-06）✅。

所以有两件事要分开测：

1. **触发率**：该触发的时候触发了吗？（不对就改 description）
2. **效果**：触发之后，产出对不对？（不对就改正文）

官方推荐用 `skill-creator` 插件做 A/B 基线对比，也就是在全新会话里，分别测「开 skill」和「关 skill」的效果。superpowers 走得更极端，把写 skill 也当成 TDD（测试驱动开发）：先跑基线，看 agent 在没有 skill 时怎么失败（RED），再写 skill 让它变对（GREEN），最后堵住漏洞（REFACTOR）（[writing-skills SKILL.md](https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md)，社区）✅。更多做法见官方 [Skill authoring best practices: Build evaluations first](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)。

---

## Claude Code 实战

### 最小可用 skill：5 分钟写一个「总结改动」skill

下面是官方文档给的入门示例（[CC Docs: skills: Create your first skill](https://code.claude.com/docs/en/skills)，官方，2026-06）✅。

先建目录：

```bash
mkdir -p ~/.claude/skills/summarize-changes
```

再写入 `~/.claude/skills/summarize-changes/SKILL.md`：

```markdown
---
description: Summarizes uncommitted changes and flags anything risky. Use when the user asks what changed, wants a commit message, or asks to review their diff.
---

## Current changes

!`git diff HEAD`

## Instructions

Summarize the changes above in two or three bullet points, then list any risks you notice such as missing error handling, hardcoded values, or tests that need updating. If the diff is empty, say there are no uncommitted changes.
```

两种触发方式都能测：

- **自动触发**：在一个 git 项目里问 `What did I change?`，Claude 看到 description 匹配，就会自动加载并运行。
- **手动触发**：直接输入 `/summarize-changes`。

注意上面那行 `` !`git diff HEAD` `` 的语法。它是一种动态上下文注入：Claude Code 会在把 skill 正文发给 Claude 之前，先执行这条命令，把输出替换进 prompt。所以 Claude 看到的是「已经填好 diff 的指令」，而不是命令本身。这对「需要把实时数据喂给 skill」的场景很有用（[CC Docs: skills: Inject dynamic context](https://code.claude.com/docs/en/skills)，官方）✅。

### 真实 skill 结构参考：superpowers brainstorming

下面是社区 skill 集合 `obra/superpowers` 里 `brainstorming` skill 的真实 frontmatter（从本地缓存读取，社区/开源实践源，2025-2026）：

```yaml
---
name: brainstorming
description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation."
---
```

它的正文包含这些元素：`<HARD-GATE>` 标签（在设计获批之前禁止写代码）、一段名为「Anti-Pattern: This Is Too Simple To Need A Design」的反模式说明、检查清单，以及一张用 graphviz 画的流程图。

这是「纪律强制型 skill」的典型做法：用强硬的指令，加上反模式表和「偷懒话术」对照表，来堵住 agent 想抄近路的借口（[brainstorming/SKILL.md](https://github.com/obra/superpowers/blob/main/skills/brainstorming/SKILL.md)，社区/开源）✅。

> 注：superpowers 的 description 用了 "You MUST use this..." 这种带强烈指令的措辞，和官方 best practices 推荐的第三人称客观描述略有出入。这是社区实践为了提高触发率和强制力，做出的取舍。官方的风格更保守，例如 `Processes PDF files...`。两种写法都能工作，但若想和官方保持一致，用第三人称客观式。

### superpowers 三段链：把 plan→execute→review 强制化

`obra/superpowers` 是目前最完整的社区 skill 集合。它用一组 skill 替代了原生的 plan mode，把 [#031 plan-execute-review 循环](./031-plan-execute-review-loop.md) 做成一条不可绕过的链（[obra/superpowers](https://github.com/obra/Superpowers)，社区/开源，2026）✅。这条链有三段：

1. **`brainstorming`**：任何创意工作之前强制激活。流程是探索上下文，一次只问一个问题，提出 2-3 个带取舍的方案，呈现设计，等用户审批后才动手写 spec。
2. **`writing-plans`**：把 spec 转成详细的实现计划，详细到「假设执行者对代码库零上下文」也能照做的程度。
3. **`executing-plans`**：逐步执行计划，每个检查点暂停验收。

配套还有几个 skill：`test-driven-development`（强制 RED-GREEN-REFACTOR）、`systematic-debugging`、`verification-before-completion`、`requesting-code-review` 等。装一个插件，就拿到一整套「工程纪律」skill。

它的 `using-superpowers` skill 甚至定了一条硬规则：哪怕只有 1% 的可能某个 skill 适用，你也必须调用它（[using-superpowers SKILL.md](https://github.com/obra/superpowers/blob/main/skills/using-superpowers/SKILL.md)，社区）✅。这是用 skill 强制流程的极端形态。

### 控制 skill 的触发行为

四种常见的配置模式（官方，[CC Docs: skills](https://code.claude.com/docs/en/skills)，2026-06）✅：

**1. 有副作用的动作（deploy/commit）——只许手动触发：**

```yaml
---
name: deploy
description: Deploy the application to production
disable-model-invocation: true
allowed-tools: Bash(git push *) Bash(npm run deploy)
---
```

`disable-model-invocation: true` 让 Claude 永远不会自作主张部署。

**2. 背景知识型（如 legacy 系统说明）——只许 Claude 自动用，从 `/` 菜单藏起来：**

```yaml
---
name: legacy-system-context
description: How the legacy billing system works, its quirks and failure modes
user-invocable: false
---
```

**3. 在隔离的 subagent 里跑（避免污染主上下文）：**

```yaml
---
name: deep-research
description: Research a topic thoroughly across the codebase
context: fork
agent: Explore
---
```

这套配置配合 [#032 SubAgent](./032-subagent-when-and-how.md) 的隔离上下文机制使用。

**4. 限定文件路径才触发：**

```yaml
---
paths: apps/web/**/*.{ts,tsx}
---
```

### skill 不触发 / 触发太频繁的排错

先看官方的排错清单（[CC Docs: skills: Troubleshooting](https://code.claude.com/docs/en/skills)，官方，2026-06）✅。

**不触发时，依次检查：**

1. description 里是否含用户会自然说出口的关键词。
2. 用 `What skills are available?` 确认这个 skill 出现在列表里。
3. 试着把请求改得更贴近 description。
4. 如果是 user-invocable，直接 `/skill-name` 手动触发。
5. frontmatter 的 YAML 坏了会导致 metadata 为空，此时 `/name` 还能用，但自动触发失效。跑 `--debug` 看解析错误。
6. description 预算溢出：装了太多 skill 时，描述会被截断、丢掉关键词。跑 `/doctor` 看哪些被截断。可以用 `skillListingBudgetFraction` 调高预算，或把低优先级 skill 设成 `"name-only"`。

**触发太频繁时：** 把 description 写得更具体，或者加 `disable-model-invocation: true` 改成纯手动。

社区对「skill 触发不稳定」的反馈很普遍。有人观察了 100 多个用户后总结，首要原因是 description 太含糊，没告诉 Claude 何时该用（[natesnewsletter: I Watched 100+ People Hit the Same Claude Skills Problems](https://natesnewsletter.substack.com/p/i-watched-100-people-hit-the-same)，社区）⚠️。这是单一社区来源，但与官方排错指引方向一致。

### skill 的内容生命周期（容易被忽略）

有一个工程细节值得留意。skill 被调用后，它的正文会作为一条消息进入对话，并在后续每一轮都留着，Claude Code 不会每轮重新读文件。所以正文要写成「贯穿整个任务的常驻指令」，而不是一次性步骤（[CC Docs: skills: Skill content lifecycle](https://code.claude.com/docs/en/skills)，官方，2026-06）✅。

auto-compaction（上下文自动压缩）发生时，被调用过的 skill 会被重新挂载：每个保留前 5000 tokens，合计预算 25000 tokens，从最近调用的开始往里填。如果你装了太多 skill、又都触发过，老的会被整条丢掉。这也是正文要精简的原因之一。

---

## 横向对比

| 维度 | Claude Code Skill | Cursor Rules | GitHub Copilot |
|------|------------------|--------------|----------------|
| **形态** | `SKILL.md` 文件夹 + frontmatter + 附属脚本/参考（Agent Skills 开放标准） | `.cursor/rules/*.mdc`（带 frontmatter 的规则文件） | `.github/copilot-instructions.md`（单文件）/ `agents.md` personas |
| **加载机制** | 渐进披露：元数据预加载，正文按需，附属文件延迟 | rules 按 `alwaysOn` / `auto` / `model` / `agent` 模式按需注入 | instructions 常驻；agents.md 按角色 |
| **自动触发** | Claude 据 description 自动发现并加载 | `auto`/`agent` 模式据描述匹配 | 无原生自动发现（靠 instructions 常驻） |
| **附带可执行脚本** | ✅ scripts/ 目录，Claude 直接执行 | ❌ 纯规则文本 | ❌ |
| **跨工具可移植** | ✅ Agent Skills 开放标准（VS Code、Gemini CLI、Codex 等也支持） | ❌ Cursor 专属 | ❌ Copilot 专属 |
| **社区生态** | anthropics/skills 官方库 + obra/superpowers 等 | Cursor 官方 rules 库 + 社区 | 社区 agents.md 模板 |

几个关键观察：

- **Claude Code 的 skill 是目前扩展机制里最完备的。** 它支持自动发现、附带可执行脚本、跨工具可移植。Agent Skills 已成为开放标准，VS Code 等工具也支持（[Anthropic 工程博客](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)，官方，2025-12 更新）✅。
- **Cursor 的 `.cursor/rules` 是最接近的对应物。** 它同样有 frontmatter、能按描述自动匹配、支持 alwaysOn/auto 等模式。但它不支持附带可执行脚本，规则只是纯文本指令。
- **Copilot 的 instructions 最简陋。** 单文件常驻，没有渐进披露，也没有自动发现。agents.md 的 personas 提供了角色化，但仍是静态注入。
- **共性趋势**：三家都在向同一个方向靠拢，也就是把领域专长和流程，打包成可复用、按需加载的资源。差异在于 Claude Code 的三层渐进披露机制最成熟，token 经济性最好。

来源：[CC Docs: skills](https://code.claude.com/docs/en/skills)（官方）、[Anthropic: Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)（官方）、[Claude blog: Skills explained](https://claude.com/blog/skills-explained)（官方）。

---

## 反模式

- ❌ **把一次性任务封装成 skill。** skill 的复利来自复用。官方和 superpowers 都点名：一次性方案、项目特定约定、别处已有充分文档的实践，都不该封装。判断信号：你没重复粘贴过 ≥3 次，就别封装。✅（官方 + superpowers）
- ❌ **description 写得太抽象、太宽泛。** Claude 靠 description 在上百个 skill 里做选择。`Helps with documents` 这种描述，让 Claude 无法判断何时触发。官方要求同时写「做什么 + 什么时候用」加关键词。社区观察 100 多个用户后发现，首要痛点就是含糊的 description。✅（官方 + 社区）
- ❌ **在 description 里概括 skill 的流程。** superpowers 实测发现，agent 会把 description 里的流程摘要当捷径，跳过读正文。description 只写「何时用」，流程留给正文。反例：`Use for TDD - write test first, watch it fail, write minimal code`；正例：`Use when implementing any feature or bugfix, before writing implementation code`。✅（社区，superpowers 实测）
- ❌ **SKILL.md 正文过大（>500 行）。** 一旦 skill 被调用，正文每轮都占 token。官方明确要求控制在 500 行以内，超了就拆成附属文件。✅（官方 best practices + CC Docs）
- ❌ **附属引用套娃（深嵌套）。** `SKILL.md → ref.md → detail.md` 会导致 Claude 只 `head -100` 部分读取、丢失信息。官方要求引用只深一层，所有附属文件都直接从 SKILL.md 链接。✅（官方）
- ❌ **给 skill 起模糊名（helper/utils/tools）。** 官方命名规范是用动名词（`processing-pdfs`）或动词短语（`process-pdfs`），别用 `helper`/`utils` 这种没有信息量的名字。也禁用 `anthropic`/`claude` 保留词。✅（官方 best practices）
- ❌ **有副作用的动作不设 `disable-model-invocation: true`。** 不加这个字段，Claude 可能在「看起来代码写完了」时自动触发 deploy/commit。deploy、commit、send-slack 这类动作，一律设成只能手动 `/name`。✅（官方）
- ❌ **装太多 skill 导致 description 预算溢出。** skill 描述会被截断、丢掉关键词，导致该触发时不触发。跑 `/doctor` 检查，把低优先级设成 `"name-only"`，或调高 `skillListingBudgetFraction`。✅（官方）
- ❌ **把「事实/约定」塞进 skill 正文。** 事实该放 CLAUDE.md（常驻但短），流程才该放 skill（按需但长）。官方判断线：CLAUDE.md 的某一节从「事实」变成「流程」时，才该抽成 skill。✅（官方）
- ❌ **skill 写完不测就发布。** 「触发」只说明 Claude 找到了它，不说明它做对了。官方要求分开测触发率和效果，用全新会话做基线对比。superpowers 说得更狠：不测就发布，等于发布未经测试的代码。✅（官方 + superpowers）
- ❌ **skill 不带 frontmatter 或 YAML 写坏。** YAML 坏了，Claude Code 会用空 metadata 加载，此时 `/name` 还能用，但自动触发失效（Claude 没有 description 可匹配）。跑 `--debug` 看解析错误。✅（官方）
- ❌ **skill 正文写满「解释为什么」。** Claude 已经很聪明。官方默认假设是：只补它不知道的。每段都自问「这段配得上它的 token 成本吗？」。✅（官方 best practices）

---

## 延伸

**交叉引用：**

- [#031 plan → execute → review 的正确循环怎么做？](./031-plan-execute-review-loop.md) —— superpowers 的 brainstorming → writing-plans → executing-plans 三段链，把这条循环强制化
- [#032 开几个 agent 并行跑，结果互相踩、被限流、token 指数级炸开——并行到底该开几个？](./032-subagent-when-and-how.md) —— skill 的 `context: fork` + `agent: Explore` 让 skill 在隔离的 subagent 里跑
- [#030 TDD 在 AI coding 里怎么做？](./030-tdd-in-ai-coding.md) —— superpowers 的 `test-driven-development` skill 把 TDD 铁律强制化；`writing-skills` skill 本身就是把 TDD 用在文档上
- [#013 压缩一次它就忘了刚定的方案——哪些决策必须写进 memory 才扛得住 compact](../02-context-engineering/013-memory-what-to-remember.md) —— CLAUDE.md（事实常驻）与 skill（流程按需）的边界

**参考资料：**

- [Extend Claude with skills — Claude Code Docs](https://code.claude.com/docs/en/skills) —— 官方头号参考：skill 创建、frontmatter 全字段、触发控制、动态上下文注入、排错、skill 内容生命周期（官方，2026-06）✅
- [Skill authoring best practices — Claude API Docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) —— 官方写作指南：精简原则、自由度、description 写法、渐进披露模式、反模式、评估流程（官方，2026）✅
- [Equipping agents for the real world with Agent Skills — Anthropic](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) —— 官方设计哲学：渐进披露三层、skill 与代码执行、开发评估指南（官方，2025-10，2025-12 更新为开放标准）✅
- [Skills explained — Claude blog](https://claude.com/blog/skills-explained) —— 官方边界厘清：skill vs MCP vs subagent vs Project vs prompt，含组合用例（官方，2026-03）✅
- [writing-skills SKILL.md — obra/superpowers](https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md) —— 社区最完整的「如何写 skill」指南：TDD 映射、description 只写触发条件、反模式表、测试方法论（社区/开源，2025-2026）✅
- [brainstorming SKILL.md — obra/superpowers](https://github.com/obra/superpowers/blob/main/skills/brainstorming/SKILL.md) —— 纪律强制型 skill 的真实结构范例：HARD-GATE、反模式段、流程图（社区/开源，2025-2026）✅
- [obra/superpowers](https://github.com/obra/Superpowers) —— 社区最完整的 skill 集合：brainstorming/writing-plans/executing-plans/TDD 等链式 skill（社区/开源，2026）✅
- [Claude Code Skills vs Slash Commands — MindStudio](https://www.mindstudio.ai/blog/claude-code-skills-vs-slash-commands-2) —— skill vs command 对比：自动触发 vs 手动、何时用哪个（社区，2026-04）⚠️
- [I Watched 100+ People Hit the Same Claude Skills Problems — natesnewsletter](https://natesnewsletter.substack.com/p/i-watched-100-people-hit-the-same) —— 社区观察：skill 不触发的首要原因是含糊的 description（社区，2025-2026）⚠️
- [I Built 106 Claude Skills. 12 Dos and Don'ts — Medium](https://medium.com/@mohit15856/i-built-106-claude-skills-here-are-the-12-dos-and-donts-i-wish-i-d-known-earlier-8f4f13903f28) —— 实战经验：坏的 description 不告诉 Claude 何时用（社区，2025-2026）⚠️
- [Specification — Agent Skills (agentskills.io)](https://agentskills.io/specification) —— Agent Skills 开放标准规范：SKILL.md 结构、frontmatter 字段（社区/标准，2025-12）✅
- [Use Agent Skills in VS Code — VS Code Docs](https://code.visualstudio.com/docs/agent-customization/agent-skills) —— 跨工具可移植性的证据：VS Code 也支持 Agent Skills 标准（官方，2026）✅

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验——你封装过哪个 skill 解决了重复流程 / 或踩过 description 写太抽象不触发的坑 / superpowers 启用前后工作流的变化]`
