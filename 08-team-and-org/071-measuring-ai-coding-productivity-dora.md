# 071. AI coding 的效能到底怎么度量？DORA / SPACE / 代码量 / AI 生码率，哪个不是 vanity metric？

> 难度：高级
> 主题：团队与组织
> 工具：Claude Code · 横向(DORA / SPACE / DX Core 4)
> 题型：决策题 + 配置题

> ⏰ 时效声明：本文事实性内容于 **2026-08-03** 复核。文中引用的是 2025 DORA 报告《State of AI-assisted Software Development》。DORA 已于 2026-04 发布后续报告《ROI of AI-assisted Software Development》（[dora.dev/ai/roi/report](https://dora.dev/ai/roi/report/)）。后续报告延续「AI 是放大器」的结论，并提出一个新概念 "instability tax"：交付的不稳定性会随 AI 采用而上升。这与本文「吞吐量上升、但稳定性负相关」的主张一致，没有推翻本文任何结论。本次复核逐条比对了 Claude Code 官方 monitoring 文档的环境变量名、指标名与属性名（2026-08-03 访问），实战一节的配置按该文档写成。

> 本篇主要面向团队负责人 / Tech Lead。被度量的开发者看「怎么做」的第零步。

## TL;DR

先给结论，再讲怎么搭。

**结论一：代码量、AI 生码率、token 消耗量，这三个都是 vanity metric（虚荣指标）——指当效能指标时。**它们衡量的是「AI 吐了多少字」，不是「团队交付了多少价值」。一旦拿来当 KPI，就会被人刷高。要说清楚的是：token 和美元消耗当**成本**指标是完全该管的（归 [#060](../07-efficiency-and-cost/060-how-much-does-claude-code-cost-per-day.md)），只是别把它当成「谁干得多」的尺子。讽刺的是，Claude Code 官方 telemetry 直接内置了 `claude_code.lines_of_code.count` 这个指标。但工具能测出来，不代表你该拿它做绩效考核。

**结论二：DORA 四指标没有失效，但在 AI 时代必须搭配稳定性指标一起看。**2025 DORA 报告的核心结论是：AI 是「放大器」，让强队更强、让烂流程更烂。AI 与吞吐量正相关，却与交付稳定性负相关。只盯吞吐量会掉进陷阱。

**结论三：别用单一指标，用一组相互制衡的指标。**业界当前的共识（来自 Nicole Forsgren 和 DX Core 4 框架）是：速度指标必须被质量指标和体验指标反向牵制。任何单看一个指标的做法，都会被人做数据。

**如果你不是定 KPI 的人，直接跳到「怎么做」的第零步**，那一节是给「被度量方」的：怎么申诉、怎么保护自己、怎么用可查证的原文说话。

一句话切边界：**本篇只回答团队和组织级别的效能怎么度量、哪些是虚荣指标。**单次产出怎么验证对错，见 [#040](../05-quality-assurance/040-who-verifies-ai-code-and-how.md)；token 账单怎么管，见 [#060](../07-efficiency-and-cost/060-how-much-does-claude-code-cost-per-day.md)；团队规范怎么立，见 [#075](./075-team-ai-coding-standards.md)。

---

## 为什么

### 1. 为什么「代码量 / AI 生码率 / token 量」是虚荣指标

先给虚荣指标的定义：数字好看、和真实价值弱相关、能被轻易做高。这三个指标全中。

先说代码量（lines of code，简称 LoC，即代码行数）。软件工程界几十年前就否定了用它衡量生产力。Nicole Forsgren 是 DORA 和 SPACE 两个框架的作者，她反复强调：任何单一的「产出」指标一旦被拿来考核，开发者就会去优化它。

> "measuring any single one 'output' can be misused: and when devs know it is being measured, they will optimize for it"
> （衡量任何单一「产出」指标都可能被滥用；开发者一旦知道某个指标在被考核，就会专门去优化它。）
> —— [Pragmatic Engineer: Developer productivity with Dr. Nicole Forsgren](https://newsletter.pragmaticengineer.com/p/developer-productivity-with-dr-nicole)

LoC 尤其糟糕。AI 时代产出代码的边际成本趋近于零。多写不等于多交付，反而可能是在堆技术债。

再说 AI 生码率，也就是 AI 写的代码占比。它衡量的是「AI 写了多少」。但一段跑不通、要返工三次的 AI 代码，生码率很高、价值却是负的。它测的是投入，不是产出。

最后说 token 量，它比前两个更等而下之。中文社区把这点说得很直接：有人提议按 token 或美元消耗给 AI 定 KPI，评论区一句话点破，「用 Token 量来定 KPI 比用代码量来定更蠢」（[V2EX 1217703 @YanSeven](https://www.v2ex.com/t/1217703)）。同一个帖子里，@sagnitude 举了个刷指标的例子：让 AI 补单元测试，结果它「给单元测试直接糊了个 return」。这印证了 Goodhart 定律：一个指标一旦成为目标，就不再是好指标。

这里有个关键陷阱：这三个指标，Claude Code 官方 telemetry 恰好都能导出（详见「实战」一节）。工具能测，不等于你该拿来考核。官方文档里 `claude_code.lines_of_code.count` 的说明只是「Count of lines of code modified」（增删的代码行数），按 `type`（added / removed）和 `model` 拆分（[CC Docs: Monitoring](https://code.claude.com/docs/en/monitoring-usage)）。它适合看 AI 用量趋势和成本归因，不适合当「谁干得多」的绩效尺子。这条边界是本篇最想让你记住的。

### 2. DORA 没失效，但 AI 让它必须「配对着看」

DORA 四指标是：部署频率、变更前置时间、变更失败率、恢复时间。它们依然成立。但 2025 年的 DORA 报告给了 AI 时代一个决定性的修正视角。这份报告由 Google 的 DORA 团队发布，调研了近 5000 名从业者。

> "AI's primary role is as an amplifier, magnifying an organization's existing strengths and weaknesses."
> （AI 的主要作用是放大器，会放大一个组织现有的优势和劣势。）
> —— [DORA Report 2025: State of AI-Assisted Software Development](https://dora.dev/dora-report-2025/)

报告里两个数据：约 90% 的开发者在用 AI（Faros 的解读记为 95%），80% 以上的人自报效率提升。但接下来是关键。

吞吐量与 AI 正相关。这是个反转：2024 年报告里两者还是负相关，2025 年反了过来。

交付稳定性与 AI 仍然负相关。AI 加速了开发，但这种加速会把下游环节的薄弱之处暴露出来，比如测试、部署、审查（[Faros AI: DORA 2025 Key Takeaways](https://www.faros.ai/blog/key-takeaways-from-the-dora-report-2025)）。

这意味着只看「部署频率 / 吞吐量」这一半，会严重误导你。AI 让你合并代码更快，但如果没有强测试、强版本控制、快反馈环，变更量一涨，下游就会爆雷。

DORA 团队还给了一个更狠的提醒：把资源投错地方也是一种失败模式。如果一个团队真正的瓶颈是部署管线脆弱，却砸钱去买 AI 编码工具，那就是被坏数据误导了（[Faros AI](https://www.faros.ai/blog/key-takeaways-from-the-dora-report-2025)）。个体产出的提升，可以和组织交付的恶化同时存在。Faros 把这种现象叫做 "localized pockets of productivity lost to downstream chaos"（局部的生产力被下游混乱吞掉，此说法仅见于 Faros 单一来源）。

AI 还带来一个特有的隐藏成本，叫 "verification tax"（验证税）：AI 省下的写代码时间，被重新花在审查和验证上（[DORA 2025 / InfoQ 解读](https://www.infoq.com/news/2026/03/ai-dora-report/)）。所以「代码写得快」根本没进入交付方程的分子。验证具体怎么做是 [#040](../05-quality-assurance/040-who-verifies-ai-code-and-how.md) 的话题，但在度量上你必须承认这笔税存在，否则吞吐数字全是幻觉。

### 3. 有硬证据：AI 在「看不见的地方」拉低了代码质量

如果你只测吞吐量、不测质量，会漏掉一个已被大规模实证的负向趋势。GitClear 分析了 2.11 亿行代码变更（2020 到 2024 年），发现在 AI 普及的这几年里出现了几个退化信号。

第一，代码克隆（重复的代码块）增长约 4 倍。

第二，重构占变更行的比例，从 2021 年的 25% 跌到 2024 年的不足 10%。同期，复制粘贴的克隆代码从 8.3% 升到 12.3%。2024 年是这个数据集里，复制粘贴代码首次超过 moved code（移动代码，重构的信号）的一年。

第三，短期 churn 代码（两周内就被返工的代码）持续上升，这是 AI 普及期的又一个退化信号。

来源：[GitClear: AI Copilot Code Quality 2025](https://www.gitclear.com/ai_assistant_code_quality_2025_research)。含义很直接：AI 让人倾向于「加了就忘」，少重构、多复制、多返工。而这些恰恰是任何「代码量 / 生码率」指标都看不到的，只有「变更失败率 + churn + 重复率」这类质量指标才抓得到。

---

## 怎么做

### 第零步：你不定 KPI，但你被 KPI 度量——先做这三件事

本库读者绝大多数是被度量方。后面四步是给设计度量的人看的，这一步是给你的。

**动作一：先确认你到底被什么指标考核，别对着想象反对。**去问一句「这个数字的口径是什么、从哪个系统取数、看的是团队还是个人」。三个问题里只要有一个答不上来，这个指标就还没成型，此时提异议成本最低。如果答案是「个人的代码行数 / AI 生码率 / token 消耗」，进入动作二。

**动作二：用可查证的原文申诉，别用「我觉得」。**下面三段是可直接复制进邮件或文档的引用，全部有公开出处，对方能自己去核。

```text
1）指标设计方自己禁止个人层面使用
DX Core 4 框架由 DORA、SPACE、DevEx 三套框架的原作者联合推出，其主指标
"diffs per engineer" 的官方说明明确要求：不要把它设为个人目标，也不要与
奖惩挂钩。
出处：https://getdx.com/research/measuring-developer-productivity-with-the-dx-core-4/

2）单一产出指标必然被优化掉
DORA 与 SPACE 两个框架的作者 Nicole Forsgren 原话：
"measuring any single one 'output' can be misused: and when devs know it is
being measured, they will optimize for it"
（衡量任何单一「产出」指标都可能被滥用；开发者一旦知道某个指标在被考核，
就会专门去优化它。）
出处：https://newsletter.pragmaticengineer.com/p/developer-productivity-with-dr-nicole

3）只看吞吐会掉进 AI 特有的陷阱
2025 DORA 报告（Google DORA 团队，近 5000 名从业者）结论："AI's primary role
is as an amplifier"，且 AI 与吞吐量正相关、与交付稳定性负相关。只考核产出量
而不同时看变更失败率，等于奖励制造下游故障。
出处：https://dora.dev/dora-report-2025/

4）工具厂商自己也没把这个指标定位成生产力度量
Claude Code 官方遥测文档里，claude_code.lines_of_code.count 的说明只有一句
"Count of lines of code modified"，按 added/removed 与 model 拆分，全文没有
把它称为生产力或绩效指标。
出处：https://code.claude.com/docs/en/monitoring-usage
```

申诉时提一个替代方案，比只反对有效得多：「这个数字我们放团队看板、不进个人绩效；个人这边改看『我负责的变更有没有引发线上问题』。」

**动作三：给自己留证据，防止被数字倒打一耙。**每两周花十分钟记一条：这两周我用 AI 省下的时间花到哪去了（返工？验证？review 别人？）。这正是 2025 DORA 报告说的 "verification tax"（验证税，AI 省下的写代码时间被重新花在审查和验证上）。绩效面谈时，这份记录是你唯一能对抗「你 diff 量怎么这么低」的东西。

**顺带一条口径提醒：AI 写的测试代码必须人审，不能只让 AI 审。**本库 [#075](./075-team-ai-coding-standards.md) 把「测试夹具（测试用的假数据、mock 对象）」列为可以 AI 审即可，但**测试逻辑本身不在此列**——本篇按更严格的口径：测试断言、边界用例、以及任何被拿来当「质量已验证」证据的测试，都要人看过。原因就在「为什么」第 1 节那个例子：让 AI 补单元测试，它可以「给单元测试直接糊了个 return」，覆盖率数字照样好看。两篇口径以本篇为准。

### 第一步：认清每个指标「测的是什么、会不会被刷」

这是本篇的决策核心表。按「投入 / 产出 / 结果」分层：越靠近「结果」越值得当北极星指标，越靠近「投入」越是虚荣指标。

| 指标 | 层次 | 测的是 | 判定 | 怎么用 |
|------|------|--------|------|--------|
| **代码行数 / diff 量** | 投入 | AI 吐了多少字 | ❌ 虚荣（可刷） | 只当「用量趋势」，**永不用于个人考核** |
| **AI 生码率（% AI 写的）** | 投入 | AI 参与度 | ❌ 虚荣 | 看 adoption 渗透率可以，别当产出 |
| **token / $ 消耗** | 投入（成本） | 花了多少钱 | ❌ 当效能是虚荣；✅ 当成本要管 | 归成本管理 [#060](../07-efficiency-and-cost/060-how-much-does-claude-code-cost-per-day.md) |
| **部署频率 / 变更前置时间**（DORA 速度） | 产出 | 交付节奏 | ⚠️ 有用但必须配对 | 与稳定性指标一起看 |
| **变更失败率 / 恢复时间**（DORA 稳定） | 结果 | 交付质量 | ✅ 信号 | AI 时代**尤其要盯**，防吞吐幻觉 |
| **重复率 / churn / 重构占比**（代码质量） | 结果 | 可维护性 | ✅ 信号 | 抓 AI 特有的「加了就忘」退化（GitClear） |
| **开发者体验（DXI / 满意度）** | 结果 | 可持续性 | ✅ 信号 | 反向牵制速度，防「快但把人榨干」 |
| **% 时间花在新能力上**（Impact） | 结果 | 业务价值 | ✅ 信号 | 防「忙而无功」 |

一句话判据：**能被一个人闷头刷高、又不改善业务的，就是虚荣指标。**

### 第二步：选框架，别自创，用成熟的三选一或组合

不要自己发明指标体系。有三个成熟框架。先按下面四个是非题选，别按「团队成熟度」这种模糊标准选。

1. **你现在能自动拿到「每次部署的时间」和「每次线上故障的开始/恢复时间」吗？** 拿不到 → 选 DORA，先把这两条数据打通，其他都免谈。
2. **能拿到，且你有渠道每季度向全员发一次调研问卷吗？** 不能发问卷 → 停在 DORA，别选另外两个：SPACE 和 DX Core 4 的核心维度都依赖主观数据，没问卷等于选了个空壳。
3. **能发问卷，且你的诉求是「防止有人用堆速度的方式做数据」吗？** 是 → 选 DX Core 4，它的四维就是为互相制衡设计的。
4. **诉求是「想看清团队为什么慢，包括协作和沟通」吗？** 是 → 参照 SPACE，它比另外两个多了 Communication 维度。

两个都是就先上 DX Core 4，用 SPACE 补它没覆盖的沟通问题——这两者不冲突。

**DORA（4 指标）是入门首选。**它聚焦「commit → 生产」这一段。它的局限是 Forsgren 本人说的：「DORA focuses on commit to production.」（DORA 聚焦从提交到生产这一段。）以及「DORA does not show the full picture」（DORA 展示的不是全貌，[Lenny's / Pragmatic](https://newsletter.pragmaticengineer.com/p/developer-productivity-with-dr-nicole)）。AI 时代务必四个指标一起看，别只挑吞吐那两个。

**SPACE（5 维度）适合想看全景的团队。**五个维度是：Satisfaction（满意度）、Performance（表现）、Activity（活动）、Communication（沟通）、Efficiency（效率）。它是一个「思考指标的框架」，而不是一套固定指标。Forsgren 说 DORA 本质上是 SPACE 的一个实例（"DORA is essentially one of many instances of SPACE"）。它适合想覆盖「人 + 流程 + 产出」全景的团队。

**DX Core 4（4 维度）适合想要可落地、防刷指标的团队。**它是 2024 年底由 DORA、SPACE、DevEx 三套框架的作者联合推出的，把三者统一成四个维度：速度、有效性、质量、影响。每个维度设一个主指标，再配若干制衡指标（[getdx: Measuring developer productivity with the DX Core 4](https://getdx.com/research/measuring-developer-productivity-with-the-dx-core-4/)）。它的设计哲学正是本篇的主张：四个维度相互制衡，防止用牺牲体验的方式堆速度。

### 第三步：铁律，单指标必配「制衡指标」

任何速度或吞吐指标，都必须挂一个反向指标一起报，否则一定会被刷。

吞吐量（diffs 数 / PR 数）上升时，要看变更失败率（CFR）是否也在上升。DX Core 4 把质量维度设计成速度维度的 "counterbalance"（反向制衡）。如果 diffs 涨、CFR 也跟着涨，那不是效能提升，是把东西越搞越乱（[getdx](https://getdx.com/research/measuring-developer-productivity-with-the-dx-core-4/)）。

速度上升时，要看开发者体验指数（DXI）是否在下降。DX Core 4 的四个维度就是设计成彼此制衡的（[getdx](https://getdx.com/research/measuring-developer-productivity-with-the-dx-core-4/)）。

数量上升时，要看重复率和 churn 是否在上升。这是 GitClear 揭示的质量退化信号。

**怎么判断「已经被刷了」——给可执行的判据。**先说清楚：DORA、SPACE、DX Core 4 三份官方材料都**没有**公布「涨多少算警戒」的绝对阈值（截至 2026-08 复核），因为各团队基线差太远。所以判据只能用相对变化，不能抄绝对数字。下面这套是可以直接照抄的相对规则：

| 检查项 | 怎么算 | 触发线（相对自身基线） | 触发了做什么 |
|--------|--------|----------------------|-------------|
| 速度 vs 质量背离 | 对比连续两个季度：吞吐量（PR 数或 diffs 数）变化率、变更失败率（CFR）变化率 | 吞吐涨 ≥20%，同期 CFR 也涨 | 停止对外报吞吐数字，先查 CFR 涨在哪个环节 |
| 速度 vs 体验背离 | 季度调研的开发者体验指数 | 连续两个季度下降 | 暂停任何提速目标，先做一轮定性访谈 |
| 代码质量退化 | 重复代码占比、两周内 churn 率（用 GitClear 或自建脚本） | 任一指标连续两季度单向上升 | 把「重构占比」加进本季度目标 |
| 指标被针对性优化 | 抽查 3 个数字最好看的 PR，人读 diff | 抽查里出现凑数提交、空断言测试、无意义拆分 | 该指标立即下线，别修，直接停 |

最后一行是最有用的一条：**任何指标体系上线三个月内，必须做一次人工抽查**。用眼睛读 3 个数字最漂亮的 PR，比再加十个指标都管用。抽查前不要预告。

### 第四步：三条硬规矩，防止指标变成考核凶器

**规矩一：产出和吞吐指标只在团队或组织级别看，绝不落到个人绩效。**DX Core 4 对它最著名的 "diffs per engineer"（人均代码变更量）指标有明确告诫：不要把它设成个人目标，也不要与奖惩挂钩（[getdx](https://getdx.com/research/measuring-developer-productivity-with-the-dx-core-4/)）。社区共识是：任何「人均产出」指标，无论包装多好，最终都会在绩效评估里被当武器用。

**规矩二：组合优于单点。**Forsgren 的原话是 "A constellation of metrics is better than a single metric for a holistic view."（一组指标比单个指标更能提供全局视角。）

**规矩三：客观数据要配主观信号。**纯遥测数据会漏掉认知负荷、心流、返工的痛感。用季度开发者体验调研补齐，比如 SPACE 里的 S（满意度）、DX Core 4 里的 DXI。

---

## Claude Code 实战

Claude Code 原生支持通过 OpenTelemetry（一套标准的遥测数据采集协议，简称 OTel）导出团队级遥测数据。这是你搭度量体系的数据源。但要用对指标，别掉进「拿它导出的 LoC 当考核」的坑。

### 官方能导出哪些指标

打开 `CLAUDE_CODE_ENABLE_TELEMETRY=1` 后，Claude Code 会按标准 OTel 协议导出以下指标（[CC Docs: Monitoring](https://code.claude.com/docs/en/monitoring-usage)，2026-08-03 核对）。

| 指标名 | 含义 | 度量定位 |
|--------|------|----------|
| `claude_code.session.count` | 启动的 CLI 会话数 | adoption（渗透率） |
| `claude_code.active_time.total` | 活跃时长（秒），按 `type`=user/cli 拆分 | adoption / 投入 |
| `claude_code.lines_of_code.count` | 增删的代码行数 | ⚠️ **虚荣**，只看趋势 |
| `claude_code.commit.count` | 创建的 commit 数 | ⚠️ 工作流影响，非产出 |
| `claude_code.pull_request.count` | 创建的 PR 数 | ⚠️ 同上 |
| `claude_code.cost.usage` | 会话成本（USD） | 成本（非效能） |
| `claude_code.token.usage` | token 用量 | 成本（非效能） |
| `claude_code.code_edit_tool.decision` | 用户 accept/reject 编辑的次数 | ✅ **有意思的信号** |

几个用法要点。

`code_edit_tool.decision`（采纳与拒绝的比例）比 LoC 有用得多。它间接反映「AI 产出被人采纳的比例」，比「AI 写了多少行」更接近价值。这是官方遥测里少有的、偏「结果」的信号。

怎么用它，说具体点。这个指标带四个属性：`tool_name`（`Edit` / `Write` / `NotebookEdit`）、`decision`（`accept` / `reject`）、`source`（`config` / `hook` / `user_permanent` / `user_temporary` / `user_abort` / `user_reject`）、`language`（编程语言）。

采纳率的算法：

```promql
# Claude Code 编辑建议的人工采纳率，按语言分组
sum by (language) (
  rate(claude_code_code_edit_tool_decision_total{decision="accept", source=~"user_.*"}[7d])
)
/
sum by (language) (
  rate(claude_code_code_edit_tool_decision_total{source=~"user_.*"}[7d])
)
```

两个要点。一是**必须过滤 `source`**：只留 `user_` 开头的（真人当场做的决定），把 `config` 和 `hook` 排除掉——那两类是权限规则自动放行/拦截的，不代表任何人的判断，混进来会把采纳率算虚高。二是**按 `language` 分组看**，别看总数：一个团队常见的情况是 Python 采纳率 85%、某个内部 DSL 只有 30%，合起来的平均值什么都说明不了。

多少算健康？**截至 2026-08，官方没有公布任何基线数值**，别去网上抄一个数字当目标。正确用法是只看自己的趋势线：某个语言或某个仓库的采纳率在两周内明显下滑，就去问那个方向的人「最近 AI 给的东西怎么样」——它是个提问的触发器，不是考核项。另外，这个指标同样**不能落到个人**，理由和 LoC 一样。

`cost.usage` 官方自己标注是近似值。原文是 "Cost metrics are approximations. For official billing data, refer to your API provider …"（成本指标是近似值。要拿官方账单数据，请查你的 API 提供方，原文后接括注 Claude Console、Amazon Bedrock、Google Cloud's Agent Platform）。所以别拿它和账单较真，账单归 [#060](../07-efficiency-and-cost/060-how-much-does-claude-code-cost-per-day.md)。

关于隐私。官方默认不导出 prompt 和工具内容，是否记录由 `OTEL_LOG_USER_PROMPTS`、`OTEL_LOG_ASSISTANT_RESPONSES`、`OTEL_LOG_TOOL_DETAILS`、`OTEL_LOG_TOOL_CONTENT` 这几个开关控制，**保持默认关闭即可**，没有任何度量需求需要打开它们。真正的问题在下面的 `user.email`。

### 落地姿势：一份能跑起来的最小配置

数据流是：Claude Code → OTel Collector → Prometheus（→ Grafana 出图）。下面这套在本机十分钟能跑通，跑通后把 endpoint 换成公司的 collector 就是团队版。所有环境变量名和默认值来自官方 monitoring 文档（2026-08-03 核对）。

**第 1 步：collector 配置 `otel-collector.yaml`**

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s

exporters:
  # 暴露 /metrics 供 Prometheus 抓取
  prometheus:
    endpoint: 0.0.0.0:8889
    # 把 OTEL_RESOURCE_ATTRIBUTES 里的 department、team.id 变成指标标签
    resource_to_telemetry_conversion:
      enabled: true
  # 调试用：把收到的数据打到 collector 日志
  debug:
    verbosity: detailed

service:
  pipelines:
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus, debug]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
```

**第 2 步：启动 collector**

```bash
docker run --rm \
  -p 4317:4317 -p 4318:4318 -p 8889:8889 \
  -v "$(pwd)/otel-collector.yaml:/etc/otelcol-contrib/config.yaml" \
  otel/opentelemetry-collector-contrib:latest
```

用 contrib 版而不是 core 版，因为 `prometheus` exporter 和 `resource_to_telemetry_conversion` 在 contrib 里。

**第 3 步：Claude Code 侧的环境变量全集**

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317

# 关键坑：Claude Code 默认发 delta，Prometheus exporter 只认 cumulative，
# 不改这一行，8889 端口上什么都看不到
export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative

# 默认 60000ms（60 秒）。调试时改短，跑通后记得改回来
export OTEL_METRIC_EXPORT_INTERVAL=10000

# 团队维度：给指标打上部门/团队标签（值里不能有空格）
export OTEL_RESOURCE_ATTRIBUTES="department=engineering,team.id=platform"

claude
```

**第 4 步：企业统一下发**（managed settings，走 MDM 推给全员，个人无需手工 export）

```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://collector.example.com:4317",
    "OTEL_EXPORTER_OTLP_HEADERS": "Authorization=Bearer example-token",
    "OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE": "cumulative"
  }
}
```

**第 5 步：Prometheus 抓取配置 `prometheus.yml`**

```yaml
scrape_configs:
  - job_name: claude-code
    scrape_interval: 30s
    static_configs:
      - targets: ["localhost:8889"]
```

### 怎么判断跑通了

按顺序验证，哪一步断了就知道问题在哪一段。

**验证 1：Claude Code 到底有没有在发。**先不接 collector，用 console exporter 打到终端：

```bash
CLAUDE_CODE_ENABLE_TELEMETRY=1 \
OTEL_METRICS_EXPORTER=console \
OTEL_METRIC_EXPORT_INTERVAL=1000 \
claude
```

预期：随便问一句话，一两秒后终端里出现包含 `claude_code.session.count`、`claude_code.token.usage` 的 JSON 输出。**没有任何输出**，说明遥测没打开（检查有没有被 managed settings 里的策略关掉）。

**验证 2：collector 收到了没。**看 collector 容器日志：

```bash
docker logs <container-id> 2>&1 | grep -c "claude_code"
```

预期：输出一个大于 0 的数字。是 0 → endpoint 或 protocol 配错了（grpc 对 4317，http 对 4318，两者写反是最常见的错）。

**验证 3：Prometheus 格式的指标出来了没。**这是最关键的一步：

```bash
curl -s http://localhost:8889/metrics | grep claude_code
```

预期看到类似：

```text
# HELP claude_code_session_count_total Count of CLI sessions started
# TYPE claude_code_session_count_total counter
claude_code_session_count_total{team_id="platform",department="engineering"} 3
```

注意指标名会被转换：点变成下划线，单调计数器再加 `_total` 后缀，所以 `claude_code.session.count` 在 Prometheus 里叫 `claude_code_session_count_total`。当前版本的 collector 里 `# HELP` / `# TYPE` 两行带的也是加了 `_total` 的全名（这个后缀行为由 prometheus exporter 的 `add_metric_suffixes` 控制，默认 true；见 [collector#12458](https://github.com/open-telemetry/opentelemetry-collector/issues/12458)，2026-08 核对），所以上面三行是一致的名字。**在 Grafana 里按原始点号名字查不到，是排查时最常见的误判。**以这条 curl 的实际输出为准。

curl 有输出、但空的 → 十有八九是漏了 `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative`。

**验证 4：Prometheus 端能查到。**在 Prometheus 的查询框执行 `claude_code_session_count_total`，预期返回非空、且数值随着你新开 Claude Code 会话而增长。到这里数据链路就通了。

### 一个必须先定的事：先定制度，再开开关

上面第 3 步一执行，`user.email` 就带上了（官方属性表标注 "Always included when available"，OAuth 登录时无法通过配置关掉）。也就是说，指标落到个人头上在技术上是默认可行的。

所以顺序不能反：**先书面说清「这些数据只在团队维度看、不进个人绩效」，再打开开关。**反过来做，等有人发现自己的邮箱在看板里，信任就没了，后面的规范推行也会很难（见 [#075](./075-team-ai-coding-standards.md)）。

如果只是想看团队 adoption、不需要精确到人，可以把账号维度关掉降低颗粒度：

```bash
export OTEL_METRICS_INCLUDE_ACCOUNT_UUID=false   # 默认 true
```

注意这只能去掉 `user.account_uuid` / `user.account_id`，去不掉 `user.email`——想彻底不落到个人，只能在 collector 侧用处理器把这个属性丢掉，或者在制度上禁止查询。

### 别指望它测出效能

交付效能，也就是 DORA 和 DX Core 4 里的质量与影响维度，要从你的 Git、CI、事故系统去取数。Claude 遥测只提供「AI 用量」这一个侧面。别指望它单独告诉你「团队更高效了」，它测的是投入，不是结果。

---

## 横向对比

三大度量框架，选哪个由「怎么做」第二步那四个是非题决定，下表的最后一列就是那四题的答案对照，别按「团队成熟度」这种感觉来选。

| 框架 | 维度 | AI 时代适配性 | 什么条件下选它（对应第二步的是非题） |
|------|------|--------------|--------|
| **DORA** | 部署频率 / 前置时间 / 变更失败率 / 恢复时间 | ⚠️ 仍有效，但「commit→生产」只覆盖一段；AI 时代必须四个一起看、盯稳定性 | 第 1 题答「拿不到部署时间或故障起止时间」→ 选它；或第 2 题答「发不了全员问卷」→ 停在它 |
| **SPACE** | 满意度 / 表现 / 活动 / 沟通 / 效率 | ✅ 天然覆盖「人+流程」，能装下认知负荷、心流这些 AI 新瓶颈 | 第 4 题答「想查清团队为什么慢、卡在协作和沟通上」→ 参照它（它比另两个多 Communication 维度） |
| **DX Core 4** | 速度 / 有效性 / 质量 / 影响 | ✅ 显式「四维制衡」，专治堆速度牺牲质量；主指标 diffs/engineer 自带「禁用于个人」警告 | 第 1、2 题都答「能」，且第 3 题答「要防有人靠堆速度做数据」→ 选它 |

三者不是竞争关系。DORA 是 SPACE 的一个子集（Forsgren 说 DORA 是 SPACE 的一个实例）。DX Core 4 则是 DORA、SPACE、DevEx 三者的统一（由三个框架的原作者联合推出）。

实践路径：小团队从 DORA 起步，加上质量和体验维度就成了 DX Core 4，想覆盖更软的协作和满意度就参照 SPACE。

> **反例警示**：GitClear 的 2.11 亿行研究说明，如果你的框架里只有「速度 / 数量」，没有「质量（重复率 / churn / 重构占比）」，AI 时代会系统性地把可维护性的退化藏起来。任何选型都要保证质量维度非空。

---

## 反模式

❌ **拿代码量或 AI 生码率当效能 KPI。**它们是虚荣指标，测投入不测产出，而且必被刷（@sagnitude 说「给单元测试直接糊了个 return」）。

❌ **拿 token 或美元消耗当效能考核。**「用 Token 量来定 KPI 比用代码量来定更蠢」（[V2EX @YanSeven](https://www.v2ex.com/t/1217703)）。token 是成本，归 [#060](../07-efficiency-and-cost/060-how-much-does-claude-code-cost-per-day.md)，不是效能。

❌ **只看 DORA 的速度那两个（部署频率、前置时间），不看稳定性。**AI 与稳定性负相关，只看吞吐量是 "acceleration whiplash"（加速甩尾），下游会爆雷（DORA 2025 / Faros）。

❌ **用单一指标下结论。**任何单指标都会被刷，要用相互制衡的指标组（Forsgren 说的 "constellation of metrics"）。

❌ **把团队级吞吐指标落到个人绩效。**DX Core 4 明确要求这类指标 "never used at the individual level"（绝不用于个人层面），否则会被当武器。Claude 遥测的 `user.email` 属性让这在技术上可行，所以制度上必须禁止。

❌ **以为上了 AI，数字就会自动变好。**AI 是放大器，烂流程只会被放大得更烂（DORA 说的 "amplifier"）。先修系统，再谈度量。

❌ **只测 AI 用量、不测交付结果。**Claude 遥测测的是投入侧，真效能要从 Git、CI、事故系统取质量与影响维度。

---

## 延伸

**交叉引用：**
- [#040 AI 说"做完了"、测试也全绿，怎么知道代码是真的对？](../05-quality-assurance/040-who-verifies-ai-code-and-how.md) —— 本篇「verification tax」的落地面：验证怎么做是 040 的活，本篇只主张度量上要承认这笔税。
- [#060 额度怎么突然就没了？20x Max 也撑不过一上午——先算清自己一天该烧多少](../07-efficiency-and-cost/060-how-much-does-claude-code-cost-per-day.md) —— token/$ 是成本指标，归这里，不进效能考核；`cost.usage` 只是近似值，真账单和订阅档位也看这篇。
- [#075 团队的 AI coding 规范怎么立？哪些该强制、哪些该自由？](./075-team-ai-coding-standards.md) —— 度量口径本身要写进规范，别把度量做成监控或考核；另外「测试该不该人审」两篇口径以本篇为准：测试夹具可以只让 AI 审，测试逻辑本身必须人审。
- [#073 天天用 AI 写代码，我是不是在越用越不会写？junior 怎么一边用 AI 一边真长本事](./073-junior-developer-growth-ai-era.md) —— 「个人产出指标」对 junior 的伤害在这篇展开。

**参考资料：**
- [DORA Report 2025: State of AI-Assisted Software Development](https://dora.dev/dora-report-2025/) — "AI as amplifier" + ROI 来自系统而非工具（行业权威，2025）
- [Faros AI: Key Takeaways from the DORA Report 2025](https://www.faros.ai/blog/key-takeaways-from-the-dora-report-2025) — 95% 采用 / 80%+ 提效 / 吞吐反转 / 稳定性负相关 / 七种团队画像 / 度量失败模式（社区，2026）
- [Monitoring - Claude Code Docs](https://code.claude.com/docs/en/monitoring-usage) — 官方 OTel 指标清单；`lines_of_code.count` 官方说明只是 "Count of lines of code modified"（按 added/removed 与 model 拆分），并未把它定位成生产力度量；"cost 是近似值"（官方，2026）
- [OpenTelemetry Collector: Prometheus Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/prometheusexporter) — 实战一节 collector 配置的依据：`endpoint`、`resource_to_telemetry_conversion`、以及「只接受 cumulative 时序」这条限制（官方，2026-08 访问）
- [Prometheus 官方：Using Prometheus as your OpenTelemetry backend](https://prometheus.io/docs/guides/opentelemetry/) — OTel 指标名到 Prometheus 名的转换规则（点变下划线、单调计数器加 `_total`）（官方，2026-08 访问）
- [getdx: Measuring developer productivity with the DX Core 4](https://getdx.com/research/measuring-developer-productivity-with-the-dx-core-4/) — 四维制衡 / diffs per engineer 禁用于个人（行业，2024-12）
- [Pragmatic Engineer: Developer productivity with Dr. Nicole Forsgren](https://newsletter.pragmaticengineer.com/p/developer-productivity-with-dr-nicole) — 单指标必被优化 / DORA⊂SPACE / constellation of metrics（社区权威）
- [GitClear: AI Copilot Code Quality 2025](https://www.gitclear.com/ai_assistant_code_quality_2025_research) — 2.11 亿行实证：克隆约 4 倍、重构 25%→<10%、克隆占比 8.3%→12.3%、短期 churn 上升（行业研究，2025）
- [V2EX 1217703: 必须对 AI 进行严肃的绩效考核](https://www.v2ex.com/t/1217703) — "用 Token 量定 KPI 比代码量更蠢" + AI 刷指标（社区，2026-06）
- [InfoQ: AI Is Amplifying Software Engineering Performance, Says the 2025 DORA Report](https://www.infoq.com/news/2026/03/ai-dora-report/) — verification tax 解读（社区，2026）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
