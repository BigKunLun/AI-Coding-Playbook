# 003. 为什么 AI 写的代码我审不动、改完自己看不懂？

> 难度：中级
> 主题：心智与工具
> 工具：Claude Code · 横向(ChatGPT / Cursor / Copilot)
> 题型：场景题 + 决策题

> ⏰ 时效声明：**2026-08-03** 复核。Anthropic 40 万会话研究的数据（新手可验证成功率 15%、中级至专家 28–33%、部分成功 77% vs 91–92%、卡壳会话里新手 4% / 专家 15%、各职业与软件工程师差距 ≤7 个百分点）本轮实访官方页逐项复核。文中涉及的 Claude Code 交互键（`Esc` 打断、`Esc Esc` 回退、`Shift+Tab` 切权限档）按官方 interactive-mode 文档 2026-08 版核对。四层框架是本库的原创归纳，不是业界通用术语，不绑定版本。

## TL;DR

**你现在可能撞上的场景**：agent 一口气改了 8 个文件、300 行，测试绿了，你点了接受。三天后线上报错指到这段代码，你打开一看——是自己项目里的代码，但你说不出它为什么这么写、改一行会牵动谁。你不是不会 review，你是**审不动**：每次都要从头看懂一遍，成本比自己写还高。

这不是工具问题，也不是"prompt 写得不够好"。是你把对系统的理解外包出去了。

三点速记：

1. **要换的是心智模型，不是操作**。"心智模型"这个词的意思很朴素：你脑中那套"这段代码怎么跑、怎么挂、怎么改"的理解。它跟代码一样是你写代码时的产物，但它不进 Git，你不碰就退化。

2. **agent 越自主，你的理解掉得越快**。放它一口气干一大块，等于让你审一个超大的 code review：看不懂、记不住、信心下降。解法是把回合切小，而不是把 prompt 写长。

3. **先测自己在第几层，再决定下一步做什么**。下面「怎么做」给了 6 道是非题，2 分钟做完就知道自己卡在哪一层、这周该改哪一个具体动作。

一句话：**"用顺了"不是学会了几个动作，而是你在一来一回中，对系统的理解还在长；不是等它交货、你验收。**

## 为什么

### 1. 症状是"审不动"，根因是理解没在长

很多人以为自己的问题是"prompt 写得不好"，于是不断把需求写得更长更细。但真正的分界线不在 prompt 长度，在**你的理解有没有跟着改动一起长**。

对照一下这两种"审 diff"：

- 验收式：你在检查"它有没有满足我提的要求"。checklist 过了就接受。你的理解没动。
- 搭档式：你在检查"它的实现和我脑子里那套模型对不对得上"。对不上就追问为什么。你的理解在动。

前者做得再熟练，三天后你还是说不出这块为什么这么设计——因为你从没构建过那个模型。

Phil Booth 把这件事的机制说清楚了：

