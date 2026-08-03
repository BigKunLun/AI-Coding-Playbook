# 074. 团队的 AI coding 规范怎么立？哪些该强制、哪些该自由？

> 难度：中级
> 主题：团队与组织
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：决策题 | 配置题 | 流程题

> ⏰ 时效声明：本文事实性内容于 **2026-07-18** 巡检复核，外链 6 条全部存活（IBM 页面 curl 可达，正文的「WebFetch 403 未逐字核验」标注按引用当时情况保留）。官方 settings 引用（五层优先级、`allowManagedPermissionRulesOnly`/`allowManagedHooksOnly`）与现行文档一致。「强制/自由怎么划」的框架不依赖具体版本，长期有效；managed settings 具体键名以官方 settings 页为准。2026-08-03 补入两条 V2EX 社区素材，均已实访核实。

> 本篇主要面向团队负责人 / Tech Lead。不是决策者也能用「怎么做」里的最后一节。

## TL;DR

立团队 AI coding 规范，最容易犯的错不是写得不够多，而是分不清哪条该强制、哪条该留给个人。

分不清的后果有两种。一种是写出一份「负责任地使用 AI」的空话，没人照做。另一种是写出一份 200 条的大部头，把人逼到绕过。

这一篇只答一个问题：规范里哪些该强制、哪些该留自由，以及强制项怎么用机器门禁落地，而不是靠一纸文档。这里的「强制」指违反了就会出事的条款，「自由」指风格、上下文、个人偏好这类交给开发者判断的部分。

三点速记：

