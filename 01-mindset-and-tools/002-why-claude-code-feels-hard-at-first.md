# 002. 为什么我一开始用 Claude Code 各种不顺、"差点放弃"？卡在哪、怎么顺

> 难度：基础
> 主题：心智与工具
> 工具：Claude Code · 横向(ChatGPT / Cursor / Copilot)
> 题型：排错题 + 场景题

> ⏰ 时效声明：**2026-07-18** 复核。本篇主干论据是 Anthropic 官方 best-practices 的逐字引用（包括 agentic 定义、trust-then-verify gap、两次纠正就 `/clear` 等），不是社区传闻。社区来源只作佐证，抓取状态也在引用处逐条标注：Taggart 一文已复核全文（✅），Reddit 与 Medium 只核到摘要级（⚠️）。文中的 5 个卡点和处方不绑定具体版本，长期有效。

## TL;DR

**结论先说：你觉得 Claude Code "不如 ChatGPT 顺手""全是炒作"，几乎每个过来人都经历过。**

Reddit 上有篇新手帖，作者用了一个月，开篇就写：差点一开始就放弃了，感觉全是炒作、没有真本事。原文是 "I almost gave up on it early on. Felt like it was all hype and no real edge"（[r/ClaudeAI 1m1ihia](https://www.reddit.com/r/ClaudeAI/comments/1m1ihia/claude_code_tips_i_wish_i_knew_as_a_beginner/)，社区，2025）。

但这句话后面有个转折：**不顺的根因不是工具差，是用法错。**

"用错了"这个主题在好几个来源里反复出现。Reddit 新手帖说 "almost gave up"。安全工程师 Taggart 自嘲把自己用成了一只点头喝水的玩具鸟。Medium 一位作者反思自己因此赔了钱，并直言 "Not because Claude Code is bad"（不是因为 Claude Code 差）（[Medium: 5 Mistakes I Made Using Claude Code](https://medium.com/@jaumegallegocusco/5-mistakes-i-made-using-claude-code-that-cost-me-real-money-55b8a8ee09bb)，社区，2025，⚠️ 仅 WebSearch 摘要级核到）。三段话措辞不同，指向同一个结论：卡住往往不是工具不行，是交互姿势没对。

本篇不重复"它是什么、和 ChatGPT 区别在哪"，那部分在 [#001](./001-claude-code-vs-chatgpt-cursor-copilot.md)。这里直接落到操作层：**新手最常卡的 5 个具体场景，每个给出「错在哪 + 正确姿势」。**

先记一句话总纲：

> **给 Claude Code「目标 + 上下文 + 验证方式」，把它当协作者、审查它的每一行改动，该打断就打断、该重来就重来。**

这正是官方强调的 agentic 用法与聊天框习惯的关键差别（[Anthropic: Claude Code Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)，官方，访问日期 2026-06）。

## 为什么

### 先承认一件事：它确实不好上手，但不是你以为的原因

**Anthropic 官方自己都承认这条学习曲线。**

Best practices 开篇的原话是：Claude Code 是一个 agentic coding environment，和"你问它答、然后等着"的聊天机器人不同，它能读你的文件、跑命令、改代码，在你旁观、纠偏或干脆走开的时候自主推进问题；但这份自主性仍然带着一条学习曲线（[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)，官方）。

关键词是 **agentic coding environment**，直译是"智能体式编码环境"。白话说，它不是"你问一句、它答一句"的对话框，而是"你说目标，它自己读文件、跑命令、改代码、看结果、再改"。

**这套交互方式和你用 ChatGPT 练出来的肌肉记忆不一样，中间隔着一段适应期。** 所以你套用 ChatGPT 的习惯来用它，一开始必然别扭。

更扎心的例子来自一个对 AI 持保留态度的安全工程师 Michael Taggart。他硬着头皮用 Claude Code 做完了一个项目。东西是做出来了，但过程让他很难受。他总结自己卡住的原因不是工具，而是交互姿势错了：他说自己的大部分时间就是读模型给的代码改动、然后按 `1` 接受，几乎每次都接受，把自己活成了"辛普森一家里那只点头喝水的鸟"（[Taggart: I used AI. It worked. I hated it.](https://taggart-tech.com/reckoning/)，社区，2025）。

**根因诊断：你不顺，八成不是 Claude Code 烂，是你把它当成了"更聪明的 ChatGPT"在用。**

下面把这句诊断拆成 5 个具体卡点。

### 卡点 1：当聊天框用，不给项目上下文，指望它凭空答

**错法**：打开终端，敲一句"帮我写个登录功能"，然后等它吐代码。它反问"用什么框架""数据库在哪"，你觉得它蠢。又或者你根本没在项目目录里启动，就在一个空文件夹里跟它聊。

**根因**：官方直接说了——Claude 能推断你的意图，但读不了你的心思；你要引用具体文件、说明约束、指出可参考的现有写法（[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)，官方）。ChatGPT 在沙箱里答题，本来就不指望知道你的项目。Claude Code 不一样，它期待你给它具体上下文，也就是哪个文件、什么约定、参考哪个已有实现，然后它去动手。你什么都不给，它只能猜；猜歪了你又怪它。

**正确姿势**：每次开口都带上「文件指针 + 约束 + 参考实现」三件套。别问"加登录功能"。改成问"给 `src/api/auth.ts` 加登录，用项目里 `src/api/users.ts` 已有的校验风格，密码用 bcrypt"。它读了文件、照着现成模式改，命中率天差地别。

### 卡点 2：当打字员用，逐行指挥它怎么改，浪费它的规划能力

**错法**：你怕它改歪，于是事无巨细地下指令——"打开 `payment.ts`，找到第 42 行，在 `if (amount)` 前面加一个 `amount > 0` 的判断……"。你以为这样最安全，结果改一个功能要下十几次指令，比自己写还累。Taggart 那篇自白里"把自己用成喝水鸟、一条条按 1 接受"的状态就是这种。

**根因**：你把一个会自主规划的 agent 当成了只会照做的打字员。官方给的标准节奏是：先探索、再计划、再写码；让 Claude 直接跳到写码，容易写出"解决了错误问题"的代码（[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)，官方）。意思是让它先读代码、再出计划、再动手，而不是你替它把每一步都想好。

**正确姿势**：给目标，别给步骤。说"给 `payment.ts` 加金额校验，跑 `npm test` 验证，参考 `users.ts` 的写法"，让它自己决定读什么、改哪行、怎么测。它出的计划你审一遍再放行。你的角色从"盯着打字员的监工"变成"验收结果的人"，这才是 agent 该有的用法。

"先规划再执行"的完整循环怎么走，见 [#031 plan → execute → review 的正确循环怎么做？](../04-execution-workflow/031-plan-execute-review-loop.md)。

### 卡点 3：不给验证方式就放它跑，它说"done"你不知真假

**错法**：你说"修这个 bug"，它改了一堆，回你一句"修好了"。你看着像那么回事，就接受了。结果上线才发现根本没修，或者修出了新 bug。

**根因**：官方把这条讲得最透。它说 Claude 会在"工作看起来做完了"的时候停下；如果没有一个能跑的检查，"看起来做完了"就是它唯一的信号，于是你成了那个验证环——每个错误都得等你自己发现（[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)，官方）。没有客观标准时，它只能靠"看起来做完了"自我判断，验证责任全压回你身上。官方给这种坑起了名字，叫 **the trust-then-verify gap**（先信任、后验证之间的落差）：它交出一个看起来合理、却没处理边界情况的实现，你一信任就翻车。

**正确姿势**：开口就给它一个能跑出 pass/fail 的验证。官方原话是：给 Claude 一个能产出通过或失败结果的东西，这个循环就能自己闭合（[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)，官方）。这个"验证"可以是测试套件、build 的退出码、linter，或者一个对比截图的脚本。别只说"修这个 bug"，要说"修这个 bug，写一个能复现它的失败测试，改完跑 `pytest` 必须通过"。它改完自己跑、自己看结果、自己迭代，验证环自己闭合，你只看最终证据。

这条怎么落地成 TDD 节奏，见 [#030 TDD 在 AI coding 里怎么做？](../04-execution-workflow/030-tdd-in-ai-coding.md)。

### 卡点 4：一条道走到黑，纠正三五次还不对，越改越乱

**错法**：它改错了，你说"不对，再改"；还是错，"再改"；又错了……你在同一个会话里跟它耗，越纠正它越跑偏，最后连最初的样子都回不去。你以为它笨，其实是你的会话上下文已经被失败的尝试污染了。

**根因**：官方把这种状态命名为 **Correcting over and over**（反复纠正）——Claude 做错了，你纠正，它还是错，你再纠正，上下文被一堆失败的做法塞满（[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)，官方）。每纠正一次，失败的做法就留在上下文里，模型被这些"错误示范"带偏。还有一种相关的坑叫 **the kitchen sink session**（大杂烩会话）：你在一个会话里塞了五件不相干的事，上下文全是噪音。

**正确姿势**：官方的红线很明确——如果同一个问题你在一个会话里已经纠正了两次以上，就跑 `/clear` 重开，用一个更具体、写进了你新学到的东西的 prompt 重新开始（[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)，官方）。两次纠正不过，果断 `/clear` 重开，把刚踩到的坑写进新 prompt。一个干净会话加一个更精准的 prompt，几乎总能跑赢一个堆满纠正的旧会话。

窗口为什么会被这样污染，机制见 [#012 上下文窗口要爆了怎么办？](../02-context-engineering/012-context-window-exploding.md)。

### 卡点 5：不读 diff、想按"2"全盘接受

**错法**：它一口气改了 8 个文件，弹出一堆 diff，你扫一眼觉得"看着对"，就一路按 `1` 接受，甚至动了按 `2`（本次会话所有改动全盘接受）的念头。

**根因**：Taggart 把这种诱惑写得最直白。他说按 `2`（"是的，接受本次会话的所有改动"）实在太诱人了；而一旦你停止审视模型的输出，出事的概率就趋近于 1（[Taggart: I used AI. It worked. I hated it.](https://taggart-tech.com/reckoning/)，社区，2025）。他还点出一个更深的问题：用 agent 写代码，你会从"代码的作者"变成"代码的观众"，只能事后倒推着去理解这段代码。这样理解成本更高，也更容易漏掉隐患。

**正确姿势**：每一行 diff 都要读，每一次都当 code review 来做。Taggart 自己的做法是 TDD 加逐行 review，最后再专门起一个"安全审计"会话，让模型来查自己的漏洞（[Taggart](https://taggart-tech.com/reckoning/)，社区）。官方也支持这种"让 AI 审自己"的做法：让一个新的 subagent 在干净的上下文里，只看 diff 和验收标准来挑错，不带"写这段代码时的偏见"（[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)，官方）。记住：你是掌舵的人，最终进 main 的代码由你负责。

## 怎么做

把每个卡点对应的"一句话正确姿势"汇总成 checklist：

1. **给上下文，别让它猜**：每次指令带「文件指针 + 约束 + 参考实现」。源：[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)（官方）"Provide specific context in your prompts"。
2. **给目标，别给步骤**：让它先探索、出计划、再动手，你审计划。源：[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)（官方）"Explore first, then plan, then code"。详见 [#031](../04-execution-workflow/031-plan-execute-review-loop.md)。
3. **给验证方式，让环自己闭合**：开口就附一个能跑出 pass/fail 的检查（测试、build、linter、截图对比）。源：[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)（官方）"Give Claude a way to verify its work"。详见 [#030](../04-execution-workflow/030-tdd-in-ai-coding.md)。
4. **两次纠正不过就 `/clear`**：别在污染的会话里死磕，清空再重写更精准的 prompt。源：[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)（官方）"After two failed corrections"。
5. **逐行读 diff，该打断就打断**：用 `Esc` 中断、`/rewind` 回退、`"Undo that"` 撤销；长任务另起 subagent 做对抗式 review。源：[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)（官方）"Course-correct early and often"，以及 [Taggart](https://taggart-tech.com/reckoning/)（社区）。
6. **在项目目录里启动，让它读得到 CLAUDE.md**：空目录启动，等于让工程师在白纸上凭空写，必然跑偏。CLAUDE.md 怎么写才生效，见 [#010 CLAUDE.md 怎么写才真的生效？](../02-context-engineering/010-claude-md-how-to-make-it-work.md)。

## Claude Code 实战

### 卡点对照：同一个任务，错法 vs 正确法

```bash
cd ~/my-api && claude

# ❌ 错法 1（当聊天框用）：不给上下文，指望它凭空答
> 帮我加个登录功能

# ✅ 正确法 1（给目标+上下文+参考+验证）
> 给 src/api/auth.ts 加 POST /login：校验邮箱密码，
  参考 src/api/users.ts 里 validateInput 的风格，密码用 bcrypt。
  改完跑 npm test src/api/auth.test.ts 必须全过。
```

### 卡点 3 的实战：给验证方式后，环自己闭合

```bash
# ❌ 错法：没验证，它说"修好了"你就信
> 修一下登录偶尔失败的 bug

# ✅ 正确法：先要一个能复现的失败测试，再修
> 用户反映登录在 session 超时后会失败。
  1. 先在 src/auth/login.test.ts 写一个复现这个 bug 的失败测试
  2. 跑 npm test 确认测试是红的（证明 bug 存在）
  3. 修 src/auth/login.ts，让测试变绿
  4. 跑完整测试套件确认没改坏别的
  每一步都把命令输出贴给我看，别只说"成功了"。
```

官方原话佐证这条节奏：让 Claude 拿出证据、而不是口头声称成功，也就是给你看测试输出、它跑了什么命令、命令返回了什么（[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)，官方）。一句话：要证据，不要它嘴上说"做完了"。

### 卡点 4 的实战：识别"该 `/clear` 了"的信号

```bash
# 你在跟它来回拉锯：
> 改这里  →  它改了 A，但漏了 B
> 把 B 也加上  →  它加了 B，又把 A 改回去了
> 不是这个意思  →  它又理解偏了……

# 🔴 此时官方建议：停下来
> /clear   # 清空上下文

# 重新组织一个更准的 prompt，把刚才踩的坑写进去：
> 注意：修改 payment.ts 时，
  金额校验必须同时满足 (1) 是正整数 (2) 不超过余额，
  两个条件缺一不可，之前改丢了第二条。
```

### 卡点 5 的实战：对抗式 review

```bash
# 它改完一坨，你别只按 1。另起一个干净会话审它：
> 用 subagent review 刚才对 src/api/auth.ts 的改动。
  只看 diff 和这个任务的目标（POST /login + bcrypt + 测试通过），
  找出：边界情况漏处理、和 users.ts 风格不一致的地方、
  有没有引入安全问题。报告问题，不要报告风格偏好。
```

## 横向对比

001 已经做过四个工具的完整横向表，这里不重复，只回答一个具体问题：**同一个卡点，换成 ChatGPT 或 Cursor 会怎样？**

| 卡点 | Claude Code（终端 agent） | ChatGPT（Web 对话） | Cursor（IDE 内嵌） |
|------|------|------|------|
| 当聊天框用 | 你啥都不给，它瞎猜改歪——**卡点最痛** | 本来就是聊天框，**没有"卡点"，因为期待一致** | 介于两者之间，IDE 有索引兜底 |
| 不给验证方式 | 它"看起来 done"就停，**坑最隐蔽**（trust-then-verify） | 你复制它代码自己跑，验证环一直是你 | IDE 内有报错提示，部分兜底 |
| 不读 diff | 终端 diff 要主动看，**诱惑最大**（想按 `2`） | 没有这步，它不直接改你文件 | inline diff 就在编辑器里，**审查成本最低** |

一句话：**Claude Code 的自主性最高，所以"用法错"的代价也最痛。** 同样的错法，ChatGPT 顶多让你白问一次，Cursor 有 IDE 兜着，Claude Code 会让你真金白银地跑偏。这正是很多新手"差点放弃"的来源。完整的四工具对比见 [#001](./001-claude-code-vs-chatgpt-cursor-copilot.md)。

## 反模式

- ❌ **把它当 ChatGPT 用**：一问一答、不给项目上下文、等它吐完整代码自己粘贴。这样你完全没用上它的 agentic 能力，还嫌它"不如 ChatGPT 快"。错法见卡点 1。✅
- ❌ **当打字员使唤**：逐行逐字下指令"打开第 42 行加 if"。这浪费它的规划能力，把自己累成喝水鸟。源：[Taggart](https://taggart-tech.com/reckoning/)（社区）。✅
- ❌ **不给验证方式就放它跑**：它说"修好了"你就信。这会踩进官方点名的 trust-then-verify gap。源：[Anthropic: Best practices](https://www.anthropic.com/engineering/claude-code-best-practices)（官方）。✅
- ❌ **一条道走到黑**：同一会话纠正 5 次还在死磕。上下文被失败尝试污染，越改越偏。官方红线是两次不过就 `/clear`。✅
- ❌ **全盘接受 diff / 想按 2**：一口气改 8 个文件你不看就接。Taggart 警告：一旦停止审视，出事概率趋近 1。源：[Taggart](https://taggart-tech.com/reckoning/)（社区）。✅
- ❌ **在空目录或 home 目录启动**：没有项目上下文，等于让工程师在白纸上凭空写，必然跑偏。✅
- ❌ **拿"它写过一坨烂代码"就全盘否定**：这正是 Taggart 和 r/ClaudeAI `1m1ihia` 那批人差点放弃的点。失望期别退坑，把用法从"下命令"调成"给目标 + 上下文 + 验证"，通常就过去了。心智具体怎么转见 [#003](./003-prompt-to-agentic-mindset-shift.md)，本篇只给操作处方。✅

## 延伸

**交叉引用：**
- [#001 Claude Code、Codex、Cursor、Copilot 到底该用哪个？按你的活儿选，不按测评选](./001-claude-code-vs-chatgpt-cursor-copilot.md) —— 本篇是它的"操作层续集"。001 答"它是什么、我该不该用"，002 答"我在用但不顺，具体卡哪、怎么顺"。
- [#003 为什么 AI 写的代码我审不动、改完自己看不懂？](./003-prompt-to-agentic-mindset-shift.md) —— 本篇的认知层续集。002 答"操作卡在哪、怎么顺"，003 答"操作对了但心智没转，差在哪"。
- [#010 CLAUDE.md 怎么写才真的生效？](../02-context-engineering/010-claude-md-how-to-make-it-work.md) —— 卡点 1「给上下文」的持久化方式：怎么写一份它真的会读的项目指令。
- [#012 上下文窗口要爆了怎么办？](../02-context-engineering/012-context-window-exploding.md) —— 卡点 4「为什么两次纠正不过就要 `/clear`」的底层机制。
- [#030 TDD 在 AI coding 里怎么做？](../04-execution-workflow/030-tdd-in-ai-coding.md) —— 卡点 3「给验证方式」的标准落地姿势。
- [#031 plan → execute → review 的正确循环怎么做？](../04-execution-workflow/031-plan-execute-review-loop.md) —— 卡点 2「给目标别给步骤」的完整节奏。

**参考资料：**
- [Claude Code Best practices — Anthropic](https://www.anthropic.com/engineering/claude-code-best-practices) —— 正确心智的官方权威源，含 agentic coding environment、trust-then-verify gap、kitchen sink session、两次纠正 `/clear`、course-correct early and often 等关键论断（官方，访问日期 2026-06）✅
- [Claude Code Docs: Overview](https://code.claude.com/docs/en/overview) —— "agentic coding tool"定义与多 surface 架构（官方，访问日期 2026-06）✅
- [I used AI. It worked. I hated it. — Michael Taggart / Taggart Tech](https://taggart-tech.com/reckoning/) —— 一个对 AI 持保留态度的工程师用 Claude Code 做完项目的完整自白，含 "Homer's drinking bird""tempting to press 2""probability approaches 1""audience rather than author" 等关键引文（社区，2025）✅
- [Claude Code Tips I Wish I Knew as a Beginner — r/ClaudeAI 1m1ihia](https://www.reddit.com/r/ClaudeAI/comments/1m1ihia/claude_code_tips_i_wish_i_knew_as_a_beginner/) —— 新手 "almost gave up...all hype" 的典型自白与转折（社区，2025）⚠️ Reddit 反爬严重，webReader 无法抓全文，WebSearch 多次独立返回一致的逐字摘要。
- [5 Mistakes I Made Using Claude Code That Cost Me Real Money — Medium](https://medium.com/@jaumegallegocusco/5-mistakes-i-made-using-claude-code-that-cost-me-real-money-55b8a8ee09bb) —— "赔了真金白银，不是因为工具差、是因为用错了"的佐证（社区，2025）⚠️ webReader 抓取失败，仅 WebSearch 确认标题、作者、URL 真实及摘要级原文。

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
