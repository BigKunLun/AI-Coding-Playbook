# 032. 开几个 agent 并行跑，结果互相踩、被限流、token 指数级炸开——并行到底该开几个？

> 难度：高级
> 主题：执行工作流
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：决策题

> ⏰ 时效声明：本篇的版本相关事实（Explore 自 v2.1.198 起继承主会话模型且 Claude API 上封顶 Opus、`model` frontmatter 默认 `inherit`、agent frontmatter 支持的字段清单、fork 从 v2.1.212 起命令改名为 `/subtask`、Explore/Plan 跳过 CLAUDE.md 与 git status）已于 **2026-08-03** 对照 [CC Docs: sub-agents](https://code.claude.com/docs/en/sub-agents) 逐项复核。Claude Code 迭代快，版本号类细节请以官方文档为准。

## TL;DR

SubAgent 的核心价值是**上下文隔离**，不是「并行更快」。

所谓上下文隔离，指它在一个全新的、干净的上下文窗口里干活。跑测试、翻日志、爬文档这类啰嗦的中间输出全部留在它自己的窗口里，只把凝练的摘要交回主会话。这对应 Anthropic 官方上下文工程四原则里的 isolate（隔离）。

一句话决策框架如下。

**该用 SubAgent**：任务会产出大量你之后不再需要的中间输出（跑测试、读日志、爬文档、大面积探索代码库），或者有两个以上互不依赖的子任务可以并行。

**不该用**：任务需要频繁来回、多个阶段共享同一份上下文（规划、实现、测试是同一条线），或者子任务之间强依赖、要改同一批文件。这时隔离的代价（协调成本、无法共享中间状态）大于收益。

三条要记住的结论：

1. **SubAgent 的本质是上下文隔离，不是并行加速**。官方原话：每个 SubAgent「starts with a fresh, isolated context window. It doesn't see your conversation history」。它看不到你的对话历史、已调用的 skill、已读过的文件，只拿到一段委派摘要就开干（[CC Docs: sub-agents](https://code.claude.com/docs/en/sub-agents)，官方，2026-06）✅。
2. **隔离是有代价的，而且代价不小**。Anthropic 自家多 Agent 研究系统的数据显示，多 Agent 架构的 token 消耗约是普通聊天的 **15 倍**。官方还明确承认「most coding tasks involve fewer truly parallelizable tasks than research」，即编码任务真正能并行的子任务比研究任务少得多（[How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)，官方，2025）✅。
3. **隔离带来的判断力优势，在正确性敏感的任务上最值钱**。让一个全新上下文的 SubAgent 只看 diff 加验收标准来挑刺，官方反复推荐这种做法。核心原因是写代码的人和评审的人不能共用同一个上下文（[Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)，官方，2026-06；与 [#031 循环](./031-plan-execute-review循环.md) 同源）✅。

---

## 为什么

### 1. 官方定调：SubAgent 是「上下文隔离」的一等公民

Anthropic 的上下文工程框架把所有上下文操作分成四类：write、select、compress、isolate。其中 isolate 就是用 SubAgent 把工作切到独立上下文窗口里，防止主上下文被污染（[Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)，官方，2025-09）✅。

Claude Code 的 SubAgent 文档把这条讲得很具体。每个 SubAgent 启动时拿到的是一个干净窗口：

> "Each subagent starts with a fresh, isolated context window. It doesn't see your conversation history, the skills you've already invoked, or the files Claude has already read. Claude composes a delegation message that summarizes the task, and the subagent works from there."
> — [CC Docs: sub-agents: Manage subagent context](https://code.claude.com/docs/en/sub-agents)（官方，2026-06）✅

它的初始上下文核心是四样：自己的 system prompt、Claude 写的一段委派消息、CLAUDE.md 与记忆层级、以及会话开始时的一个 git 快照。另有两样按需注入：`skills` 字段预加载的 skill 内容，以及可用于 `SendMessage` 的兄弟 agent 名册。对话历史完全不继承（[CC Docs: sub-agents](https://code.claude.com/docs/en/sub-agents)，官方，2026-06）✅。

这里有两个例外要注意。第一，内置的 `Explore` 和 `Plan` 会跳过 CLAUDE.md 和 git status，好让研究又快又便宜。第二，有一种叫 fork 的变体，它继承父会话的全部历史，而不是全新上下文，后文详述。

这条机制带来的直接收益是：啰嗦操作（跑全量测试、读 10 万行日志、爬一堆文档）的全部输出都留在 SubAgent 自己的窗口里，主会话只收摘要。官方给了这个范式：

> "Use a subagent to run the test suite and report only the failing tests with their error messages"
> — [CC Docs: sub-agents: Isolate high-volume operations](https://code.claude.com/docs/en/sub-agents)（官方，2026-06）✅

还有一个更关键的工程性质：SubAgent 的对话记录存在独立文件里，主会话做 compact（压缩上下文）时它不受影响。也就是说它是一个扛得住 compact 的工作面，这与 [#012 上下文爆炸](../02-上下文工程/012-上下文窗口要爆了.md) 直接呼应（[CC Docs: sub-agents: Resume subagents](https://code.claude.com/docs/en/sub-agents)，官方，2026-06）✅。「SubAgent 隔离上下文」这个论断有官方文档加官方博客两个来源支撑 ✅。

### 2. 代价很真实：token 15 倍、协调成本、无法共享中间状态

隔离不是免费的。Anthropic 在自家多 Agent 研究系统的复盘里给了最硬的量化：

> "agents typically use about 4× more tokens than chat interactions, and multi-agent systems use about **15× more tokens** than chats… multi-agent systems require tasks where the value of the task is high enough to pay for the increased performance."
> — [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)（官方，2025）✅

官方甚至直接点名，编码任务往往是多 Agent 的差场景：

> "some domains that require all agents to share the same context or involve many dependencies between agents are not a good fit for multi-agent systems today. For instance, **most coding tasks involve fewer truly parallelizable tasks than research**, and LLM agents are not yet great at coordinating and delegating to other agents in real time."
> — [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)（官方，2025）✅

代价为什么这么大？有三个结构性原因。

第一，**协调成本增长很快**。官方原话是「rapid growth in coordination complexity」。早期 Agent 会犯这些错：为一个简单查询启动 50 个 SubAgent、无休止地在网上找不存在的来源、用过量更新互相干扰（[multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)，官方）✅。

第二，**SubAgent 之间无法共享中间状态**。它们只能把结果报告回主 Agent，主 Agent 再分发给下一个。官方把这称为「game of telephone」，也就是传话游戏，信息在多级传递中会失真。官方给的解法是让 SubAgent 直接把产物写到文件系统，只回传一个引用（[multi-agent research system: Appendix](https://www.anthropic.com/engineering/multi-agent-research-system)，官方）✅。

第三，**同步执行造成瓶颈**。目前主 Agent 要同步等 SubAgent 完成才能继续。主 Agent 无法中途纠偏，SubAgent 之间也无法协调，整个系统可能被一个慢的 SubAgent 卡住（[multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)，官方）✅。

#### 15 倍还只是均值：SubAgent 能自己再 spawn SubAgent

上面的 15 倍是「你按计划开几个 agent」时的账。真实社区案例里更贵的一类是：**你只派了 1 个，它自己长成了几十个。**

`general-purpose` 这个内置 SubAgent 拿的是全工具集，其中包含派活的 Agent 工具本身。也就是说它能再派子 agent，子 agent 还能再派，形成一棵没有深度上限、也没有总数上限的扇出树。一位用户报告：只发了一句「research Venmo integration options」，最后同时在跑 **48 个以上**后台 agent，其中大量是重复劳动——4 个 agent 在查同一个 Wise API、3 个在查同一个 Apple Pay P2P。他描述的原话是「agents kept spawning faster than I could stop them manually」，即新 agent 冒出来的速度比他手动停的速度还快；同样的情况在不同会话里复现了两次（[GH #68110](https://github.com/anthropics/claude-code/issues/68110)，社区，2026-06，issue 仍 open）⚠️。

同期还有两个同族案例：Agent Teams 带 5–8 个队友时，主会话被队友的 idle 通知和重复任务派发反复唤醒，**13%–22% 的输入 token 花在纯粹的「收到」上**（[GH #47930](https://github.com/anthropics/claude-code/issues/47930)，社区，2026-04）⚠️；deep-research 工作流一次扇出约 75 个并发校验 agent，只要其中任何一个没按 schema 返回结构化输出，整轮直接中止，三次尝试烧掉约 350 万 token、零可用产出（[GH #65500](https://github.com/anthropics/claude-code/issues/65500)，社区，2026-06）⚠️。

三个案例的共同点是同一个失效模式：**并行的开销是乘法的，但失败是全局的**。扇出越宽，任意一个分支跑偏或空转，代价越是按分支数整体翻倍。这就是「更慢更贵」的最极端形态——不是你选错了场景，是你根本没意识到自己开了多少个。

对应的三条防线，都在下文「怎么做」里展开：给会派活的 agent 用 `disallowedTools` 掐掉它继续派活的能力（第一步末尾）、按复杂度定 agent 数量而不是能开多少开多少（第二步）、以及派完活用 `/tasks` 和 `/usage` 回检实际跑了几个（第五步）。

agent teams 是 Claude Code 较新的多会话协调机制。它的文档用一张对照表把这个权衡讲得很清楚（[CC Docs: agent-teams: Compare with subagents](https://code.claude.com/docs/en/agent-teams)，官方，2026-06）✅：

|  | Subagents | Agent teams |
|---|---|---|
| 上下文 | 独立窗口；结果回传给调用者 | 独立窗口；完全独立 |
| 通信 | **只能向主 Agent 报告** | 队友之间直接互发消息 |
| 协调 | 主 Agent 管理一切 | 共享任务列表，自协调 |
| 适合 | 只关心结果的聚焦任务 | 需要讨论和协作的复杂工作 |
| Token 成本 | 较低（摘要回传） | 较高（每个队友是独立 Claude 实例） |

「隔离有代价」这个论断有官方研究博客加官方 agent teams 文档两个来源支撑 ✅。

### 3. 什么时候多 Agent 真的值？

既然代价是 15 倍 token，收益什么时候能盖过它？Anthropic 给了三组数据。

**性能提升显著，但只在研究类任务上**。「Opus 当主 Agent、Sonnet 当 SubAgent」的多 Agent 系统，在 Anthropic **内部研究类评测（internal research eval）** 上比单 Agent Opus 高出 **90.2%**。原文是 "outperformed single-agent Claude Opus 4 by 90.2% on our internal research eval"——评测对象是「开放式信息搜集」，不是写代码。同一篇文章下面就明说编码任务可并行子任务比研究少，所以**不要把这个 90.2% 迁移到编码场景上**（[multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)，官方，2025）✅。

**token 用量本身就解释了 80% 的性能差异**。在 BrowseComp 评测上，token 用量解释了 80% 的差异，另外两个因素是工具调用次数和模型选择。结论是多 Agent 架构本质上就是为问题花够多的 token，把工作分散到多个独立上下文窗口，以此增加并行推理容量（同上）✅。

**并行化把延迟砍到十分之一**。引入并行后，复杂查询的研究时间最多缩短 90%（同上）✅。

但官方划的适用边界同样明确。多 Agent 在这三类任务上才值回票价：

> "multi-agent systems excel at valuable tasks that involve **heavy parallelization, information that exceeds single context windows, and interfacing with numerous complex tools**."
> — [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)（官方，2025）✅

> 个人观点（小C）：很多人把多 Agent 理解成「让 AI 干活更快」，这是误读。官方数据说的其实是另一件事：多 Agent 的本质是用 15 倍的 token，换取在「单上下文装不下」的任务上，从做不出来变成做得出来。它买的是能力边界，不是速度。如果你的任务一个上下文就装得下，也没有真正可并行的子任务，那多 Agent 只会让你白花 15 倍的钱，还因为协调开销更慢。

---

## 怎么做

决策题的核心是一张「何时用、何时不用」的判断矩阵。按下面五步走。

### 第一步：过「该不该用 SubAgent」的判断矩阵

四个维度逐个打分。任意一个维度命中「该用」，就该考虑。

| 维度 | ✅ 该用 SubAgent | ❌ 不该用（留在主会话） |
|------|------------------|------------------------|
| **上下文消耗** | 任务会产出大量啰嗦输出（测试、日志、文档、大范围探索），你**不再需要逐字保留** | 任务输出轻量，或后续多轮还要引用这些输出 |
| **任务独立性** | 两个以上子任务**互不依赖**、各改各的文件/各查各的领域 | 子任务之间有先后依赖（A 的输出是 B 的输入） |
| **来回频率** | 任务可自包含完成、只回传一个摘要 | 需要频繁和你来回对齐、迭代细化 |
| **上下文共享** | 各子任务不需要看到彼此的中间状态 | 规划、实现、测试共享同一份理解，需要上下文连贯 |

**一条硬红线，压过上面所有打分**：不要让多个并行 SubAgent 改同一批文件。它们看不到彼此的中间状态，只能各写各的，后写的会覆盖先写的。真需要并行改动同一个仓库，给每个 SubAgent 加 `isolation: worktree`（frontmatter 字段，官方，让它在临时 git worktree 里拿一份独立的仓库副本），或者干脆串行。

**第二条硬红线：别让 SubAgent 自己再派活。** 前面 #68110 那棵 48 个 agent 的扇出树，根因就是 `general-purpose` 继承了全工具集，其中包含派活工具。要掐断递归，自定义 agent 时用 `tools` 白名单显式列出它需要的工具（不写派活工具），而不是省略 `tools` 让它继承全部。比如调研型 agent 写 `tools: Read, Grep, Glob, WebFetch` 就够了。验证方法：派活后跑 `/tasks`，看在跑的任务数是不是等于你派的数量——多出来的就是它自己生的。

判断时可以对照官方给的「何时该留在主会话」清单：需要频繁来回或迭代细化、多阶段共享大量上下文、快速定点改动、以及延迟敏感的场景（因为 SubAgent 要从头攒上下文）（[CC Docs: sub-agents: Choose between subagents and main conversation](https://code.claude.com/docs/en/sub-agents)，官方，2026-06）✅。

### 第二步：决定并行、串行还是后台

能用之后，还要选执行模式。社区站点 Claude Fast 整理了一套路由框架，概念与官方一致，但具体路由表是该站的整理（[Claude Code Sub-Agents: Parallel vs Sequential Patterns](https://claudefa.st/blog/guide/agents/sub-agent-best-practices)，社区，2026-06）⚠️：

| 模式 | 什么时候用 | 选错了的后果 |
|------|-----------|-------------|
| **并行** | 子任务跨**独立领域、不碰同一批文件** | 合并冲突、状态不一致 |
| **串行（chain）** | 存在依赖或共享资源（schema→API→前端；研究→规划→实现；实现→测试→安全审计） | 把本可并行的独立工作硬串起来，浪费时间 |
| **后台（background）** | 你想继续干别的、让 SubAgent 异步跑（如调研） | 结果忘了检查就丢了 |

并行有一条硬规则：只有当各个 agent 改的是不同文件时才成立（同上，社区）⚠️。

至于该开几个 agent，官方建议按复杂度定规模（[multi-agent research system: Scale effort to query complexity](https://www.anthropic.com/engineering/multi-agent-research-system)，官方，2025）✅：

| 任务复杂度 | agent 数 | 每个 agent 的工具调用次数 |
|---|---|---|
| 简单事实查找 | 1 个 | 3–10 次 |
| 直接对比（两三个候选方案/模块） | 2–4 个 | 各 10–15 次 |
| 复杂研究（多领域、单上下文装不下） | 10 个以上，分工必须写明确 | 不设上限 |

「10 个以上」和后面反模式里官方复盘的失败模式「为一个简单查询启动 50 个 SubAgent」不矛盾，线画在**任务复杂度**上而不是数字上：判断标准是「每个 agent 是否有一块别人不重叠的领域，并且能靠 10 次以上的工具调用把它填满」。如果你说不出第 6 个 agent 负责什么、它和第 3 个有什么区别，那就是多开了。真正需要 10 个以上的场景在日常编码里基本不存在——编码任务用 2–4 个是常态。

### 第三步：写好委派指令

委派指令是 SubAgent 成败的关键。SubAgent 看不到你的对话历史，它只能看到你给它的那段委派消息，所以这段话的信息密度决定一切。

社区总结的失败模式很准：「Most sub-agent failures aren't execution failures — they're invocation failures」，意思是绝大多数 SubAgent 出问题不是执行没做好，而是你派活时没说清楚（[Claude Fast](https://claudefa.st/blog/guide/agents/sub-agent-best-practices)，社区）⚠️。

官方在多 Agent 复盘里给了同样的教训：

> "Without detailed task descriptions, agents duplicate work, leave gaps, or fail to find necessary information… Each subagent needs an objective, an output format, guidance on the tools and sources to use, and clear task boundaries."
> — [multi-agent research system: Teach the orchestrator how to delegate](https://www.anthropic.com/engineering/multi-agent-research-system)（官方，2025）✅

一条合格的委派指令应包含四要素：目标、涉及的文件或范围、期望的输出格式、明确的边界。

### 第四步：决定 SubAgent 还是 Agent Team

如果子任务之间需要互相讨论、互相质疑，而不是各干各的回传结果，那就用 Agent Team，而不是 SubAgent。

官方给的判断线是：SubAgent 适合「只有结果重要」的场景，Agent Team 适合「需要讨论和协作」的场景（[CC Docs: agent-teams: Compare with subagents](https://code.claude.com/docs/en/agent-teams)，官方，2026-06）✅。典型的 Agent Team 场景有两个：一是竞争性假设的调试，比如 5 个队友各试一种理论、互相反驳；二是跨层改动，比如前端、后端、测试各配一个队友。

注意 Agent Team 默认关闭，需要设 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 启用，而且 token 成本更高（同上）✅。

### 第五步：事后回检，确认这次派活是赚的

决策题最缺的就是回检手段。派完活跑这三个命令，用四条信号判断这次 SubAgent 是不是白派了。

```
/context    # 看主上下文占用（彩色格子图 + 各项占比）
/usage      # 看这次会话的用量；/cost 是它的别名
/tasks      # 看后台 SubAgent 的运行/完成状态
```

正确的做法是**派活前先跑一次 `/context` 记下占用百分比**，派完活再跑一次对比。

| 信号 | 说明这次派对了 | 说明不该派 |
|---|---|---|
| **主上下文占用** | SubAgent 干完后主上下文只多了一段摘要，占用增幅明显小于任务本身的输出量 | 占用涨得和自己干差不多——说明这活的输出本来就不啰嗦，隔离没省下什么 |
| **回传内容** | 回来的是结论/清单/失败用例，你能直接拿来用 | 回来的是「我看了一下，你要不要我继续」，还得再派一轮——说明委派指令写糊了，或者这活本来就该留主会话 |
| **来回轮数** | 一次派活一次交付 | 你和 SubAgent 之间来回超过 2 轮——隔离的协调成本已经吃掉收益，退回主会话 |
| **耗时 vs 用量** | 并行任务的墙上时间明显短于串行 | `/usage` 显示用量翻倍但耗时没减少——典型的「把不可并行的活硬并行了」 |

一条经验判据：**如果你发现自己在给 SubAgent 补充它本该知道的背景，那这活就不该用 SubAgent**，要么改用 fork（继承上下文），要么直接留在主会话。

（`/context` 输出格式随版本变化，以上为 2026-08 的行为；`/context` 的超限警告需要 v2.1.216 及以上 —— [CC Docs: commands](https://code.claude.com/docs/en/commands)，官方，2026-08）✅

---

## Claude Code 实战

### 三种调用方式（由轻到重）

官方给了三种从轻到重的调用姿势（[CC Docs: sub-agents: Invoke subagents explicitly](https://code.claude.com/docs/en/sub-agents)，官方，2026-06）✅。

1. **自然语言**：在 prompt 里点名 SubAgent，由 Claude 决定是否委派。例如 `Use the test-runner subagent to fix failing tests`。
2. **@-mention**：写 `@"code-reviewer (agent)"`，可以保证该 SubAgent 一定会跑，不交给 Claude 自行判断。
3. **整会话当 SubAgent 跑**：用 `claude --agent code-reviewer`，整个会话都用该 SubAgent 的 system prompt、工具限制和模型。也可以在 `.claude/settings.json` 里写 `"agent": "code-reviewer"` 设为默认。

### 内置 SubAgent：Explore / Plan / general-purpose

不用自己配，Claude Code 自带三个（[CC Docs: sub-agents: Built-in subagents](https://code.claude.com/docs/en/sub-agents)，官方，2026-06）✅：

| 内置 Agent | 模型 | 工具 | 用途 |
|-----------|------|------|------|
| **Explore** | 继承主会话（Claude API 上限封顶到 Opus） | 只读（无 Write/Edit） | 文件发现、代码搜索、代码库探索；可指定 `quick` / `medium` / `very thorough` |
| **Plan** | 继承主会话 | 只读 | plan mode 下做代码库调研，探索输出留在独立窗口，主会话保持只读 |
| **general-purpose** | 继承主会话 | 全工具 | 复杂多步任务，既要探索又要改代码 |

> ⚠️ 时效：早期版本的 Explore 固定跑 Haiku，从 v2.1.198 起改为继承主会话模型（在 Claude API 上封顶到 Opus，永远不会比你为会话选的模型更贵）。如果想让 Explore 继续走低成本模型，可以在 `.claude/agents/` 里定义一个同名 `Explore` 并写 `model: haiku`，覆盖内置的（[CC Docs: sub-agents: Built-in subagents](https://code.claude.com/docs/en/sub-agents)，官方，2026-06）✅。

Explore 和 Plan 会跳过 CLAUDE.md 和 git status 来保持轻量；其他所有 SubAgent 都会加载它们。

### 自定义 SubAgent：`.claude/agents/` 一个 Markdown 文件

最小可用的只读评审 agent，存成 `.claude/agents/code-reviewer.md`：

```yaml
---
name: code-reviewer
description: 代码审查专家。写完或修改代码后主动用。
tools: Read, Grep, Glob
model: inherit
---

你是资深代码审查者。被调用时：
1. 读 PLAN.md 或需求描述，拿到验收标准
2. 只看本次修改过的文件
3. 按优先级输出：Critical / Warning / Suggestion
```

存放位置有两级。项目级放 `.claude/agents/`，进版本控制、团队共享；用户级放 `~/.claude/agents/`，跨项目可用。

`tools` 是白名单，省略则继承全部工具；`disallowedTools` 是黑名单；两个都写时先扣黑名单再解析白名单（[CC Docs: sub-agents](https://code.claude.com/docs/en/sub-agents)，官方，2026-08 复核）✅。

#### ⚠️ 加了 Bash，这个 agent 就不是只读的了

很多模板写 `tools: Read, Grep, Glob, Bash` 并注释「只读」，这是错的。`Bash` 是一个能执行任意 shell 命令的工具，agent 完全可以 `echo x > src/app.ts`、`sed -i`、`git checkout .`、`rm`。官方文档说这套配置「can't edit files, write files」，指的是 Edit / Write **这两个工具**不可用，不代表文件系统不可写。

Claude Code 的 agent frontmatter **没有** `allowed-tools` 这类按命令参数细分的字段（截至 2026-08，官方支持的字段只有 `name` / `description` / `tools` / `disallowedTools` / `model` / `permissionMode` / `maxTurns` / `skills` / `mcpServers` / `hooks` / `memory` / `background` / `effort` / `isolation` / `color` / `initialPrompt`）。所以要「能跑命令但不能写文件」，只有两条正经路子：

**路子一（推荐，最简单）：真只读就别给 Bash。** 评审、探索这类任务用 `tools: Read, Grep, Glob` 就够，git diff 的内容让主会话贴给它，或者让它读文件自己比对。

**路子二：给 Bash，但用 frontmatter 里的 `PreToolUse` hook 逐条拦截。** 这是官方文档给的机制，可直接复制：

`.claude/agents/code-reviewer.md`：

```yaml
---
name: code-reviewer
description: 代码审查专家。写完或修改代码后主动用。
tools: Read, Grep, Glob, Bash
model: inherit
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/allow-readonly-git.sh"
---

你是资深代码审查者。只允许跑 git diff / git log / git show，不要尝试修改任何文件。
```

`scripts/allow-readonly-git.sh`（hook 从 stdin 拿到 JSON，退出码 2 表示拦截并把 stderr 回给 agent）：

```bash
#!/bin/bash
# 只放行只读 git 命令，其余一律拦截
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

case "$COMMAND" in
  "git diff"*|"git log"*|"git show"*|"git status"*)
    exit 0
    ;;
esac

echo "Blocked: 该 agent 只允许 git diff / log / show / status，收到：$COMMAND" >&2
exit 2
```

**怎么验证做对了**：

```bash
chmod +x ./scripts/allow-readonly-git.sh   # macOS/Linux 上不加这步 hook 会直接失败，等于没拦
```

然后在 Claude Code 里派活验证：

```
用 code-reviewer subagent 跑一句 `echo hacked > /tmp/cc-hook-test.txt`
```

预期：命令被拦下，SubAgent 收到 `Blocked: 该 agent 只允许 git diff / log / show / status，收到：echo hacked > /tmp/cc-hook-test.txt`。再确认文件确实没被创建：

```bash
test -f /tmp/cc-hook-test.txt && echo "拦截失败：文件被写出来了" || echo "OK：hook 生效"
```

预期输出 `OK：hook 生效`。如果输出的是「拦截失败」，先检查脚本有没有可执行权限、路径是否相对于项目根目录、以及项目级 agent 的 frontmatter hook 是否需要先通过 workspace trust 弹窗（v2.1.218 起项目级 agent 的 frontmatter hook 要先信任该目录才会运行；用户级 `~/.claude/agents/` 不需要）（[CC Docs: sub-agents: Conditional rules with hooks](https://code.claude.com/docs/en/sub-agents)，官方，2026-08 复核）✅。

另外提醒一句：`permissions.deny` 里的规则（如 `"Bash(rm:*)"`）是**整个会话生效**，不是只对某个 agent 生效，别把它当成 agent 级沙箱。

写 `model: haiku` 可以把便宜的任务路由到快模型。官方明确说这是「control costs by routing tasks to faster, cheaper models」的用法，即通过把任务派给更快更便宜的模型来控制成本（[CC Docs: sub-agents](https://code.claude.com/docs/en/sub-agents)，官方）✅。

如果想全局统一，可以设 `CLAUDE_CODE_SUBAGENT_MODEL`，强制所有 SubAgent 用某个模型。

### Fork：需要共享上下文时的特例

普通 SubAgent 是全新上下文，fork 正好反过来：它继承父会话的全部历史，但它自己的工具调用不进主上下文，只回最终结果（[CC Docs: sub-agents: Fork the current conversation](https://code.claude.com/docs/en/sub-agents)，官方，2026-06）✅。

fork 适合两种场景。一是某个命名 SubAgent 需要太多背景才能干活，这时 fork 比从头攒上下文更划算。二是想在同一个起点上并行试多种方案。fork 还能复用父会话的 prompt cache，因此比全新 SubAgent 便宜。

**命令是什么、要不要设环境变量，按版本分三段说清楚**（截至 2026-08，[CC Docs: sub-agents: Fork the current conversation](https://code.claude.com/docs/en/sub-agents)，官方）✅：

| 版本 | 你手动开 fork 的命令 | 是否需要环境变量 |
|---|---|---|
| v2.1.212 及以后 | `/subtask <任务>` | 不需要 |
| v2.1.161 – v2.1.211 | `/fork <任务>` | 不需要 |
| v2.1.117 – v2.1.160 | `/fork <任务>` | 需要 `CLAUDE_CODE_FORK_SUBAGENT=1` |

**表格有一个例外**：在 v2.1.212 及以后，如果你关掉了 agent view（后台会话面板），`/subtask` 不可用，此时改由 `/fork` 来起 fork 子任务；只有 agent view 开着时，`/fork` 才是「把整个会话复制成一个独立后台会话」。官方原文：「When agent view is turned off, `/subtask` isn't available and `/fork` starts the forked subagent instead; otherwise `/fork` copies the whole session into a new background session」（[CC Docs: sub-agents: Fork the current conversation](https://code.claude.com/docs/en/sub-agents)，官方，2026-08 复核）✅。

也就是说，在 agent view 默认开启的情况下，**当前版本直接敲 `/subtask` 就行，不用先设环境变量**：

```
/subtask draft unit tests for the parser changes so far
```

`CLAUDE_CODE_FORK_SUBAGENT` 现在管的是另一件事：设成 `1` 让 Claude 自己也能主动 spawn fork（并且所有 SubAgent 一律转后台跑），设成 `0` 则彻底关掉 fork 模式。这跟你手敲 `/subtask` 是两回事。

注意 v2.1.212 起、且 agent view 开启时，`/fork` 被改成了另一个意思：把整个会话复制成一个独立的后台会话，而不是开一个 fork 子任务。所以如果你照老教程敲 `/fork` 发现行为不对，先跑 `claude --version` 对一下版本，再确认 agent view 的开关状态。

**怎么验证**：

```bash
claude --version   # 看是否 ≥ 2.1.212，决定敲 /subtask 还是 /fork
```

fork 起来后，它会出现在 prompt 下方的面板里；也可以用 `/tasks` 看在跑的子任务列表，完成后结果会以一条消息回到主会话。

### 并行调研的最小范式

```
Research the authentication, database, and API modules in parallel
using separate subagents
```

每个 SubAgent 独立探索自己的领域，Claude 再综合结果。这只在各条研究路径互不依赖时效果最好（官方原话，[CC Docs: sub-agents: Run parallel research](https://code.claude.com/docs/en/sub-agents)）✅。如果需要持续并行、或超出单个上下文，就升级到 Agent Team。

### 对抗式 review：SubAgent 最值的用法

官方反复推荐的做法是：让一个全新上下文的评审者只看 diff 和验收标准，看不到写代码时的理由。

```
用一个 subagent 评审 [feature] 的 diff，对照 PLAN.md：
检查每条需求是否实现、边界 case 是否有测试、
有没有改动任务范围外的东西。报 gap，不报风格偏好。
```

因为评审者是 SubAgent，执行会话会直接收到 gap 并修复、再审，你不用在两个窗口之间复制粘贴（[Best practices: Add an adversarial review step](https://code.claude.com/docs/en/best-practices)，官方，2026-06）✅。详见 [#031 循环](./031-plan-execute-review循环.md) 的 Phase ④。

---

## 横向对比

| 维度 | Claude Code | Cursor | GitHub Copilot |
|------|------------|--------|----------------|
| **多 Agent 机制** | SubAgent（会话内，全新隔离上下文，结果回传）+ Agent Teams（独立会话，队友互发消息，实验性）| **Cloud Agents**（原名 Background Agents）：每个任务一个隔离云 VM，clone 仓库→开分支→交 PR；Composer 最多 8 个并行 | Copilot coding agent（云沙箱，自主跑 issue→PR）；无文档化的会话内 subagent 模型 |
| **隔离粒度** | 进程级 + 独立上下文窗口 + 对话记录独立持久化（抗 compact）| **VM 级**：一次性文件系统，完全不影响本地；可自托管 | 云沙箱环境 |
| **并行规模** | 受本地资源约束；Agent Team 建议 3-5 个队友起步 | Composer 一个 prompt 最多 **8 个** agent 并行（worktree/远程机隔离，官方 changelog 2.0 证实 ✅）；云 Agent 数量随订阅额度 | 单任务为主 |
| **agent 间通信** | SubAgent 只能回传主 Agent；Agent Team 可互发消息 | 各自独立产出 PR，无原生互发消息 | 无 |
| **异步/后台** | `Ctrl+B` 后台跑；frontmatter `background: true`；`/subtask` 起 fork 异步（v2.1.212 前叫 `/fork`）| 云端异步，关电脑也继续跑；产出截图/视频证据 | 云端异步 |
| **Token 成本透明度** | 官方明确：多 Agent 约 15× 聊天 token；Agent Team 线性随队友数增长 | 按订阅/额度计，单任务成本不透明 | 按额度计 |

三点关键观察。

**隔离哲学不同**。Claude Code 的 SubAgent 是上下文级隔离：同一台机器、同一个仓库，但独立上下文窗口，主打防止主上下文爆掉加对抗式 review。Cursor Cloud Agents 是环境级隔离：独立 VM、一次性文件系统，主打无人值守的长任务加并行 PR，但 token 和协调成本不透明（[Cursor 官方: self-hosted cloud agents](https://cursor.com/blog/self-hosted-cloud-agents)、[Digital Applied: Cursor Cloud Agents](https://www.digitalapplied.com/blog/cursor-cloud-agents-isolated-vms-guide)，官方/社区，2025-2026）✅。

**Claude Code 把「何时不用」说得最坦诚**。官方明确说过，编码任务真正可并行的子任务比研究少，以及多 Agent 需要任务价值高到能付得起 15 倍 token（[multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)，官方）✅。Cursor 和 Copilot 倾向于鼓励多用 agent，较少讨论协调代价。需要说明的是，Cursor/Copilot 的「不鼓励用」场景多为社区推断，不是官方明确表述 ⚠️。

**共性趋势**。三家都在向「让 agent 在隔离环境里自主跑、产出 PR」靠拢。差异在于：Claude Code 的 SubAgent 是轻量、会话内、能做对抗式 review 的工具，而 Cursor/Copilot 的 cloud agent 是重量、跨会话、面向长任务的工具。它们解决的不是同一个问题。

来源：[CC Docs: sub-agents](https://code.claude.com/docs/en/sub-agents) / [agent-teams](https://code.claude.com/docs/en/agent-teams)（官方）、[Cursor: self-hosted cloud agents](https://cursor.com/blog/self-hosted-cloud-agents)（官方）、[Digital Applied](https://www.digitalapplied.com/blog/cursor-cloud-agents-isolated-vms-guide)（社区）。

---

## 反模式

- ❌ **什么都丢给 SubAgent**。官方明确：需要频繁来回、多阶段共享上下文、快速定点改动时，应留在主会话。SubAgent 要从头攒上下文，延迟更高。✅（官方）
- ❌ **让多个 SubAgent 改同一批文件**。会互相覆盖。并行的硬规则是各 agent 改不同文件。Agent Team 文档也把「改同一文件」列为该用单会话的信号。✅（官方 + 社区）
- ❌ **把多 Agent 当加速器用**。代价是 15 倍 token。它买的是「单上下文装不下」任务的能力边界，不是速度。简单任务用多 Agent 只会更慢更贵。✅（官方）
- ❌ **给 SubAgent 模糊的委派指令**。SubAgent 看不到你的对话历史，只能看到你给它的那段话。「Fix authentication」是坏指令；好指令要带目标、文件范围、输出格式、边界。官方原话：「Without detailed task descriptions, agents duplicate work, leave gaps」。✅（官方）
- ❌ **让写代码的上下文自己 review 自己**。agent 自查会顺着刚才的思路找理由。要用全新上下文的 SubAgent 做对抗式 review，让写代码的人和评审的人不是同一个。✅（官方）
- ❌ **用 SubAgent 做需要共享中间状态的任务**。SubAgent 之间只能通过主 Agent 传话（game of telephone），信息会失真。需要协作讨论的任务用 Agent Team，或干脆留在单会话。✅（官方）
- ❌ **为一个简单查询启动一堆 SubAgent**。这是官方复盘里的早期失败模式，即「spawning 50 subagents for simple queries」。要按复杂度定规模，简单的事 1 个 Agent 就够。✅（官方）
- ❌ **让一个全工具的 SubAgent 自己再派活**。它拿得到派活工具就会继续派，形成没有深度上限的扇出树。社区实测一句调研请求长出 48 个以上并发 agent，大量重复劳动，停都停不过来。自定义 agent 用 `tools` 白名单掐掉派活工具，派完用 `/tasks` 数一下实际跑了几个。⚠️（社区）
- ❌ **开了 Agent Team 就不管，任其空转**。官方建议从研究和评审开始，不要让它无人值守太久；token 成本随队友数线性增长，3 到 5 个够用。✅（官方）
- ❌ **以为 `tools: Read, Grep, Glob, Bash` 是只读沙箱**。`Bash` 能执行任意 shell 命令，`echo x > file`、`sed -i`、`rm` 都做得到。官方说这套配置「can't edit files, write files」，只是指 Edit / Write 工具不可用。真要只读就去掉 Bash；确需跑命令就配 frontmatter 里的 `PreToolUse` hook 逐条拦。✅（官方）
- ❌ **把 fork 当 SubAgent 用、指望它隔离上下文**。fork 继承父会话的全部历史，不提供输入隔离。要干净上下文就用命名 SubAgent；只有想共享上下文、只隔离工具输出时，才用 fork。✅（官方）

---

## 延伸

**交叉引用：**
- [#031 plan → execute → review 的正确循环怎么做？](./031-plan-execute-review循环.md) —— 对抗式 review 的 SubAgent 用法；Phase ④ 的核心机制
- [#012 上下文窗口要爆了怎么办？](../02-上下文工程/012-上下文窗口要爆了.md) —— SubAgent 是最高效的防爆手段；transcript 抗 compact
- [#030 TDD 在 AI coding 里怎么做？](./030-AI写的测试不可信.md) —— 双 session「写测试的人 ≠ 写实现的人」就是 SubAgent 的应用
- [#033 Skill / superpowers 怎么用、怎么写？](./033-Skill与superpowers怎么用.md) —— dispatching-parallel-agents / subagent-driven-development skill 把并行强制化
- [#063 什么时候该用 Opus、什么时候该用 Sonnet/Haiku？怎么按任务路由模型才不浪费？](../07-效率与成本/062-什么时候用Opus什么时候用Sonnet.md) —— 本篇「多 Agent 烧 15× token」的成本侧对策：给 SubAgent 按任务路由更便宜的模型，别让并行白烧钱

**参考资料：**
- [Create custom subagents — Claude Code Docs](https://code.claude.com/docs/en/sub-agents) — 官方头号参考：fresh isolated context、built-in agents、自定义配置、fork、前台/后台、何时用主会话 vs SubAgent（官方，2026-06）✅
- [How we built our multi-agent research system — Anthropic](https://www.anthropic.com/engineering/multi-agent-research-system) — 官方量化：研究类内部评测 +90.2%（非编码评测）、token 15×、token 解释 80% variance；何时该用/不该用多 Agent；协调复杂度、game of telephone、同步瓶颈（官方，2025）✅
- [Orchestrate teams of Claude Code sessions — Claude Code Docs](https://code.claude.com/docs/en/agent-teams) — SubAgent vs Agent Team 对照；何时用哪个；token 成本线性增长；文件冲突（官方，2026-06）✅
- [Effective context engineering for AI agents — Anthropic](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — write/select/compress/isolate 四原则；SubAgent = isolate（官方，2025-09）✅
- [Best practices for Claude Code — Claude Code Docs](https://code.claude.com/docs/en/best-practices) — 对抗式 review subagent 范式；「A reviewer running in a fresh subagent context sees only the diff and the criteria you give it, not the reasoning that produced the change」（官方，2026-06）✅
- [Slash commands — Claude Code Docs](https://code.claude.com/docs/en/commands) — `/context` / `/usage`（`/cost` 是别名）/ `/tasks`，本篇「第五步事后回检」的验证命令来源（官方，2026-08 复核）✅
- [Hooks reference — Claude Code Docs](https://code.claude.com/docs/en/hooks) — `PreToolUse` 输入 JSON schema 与退出码 2 的拦截语义，本篇 Bash 只读拦截脚本的依据（官方，2026-08 复核）✅
- [Subagents in the SDK — Claude Code Docs](https://code.claude.com/docs/en/agent-sdk/subagents) — SDK 里定义和调用 SubAgent 隔离上下文、并行（官方，2026）✅
- [Claude Code Sub-Agents: Parallel vs Sequential Patterns — Claude Fast](https://claudefa.st/blog/guide/agents/sub-agent-best-practices) — 并行/串行/后台路由框架；invocation 质量决定成败；CLAUDE_CODE_SUBAGENT_MODEL（社区，2026-06）⚠️
- [Run cloud agents in your own infrastructure — Cursor](https://cursor.com/blog/self-hosted-cloud-agents) — Cursor Cloud/Background Agents 自托管、隔离环境（官方，2025-2026）✅
- [Cursor Cloud Agents: Build and Test in Isolated VMs — Digital Applied](https://www.digitalapplied.com/blog/cursor-cloud-agents-isolated-vms-guide) — Cursor 云 Agent 架构：隔离 VM、disposable filesystem、PR 工作流（社区，2025-2026）✅
- [Parallel AI Agents in Cursor 2.0 — Medium](https://medium.com/towards-data-engineering/parallel-ai-agents-in-cursor-2-0-a-practical-guide-e808f89cffb9) — Cursor 2.0 最多 8 个并行 agent（社区，2025）⚠️
- [General-purpose sub-agents recursively spawn unbounded child agents #68110 — GitHub](https://github.com/anthropics/claude-code/issues/68110) — 一句调研请求扇出 48+ 并发 agent、无深度与总数上限、大量重复劳动；本篇「token 指数爆炸」的头号实证（社区，2026-06，issue 状态 open）⚠️
- [Agent Teams: lead session loops on idle notifications #47930 — GitHub](https://github.com/anthropics/claude-code/issues/47930) — 5–8 个队友时主会话 13%–22% 输入 token 花在无操作的确认上（社区，2026-04）⚠️
- [deep-research workflow aborts entire run and burns millions of tokens #65500 — GitHub](https://github.com/anthropics/claude-code/issues/65500) — 约 75 个并发校验 agent，单点失败导致整轮中止，三次尝试约 350 万 token 零产出（社区，2026-06）⚠️
- [FEATURE: Independent Context Windows for Sub-Agents #10212 — GitHub](https://github.com/anthropics/claude-code/issues/10212) — 按预期输出大小路由 SubAgent 的社区讨论（社区，2025）⚠️

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验——你哪次用 SubAgent 救了爆掉的上下文 / 或反过来多 Agent 烧了 15 倍 token 却没拿到收益的踩坑案例]`
