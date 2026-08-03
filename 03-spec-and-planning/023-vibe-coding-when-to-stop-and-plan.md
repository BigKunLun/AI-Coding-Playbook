# 023. Vibe coding 为什么会翻车？什么时候必须停下来规划？

> 难度：中级
> 主题：需求与规划
> 工具：Claude Code · 横向(Cursor / Copilot / Gemini CLI)
> 题型：场景题

> ⏰ 时效声明：本文事实性内容于 **2026-07-18** 复核。外链抽查：Karpathy 推文、Simon Willison、V2EX、India Today、官方 best-practices 均存活；fortune.com 返回 403 为付费墙/反爬非死链（引语另有 India Today 二手印证）；Reddit 各帖为反爬站点、引文来自搜索片段（文中已逐条标注 ⚠️）。「何时停下来规划」的信号清单与决策框架不依赖具体版本，长期有效。2026-08-03 补入「demo 到产品的预期差」一节，其两条 HN 外链与原文已于当日实访核实存活 ✅。

## TL;DR

「Vibe coding」这个词是 Andrej Karpathy 在 2025 年 2 月的推文里造的。他给的定义是「fully give in to the vibes, embrace exponentials, and forget that the code even exists」，也就是：不看代码改动、一路点 `Accept All`、报错就直接复制粘贴回去（[Karpathy 推文](https://x.com/karpathy/status/1886192184808149383)，一手，2025-02）✅。

但他当时就画了一条生死线，原话是「It's not too bad for throwaway weekend projects」，意思是这套玩法只适合「用完就扔的周末小项目」。

vibe coding 翻车的根因，就是越过了这条线：把为一次性脚本设计的姿势，用到了有真实用户、需要长期维护的项目上。

Cursor CEO Michael Truell（不是 Aman Sanger）在 2025 年 12 月的 Fortune Brainstorm AI 大会上把后果讲得很直白（[Fortune](https://fortune.com/article/cursor-ceo-vibe-coding-warning/)，一手新闻，2025-12）✅：

> "If you close your eyes, and you don't look at the code, and you have AIs build things with shaky foundations as you add another floor, and another floor, and another floor, and another floor, things start to kind of crumble."
>
> （闭着眼睛不看代码，让 AI 在摇晃的地基上一层层往上盖，最后整个东西开始垮。）

一句话心法：vibe coding 翻车不是因为「模型不够强」，而是因为「没有让 AI 停下来的验收锚点，也没有把决策沉淀成可复用的上下文」。速度快是它的优点，容易失控是它的代价。本篇要给的，就是「何时必须从 vibe 切到 spec」的信号清单。

先看「能不能 vibe、何时必须停」的速查表：

| 场景 | 能不能 vibe |
|------|-----------|
| 一次性脚本、探索性 POC、周末玩具 | ✅ 随便 vibe，返工成本≈0 |
| 单个功能、0.5–2 天、自己能完全看懂 | ⚠️ 可以 vibe，但要配验收检查 |
| 中型功能（>3 天）、跨多文件/多层 | ❌ 必须停，补 spec 再继续 |
| 有真实用户、生产代码、需对结果负责 | ❌ 严禁纯 vibe，spec 先行 |
| 上下文已过半、同一问题纠正 AI 超过两次 | ❌ 立刻停，`/clear` + 回写 spec |

三条要记住的结论：

**1. vibe coding 是「不验证就接受」的姿势，不是「用 AI 写代码」本身。** Simon Willison 在专门的澄清文里说得很清楚：「Vibe coding is NOT the same thing as writing code with the help of LLMs!」（vibe coding 跟「用 LLM 帮忙写代码」不是一回事）。他给的定义是「building software with an LLM without reviewing the code it writes」（用 LLM 造软件、但不 review 它写的代码）。所以，用 AI 写代码但看懂每一行改动，不算 vibe coding（[simonwillison.net](https://simonwillison.net/2025/Mar/19/vibe-coding/)，社区权威，2025-03）✅。

**2. 翻车的拐点是「复杂度悬崖」（complexity cliff）。** 项目小到「一个人脑子里装得下」时 vibe 没问题。一旦越过这条线，AI 就会开始「vibe code itself into infinite knots and make architectural decisions that would make a codebase impossible to maintain」（把自己绕成一团乱麻，做出让代码库无法维护的架构决定）。这不是慢慢变差，而是断崖式崩盘（r/cursor 1q1v99l，社区，2025）⚠️。

**3. Anthropic 官方把「先探索、再计划、再写码」列为推荐工作流的第一条**，直接反对「上来就写」。官方原话：「Letting Claude jump straight to coding can produce code that solves the wrong problem. Use plan mode to separate exploration from execution.」（让 Claude 直接上手写代码，可能写出解决错问题的代码；用 plan mode 把探索和执行分开）（[Best practices](https://code.claude.com/docs/en/best-practices)，官方，2026-06）✅。

---

## 为什么

### 1. vibe coding 的三个失败模式：从 Karpathy 原文反推

回到 vibe coding 的定义原文，Karpathy 自述的行为里其实已经埋下了所有翻车的种子（[Karpathy 推文](https://x.com/karpathy/status/1886192184808149383)，一手，2025-02）✅：

> "I 'Accept All' always, I don't read the diffs anymore. When I get error messages I just copy paste them in with no comment, usually that fixes it. The code grows beyond my usual comprehension, I'd have to really read through it for a while. Sometimes the LLMs can't fix a bug so I just work around it or ask for random changes until it goes away."
>
> （我永远点「全部接受」，不再看代码改动。报错我就原样粘回去，通常就修好了。代码长到我看不懂，得花时间才能读明白。有时 LLM 修不好一个 bug，我就绕过去，或者让它随便改改直到问题消失。）

把这段拆开，正好对应三个失败模式。

**失败模式一：先信任后验证的鸿沟（trust-then-verify gap）。** 点 `Accept All` 却不看改动，等于放弃了第一道验证。Anthropic 官方把这条列为 Claude Code 的常见失败模式之一，原话是「The trust-then-verify gap: Claude produces a plausible-looking implementation that doesn't handle edge cases」（Claude 写出看起来合理、但没处理边界情况的实现）（[Best practices](https://code.claude.com/docs/en/best-practices)，官方）✅。说白了，vibe coding 把「看起来对」当成了「真的对」。

**失败模式二：上下文腐烂（context rot），指对话越拖越长、AI 逐渐忘掉早期决策。** 报错就复制粘贴回去、「通常就修好了」，修的是症状不是根因。修过的痕迹全堆在上下文里，等上下文填满，AI 就开始遗忘早期决策。官方原话（[Best practices](https://code.claude.com/docs/en/best-practices)，官方）✅：

> "Most best practices are based on one constraint: Claude's context window fills up fast, and performance degrades as it fills... The context window is the most important resource to manage."
>
> （大多数最佳实践都基于一个约束：Claude 的上下文窗口填得很快，而且越填性能越差。上下文窗口是最需要管理的资源。）

r/webdev 上有人专门记录了这个症状：项目一旦超出单次上下文窗口，就会「extremely vulnerable to context rot」（极易发生上下文腐烂）。到那一刻，之前 vibe 出来的所有隐性决策就没人能解释了（r/webdev 1qdbsyf，社区）⚠️。

**失败模式三：用 prompt 糊过去（prompt through），而不是理解根因。** 最致命的是这一句：「Sometimes the LLMs can't fix a bug so I just work around it or ask for random changes until it goes away」。r/cursor 上一位开发者把这种行为命名为 prompt through，他说「Spaghetti code happens when I 'prompt through' an issue, instead of [understanding it]」（面条代码就是我不去理解问题、只靠 prompt 硬糊过去时产生的）（r/cursor 1j6ufkg，社区）⚠️。每一次「糊过去」都在代码库里留下一笔技术债，而且这笔债没有任何文档记录。

以上「三个失败模式」的论断，有 Karpathy 原文（一手）、官方 best-practices、以及 r/cursor 与 r/webdev 社区印证，共 ≥2 源 ✅。

### 2. 为什么是断崖式崩盘，而不是慢慢变差

很多人误以为「vibe coding 越写越乱」是一种线性退化。其实不是，它是断崖式的：临界点之前一切顺利，越过临界点后迅速失控。

V2EX 上 wingtao 的分析帖把这个「悬崖」讲得很清楚（[V2EX 1183614](https://www.v2ex.com/t/1183614)，社区，2026-01）✅：

> "对于 0.5 PD 或 1 PD 的小任务…一次性生成的 Plan/Spec 偶尔是可以工作的。但对于持续时间超过一周的复杂任务…一次性生成的 Spec 几乎必然失效。这不是模型能力问题，而是问题复杂度的自然结果。"

为什么是断崖？因为「能 vibe 得动」依赖一个隐含前提：当前会话的上下文，加上你脑子里记着的东西，能共同覆盖整个项目的状态。

项目小的时候这个前提成立，你随时能在脑子里重建全局。项目一旦大到「超过一个人脑子能装下的量」，前提就瞬间崩塌：你和 AI 都失去了全局视图，每一次改动都成了盲改。

这正是 Cursor CEO Truell 说的「一层层加盖，最后开始垮」的机制：每一层都是在前一层「shaky foundation」（摇晃的地基）上加的，地基的脆弱是一点点累积的，而崩塌是一瞬间的（[Fortune](https://fortune.com/article/cursor-ceo-vibe-coding-warning/)，一手新闻，2025-12）✅。

社区对这种断崖的描述高度一致。r/cursor 上那条被反复引用的帖子说（r/cursor 1q1v99l，社区，2025）⚠️：

> "I've watched Cursor vibe code itself into infinite knots and make architectural decisions that would make a codebase impossible to maintain."
>
> （我见过 Cursor 把自己 vibe 成一团解不开的乱麻，做出让代码库无法维护的架构决定。）

「一团乱麻」加上「无法维护」，正是越过悬崖后的状态：不是某一行代码错了，而是整个架构的决策链断了，无法局部修复。r/vibecoding 上有人把这个过程叫「death spiral」（死亡螺旋），并形容为「enter for speed, stay for the debugging hell」（为速度而来，为 debug 地狱而留）（r/vibecoding 1m37cyl，社区）⚠️。

以上「断崖式崩盘 / 复杂度悬崖」的论断，有 V2EX wingtao、Cursor CEO Truell（Fortune）、r/cursor 1q1v99l，共 ≥2 源 ✅（V2EX 抓全文，Fortune 抓全文，r/cursor 为搜索片段）。

### 3. 官方的答案不是「别用 AI」，而是「把探索和执行分开」

需要澄清一个常见误读：vibe coding 翻车，不等于 AI coding 有罪。问题不在「用 AI」，而在「跳过规划直接执行」。

Anthropic 官方给的解法，是把这两步物理隔离（[Best practices](https://code.claude.com/docs/en/best-practices)，官方，2026-06）✅：

> "Letting Claude jump straight to coding can produce code that solves the wrong problem. Use plan mode to separate exploration from execution."

「Explore first, then plan, then code」是官方工作流的章节标题，意思是：先探索（只读、摸清现状），再规划（出方案、写 spec），最后才执行（写码）。这跟 SDD（Spec-Driven Development，规格驱动开发）主张的「spec 先行」是同一件事的两种说法。

Simon Willison 给了一个更可操作的「停止 vibe」判据，他称之为生产环境的黄金法则（[simonwillison.net](https://simonwillison.net/2025/Mar/19/vibe-coding/)，社区权威，2025-03）✅：

> "My golden rule for production-quality AI-assisted programming is that **I won't commit any code to my repository if I couldn't explain exactly what it does to somebody else**."
>
> （我做生产级 AI 辅助编程的黄金法则是：如果一段代码我没法向别人准确解释它在做什么，我就不会把它提交进仓库。）

这条法则直接把「能不能 vibe」变成了一个可自检的问题：这段代码我能给别人讲明白吗？讲不明白，就必须停下来规划。

V2EX 上 GeruzoniAnsasu 的实战总结和这条法则同频：「spec 本质就是逐条检查的清单，用来把难以控制的 AI 自由发挥细化为逐字逐行的约束和回归项」（[V2EX 1183614 #29](https://www.v2ex.com/t/1183614)，社区）✅。

> 个人观点（小C）：先区分你现在是「探索期」还是「交付期」。探索期允许 vibe，甚至鼓励 vibe，因为你要的就是快速看到「AI 怎么理解这个问题」，产出的半成品本身就是探索素材。一旦进入「这个功能要上线、有真实用户、要对结果负责」的交付态，黄金法则立刻生效：不能解释的代码不许 commit。这也是 020 篇「vibe coding 探索 vs production engineering」区分的延伸。

以上「官方答案 = 探索/执行分离」的论断，有官方 best-practices、Simon Willison 黄金法则、V2EX GeruzoniAnsasu，共 ≥2 源 ✅。

---

## 怎么做

这是本篇的核心：给出「必须停下来规划」的可操作信号清单。

### 「必须停下来规划」的信号清单（8 条）

当你观察到下列任意一个信号，就该从 vibe 模式切换到 spec/plan 模式。信号越靠前越早出现，越靠后后果越严重：

| # | 信号 | 触发动作 | 来源 |
|---|------|---------|------|
| 1 | **你无法逐行向别人解释这段 AI 代码做了什么** | 停，补 spec 再继续 | Simon Willison 黄金法则 ✅ |
| 2 | **同一个问题你已纠正 Claude 超过 2 次** | 立刻 `/clear`，把已确认的事实回写 spec，新 session 重来 | Claude Code 官方 ✅ |
| 3 | **你在「用 prompt 糊过去」而不是理解根因** | 停，让 AI 在 plan mode 做根因分析，而不是继续打补丁 | r/cursor 1j6ufkg ⚠️ |
| 4 | **AI 开始做出你无法评估对错的架构决定** | 停，这些决定必须进 spec 由你拍板，不能交给 vibe | r/cursor 1q1v99l ⚠️ |
| 5 | **进入「debug 地狱」：为修一个 bug 引入两个新 bug** | 停，这是复杂度悬崖的典型症状，硬刚只会越陷越深 | r/vibecoding 1m37cyl ⚠️ |
| 6 | **上下文过半，AI 开始遗忘早期约定** | `/clear`，把约定固化进 CLAUDE.md / spec，新 session 带书面上下文重来 | Claude Code 官方 + r/webdev ✅ |
| 7 | **任务从「周末玩具」升级为有真实用户/真实成本** | 切换范式：从 vibe 切 SDD，spec 先行 | Karpathy 原始边界 ✅ |
| 8 | **项目超过 ~1 人周复杂度，你脑子里装不下全局了** | 必须拆 task + 写 spec，不能再用「脑子当数据库」 | V2EX wingtao ✅ |

> 个人观点（小C）：信号 1 和信号 2 是最便宜的刹车，它们在你还没意识到项目变复杂时就会触发。把 Simon Willison 的黄金法则贴到显示器上，把官方的「两次纠正就 /clear」写进肌肉记忆。这两个习惯能挡掉 80% 的 vibe 翻车。

### 从 vibe 切 spec 的具体动作（三步）

信号触发后，别继续在同一个被污染的会话里硬刚。按这三步走。

**第一步：止血，先 `/clear`，但先把已确认的事实抢救出来。**

官方明确说：「If you've corrected Claude more than twice on the same issue in one session, the context is cluttered with failed approaches. Run `/clear` and start fresh…」（如果你在一个会话里对同一个问题纠正 Claude 超过两次，上下文已经被失败的尝试塞满了，运行 `/clear` 重开），原文后面接的是「with a more specific prompt that incorporates what you learned」（用一个更具体、吸收了你已学到的东西的 prompt）（[Best practices](https://code.claude.com/docs/en/best-practices)，官方）✅。

但 `/clear` 之前先抢救：把当前会话里已经验证为真的结论写进 `SPEC.md` 或 `CLAUDE.md`。这些结论包括：哪些方案试过不行、哪些约束必须满足、架构决策的来龙去脉。否则 `/clear` 之后，这些用真金白银换来的认知就丢了。

**第二步：补 spec，回答「做什么 / 验收标准 / 不做什么」。**

切到 plan mode（连按两次 `Shift+Tab`，或用 `claude --permission-mode plan`），用官方推荐的访谈式 prompt 把需求逼问清楚（[Best practices](https://code.claude.com/docs/en/best-practices)，官方）✅：

```
我想做 [简要描述]。用 AskUserQuestion 工具详细地访谈我。
问技术实现、UI/UX、边界情况、顾虑和权衡。别问显而易见的问题，
挖那些我可能没考虑到的难点。
一直问到把所有点覆盖完，然后写一份完整的 spec 到 SPEC.md。
```

spec 至少要回答五件事：做什么（what & why）、输入输出契约、验收标准、约束与边界、明确不做什么（out of scope）。其中验收标准最关键，必须是可执行的 pass/fail 判断。这就是 021 篇讲的最小 PRD 五要素。

vibe 翻车的根因，往往就是「没有验收标准」，于是 AI 在「看起来做完了」的时候就停下了。官方原话：「Claude stops when the work looks done. Without a check it can run, 'looks done' is the only signal available」（Claude 在工作看起来完成时就停下；如果没有一个它能跑的检查，「看起来完成」就是唯一可用的信号）（[Best practices](https://code.claude.com/docs/en/best-practices)，官方）✅。

**第三步：重开一个新 session，带着书面 spec 执行。**

spec 写完后，开一个全新的 session 来执行。官方推荐这样做：新 session 上下文干净，再对照书面 spec，就能避免长会话里累积的失败尝试干扰。这就是从 vibe 切 SDD 的完整动作链。

PRD 具体怎么写、要不要加码到全流程 SDD，见 [#021 动手前到底要不要先写 PRD / 需求文档？写多详细才够？](./021-prd-before-coding-how-detailed.md)。

### 「能不能 vibe」的决策框架

把信号清单浓缩成一个决策表：

| 项目特征 | 决策 | 理由 |
|---------|------|------|
| 一次性脚本、探索性 POC、返工成本≈0 | ✅ 随便 vibe | Karpathy 自己限定的「throwaway weekend projects」 |
| 单功能、0.5–2 天、你自己能完全看懂 | ⚠️ vibe + 配验收检查 | 满足黄金法则，但加个 pass/fail 检查兜底 |
| 中型功能、>3 天、跨多文件/多层 | ❌ 必须切 spec | 越过复杂度悬崖，vibe 必然绕成乱麻 |
| 有真实用户、生产代码、需对结果负责 | ❌ 严禁纯 vibe | 违背黄金法则的代码不许进生产 |
| 上下文已过半、纠正 AI 超过两次 | ❌ 立刻停 | 官方明确的上下文已被污染信号 |

### 老板看到 demo 就以为做完了：怎么管理这段预期差

前面几节解决的是「你自己什么时候该停」。还有一种情况是你已经决定要停下来补 spec，但老板不同意——因为他上周看过那个 vibe 出来的 demo，觉得「不是已经能跑了吗，怎么还要两个月」。这一节讲怎么跟他把这段差距说清楚。

**先承认对方没错，是「能跑」的定义不同。** demo 确实能跑，只是跑的是被挑好的那条路径：一个账号、一份干净数据、你演示时点的那几个按钮。产品要跑的是所有路径。你要争的不是「demo 是假的」，而是「demo 覆盖的是 happy path，剩下的工作量在别的地方」。

**用一个具体数字给对方一个可以记住的比例。** 有个开发者把自己一个上线项目的工时全程记了下来：vibe 出可用原型花了约 1 小时，做到真能上线一共花了约 100 小时——差不多 100 倍（[The 100 hour gap](https://kanfa.macbudkowski.com/vibecoding-cryptosaurus)，实践，2026-03，HN 262 分 / 331 评论）✅。这 99 小时花在哪，作者列得很清楚：UI 在移动端的实际排版、把核心生成逻辑跑 200 次找边界情况、S3/Lambda/环境变量/域名这类基础设施、限流和并发、合约权限收口和多签、以及上线当天的退款与救火。注意这里没有一项是「写业务代码」。

作者自己引的是 Tom Cargill 的老规律：前 90% 的代码占掉前 90% 的时间，剩下 10% 的代码占掉另外 90% 的时间。AI 把第一个 90% 压缩了，第二个 90% 一点没动。这句话对非技术管理者特别好用，因为它不依赖任何 AI 知识。

**把 demo 明确定性为「一次需求确认」，而不是「一次交付」。** HN 上那篇讲 PM 用 vibe coding 的讨论里，作者自己的定位就是这个：文档和线框图很难把一个功能讲明白，做个原型能让一大群人瞬间理解要做什么（[My spicy take on vibe coding for PMs](https://www.ddmckinnon.com/2026/02/11/my-%f0%9f%8c%b6-take-on-vibe-coding-for-pms/) 及其 HN 讨论，社区，2026-02，HN 206 分 / 191 评论）✅。同一串讨论下也有人补了反面：真正难的从来不是写代码，是写错了代码——错的需求、错的用户、没人在乎的场景。这两句合起来正好是你要的话术：demo 的价值是把「错的需求」提前暴露掉，这个价值很大，但它兑现的是需求确认，不是工程交付。

**给三个可以直接说出口的句子：**

1. 「这个 demo 帮我们确认了要做什么，我按它写一份验收清单，你签字，我按清单排期。」——把 demo 转成 spec 的输入，顺势接上前面的三步动作。
2. 「demo 现在支持 1 个用户、1 份测试数据、我演示的那 3 个操作。要支持真实用户，缺的是 A/B/C。」——A/B/C 用上面那份工时清单里的类目替换成你项目的实际项，越具体越好。
3. 「我可以下周就上线现在这版，前提是我们接受它挂了不保证多久能修。」——把风险明码标价交回给决策者，比说「不行」有效。

**别在会上现场改 demo。** 一旦你当场加了个字段就跑通了，对方对成本的估计只会更低。要改就带回去，下一次汇报时同时给出「这个改动实际花了多久」。

---

## Claude Code 实战

### plan mode：vibe 的天然刹车

在 Claude Code 里，「从 vibe 切 spec」最顺手的入口是 plan mode。它强制只读、只出方案，把「探索」和「执行」物理隔离，正好对应官方的「先探索、再计划、再写码」。

具体四步：

1. 感觉到信号触发（比如已经纠正 Claude 第三次了），立刻连按两次 `Shift+Tab` 进 plan mode。
2. 让 Claude 在只读模式下重新探索相关代码，把它对问题的理解写出来给你 review。这一步往往能暴露 vibe 阶段积累的误解。
3. 让它用上面的访谈式 prompt 产出 `SPEC.md`，你 review 确认。
4. 开一个新 session、带着书面 spec 执行，别在原会话继续。

> 边界提醒：本篇只讲「何时停 + 停下来补 spec」这个动作。spec 定了之后如何一轮轮执行、怎么验收、怎么派 SubAgent，是 [#031 plan→execute→review 循环](../04-execution-workflow/031-plan-execute-review-loop.md) 的职责。本篇是 031 的上游。

### 三档「从 vibe 切 spec」姿势

| 档位 | 怎么做 | 适用 | 仪式感 |
|------|-------|------|--------|
| **轻量** | `/clear` + plan mode 手写 `SPEC.md` | 单功能、信号刚触发 | 低，零额外工具 |
| **技能链** | superpowers 的 `brainstorming → writing-plans` | 需求还模糊、要引导式收敛 | 中，装插件 |
| **全流程 gated** | GitHub Spec Kit 的 `/speckit.*` 命令链 | 项目已大到必须团队协作 | 高，四阶段 gated |

绝大多数「个人项目 vibe 翻车」的场景，用第一档（plan mode 手写 spec）就够了。Spec Kit 的重量见 020 篇的分析，小任务用它反而过重。

---

## 横向对比

| 维度 | Claude Code | Cursor | GitHub Copilot | Gemini CLI |
|------|------------|--------|----------------|------------|
| **「防 vibe」的原生机制** | plan mode（只读强制）+ `/clear` + AskUserQuestion 访谈 | `.cursor/rules` + chat 引导，无原生只读强制 | `agents.md` + Spec Kit `/speckit.clarify` | Spec Kit 集成 |
| **从 vibe 切 spec 的入口** | 连按两次 `Shift+Tab` 进 plan mode | 依赖人工切换 + rules | `/speckit.specify` | `/speckit.specify` |
| **上下文管理** | 官方明确「context window 是最重要的资源」+ 两次纠正即 `/clear` | Composer 上下文压缩（社区反馈会引发死循环） | Spec Kit 把上下文固化进 spec 文档 | Spec Kit 同上 |

共性观察：vibe coding 翻车是一个工具无关的现象。Cursor 被称作「vibe coding 的摇篮」，它的 CEO 反而最先出来警告这套玩法的危险。

差异在于各工具「防 vibe 原生刹车」的成熟度。Claude Code 的 plan mode（只读强制）加 `/clear` 加访谈式提问，把「停下来规划」做得最顺；Cursor 更多依赖人工纪律；Copilot 和 Gemini CLI 靠 Spec Kit 的 gated 流程。来源：[Best practices](https://code.claude.com/docs/en/best-practices)（官方）、[Fortune: Cursor CEO](https://fortune.com/article/cursor-ceo-vibe-coding-warning/)（一手新闻）。

---

## 反模式

- ❌ **把 vibe coding 等同于「用 AI 写代码」。** Simon Willison 明确说过：「Vibe coding is NOT the same thing as writing code with the help of LLMs」。用 AI 且看懂每一行改动，是正常的 AI coding；用 AI 且一路 `Accept All` 不看，才是 vibe coding。混淆两者，你要么会妖魔化 AI，要么会毫无防备地 vibe。✅（Simon Willison）
- ❌ **把周末项目的姿势用到生产代码。** Karpathy 原文自己限定了「throwaway weekend projects」。越过这条线，就是 Cursor CEO 说的「摇晃的地基 + 一层层加盖 = 最后垮掉」。✅（Karpathy + Cursor CEO Truell）
- ❌ **纠正 Claude 超过两次还不 `/clear`。** 官方明确：上下文已被失败的尝试污染，继续只会越改越错。两次是硬上限。✅（官方 best-practices）
- ❌ **用 prompt 糊过去而不找根因。** 每一次「糊过去」都留下一笔无文档的技术债，累积到复杂度悬崖就是断崖崩盘。⚠️（r/cursor 1j6ufkg）
- ❌ **上下文过半还在硬刚。** 官方原话「performance degrades as it fills」（上下文越满性能越差）。AI 已经开始遗忘早期约定，你却还在基于它的输出做决策。立刻 `/clear` + 回写 spec。✅（官方 + r/webdev）
- ❌ **把「不能解释的代码」commit 进仓库。** 这违背 Simon Willison 的黄金法则。生产代码必须能向别人讲明白。✅（Simon Willison）
- ❌ **拿 vibe 出来的 demo 直接向上汇报「功能已完成」。** demo 跑的是你挑好的那条路径，产品要跑的是所有路径。一次记录完整工时的实践显示，原型 1 小时、上线 100 小时，差的 99 小时全在边界情况、基础设施、限流并发和上线救火上。汇报时把 demo 定性成「需求已确认」，别定性成「功能已完成」。✅（The 100 hour gap）
- ❌ **以为「换个更强的模型」能救 vibe 翻车。** V2EX wingtao 论证过：这是「问题复杂度的自然结果，不是模型能力问题」。复杂度不会因为模型变强而消失，只会换个形式出现。✅（V2EX + Cursor CEO Truell）

---

## 延伸

**交叉引用：**
- [#021 动手前到底要不要先写 PRD / 需求文档？写多详细才够？](./021-prd-before-coding-how-detailed.md) —— 本篇给「必须停下来」的信号（vibe 为什么翻车），021 给「停下来之后 PRD 写到什么详细度」，最重的一档就是全流程 SDD。从 vibe 切 spec 的落地手册。
- [#022 怎么把一个大需求拆成 AI 能一次做对的子任务？](./022-task-decomposition-for-ai.md) —— 本篇信号 4、8 触发后，往往发现任务太大，022 接「怎么拆」。vibe 翻车的常见根因之一就是任务没拆。
- [#031 plan → execute → review 的正确循环怎么做？](../04-execution-workflow/031-plan-execute-review-loop.md) —— 本篇是「何时从 vibe 切 spec」（需求侧动机），031 是「spec 定了之后如何一轮轮执行」（执行纪律）。本篇是 031 的上游。
- [#012 上下文窗口要爆了怎么办？](../02-context-engineering/012-context-window-exploding.md) —— 本篇信号 6（上下文腐烂）的机制层展开在 012。本篇讲「何时因上下文问题停下来」，012 讲「上下文塞满的机制与处置」。

**参考资料：**
- [Andrej Karpathy: vibe coding 定义推文 — X/Twitter](https://x.com/karpathy/status/1886192184808149383) — 一手：「forget that the code even exists」「Accept All, I don't read the diffs」「It's not too bad for throwaway weekend projects」（一手，2025-02-02）✅
- [Best practices for Claude Code — Claude Code Docs](https://code.claude.com/docs/en/best-practices) — 官方：「Explore first, then plan, then code」「context window fills up fast, performance degrades」「Claude stops when the work looks done」「两次纠正即 /clear」、五种常见失败模式（trust-then-verify gap / infinite exploration 等）（官方，2026-06）✅
- [Cursor CEO warns vibe coding builds shaky foundations — Fortune](https://fortune.com/article/cursor-ceo-vibe-coding-warning/) — 一手新闻：Michael Truell 在 Fortune Brainstorm AI 大会发言「close your eyes... shaky foundations... add another floor... things start to kind of crumble」、定义 vibe coding（一手新闻，2025-12）✅
- [India Today: Cursor CEO says AI vibe coding is not good coding — everything will start to fall apart soon](https://www.indiatoday.in/technology/news/story/cursor-ceo-says-ai-vibe-coding-is-not-good-coding-everything-will-start-to-fall-apart-soon-2841988-2025-12-26) — 二手印证：同一段 Truell 引语的另一转述版本，交叉印证 CEO 言论真实性（新闻，2025-12）✅
- [Vibe coding — Simon Willison](https://simonwillison.net/2025/Mar/19/vibe-coding/) — 社区权威：「Vibe coding is NOT the same thing as writing code with the help of LLMs」「building software with an LLM without reviewing the code it writes」、生产环境黄金法则「won't commit any code I couldn't explain exactly what it does」、复述完整 Karpathy 推文（社区权威，2025-03）✅
- [Spec，真的能解决 AI Coding 的问题吗？ — V2EX 1183614](https://www.v2ex.com/t/1183614) — 社区：一次性生成 spec 的机制性失败（模型快速收敛倾向）、小任务 vs 大任务的复杂度悬崖（「超过一周的复杂任务一次性 Spec 几乎必然失效，这不是模型能力问题，而是问题复杂度的自然结果」）、graymmon 的 vibe→spec 重构案例、GeruzoniAnsasu 的 spec 工作流（社区，2026-01）✅
- [The 100 hour gap between a vibecoded prototype and a working product](https://kanfa.macbudkowski.com/vibecoding-cryptosaurus) — 实践：作者记录单个上线项目的完整工时，原型约 1 小时、上线约 100 小时；99 小时的去向清单（UI 实际排版、200 次边界测试、S3/Lambda/域名、限流并发、合约权限与多签、上线救火），并引 Tom Cargill「后 10% 的代码占另外 90% 的时间」（实践，2026-03；[HN 47386636](https://news.ycombinator.com/item?id=47386636) 262 分 / 331 评论）✅
- [My spicy take on vibe coding for PMs](https://www.ddmckinnon.com/2026/02/11/my-%f0%9f%8c%b6-take-on-vibe-coding-for-pms/) — 社区：把原型定位为「让一大群人瞬间理解要做什么」的沟通手段而非交付物；HN 讨论区补充「难的不是写代码，是写错的代码——错的需求、错的用户、没人在乎的场景」（社区，2026-02；[HN 47240736](https://news.ycombinator.com/item?id=47240736) 206 分 / 191 评论）✅
- [Does "vibe coding" hit a massive wall once your project gets big? — r/cursor 1q1v99l](https://www.reddit.com/r/cursor/comments/1q1v99l/does_vibe_coding_hit_a_massive_wall_once_your/) — 社区：「vibe code itself into infinite knots and make architectural decisions that would make a codebase impossible to maintain」（社区，2025）⚠️（Reddit 反爬，引文来自多次搜索一致片段）
- [Vibe coding is a trap in the long run — r/cursor 1j6ufkg](https://www.reddit.com/r/cursor/comments/1j6ufkg/vibe_coding_is_a_trap_in_the_long_run/) — 社区：「Spaghetti code happens when I 'prompt through' an issue, instead of [understanding it]」——prompt through 命名出处（社区，2025）⚠️（搜索片段级）
- [The AI Coding Death Spiral — r/vibecoding 1m37cyl](https://www.reddit.com/r/vibecoding/comments/1m37cyl/the_ai_coding_death_spiral/) — 社区：「enter for speed, stay for the debugging hell」——death spiral / debug 地狱描述（社区，2025）⚠️（搜索片段级）
- [I Tried Vibe Coding and I Need Advice — r/webdev 1qdbsyf](https://www.reddit.com/r/webdev/comments/1qdbsyf/i_tried_vibe_coding_and_i_need_advice/) — 社区：context rot 症状——项目超出单次上下文窗口后「extremely vulnerable to context rot」（社区，2025）⚠️（搜索片段级）
- [Cursor CEO says vibe coding will make your app crumble — r/ExperiencedDevs 1q75d1w](https://www.reddit.com/r/ExperiencedDevs/comments/1q75d1w/cursor_ceo_says_vibe_coding_will_make_your/) — 社区：开发者社区对 Truell Fortune 言论的讨论（社区，2025-12）⚠️（二手转述帖，CEO 言论主源为 Fortune）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验——你 vibe coding 翻过车吗？在什么项目、什么复杂度拐点翻的？你个人用 Simon Willison 黄金法则还是「两次纠正即停」？从 vibe 切 spec 你通常用 plan mode 还是直接手写 SPEC.md？]`
