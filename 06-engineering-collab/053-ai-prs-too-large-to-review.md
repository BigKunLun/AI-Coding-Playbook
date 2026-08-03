# 053. AI 生成的 PR 太大太多，review 机制怎么扛住不崩？

> 难度：中级
> 主题：工程协作
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：流程题 + 治理

> ⏰ 时效声明：本篇的定价与机制事实（机审每次 15-25 美元、三种触发模式的计费方式、机审结论为 neutral 不拦截合并、`REVIEW.md` 逐字注入且优先级最高、用 `gh + jq` 解析严重度）已于 **2026-07-18** 对照官方 [code-review 文档](https://code.claude.com/docs/en/code-review)核实无误。Salesforce 的全部引文（代码量 +30%、单个 PR 超 20 文件/1000 行、最大 PR 的 review 时间见顶）同日对照原文确认。注意 Code Review 目前是 research preview（预览版，面向 Team/Enterprise 订阅），定价和形态可能随正式发布调整。
> 开源侧事实（curl 关停赏金的年限/金额/比例、2026-01 的 16 小时 7 份提交、tldraw 自动关闭外部 PR 及 Steve Ruiz 引文、Ghostty 永久封禁、Stefan Prodan 的 DDoS 引文）已于 **2026-08-03** 对照 [RedMonk 原文](https://redmonk.com/kholterhoff/2026/02/03/ai-slopageddon-and-the-oss-maintainers/)核实。tldraw 的暂停是维护者自述的临时措施，当前是否仍生效请自行确认。

## TL;DR

AI 让写代码快了几倍，但 review 没跟着变快。原因很简单：review 这道质量门靠的是人的带宽，而人的带宽没变。

结果就是 PR 越堆越大、越堆越多，reviewer 开始机械地点 approve。

Salesforce 的数据坐实了这个失效模式：引入 AI 后代码量涨约 30%，单个 PR 常常超过 20 个文件、1000 行改动。更糟的是，最大那批 PR 的 review 时间不升反降。这不是审得更快了，而是 reviewer 已经不再真正参与（[Salesforce Eng](https://engineering.salesforce.com/scaling-code-reviews-adapting-to-a-surge-in-ai-generated-code/)，2026）。

要扛住不崩，靠四件事叠加，不是四选一：

1. **控住 PR 体积**：从源头把「大而杂」拆成「小而聚焦」，让人还审得动。这是生产者一侧的治理。
2. **上 AI review 当第一道分流**：机审先跑一遍，把明显问题挡在人审之前。但它只是辅助信号，不拦截 PR，最终拍板的仍是人（[CC Docs: code-review](https://code.claude.com/docs/en/code-review)，官方，2026-06）。
3. **重构 review 流程本身**：保留代码结构、按风险分层、逐步展开，别再让人对着 1000 行平铺的 diff 硬看（Salesforce / Cloudflare 实践）。
4. **定治理规则**：谁验证、谁背锅、AI PR 要不要声明、能不能把第一遍 review 甩给别人。Kubernetes 直接把「大型 AI 生成 PR」写进了禁令（[K8s PR Process](https://www.kubernetes.dev/docs/guide/pull-requests/)，官方政策，2026）。

一句话划清边界：本篇讲团队级 review 这道质量门在 AI 冲击下怎么不崩。想看「谁来验证、验证分几层」的体系框架，见 [#040](../05-quality-assurance/040-who-verifies-ai-code-and-how.md)。想看「一个人怎么审 AI 代码」的技巧，见 [#041](../05-quality-assurance/041-how-to-review-ai-generated-code.md)。想看 git 提交流程（分支、commit、PR 怎么开），见 [#052](./052-git-workflow-with-ai.md)。

## 为什么

### 1. 瓶颈从「写」搬到了「审」

传统 review 有一个隐含前提：代码产出速度和人审速度大致匹配。一个人一天写几百行，另一个人一天审得完。

AI 把「写」加速了几倍，但「审」还是靠人的眼睛和脑子。供需一下子失衡了。

Salesforce 工程团队量化了这个失衡。引入 AI 编码后，代码量增加约 30%，单个 PR 经常膨胀到超过 20 个文件、1000 行改动，review 的排队时间逐季度上升（[Salesforce Eng](https://engineering.salesforce.com/scaling-code-reviews-adapting-to-a-surge-in-ai-generated-code/)，2026）。

### 2. 最危险的信号：review 时间「不升反降」

最扎心的发现不是排队时间上升，而是最大的 PR 反而审得更快了。

> "review time for the largest pull requests began to plateau — or even decline. This indicated that reviewers were no longer meaningfully engaging with changes."
>
> 大意：最大那批 PR 的 review 时间开始见顶，甚至下降。这说明 reviewer 已经不再真正参与这些改动。
>
> —（[Salesforce Eng](https://engineering.salesforce.com/scaling-code-reviews-adapting-to-a-surge-in-ai-generated-code/)，2026）

PR 越大，本该审得越久。结果最大的 PR 审得反而更快。唯一说得通的解释是：reviewer 面对 1000 行 diff 直接放弃了，滑到底点 approve。

这就是 [#040](../05-quality-assurance/040-who-verifies-ai-code-and-how.md) 里说的 rubber stamp（橡皮图章，指审查只走个形式、不真看内容）。人审这一层名义上还在，实际已经塌了。Salesforce 的原话是，规模化之下，信任、安全、技术严谨这些核心价值越来越难保证。

### 3. 开源侧是同一个病，但症状更极端

企业内部至少 PR 作者是同事，跑得掉、找得到人。开源维护者面对的是陌生人批量投喂的 AI PR 和 issue。

开发者 Andi McClure 把这类贡献称为「既浪费我的时间，又违反了我项目的行为准则」（both a waste of my time and a violation of my projects' code of conduct）。她预言，过滤 AI 生成的 issue 和 PR 会成为维护者额外的负担，甚至打算引入一种「口头 CAPTCHA」来筛人（[Socket](https://socket.dev/blog/oss-maintainers-demand-ability-to-block-copilot-generated-issues-and-prs)，社区，2025-05）。

curl 项目也吃过亏。在收到一份 AI 生成的假漏洞报告后，它直接改了文档，要求贡献者声明自己是否用了 AI 工具（同上）。

到 2026 年初，这条路已经走到尽头。curl 关掉了跑了六年、累计发出 8.6 万美元的漏洞赏金计划：2025 年中期约 20% 的提交是 AI 垃圾，全年只有 5% 的提交真的指出了漏洞；2026 年 1 月更是在 16 小时内涌进 7 份提交，里面有真 bug，但没有一个是真漏洞。Daniel Stenberg 早在 2025 年 5 月就加了「是否使用 AI」的声明勾选框，结果没起作用（[RedMonk](https://redmonk.com/kholterhoff/2026/02/03/ai-slopageddon-and-the-oss-maintainers/)，社区，2026-02）。

同一时期 tldraw 的做法更极端：创始人 Steve Ruiz 宣布自动关闭全部外部 PR，等到「GitHub 提供更好的贡献管理工具」为止。他还点出了一个循环——自己用 AI 脚本生成的低质量 issue，被贡献者喂给他们自己的 AI，变成低质量 PR，「AI 把两头的活都干了」（My low-effort issues were becoming low-effort pull requests, with AI doing both sides of the work）。Ghostty 则在 2026 年 1 月底立了零容忍规则：未经邀请提交 AI 生成内容的人，永久封禁（同上）。

Flux 维护者 Stefan Prodan 的一句话概括了这个局面：AI 垃圾正在 DDoS 开源维护者，而托管开源项目的平台没有动力去阻止（AI slop is DDOSing OSS maintainers, and the platforms hosting OSS projects have no incentive to stop it）（同上）。

对企业团队来说，这段的意义不是围观。开源维护者只是先撞上了同一堵墙：当提交量的增长不受成本约束时，评审侧一定会先崩。企业内部之所以还撑得住，只是因为工位和绩效构成了天然的提交限流。

### 4. 为什么「多加一个 AI reviewer」不能单独解决

直觉是：人审不过来，那就让 AI 来审。方向对，但有个硬边界——AI review 天生就不是门禁。

官方对 Claude Code Review 的定位很明确：

> "Findings are tagged by severity and don't approve or block your PR... The check run always completes with a neutral conclusion so it never blocks merging through branch protection rules."
>
> 大意：发现的问题按严重度打标签，但既不批准也不拦截你的 PR。检查始终以 neutral（中性）结论结束，所以它永远不会通过分支保护规则挡住合并。
>
> —（[CC Docs: code-review](https://code.claude.com/docs/en/code-review)，官方，2026-06）

也就是说，机审只产出「信号」，不产出「放行还是拦截」的决定。

Cloudflare 把话说得更直白：这不是人工 review 的替代品，至少以今天的模型还不是（This isn't a replacement for human code review, at least not yet with today's models）（[Cloudflare](https://blog.cloudflare.com/ai-code-review/)，2026）。

所以 AI review 是分流器，不是守门员。它帮人省掉一部分明显问题，但最终担责的仍是人。

## 怎么做

四层叠加，从源头到门禁，按团队成熟度逐层往上加。

### 第一层：控住 PR 体积（生产者侧）

**约定「一个 PR 只做一件事」。** AI 一次能改 20 个文件，不代表这些改动该塞进一个 PR。把规则写进 `CLAUDE.md` 或团队规范，让 AI 按逻辑边界拆成多个小 PR，而不是一把全塞进去。

**设一个软性的体积上限。** 比如非生成代码超过 400 行就该拆。大 PR 不是绝对禁止，而是需要作者主动说明为什么拆不开。

**生成代码和手写代码分开提交。** lockfile、迁移生成物、schema 生成代码单独放一个 commit 或 PR，别混进逻辑改动里淹没 reviewer。这部分也正是 AI review 该跳过的（对应下文 `REVIEW.md` 的跳过规则）。

**PR 描述必须写清意图。** 不只写「改了什么」，还要写「为什么这么改」。Kubernetes 的红线是：如果你说不清一处改动为什么要做，这个 PR 就会被关掉（if you cannot explain why a change was made, the PR will be closed）（[K8s](https://www.kubernetes.dev/docs/guide/pull-requests/)）。

### 第二层：上 AI review 当第一道分流

**让机审先跑，人只看它标出来的和它够不到的。** Claude Code Review 的机制是：一队专门的 agent 检查代码改动，找逻辑错误、安全漏洞、没考虑到的边界情况和隐蔽的回归问题。之后还有一个验证步骤，拿候选问题去对照代码的真实行为，过滤掉误报（[CC Docs](https://code.claude.com/docs/en/code-review)）。

**默认聚焦正确性，别让它当格式检查工具。** 官方明说，Code Review 关注的是正确性，也就是会搞坏生产的 bug，而不是格式偏好或缺失的测试覆盖（focuses on correctness: bugs that would break production, not formatting preferences or missing test coverage）（同上）。格式交给 CI 的 linter（代码风格检查工具），机审的注意力留给逻辑 bug。

**先搞清成本模型，再决定触发频率。** 官方定价是每次 review 平均 15-25 美元，而且「每次 push 后都审」这个模式会按推送次数成倍计费（[CC Docs](https://code.claude.com/docs/en/code-review)）。高流量的仓库建议用手动触发，或者「PR 创建后只审一次」，别每次 push 都烧一遍钱。

### 第三层：重构 review 流程本身

**保留代码结构，别把 diff 当成一整块平铺文本。** Salesforce 的做法是在分析时保留文件、函数、模块这些结构边界（preserves structural boundaries — files, functions, and modules），而不是把 diff 当成没有结构的纯文本（[Salesforce](https://engineering.salesforce.com/scaling-code-reviews-adapting-to-a-surge-in-ai-generated-code/)）。

**逐步展开，按风险分层。** 让 reviewer 分批拿到上下文（receive context incrementally），优先暴露架构决策、涉及安全的改动和高风险区域（architectural decisions, security-sensitive changes, and elevated risk areas）（同上）。人先看那高风险的 10%，而不是从第 1 行一路平铺看到第 1000 行。

**异步跑，结果预存。** 机审最多要跑五分钟（can take up to five minutes）。Salesforce 让它在 PR 创建时就异步跑完，把结果存下来，人来看时秒出（同上）。Cloudflare 是同样的思路，规模更大：在 5169 个仓库、48095 个合并请求上跑了 131246 次 review，中位耗时 3 分 39 秒完成，人工「破窗」（break glass，即绕过机审强行处理）只有 288 次，占 0.6%（[Cloudflare](https://blog.cloudflare.com/ai-code-review/)）。

### 第四层：定治理规则

**明确「第一遍 review 不许甩给 reviewer」。** Kubernetes 的原则是：不要把 AI 生成改动的第一遍 review 留给 reviewer，提 PR 之前先自己验证过（Do not leave the first review of AI generated changes to the reviewers. Verify the changes (code review, testing, etc.) before submitting your PR）（[K8s](https://www.kubernetes.dev/docs/guide/pull-requests/)）。作者先自审、拿出证据，才配占用 reviewer 的带宽。

**要求声明 AI 的使用。** K8s 允许用 AI 工具帮忙写 PR，但你必须在 PR 描述里说明这一点，而且作为作者，你要对每一处改动负责、理解每一处改动（you are responsible for understanding every change）（同上）。

**要求人亲自回 review 意见。** K8s 规定，回复 review 意见时不能依赖 AI 工具；如果你不直接和 reviewer 交流，PR 会被关掉（If you do not engage directly with reviewers, the PR will be closed）（同上）。这是为了防止连讨论环节都退化成 AI 对 AI。

**把责任归属写死在流程里。** 担责的永远是提 PR 的人。机审结论是 neutral、不拦截。这条和 [#040](../05-quality-assurance/040-who-verifies-ai-code-and-how.md) 的底线一致。

### 如果你维护的是开源项目：还要多一层「入口限流」

上面四层默认贡献者是同事，来源可控。开源没这个前提，所以要在最前面再加一道入口限流。按代价从低到高排：

1. **先写清收不收 AI 贡献。** 在 `CONTRIBUTING.md` 里写明是否接受 AI 生成的 PR、要不要声明、作者要不要能解释每一处改动。这是成本最低的一步，但别指望它挡住恶意提交——curl 加了声明勾选框，效果为零。
2. **给赏金和悬赏类入口设门槛。** 假漏洞报告的成本几乎为零，而验证成本全落在维护者头上。curl 的结论是这个账算不平，直接关停。可行的中间态是只接受能复现的 PoC（proof of concept，可运行的复现代码），跑不起来就不进人工队列。
3. **要求 PR 先关联已确认的 issue。** 先让 issue 过一遍人工确认，再允许提 PR。这能掐掉 tldraw 说的那个「AI 生成 issue、AI 又拿它生成 PR」的自动循环。
4. **实在扛不住就暂停外部 PR。** tldraw 自动关闭全部外部 PR，Ghostty 对未经邀请的 AI 提交永久封禁。这两条都是止血手段，代价是同时挡掉真实贡献者，只在维护者已经被淹没时才用，并且要写明是临时措施。

企业团队照抄这层通常没必要：内部提交量受工位约束，加了只会增加摩擦。

## Claude Code 实战

### 用 `REVIEW.md` 把机审调成「团队分流器」

Code Review 会读仓库根目录的 `REVIEW.md`。它的内容会作为优先级最高的指令块，逐字注入到 review 流水线里每个 agent 的系统提示中（injected into the system prompt of every agent in the review pipeline as the highest-priority instruction block）（[CC Docs](https://code.claude.com/docs/en/code-review)）。

针对「PR 太大太多」这个场景，最有用的是三类调参：

```markdown
# Review instructions

## Important 的定义（收窄，别让人被噪音淹没）
只有会破坏行为、泄露数据、阻断回滚的才算 Important：
错误逻辑、未按租户 scope 的 DB 查询、日志里的 PII、不向后兼容的迁移。
风格、命名、重构建议最多算 Nit。

## 给 Nit 封顶（大 PR 的 nit 能刷屏）
每次 review 最多贴 5 条 Nit，多出来的在 summary 里写「另有 N 条同类」。

## 不要 review（把生成代码/CI 已管的挡在外面）
- CI 已经管的：lint、格式、类型错
- 生成文件 src/gen/ 与所有 *.lock
- 机器生成的分支

## 收敛再次 review（防止一行小改被审到第七轮）
首次 review 之后，只报 Important，抑制新增 Nit。
```

有一点要注意：`REVIEW.md` 是逐字粘贴的，不会展开 `@import`，所以规则要直接写进去（同上）。

它和 `CLAUDE.md` 的区别在于：违反 `CLAUDE.md` 只会被标成 nit 级，而 `REVIEW.md` 是 review 专用的、优先级最高。

### 让 CI 把机审信号变成硬门禁

机审本身是 neutral、不拦截的。但你可以在自己的 CI 里解析它的严重度，自定义门禁。官方给了用 `gh` 加 `jq` 解析的口子：

```bash
gh api repos/OWNER/REPO/check-runs/CHECK_RUN_ID \
  --jq '.output.text | split("bughunter-severity: ")[1] | split(" -->")[0] | fromjson'
# 返回如 {"normal": 2, "nit": 1, "pre_existing": 0}
# normal 是 Important 计数，非 0 = 有该修的 bug
```

在 CI 里判断 `normal != 0` 就让流水线失败，就把「辅助信号」升级成了「必须过的闸门」（[CC Docs](https://code.claude.com/docs/en/code-review)）。

注意这是你在给它加门禁，不是机审自己拦截，仍然符合「决定权在人和流程」的边界。

### 提 PR 前先本地自审（履行「第一遍 review 不甩锅」）

不装 GitHub App 也能审。在任意 Claude Code 会话里跑 `/code-review`，默认审「本分支领先 upstream 的提交」加上「未提交的改动」。加 `--fix` 会直接把修复应用到工作区（[CC Docs](https://code.claude.com/docs/en/code-review)）。

这正好落地了 K8s 那条「先自己 verify 再提 PR」的要求。

## 横向对比

| 工具 / 方案 | 定位 | 是否拦截 PR | 关键差异 |
|------|------|--------------|---------|
| **Claude Code Review** | 多 agent 机审，含误报过滤 | 否（neutral，可靠 CI 自定义门禁） | 原生多 agent、`REVIEW.md` 高优先级调参、15-25 美元/次 |
| **Cursor Bugbot** | 以单 agent 为主的 PR 机审 | 否 | 同属机审信号，agent 编排较轻 |
| **GitHub Copilot review** | 平台内建的 PR review | 否 | 与 GitHub 深度集成，定制和跳过规则较弱 |
| **Cloudflare 自建（GitLab CI）** | 内部 AI reviewer 组件 | 否（靠人工「破窗」兜底） | 自托管、规模化验证过（4.8 万 MR）、明确「非人审替代品」 |

共性很清楚：主流 AI review 都刻意不拦截 PR。因为它们都知道机审会漏、也会误报，最终判断权必须留在人和流程手里。差异在于编排方式（单 agent 还是多 agent）、调参能力（有没有 `REVIEW.md` 这类机制）以及是否自托管。

想看机审工具更深入的对比，见 [#041](../05-quality-assurance/041-how-to-review-ai-generated-code.md)。

## 反模式

- ❌ **只上 AI review，以为人就能撒手。** 机审 neutral、不拦截，连 Cloudflare 都说它「非人审替代品」。AI review 是分流器不是守门员，撒手就等于换个马甲的橡皮图章。
- ❌ **放任 20 文件/1000 行的巨型 PR。** Salesforce 的数据显示，最大的 PR review 时间不升反降，说明没人真在审。不控体积，加多少工具都白搭。
- ❌ **把机审当格式检查工具用。** 官方明说它聚焦正确性、不管格式。格式让 CI 的 linter 管，别浪费 15-25 美元一次的机审注意力去挑空格。
- ❌ **每次 push 都触发全量机审。** 这个模式按推送次数成倍计费，高流量仓库会烧穿预算。用手动触发，或者「创建后只审一次」，需要时再 `@claude review once`。
- ❌ **把 AI 改动的第一遍 review 甩给 reviewer。** K8s 明令禁止。作者不先自审、说不清为什么改，就是把认知负担转嫁给别人。
- ❌ **让 AI 代替自己回 review 意见。** K8s 规定，不直接和 reviewer 交流的 PR 会被关掉。讨论环节退化成 AI 对 AI，review 就彻底失去意义。
- ❌ **只靠一个「是否使用 AI」的声明勾选框来挡垃圾提交。** curl 加了勾选框，垃圾报告照旧，最后只能关停赏金。声明是给诚实贡献者划责任边界的，不是过滤器，真要限流得靠可复现门槛或 issue 前置确认。
- ❌ **把开源那套入口限流原样搬进公司内网。** 暂停外部 PR、永久封禁这类手段针对的是不受成本约束的陌生投稿。内部提交量本来就受工位约束，抄过来只会平白增加摩擦。
- ❌ **照搬 K8s 那一整套最严治理到所有场景。** 注意 K8s 并没有一刀切禁掉 AI PR，它禁的是大型 AI 生成 PR、AI 写的 commit message 和 AI 代回 review 意见，同时强制声明 AI 使用。即便如此，开源无偿维护和企业内部团队的信任前提也不同，治理强度要分场景，别无脑抄禁令。政策该怎么定，决策见 [#075](../08-team-and-org/075-team-ai-coding-standards.md)。

## 延伸

**交叉引用：**
- [#040 AI 说"做完了"、测试也全绿，怎么知道代码是真的对？](../05-quality-assurance/040-who-verifies-ai-code-and-how.md) —— 本篇的「人审塌成橡皮图章」「担责在人」承接自 040 的验证体系框架。
- [#041 怎么 review AI 生成的代码？（人审 + 机审策略）](../05-quality-assurance/041-how-to-review-ai-generated-code.md) —— 本篇讲团队级 review 治理，041 讲个人审代码的技巧和机审工具细比。
- [#052 AI 写代码怎么和 git 流程配合？分支策略、commit、PR 怎么不让 AI 搞乱？](./052-git-workflow-with-ai.md) —— PR 怎么开、commit 怎么写在 052；本篇专讲 PR 开出来之后的 review 门。
- [#075 团队的 AI coding 规范怎么立？哪些该强制、哪些该自由？](../08-team-and-org/075-team-ai-coding-standards.md) —— 本篇「第四层治理规则」的组织级落地和政策制定归 075。

**参考资料：**
- [Code Review — Claude Code Docs](https://code.claude.com/docs/en/code-review) — 多 agent 机审机制、neutral 不拦截、`REVIEW.md` 调参、gh+jq 严重度门禁、15-25 美元/次定价（官方，2026-06）
- [Scaling Code Reviews — Salesforce Engineering](https://engineering.salesforce.com/scaling-code-reviews-adapting-to-a-surge-in-ai-generated-code/) — 代码量 +30%、超 20 文件/1000 行的 PR、最大 PR review 时间见顶、保留结构/逐步展开/异步（实践，2026）
- [Orchestrating AI Code Review at scale — Cloudflare](https://blog.cloudflare.com/ai-code-review/) — 自建 CI 原生 AI reviewer、4.8 万 MR 规模、中位 3 分 39 秒、「非人审替代品」、破窗 0.6%（实践，2026）
- [Pull Request Process — kubernetes.dev](https://www.kubernetes.dev/docs/guide/pull-requests/) — 禁大型 AI PR、禁 AI commit message、第一遍 review 不许甩锅、必须声明与亲自回复（官方政策，2026）
- [OSS maintainers demand ability to block Copilot-generated PRs — Socket](https://socket.dev/blog/oss-maintainers-demand-ability-to-block-copilot-generated-issues-and-prs) — 开源维护者被 AI PR 淹没、curl 的声明要求、口头 CAPTCHA（社区，2025-05）
- [AI Slopageddon and the OSS Maintainers — RedMonk](https://redmonk.com/kholterhoff/2026/02/03/ai-slopageddon-and-the-oss-maintainers/) — curl 关停六年赏金（8.6 万美元、20% 是 AI 垃圾、5% 有效率）、tldraw 自动关闭外部 PR、Ghostty 永久封禁、「AI 正在 DDoS 维护者」（社区，2026-02）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