> When you write code, the code is not the only artifact that's generated. You also construct a mental model of how the code works, its runtime behaviour under different conditions, how it fails and so on. ... Mental models also have an alarming tendency that code doesn't: they degrade rapidly whenever you're not thinking about them and the cost of reconstructing them increases the longer you continue not to think about them.
>
> —— Phil Booth《[Agentic coding and mental models](https://philbooth.me/blog/agentic-coding-and-mental-models)》，社区权威，2026-06-11

白话：写代码时你产出两样东西，代码本身，和脑中"它怎么跑、怎么挂、怎么改"的理解。代码进 Git 不会忘，理解一不碰就退化，放得越久重建成本越高。

而 agent 的自主性直接冲击后者：

> Increasing autonomy for coding agents has precisely the same effect as increasing the size of code reviews. It makes my job harder, slows down development of my mental model and decreases confidence that I understand what's going on.
>
> —— Phil Booth，同上

一次接受 300 行，就是给自己派了一个 300 行的 code review。这也是"vibe coding 放羊式"真正危险的地方：危险的不是代码质量差（那是表象），而是等它坏了你不会修，只能再去求 agent。

### 2. 官方数据能支持什么、不能支持什么

Anthropic 对约 40 万个 Claude Code 会话、约 23.5 万人（2025-10 至 2026-04）做了隐私保护分析，题为《[Agentic coding and persistent returns to expertise](https://www.anthropic.com/research/claude-code-expertise)》（官方研究，2026-06-16）。

官方数据（2026-08 复核）：

| 指标 | 新手 | 中级至专家 |
|---|---|---|
| 可验证成功（verified success） | 15% | 28–33% |
| 部分成功（partial success） | 77% | 91–92% |
| 卡壳会话中的可验证成功 | 4% | 15%（专家） |

另外，产码会话里前十大职业的成功率都落在软件工程师的 ±7 个百分点内（软件类约 34%，其他职业约 29%），官方由此说 coding agents 并没有取代领域专长。

**这份数据能支持的**：专长在 agentic 时代仍有持续回报，玩家没有被"拉平"；尤其在会话卡壳时，专家把局面救回来的比例是新手的近 4 倍——这一格最贴近"你自己得懂"的直觉。

**这份数据不能支持的**：它没有测量"心智模型是否被外包"，也没证明"外包理解会导致失败"。它是横截面的相关性，不是因果实验。上一节那条"理解外包→审不动→修不了"的链条，依据是 Phil Booth 的一手工程经验和你自己的可复现体感，不是这份研究。两者分开看，别当成同一个证据。

> 001 已经引过 Phil Booth 的 driver/navigator 搭档框架（LLM 当司机、人当领航、频繁打断），这里不重复。003 只取他的另一个角度：心智模型的构建与退化。

## 怎么做

### 第一步：2 分钟自测，先定位自己在第几层

下面 6 题按你**最近三次**真实使用回答，只答"是 / 否"。不要回忆理想状态，回忆上一次实际发生了什么。

| # | 自测题 | 是 / 否 |
|---|---|---|
| 1 | 上一个 agent 改完的模块，你能不看代码说出它为什么这么设计吗？ | |
| 2 | 最近一次 diff，你是逐段读完才接受的，还是先按接受再说？（逐段读完=是） | |
| 3 | 你能说出上次那个改动会牵动哪些调用方 / 哪些下游？ | |
| 4 | 上一个任务里，你在 agent 干到一半时打断过它、纠正过方向吗？ | |
| 5 | 开工前你有没有先让它给计划、并且你从计划里挑出过至少一个漏项？ | |
| 6 | 交付时你判断的是"测试绿了"，还是"它的实现和我脑中的模型对得上"？（后者=是） | |

计分与定位（"是"的个数）：

- **0–1 条**：第 0 层，Prompt 心智。
- **2–3 条**：第 1 层，目标心智。
- **4–5 条**：第 1 层顶部到第 2 层之间。
- **6 条**：第 2 层，Pair 心智，这就是"用顺了"。

再加一条**否决项**：不管你答对几条，如果第 1 题是"否"，你就还没到第 2 层。说不出"为什么这么设计"，说明理解没长起来，其余都是操作熟练度。

（说明：这套 0–3 层分档是本库为了让读者能自检而做的原创归纳，不是业界通用术语，别拿它当行话去跟人对齐。）

### 第 0 层：Prompt 心智（"我下指令，它执行"）

**你在想什么**：需求写清楚了，它就该给我对的代码。脑子里还是 ChatGPT 那套"我提问→它回答→我拿走"。

**典型表象**：不给上下文当聊天框用、逐行指挥当打字员用。指针见 [002 卡点 1、2](./002-why-claude-code-feels-hard-at-first.md)。

**下一步只做一件事**：下个任务开工前，先把「目标 + 约束 + 验证方式」三样写进第一条消息，别写实现步骤。做到这条你就进第 1 层。

**验证做对了没有**：会话开始后它应该先去读文件、给出改动范围，而不是立刻贴代码。如果它上来就贴整段实现，说明你给的还是步骤不是目标。

### 第 1 层：目标心智（"我给目标+上下文+验证，它去跑"）

**你在想什么**：会给目标、给参考文件、给验证方式，两次纠正不成就 `/clear`。但你把自己定位成"设计验证、让它通过验证"的验收人。

**典型表象**：指针见 [002 怎么做 checklist](./002-why-claude-code-feels-hard-at-first.md)。

**这层的天花板**：操作全对，理解仍在外包。简单任务够用，复杂任务一来就露馅——你能 review 出"写得对不对"，说不出"为什么这么设计、改了牵动什么"。对应自测题的 1、3、6 三条通常是"否"。

**下一步只做一件事**：把回合切小。给它一个任务后，**在它改完第一个文件时就 `Esc` 打断**，让它先解释这一段的设计取舍，你判断完再放行。一次任务里至少这样打断两次。

**验证做对了没有**：这个任务收尾时，不看代码，口头讲一遍"这块为什么这么写、改它会牵动谁"。讲得出来 = 这次理解长了；讲不出来 = 回合还是切得太大。

### 第 2 层：Pair 心智（"我和它搭档，理解在协作中长起来"）

这是目标画像。和第 1 层的唯一区别：你不再只审"验证过没过"，而是在一来一回里持续构建和修正自己对系统的理解。

Phil Booth 把这层的机制说得最直接：

> I want the equivalent of a small code review, not a big one. Another way of framing this is to say I want a shorter feedback loop. And what feedback loop is even shorter than code review? Yes, it's pair programming.
>
> —— Phil Booth，同上

也就是：不要偶尔审一大坨 diff，而要频繁、小块地来回，让理解始终在线、不被一次性冲垮。002 里"频繁打断"这条在这里才有真正的理由——不是为了控制它，是为了保护你自己的理解。

Tweag 那边给出的是同一件事的另一面：agentic coding 不是甩手交责任，而是放大好的工程判断力；实验里最成功的工程师，是把 AI 当协作者而不是当魔法师的那些人（社区，2025-10）。

**这层的日常动作**：见下面「Claude Code 实战」的四步句式，那是这一层的可复制件。

**验证做对了没有**：连续三个任务，每个都能在收尾时不看代码说清设计取舍和影响面。做不到就退回第 1 层的打断练习。

### 第 3 层：Orchestration 心智（"我把判断力写成系统"）

前两层是你一个人和一个 agent 搭档；这一层是**把你在搭档中反复说的那些话，固化成 agent 每次都会自动遵守的东西**，这样你不用每次口头重复判断标准。

**你在想什么**：从"我这次得提醒它别自己造锁"变成"这条规矩应该写在哪，让它下次自己知道"。

**具体落在四个东西上**：

| 固化对象 | 放哪 | 用来固化什么 |
|---|---|---|
| CLAUDE.md | 仓库根目录 | 项目常识与硬规矩（技术栈、测试怎么跑、哪些目录不许动） |
| skill | `.claude/skills/<名字>/SKILL.md` | 你反复走的同一套流程（发版检查、写迁移脚本） |
| subagent | `.claude/agents/<名字>.md` | 需要独立上下文的子任务（大范围调研、写测试），不污染主会话 |
| hook | `.claude/settings.json` | 必须每次强制执行、不能靠它自觉的事（提交前跑测试） |

**判断你该不该进这层**：只有一个信号——**同一句纠正你说了三次以上**。比如你连续三次都要说"用项目里已有的 redis-lock.ts，别自己造"，那这句话就该进 CLAUDE.md，而不是继续靠你嘴说。三次以下不用动，过早固化只会写出一堆没人遵守的规矩。

**下一步只做一件事**：翻一下最近一周的会话，找出你重复最多的那句纠正，写进 CLAUDE.md，一条就够。

**验证做对了没有**：写完之后开新会话跑同类任务，看它是否不用你提醒就遵守了。没遵守说明规则写得太笼统——[#010 CLAUDE.md 怎么写才真的生效？](../02-context-engineering/010-claude-md-how-to-make-it-work.md) 讲怎么改。

四种能力的完整选型（什么时候用哪个、怎么配）归 [#004](./004-claude-code-capabilities-map.md)，本篇只给"什么时候该开始想这件事"的信号。

补充：日常的 plan→execute→review 节奏属于第 2 层搭档心智的落地纪律，不属于本层，详见 [#031 plan → execute → review 的正确循环怎么做？](../04-execution-workflow/031-plan-execute-review-loop.md)。

## Claude Code 实战

### 可复制的四步搭档句式

这是第 2 层的日常做法，换任何场景都能套。四步是：**先对齐 → 要计划 → 挑漏项 → 对齐已有实现**。

```
# 第 1 步 先对齐（不许它写代码）
先别写代码，我跟你对齐一下：
这次要解决的问题是 <问题现象，不是方案>。
约束是 <一致性 / 性能 / 兼容 等硬条件>。
参考项目里已有的 <文件或模块>。
你先告诉我：你打算读哪些文件、改哪些、风险在哪？

# 第 2 步 要计划（拿到它的计划后，你负责挑漏）
计划里少了 <你发现的漏项>。加上，并且用已有的 <模块>，别自己造。

# 第 3 步 改动中打断（读到不对就 Esc，然后问为什么）
等等，你这里用的是 <它的做法>，
项目里 <另一个模块> 用的是 <既有做法>，
对齐一下，并告诉我为什么。

# 第 4 步 收尾（判断的是模型对不对得上，不是绿不绿）
跑测试。然后用三句话讲清楚：
这个改动的核心取舍是什么、哪些调用方会受影响、什么情况下它会失效。
```

第 3 步用的 `Esc` 是打断当前回应或工具调用，Claude 会保留已完成的部分（官方 interactive-mode 文档，2026-08）。如果改动已经落盘、你想整体退回某个时点，在输入框为空时按两次 `Esc` 打开回退菜单。

### 一个真实场景走一遍

任务：给已有的 `UserService` 加一层缓存。

第 0 层脑子里：想的是"我要它给 UserService 加缓存"，等它吐代码，扫一眼像那么回事，接受。理解没动，甚至更模糊。

第 2 层脑子里，套上面的四步：

```bash
cd ~/my-api && claude
```

```
> 先别写代码，我跟你对齐一下：
  要解决的是 getUserById 读放大，用 Redis。
  约束：必须支持写后失效（TTL 5 分钟），还要防缓存穿透。
  参考项目里已有的 Redis 用法。
  你先告诉我：你打算读哪些文件、改哪些、风险在哪？

# 它回了一版计划 → 你发现它漏了热点 key 重建的并发保护
> 计划里少了缓存击穿的防护。加一个：
  用已有的 redis-lock.ts 做单飞，别自己造。

# 它开始改 → 你逐段读 diff，读到失效策略不对就 Esc 打断
> 等等，你这个失效策略是写后立即删 key，
  项目里 ProfileService 用的是"先更新 DB 再删缓存"，
  对齐一下，告诉我为什么。

# 它解释 → 你判断对不对，对就放行
> 跑测试。然后三句话讲清楚：核心取舍、受影响的调用方、什么情况下会失效。
```

**怎么判断这次做对了**：任务结束后合上编辑器，口头讲一遍"这个缓存为什么用先更新 DB 再删、并发下最坏会脏多久、下游哪些接口受影响"。讲得出来，说明你的理解跟着长了；讲不出来，说明你只是完成了一次验收。

## 横向对比

001 已有四工具完整横向表，这里只回答一个心智层问题：同一场转换，在不同工具上陡峭程度不同。

- **ChatGPT**（网页对话）：不要求你转。它就是 prompt 工具，停在第 0 层就是正确用法，期待和现实一致。
- **Copilot**（编辑器内补全）：起步门槛最低。但它向 agent 演进后（多文件改动、自主执行），停在"按 Tab 接受补全"越来越不够用。
- **Cursor**（IDE 内嵌）：半要求。在编辑器里搭档，到第 1 层够用，inline diff 让审查成本最低。
- **Claude Code**（终端 agentic）：最要求。它在你的项目里直接动手，第 1 层会卡（能 review 但理解没长），撑到第 2 层才顺。

这解释了 002 那条"怀疑→上瘾→失望→转变"曲线为什么在 Claude Code 用户身上最明显：门槛最高，"差点放弃"的人最多。完整对比见 [#001](./001-claude-code-vs-chatgpt-cursor-copilot.md)。

## 反模式

- ❌ **把 agentic 工具当 prompt 工具用**（停在第 0 层）。用得很痛还觉得工具差。002 的角度是"操作错"，本篇的角度是"心智没转"。
- ❌ **以为操作对了就等于转过来了**（停在第 1 层）。姿势全对，理解还在外包。表现是简单任务漂亮、复杂任务一崩就懵。自测题第 1、3、6 条就是专门抓这种情况的。
- ❌ **用更长的 prompt 解决"审不动"**。审不动的原因是单次改动太大，不是描述太短。正确动作是把回合切小、中途打断，不是继续加字。
- ❌ **把 agentic 等同于放权甩手**（vibe coding 放羊式）。真正的 agentic 是搭档加放大判断力。需求侧何时该停 vibe 转 spec，见 [#023 Vibe coding 为什么会翻车？什么时候必须停下来规划？](../03-spec-and-planning/023-vibe-coding-when-to-stop-and-plan.md)。
- ❌ **以为转换一次性完成**。理解会退化，一段时间只甩大块任务，就会悄悄退回第 1 层甚至第 0 层。建议每月重跑一次上面 6 道自测题。
- ❌ **过早进第 3 层**。同一句纠正没说满三次就急着写 CLAUDE.md / skill，结果是一堆没人遵守也没人维护的规矩。

## 延伸

**交叉引用：**
- [#001 Claude Code、Codex、Cursor、Copilot 到底该用哪个？按你的活儿选，不按测评选](./001-claude-code-vs-chatgpt-cursor-copilot.md) —— agentic 本质定义、四工具形态、driver/navigator 框架。本篇是它的认知层深水区。
- [#002 为什么我一开始用 Claude Code 各种不顺、"差点放弃"？卡在哪、怎么顺](./002-why-claude-code-feels-hard-at-first.md) —— 操作层 5 卡点加正确姿势 checklist。002 是操作层，003 是它的认知层续集。
- [#004 Claude Code 的 plan / skill / subagent / CLAUDE.md 这堆"能力"到底是啥、什么时候用哪个？](./004-claude-code-capabilities-map.md) —— 第 3 层四种固化手段的完整选型。
- [#010 CLAUDE.md 怎么写才真的生效？](../02-context-engineering/010-claude-md-how-to-make-it-work.md) —— 第 3 层"把重复纠正固化下来"的具体写法。
- [#011 Context Engineering 和 Prompt Engineering 到底什么区别？](../02-context-engineering/011-context-vs-prompt-engineering.md) —— 第 0 层到第 1 层的底层机制。
- [#023 Vibe coding 为什么会翻车？什么时候必须停下来规划？](../03-spec-and-planning/023-vibe-coding-when-to-stop-and-plan.md) —— 停在第 0 层的极端形态，需求侧决策。
- [#031 plan → execute → review 的正确循环怎么做？](../04-execution-workflow/031-plan-execute-review-loop.md) —— 第 2 层的落地节奏。

**参考资料：**
- [Agentic coding and mental models — Phil Booth](https://philbooth.me/blog/agentic-coding-and-mental-models) —— 心智模型的构建与退化、自主性越高构建越慢、更短的反馈回路就是搭档编程（社区权威，2026-06-11）✅ webReader 全文逐字复核
- [Agentic coding and persistent returns to expertise — Anthropic](https://www.anthropic.com/research/claude-code-expertise) —— 约 40 万会话、约 23.5 万人（2025-10 至 2026-04）的隐私保护分析（官方研究，2026-06-16）✅ 2026-08-03 WebFetch 实访复核：可验证成功 15% vs 28–33%、部分成功 77% vs 91–92%、卡壳会话 4% vs 15%、各职业与软件工程师差距 ≤7 个百分点均取自官方页
- [Interactive mode — Claude Code 官方文档](https://code.claude.com/docs/en/interactive-mode) —— `Esc` 打断当前回应并保留已完成工作、输入框为空时 `Esc Esc` 打开回退菜单、`Shift+Tab` 循环权限档（官方文档，2026-08-03 复核）
- [Introduction to Agentic Coding — Modus Create / Tweag](https://tweag.io/blog/2025-10-23-agentic-coding-intro/) —— "不是甩手交责任而是放大工程判断力"、"当协作者不是魔法师"（社区，2025-10-23）✅ webReader 全文逐字复核。注：文中 "our experiments" 指 Modus Create 的双团队对照实验（n=2 团队），属公司单次实验、非学术或广泛共识，评级为"社区"

> 本篇个人实践（L4）：`[待补：BOSS 的"用顺了"时刻 / 心智迁移体验]`
