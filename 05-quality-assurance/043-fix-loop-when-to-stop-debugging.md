# 043. AI 改不对 bug、陷入 fix loop / 越改越糟，什么时候必须停、怎么跳出？

> 难度：高级
> 主题：质量保证
> 工具：Claude Code · 横向(Cursor / Copilot / …)
> 题型：排错题 + 决策题

> ⏰ 时效声明：本篇引用的模型和配置故事都是当时的快照。比如 4-23 postmortem（2026-04 发布）里记录的 reasoning effort 从 high 降到 medium 事件（发生在 2026-03-04），以及 Cursor 论坛里 Sonnet 4.0 卡循环的报告（2025-05）。模型和默认配置会随版本变化，这些案例只是用来证明"配置退化会引发 fix loop"这个机制，不代表当前模型的行为。本篇的决策框架（纠正 2 次就 /clear、失败 3 次质疑架构、迭代 5 次设上限）跟模型版本无关，长期有效。

## TL;DR

先说结论。AI 改一个 bug，改了 5 轮还在原地转圈，越改越编出新的幻觉，甚至把本来能跑的代码改崩了。这通常不是"模型不够强"或者"再试一次就好"，而是你陷进了 fix loop——AI 反复修同一个 bug 却始终修不对的死循环。

Mark Essien 的实战经历最能说明问题。一个本该 2 天搞定的 bug，他和 AI 折腾了将近两周。原因是 AI 一直在改主代码、想办法掩盖问题，而不去碰真正的根因。

> AI kept changing the main code and trying to mask the problem.