1. **先分清 must 和 should。** 只把「违反就坏事」的东西设成强制，比如安全禁令、高危代码人审、工具白名单、人对产出负责。其余的（模型选择、工作流、个人偏好）留给开发者判断。强制项越少，越能真正被执行。
2. **强制项必须机器可执行，不能停在文档里。** 「Confluence 里放个 PDF 改变不了行为」（[Metacto](https://www.metacto.com/blogs/creating-effective-ai-usage-policies-for-development-teams)）。强制要靠 linter、CI、managed policy 落地；纸面规则只配当 should。
3. **规范要管到所有用 AI 的人，不只研发。** 产品用 AI 出的方案、管理层用 AI 排的期，同样要有人为准确性负责，否则幻觉会一路传到交付端。
4. **规范是活文档，不是冻结的禁令。** 第一版一定不完美，「那些失败就是反馈」（[Stack Overflow](https://stackoverflow.blog/2026/03/26/coding-guidelines-for-ai-agents-and-people-too/)）。同一条豁免申请出现三次，说明规范该改，而不是执行该更严。

本篇的边界：只讲规范的强制/自由怎么划，以及怎么用 Claude Code 的三层设置落地。相关但不在本篇展开的内容，各有去处。安全红线细节见 [#072](./072-AI-coding安全红线.md)。review 流程怎么改见 [#053](../06-工程协作/053-AI的PR太大没法review.md) 和 [#041](../05-质量保证/041-怎么审查AI生成的代码.md)。token 账单和预算见 [07 主题](../07-效率与成本/060-一天该烧多少额度.md)。本篇讲「规矩写什么、怎么强制」。

---

## 为什么

### 1. 没有基线，每个人的 agent 各走各的

不立规范的真正问题，不是 AI 写的代码本身有多烂，而是一致性会塌方。

没有标准时，每个开发者的 AI agent 会做出不同的决定。一个用 Jest 测试，一个用 Mocha。一个照你的错误处理模式写，一个自己发明一套。代码都能跑，但代码库会越来越难懂、越来越难维护（[IBM: Standardize AI Code Generation](https://www.ibm.com/think/insights/standardize-ai-code-generation-across-your-development-team)，2026）⚠️（IBM 页面 WebFetch 403 反爬，内容经 WebSearch 返回、未能逐字二次核验，标注风险）。

Augment 把这个张力说得更直白：代码库模式一致时，AI 助手是「force multipliers」（力量倍增器）；模式不一致时，它们是「chaos amplifiers」（混乱放大器）（[Augment Code: 12 Rules for AI-Ready Teams](https://www.augmentcode.com/guides/enterprise-coding-standards-12-rules-for-ai-ready-teams)，2025-09 发布 / 2026-06 更新）✅。

道理很简单：AI 会照着你代码库里已有的模式来续写。规范就是喂给它的那套「已有模式」。这是「要有规范」的根本理由。

### 2. 但空话和大部头都会失败

有了规范也可能失败，通常有两种失败方式。

第一种是空话，比如「负责任地使用 AI」。含糊的政策没法执行，只会被绕过（[GoGloby](https://gogloby.com/insights/ai-policy/)，2026-06）✅。

第二种是像禁令一样的大部头。Metacto 的告诫最关键：如果规范感觉像是伪装成治理的禁令，它就会失败；工程师只会采纳那些让安全路径比绕路更省事的规则（[Metacto](https://www.metacto.com/blogs/creating-effective-ai-usage-policies-for-development-teams)，2026-07）✅。规则条数越多、豁免流程越慢，绕过率就越高。

所以规范的设计目标不是覆盖所有情况，而是让该强制的少而硬、其余留自由。这正是「哪些强制、哪些自由」这道题的核心。

### 3. 强制的边界：bounded autonomy（有界自主）

2026 年的主流治理范式叫「bounded autonomy」，字面意思是「有边界的自主」。

它包含三件事：给 agent 明确的操作边界，对高风险决策强制升级到人来批准，以及保留完整的审计轨迹（[IBM 综述引用的 2026 框架](https://www.ibm.com/think/insights/standardize-ai-code-generation-across-your-development-team)）⚠️。

翻译成一句话：agent 能自主做什么、什么必须人批准，这条线要明确画出来。线以内放手，线以外强制。这就是强制/自由的分界原则。下面「怎么做」把它落成两张表。

### 4. 规范只管写代码的人，上游会漏掉

多数团队的 AI 规范只写给研发：怎么用 agent、怎么 review、哪些代码要人审。但用 AI 的不止研发。

V2EX 上一个 64 回复的帖子说的就是这种情况：产品经理用 AI 生成十几页「技术方案」，里面是不存在的功能和接口，跟现有数据结构也对不上，末尾还附了一份 AI 估的排期；老板对这位 PM 很信任，方案就这么往下压（[V2EX 1229246](https://www.v2ex.com/t/1229246)，2025-07，7920 浏览 / 64 回复）✅。

另一个帖子把链路补全了：领导、产品、开发、测试全都在用 AI，结果是「从头到尾，没人认真读过那个规划，包括领导」。帖子里有两句话值得抄进规范讨论——「AI 顶多是放大器」，本来规范的团队更高效、本来混乱的团队只会更稀烂；以及「脑子可以外包，责任不能外包」（[V2EX 1221898](https://v2ex.com/t/1221898)，72 回复）✅。

这两个帖子说明一件事：「人对产出负责」这条如果只写在研发那一栏，就会出现一个缺口——上游用 AI 出的方案没人为准确性负责，下游却要按它排期交付。所以立规范时要先答一个问题：这份规范管到谁？范围应该是「所有用 AI 产出会进入交付链路的东西的人」，而不是「所有写代码的人」。具体怎么补在下面「怎么做」的第一张表里。

---

## 怎么做

### 第一交付物：强制 vs 自由分类表

原则只有一条：只强制「违反就坏事」的，其余留自由。也就是区分 must（违反会破坏代码库、触发安全或法律风险）和 should（风格、上下文、个人判断）。

#### 该强制（must，且尽量机器门禁）

| 强制项 | 为什么必须硬 | 落地手段（非纸面） |
|--------|-------------|-------------------|
| **安全红线**：禁止把密钥、客户数据、受监管数据、专有源码贴进未批准工具；禁止用个人或消费账号写公司代码 | 数据外泄不可逆 | managed policy 的 deny 规则 + secrets 扫描 + DLP，细节见 [#072](./072-AI-coding安全红线.md) |
| **高危代码强制人审**：认证、加密、支付、隐私、基础设施的 AI 改动，合并前须指定 senior 或安全 owner 签字 | 出事代价最高 | 按风险分级触发（见下），CI 分支保护卡门禁 |
| **agentic 硬限**：不得部署生产、改基础设施、改密钥、改访问控制、跑破坏性命令，除非有显式人批准加审计日志（[Metacto](https://www.metacto.com/blogs/creating-effective-ai-usage-policies-for-development-teams)）✅ | 自主 agent 的高危动作不可回滚 | 权限 deny + approval gate（Claude Code managed policy） |
| **人对产出负责**：提交或批准 AI 辅助工作的开发者，对结果负责；开发者不得合并他解释不了的 AI 代码（[Metacto](https://www.metacto.com/blogs/creating-effective-ai-usage-policies-for-development-teams)）✅ | 责任不能转嫁给 AI | PR 模板 + review 纪律，机制见 [#040](../05-质量保证/040-怎么验证AI代码是真的对.md) |
| **上游产出同样适用**：AI 写的需求、技术方案、排期，提出者要能自己解释每一条，并标明哪部分是 AI 生成；接口和数据结构须与现有系统对齐后才能进排期 | 幻觉方案会一路传到交付端，且下游只能被动接单（[V2EX 1229246](https://www.v2ex.com/t/1229246)）✅ | 方案模板加「AI 参与标注」和「已核对的接口清单」两栏；技术评审是这条的门禁 |
| **工具/模型白名单**：批准的工具（企业档 Cursor/Copilot、带内部端点的 Claude Code）对禁止的工具（个人 ChatGPT、浏览器插件、个人邮箱的免费 API key）（[GoGloby](https://gogloby.com/insights/ai-policy/)）✅ | 影子 AI 等于影子风险 | 采购或网关层强制 + managed policy |

#### 该自由（should / 开发者判断）

| 自由项 | 为什么别强制 |
|--------|-------------|
| **具体工作流**（先 plan 还是直接写、开不开 plan mode、派不派 SubAgent） | 因人因任务而异，强制反而降效；把「要有验证」设成 must，把「怎么走到验证」留自由 |
| **低风险场景的模型选择** | 内部工具或一次性脚本用哪个模型，交给成本判断，见 [07 主题](../07-效率与成本/060-一天该烧多少额度.md) |
| **个人偏好**：statusline、快捷键、本地实验配置 | 与团队一致性无关，强制只增摩擦 |
| **风格细节里「选哪个」**：snake_case 还是 camelCase | Augment 说得清楚：选哪个不重要，全组一致才重要，挑一个、坚持它（[Augment](https://www.augmentcode.com/guides/enterprise-coding-standards-12-rules-for-ai-ready-teams)）✅。所以这类是「一致性要强制、具体选项自由约定」：写进 CLAUDE.md 让 agent 统一，而不是逐条人审 |
| **AI 参与的披露粒度** | 别要求每一次 autocomplete 都披露，只对实质性的 AI 改动、高危代码、agentic 动作要求（[Metacto](https://www.metacto.com/blogs/creating-effective-ai-usage-policies-for-development-teams)）✅。披露开销要与真实风险成比例 |

> **关键纪律**：强制项每加一条，都要问两个问题——违反了会坏什么事、能不能机器检测。答不上来的，降级成 should 写进 CLAUDE.md，别写进 deny 规则。

### 第二交付物：风险分级的 review 触发

强制不是「一刀切最严」，而是按风险分层。因为如果不分层，工程师会默认走最低档（[GoGloby](https://gogloby.com/insights/ai-policy/)）✅。

| 风险档 | 工作类型 | 强制 review |
|--------|---------|------------|
| **AI 审即可** | 内部文档、测试夹具 | 无需人审 |
| **单个人审** | 非关键应用代码 | 一名工程师 |
| **指定 senior + 显式签字** | 基础设施、认证、支付、客户数据 | 强制 senior |

> 触发条件必须无歧义，否则工程师会默认走最低档（[GoGloby](https://gogloby.com/insights/ai-policy/)）✅。review 流程本身怎么改（PR 体量、reviewer 疲劳）归 [#053](../06-工程协作/053-AI的PR太大没法review.md) 和 [#041](../05-质量保证/041-怎么审查AI生成的代码.md)，本篇只定「哪档触发强制」。

### 第三交付物：把规范当活文档运营

**第一版不求完美。** 你第一版的编码规范不会产出完美的 agentic 代码，没关系，那些失败就是反馈（[Stack Overflow](https://stackoverflow.blog/2026/03/26/coding-guidelines-for-ai-agents-and-people-too/)，Ryan Donovan，2026-03）✅。

**保持协作可编辑。** 把标准文件当成和工程团队的一场对话，让所有人都能编辑、评论、更新（[Stack Overflow](https://stackoverflow.blog/2026/03/26/coding-guidelines-for-ai-agents-and-people-too/)）✅。

**豁免是信号，不是漏洞。** 如果同一个豁免出现三次，要么批准一个受治理的工作流，要么把禁令写得更清楚（[Metacto](https://www.metacto.com/blogs/creating-effective-ai-usage-policies-for-development-teams)）✅。

**别指望规则一根独木撑起一切。** 别因此放弃那些确定性的代码标准执行器：linter、formatter、静态分析工具在你的构建流水线里仍有一席之地，它们能抓住 agent 搞砸的基础问题（[Stack Overflow](https://stackoverflow.blog/2026/03/26/coding-guidelines-for-ai-agents-and-people-too/)）✅。

### 如果你是被 mandate 的那一方

上面三份交付物都要拍板权。如果你是被规范约束、或者被自上而下要求「必须用 AI」的那一方，下面这几条今天就能做，不需要任何审批。

**一，收到一份含糊的规范时，别在群里吐槽，去问「这条怎么机器检测」。** 把「负责任地使用 AI」这类条款逐条提回去：违反了会坏什么事、CI 能不能查出来。答不上来的条款，建议降级成 should 写进 CLAUDE.md。话题落在「怎么写才可执行」，会被当成建议；落在「我不想被管」，会被当成抵触。

**二，被规范拦住时，走豁免流程，并且留记录。** 同一条豁免申请出现三次，就是规范该改的信号（[Metacto](https://www.metacto.com/blogs/creating-effective-ai-usage-policies-for-development-teams)）✅。你把三次记录摆出来，比讲道理有力。绕过规则则相反——一次绕过就把这条证据链毁了。

**三，自己团队先把 should 那半边落地，不用等公司批。** 在仓库根写 `.claude/settings.json` 和项目 `CLAUDE.md`，把命名、技术栈、错误处理约定定下来；个人偏好放 `settings.local.json` 不进 git。这两步不需要任何 IT 权限，却能解决「每个人的 agent 各走各的」这个最常见的问题。等公司的强制层下来时，你这部分正好是对方要的团队默认。

**四，收到上游用 AI 生成的方案时，把核对成本摆到台面上，别自己默默消化。** V2EX 那个帖子下面票数最高的两条回复给的正是可执行的做法：一是「谁定义谁负责，他用 AI 出方案，你用 AI 实施」，把责任归位；二是用推理模型把方案反向挑一遍刺，列出具体的 P0/P1 问题清单再打回（[V2EX 1229246](https://www.v2ex.com/t/1229246)）✅。第二条更实用——你交回去的不是「这方案不行」，而是「这 5 个接口不存在、这 3 处和现有表结构冲突」。有清单才叫评审意见，没清单只会被当成不配合。

**五，别接受基于 AI 使用量的考核指标。** 如果考核的是「提示词条数」「AI 生成代码行数」这类用量，正确的提法不是拒绝用 AI，而是把指标换成结果口径：交付周期、缺陷率、review 一次通过率。用量指标的问题很具体——它奖励把活儿拆碎、奖励生成再删掉，和「人对产出负责」直接冲突。提这个建议时带上前一条的清单证据，比表态有用。

---

## Claude Code 实战

Claude Code 的三层设置正好把「强制 / 团队默认 / 个人自由」三档一一对应。这是把上面分类表落地的现成机制。

官方给出的优先级从高到低如下：

> "1. **Managed** (highest): can't be overridden by anything（最高，不能被任何东西覆盖）
> 2. **Command line arguments**: temporary session overrides
> 3. **Local**: overrides project and user settings
> 4. **Project**: overrides user settings
> 5. **User** (lowest): applies when nothing else specifies the setting"
> — [CC Docs: settings](https://code.claude.com/docs/en/settings)（官方，2026）✅

对号入座：

| 层 | 放什么 | 对应规范档 |
|----|--------|-----------|
| **Managed settings（IT 部署，不可覆盖）** | 安全 deny 规则、工具白名单、agentic 硬限、禁 bypass | **强制（must）** |
| **Project settings（`.claude/settings.json`，进 git，全组共享）** | 团队默认权限、hooks、MCP、命名和技术栈约定（写进项目 CLAUDE.md） | **团队默认（should，可议）** |
| **User/Local settings（`.claude/settings.local.json`，不进 git）** | 个人偏好、本地实验 | **个人自由** |

把强制变成硬门禁，靠的是两把只在 managed settings 生效的锁：

> "`allowManagedPermissionRulesOnly` — (Managed settings only) Prevent user and project settings from defining `allow`, `ask`, or `deny` permission rules. Only rules in managed settings apply."
> "`allowManagedHooksOnly` — (Managed settings only) Only managed hooks, SDK hooks, and hooks from plugins force-enabled in managed settings `enabledPlugins` are loaded. User, project, and all other plugin hooks are blocked."
> — [CC Docs: settings](https://code.claude.com/docs/en/settings)（官方，2026）✅

这两个键就是「哪些必须强制」的技术闸门。开了它们，开发者就无法把自己的 allow 规则或私有 hook 加进去，一切只走 IT 批准的规则。

还有一条底层规则：deny 优先于 allow，且跨层时下层的 allow 翻不了案。这是安全红线能真正强制的关键，deny 细节归 [#072](./072-AI-coding安全红线.md)。

团队共享和个人自由这两档，官方文档也有明确定位：

> "`.claude/settings.json` for settings that are checked into source control and shared with your team."
> "`.claude/settings.local.json` for settings that are not checked in, useful for personal preferences and experimentation."
> — [CC Docs: settings](https://code.claude.com/docs/en/settings)（官方，2026）✅

一个可以直接跑的落地动作，分四步：

1. 团队默认（should）写进仓库根的 `.claude/settings.json` 和项目 `CLAUDE.md`。命名、技术栈、错误处理约定都放这里，让 agent 统一续写。CLAUDE.md 怎么写见 [#010](../02-上下文工程/010-CLAUDE-md怎么写才生效.md)。
2. 硬红线（must）交给 IT 用 managed-settings.json 部署（走 MDM/Jamf/Intune/Group Policy，或 v2.1.38+ Team 档的 server-managed settings），并配上 `allowManagedPermissionRulesOnly`。
3. 个人偏好留在 `settings.local.json`，别进 git。
4. 在 CI 挂 linter 和 secrets 扫描。纸面上的 must 只有挂上机器门禁才算真强制，这呼应了 [#040](../05-质量保证/040-怎么验证AI代码是真的对.md) 的「约束层当独立真值源」。

> 想确认当前生效的是哪一层：在 Claude Code 里跑 `/status`，Setting sources 一行会列出每个生效层及投递渠道（Enterprise managed settings、file 等）。（据社区整理，⚠️）

---

## 横向对比

| 工具 | 「强制」机制 | 差异 |
|------|-----------|------|
| **Claude Code** | managed-settings.json（MDM 或 server-managed）加 `allowManagedPermissionRulesOnly` 硬锁，deny 跨层不可翻案 | 三层设置天然对应 强制/默认/自由，IT 可部署不可覆盖层 |
| **Cursor** | Team/Enterprise 的 admin 规则加 Cursor Rules 全员分发 | 规则以「引导 agent 风格」为主，硬权限边界依赖底层模型厂商条款 |
| **GitHub Copilot** | 企业策略（组织级开关、内容排除、代码引用过滤） | 偏「哪些能用、哪些内容不喂」，代码库风格一致性靠外部 linter |

> 共性一句话：团队一致性这类软约束，靠共享规则文件（CLAUDE.md / Cursor Rules）加 linter；安全和高危这类硬约束，靠 IT 可部署、不可覆盖的 managed policy。两类别混。

---

## 反模式

- ❌ **写「负责任地使用 AI」这类空话当规范。** 不可执行、会被绕过（[GoGloby](https://gogloby.com/insights/ai-policy/)）✅。规范要点名具体工具、具体数据类、具体工作流。
- ❌ **规范写成大部头、豁免流程又慢。** 感觉像伪装成治理的禁令就会失败（[Metacto](https://www.metacto.com/blogs/creating-effective-ai-usage-policies-for-development-teams)）✅。慢豁免是政策失败，不是安全特性。
- ❌ **把 must 停在 Confluence 文档里。** 「Confluence 里放个 PDF 改变不了行为」（[Metacto](https://www.metacto.com/blogs/creating-effective-ai-usage-policies-for-development-teams)）✅。强制项没挂机器门禁，就等于没强制。
- ❌ **要求每次 autocomplete 都披露 AI。** 披露开销要与真实风险成比例，只对实质性改动、高危代码、agentic 动作要求（[Metacto](https://www.metacto.com/blogs/creating-effective-ai-usage-policies-for-development-teams)）✅。
- ❌ **风格细节逐条人审。** snake_case 还是 camelCase 这类，选哪个不重要、一致才重要（[Augment](https://www.augmentcode.com/guides/enterprise-coding-standards-12-rules-for-ai-ready-teams)）✅。写进 CLAUDE.md 让 agent 统一，别耗人审。
- ❌ **规范只写给写代码的人。** 用 AI 的还有产品、测试、管理层。上游用 AI 出的方案没人负责准确性，下游就要按幻觉排期交付（[V2EX 1229246](https://www.v2ex.com/t/1229246)）✅。「人对产出负责」这条要覆盖所有进入交付链路的 AI 产出。
- ❌ **按 AI 使用量考核。** 提示词条数、AI 生成行数这类指标奖励把活儿拆碎和生成再删，和「人对产出负责」冲突。要考核就考核交付周期、缺陷率这类结果口径。
- ❌ **靠规则文档替代 linter/CI。** 别放弃那些确定性执行器，它们能抓 agent 搞砸的基础问题（[Stack Overflow](https://stackoverflow.blog/2026/03/26/coding-guidelines-for-ai-agents-and-people-too/)）✅。
- ❌ **把第一版规范当终稿冻结。** 第一版不会完美，那些失败就是反馈（[Stack Overflow](https://stackoverflow.blog/2026/03/26/coding-guidelines-for-ai-agents-and-people-too/)）✅。同一豁免出现三次，是该改规范的信号。

---

## 延伸

**交叉引用：**
- [#072 AI coding 的安全红线怎么画？密钥泄露、数据外泄、第三方上传的真实事故与防护](./072-AI-coding安全红线.md) —— 本篇「安全红线强制项」的细节与真实事故在 072。
- [#053 AI 生成的 PR 太大太多，review 机制怎么扛住不崩？](../06-工程协作/053-AI的PR太大没法review.md) / [#041 怎么 review AI 生成的代码？（人审 + 机审策略）](../05-质量保证/041-怎么审查AI生成的代码.md) —— 本篇只定「哪档触发强制人审」，review 流程本身在这两篇。
- [#040 AI 说"做完了"、测试也全绿，怎么知道代码是真的对？](../05-质量保证/040-怎么验证AI代码是真的对.md) —— 把 linter 和扫描当「约束层独立真值源」挂进强制门禁。
- [#010 CLAUDE.md 怎么写才真的生效？](../02-上下文工程/010-CLAUDE-md怎么写才生效.md) —— 团队默认（should）落地在 CLAUDE.md：文件级写法在 010，本篇是组织级政策框架。
- [#052 AI 写代码怎么和 git 流程配合？分支策略、commit、PR 怎么不让 AI 搞乱？](../06-工程协作/052-别让AI搞乱git仓库.md) —— commit 署名和披露的操作层。
- token 账单和预算上限 —— 见 [07 主题](../07-效率与成本/060-一天该烧多少额度.md)。

**参考资料：**
- [CC Docs: Settings](https://code.claude.com/docs/en/settings) — 设置优先级（Managed 最高、不可覆盖）+ allowManagedPermissionRulesOnly/allowManagedHooksOnly + project/local 共享与个人自由的定位（官方，2026）✅
- [Metacto: AI Usage Policy Template for Developers 2026](https://www.metacto.com/blogs/creating-effective-ai-usage-policies-for-development-teams) — must/never 清单、人对产出负责、agentic 硬限、「伪装成治理的禁令会失败」、豁免三次即改规范、披露与风险成比例（从业者/厂商指南，2026-07）✅
- [GoGloby: AI Policy for Software Teams 2026](https://gogloby.com/insights/ai-policy/) — 规范六要素、工具白名单/禁用清单、风险分级 review 触发、「含糊政策不可执行」（从业者/厂商指南，2026-06）✅
- [Augment Code: Enterprise Coding Standards — 12 Rules for AI-Ready Teams](https://www.augmentcode.com/guides/enterprise-coding-standards-12-rules-for-ai-ready-teams) — 「force multipliers vs chaos amplifiers」、命名「选哪个不重要一致才重要」、「手工执行在企业规模会失败」（从业者/厂商指南，2025-09 发布 / 2026-06 更新）✅
- [Stack Overflow Blog: Building shared coding guidelines for AI (and people too)](https://stackoverflow.blog/2026/03/26/coding-guidelines-for-ai-agents-and-people-too/) — Ryan Donovan：第一版不完美/失败即反馈、标准文件当团队对话、别放弃 linter/formatter（社区/媒体，2026-03）✅
- [V2EX: 产品经理开始用 AI 做「技术方案」了](https://www.v2ex.com/t/1229246) — PM 用 AI 出十几页技术方案，接口和功能都是编的、还附 AI 估的排期；高赞回复「谁定义谁负责」与「用推理模型反向挑刺再打回」（社区，2025-07，7920 浏览 / 64 回复，2026-08-03 实访核实）✅
- [V2EX: IT 团队没人愿意动脑子了](https://v2ex.com/t/1221898) — 全链路依赖 AI、「没人认真读过那个规划，包括领导」；「AI 顶多是放大器」「脑子可以外包，责任不能外包」（社区，72 回复，2026-08-03 实访核实）✅
- [IBM: Standardize AI Code Generation Across Your Development Team](https://www.ibm.com/think/insights/standardize-ai-code-generation-across-your-development-team) — 无标准时每个 agent 各走各的（Jest vs Mocha）、分层 global rules、活文档季度复审、bounded autonomy（从业者综述，2026）⚠️（页面 403 反爬，内容经 WebSearch 返回未逐字二次核验）

> 本篇个人实践（L4）：`[待补：BOSS 团队的强制清单实际几条 / 哪条最先落 managed policy / 哪条从强制降回自由 / 豁免流程踩过的坑]`
