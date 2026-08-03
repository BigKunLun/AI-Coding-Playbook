# 060. 额度怎么突然就没了？20x Max 也撑不过一上午——先算清自己一天该烧多少

> 难度：中级
> 主题：效率与成本
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：场景题 + 配置题

> ⏰ 时效声明：本篇所有价格与基准数字（模型单价、$13/天、缓存倍率等）已于 **2026-07-18** 对照官方文档逐项核实无误，来源为 [CC Docs: costs](https://code.claude.com/docs/en/costs) 和 [claude.com/pricing](https://claude.com/pricing)。价格类事实随官方调价即失效，引用前请以官方页面为准。「怎么做」第四步的订阅计划价与 `/usage-credits` 行为另于 **2026-08-03** 核实。

## TL;DR

先给一个参考锚点，再教你怎么量自己的消耗。

**记住官方的三个数。** 在企业部署里，平均每个活跃开发者每天花 **$13**，每月 **$150–250**。而且 **90% 的用户每个活跃天低于 $30**。你落在这个区间，就算正常。来源：[CC Docs: costs](https://code.claude.com/docs/en/costs)（官方，2026-06）。

**"一天多少 token 才正常"其实是个错问题。** token 数没有绝对的正常值，原因有两个。一是不同模型的单价差 5 倍：Opus 每百万 token 是 $5/$25（输入/输出），Haiku 只有 $1/$5。二是绝大部分 token 走的是缓存，缓存命中只花 0.1 倍价格。有社区实测过缓存命中率高达 88.8%、日均 $13.86、按月推算约 $416，见 [HN 45914307](https://news.ycombinator.com/item?id=45914307)（社区，2025-11，个例）。所以真正要盯的是"每天花多少钱"和"缓存命中率"，不是 token 的绝对数字。

**量自己的消耗有三层工具。** 在会话里敲 `/usage`，能看本会话的 token 和估算美元。订阅制（Pro/Max）用户看的是额度进度条，不是账单。想跨会话看历史，用社区工具 **ccusage**，它读本地日志，命令是 `npx ccusage@latest`。API 或企业用户的权威账单在 Console。

**本篇只回答"正常量级 + 怎么测自己"。** 测完发现额度不够、该上哪一档订阅，见本篇「怎么做」第四步。主动省 token 的手段见 [#062 怎么少烧 token？prompt caching / 精简 CLAUDE.md / 模型切换哪个最有效？](./062-reduce-claude-code-token-usage.md)。按任务选模型见 [#063 什么时候该用 Opus、什么时候该用 Sonnet/Haiku？怎么按任务路由模型才不浪费？](./063-model-routing-when-to-use-opus.md)。团队层面怎么把用量和预算写进规范，见 [#075 团队的 AI coding 规范怎么立？哪些该强制、哪些该自由？](../08-team-and-org/075-team-ai-coding-standards.md)。

---

## 为什么

### 1. 官方给了明确基准，别拿社区极端值吓自己

Anthropic 官方文档直接写了企业部署的成本分布：

> "Across enterprise deployments, the average cost is around **$13 per developer per active day** and **$150-250 per developer per month**, with costs remaining **below $30 per active day for 90% of users**."
>
> 中文转述：在企业部署里，平均每个开发者每个活跃天约 $13、每月 $150–250，且 90% 的用户每个活跃天低于 $30。
>
> 来源：[Manage costs effectively — Claude Code Docs](https://code.claude.com/docs/en/costs)（官方，2026-06）

把这三个数当作你的正常标尺。中位数体验约 $13/天，90 分位是 $30/天，月账单 $150–250 是常态。

注意里面的"活跃天"这个词。不写代码的那天不算，所以别拿 30 天去乘 $13。

官方还强调，人均成本会因为模型选择、代码库大小、使用方式（比如同时跑多个实例、开自动化）而差别很大。换句话说，跑多个实例、开自动化、默认一直挂 Opus，都会把你推到分布的高消耗一侧。这不是故障，而是你自己的使用模式决定的。

### 2. "一天多少 token"没有标准答案，钱由单价和缓存决定

同样的 token 数，花的钱可以差一个数量级。原因有两个。

**第一，模型单价差 5 倍。** 官方各模型每百万 token 的定价如下：

| 模型 | 输入 $/1M | 输出 $/1M |
|------|-----------|-----------|
| Claude Opus 4.8 | $5.00 | $25.00 |
| Claude Sonnet 5 / Sonnet 4.6 | $3.00 | $15.00 |
| Claude Haiku 4.5 | $1.00 | $5.00 |

来源：Anthropic 官方定价（[claude.com/pricing](https://claude.com/pricing)）。注：Sonnet 5 有引导期折扣（$2/$10，至 2026-08-31），本表按标准价列，分档细节见 [#063](./063-model-routing-when-to-use-opus.md)。同样是 100 万输出 token，Opus 花 $25，Haiku 只花 $5。所以"今天烧了多少 token"和"花了多少钱"之间，隔着一层模型选择。路由怎么选见 [#063](./063-model-routing-when-to-use-opus.md)。

**第二，绝大多数 token 是缓存命中，只花 0.1 倍价。** prompt caching 指的是把重复内容（比如系统提示词）缓存起来复用，Claude Code 默认就开着。官方说明：

> "Claude Code automatically optimizes costs through **prompt caching**, which reduces costs for repeated content like system prompts …"
>
> 中文转述：Claude Code 通过 prompt caching 自动优化成本，对系统提示词这类重复内容降低费用。
>
> 来源：[CC Docs: costs](https://code.claude.com/docs/en/costs)（官方，2026-06）

缓存的计价规则（官方倍率）是这样的。写入缓存花 1.25 倍（5 分钟有效期）或 2.0 倍（1 小时有效期）。读取缓存只花 0.1 倍输入价。

有个社区实测把这点讲得很透。帖子标题说的是 6 周花了 $638，作者后来在评论里用 Claude 复盘完整 CSV 账单，给出了一个覆盖更长区间的统计：70 天共 $928.45，平均每个请求 83,371 tokens、缓存命中率 88.8%、单日均值 $13.86、按月推算约 $416。两组数字不冲突，只是统计区间不同（6 周 vs 70 天），本篇后文引用的是 70 天那组。见 [HN 45914307](https://news.ycombinator.com/item?id=45914307)（社区，2025-11，个例）。88.8% 的 token 走 0.1 倍价，这就是为什么"海量 token"不等于"海量账单"。

所以，盯 token 绝对数会误判。你要盯两个指标。一是每日美元，用来对齐 $13 和 $30 基准。二是缓存命中率，命中率低就说明钱在漏，怎么治见 [#062](./062-reduce-claude-code-token-usage.md)。

### 3. `/usage` 里的美元是估算，订阅制根本不按它计费

官方对 `/usage` 里那个美元数有明确警告：

> "The dollar figure is an **estimate computed locally from token counts and may differ from your actual bill**. For authoritative billing, see the Usage page in the Claude Console."
>
> 中文转述：这个美元数是本地根据 token 数估算出来的，可能和实际账单有出入。权威账单请看 Claude Console 的 Usage 页。
>
> 来源：[CC Docs: costs](https://code.claude.com/docs/en/costs)（官方，2026-06）

订阅制（Pro/Max）的计费逻辑完全不同：

> "Claude Max and Pro subscribers have usage included in their subscription, so the **session cost figure isn't relevant for billing purposes**. Subscribers see plan usage bars, activity stats, and a usage breakdown on the same screen."
>
> 中文转述：Max 和 Pro 订阅用户的用量已包含在订阅里，所以那个会话成本数字和计费无关。订阅用户在同一屏看到的是额度进度条、活动统计和用量拆分。
>
> 来源：同上（官方，2026-06）

所以要分两种人看。API 或 Console 用户，`/usage` 的美元只是本地估算，Console 账单才是真值。订阅用户，那个美元数只是"如果按 API 算会是多少"的参考，你真正该看的是额度进度条。订阅按 5 小时窗口加周窗口结算，怎么用这条进度条判断该不该升档，见下面「怎么做」的第四步。

---

## 怎么做

### 第一步：定位自己该对齐哪个基准

| 你的场景 | 正常量级参考 | 数据源 |
|---------|-------------|--------|
| 个人订阅 Pro/Max，日常写代码 | 额度进度条别频繁撞顶即正常；换算成 API 约 $13/活跃天档 | 官方 $13/天基准 |
| API 按量计费，单人重度使用 | $13/天是中位，$30/天已是 90 分位；月 $150–250 | 官方基准 |
| 挂 Opus + 多实例 + 自动化 | 会明显高于 $30/天，属高消耗一侧，正常但可优化 | 官方"vary widely" |
| 企业/团队人均 | $150–250/人·月做预算起点，先小范围试点建基线 | 官方"start with a small pilot group" |

官方对团队给了明确的估法：

> "start with a small pilot group and use the tracking tools below to establish a baseline before wider rollout"
>
> 中文转述：先用一个小的试点组，配合下面的跟踪工具建立基线，再大范围推广。
>
> 来源：[CC Docs: costs](https://code.claude.com/docs/en/costs)（官方）

一句话，别拍脑袋定预算，先试点测出基线。

### 第二步：量自己的实际消耗（三层工具）

**第一层，会话内即时看，用 `/usage`。** 在会话里敲 `/usage`，顶部的 Session 块给出本会话的 token 明细和估算美元。订阅用户还能额外看到额度进度条和活动统计，按 `d` 或 `w` 切换近 24 小时和近 7 天。注意，这些数据只来自本机的会话历史，其他设备和 claude.ai 上的用量不算在内（官方）。执行 `/clear` 开新会话后，总额会归零。

**第二层，跨会话和历史复盘，用 ccusage（社区工具）。** 官方 Console 不给订阅用户看逐 token 明细，社区工具 ccusage 正好填这个空。它读 Claude Code 的本地日志文件、不上传数据，敲 `npx ccusage@latest` 就能用。它支持 `daily`、`weekly`、`monthly`、`session`、`blocks`（5 小时窗口）等视图，`ccusage blocks --live` 还有实时仪表盘。来源：[ccusage.com](https://ccusage.com/) 和 [github.com/ryoppippi/ccusage](https://github.com/ryoppippi/ccusage)（社区）。建议每周跑一次，看看 token 花在哪、据此调整习惯。

**第三层，权威账单，看 Console 或企业分析。** API 用户看 [Claude Console 的 Usage 页](https://platform.claude.com/usage)，这是唯一权威账单。企业和团队看组织分析里的支出报告（可按用户或模型拆分、导出 CSV、每日更新），或者用 Enterprise Analytics API（官方）。

### 第三步：判断"是否正常"的清单

- [ ] 把消耗换算成**每活跃天美元**，对齐 $13（中位）和 $30（90 分位）。超了先别慌，看是不是挂了 Opus 或跑了多实例。
- [ ] 看**缓存命中率**（ccusage 会分列 cache read 和 cache write）。健康值应该很高（社区实测在 88.8% 量级）。偏低说明上下文频繁失效，是漏钱点，怎么治见 [#062](./062-reduce-claude-code-token-usage.md)。
- [ ] 订阅用户看额度进度条是否频繁撞 5 小时或周窗口的顶。撞顶不等于超支，那是节流机制。
- [ ] 团队先小范围试点建基线，再拿 $150–250/人·月做预算。

### 第四步：测完发现额度不够，先别急着升档

测出来的日均乘以月活跃天数，就是「同样的活儿走 API 要花多少钱」（下称 API 等价月消耗）。拿这个数定档时，只有两条金额线，再往上就不看金额了（订阅价：Pro $20/月、Max 5x $100/月、Max 20x $200/月，[claude.com/pricing](https://claude.com/pricing)，官方，2026-08 核实）：

- API 等价超过约 $20/月 → Pro 回本。
- 超过约 $100/月 → Max 5x 回本。
- 再往上 → **仍然停在 Max 5x**。订阅档位买的是限流额度，不是消费额度。API 等价 $260/月的人在 Max 5x 上已经净省 $160，升到 Max 20x 并不会「更划算」。

所以升到 Max 20x 的唯一正当理由是**持续撞 5 小时窗口或周窗口的限流**——用第二步的 `/usage` 看限额条，一周里有 3 天以上被打断且影响交付，才算「持续」。偶尔一次不算。

**偶发峰值用 `/usage-credits` 兜底。** 这个会话内命令让你用完订阅额度后按标准 API 价继续跑，并且能设月度上限。用法：先确认自己是 `/login` 的订阅凭据登录（用 API key 认证时该命令不可用），会话里敲 `/usage-credits` 跳到网页 Settings → Usage，在 Usage credits 区域点 Enable，绑支付方式，**先用 Adjust limit 把月度上限设死**（有个 "Set to unlimited"，别选），最后 Add funds。

两个副作用必须知道：超出部分按标准 API 价计费，没有折扣；而且一旦动用 usage credits，prompt cache 有效期会从订阅的 1 小时降到 5 分钟（官方 costs 文档）。间隔稍长的下一次提问更容易缓存未命中、重新处理整段上下文，单价和用量同时上升。这就是它只适合扛偶发峰值、不适合当常态的原因。

**怎么判断做对了**：网页 Settings → Usage 里出现余额和月度上限两个数字；撞到 spend limit 时 Claude Code 会直接在 CLI 里提示你抬高或移除上限。

---

## Claude Code 实战

**场景**：你是订阅 Max 用户，感觉最近烧得快，想判断是否正常。跟着走一遍。

| 步骤 | 动作 | 该看什么 / 为什么 |
|------|------|------------------|
| 1 | 会话里敲 `/usage`，按 `w` 切到近 7 天 | 看额度进度条，以及 skills、subagents、MCP 的用量占比拆分（官方支持按来源归因）。先定位是谁在吃额度。 |
| 2 | `npx ccusage@latest daily` | 跨会话看每日趋势。哪天异常高就点进去，看是不是那天挂了 Opus 或派了 agent team。 |
| 3 | 看 ccusage 的 cache 分列 | 缓存命中率是否健康。低了说明上下文老失效，频繁改 CLAUDE.md 或换模型都会让缓存前缀失效。 |
| 4 | 把每活跃天换算成美元，对齐 $13/$30 | $30/天以内属于官方的 90% 区间，正常。超了看第 5 步。 |
| 5 | 排查高消耗成因 | 官方点名了两个最常见原因，见下方引用。 |

官方对高消耗最常见的两个成因说得很直接：

> "long sessions that were never cleared or to Opus left as the default model"
>
> 中文转述：从不清理的长会话，以及把 Opus 一直当默认模型。
>
> 来源：[CC Docs: costs](https://code.claude.com/docs/en/costs)（官方）

对应的做法是：用 `/clear` 分隔无关任务，以及按任务选模型。

**一个常被忽略的成本项是 agent teams。** 这里只给指针，不展开攻略。官方明确说，agent teams 在 plan 模式下大约用 **7 倍 token**，因为每个队友都有独立的上下文。见 [CC Docs: costs](https://code.claude.com/docs/en/costs)（官方）。如果你的"烧得快"发生在派了多个 agent 之后，这就是原因。并发的经济账细节在 [#063](./063-model-routing-when-to-use-opus.md) 的模型和路由讨论里，执行侧决策见 [#032](../04-execution-workflow/032-subagent-when-and-how.md)。

**后台也会烧一点点。** 官方说明，Claude Code 空闲时也有后台 token，比如生成会话摘要、查询 `/usage` 状态等。但这部分"typically under $0.04 per session"（通常每个会话不到 $0.04，官方）。量级可以忽略，别为这个焦虑。

---

## 横向对比

不同工具的成本可见性和计费模型差别很大，这直接决定了你"怎么估"。

| 工具 | 计费模型 | 成本可见性 | 关键差异 |
|------|---------|-----------|---------|
| **Claude Code** | 订阅(Pro/Max 额度) 或 API 按 token | `/usage`(会话估算) + Console(权威) + ccusage(本地历史) | token 计价透明、缓存自动、官方给了 $13/$30 基准；单 token 相对贵但缓存命中率高 |
| **Cursor** | 订阅(含额度) + 超额按请求/token | 应用内 usage 面板 | 订阅打包，超额才计量；模型混用，成本归因不如逐 token 透明 |
| **GitHub Copilot** | 固定月费(座席) + premium requests 配额 | 组织后台按座席/请求 | 以座席制为主，成本可预测但和 token 量脱钩，难以按用量精算 |

核心差异是这样。Claude Code 是三者里 token 级成本最透明的，逐 token 计价、加上 `/usage` 和 ccusage，能拆到 skill 或 subagent 级别。代价是社区常说的"单 token 更贵"，但这个印象忽略了缓存命中率。座席制工具（Copilot）成本可预测，但你几乎无法回答"这个任务花了多少钱"。至于订阅还是 API 更划算、该定哪一档，见「怎么做」的第四步。

---

## 反模式

- ❌ **拿"一天多少 token"当正常性标准。** token 单价按模型差 5 倍，且约九成走 0.1 倍缓存价，token 绝对数说明不了钱。要盯每日美元和缓存命中率。
- ❌ **把 `/usage` 的美元数当账单。** 官方明说它是估算、可能和实际账单有出入；订阅用户那个数更是不用于计费。权威值在 Console。
- ❌ **用 30 天乘 $13 估月账单。** 官方基准是"每活跃天"，不写代码那天不算。直接用官方给的 $150–250/月区间，别自己乘。
- ❌ **看到额度撞顶就以为超支。** 订阅制的 5 小时和周窗口是节流机制，撞顶是限速不是扣费。换算成美元之前别恐慌。
- ❌ **默认挂 Opus、从不 `/clear` 还嫌贵。** 官方点名这两个是高消耗最常见成因。这不是"Claude Code 贵"，是使用模式问题。省法见 [#062](./062-reduce-claude-code-token-usage.md) 和 [#063](./063-model-routing-when-to-use-opus.md)。
- ❌ **按金额一路升档到 Max 20x。** 「API 等价 $260 > $200，所以该上 20x」是错的。订阅档位是限流额度不是消费额度，升 20x 的唯一理由是持续撞限流。
- ❌ **一撞限流就跳最贵档。** 偶发峰值先用 `/usage-credits` 设上限兜底。但它会把缓存有效期从 1 小时压到 5 分钟，是应急手段不是常态。
- ❌ **团队直接拍人均预算就铺开。** 官方建议先小范围试点建基线再放大。别拿别人的极端账单当自己的预期，比如社区流传的 $80K/月、$47K 事件账单，这些都是未经核实的个例。

---

## 延伸

**交叉引用：**
- [#075 团队的 AI coding 规范怎么立？哪些该强制、哪些该自由？](../08-team-and-org/075-team-ai-coding-standards.md) —— 个人测出的量级要变成团队预算和用量约定，落到规范里。
- [#062 怎么少烧 token？prompt caching / 精简 CLAUDE.md / 模型切换哪个最有效？](./062-reduce-claude-code-token-usage.md) —— 本篇教怎么测，062 教怎么降（缓存、清理、瘦身 CLAUDE.md）。
- [#063 什么时候该用 Opus、什么时候该用 Sonnet/Haiku？怎么按任务路由模型才不浪费？](./063-model-routing-when-to-use-opus.md) —— 模型单价差 5 倍，路由是成本的主变量。
- [#032 开几个 agent 并行跑，结果互相踩、被限流、token 指数级炸开——并行到底该开几个？](../04-execution-workflow/032-subagent-when-and-how.md) —— agent teams 约 7 倍 token，是本篇成本视角的执行侧决策。
- [#012 上下文窗口要爆了怎么办？](../02-context-engineering/012-context-window-exploding.md) —— 上下文膨胀是成本的根因之一。

**参考资料：**
- [Manage costs effectively — Claude Code Docs](https://code.claude.com/docs/en/costs) —— $13/活跃天、$150–250/月、90% 低于 $30/天，加上 `/usage` 估算警告、订阅额度语义、agent teams 约 7 倍、后台低于 $0.04（官方，2026-06）。
- [Anthropic 定价（各模型每百万 token）](https://claude.com/pricing) —— Opus $5/$25、Sonnet $3/$15、Haiku $1/$5；缓存写入 1.25 倍或 2.0 倍、读取 0.1 倍（官方）。
- [I spent $638 on AI coding agents in 6 weeks — HN 45914307](https://news.ycombinator.com/item?id=45914307) —— $928.45/70 天、平均 $0.06/请求、83,371 tokens/请求、缓存命中 88.8%、日均 $13.86、按月约 $416（社区，2025-11，个例）。
- [Claude Pricing — claude.com/pricing](https://claude.com/pricing) —— Pro $20/月、Max 5x $100/月、Max 20x $200/月，用于「怎么做」第四步的两条金额线（官方，2026-08 核实）。
- [Manage usage credits for paid Claude plans — Claude 帮助中心](https://support.claude.com/en/articles/12429409-manage-usage-credits-for-paid-claude-plans) —— usage credits 的网页端开启路径与月度上限设置（官方，2026-08 核实）。
- [ccusage —— 本地用量分析 CLI](https://ccusage.com/) 和 [github.com/ryoppippi/ccusage](https://github.com/ryoppippi/ccusage) —— 订阅用户查看逐 token 明细的社区首选工具（社区）。

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