最后发现根因只是别处的一行代码：变量 `x` 在运行时被改成了 `x + speed`，AI 始终没碰它。他的结论是：AI 能修对前 3 个问题，但卡在第 4 个上；一旦你彻底卡死，最终产出就是 0（[LinkedIn @markessien](https://www.linkedin.com/posts/markessien_i-and-ai-had-been-struggling-to-fix-a-bug-activity-7333369661352284161-ZKXS)，社区，2025-05）。

> AI fixes 3 things correctly, but is stumped at the fourth. If you grind to a halt, then ultimately, your output is 0.

本篇给一套调试阶段的决策方法，不重复讲验证体系、人工审查、查幻觉这些内容——那些分别见 [#040](./040-who-verifies-ai-code-and-how.md)、[#041](./041-how-to-review-ai-generated-code.md)、[#042](./042-hallucinated-apis-and-dependencies.md)。本篇只回答三个问题：为什么会陷进去（4 类根因）、什么时候必须停（分层的硬触发框架）、怎么跳出（按根因匹配不同策略）。

五点速记：

1. 改不对是普遍现象，不是个例，而且有隐性成本、会越改越糟。tonybai 说"AI 帮我省了 30 分钟敲代码的时间，我却花了 2 小时去 Review 和填坑"，还提出"90% 陷阱"（[tonybai](https://tonybai.com/2025/12/17/ai-programming-90-percent-trap-generation-vs-bug-fix/)，社区，2025-12）。官方一个 caching bug 曾让 Claude"越干越想不起来自己为什么要这么干"（[4-23 postmortem](https://www.anthropic.com/engineering/april-23-postmortem)，官方）。
2. 陷进去有 4 类根因：上下文污染、只做局部修复缺全局因果、问题定义就错了、模型能力到顶或配置退化。详见"为什么"一节。
3. 何时停有硬触发。官方说"纠正 2 次仍错就 /clear"，obra 说"失败 3 次就质疑架构"，Medium 说"迭代上限设 5 次"，三层递进。详见"怎么做"一节的决策框架。
4. 跳出要按根因匹配，不是一条线性 checklist。可选的策略有：/clear 重开、用 systematic-debugging 方法、git reset 回退、换模型、拆问题、人接手。详见"怎么做"一节的跳出策略矩阵。
5. 健康的 fixloop 和失控的 fix loop 是同一机制的两面。让 AI 自己跑测试、自动闭环验证本身是好事（官方叫"the loop closes on its own"）。失控只发生在三个条件同时缺失时：缺真实验证信号、缺迭代上限、缺人来盯着。别因噎废食。

划一下边界。本篇只讲调试阶段"改不对"的决策。需求阶段（写之前、写之中该不该停下来规划）见 [#023](../03-spec-and-planning/023-vibe-coding-when-to-stop-and-plan.md)。验证体系见 [#040](./040-who-verifies-ai-code-and-how.md)。人工审查见 [#041](./041-how-to-review-ai-generated-code.md)。幻觉的查和防见 [#042](./042-hallucinated-apis-and-dependencies.md)。systematic-debugging 这个 skill 的完整流程见 [superpowers](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md)，本篇只取它的决策触发点。

---

## 为什么

### 本篇接住 040/041/042 掉下来的深水区

[#040](./040-who-verifies-ai-code-and-how.md) 的反模式一节有一句话："验证一直不过、越改越糟还硬撑，就转 043。" [#041](./041-how-to-review-ai-generated-code.md) 有一句话："review 发现问题让 agent 改、越改越糟，就转 043。" [#042](./042-hallucinated-apis-and-dependencies.md) 有一句话："查出来幻觉让 agent 改、越改越编新幻觉，就转 043。"

这三句话都默认了一个前提：只要让 AI 改，它就能改对。当这个前提崩了，就是本篇要接住的地方。

再和 [#023](../03-spec-and-planning/023-vibe-coding-when-to-stop-and-plan.md) 切分清楚，这是本篇最关键的边界。023 讲的是需求阶段：vibe coding 写之前和写之中，需求不清或复杂度超限时，该不该停手转去写 spec。本篇讲的是调试阶段：验证失败之后，AI 改了 N 轮还不对、越改越糟、改出新 bug，该不该停手换个方法。两者的阶段、触发条件、动作链完全不同。

两者都会用到 `/clear`，但触发点不一样。023 讲的是需求侧为什么要 /clear，本篇讲的是调试侧什么时候必须 /clear，动作相同但动机不同。所以本篇不重复列 023 的信号清单和决策框架。特别说明一点：023 的信号 #2"纠正超过 2 次"和本篇 L1"纠正 2 次仍错"，引用的是同一条官方铁律（more than twice），只是用在不同阶段——023 当作需求侧写之中的信号，本篇当作调试侧验证失败后的硬触发。

### 改不对是普遍现象，有隐性成本，会越改越糟

这不是个别倒霉蛋的遭遇，而是 AI 在调试阶段的普遍失效。更麻烦的是它的隐性成本，往往远超生成代码省下的那点时间。

tonybai 描述的"90% 陷阱"是典型。AI 写的代码往往 90% 可用，剩下 10% 充满隐蔽的 bug、过时的库引用和糟糕的结构。结果就是"AI 帮我省了 30 分钟敲代码的时间，我却花了 2 小时去 Review 和填坑"。生成 1 分钟、修 bug 1 小时，是常态（[tonybai](https://tonybai.com/2025/12/17/ai-programming-90-percent-trap-generation-vs-bug-fix/)，社区，2025-12）。

Mark Essien 的两周更极端。一个本该 2 天的 bug 花了将近两周，根因只是别处一行 `x + speed`，AI 一直在改主代码来掩盖问题。他的核心判断是：AI 真正的速度，不在于它修好第一批任务有多快，而在于它修完所有任务要多久（[LinkedIn @markessien](https://www.linkedin.com/posts/markessien_i-and-ai-had-been-struggling-to-fix-a-bug-activity-7333369661352284161-ZKXS)，社区，2025-05）。

> The total speed of AI is not just in how it fixes the first tasks, but how long it takes to fix ALL tasks.

官方的 4-23 postmortem 给出了机制层面的证据。一个 caching bug 让 Claude 继续执行，但越来越想不起来自己当初为什么要这么做，表现出来就是用户报告的健忘、重复和奇怪的工具选择。这等于官方亲口承认，AI 会越改越没有方向感，正好对应 fix loop 里越改越糟的体感（[4-23 postmortem](https://www.anthropic.com/engineering/april-23-postmortem)，官方）。

> continue executing, but increasingly without memory of why it had chosen to do what it was doing. This surfaced as the forgetfulness, repetition, and odd tool choices people reported.

换个工具也一样。Cursor 里有用户报告 Sonnet 4.0 会无限次地反复跑测试套件，却始终不去真正修复测试。换工具并不免疫（[Cursor Forum](https://forum.cursor.com/t/claude-sonnet-4-0-gets-stuck-in-loops/97598)，仅 meta description 可抓，反爬）。

结论：生成快不等于交付快。当 AI 卡在第 4 个问题上，前面攒下的速度优势会被后面的填坑时间吞光。

### fix loop 的 4 类根因

为什么 AI 会陷进 fix loop？不是单一原因，而是 4 类根因。诊断对根因，才能选对跳出策略。

#### 根因 ① 上下文污染

结论：每一次失败的修复尝试，都在往上下文里塞进更多错误代码和历史报错。到第四第五轮，AI 已经很难在膨胀的上下文里精确定位真正的问题了。（上下文指 AI 一次对话里能"记住"的全部内容。）

官方把这条列为一个显式命名的失败模式。官方文档说，大多数最佳实践都基于一个约束：Claude 的上下文窗口填得很快，越填性能越差；快满的时候，Claude 可能开始"忘记"早先的指令、出更多错。这个失败模式的名字叫"Correcting over and over"（[CC Docs: best-practices](https://code.claude.com/docs/en/best-practices)，官方，2026-06）。

> Claude does something wrong, you correct it, it's still wrong, you correct again. Context is polluted with failed approaches.

社区也有同样的观察：修 bug 需要聚焦，而 AI 的每一次修复尝试都在稀释聚焦（[掘金](https://juejin.cn/post/7650463834928889908)，社区，2026-06）。

怎么诊断这一类：你已经就同一个问题纠正 AI 2 次仍错，或者对话已经很长、塞满了多轮失败的 diff 和报错栈。

#### 根因 ② 只做局部修复，缺全局因果

结论：AI 遇到报错的第一反应，是在报错附近找问题、改掉它。但很多 bug 的根因不在报错那一行，而是来自上游的数据格式错误、被忽略的边界条件、或架构层面的设计缺陷。AI 改的只是症状，根因始终没碰。

掘金有个贴切的比喻：AI 不擅长"后退一步"审视全局，它像一个拿着手电筒找钥匙的人，灯光照到哪里就找哪里。作者还有一句：AI 会在同一个坑里以不同的姿势跌倒，它换了变量名、改了逻辑顺序、加了防御性判断，但根因它始终没碰（[掘金](https://juejin.cn/post/7650463834928889908)，社区）。

Mark Essien 的案例就是这一类。AI 不停冒出越来越多美妙的理论，做各种表面上的改动来试图修问题，但一直在改可见的症状，真正的根因（别处的 `x + speed`）它从没看到（[LinkedIn @markessien](https://www.linkedin.com/posts/markessien_i-and-ai-had-been-struggling-to-fix-a-bug-activity-7333369661352284161-ZKXS)）。

dev.to 从另一个角度点破了原因：AI 没有完整的上下文，它不记得你的状态在过去 30 次调用里是怎么变化的，也看不到那个只在周五、只在预发环境才出现的诡异异步竞态（[dev.to](https://dev.to/dev_tips/ai-killed-my-coding-brain-but-im-rebuilding-it-4i35)，社区）。

> AI doesn't have full context. It doesn't remember how your state mutated over the last 30 calls.

怎么诊断这一类：每个 fix 都在新地方发现新问题，报错的位置在不停漂移。这正是 obra 列的一条 Red Flag——"Each fix reveals new problem in different place"。

#### 根因 ③ 问题定义就错了

结论：你连问题都没定义对就让 AI 改，它当然转圈。根因不在模型，在你喂给它的那个"问题"。

tonybai 说得直接：问题不在模型，而在你的工作流；大多数人还在用"抽盲盒"的方式通过聊天框写代码，这叫 Vibe Coding，不叫 Engineering。用抽盲盒的姿势去 debug，必然转圈（[tonybai](https://tonybai.com/2025/12/17/ai-programming-90-percent-trap-generation-vs-bug-fix/)，社区）。

知乎补了一层机制。当你直接让 AI 改一个没定义清楚的 bug，你其实在要求它同时完成两件极其困难的任务：一是理解问题，二是解决问题。让它边理解边改，两件难事挤在一起，注意力发散，逻辑坍塌（[知乎 @郝敬](https://zhuanlan.zhihu.com/p/1959760698503598667)，社区，2025-10）。

obra 给出了判断标准：修复失败 3 次之后，就该意识到这不是一个失败的假设，而是架构本身就错了——也就是问题定义错了（[obra: systematic-debugging](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md)，社区权威）。

> This is NOT a failed hypothesis - this is a wrong architecture.

怎么诊断这一类：AI 反复修同一个区域但不收敛；你自己也说不清"修好的标准是什么"；你给 AI 的是一句"fix this bug"，而不是"这个症状 + 这个预期行为 + 这个失败的测试"。

#### 根因 ④ 模型能力到顶，或配置退化

结论：有些 bug 就是当前模型或当前配置搞不定。这不是你的错，也不是 AI 不努力，是能力上限。

官方 4-23 postmortem 给了配置退化的实例。3 月 4 日，官方把 Claude Code 的默认 reasoning effort 从 high 改成了 medium，事后承认这是个错误的取舍；改完不久，用户就开始反映 Claude Code 变笨了。配置变更会静悄悄地拉低调试能力，而且用户一开始分不清是模型变笨了，还是自己运气差（[4-23 postmortem](https://www.anthropic.com/engineering/april-23-postmortem)，官方）。

> This was the wrong tradeoff.

dev.to 说的是能力上限：你可以尽情靠 AI 写代码，但一旦有东西以意料之外的方式坏掉，AI 就只能靠猜（[dev.to](https://dev.to/dev_tips/ai-killed-my-coding-brain-but-im-rebuilding-it-4i35)，社区）。

V2EX 上的社区直觉更干脆：到点就换模型，"直接开除啊，说明这个 AI 不行"（[V2EX 1187820](https://v2ex.com/t/1187820)，社区，2026-01）。

怎么诊断这一类：换一个更强的模型（或提高 effort）之后，同一个 bug 一两轮就过了，反过来就证明之前撞的是模型上限。

### 健康的 fixloop 和失控的 fix loop

先澄清一个容易混淆的点，别因噎废食。fixloop 这个词，在 Waleed Kadous 那里本来是正面的。

他给的定义是：fixloop 就是让 AI 自己看它有没有修好问题，没修好就再试一次。让 AI 自己看 pass/fail、自动闭环，是好事，能把调试时间砍到五分之一甚至更多（[Medium @waleedk](https://waleedk.medium.com/getting-out-of-the-cycle-fixloops-make-ai-codevelopment-more-productive-33d2e40e0e1f)，社区方法论，2025-12）。

> A fixloop is where the AI can see if it fixed the problem or not, and if it didn't, try again.

官方是同一个意思：给 Claude 一个能产出 pass 或 fail 的东西，这个循环就会自己闭合——Claude 干活、跑检查、读结果、迭代，直到检查通过（[CC Docs: best-practices](https://code.claude.com/docs/en/best-practices)，官方）。[#030 TDD](../04-execution-workflow/030-tdd-in-ai-coding.md) 里的红绿信号就是这种 pass/fail。

> Give Claude something that produces a pass or fail, and the loop closes on its own.

那什么时候会失控？Waleed 指出是三个缺失同时出现（[Medium @waleedk](https://waleedk.medium.com/getting-out-of-the-cycle-fixloops-make-ai-codevelopment-more-productive-33d2e40e0e1f)）：

第一，缺真实的验证信号。AI 靠"看起来做完了"自报修好，而不是真去跑 pass/fail。官方也说，Claude 会在工作"looks done"的时候停下；如果没有一个它能跑的检查，"looks done"就是它唯一能拿到的信号。obra 的铁律正好反制这一点：没有新鲜的验证证据，就不允许声称完成（[obra: verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md)）。

> NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE

第二，缺迭代上限。fixloop 会失控跑飞，你可能卡进一个无限循环，AI 反复幻想出同一个修复方案。

第三，缺人来监督。fixloop 很强，但只有当你保持"监督者"的角色、而不是当甩手掌柜时，它才最好使。

所以结论是：fix loop 不是"让 AI 自动改"这件事本身错，而是"盲目自动改"错。配上 pass/fail 信号、迭代上限、加上你盯着，自动闭环反而是加速器。本篇教的"何时停、怎么跳出"，是给失控的 fix loop 兜底，不是否定 fixloop 这个模式。

---

## 怎么做

本篇的核心交付有两个：一个是"何时必须停"的决策框架，一个是"怎么跳出"的按根因匹配策略表。

### 第一交付物：何时必须停的决策框架

结论：何时停不是拍脑袋，而是按严重度递进的分层硬触发，触发任意一层就停。这套框架综合了官方、obra、Medium、掘金四方的说法，不重复列 023 的需求侧信号清单。

#### 分层硬触发（4 层，按严重度递进）

| 层级 | 硬触发信号 | 触发后动作 | 来源 |
|------|-----------|-----------|------|
| L1（最早） | 同一个 bug 纠正 Claude 2 次仍错 | `/clear`，把已验证的事实抢救出来写进 SPEC/CLAUDE.md，新 session 用书面上下文重来 | [CC Docs: best-practices](https://code.claude.com/docs/en/best-practices) |
| L2 | 修复尝试满 3 次仍不对 | 停下，质疑问题定义和架构，回到根因分析，不要去试第 4 次修复 | [obra: systematic-debugging](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md) |
| L3 | 迭代次数到上限（建议 5 次） | 停下，让 AI 报告"学到了什么"，人介入提供方向 | [Medium @waleedk](https://waleedk.medium.com/getting-out-of-the-cycle-fixloops-make-ai-codevelopment-more-productive-33d2e40e0e1f) |
| L4（最严重） | 几十轮还在转圈，或每个修复都在新地方冒出新问题，或 L1–L3 的动作都走过一遍仍不收敛 | 停下，人自己看代码、定位、设计方案，再让 AI 落地 | [掘金](https://juejin.cn/post/7650463834928889908) + obra Red Flags |

L1 的官方原文是：如果你在同一个 session 里就同一个问题纠正 Claude 超过两次，上下文就已经被失败的尝试塞乱了；运行 `/clear`，用一个更具体、写进了你新学到的东西的 prompt 重新开始。一个干净的 session 配一个更好的 prompt，几乎总是胜过一个攒满修正的长 session（[CC Docs: best-practices](https://code.claude.com/docs/en/best-practices)）。

> A clean session with a better prompt almost always outperforms a long session with accumulated corrections.

L2 的 obra 原文是：如果修复不起作用，停下，数一数你已经试了几次修复。如果少于 3 次，回到第一阶段，带着新信息重新分析。如果达到或超过 3 次，停下并质疑架构，不经过架构层面的讨论，不要去试第 4 次修复（[obra: systematic-debugging](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md)）。

> If ≥ 3: STOP and question the architecture — DON'T attempt Fix #4 without architectural discussion

关于 L1 到 L4 的关系：不是"过了 L1 才看 L2"，任何一层触发就该停。L1 最早也最便宜，/clear 几乎零成本；L4 最贵，需要人全程接管。越早触发越省时间。

#### 按问题类型判断该不该继续让 AI 改

结论：不同类型的 bug，该不该继续让 AI 改，答案完全不同（[掘金](https://juejin.cn/post/7650463834928889908)）。

| 问题类型 | 该不该继续让 AI 改 | 理由 |
|---------|-------------------|------|
| 语法错误 / 类型错误 | 继续，这是 AI 强项 | 确定性高，AI 几乎不会错 |
| 运行时报错，原因明显 | 给 1-2 轮 | 给足上下文，几轮能过 |
| 逻辑 bug，几轮没修好 | 换模型或换工具 | 多半撞上根因 ② 或 ③ |
| 几十轮还在转圈 | 停，自己看代码、测试、定位后再给 AI 修 | 根因 ①②③ 叠加，硬刚无效 |
| 架构层面的 bug | 人设计方案，再让 AI 落地 | 根因 ③，问题定义本身要重来 |

一条关键纪律：这套决策框架是本篇原创（综合官方、obra、Medium、掘金分层），不重复列 023 的 8 条信号清单（那是需求侧的：无法逐行解释、纠正超 2 次、用 prompt 糊过去等等）。本篇的触发条件是"验证失败后改不对"，023 是"写之前、写之中需求不清"。

### 第二交付物：按根因匹配的跳出策略表

结论：跳出不是"无脑 /clear"的一条线性 checklist，而是按诊断出的根因匹配不同策略的条件分支。诊断对根因，才能选对策略。

| 根因诊断 | 跳出策略 | 具体动作 | 来源 |
|---------|---------|---------|------|
| ① 上下文污染 | `/clear` 重开 + 抢救事实 | 把"已试过都不行"和"已确认的结论"写进 SPEC.md 或 CLAUDE.md，新 session 用干净上下文加更具体的 prompt 重来 | [CC Docs](https://code.claude.com/docs/en/best-practices) + [V2EX](https://v2ex.com/t/1187820) |
| ② 局部修复缺全局 | 换 systematic-debugging + 两步调试法 | 强制把"分析"和"修复"分成两步；先写单一假设再写最小化测试；一次只改一个变量 | [obra](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md) + [知乎 @郝敬](https://zhuanlan.zhihu.com/p/1959760698503598667) |
| ③ 问题定义错 | 重新定义问题 + 拆问题 | 质疑架构（obra 说 "This is a wrong architecture"）；切 plan mode 重新写 spec（见 [#023](../03-spec-and-planning/023-vibe-coding-when-to-stop-and-plan.md)）；把大 bug 拆成小任务（见 [#022](../03-spec-and-planning/022-task-decomposition-for-ai.md)） | obra + [tonybai](https://tonybai.com/2025/12/17/ai-programming-90-percent-trap-generation-vs-bug-fix/) |
| ④ 模型能力到顶 | 换模型 / 换 effort | 提高 reasoning effort，或换更强的模型（Opus），或换工具。反向验证：换完一两轮就过，说明之前是上限 | [4-23 postmortem](https://www.anthropic.com/engineering/april-23-postmortem) + [V2EX](https://v2ex.com/t/1187820) |
| 已经失控 | `git reset` 回退 | 硬 reset 回这条链的第一个 commit，换思路重做或直接跳过。有人这样描述："它是个死循环……我干脆硬 reset 回那条链的第一个 commit，要么换个思路做，要么跳过它" | [HN 42829466 评论](https://news.ycombinator.com/item?id=42829466) |
| 该人接手 | 人自己 debug | 人读代码、定位根因、设计修复，再让 AI 落地。dev.to 有句话："你没搞懂过的东西没法调试，你没真正写过的东西更别想修好" | [dev.to](https://dev.to/dev_tips/ai-killed-my-coding-brain-but-im-rebuilding-it-4i35) + [掘金](https://juejin.cn/post/7650463834928889908) + [V2EX](https://v2ex.com/t/1187820) |

怎么用这张表：先按"根因诊断"这一列判断你撞上的是哪一类（参考"为什么"一节里每类的"怎么诊断"），再取对应行的跳出策略。多根因叠加很常见，上下文污染和局部修复往往同时出现。这时优先解最便宜的那个（/clear），再解最贵的（人接手）。V2EX 上有两条相关的社区共识：一是"每修一个新开一个对话，这样不会因为上下文太长而降智"；二是"方案 2 更合适，实测方案一结果 BUG 越修越多"（[V2EX 1187820](https://v2ex.com/t/1187820)，楼层昵称以原文为准）。

再强调一条纪律：跳出策略是一棵按根因匹配的条件分支树，这正是本篇作为高级篇的深度所在。中级往往给一条线性 checklist（先试 /clear，不行再换模型）；高级给的是条件分支——根因是污染就 /clear，根因是缺全局就上 systematic-debugging，根因是定义错就重新写 spec。诊断错了根因、选错策略，就白费功夫。

---

## Claude Code 实战

### 场景导览：识别并跳出一个 fix loop

场景：agent 在改一个上传超时 bug，用户反馈上传超过 5MB 时超时。改了 4 轮，每轮都说"我修好了"，跑测试还是错，第 4 轮甚至编出了一个不存在的 API（这一段联动 [#042](./042-hallucinated-apis-and-dependencies.md)）。

第 1 步，诊断根因。这里同时命中了几类：

- 根因 ① 上下文污染：4 轮失败尝试堆积，对话已经很长，塞满了 diff 和报错栈。
- 根因 ② 局部修复：agent 一直在改上传函数本身，但你隐约觉得根因可能在别处（像 Mark Essien 案例里的 `x + speed`）。
- 幻觉：第 4 轮编了个 API。这属于 [#042](./042-hallucinated-apis-and-dependencies.md) 的查防范畴，这里不展开。

第 2 步，触发决策。L2（失败 3 次）已经触发，所以停下，不要去试第 5 次修复。先质疑问题定义：真的是上传函数的问题吗？还是上游的 speed 或 timeout 配置？

第 3 步，按根因匹配跳出策略。先解最便宜的上下文污染：

```
# 3a. 先解上下文污染（最便宜）
/clear

# 3b. 抢救已验证的事实，写进 CLAUDE.md 或 SPEC
# 在 /clear 前手动总结：
# - 症状：上传 >5MB 超时
# - 已试过且无效：改 upload timeout（3 次）、改 buffer size（1 次）
# - 已排除：网络层、服务端接收逻辑
# - 待验证假设：speed 变量在 runtime 被改，影响 timeout 计算
```

第 4 步，新 session 里用 systematic-debugging，解掉局部修复这个根因。用下面的"两步调试法"prompt，强制把分析和修复分开：

```
# 第一步：纯分析（不修复）
这是报错：[粘贴堆栈]。用户反馈上传超过 5MB 时发生。
已排除：网络层、服务端接收逻辑。已试过无效：改 upload timeout、改 buffer size。
请先分析，不要改代码：
1. 哪里失败了？追踪 timeout 变量从定义到使用的完整路径。
2. 这个 timeout 在 runtime 会被改吗？谁改的？
3. 最可能的根因是什么？给单一 hypothesis。

# 第二步：修复 + 测试（分析确认后）
你的「speed 变量在 runtime 影响 timeout」理论合理。
专注修这一个点，不要动 upload 函数本身。
修完为「上传 10MB」场景加测试，跑测试给我看输出。
```

第 5 步，验证。agent 跑测试，你看到的应该是测试的实际输出（证据），而不是它嘴上说"我修好了"（声称）。obra 的铁律是："永远先给证据，再谈结论"（[obra: verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md)）。

> Evidence before claims, always.

### 两步调试法 prompt 模板（可抄可改）

知乎的核心方法就一句：强制把"分析"和"修复"两个步骤分开。它建议的心态是把 AI 当成一个"天赋异禀但缺乏经验的实习生"，你需要正确地引导它，而不是把它当成一个"什么都懂的魔法黑盒"（[知乎 @郝敬](https://zhuanlan.zhihu.com/p/1959760698503598667)）。

```
# 第一步：纯分析（禁止改代码）
这是报错 [粘贴堆栈]。
请分析（不要改代码）：
1. 哪里失败了？
2. 这段代码如何被使用？数据怎么流的？
3. 最可能的原因是什么？给单一 hypothesis。

# 第二步：修复 + 测试（分析确认后）
你的 [假设] 理论合理。专注 [这个点] 修复，忽略 [其他]。
修复它，并为 [具体场景] 加测试，跑测试给我看输出。
```

### systematic-debugging 的决策触发点

[obra 的 systematic-debugging skill](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md) 是一套"在动任何 bug 之前先做根因分析"的方法论。本篇不展开它的完整流程，只取几个决策触发点。

何时启用（obra 原文）：尤其在这些情况下用它——你有时间压力、"就快速改一下"看起来很显然、你已经试过多次修复、上一次修复没起作用、你还没完全搞懂这个问题。这些正好对应你已经陷在 fix loop 里的状态。

何时停手换法（obra 原文）：达到或超过 3 次修复失败，停下并质疑架构，不经过架构讨论不要去试第 4 次。

为什么系统性方法比硬刚快（obra 原文）：系统性方法修一个 bug 要 15 到 30 分钟，随机乱改要 2 到 3 小时的反复折腾，一次修对的成功率是 95% 对 40%。

Iron Law（obra 原文）：没有先做根因调查，就不允许动手修（[obra: systematic-debugging](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md)）。

> NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST

这个 skill 的四阶段完整流程见 [superpowers: systematic-debugging](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md)，本篇不展开。

---

## 横向对比（弱化）

本篇不做工具的横向大表，只回答一个问题：别的工具会不会陷 fix loop？换工具有没有用？

会陷。Cursor 里的 Sonnet 4.0 也被报告过，会无限次地反复跑测试套件，却始终不去真正修复测试（[Cursor Forum](https://forum.cursor.com/t/claude-sonnet-4-0-gets-stuck-in-loops/97598)，反爬）。fix loop 不是某个工具独有的问题，是 LLM 调试的共性失效。

换模型、换工具确实是跳出策略之一（对应上面跳出策略表里的根因 ④）。但要先诊断是不是真的撞上了模型上限。如果是根因 ①②③，换工具不解决问题，反而会把同样的上下文污染带到新工具里去。

---

## 反模式

- 硬刚，想着"再试一次就好"。官方把"Correcting over and over"列为一个显式命名的失败模式，说这时上下文已经被失败的方法污染了。纠正 2 次仍错就 /clear，这是硬上限，不是建议。
- 相信 AI 每轮说的"我修好了"。obra 说没有新鲜的验证证据就不许声称完成，官方说 Claude 会在"看起来做完"的时候停下。每一轮都要看证据（测试输出），别信声称。
- 让 AI 边理解问题边改，不分离分析和修复。知乎指出这等于要求 AI 同时完成理解和解决两件难事，注意力发散。要强制用两步调试法。
- 一直改症状不碰根因。掘金说 AI 会在同一个坑里以不同姿势跌倒，根因始终没碰；Mark Essien 说 AI 一直在改主代码来掩盖问题。这时要换 systematic-debugging。
- /clear 的时候不抢救已验证的事实。失败的尝试里也有真金白银的认知，比如哪些方法试过不行、哪些已经排除。/clear 之前要手动总结、写进 SPEC 或 CLAUDE.md，否则新 session 从零开始会重蹈覆辙。
- 把 fixloop 当成"自动改"的错，因噎废食。Waleed 的 fixloop 原意是健康的自动闭环（依赖官方的 pass/fail 信号），只有失控才坏。配上迭代上限、人来监督、真实的 pass/fail 信号，就能放心用。
- 把需求侧的信号混进来触发。"需求不清、复杂度超限、vibe coding 该停"是 [#023](../03-spec-and-planning/023-vibe-coding-when-to-stop-and-plan.md) 的活（需求侧何时停），本篇是调试侧（验证失败后改不对）。别把两个阶段的触发条件搅在一起。

---

## 延伸

**交叉引用：**

- [#023 Vibe coding 为什么会翻车？什么时候必须停下来规划？](../03-spec-and-planning/023-vibe-coding-when-to-stop-and-plan.md)：需求侧何时停。这是本篇最关键的边界，023 讲需求侧、043 讲调试侧，都会用 /clear 但触发点不同。
- [#040 AI 说"做完了"、测试也全绿，怎么知道代码是真的对？](./040-who-verifies-ai-code-and-how.md)：验证体系总览。本篇是它反模式一节"越改越糟→043"那句指针的展开，040 给体系，本篇给改不对的决策。
- [#041 AI 一次吐几百行 diff 我读不过来、让它自己 review 它只说自己写得好——怎么 review AI 生成的代码？](./041-how-to-review-ai-generated-code.md)：人工审查的执行侧。注意本篇的"人接手"跳出策略不等于 041 的"人审"，041 是审查 AI 的产出，本篇是人自己 debug 取代 AI。
- [#042 AI 写的方法不存在、pip install 报 404、API 参数对不上——幻觉 API 和幻觉依赖怎么查、怎么防？](./042-hallucinated-apis-and-dependencies.md)：幻觉的查和防。本篇根因里的"幻觉修复"联动 042，042 讲怎么查幻觉，本篇讲查出来后让 AI 改、结果越改越编新幻觉怎么办。
- [#030 AI 写的测试一跑就过、还偷偷删测试怎么办？（TDD 在 AI coding 里怎么做）](../04-execution-workflow/030-tdd-in-ai-coding.md)：TDD。健康的 fixloop 依赖 TDD 的红绿 pass/fail 信号来闭合循环。
- [#022 怎么把一个大需求拆成 AI 能一次做对的子任务？](../03-spec-and-planning/022-task-decomposition-for-ai.md)：拆任务。本篇跳出策略里的"拆问题"指向这里，问题定义错时往往要拆。
- [superpowers: systematic-debugging](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md)：skill 完整流程。本篇只取它的决策触发点（3 次质疑架构、先假设再动手），完整流程见此。
- [superpowers: verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md)：完成宣告的验证。本篇"AI 每轮说修好了实际没修"的依据就来自这里的"Evidence before claims, always"。

参考资料：

- [CC Docs: best-practices](https://code.claude.com/docs/en/best-practices)：纠正 2 次仍错就 /clear 的铁律、"Correcting over and over"失败模式、上下文退化、"looks done"、"the loop closes on its own"（官方，2026-06）。
- [Anthropic 4-23 postmortem](https://www.anthropic.com/engineering/april-23-postmortem)：caching bug 导致"越干越想不起来为什么"、effort 从 high 改 medium 导致退化（官方，2026-04）。
- [obra: systematic-debugging](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md)：Iron Law"NO FIXES WITHOUT ROOT CAUSE"、"≥3 次质疑架构"、Red Flags、95% 对 40% 的对比（社区权威，2026）。
- [obra: verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md)："Evidence before claims, always"、"NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"（社区权威，2026）。
- [Medium @waleedk: Getting out of the cycle: fixloops](https://waleedk.medium.com/getting-out-of-the-cycle-fixloops-make-ai-codevelopment-more-productive-33d2e40e0e1f)：fixloop 的正面定义、护栏（迭代上限 5 次、监督者而非甩手掌柜）（社区方法论，Waleed Kadous，2025-12）。
- [知乎 @郝敬: 为什么 AI 总修不对 Bug](https://zhuanlan.zhihu.com/p/1959760698503598667)：两步调试法（强制分离分析和修复）、"同时完成理解和解决两件难事"、实习生比喻（社区，2025-10）。
- [tonybai: AI 编程的 90% 陷阱](https://tonybai.com/2025/12/17/ai-programming-90-percent-trap-generation-vs-bug-fix/)："90% 可用、10% 隐蔽 bug"、"30 分钟省下、2 小时填坑"、"问题在工作流不在模型"（个人博客，文末有极客时间专栏推广，引其方法论部分；社区，2025-12）。
- [掘金: 为什么大模型修不好自己的 bug](https://juejin.cn/post/7650463834928889908)：四类根因、"手电筒找钥匙"、"同一个坑不同姿势跌倒"、何时停判断表（有 Claude Code/DesignArena 推广倾向，引其根因分析部分；社区，2026-06）。
- [LinkedIn @markessien: AI vs Human debugging a bug](https://www.linkedin.com/posts/markessien_i-and-ai-had-been-struggling-to-fix-a-bug-activity-7333369661352284161-ZKXS)："mask the problem"、"2 天的 bug 花了 2 周"、"卡在第 4 个、产出为 0"（社区，2025-05）。
- [dev.to: AI killed my coding brain](https://dev.to/dev_tips/ai-killed-my-coding-brain-but-im-rebuilding-it-4i35)："调试是 AI 崩塌的地方"、"AI 没有完整上下文、记不住过去 30 次调用"、"没搞懂过的东西没法调试"（社区，2025）。
- [HN 42829466 评论](https://news.ycombinator.com/item?id=42829466)：Aider 用户"硬 reset 回第一个 commit"、"死循环……自信笃定的语气"（只引评论，不确认头帖标题；社区）。
- [V2EX 1187820: AI 生成代码多个 bug 怎么办](https://v2ex.com/t/1187820)："BUG 越修越多"、"每修一个新开一个对话"、"直接开除换模型"（社区，2026-01）。
- [Cursor Forum 97598](https://forum.cursor.com/t/claude-sonnet-4-0-gets-stuck-in-loops/97598)：Sonnet 4.0"无限次反复跑测试套件"（反爬，仅 meta description 可抓，只作现象证据；社区，2025-05）。

> 本篇个人实践（L4）：`[待补：BOSS 被 AI 的 fix loop 坑过吗？最惨的一次改了几轮、花了多久？你个人的「何时停」触发点是几次（2 次 /clear 还是 3 次质疑架构）？你用 /clear 重开多还是 git reset 回退多？systematic-debugging skill 你启用过吗、管用吗？两步调试法 prompt 你试过吗？]`
