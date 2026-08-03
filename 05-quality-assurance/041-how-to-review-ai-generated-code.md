# 041. AI 一次吐几百行 diff 我读不过来、让它自己 review 它只说自己写得好——怎么 review AI 生成的代码？

> 难度：中级
> 主题：质量保证
> 工具：Claude Code · 横向(Cursor / Copilot / …)
> 题型：流程题

> ⏰ 时效声明：本篇的命令、flag 与 gh + jq 门禁片段已于 **2026-08-03** 对照[官方 code-review 文档](https://code.claude.com/docs/en/code-review)逐条核实。注意一个刚变过的行为：**2026 年 7 月起 `@claude review` 不再订阅后续 push**，要订阅得用 `@claude review always`（官方文档明确标注了这次变更）。官方 Code Review 博客的三组数字（16%→54%、84% / 7.5 条、误报低于 1%）是**厂商对自家产品的自报效果数据**，没有第三方复现，看的时候按"厂商立场"打折。Cloudflare（48095 个 MR、288 次 break glass、0.6%）与 Uber uReview（75% 评论被标为有用）同样是各家自报的内部快照。四段人审工作流与 REVIEW.md 的七个 pattern 属方法论与官方机制，长期有效；`/code-review` 的子命令、flag、严重程度标记会随版本调整，请以官方文档为准。"要不要上机审"一节引用的 HN 两帖为社区观点与个人实测（2026-02 / 2026-05），其中 Copilot code review 吃 Actions 分钟数是 GitHub 2026-05 的计费变更，具体单价与是否仍如此请以 GitHub 官方计费文档为准。截至 2026-08，Code Review 托管服务仍是 research preview，仅 Team / Enterprise 可用，单次 review 官方标价 15–25 美元。

## TL;DR

[#040](./040-who-verifies-ai-code-and-how.md) 已经讲过：验证是一个多层体系，人审只是其中负责“拍板”的一环，任务是读 diff、设门禁、做最终决定。

但真坐到 AI 一次吐出几百行 diff 面前，那句定位就不够用了。你会遇到三个问题：读不过来、读完也不放心、让 AI 自己 review 又怕它自评太乐观。

本篇把“人审”这一环拆成一套可执行的四段工作流：

- **第一段，self-review（人自己读 diff 的方法）**：先读计划和 prompt 再读 diff；主动把 diff 改得更好读；AI 说“做完了”时要它拿出运行证据。
- **第二段，机审辅助**：用 Claude Code Review 按严重程度分流，用 REVIEW.md 定规则，其中“不该报什么”比“该报什么”更重要。
- **第三段，对抗机审**：派一个独立上下文的 reviewer 子 agent 来挑刺；跨模型、跨厂商互查；给 reviewer 分配专业角色。
- **第四段，门禁**：解析严重程度来卡 CI；人真正读懂 diff 才 merge；留一个应急放行口。

一句话划边界：机审是分流的闸门，不是最终裁判，拍板永远在人。体系全景见 [#040](./040-who-verifies-ai-code-and-how.md)，测试相关归 [#030](../04-execution-workflow/030-tdd-in-ai-coding.md)，幻觉 API 的查防见 [#042](./042-hallucinated-apis-and-dependencies.md)，改不对时何时停手见 [#043](./043-fix-loop-when-to-stop-debugging.md)。

---

## 为什么

### 1. 从 040 接过来，进到执行层面

040 把“验证”拆成了体系，并给“人审”下了一句定位：读 diff、设门禁、拍板。

但真面对一片 diff 时，这一句话不够用，有三个原因。第一，AI 的产出速度远超人的阅读速度。第二，“读完一遍”不等于“验证过”。第三，让 AI 自己 review（同一个上下文、同一个模型）会有确认偏误，也就是它倾向于认可自己刚写的东西。

所以本篇只挖“人审 + 机审辅助”这一环的具体做法，不再重复 040 的体系框架和组合决策。

### 2. review 为什么成了瓶颈

第一个原因很直接：AI 的产出速度远超人的阅读速度。

官方的 Code Review 博客给了明确数据：过去一年里，每个 Anthropic 工程师的代码产出增长了 200%，代码 review 因此成了瓶颈，很多 PR 只被草草扫一眼，而不是被认真读。

> "Code output per Anthropic engineer has grown **200%** in the last year. Code review has become a bottleneck… many PRs get **skims rather than deep reads**."
> —— [Anthropic Code Review 博客](https://claude.com/blog/code-review)（官方，2026-03）

人读大 diff 时的困境是什么样？HN 上一位每天要 review 大约 20 个 PR 的工程师描述得很直白：他要看 50 到 60 个文件，但根本记不住整个文件的上下文，因为改动都是分散的——中间三行、这里五行、结尾又四行。

> "I am looking at around 50-60 files, but I can't keep the context of the whole file because change I am looking is somewhere in the middle, 3 lines here, 5 lines there and another 4 lines at the end."
> —— [HN 47234917，@throwaw12](https://news.ycombinator.com/item?id=47234917)（社区，2026-02）

在这种速度差之下，人审会退化成盖橡皮图章式的走过场。这一点 040 已经论过，这里不重复。

结论是：review 本身成了瓶颈，所以需要一套执行层面的工作流——人审技巧、机审辅助、对抗机审、门禁——把人审从走过场里救出来。

### 3. “读完一遍”不等于“验证过”

从头读到尾并不等于 review，它有三个失效点。

第一，读不过来，前面的官方 200% 数据和 throwaw12 每天 20 个 PR 都说明了这点。第二，读完不等于读懂，改动分散导致上下文断裂。第三，让 AI 自己 review 会有确认偏误——聊天类模型会把整段对话史当成“既定事实”（这一点第三段会引 pyridines 展开）。

所以本篇的主交付物，就是用一套有方法的工作流，替代“从头读到尾”。

---

## 怎么做

本篇的核心交付：人审执行层面的四段工作流。

### 第一段：diff 太长读不过来时，人自己怎么读（self-review）

人审不该从 diff 开始读，而该从计划和 prompt 开始审。

**动作一：把 review 左移，先读计划/prompt 再读 diff。**

在 agent 大规模生成代码之前，先审它的计划、任务分解和关键 prompt。读 diff 时对照计划，看它是不是在实现你的意图，而不是只看代码“碰巧正确”。

tonybai 把这总结为“审查剧本，而不是审查表演”：在开发者大规模生成代码前，先审查其核心设计思路、任务分解和关键 prompt。来源见 [tonybai：AI 代码审查的危与机](https://tonybai.com/2025/12/27/code-review-hell-in-ai-age/)（社区权威，2025-12）。计划-执行-审查这个循环本身见 [#031](../04-execution-workflow/031-plan-execute-review-loop.md)。

具体审计划的哪几项、什么样算不合格，用这四条：

| 审什么 | 不合格的样子 | 不合格就做什么 |
|--------|--------------|----------------|
| 要改哪些文件 | 计划里没列文件清单，或列的文件跟你预期的模块对不上 | 让它先列出文件清单再动手 |
| 改动边界 | 出现"顺便重构一下 X""统一一下 Y"这类计划外扩张 | 砍掉扩张项，另开一个任务 |
| 验收标准 | 没写"怎么算做完"，或写成"代码能跑" | 要它写成可执行的命令，比如"`pytest tests/test_auth.py` 全绿" |
| 未知项 | 计划里对不确定的地方直接假设了一个答案，没标出来 | 让它把假设列成问题问你，别自己拍板 |

这四条里任何一条不合格，就退回改计划，别让它开始写。改完计划再写的成本，远低于读完 300 行 diff 才发现方向错了。

**动作二：主动把 diff 改得更好读。**

既然 review 成了瓶颈，就该让 diff 本身更好读。

> "You can use AI to make a reviewers job much easier. **Add documents, divide your MR into reviewable chunks**, et cetera. If reviewing is the expensive part now, **optimize for reviewability**."
> —— [HN 47234917，@bryanlarsen](https://news.ycombinator.com/item?id=47234917)（社区，2026-02）

上面这段的意思是：你可以用 AI 让审查者更轻松，比如补文档、把一个大 MR 拆成一块块可审的小块。既然现在审查是最贵的环节，就该为“好审”做优化。具体动作就是：把大 PR 拆成可独立看懂的小块，补上 PR 描述和设计文档。

**动作三：区分 AI-Go 区和 AI-No-Go 区。**

这也来自 tonybai。核心业务逻辑和安全相关代码属于 AI-No-Go 区，人审要重点盯；单元测试、文档、模板代码属于 AI-Go 区，可以轻审。

光记在脑子里没用，要在仓库里落成两处规则，一处管人、一处管机审。

**管人：`.github/CODEOWNERS`**，让 No-Go 区的改动强制拉上人。GitHub 的 CODEOWNERS 用 gitignore 风格的 glob，后面的规则覆盖前面的：

```
# .github/CODEOWNERS
# 默认：AI-Go 区，谁都能审
*                           @my-org/dev-team

# AI-No-Go 区：必须由对应 owner 审
/src/auth/                  @my-org/security
/src/billing/               @my-org/payments-leads
/migrations/                @my-org/dba
**/*.tf                     @my-org/platform
```

配完到 Settings → Branches 打开 "Require review from Code Owners"，否则 CODEOWNERS 只是加个建议 reviewer，不阻塞。验证方法：开一个只改 `src/auth/` 下文件的测试 PR，确认 PR 的 Reviewers 里自动出现 `@my-org/security`，且在他们 approve 前 merge 按钮是灰的。

**管机审：`REVIEW.md` 里给 Go 区降门槛。**官方支持按路径设不同的严格度，写法是直接用自然语言指路径：

```markdown
## 按路径调整严格度
- `src/auth/`、`src/billing/`、`migrations/`：AI-No-Go 区，
  任何行为改变都按 Important 报，宁可误报。
- `tests/`、`docs/`、`scripts/`：AI-Go 区，只在接近确定且严重时才报。
- `src/gen/`、`*.lock`：不报。
```

**动作四：AI 说“做完了”，先要运行证据。**

agent 报告“做完了”时，人 review 的第一步不该是读代码，而该是让它贴出运行证据。obra 的规则很硬：没有新鲜的验证证据，就不接受任何“完成”声明；先给证据，再谈完成；声称完成却没验证，是不诚实，不是效率。

> "**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE**… **Evidence before claims, always.** Claiming work is complete without verification is dishonesty, not efficiency."
> —— [obra：verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md)（社区权威，2026）

obra 还给了一份反面清单：“Bug 修好了”不算数——代码改了、就假设修好了，不够；“Agent 完成了”不算数——agent 自报成功，不够。也就是说，“改了代码就当修好”和“agent 自称成功”都不能算验证。

**动作五：读 diff 的具体顺序。**

1. 先看 commit message 或 PR 描述是否和计划匹配。不匹配就是意图漂移了，先去问 agent。
2. 按文件类别排优先级：安全、认证、数据库迁移这类文件先读。这来自 tonybai 的 AI-No-Go 区，以及 Cloudflare 的“安全敏感文件触发全面审查”。
3. 重点看被删掉的代码。agent 删测试、删边界检查是常见的偷懒方式，详见 [#030](../04-execution-workflow/030-tdd-in-ai-coding.md) 的 TDD 攻略。
4. 关注新增的 API 和依赖。AI 编造出不存在的包或 API 是一类高发错误，查防手法见 [#042](./042-hallucinated-apis-and-dependencies.md)。
5. 大 diff 先用 `/code-review` 在本地跑一遍筛出重点，这属于第二段。

### 第二段：机审报一堆噪音、开发者学会忽略——用严重程度分流 + REVIEW.md 定规则

机审的定位是分流的闸门，不是替人读。它负责找正确性问题，把人的注意力聚焦到真正重要的发现上。

**先决定要不要上：机审什么时候是净负担。**

上机审前先算一笔账，别默认"开着总没坏处"。HN 上一个标题就叫《AI 代码审查泡沫》的帖子（351 分 / 249 条评论，2026-02）把反方理由摆得很清楚，三条值得先看：

> "the **signal to noise ratio is poor**... in almost all cases, sufficient human attention would also have identified the critical bug—so **human attention is the primary bottleneck here**."
> —— [HN 46766961，@zmmmmm](https://news.ycombinator.com/item?id=46766961)（社区，2026-02）

意思是信噪比差，而且大多数情况下只要人看得够仔细同样能发现关键 bug，真正的瓶颈还是人的注意力。另一条来自 Greptile（做 AI code review 的创业公司）创始人 dakshgupta，是承认自家品类局限的话：LLM 不敢冒险把一个问题的严重程度判低，所以它没法有效过滤掉 nit。还有一条更直接：这些工具都缺上下文，给出的东西超不过 linter 已经能查的范围（@candiddevmike）。

再加一条钱的账。GitHub 在 2026-05 宣布 Copilot code review 开始吃 Actions 分钟数，HN 上那条讨论（312 分 / 207 条）里有两个具体数字：一个 30 万行代码的仓库上，单次 review 要跑 5 到 10 分钟（@psalaun）；而按 Actions 分钟数加 token 双重计费，实际成本追不清（@pando85）。也有人因为 review 从近乎即时变成要排队跑 Actions，把订阅退了（@mhitza）。

所以判断标准是这四条，命中任意一条就先别上，或者只在部分路径上开：

| 情况 | 为什么是净负担 |
|------|----------------|
| 团队每天 PR 量小、人本来就读得完 | 机审只是加了一层要人去分辨真假的噪音，瓶颈没被解开 |
| 你还没写 REVIEW.md 或等价的"不该报什么" | 默认配置下 nit 会淹掉 Important，开发者很快学会整片忽略 |
| CI 分钟数或 token 预算紧、PR 量大 | 5-10 分钟一次 × 每天几十个 PR，账单和排队时间都不小 |
| 仓库大部分是生成代码、配置、文档 | 机审在这些路径上几乎只产出风格意见 |

反过来，值得上的信号也很明确：PR 量已经大到人只能草草扫一眼；仓库里有安全、权限、迁移这类 AI-No-Go 区需要一层兜底；以及你愿意花时间调 REVIEW.md，把它当成一个需要维护的配置而不是开关。第一次上时按高流量仓库的做法来——触发模式设成手动，只对重要 PR 评 `@claude review`，跑两周看命中率再决定要不要全开。

Anthropic 给了一组数据：机审上线后，得到实质性 review 评论的 PR 从 16% 升到 54%；在大 PR 里，84% 有发现、平均每个 7.5 条；被标错的比例低于 1%。

先说立场：**这三个数字来自 Anthropic 自家博客，是厂商对自家产品的自报效果，测量口径（什么算"实质性评论"、误报由谁判定）没有公开，也没有第三方复现。**它能说明的是量级——机审确实能在人只草草扫一眼的地方补上一层，但"误报低于 1%"这种数字别当中立基准直接拿去说服团队。来源见 [Anthropic Code Review 博客](https://claude.com/blog/code-review)（厂商自报，2026-03）。下面 Cloudflare 和 Uber 的数字同理，都是各家自报的内部快照。

**它管什么。**

官方定调：Code Review 关注的是正确性——那些会让线上出故障的 bug，而不是格式偏好或测试覆盖缺失。它找的是逻辑错误、安全漏洞、被破坏的边界情况、隐蔽的回归。

> "Code Review focuses on **correctness**: bugs that would break production, not formatting preferences or missing test coverage"
> —— [Claude Code 文档：code-review](https://code.claude.com/docs/en/code-review)（官方，2026-06）

**怎么触发。**

下面这些命令来自官方文档，截至 2026-08 核实。

| 命令 | 干什么 |
|------|--------|
| PR 评论 `@claude review` | 单次 review，**不**订阅后续 push（2026-07 前它是订阅的，官方改了） |
| PR 评论 `@claude review always` | 开始 review，并订阅该 PR 后续每次 push |
| PR 评论 `@claude review once` | 与不带参数的 `@claude review` 完全相同，单次不订阅 |
| 本地 `/code-review` | 审当前分支领先 upstream 的提交加未提交改动，报正确性 bug 以及可复用、可简化、可提效的清理项 |
| `/code-review main...my-feature` | 审指定目标，可传文件路径、PR 号、分支名或 ref 区间 |
| `/code-review --comment` | 把发现贴成 PR 内联评论 |
| `/code-review --fix` | 审完后直接把修复应用到工作区 |
| `/code-review ultra --fix` | 跑云端更深度的 ultrareview，并应用修复 |

三个容易踩的点：评论命令必须发成 PR 顶层评论（不能是 diff 行上的内联评论），命令要放在评论开头；`@claude review` 这类托管服务只对 Team / Enterprise 开放，个人订阅只能用本地 `/code-review`；本地 `/code-review` **不读 REVIEW.md**（官方明确说明），REVIEW.md 只对 GitHub 上的托管 Code Review 生效，本地那条链路靠 CLAUDE.md。

**三档严重程度怎么读。**

下面三档同样来自官方文档。

| 标记 | 严重程度 | 含义 |
|------|----------|------|
| 🔴 | Important | 合并前应该修的 bug |
| 🟡 | Nit | 小问题，值得修但不阻塞 |
| 🟣 | Pre-existing | 代码库里本就存在、不是这个 PR 引入的 bug |

人审只聚焦 🔴 Important，🟡 Nit 批量扫一眼就行，🟣 Pre-existing 基本可忽略，因为不是这次引入的。

**用 REVIEW.md 定规则，“不该报什么”比“该报什么”更重要。**

官方的机制是：REVIEW.md 会作为最高优先级指令，被直接注入到 review 管道里的每一个 agent。官方给了七个调优 pattern：

- **重定义严重程度**：按仓库性质（后端、文档、原型）重新定义什么算 Important。
- **限制 nit 数量**：控制单次 review 报多少个 nit，比如最多报五个。
- **跳过规则**：跳过生成代码、lockfile、以及 CI 已经管的东西。
- **仓库专属检查**：加上每个 PR 都要查的规则，比如新 API 路由必须有集成测试。
- **验证门槛**：要求发现带上源码引用（`file:line`），砍掉靠猜的误报。
- **重审收敛**：第一轮之后，压住新的 nit，只报 Important，避免一行小修复被挑到第七轮还在挑风格。
- **摘要格式**：要求 review 正文以一行统计开头，比如 `2 factual, 4 style`；没有事实性问题时先说 “no factual issues”，好让作者先知道工作的整体情况再看细节。

工业界的共识是：跳过规则和报告规则同等重要。Cloudflare 说得很透——告诉 LLM 不做哪些事，才真正体现提示词工程的价值；没有这些限制，就会收到大量推测性的理论警告，开发者会立刻学会忽略它们。

> "事实证明，**告知 LLM 不做哪些事情才真正体现提示词工程的价值**。如果没有这些限制，会收到大量推测性理论警告，而开发人员会立即学会忽略它们。"
> —— [Cloudflare 博客](https://blog.cloudflare.com/zh-cn/ai-code-review/)（社区权威，2026-04）

Uber 的教训一致。它的 uReview 总结出的头条经验就是“精准比数量更重要”：开发者会很快对一个净生成低质量或无关建议的工具失去信心。

> "**Precision Is More Valuable than Volume**… Developers quickly lose confidence in a tool that generates low-quality or irrelevant suggestions"
> —— [Uber uReview 原帖](https://www.uber.com/blog/ureview/)（官方，2025-08）；中文读者可参 [tonybai 转述](https://tonybai.com/2025/12/27/code-review-hell-in-ai-age/)

**机审结果本身也要再过滤一遍。**

Uber 的 uReview 不是一个 prompt 出评论，而是多阶段流水线：Standard Assistant 找逻辑缺陷和 bug，Best Practices Assistant 看风格规范，AppSec Assistant 找安全漏洞；三个专业助理之后，再由 Review Grader 二次打分、过滤掉低置信度的评论，最后做语义去重、并抑制历史上被证明低价值的评论类型。

效果是：会和这个工具互动的工程师，把它 75% 的评论标为有用。来源见 [Uber uReview 原帖](https://www.uber.com/blog/ureview/)（2025-08，数据已复核）。

所以即使是机审，也要做机审的品控：人审聚焦高信噪比的正确性反馈，忽略文体说教。Uber 原帖明确说开发者不喜欢可读性和风格类评论——可读性挑剔、小的日志调整、低影响的性能优化、风格问题，评分都很差；而正确性 bug、缺失的错误处理、编码最佳实践的违规，评分都很好。

### 第三段：让 AI 自己 review，它只说自己写得好——换独立上下文 / 换模型

第二段的机审有个天花板：同一个上下文、同一个模型跑出来的机审，会有确认偏误。

赶时间的话，这一节只有五个动作，下面的引用是它们的依据：

| 做法 | 一句话动作 | 成本 |
|------|-----------|------|
| 独立上下文 reviewer | 开一个子 agent，只给它 diff + 验收标准，不给写代码那段对话 | 低，最先上 |
| 分配专业角色 | 给 reviewer 指定单一职责（安全 / 性能 / 质量），每个都写清"不该报什么" | 低 |
| 跨模型互查 | 把 diff 贴给另一家模型审一遍 | 中，手动复制粘贴 |
| 按风险分流 | 小改动用低 effort，碰安全文件才拉满 | 低 |
| 乒乓式结对 | 一个 agent 写测试、另一个只写让测试通过的实现 | 高，适合核心逻辑 |

**为什么需要对抗机审。**

写代码的 agent 倾向于说自己写得好。HN 上 hex4def6 建议：另派一个 reviewer agent，目标就是挑剔地审这段代码；结果通常会比问那个写代码的 agent 好得多——后者只会向你保证代码“已充分测试、可上生产”。

> "task a code reviewer agent with the goal of **critically examining the code**. The results will normally be much better than asking the coder agent who will assure you it's 'fully tested and production ready'."
> —— [HN 47234917，@hex4def6](https://news.ycombinator.com/item?id=47234917)（社区，2026-02）

pyridines 解释了为什么独立上下文的 reviewer 更敢挑刺：一个“视角全新”的 agent，也就是没有“被告知要写什么、然后写了它”这段经历的 agent，会有不同的视角、更能批判。聊天类模型会把之前整段对话史当成一种“权威真相”，去掉这段历史，就能去掉这种偏向。

> "an agent with '**fresh eyes**', i.e., without the context of being told what to write and writing it, does have a different perspective and is able to be more critical. Chatbots tend to take the entire previous conversational history as a sort of **canonical truth**, so removing it seems to get rid of any bias…"
> —— [HN 47234917，@pyridines](https://news.ycombinator.com/item?id=47234917)（社区，2026-02）

**做法一：派一个独立上下文的 reviewer 子 agent。**

派一个独立上下文的 reviewer 子 agent，只给它 diff 加验收标准，让它挑刺。子 agent 的机制归 [#032](../04-execution-workflow/032-subagent-when-and-how.md)。关键是：写代码的 agent 不能等于评分的 agent。

HN 上 ojo-rojo 描述的模式是：后续用一个独立的 agent 去分析原始 issue 和产出的代码，只有当代码满足 issue 的意图时才批准。来源见 [HN 47234917，@ojo-rojo](https://news.ycombinator.com/item?id=47234917)。

**做法二：给 reviewer 分配专业角色。**

Cloudflare 上线了多达七个专业审查器，分别负责安全、性能、代码质量、文档、发布管理和合规，再由一个协调器对这些结果做去重、判断问题的实际严重程度。来源见 [Cloudflare 博客](https://blog.cloudflare.com/zh-cn/ai-code-review/)。

你能复刻的最小版本，是给 reviewer 子 agent 配角色：一个盯安全、一个盯性能、一个盯质量。每个角色都要带上“该报什么、不该报什么”。Cloudflare 的安全 reviewer 示例就规定：不报理论风险、不报未改动的代码、不报“考虑用某个库”这类建议。

**做法三：跨模型、跨厂商互查。**

用另一个模型来 review，可以突破单模型的训练盲区。

> "IME it works even better if you use another model for review. **We've seen code by cc and review by gpt5.2/3 work very well.**"
> —— [HN 47234917，@NitpickLawyer](https://news.ycombinator.com/item?id=47234917)

> "I routinely **copy/paste code from Claude to ChatGPT and Gemini have them check each other's code**. This works very well."
> —— [HN 47234917，@lateforwork](https://news.ycombinator.com/item?id=47234917)

上面两段的意思分别是：用另一个模型来 review 效果更好，Claude Code 写、GPT 审的组合很好用；以及经常把 Claude 的代码复制粘贴到 ChatGPT 和 Gemini，让它们互查，效果也很好。Claude Code 原生支持多 agent（官方称之为“一队专门 agent”），而跨模型互查目前靠人手动复制粘贴——成本是手动，收益是突破同模型盲区。

**做法四：按风险等级分流。**

Cloudflare 的做法是按 diff 规模调 reviewer 数量和模型：10 行以内用 2 个 agent、协调器降级到 Sonnet，100 行以内用 4 个，超过 100 行或涉及安全敏感文件用 7 个以上并用 Opus 协调。

**但这套参数你抄不了**——托管的 Claude Code Review 没有"配置 reviewer 数量"这个旋钮，那是 Cloudflare 自建流水线里的调度逻辑。放在这里只是说明思路：别派精英队去审一个错别字。

你手上真能拧的等价旋钮有两个，都在本地 `/code-review`：

```bash
# 小改动：低 effort，只报最有把握的，误报少、快
/code-review low

# 大改动或碰了安全敏感文件：拉高 effort，撒更大的网
/code-review max

# 真正重要的分支：走云端 ultrareview（更贵更深）
/code-review ultra --fix
```

官方对 effort 的说明是：`low` 和 `medium` 只报最有把握的发现，误报更少；`high` 到 `max` 撒更大的网，可能包含它不太确定的发现。不传 effort 就沿用当前会话的 effort。至于托管服务这侧，能拧的只有每个仓库的触发模式（每次 push / 建 PR 时一次 / 手动），高流量仓库设成手动、只对重要 PR 评 `@claude review`，就是最实用的那档分流——顺带也是省钱手段，官方标价单次 review 15–25 美元（2026-08）。

**做法五：乒乓式结对。**

HN 上 turlockmike 的模式：第一步，一个 agent 按 spec 写一个最小的测试；第二步，另一个 agent 只写刚好能让测试通过的最小实现；重复。

> "1. Agent writes a minimal test against a spec. 2. Another agent writes minimal implementation to make test pass only. Repeat."
> —— [HN 47234917，@turlockmike](https://news.ycombinator.com/item?id=47234917)

两个 agent 互不共享上下文，机制指针见 [#032](../04-execution-workflow/032-subagent-when-and-how.md)。

### 第四段：机审不阻塞合并，怎么把它变成真门禁（CI 卡严重程度 + 应急放行）

**机审不阻塞 PR，人用严重程度设 CI 门禁。**

官方明确：check run 总是以“中性结论”结束，所以它永远不会通过分支保护规则阻塞合并。如果你想用 Code Review 的发现来卡合并，就自己在 CI 里读 check run 输出的严重程度统计。

> "always completes with a **neutral conclusion** so it never blocks merging through branch protection rules. If you want to gate merges on Code Review findings, read the severity breakdown from the check run output in your own CI"
> —— [Claude Code 文档：code-review](https://code.claude.com/docs/en/code-review)

check run 的 Details 正文最后一行是一段机器可读的注释，里面带 `bughunter-severity: {...}`。官方给的解析方式是两步：先列出这个 commit 的所有 check run 拿到 ID，再用 `gh` 加 `jq` 把那段 JSON 抠出来。返回形如 `{"normal": 2, "nit": 1, "pre_existing": 0}`，其中 `normal` 是 Important 发现的数量，非零就意味着 Claude 找到了至少一个合并前值得修的 bug。

**手动跑一遍（先在本地确认能取到值）。** 把 `OWNER`/`REPO`/commit sha 换成你自己的：

```bash
OWNER=my-org
REPO=my-service
SHA=$(git rev-parse HEAD)

# 第一步：找到 Claude Code Review 这条 check run 的 id
CHECK_RUN_ID=$(gh api "repos/$OWNER/$REPO/commits/$SHA/check-runs" \
  --jq '.check_runs[] | select(.name == "Claude Code Review") | .id')
echo "check run id = $CHECK_RUN_ID"

# 第二步：解析严重程度统计
gh api "repos/$OWNER/$REPO/check-runs/$CHECK_RUN_ID" \
  --jq '.output.text | split("bughunter-severity: ")[1] | split(" -->")[0] | fromjson'
```

预期输出类似：

```
check run id = 41234567890
{
  "normal": 2,
  "nit": 1,
  "pre_existing": 0
}
```

如果第一步 `CHECK_RUN_ID` 是空的，说明这个 commit 上还没跑过 Code Review（review 平均要 20 分钟），或者仓库没开这个服务，别急着往 CI 里塞。

**做成 GitHub Actions 门禁。** 下面这个 job 轮询等 review 出结果，然后 `normal` 非 0 就让 CI 变红：

```yaml
name: Code Review Gate

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  gate:
    runs-on: ubuntu-latest
    permissions:
      checks: read
      pull-requests: read
    steps:
      - name: Wait for Claude Code Review and gate on Important findings
        env:
          GH_TOKEN: ${{ github.token }}
          OWNER_REPO: ${{ github.repository }}
          SHA: ${{ github.event.pull_request.head.sha }}
        run: |
          set -euo pipefail

          # 最多等 30 分钟（官方说单次 review 平均 20 分钟）
          for i in $(seq 1 60); do
            RUN=$(gh api "repos/$OWNER_REPO/commits/$SHA/check-runs" \
              --jq '.check_runs[] | select(.name == "Claude Code Review") | select(.status == "completed") | .id' \
              | head -n 1)
            if [ -n "$RUN" ]; then break; fi
            echo "waiting for Claude Code Review... ($i/60)"
            sleep 30
          done

          if [ -z "${RUN:-}" ]; then
            echo "::warning::Code Review 没有在 30 分钟内完成，本次不阻塞（review 是 best-effort，不会自动重试）"
            exit 0
          fi

          SEVERITY=$(gh api "repos/$OWNER_REPO/check-runs/$RUN" \
            --jq '.output.text | split("bughunter-severity: ")[1] | split(" -->")[0] | fromjson')
          echo "severity breakdown: $SEVERITY"

          IMPORTANT=$(echo "$SEVERITY" | jq -r '.normal')
          if [ "$IMPORTANT" -gt 0 ]; then
            echo "::error::Claude Code Review 报了 $IMPORTANT 个 Important 发现，修完再合"
            exit 1
          fi
          echo "no Important findings"
```

两点说明。第一，官方明确 review 运行是 best-effort、失败不会自动重试，所以超时这条分支要 fail open（`exit 0`），否则基础设施抖一下就把所有 PR 卡死。第二，要真正阻塞合并，还得去仓库 Settings → Branches 把这个 job 加进 required status checks，光让它变红不够。

**怎么判断做对了。** 开一个测试 PR，故意塞一个明显的逻辑 bug（比如把权限判断的 `if (!user.isAdmin)` 写成 `if (user.isAdmin)`，或者把边界条件的 `<=` 改成 `<` 导致越界）。等 Claude Code Review 跑完，看两处：check run 的 Details 里出现 🔴 Important，而这个 gate job 失败并打印 `Claude Code Review 报了 1 个 Important 发现`。然后把这个 bug 改回来推一次，重跑，确认输出变成 `severity breakdown: {"normal":0,...}` 且 job 变绿。两次都符合预期，门禁才算真的接上了；只看到 job 一直绿，很可能是 `CHECK_RUN_ID` 压根没取到，走了 fail open 那条分支。

**让机审先打分，人只看低分。**

HN 上 MrDarcy 的做法：让 Claude Code 做 review 并给一个质量评分（比如按等级打分），然后连 C 级及以下的工作都不用去看。

> "have Claude Code do the code review and **assign a quality score, call it a grade**… then **don't even bother looking at C work or below**."
> —— [HN 47234917，@MrDarcy](https://news.ycombinator.com/item?id=47234917)（社区，2026-02）

机审做闸门、人聚焦高风险，就是把有限的人审精力投到机审打了低分的 diff 上。

**人真正读懂 diff 才 merge。**

官方博客说：它不会批准 PR，那仍然是人的决定。

> "**It won't approve PRs — that's still a human call**"
> —— [Anthropic Code Review 博客](https://claude.com/blog/code-review)

机审抓不到架构意图和跨系统副作用，这些归人审。Cloudflare 也坦诚了自身局限：架构意识、跨系统影响、微妙的并发错误，以及成本会随 diff 大小上升。来源见 [Cloudflare 博客](https://blog.cloudflare.com/zh-cn/ai-code-review/)。谁负责的底色 040 已经讲过，这里不重复。

**留一个应急放行口。**

这也是 Cloudflare 的做法：热修复场景下，人可以 override 机审。如果真人审查者加了 `break glass` 注释，系统会强制批准，无论 AI 发现了什么。

> 来源：[Cloudflare 博客](https://blog.cloudflare.com/zh-cn/ai-code-review/)

不过遥测会跟踪它，避免被滥用。Cloudflare 的数据佐证了这点：前 30 天的 48095 个 MR 里，只用了 288 次 break glass，占 0.6%，说明这个应急口没被滥用。

---

## Claude Code 实战

这里给两样东西：一个“同一个 diff 走完四段工作流”的导览示例，以及一个可以直接抄的 REVIEW.md 模板。

### 导览：review 一个 agent 生成的 PR（给 UserService 加权限校验，约 200 行）

| 段 | 动作 | 看什么 |
|----|------|--------|
| self-review | 先读 agent 的计划/prompt | diff 是否实现了“加权限校验”的意图，而不是只看代码碰巧正确 |
| self-review | 按文件类别读 | 认证和权限文件先读；重点看被删的边界检查、新增的 API |
| self-review | 要 agent 贴运行证据 | 不信“我做完了”，要测试输出或命令返回（obra） |
| 机审辅助 | 在 PR 上 `@claude review` | 看严重程度表：2 个 🔴 Important（认证竞态 + 缺租户隔离） |
| 机审辅助 | 看 REVIEW.md 是否覆盖 | 已配“新 API 路由必须有集成测试”，命中了缺租户隔离 |
| 对抗机审 | 派独立上下文的 reviewer 子 agent | 只给 diff 加验收标准，独立上下文挑刺（032 机制） |
| 对抗机审 | 跨模型互查 | 把 diff 贴给 GPT 审一遍，突破单模型盲区 |
| 门禁 | gh 加 jq 解析严重程度 | 跑上面那段 CI，`normal` 非 0 就让 agent 修，然后重审 |
| 门禁 | 人读懂 diff 才 merge | Important 全清零、且人读懂每一处改动，才 merge |

### REVIEW.md 最小模板（可直接抄）

下面这版综合了官方文档的完整示例，以及 Cloudflare 和 Uber 的工业级实践。内容全部来自官方 code-review 文档的七个 pattern，可以直接复制到仓库根目录再改：

```markdown
# Review instructions

## What Important means here
Reserve Important for findings that would break behavior, leak data,
or block a rollback: incorrect logic, unscoped database queries, PII
in logs or error messages, and migrations that aren't backward
compatible. Style, naming, and refactoring suggestions are Nit at
most.

## Cap the nits
Report at most five Nits per review. If you found more, say "plus N
similar items" in the summary instead of posting them inline. If
everything you found is a Nit, lead the summary with "No blocking
issues."

## Do not report
- Anything CI already enforces: lint, formatting, type errors
- Generated files under `src/gen/` and any `*.lock` file
- Test-only code that intentionally violates production rules

## Always check
- New API routes have an integration test
- Log lines don't include email addresses, user IDs, or request bodies
- Database queries are scoped to the caller's tenant

## Re-review behavior
After the first review, suppress new nits and post Important findings only.

## Verification bar
Behavior claims need a `file:line` citation in the source, not an
inference from naming.

## Summary shape
Open the review body with a one-line tally such as `2 factual, 4 style`.
If there are no factual issues, lead with "no factual issues."
```

上面模板的七段，正好对应七个 pattern：重定义严重程度（What Important means here）、限制 nit 数量（Cap the nits）、跳过规则（Do not report）、仓库专属检查（Always check）、重审收敛（Re-review behavior）、验证门槛（Verification bar）、摘要格式（Summary shape）。每一段都来自官方 code-review 文档，可按自己仓库改。

两个前置条件别搞错：文件必须放在**仓库根目录**、文件名就是 `REVIEW.md`；它是**逐字粘贴**进 review agent 的系统提示的，所以 `@` 导入语法不会展开，被引用的文件也不会被读进去，规则得直接写在文件里。另外它只对 GitHub 上的托管 Code Review 生效，本地 `/code-review` 不读它。

**怎么判断它真的生效了。**分三条各自验证，别只看"感觉安静了"：

1. **确认被读到**。在 `REVIEW.md` 末尾临时加一行：`## Summary shape` 段里要求 `Open the review body with the exact prefix "[REVIEW.md active]"`。然后开一个测试 PR 评 `@claude review`，看 review 正文第一行是不是那个前缀。有 → 文件被注入了；没有 → 检查文件是不是在根目录、仓库有没有在 admin settings 里被勾上。验完把这行删掉。
2. **确认 nit 上限生效**。找一个改动大、风格问题多的 PR（比如批量重命名），跑一次 review，数 🟡 Nit 的内联评论条数。应该 ≤ 5，且摘要里出现 "plus N similar items"。超过 5 条说明这条规则被淹没了——通常是 `REVIEW.md` 太长，官方明确说长文件会稀释重要规则，删到只剩改变行为的指令。
3. **确认跳过规则生效**。故意在 `src/gen/` 下（或你自己的生成目录）改一个明显有问题的地方推上去，确认 review 对这个文件一条评论都没有。如果还在报，多半是路径写法和仓库实际目录对不上，把 glob 换成实际相对路径再试。

前后对比也值得记一笔：配 `REVIEW.md` 之前先跑一次 review 记下评论条数和 Important / Nit 比例，配完再跑一次同类 PR，Nit 明显下降、Important 没被误杀，才算调对了。

---

## 横向对比

这里只回答一个执行层面的问题：别的工具有没有对应物？有。Cursor 有 Cursor Bot review，GitHub 有 Copilot review，各厂也有各自的 SAST 静态安全扫描工具。

核心差异在“多 agent 编队加跨模型互查”。Claude Code 原生支持多 agent（官方称之为“一队专门 agent”），而跨模型互查靠人手动复制粘贴（见 @lateforwork）。更详细的机审工具生态对比不在本篇范围，且变化很快，请以各家官方文档为准。

---

## 反模式（review 策略的误用）

- ❌ **把“review”等同于“从头读到尾”**。人根本读不过来（官方 200%、throwaw12 每天 20 个 PR）。应该左移读计划、拆小块、机审分流。
- ❌ **让写代码的 agent 自己 review（同上下文同模型）**。会有确认偏误（pyridines 说它把历史当权威真相，hex4def6 说它只会向你保证已充分测试）。应该用独立上下文的 reviewer 子 agent 或跨模型。
- ❌ **不算账就把机审全仓打开**。PR 量本来就读得完、或者还没写"不该报什么"就开，只是加了一层噪音；Copilot review 改成吃 Actions 分钟数后，30 万行仓库单次要跑 5-10 分钟，成本也要算进去。先手动触发跑两周看命中率。
- ❌ **REVIEW.md 只写“该报什么”、不写“不该报什么”**。噪音会摧毁信任（Cloudflare 说开发者会立刻学会忽略、Uber 说充满噪音的建议会迅速摧毁信任）。
- ❌ **把机审当最终裁判、全权交给它**。官方说它不批准也不阻塞 PR、结论是中性的；机审是辅助信号，拍板在人。
- ❌ **机审说没问题就 merge、人不读 diff**。官方说它不会批准 PR、那仍是人的决定；机审抓不到架构意图和跨系统副作用（Cloudflare 已坦诚这些局限）。
- ❌ **信 AI 的“我修好了 / 做完了”就放过 review**。obra 的规则是没有新鲜验证证据就不接受完成声明，要拿运行证据。
- ❌ **review 发现问题、让 agent 改、越改越糟还硬撑**。这是另一个问题，属于调试侧何时停手，见 [#043](./043-fix-loop-when-to-stop-debugging.md)，不是 review 策略本身的问题。
- ❌ **把文体说教当成 review 的价值**。Uber 说开发者讨厌文体说教，review 应聚焦正确性、bug、最佳实践这类高信噪比反馈。

---

## 延伸

**交叉引用：**
- [#040 AI 说"做完了"、测试也全绿，怎么知道代码是真的对？](./040-who-verifies-ai-code-and-how.md) —— 验证体系总览，本篇是其中“人审”一环的执行层面深入，必引。
- [#030 TDD 在 AI coding 里怎么做？](../04-execution-workflow/030-tdd-in-ai-coding.md) —— 测试作为验证手段的攻略，本篇不碰 TDD 的红绿循环。
- [#031 plan → execute → review 的正确循环怎么做？](../04-execution-workflow/031-plan-execute-review-loop.md) —— 本篇 self-review 段“先读计划”对应的循环指针。
- [#032 开几个 agent 并行跑，结果互相踩、被限流、token 指数级炸开——并行到底该开几个？](../04-execution-workflow/032-subagent-when-and-how.md) —— 本篇对抗机审段“独立上下文 reviewer 子 agent、乒乓式结对”的机制指针，必引。
- [#042 AI 写的方法不存在、pip install 报 404、API 参数对不上——幻觉 API 和幻觉依赖怎么查、怎么防？](./042-hallucinated-apis-and-dependencies.md) —— 本篇 self-review 段“新 API、新依赖”一项的攻略指针（类型、lint、schema 手法）。
- [#043 AI 改不对 bug、陷入 fix loop / 越改越糟，什么时候必须停、怎么跳出？](./043-fix-loop-when-to-stop-debugging.md) —— 本篇反模式段的指针，讲跳出改不动的循环。
- [#053 AI 生成的 PR 太大太多，review 机制怎么扛住不崩？](../06-engineering-collab/053-ai-prs-too-large-to-review.md) —— 本篇讲单个 PR 怎么审，053 讲 PR 又大又多时 review 机制怎么扛住。

**参考资料：**
- [Code Review - Claude Code 文档](https://code.claude.com/docs/en/code-review) —— REVIEW.md 七个 pattern 与放置规则、三档严重程度、gh 加 jq 解析 `bughunter-severity`、`@claude review` / `always` / `once` 的区别、`/code-review` 的 flag 与 effort、中性结论、定价（官方，2026-08-03 核实）
- [Bringing Code Review to Claude Code](https://claude.com/blog/code-review) —— 200% / 只草草扫 / 16% 升 54% / 84% / 7.5 / 低于 1% / “它不会批准 PR，那仍是人的决定”（**厂商自报效果数据**，官方博客，2026-03）
- [GitHub 官方文档：About code owners](https://docs.github.com/en/repositories/managing-your-repositories-settings-and-features/customizing-your-repository/about-code-owners) —— CODEOWNERS 的 glob 语法与"后写覆盖先写"规则，本篇 AI-No-Go 区落地用（官方）
- [obra：verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md) —— “没有新鲜验证证据就不接受完成声明”加常见失效清单（社区权威，2026）
- [HN：When AI writes the software, who verifies it?](https://news.ycombinator.com/item?id=47234917) —— pyridines（视角全新）/ hex4def6（挑剔地审）/ MrDarcy（质量评分）/ NitpickLawyer 与 lateforwork（跨模型）/ turlockmike（乒乓）/ bryanlarsen（为好审做优化）/ throwaw12（每天 20 个 PR）/ ojo-rojo（后续独立审）（社区，2026-02）
- [HN：There is an AI Code Review Bubble](https://news.ycombinator.com/item?id=46766961) —— 机审值不值得上的反方：zmmmmm（信噪比差、人的注意力才是瓶颈）/ dakshgupta（LLM 不敢降级严重程度、过滤不掉 nit）/ candiddevmike（缺上下文、超不过 linter）（社区，2026-02）
- [HN：GitHub Copilot code review will start consuming GitHub Actions minutes](https://news.ycombinator.com/item?id=47932028) —— 机审的成本账：psalaun（30 万行仓库单次 review 5-10 分钟）/ pando85（分钟数加 token 双重计费追不清）/ mhitza（变慢后退订）（社区，2026-05）
- [Cloudflare：大规模编排 AI 代码审查](https://blog.cloudflare.com/zh-cn/ai-code-review/) —— 七个专业 reviewer / “不该 flag 什么” / 风险等级 / break glass / 坦诚局限（社区权威，2026-04）
- [Uber：uReview](https://www.uber.com/blog/ureview/) —— 75% 有用 / 三专业助理加 Review Grader / 场内教训（官方，2025-08，数据已复核原帖）
- [tonybai：AI 代码审查的危与机](https://tonybai.com/2025/12/27/code-review-hell-in-ai-age/) —— 代码导演 / 审查左移 / AI-Go 与 AI-No-Go / Uber 场内教训的中文转述（社区权威，2025-12）

> 本篇个人实践（L4）：`[待补：BOSS 的 review 工作流实际怎么走 / REVIEW.md 写了什么 / 用没用跨模型互查 / 哪段最先上哪段最后才加]`
