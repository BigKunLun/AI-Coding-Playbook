# 062. 什么时候该用 Opus、什么时候该用 Sonnet/Haiku？怎么按任务路由模型才不浪费？

> 难度：中级
> 主题：效率与成本
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：决策题 + 配置题

> ⏰ 时效声明：本篇的模型单价（Haiku $1/$5、Sonnet $3/$15、Opus $5/$25、Fable $10/$50）与倍率换算已于 **2026-07-18** 对照 Anthropic 官方定价核实无误；`/model` alias 表与 SubAgent 继承规则同日对照官方文档核实。模型换代或调价后倍率结论需重算，请以官方页面为准。

## TL;DR

先说结论：默认不要把 Opus 当常驻模型。这是账单意外飙高最常见的原因之一。官方费用文档把「Opus 被留作默认模型」和「长会话一直不清理」并列为计费失控的两大根因（[CC Docs: costs](https://code.claude.com/docs/en/costs)，官方，2026-06）✅。

正确做法是分三层路由。判断标准是「这个任务需要模型多聪明」，而不是「我想用最强的那个」。

第一层，默认用 Sonnet。它是日常写代码的主力。官方原话是「Sonnet 能很好地处理大多数编码任务，而且比 Opus 便宜」（[CC Docs: costs](https://code.claude.com/docs/en/costs)）✅。

第二层，Opus 只留给硬骨头。官方建议「把 Opus 留给复杂的架构决策或多步推理」，也就是复杂架构、多步推理、问题描述含糊这几类。它的单价约为 Sonnet 的 **1.67 倍**（Opus 每百万 token $5/$25，Sonnet $3/$15，详见文末定价）✅。

第三层，Haiku 干苦力活。跑测试、抓日志、机械搜索这类交给 SubAgent 的子任务，配上 `model: haiku` 即可（[CC Docs: sub-agents](https://code.claude.com/docs/en/sub-agents)）✅。它的单价只有 Sonnet 的 **三分之一**（$1/$5）✅。

选型时可以记一句官方博客给的诊断问题：Claude 做错了，是「不够懂」还是「不够努力」？不够懂就升模型，不够努力就升 effort（effort 指让模型多思考、多检查的努力档位）。出处见 [Anthropic: Choosing a model and effort level](https://claude.com/blog/claude-model-and-effort-level-in-claude-code)（官方，2026）✅。

关于边界：本篇只讲模型路由的经济决策和配置。相关话题各有专篇。「一天烧多少钱算正常、订阅该定哪一档」见 [#060](./060-一天该烧多少额度.md)；「怎么少烧 token，包括缓存和精简 CLAUDE.md」见 [#062](./061-怎么少烧token.md)；「SubAgent 何时派」的决策侧见 [#032](../04-执行工作流/032-SubAgent并行开几个.md)，本篇只补它的成本维度。

## 为什么

### 1. 贵模型不一定贵，但无脑用贵的一定亏

很多人以为「反正缓存便宜，全程用 Opus 更稳」。但官方明确把「Opus 被留作默认」列为高账单的根因。原文如下：

> "Unexpectedly high spend on an API or cloud-provider plan: usually traces back to long sessions that were never cleared or to **Opus left as the default model**. The highest-impact habits to share are clearing between unrelated tasks and **matching the model to the job**…"
> — [CC Docs: costs](https://code.claude.com/docs/en/costs)（官方，2026-06）✅

翻成白话：API 或云计费账单意外飙高，通常源于两件事，一是长会话一直没清理，二是把 Opus 留作了默认模型；最有效的习惯是在不相关的任务之间清理会话，以及让模型匹配任务。（原句结尾还有一句 "…both covered in reduce token usage."，指向该文档的「减少 token 用量」小节，这里省略。）

关键词是「让模型匹配任务」。路由是一个主动的动作，不是「选个最强的就一劳永逸」。

### 2. 单价差是真实存在的，按 token 计费时会逐条累加

以下按 Anthropic 官方定价，单位是每百万 token 的 input/output 价格：

| 模型 | input $/1M | output $/1M | 上下文 | 相对 Sonnet |
|------|-----------|-------------|--------|-------------|
| **Haiku 4.5** | $1 | $5 | 200K | ≈ 1/3 |
| **Sonnet 5** | $3（引导期 $2，至 2026-08-31）| $15（引导期 $10）| 1M | 1x（基准）|
| **Opus 4.8** | $5 | $25 | 1M | ≈ 1.67x |
| **Fable 5** | $10 | $50 | 1M | ≈ 3.3x |

数据源为 Anthropic 官方模型定价（2026-06）✅。注意引导期 Sonnet 5 的折扣只在 2026-08-31 前有效，你读到本篇时请以官方定价页现价为准。

这张表要看两点。第一，Opus 只比 Sonnet 贵 1.67 倍，不是数量级的差距。第二，订阅制下你不直接按 token 付费，但仍然会消耗用量额度（会话额度、每周额度）。所以路由照样影响你多久会撞到限额（见 [#060](./060-一天该烧多少额度.md)）。

### 3. 贵模型单价高，但可能 token 更省，权衡不是单变量

社区里有个常见争论：Opus 单价是 Sonnet 的 1.67 倍，但因为它更少走弯路、更少来回改，完成同一个任务的总 token 可能反而更少。这个权衡是真实存在的。社区讨论标题就点出了「Opus 更贵但 token 更省」这个对立观点，见 [r/ClaudeCode 讨论](https://www.reddit.com/r/ClaudeCode/comments/1rc6xpu/is_opus_46_really_worth_it_compared_to_sonnet/)（社区，⚠️ 单源、未逐字核对正文）。

但这不能推出「Opus 永远更划算」。官方给的判断标准更精确：要区分 Claude 是「缺知识」还是「没努力」。原文如下：

> "did it not *try* hard enough, or did it not *know* enough?"
> — [Anthropic: Choosing a model and effort level](https://claude.com/blog/claude-model-and-effort-level-in-claude-code)（官方，2026）✅

翻成白话：它是不够努力，还是不够懂？不够努力就升 effort，不够懂就升模型。

同一篇官方博客还把三档模型拟人化，值得记住。Sonnet 是「很好的通才」，适合能被精确描述的编辑、机械改动、以及上下文里已有代码的问答。Opus 是「专家」，适合复杂、含糊、小模型容易「自信地答错」的问题，它比 Sonnet 更会处理模糊需求。Fable 是最强的专家，适合微妙的 bug、陌生领域、架构决策，只有在其它模型「真的被逼到极限」时才动用它 ✅。

## 怎么做

下面是三档路由的操作清单，从默认往上升级。

第一步，把默认设成 Sonnet，不是 Opus。在 `/config` 里设默认模型，或用 `/model sonnet`（v2.1.153 及以后会把它存为新会话默认）。日常编码、能描述清楚的改动、上下文里已有代码的问答，全部走 Sonnet ✅。

第二步，撞到「不够懂」时才升 Opus。触发信号包括：复杂架构决策、多步推理、含糊的根因排查、小模型反复自信地改错。手段是用 `/model opus` 临时切换，或对整个规划阶段用 `opusplan`（详见实战）✅。

第三步，撞到「不够努力」时先升 effort，别急着升模型。触发信号包括：Claude 跳过了某个文件、没跑测试、没复查。手段是用 `/effort` 或在 `/model` 里调 effort 档位，这比换模型便宜（[CC Docs: model-config](https://code.claude.com/docs/en/model-config)，官方）✅。反过来，简单任务可以把 effort 调低。官方博客的原话是「降低 effort 会提升速度、通常还能降低成本，而不影响输出质量」（[Anthropic: Choosing a model and effort level](https://claude.com/blog/claude-model-and-effort-level-in-claude-code)，官方，2026）✅。

第四步，给 SubAgent 显式配便宜模型。跑测试、抓文档、处理日志这类高 token、低智力的子任务，在 subagent 的 frontmatter 里写 `model: haiku`；需要更强分析能力的子任务写 `model: sonnet`。不写的话默认是 `inherit`，也就是跟随主会话的模型 ✅。

第五步，Agent teams 里用 Sonnet 当队友。官方建议「队友用 Sonnet，它在协调类任务上兼顾了能力和成本」。而且 agent teams（也就是 plan mode 下的多智能体）大约会消耗 7 倍 token，务必收敛队伍规模（[CC Docs: costs](https://code.claude.com/docs/en/costs)）✅。

第六步，只有真正的硬骨头才动用 Fable。适用场景是跨会话的大重构、线上故障排查、架构决策，用 `/model fable`。它的单价约为 Sonnet 的 3.3 倍，不是日常选项 ✅。

> 一条反直觉但省钱的经验：升 effort 常常比升模型更值。同一个 Sonnet 在高 effort 下也能「彻底理解你的具体代码」（官方博客 ✅）。很多「以为只有 Opus 才做得对」的情况，其实只是 effort 不够。

## Claude Code 实战

### `/model` 的全部可选项

以下是 Anthropic API 上的官方 alias 表：

| alias | 行为 | 何时用 |
|-------|------|--------|
| `default` | 清除覆盖，回到账户推荐模型 | 想重置 |
| `sonnet` | 最新 Sonnet（API 上 = Sonnet 5）| **日常编码默认** |
| `opus` | 最新 Opus（= Opus 4.8）| 复杂推理/架构 |
| `haiku` | 快而省 | 简单任务、SubAgent 苦力 |
| `fable` / `best` | Fable 5（有权限时）| 最难、跨会话的长任务 |
| `sonnet[1m]` / `opus[1m]` | 1M 上下文窗口 | 超长会话（Sonnet 5 本身已是 1M）|
| **`opusplan`** | **plan mode 用 opus，执行阶段自动切 sonnet** | **想「Opus 规划 + Sonnet 干活」自动化的最佳默认** |

来源为 [CC Docs: model-config](https://code.claude.com/docs/en/model-config)（官方，2026-06）✅。alias 解析到的具体版本随 provider 不同，例如在 Bedrock 上 `sonnet` 等于 Sonnet 4.5。

### `opusplan`：路由的一键最优解

`opusplan` 把本篇的核心决策自动化了：规划这种高价值、需要处理含糊需求的思考交给 Opus，代码生成这种机械执行交给 Sonnet。

```
/model opusplan
```

设好之后，进入 plan mode（连按两次 `Shift+Tab`，该键在权限档之间循环切换，见 [#031](../04-执行工作流/031-plan-execute-review循环.md)）时会用 Opus 出方案。你批准方案后，会自动切到 Sonnet 执行。

对于「既想省 Opus 额度、又想用它的规划能力」的人，这是推荐的默认设置，因为 Opus 只花在最该花的地方。（`opusplan` 的定义来自官方 alias ✅；「省 Opus 额度」这个动机属于社区共识 ⚠️。）

### SubAgent 按任务配模型

在 subagent 定义的 frontmatter 里显式指定模型，把苦力活压到 Haiku：

```markdown
---
name: test-runner
description: 跑测试并只回报失败项
model: haiku          # 高 token、低智力 → 用最便宜的
---
（system prompt……）
```

```markdown
---
name: data-analyst
description: 数据分析工作流
model: sonnet         # 需要真正理解 → 用 Sonnet，别 inherit 到 Opus
---
```

`model` 字段可选 `sonnet`、`opus`、`haiku`、`fable`、完整模型 ID 或 `inherit`，省略则默认 `inherit`，也就是跟随主会话。

这里有一个坑：如果主会话在用 Opus，那些没写 `model` 的 SubAgent 会全部继承 Opus，连苦力活都在烧 Opus。只有显式写 `model: haiku` 才省得下来（[CC Docs: sub-agents](https://code.claude.com/docs/en/sub-agents)，官方 ✅）。

> 内置的 `Explore` 子代理从 v2.1.198 起会继承主会话模型（API 上封顶到 Opus）。想强制它走便宜模型，可以自定义一个同样叫 `Explore` 的子代理，写上 `model: haiku` 来覆盖它（同上 ✅）。

### effort 是模型之外的第二个旋钮

除了换模型，你还有 effort 这个旋钮。简单任务降 effort 省钱，难任务升 effort 补「不够努力」，两者都比换模型来得轻。

需要注意的是，extended thinking（扩展思考，指让模型在回答前多想一段）产生的思考 token 是按 output 计费的，默认预算每个请求可达数万 token。简单任务可以用 `/effort` 降档，或在 `/config` 里关掉（[CC Docs: costs](https://code.claude.com/docs/en/costs) 与 [model-config](https://code.claude.com/docs/en/model-config)，官方 ✅；thinking 成本的专题超出本篇边界）。

## 横向对比

| 工具 | 模型路由机制 | 差异 |
|------|-------------|------|
| **Claude Code** | `/model`（含 `opusplan` 自动切）+ per-SubAgent `model` + effort 旋钮 | 路由粒度最细：会话级、阶段级（plan/execute）、子任务级三层都能独立配 |
| **Cursor** | 每次对话手动选模型（下拉），可混用 Anthropic/OpenAI/自带 key | 无「规划用贵的、执行用便宜的」自动切换；跨厂商是其强项 |
| **GitHub Copilot** | Chat/Agent 里手动选模型（含 Claude、GPT、Gemini） | 无 SubAgent 级路由；模型切换是全局对话级 |

核心差异在于自动化程度。Claude Code 用 `opusplan` 做阶段级自动路由，用 SubAgent 的 `model: haiku` 做子任务级路由，把「贵模型只花在刀刃上」做成了机制，而不是靠人每次手动记得切。Cursor 和 Copilot 更偏「手动单选加跨厂商灵活」。

## 反模式

- ❌ **把 Opus 设成常驻默认**。这是官方点名的高账单两大根因之一（另一个是长会话不清理）。默认应该是 Sonnet ✅。
- ❌ **一遇到错就升到 Opus/Fable**。要先分清是「不够懂」还是「不够努力」。很多情况是 effort 不够，升 effort 比升模型便宜（官方诊断问题）✅。
- ❌ **SubAgent 不写 `model` 就跑苦力活**。默认是 `inherit`，主会话在 Opus 时连跑测试都在烧 Opus。高 token、低智力的子任务要显式配 `model: haiku` ✅。
- ❌ **用 Fable 干日常活**。它单价约为 Sonnet 的 3.3 倍。官方定位是只有在「真的把其它模型逼到极限」的硬骨头上才用，不是默认 ✅。
- ❌ **以为「贵一定慢、一定亏」或「贵一定更划算」**。这两种都是单变量误判。贵模型可能 token 更省，也可能纯烧钱，取决于任务是不是真需要它的智力。按「不够懂 vs 不够努力」来判断 ✅。
- ❌ **在 Agent teams 里给每个队友都上 Opus**。teams 本就约 7 倍 token，队友用 Sonnet、收敛规模、干完即关 ✅。

## 延伸

**交叉引用：**
- [#060 额度怎么突然就没了？20x Max 也撑不过一上午——先算清自己一天该烧多少](./060-一天该烧多少额度.md) —— 模型选择是成本量级的主变量之一，本篇是它的「怎么选」侧。
- [#061 怎么少烧 token？prompt caching / 精简 CLAUDE.md / 模型切换哪个最有效？](./061-怎么少烧token.md) —— 「模型切换」是省 token 手段之一，本篇是它的深入；缓存和精简 CLAUDE.md 归 062。
- [#032 开几个 agent 并行跑，结果互相踩、被限流、token 指数级炸开——并行到底该开几个？](../04-执行工作流/032-SubAgent并行开几个.md) —— 决策侧；本篇补「派出去的 SubAgent 该配哪个模型」的成本侧。
- [#031 plan → execute → review 的正确循环怎么做？](../04-执行工作流/031-plan-execute-review循环.md) —— `opusplan` 正是在 plan/execute 边界上切模型。

**参考资料：**
- [Manage costs effectively — Claude Code Docs](https://code.claude.com/docs/en/costs) —— "Sonnet handles most coding tasks well"、"Reserve Opus for complex..."、"Opus left as the default model" 为高账单根因、agent teams ~7x、`model: haiku` for subagents（官方，2026-06）✅
- [Model configuration — Claude Code Docs](https://code.claude.com/docs/en/model-config) —— 全部 model alias 表、`opusplan`「opus during plan mode, then sonnet for execution」、各 provider alias 解析版本（官方，2026-06）✅
- [Create custom subagents — Claude Code Docs](https://code.claude.com/docs/en/sub-agents) —— `model` frontmatter（sonnet/opus/haiku/fable/inherit，默认 inherit）、"Control costs by routing tasks to faster, cheaper models like Haiku"、Explore 继承规则（官方，2026-06）✅
- [Choosing a Claude model and effort level in Claude Code — Anthropic Blog](https://claude.com/blog/claude-model-and-effort-level-in-claude-code) —— Sonnet「generalist」/ Opus「expert」/ Fable 定位、"know enough vs try hard enough" 诊断问题、effort 降级省钱（官方，2026）✅
- [Anthropic 模型定价（Opus 4.8 $5/$25、Sonnet 5 $3/$15、Haiku 4.5 $1/$5、Fable 5 $10/$50，每百万 token）](https://claude.com/pricing) —— 单价与倍率均以官方为准（官方，2026-06）✅
- [Is Opus 4.6 really worth it compared to sonnet? — r/ClaudeCode](https://www.reddit.com/r/ClaudeCode/comments/1rc6xpu/is_opus_46_really_worth_it_compared_to_sonnet/) —— 社区对「Opus 单价更高但 token 更省」的权衡讨论（社区，⚠️ 单源、仅标题级引用、未逐字核对正文）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
