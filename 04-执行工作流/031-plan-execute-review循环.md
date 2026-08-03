# 031. 让 AI 改一个小功能，它却动了一堆无关文件怎么办？（plan → execute → review 循环）

> 难度：中级
> 主题：执行工作流
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：流程题

> ⏰ 时效声明：**2026-08-03** 核实。plan mode 的进入方式（`Shift+Tab` 循环 / `/plan` 前缀 / `--permission-mode plan`）、`Ctrl+G` 编辑计划、批准计划的四个选项、`defaultMode: "plan"`、`opusplan` 别名与四种配置入口，均已对照官方 permission-modes 与 model-config 文档逐条核对。CHI 2025 论文（arXiv:2502.01390）真实存在，N=248 与"低质量计划损害信任"结论已在摘要确认；"66% 执行准确率"与"2×2 因子设计"出自论文全文，本轮仅核实到摘要级，引用时建议复核原文。Claude Code 版本行为随小版本变化快，本文所述以 v2.1.2xx 系列文档为准。

## TL;DR

你让 AI 加一个字段，它顺手重构了三个模块、改了七个你没提过的文件。或者更糟：它写得很漂亮，但解的不是你要的那道题。返工的成本远高于规划的成本。

根因不是模型笨，是你没在动手前把"改哪几个文件、每步怎么验证"钉死。agent 的默认行为就是收到需求立刻敲代码，没有边界它就自己划边界。

正确的核心循环是一个有闸门的三段式。第一段 PLAN，在只读模式下把"要改哪些文件、验收标准是什么"想透。第二段 EXECUTE，交给 agent 实现。第三段 REVIEW，用证据而不是口头断言来验收。不合格就退回 PLAN 重来。

一句话心法：你的时间应该花在 PLAN 和 REVIEW 上，EXECUTE 尽量交给 agent。agent 动手快但方向感差，你方向感强但动手慢，分工对了效率才最高。

三条结论：

1. 先探索，再规划，最后编码。Anthropic 官方把这条列为推荐工作流。原话是"Letting Claude jump straight to coding can produce code that solves the wrong problem"（让 Claude 直接上手写代码，可能写出解错了题的代码）。跳过规划最贵的错误，是优雅地解错了题。

2. 计划质量直接决定执行准确率。CHI 2025 一项 N=248 的实证研究显示：高质量计划配合必要的人工执行参与，能达到约 66% 的执行准确率。缺了这些条件，agent 会同时损害信任和绩效。

3. Review 不是"看一眼"，而是"对抗式验收"。官方建议让一个全新上下文的 subagent 只看代码改动（diff）和验收标准来挑刺。原因是这个 reviewer 看不到写代码时的推理过程，不会替刚写的代码辩护。核心原则是：写代码的人不评审自己刚写的代码。

---

## 为什么

### 1. 官方定调：把"探索"和"执行"强行分开

Anthropic 在 Claude Code 官方最佳实践里用了一个独立的小节标题："Explore first, then plan, then code"（先探索，再规划，然后编码）。

> "Letting Claude jump straight to coding can produce code that solves the wrong problem. Use plan mode to separate exploration from execution."
> —— [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)（官方，2026-08 核实）

官方推荐的工作流是四步：探索 → 规划 → 落地 → 提交（Explore → Plan → Implement → Commit）。plan mode（规划模式，agent 只能读不能改的一种模式）就是覆盖前两步的"只读闸门"。官方对它的定义是："Claude reads files, runs shell commands to explore, and writes a plan, but does not edit your source"（Claude 读文件、跑命令做探索、写出计划，但不改你的源码），并且"edits stay blocked until you approve the plan"（在你批准计划前，编辑一直是被挡住的）。来源：[Choose a permission mode](https://code.claude.com/docs/en/permission-modes)（官方，2026-08 核实）。

Flask 作者 Armin Ronacher 对 plan mode 注入的系统提示词做了逐行拆解。他发现 plan mode 内部本身就是一个四阶段状态机：先理解（Initial Understanding），再设计（Design），再评审对齐（Review），最后写出最终计划（Final Plan），全程只读。提示词里的关键约束是"you MUST NOT make any edits… or otherwise make any changes to the system"（你绝不能做任何编辑或改动）。本质上它就是一段注入的提示词加一个状态机。来源：[What Actually Is Claude Code's Plan Mode?](https://lucumr.pocoo.org/2025/12/17/what-is-plan-mode/)（社区权威，2025-12）。

为什么这条值得官方单独点名？因为 agent 的默认行为就是"不假思索动手"。你给它一句"实现登录"，它的第一反应是去敲代码，而不是反问你用什么鉴权方案、session 还是 token、错了重来的成本谁担。plan mode 的价值就是用只读约束强行打断这个默认行为，把"想"和"做"从同一个连续动作里拆开。

### 2. 实证证据：计划质量是执行准确率的主导因素

"先规划再执行"不是直觉经验，而是有数据支撑的。CHI 2025 发表了一项实证研究，N=248，采用 2×2 因子设计（自动 vs 人工参与 × 规划阶段 vs 执行阶段）。结论很硬。

研究把 LLM agent 称为"双刃剑"。当存在高质量计划、且执行阶段有必要的人工参与时，agent 能有效提升团队绩效。否则会同时损害信任和绩效。具体地，高质量计划能达到约 66% 的执行准确率，而低质量计划下 agent 的产出反而不如不参与。来源：[Plan-Then-Execute: An Empirical Study of User Trust and Team Performance (CHI 2025)](https://arxiv.org/abs/2502.01390)（学术研究，2025）。

这个结论精准解释了为什么"vibe coding"（凭感觉让 agent 自由发挥）在探索期爽、在生产期崩。没有高质量计划这个前置条件，agent 的自主性是有害的。规划不是走流程的形式主义，而是提升 agent 产出可靠性的杠杆。

社区实践和官方建议在这一点上高度一致。Addy Osmani 在 spec 写作指南里，把"先用 Plan Mode 只读探索、再退出执行"称为防止一种陷阱的手段：在 spec 还不扎实时就急着生成代码。他还引用了 GitHub Spec Kit 的门控工作流，规则是 spec 没验证就不准进实现。来源：[How to write a good spec for AI agents](https://addyosmani.com/blog/good-spec/)（社区权威，2026-01）。

> 个人观点（小C）：很多人把"规划"理解成写一大段需求文档甩给 agent，这是另一种极端。真正有效的规划是对话式、迭代式的。agent 反问你（官方叫"Let Claude interview you"），你回答，它把歧义收敛成方案，你再审。规划的本质是在动手前把假设暴露出来，而不是把文档写得更长。

### 3. Review 的工程价值：用"证据"和"对抗"闭合验证环

PLAN 解决"方向对不对"，EXECUTE 解决"代码写出来"。但中间缺一环：代码真的实现了 PLAN 吗？这就是 REVIEW 的位置。

官方对 review 的第一条要求是拿证据说话。

> "Have Claude show evidence rather than asserting success: the test output, the command it ran… Reviewing evidence is faster than re-running the verification yourself."
> —— [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)（官方，2026-08 核实）

官方的第二条要求是引入独立检查。

> "The longer Claude works unattended, the more an independent check matters… A reviewer running in a fresh subagent context sees only the diff and the criteria you give it, not the reasoning that produced the change."
> —— [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)（官方，2026-08 核实）

为什么必须"对抗式"？因为写代码的上下文天然会替自己刚写的代码辩护。让同一个 agent 在同一个上下文里"自查"，它会顺着刚才的思路找理由。全新上下文的 reviewer 只看 diff 和验收标准，看不到写代码时的理由，所以能在自己的评估标准上客观打分。这就是"写代码的和打分的不能是同一个上下文"的工程价值，和 [#030 TDD](./030-AI写的测试不可信.md) 里"测试先于实现存在"是同源逻辑。

但对抗也有代价，官方专门给了一条反向提醒：

> "A reviewer prompted to find gaps will usually report some, even when the work is sound… Chasing every finding leads to over-engineering."
> —— [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)（官方，2026-08 核实）

所以 reviewer 的 prompt 必须写死"只报影响正确性或明确需求的缺口，其余标为可选"，否则你会被一堆"建议加个抽象层"淹掉。

社区领袖 Simon Willison 用一个更强硬的说法总结了跳过 review 的后果："house of cards code"（纸牌屋代码）。意思是 AI 生成的代码看起来很稳，但在你没测的边界条件下一触即溃。来源：[Agentic Engineering Patterns](https://simonw.substack.com/p/agentic-engineering-patterns) 和 [Simon Willison's Weblog: code review](https://simonwillison.net/tags/code-review/)（社区权威，2025-2026）。"review 检查点有价值"这一论断，官方和 Willison 两个来源都支持。

> 别把这条和他另一个更出名的说法混起来。Willison 的 "lethal trifecta"（致命三件套）讲的是 prompt injection 安全，指的是一个 agent 同时具备三样能力时会出事：能读你的私有数据、会接触到不可信内容、还能对外发消息（[The lethal trifecta](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)，社区权威，2025-06）。那是安全议题，归 [#072](../08-团队与组织/072-AI-coding安全红线.md)，和本篇的 review 纪律不是一回事。

---

## 怎么做

### 第 0 步：先判断这次要不要走完整循环

不是每个任务都值得规划。官方给了一条可以机械执行的判据：

> "If you could describe the diff in one sentence, skip the plan."（如果你能用一句话描述这次的 diff，就跳过规划。）
> —— [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)（官方，2026-08 核实）

官方同时给了三个"必须规划"的信号："when you're uncertain about the approach, when the change modifies multiple files, or when you're unfamiliar with the code being modified"（方案不确定 / 改动跨多个文件 / 你对被改的代码不熟）。

还有一个例外要单独记：探索性任务可以故意不规划。官方原话是"Sometimes a vague prompt is exactly right because you want to see how Claude interprets the problem before constraining it"（有时模糊的 prompt 恰恰是对的，因为你想在约束它之前先看它怎么理解问题）。但这是"我在探索"的特权。一旦进入"我要这个功能上线"的确定态，规划就不再是可选项。

| 情形 | 走不走循环 |
|------|-----------|
| 改错别字、加一行日志、改个变量名 | 跳过，直接让它做 |
| 一句话能描述完 diff | 跳过 |
| 改动跨 2 个以上文件 | 走完整循环 |
| 你不熟这块代码 / 方案有多个选项 | 走完整循环 |
| 你在试水、想看 agent 怎么理解问题 | 故意不规划，但别把产出直接上线 |

### 循环全貌

四个阶段，两道闸门。闸门不过就不准进下一段。

| 阶段 | 谁在做 | 产出 | 闸门 |
|------|--------|------|------|
| ① UNDERSTAND 明确需求 | 你 + agent 对话 | 自包含的 SPEC.md（点名文件与接口、写明 out of scope、以端到端验证收尾） | —— |
| ② PLAN 规划 | agent，只读模式 | PLAN.md（文件清单 / 改动性质 / 分步顺序 / 每步验证命令） | **闸门 A**：清单式过审，见下 |
| ③ EXECUTE 实现 | agent 写代码 | 代码 + 每步的测试/build 输出 | **闸门 B**：证据而非断言 |
| ④ REVIEW 对抗式验收 | 全新上下文的 subagent | gap 列表 | gap 全修复 + 重测通过 |

不通过时的回退规则：方向错了回 ②，只是实现没到位回 ③。

### Phase ① UNDERSTAND：明确需求（最容易被跳过，最贵的一步）

在让 agent 动任何代码前，先把"做什么"收敛清楚。有两种姿势。

第一种是你主导：写一段清晰的需求说明，包含目标、约束、验收标准，交给 agent。

第二种是 agent 主导，用官方推荐的"Let Claude interview you"（让 Claude 访谈你）。让 agent 主动反问你技术细节、边界、权衡，直到歧义收敛。这对"你自己也没完全想清楚"的需求特别有效。官方原文模板如下（把 `[简要描述]` 换成你的功能）：

```text
我想做 [简要描述]。用 AskUserQuestion 工具详细地访谈我。

问技术实现、UI/UX、边界情况、顾虑和权衡。别问显而易见的问题，
挖那些我可能没考虑到的难点。

一直问到把所有点覆盖完，然后写一份完整的 spec 到 SPEC.md。
```

来源：[Best practices: Let Claude interview you](https://code.claude.com/docs/en/best-practices)（官方，2026-08 核实）。

**闸门**：产出一份自包含的需求。它要命名涉及的文件和接口，声明哪些不在范围内（out of scope），并以一个能证明功能可用的端到端验证步骤收尾。官方原话："Time spent making the spec precise pays off more than time spent watching the implementation"（把 spec 打磨精确所花的时间，比盯着实现过程更值）。

spec 写完后开一个新 session 执行，新 session 上下文干净、只专注实现。

### Phase ② PLAN：规划（只读，不准动手）

**怎么进 plan mode**（三选一，官方 permission-modes 文档，2026-08 核实）：

```bash
# 方式 1：会话中按 Shift+Tab 循环 default → acceptEdits → plan
#         状态栏出现 "⏸ plan mode on" 才算进去了

# 方式 2：只让某一条 prompt 走规划，前缀 /plan
#         例：/plan 给订单列表加分页

# 方式 3：启动时直接进
claude --permission-mode plan

# 方式 4：把某个项目默认设成规划模式（写 .claude/settings.json）
```

```json
{
  "permissions": {
    "defaultMode": "plan"
  }
}
```

**PLAN 阶段可复制 prompt 模板**（这是本阶段的核心资产，别只喊一句"做个计划"）：

```text
现在是 plan mode，你不准改任何文件。读 @SPEC.md 和相关代码，产出 PLAN.md，
严格按下面四段结构写，缺一段视为不合格：

## 1. 涉及文件清单
逐行列出，每行格式：`具体/文件/路径.ts` —— 一句话说明为什么要动它
只写你实际读过的文件；没读过就先读。不准写"相关模块""若干配置"这类模糊指代。

## 2. 每个文件的改动性质
逐行格式：`路径` | 新增 / 修改 / 删除 | 改动的函数或符号名 | 预计行数量级
如果某个文件在 SPEC.md 里没被提到，单独标注 [范围外] 并说明为什么必须动它。

## 3. 分步实现顺序
编号步骤，每步控制在 2-5 分钟能做完的粒度。
每步写清：做什么、依赖哪一步、失败了怎么回退。

## 4. 每步的验证命令
第 3 段的每一个编号步骤，都要有一行对应的：
- 验证：<可以直接粘到终端跑的命令>  → 预期：<看到什么算通过>
没有验证命令的步骤不准存在。如果某步确实无法自动验证，写明人工验证的具体操作。

最后单独列一节"我不确定的地方"，把需要我拍板的选项列出来，不要自己替我决定。
```

写完计划后，按 `Ctrl+G` 可以把计划在你的默认文本编辑器里打开直接改，改完再让它继续。批准计划时官方给的选项包括：用 auto 模式执行、逐条手动批准编辑、送到 Ultraplan 在浏览器里细化、或者继续留在规划模式接着改。来源：[Choose a permission mode: Review and approve a plan](https://code.claude.com/docs/en/permission-modes)（官方，2026-08 核实）。

superpowers 插件的 `brainstorming` 技能把这一步强制化：探索上下文、提问、提 2 到 3 个带取舍（trade-off）的方案、呈现设计、等用户审批，全程不准跳过去写代码。它甚至专门列了一条反模式："This Is Too Simple To Need A Design"（这太简单了不用设计）——越是"简单"的项目，越是那些没被审视的假设造成最多返工的地方。来源：[brainstorming SKILL.md](https://github.com/obra/superpowers/blob/main/skills/brainstorming/SKILL.md)（社区/开源，2025-2026）。

#### 闸门 A：可勾选的过审清单（不是"感觉对不对"）

计划落到 `PLAN.md` 之后，逐条勾。任何一条不过，退回重写，不准进 EXECUTE。

- [ ] 第 1 段里每一行都是具体文件路径，没有"相关模块""若干配置"这类词。
- [ ] 第 2 段里所有标了 `[范围外]` 的文件，你都逐个确认过确实必须动。有一个说不清楚就打回。
- [ ] SPEC.md 里的每一条验收标准，都能在第 3 段找到至少一个对应的步骤编号。
- [ ] 第 3 段的步骤数 == 第 4 段的"验证："行数。不相等说明有步骤没验证。
- [ ] 没有任何一步的描述里出现"顺便""同时优化""重构一下"。
- [ ] "我不确定的地方"那一节你已经逐条回答，没有留给 agent 自己拍板。

前四条可以直接用命令查：

```bash
# 步骤数 vs 验证命令数，两个数字必须相等
grep -cE '^[0-9]+\.' PLAN.md
grep -c '^- 验证：' PLAN.md

# 计划点名了哪些文件（后面闸门 B 要拿它跟真实 diff 比对）
grep -oE '`[^`]+\.(ts|tsx|js|py|go|java|rs|rb)`' PLAN.md | tr -d '`' | sort -u > /tmp/plan-files.txt
cat /tmp/plan-files.txt

# 检查有没有模糊指代
grep -nE '相关模块|若干|等文件|顺便|同时优化' PLAN.md && echo "❌ 存在模糊表述，打回" || echo "✅ 无模糊表述"
```

预期输出：前两条命令打印同一个数字；最后一条打印 `✅ 无模糊表述`。

### Phase ③ EXECUTE：实现（小步、留证据）

方案过了闸门 A，退出 plan mode 让 agent 实现。核心纪律是小步迭代，每步留证据。让 agent 做三件事：

1. 严格按 PLAN.md 的步骤编号一步步实现，每步做完报编号。
2. 每步做完跑该步对应的"验证："命令，把原始输出贴出来。要的不是"我改好了"，而是"这是测试通过的输出"。
3. 失败时修代码不修测试，见 [#030 TDD](./030-AI写的测试不可信.md) 的红绿循环。

官方对"频繁纠偏"持积极态度："The best results come from tight feedback loops… correcting it quickly generally produces better solutions faster"（最好的结果来自紧密的反馈循环，快速纠正通常更快得到更好的方案）。更关键的一条：如果在同一个 session 里纠正超过两次同一个问题，说明上下文已经被失败方案污染了，直接 `/clear` 清空、用更好的初始 prompt 重来。来源：[Best practices: Course-correct early and often](https://code.claude.com/docs/en/best-practices)（官方，2026-08 核实）。

#### 闸门 B：证据验收（含范围检查）

```bash
# 1. 实际改了哪些文件
git diff --name-only <基线分支>... | sort > /tmp/actual-files.txt

# 2. 和计划点名的文件对比：左边是"计划里有但没改"，右边是"改了但计划里没有"
diff /tmp/plan-files.txt /tmp/actual-files.txt
```

预期输出：`diff` 无输出（两边一致）。出现 `>` 开头的行就是范围蔓延——这正是"让它改一个功能，它动了一堆无关文件"的检出点。逐个追问 agent 为什么动它，说不清就 `git checkout` 还原那个文件。

同时要求 agent 贴出全量测试的原始输出，而不是"测试都过了"这句话。

### Phase ④ REVIEW：对抗式验收（全新上下文）

agent 说"完成了"，别信，要验收。按从轻到重分三档。

| 档位 | 做法 | 适用 |
|------|------|------|
| 自验证 | agent 自己跑测试/截图，贴原始输出 | 任何任务，今天就能用 |
| `/goal` 会话级 | 把验收标准设成会话终止条件，每轮由独立评估器复查 | 中等任务，不想全程盯 |
| **对抗式 review** | 全新上下文的 subagent 只看 diff + 验收标准挑刺，写代码的和打分的不是同一个 | 正确性要求高 / 长任务 |

对抗式 review 的可复制 prompt（在官方模板基础上补了范围与噪音控制）：

```text
用一个 subagent 评审当前 diff，对照 PLAN.md：
1. PLAN.md 第 1 段列的每个文件，改动是否都做了？
2. PLAN.md 里列出的边界情况，是否每个都有对应测试？
3. 有没有改动 PLAN.md 文件清单之外的文件？逐个列出来。
4. 只报影响正确性或明确需求的缺口。风格偏好、"可以加个抽象层"这类一律标为"可选"，
   不要为了凑数量而报。
输出格式：每条 gap 给出 文件:行号 + 违反了 PLAN.md 的哪一条。
```

官方原版对照：

> "Use a subagent to review the rate limiter diff against PLAN.md. Check that every requirement is implemented, the listed edge cases have tests, and nothing outside the task's scope changed. Report gaps, not style preferences."
> —— [Best practices: Add an adversarial review step](https://code.claude.com/docs/en/best-practices)（官方，2026-08 核实）

如果只是想查 bug 而不是对照计划，直接用 Claude Code 自带的 `/code-review` 技能，它在一个全新 subagent 里评审当前 diff 并把发现带回主会话。

**通过判据**：reviewer 报的"影响正确性"级别 gap 全部修复，且全量测试重跑通过。标为"可选"的条目你自己决定要不要做——官方明确警告，追着每一条 finding 改会导致过度设计。

---

## Claude Code 实战

### 用 `opusplan` 让"想"和"做"分开花算力

`opusplan` 是官方的模型别名，行为是：plan mode 里用 Opus 做复杂推理和架构决策，退出 plan mode 后自动切 Sonnet 做代码生成。等于把贵的 token 花在"想"上，便宜快的花在"敲"上。

四种配置入口（官方按优先级从高到低列出，2026-08 核实）：

```bash
# 1. 会话中切换（会写入用户设置成为新会话默认）
/model opusplan

# 2. 启动时指定（只影响这一个会话）
claude --model opusplan

# 3. 环境变量（只影响这一个会话）
export ANTHROPIC_MODEL=opusplan

# 4. 写进设置文件，永久生效
```

```json
{
  "model": "opusplan"
}
```

补充两个细节：`opusplan` 的 Opus 规划阶段与 `opus` 用同样的上下文窗口；如果你不在自动升级 1M 上下文的订阅档位、又想让规划和执行两阶段都用 1M，把模型设成 `opusplan[1m]`。另外 `ANTHROPIC_DEFAULT_OPUS_MODEL` 决定 plan mode 用哪个具体 Opus 版本，`ANTHROPIC_DEFAULT_SONNET_MODEL` 决定非 plan mode 用哪个 Sonnet 版本。来源：[Model configuration](https://code.claude.com/docs/en/model-config)（官方，2026-08 核实）。

**怎么确认生效**：设好之后进 plan mode（`Shift+Tab` 到 `⏸ plan mode on`），运行 `/status` 查看当前模型，规划期间应显示 Opus 系；批准计划退出 plan mode 后再看一次，应变成 Sonnet 系。若两次显示一致，说明 `opusplan` 没生效——最常见原因是项目或托管设置里的 `model` 字段优先级更高覆盖了你的选择，启动时的头部提示会写明是哪个设置文件设的。

### plan mode 的几个容易记错的点

- **进入**：`Shift+Tab` 循环 `default → acceptEdits → plan`（所以从默认态是按两次），或单条 prompt 前缀 `/plan`，或启动时 `claude --permission-mode plan`。状态栏显示 `⏸ plan mode on` 才算进去。
- **退出而不批准**：再按一次 `Shift+Tab`。
- **批准即离开**：批准计划会退出 plan mode 并切到你选的权限模式，Claude 随即开始改文件。想再规划一次，`Shift+Tab` 循环回去或再用 `/plan` 前缀。
- **编辑计划**：`Ctrl+G` 在默认文本编辑器里打开计划直接改。这一条很多人不知道，比来回让 agent 改计划快得多。
- **plan mode 不等于完全只读**：它挡的是编辑。命令执行在开了 auto mode 且 `useAutoModeDuringPlan` 打开时由分类器判断放行；在开启了 bypass permissions 的会话里，plan mode 的拦截根本不生效（Claude 仍被指示不要改，但真改了也不会被挡）。别拿 plan mode 当安全沙箱用。
- 来源：[Choose a permission mode](https://code.claude.com/docs/en/permission-modes)（官方，2026-08 核实）；提示词层面的拆解见 [lucumr.pocoo.org](https://lucumr.pocoo.org/2025/12/17/what-is-plan-mode/)（社区权威，2025-12）。

### superpowers 三段链路：brainstorming → writing-plans → executing-plans

如果你要一套比原生 plan mode 更强制的流程，可以装 `obra/superpowers` 插件。它明确不进 plan mode，而是用三段技能链替代。来源：[obra/superpowers](https://github.com/obra/Superpowers) 和 [Superpowers v4.3.0 发布说明](https://blog.fsck.com/agent-blog/2026/02/12/superpowers-v4-3-0/)（社区/开源，2026-02）。

1. **`brainstorming`**：在任何创意工作前强制激活。一次问一个问题收敛需求、提 2 到 3 个带取舍的方案、等审批后才把 spec 写到文件、再做一次 spec 自审（扫占位符、矛盾、歧义、范围）。终态只能是"调用 writing-plans"。
2. **`writing-plans`**：把 spec 转成详细实现计划，假设执行者对代码库零上下文，把工作拆成 2 到 5 分钟的小任务。来源：[writing-plans SKILL.md](https://github.com/obra/superpowers/blob/main/skills/writing-plans/SKILL.md)（社区/开源）。
3. **`executing-plans`**：逐步执行计划，在每个检查点暂停验收、处理阻塞项。来源：[executing-plans skill](https://www.claudepluginhub.com/skills/obra-superpowers-2/executing-plans)（社区）。

它把 PLAN、EXECUTE、REVIEW 做成了不可绕过的技能链，而不是靠你记得喊一句"先规划"。

### GitHub Spec Kit：把循环做成门控 CLI

GitHub 的开源 Spec Kit 把这条循环固化成四阶段门控工作流：Specify → Plan → Tasks → Implement，分别产出 `spec.md`、`plan.md`、`tasks.md`，规则是 spec 没验证就不准进实现。它把"人评审"做成流程里的显式检查点，而不是"记得看一眼"。来源：[github/spec-kit](https://github.com/github/spec-kit) 和 [Addy Osmani: How to write a good spec](https://addyosmani.com/blog/good-spec/)（官方/社区，2025-2026）。

---

## 横向对比

| 维度 | Claude Code | Cursor | GitHub Copilot |
|------|------------|--------|----------------|
| **规划闸门** | 原生 plan mode（只读强制）+ superpowers 三段链 | 无原生只读 plan mode；靠 rules / `.cursor/rules` 和 chat 引导 | 无原生 plan mode；靠 instructions 文件 |
| **review 机制** | 原生 adversarial subagent / Writer-Reviewer 双 session / `/code-review` skill | Composer 多文件，但无独立 fresh-context grader | 无内置对抗式 review |
| **会话级验收** | `/goal` + `Stop` hook（确定性闸门）| 无 | 无 |
| **规划与执行分算力** | `opusplan` 别名自动切换 | 手动换模型 | 手动换模型 |
| **spec→plan→tasks 工具链** | 社区 superpowers（强制化）+ GitHub Spec Kit（gated） | 用户自建 rules | Copilot agents.md personas |

**共性观察**：所有工具的 agent 都有"不假思索动手"的天然倾向，CHI 2025 研究适用于全部 LLM agent。差异在于"强制力"。Claude Code 用 plan mode（只读约束）、subagent（对抗 review）、hook（确定性闸门）把这条循环闭合得最硬。Cursor 和 Copilot 更多依赖人工纪律。来源：[Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)（官方）、[Addy Osmani](https://addyosmani.com/blog/good-spec/)（社区）。

---

## 反模式

- ❌ **不规划直接让 agent 动手**。最贵的错误不是代码 bug，是优雅地解错了题。判断线很简单：一句话描述不完这次 diff，就必须规划。（官方 + CHI 2025 研究）
- ❌ **把"做个计划"当成完整 prompt**。不指定输出结构，agent 会给你一段散文式的方案，里面全是"相关模块""做必要的改动"，闸门 A 无从下手。计划必须落成"文件清单 / 改动性质 / 分步顺序 / 每步验证命令"四段。（本文实践）
- ❌ **闸门只靠"感觉方向对不对"**。闸门要能机械执行才有用。用 `git diff --name-only` 跟计划的文件清单做 diff，这一条就能挡住大部分"它改了一堆无关文件"。（本文实践）
- ❌ **让写代码的上下文自己 review 自己**。agent 自查会顺着刚才的思路找理由，要用全新上下文的 subagent。（官方）
- ❌ **追着 reviewer 报的每一条 finding 改**。官方明确警告：被要求找缺口的 reviewer 一定会找出一些，即使代码没问题；照单全收会导致多余的抽象层、防御式代码和永远触发不了的测试用例。只修影响正确性和明确需求的。（官方）
- ❌ **在同一个 session 里反复纠正同一个问题**。上下文会被失败方案污染。纠正两次还不对就 `/clear` 重来。（官方）
- ❌ **把 plan mode 当安全沙箱**。它挡的是文件编辑；在 bypass permissions 会话里连编辑都不挡，命令执行也可能被分类器放行。需要真隔离用 `/sandbox` 或容器。（官方 permission-modes）
- ❌ **写完 spec 就忘**。spec 是活文档，执行中发现的变更要回写，否则 spec、plan、实现三者会漂移。（单一来源：Spec Kit discussion #775 的社区讨论，未见官方结论）

---

## 延伸

**交叉引用：**
- [#030 TDD 在 AI coding 里怎么做？](./030-AI写的测试不可信.md) —— TDD 的 RED 阶段就是把验收标准前置，和 plan-first 循环同源。REVIEW 阶段的"证据非断言"和 TDD 的"watch it fail"一脉相承。
- [#033 Skill / superpowers 怎么用、怎么写？](./033-Skill与superpowers怎么用.md) —— brainstorming/writing-plans/executing-plans 三段链把循环强制化。
- [#032 开几个 agent 并行跑，结果互相踩、被限流、token 指数级炸开——并行到底该开几个？](./032-SubAgent并行开几个.md) —— 对抗式 review 的 subagent 用法。
- [#012 上下文窗口要爆了怎么办？](../02-上下文工程/012-上下文窗口要爆了.md) —— 长循环用 subagent，既隔离上下文又做对抗 review。

**参考资料：**
- [Best practices for Claude Code — Claude Code Docs](https://code.claude.com/docs/en/best-practices) —— 官方头号参考："Explore first, then plan, then code""If you could describe the diff in one sentence, skip the plan""Let Claude interview you""adversarial review step"及其过度设计警告、"纠正两次就 /clear"（官方，2026-08 核实）
- [Choose a permission mode — Claude Code Docs](https://code.claude.com/docs/en/permission-modes) —— plan mode 的进入方式（`Shift+Tab` / `/plan` / `--permission-mode plan`）、`Ctrl+G` 编辑计划、批准计划的选项、`defaultMode: "plan"`、plan mode 在 bypass permissions 下不拦截（官方，2026-08 核实）
- [Model configuration — Claude Code Docs](https://code.claude.com/docs/en/model-config) —— `opusplan` 别名定义、四种配置入口、`opusplan[1m]`、`ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL`（官方，2026-08 核实）
- [Plan-Then-Execute: An Empirical Study of User Trust and Team Performance (CHI 2025)](https://arxiv.org/abs/2502.01390) —— N=248 实证：高质量计划达约 66% 执行准确率，无高质量计划时 agent 损害信任和绩效（学术研究，2025）
- [What Actually Is Claude Code's Plan Mode? — Armin Ronacher](https://lucumr.pocoo.org/2025/12/17/what-is-plan-mode/) —— 对 plan mode 注入 prompt 的逐行拆解："MUST NOT make any edits"、四阶段状态机（社区权威，2025-12）
- [brainstorming SKILL.md — obra/superpowers](https://github.com/obra/superpowers/blob/main/skills/brainstorming/SKILL.md) —— 强制设计先行流程、"Too Simple To Need A Design"反模式、终态只能调用 writing-plans（社区/开源，2025-2026）
- [obra/superpowers](https://github.com/obra/Superpowers) —— brainstorming→writing-plans→executing-plans 三段链，替代原生 plan mode（社区/开源，2026）
- [writing-plans SKILL.md — obra/superpowers](https://github.com/obra/superpowers/blob/main/skills/writing-plans/SKILL.md) —— 把 spec 转成零上下文级别的详细实现计划，任务拆到 2-5 分钟（社区/开源，2025-2026）
- [executing-plans skill — Claude Plugin Hub](https://www.claudepluginhub.com/skills/obra-superpowers-2/executing-plans) —— step-by-step 执行 + review checkpoints（社区，2025-2026）
- [Superpowers v4.3.0 — blog.fsck.com](https://blog.fsck.com/agent-blog/2026/02/12/superpowers-v4-3-0/) —— superpowers 明确"never enter plan mode"，用三段链替代（社区，2026-02）
- [How to write a good spec for AI agents — Addy Osmani](https://addyosmani.com/blog/good-spec/) —— spec 六要素、Plan Mode 只读探索、curse of instructions、引用 GitHub Spec Kit gated workflow（社区权威，2026-01）
- [Agentic Engineering Patterns — Simon Willison](https://simonw.substack.com/p/agentic-engineering-patterns) —— house of cards code、永不跳过 review 的纪律（社区权威，2025-2026）
- [Simon Willison's Weblog: code review](https://simonwillison.net/tags/code-review/) —— code review 相关文章合集（社区权威，2025-2026）
- [The lethal trifecta for AI agents — Simon Willison](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/) —— 私有数据 + 不可信内容 + 对外通信＝prompt injection 高危组合。本篇只用来做术语澄清，安全议题归 [#072](../08-团队与组织/072-AI-coding安全红线.md)（社区权威，2025-06）
- [github/spec-kit](https://github.com/github/spec-kit) —— Specify→Plan→Tasks→Implement 四阶段 gated CLI 工作流（官方/开源，2025-2026）
- [Spec Kit Discussion #775](https://github.com/github/spec-kit/discussions/775) —— spec/plan/tasks 三者漂移的社区讨论（社区，2025）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验——你跳过规划直接动手被坑 / 认真规划后一次过的对比案例，或 superpowers 三段链启用后返工率的变化]`
