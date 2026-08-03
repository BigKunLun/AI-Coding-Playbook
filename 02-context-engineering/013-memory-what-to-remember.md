# 013. 压缩一次它就忘了刚定的方案——哪些决策必须写进 memory 才扛得住 compact

> 难度：中级
> 主题：上下文工程
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：流程题

> ⏰ 时效声明：**2026-07-18** 复核——核心数字"MEMORY.md 每次加载前 200 行或 25KB"与官方 context-window 文档现行表述逐字一致；`/doctor` 体检（v2.1.206+）与 CLAUDE.md <200 行建议均出自官方文档。版本号类细节随 Claude Code 迭代，请以官方为准。

## TL;DR

Claude Code 的 memory 是一套跨会话携带知识的机制。它能让你在新会话里不用从头交代项目背景，但代价是每次会话开始都会占用一部分上下文预算。

核心心智模型只有一句：记忆不是"能记就记"，而是"该记才记"。该记的是原因、偏好和指向外部资源的指针，不该记的是任何能从 git 或代码里直接查到的状态。

下面是三条可以直接照做的结论。

**第一，先分清两个角色。** 一个是 `CLAUDE.md`，由你手写指令；另一个是 auto memory，由 Claude 自己维护，写在 `MEMORY.md` 里，每次只加载前 200 行或 25KB。两者都是"上下文"而不是"配置"，写得越长，Claude 的遵守率越低。

**第二，真正该记的只有四类。** 反复纠正过的偏好、只能靠踩坑才学到的隐性知识（比如命令参数、环境坑）、跨会话的协作约定、指向外部资源的指针。除此之外一律不进记忆。

**第三，记忆会膨胀也会过时，必须有维护闭环。** 定期用 `/memory` 审计，把反复出现的条目提升为正式规则，给每条记忆写一个失效条件。放任膨胀的记忆会加速 context rot（上下文腐化，指无关信息越堆越多、稀释模型注意力）。

---

## 为什么

### 1. 官方机制：两套互补的记忆系统

Claude Code 官方文档定义了两套记忆系统，它们都在每次会话开始时加载。

一套是 `CLAUDE.md`，由你手写，装的是指令和规则。它按 project / user / org 分层，会全量加载，但官方建议每个文件不超过 200 行。它适合放编码规范、工作流和架构说明。

另一套是 auto memory，写在 `MEMORY.md` 里，由 Claude 自己维护，装的是它学到的模式和教训。它的作用域是单个仓库（同一仓库的多个 worktree 共享），每次只加载前 200 行或 25KB，超出部分不加载。它适合放构建命令、调试洞见，以及 Claude 自己发现的偏好。

两套系统的对照见下表。

|  | CLAUDE.md 文件 | Auto memory（`MEMORY.md`）|
| --- | --- | --- |
| **谁写** | 你 | Claude 自己 |
| **装什么** | 指令和规则 | 学到的模式和教训 |
| **作用域** | project / user / org | per-repo（同 repo 的 worktrees 共享）|
| **加载量** | 全量加载（但官方建议每文件 <200 行）| **前 200 行或 25KB**，超出不加载 |
| **用途** | 编码规范、工作流、架构 | 构建命令、调试洞察、Claude 发现的偏好 |

这套设计有一个关键细节：auto memory 存在 `~/.claude/projects/<project>/memory/` 目录下，`MEMORY.md` 只是一个索引。详细内容可以拆到 `debugging.md`、`api-conventions.md` 等主题文件里，这些主题文件启动时不加载，Claude 需要时才用文件工具按需读取。

换句话说，记忆系统的设计本意是"索引常驻、细节按需"，而不是把所有东西预先塞满上下文。（[How Claude remembers your project](https://code.claude.com/docs/en/memory)，官方，2026-06）✅

### 2. 它是"上下文"不是"学习"，这是最容易误解的点

社区反复强调一个认知纠偏：auto memory 不是 Claude 在学习，而是 Claude 在替你做配置。

Brent Peterson 用了几周 auto memory 后打开文件，发现在一个有 13 个项目、40 多个 skill 的工作区里，Claude 只记了 12 行。而且全是"文件名要带 Claude 实例名"这类操作性配置。他的原话是：

> "Claude didn't 'learn' from that naming collision... What actually happened [was]... that's not learning. That's configuration. Automated configuration, sure. But still just training Claude to operate in my specific workspace."
>
> 大意：Claude 并没有从那次命名冲突里"学到"什么。真正发生的只是配置，是自动化的配置，本质上仍然是在训练 Claude 适应我这个特定的工作区。
> —— [Automatic Memory Is Not Learning — Brent W. Peterson](https://medium.com/@brentwpeterson/automatic-memory-is-not-learning-4191f548df4c)（社区，2026-02）✅

官方文档也说明了同一件事：两套记忆都是作为"context"注入的，不是强制生效的配置。Claude 会读，也会尽量遵守，但没有"保证严格执行"这回事。指令越模糊或越矛盾，遵守率越低。（[Troubleshoot memory issues](https://code.claude.com/docs/en/memory)，官方，2026-06）✅

"记忆不是学习、也不是强制配置"这个论断有官方和社区两个来源支撑。✅

> 个人观点（小C）：理解这一点很重要。你写进记忆的每一条，本质上都是"每次会话都白送给 Claude 读一遍"的上下文。写得越多，留给真正任务的空间就越少，而且每一条都在稀释其他指令的注意力。

### 3. 边界：memory、CLAUDE.md 和检索（RAG）怎么分工

这是本文最关键的决策框架。三者的分工在官方和社区多个来源里高度一致。✅

- `CLAUDE.md`（手写指令）：你全权控制，每次启动全量加载。该装"每次都适用"的规则，不该装能从代码查到的东西。
- auto memory（Claude 自写）：由 Claude 判断，每次启动加载前 200 行。该装踩坑才懂的隐性模式，不该装一次性的任务状态。
- 检索 / RAG（按需读取文件）：这里指代码库里已有的事实，用到时才加载。该装代码结构、API、文档，不该装个人偏好。

对照表如下。

| 维度 | `CLAUDE.md`（手写指令）| Auto memory（Claude 自写）| 检索 / RAG（按需读取文件）|
|------|----------------------|--------------------------|----------------------------|
| **谁控制** | 你全控 | Claude 判断 | 代码库里已有的事实 |
| **加载时机** | 每次启动全量 | 每次启动前 200 行 | **用到时才加载** |
| **该装** | 「每次都适用」的规则 | 踩坑才懂的非显性模式 | 代码结构、API、文档 |
| **不该装** | 能从代码查的 | 一次性任务状态 | 个人偏好 |

官方对"什么时候该往 CLAUDE.md 里加"给了明确信号：只有当你发现自己在重复纠正同一件事时才加。

> "Add to it when: Claude makes the same mistake a second time... You type the same correction or clarification into chat that you typed last session... A new teammate would need the same context."
>
> 大意：满足这些情况才往里加——Claude 第二次犯同一个错；你在对话里敲下和上一次会话一样的纠正或说明；一个新同事也会需要同样的背景。
> —— [When to add to CLAUDE.md](https://code.claude.com/docs/en/memory)（官方，2026-06）✅

社区的 MindStudio 进一步总结了 auto memory 的隐式筛选标准，四条要同时满足才值得记：会反复出现（Recurrence）、读代码推不出来（Inferability）、稳定不变（Stability）、本项目独有（Project specificity）。（[What Is Claude Code Auto-Memory?](https://www.mindstudio.ai/blog/what-is-claude-code-auto-memory)，社区，2026-03）✅

Reddit 上 r/ClaudeCode 的实战帖把核心边界说得更直白：能从代码库推断出来的东西不需要进记忆，只有那些非显性、只能靠撞墙才学到的才值得记。（社区共识，2025-2026）✅

### 4. 记忆膨胀和过时的代价是真实存在的

记忆不是免费的。它每次会话都消耗 token，还会随时间腐化（详见 [#012](./012-context-window-exploding.md)）。代价主要有三种。

**膨胀代价。** `MEMORY.md` 一旦超过 200 行，超出部分直接不加载，Claude 只能看到前 200 行，并收到一条警告。有人抓包确认了这个硬上限，源码里写着 `var U_ = "MEMORY.md", pZ = 200`。官方也建议 CLAUDE.md 每个文件不超过 200 行，否则会"consume more context and reduce adherence"（消耗更多上下文、降低遵守率）。这个论断有社区和官方两个来源。（[Giuseppe Gurgone: Claude Code's experimental memory system](https://giuseppegurgone.com/claude-memory)，社区，2026；官方，2026-06）✅

**过时代价。** Reddit 实战帖把问题说得很直白：`Too much context leads to context bloat or it gets stale fast`（上下文太多会导致膨胀，或者很快变得陈旧）。不清理的记忆会让 Claude 自信地引用已经失效的命令、已经重构掉的目录。（[r/ClaudeCode: claude.md doesn't scale](https://www.reddit.com/r/ClaudeCode/comments/1qr9dws/claudemd_doesnt_scale_built_a_memory_agent_for/)，社区，2025-2026）✅

**沉默失效。** Peterson 的经历最典型。他花了几个月搭建的 learning-moment 系统，因为没有接到 `MEMORY.md`，新会话根本不知道这些教训的存在。两套记忆系统之间不会自动打通。（[Automatic Memory Is Not Learning](https://medium.com/@brentwpeterson/automatic-memory-is-not-learning-4191f548df4c)，社区，2026-02）✅

---

## 怎么做

流程题的核心是一张"该记 / 不该记"的决策清单。每次想往记忆里写东西之前（或让 Claude 写之前），先过一遍这张表。

### 该记 ✅（4 类）

1. **反复纠正过的偏好。** 比如"用 pnpm 不用 npm""金额用分不用浮点""commit message 用中文"。官方给的信号是：当你第二次纠正同一件事，就该写进去。✅
2. **只能靠踩坑学到的隐性知识。** 比如某测试需要本地 Redis、某次构建必须带 `--force`、某目录是自动生成的不能手改。这类"读代码看不出来"的事实，正是 auto memory 的甜区。✅
3. **跨会话的协作约定。** 比如代码 review 反复抓到的问题、新人 onboarding 必须知道的协作方式、外部系统的指针（生产环境 URL、关键文档位置）。✅
4. **指向外部资源的指针（而不是内容本身）。** 写"架构详见 @docs/architecture.md"，而不是把整份架构文档复制进来。注意：官方明确说，import 进来的文件仍会在启动时全量加载，并不省 token。真正省 token 的做法是"只放指针、按需读取"。✅

### 不该记 ❌（5 类）

1. **能从 git 或代码查到的状态。** 比如"当前在 feature/auth 分支""package.json 里 React 是 18.2""test 文件在 src/__tests__/"。这些用 `git log` 或 `grep` 一秒就能查到，写进记忆只会过时。✅（官方 + Reddit 共识）
2. **一次性的任务计划或待办清单。** 比如"正在重构 auth 模块，第 3 步做完了"。计划变化太快，记忆很快就变成化石。这类信息应该放 issue tracker 或 progress 文件（见 [#012](./012-context-window-exploding.md)）。✅
3. **能从代码库直接推断的显性信息。** 比如函数明显的用途、显式的命名规范。对应 MindStudio 的 Inferability 标准：读代码就能推出来的不需要记。✅
4. **对正在变化的代码的观察。** 比如"这个函数现在是这样写的"。对应 auto memory 的 Stability 标准：不稳定的东西不是好的记忆候选。✅
5. **通用编程常识。** 比如"TypeScript 是静态类型""React 用 JSX"。这些 Claude 本来就知道，记忆只应该装本项目独有的东西。✅

### 维护闭环（3 个习惯）

1. **定期审计。** 每月跑一次 `/memory`，打开所有记忆文件逐条问："这条现在还成立吗？"删掉死指令，比如脚本已不存在的命令、已被重构的路径。官方也建议定期 review 你的 CLAUDE.md 文件，删掉过时或矛盾的指令（"Review your CLAUDE.md files... periodically to remove outdated or conflicting instructions"，官方，2026-06）✅。官方还提供了 `/doctor` 自动体检（v2.1.206+）：它会对已入库的 CLAUDE.md 提议精简，砍掉那些"能从代码库推断"的目录结构、依赖清单、架构概览，保留那些"和工具默认行为不同"的坑、原因和约定。它相当于本篇"该记 / 不该记"标准的机器版执行者。（官方，2026-06）✅
2. **把重复条目提升为规则。** 如果 auto memory 里反复出现同一条，说明它应该"升舱"到 `CLAUDE.md`，变成硬规则。社区有一个 `/remember` 命令专门做这件事：识别反复出现的模式，并提议加进 `CLAUDE.local.md`。（[Brent Peterson](https://medium.com/@brentwpeterson/automatic-memory-is-not-learning-4191f548df4c)，社区，2026-02）✅
3. **给每条记忆写一个失效条件。** 写记忆时顺手加一句"本条在 X 之后失效"。比如"用 Redis 5.x；升级到 6.x 后本条作废"。这样新会话一眼就能看出哪些该清理。⚠️（社区实践，个人建议）

---

## Claude Code 实战

### `/memory` 和 `/context`：审计记忆的两个工具，别用错

`/memory` 用来浏览和编辑记忆文件。它会跨 user 和 project 作用域列出你的 `CLAUDE.md`、`CLAUDE.local.md` 和其他记忆文件的位置，可以切换 auto memory 开关，也提供打开 auto memory 文件夹的入口，选中任一文件还能在编辑器里打开。

`/context` 用来查本会话实际加载了哪些文件。官方明确说："To check which files actually loaded into the current session, run `/context`"（要查当前会话实际加载了哪些文件，运行 `/context`）。如果某个文件不在 `/context` 的明细里，Claude 就看不到它。排查"CLAUDE.md 不生效"时，也应该先跑 `/context`。

这里有个易错点：想确认某条记忆是否真的被加载，别只开 `/memory`，因为它只告诉你文件位置。要用 `/context` 看实际注入了什么。（[CC Docs: memory](https://code.claude.com/docs/en/memory)，官方，2026-06）✅

### auto memory 的目录结构（官方）

```
~/.claude/projects/<project>/memory/
├── MEMORY.md          # 索引，每次启动加载前 200 行
├── debugging.md       # 主题文件，用到时才读
├── api-conventions.md
└── ...
```

其中 `<project>` 由 git repo 根目录派生。同一仓库下的所有 worktree 和子目录共享一个 memory 目录。

auto memory 是本机本地的，不跨机器，也不进 git。

它默认开启。想关掉，可以在 settings.json 里设 `autoMemoryEnabled: false`，或者设环境变量 `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`。（官方，2026-06）✅

### 一个该记的 MEMORY.md 索引示例（<20 行）

```markdown
## Build & Env
- 集成测试需本地 Redis（端口 6379），否则 test:integration 挂
- 必须用 pnpm，npm install 会破坏 lockfile

## Conventions（踩坑所得）
- 金额一律用分（整数），禁止浮点 —— [2026-06 发现的精度 bug]
- 提交前必须跑 npm run lint && npm test

## 外部指针
- 架构决策详见 @docs/adr/
- 生产环境配置在 1Password vault "payments-prod"
```

注意看：这里全是非显性的、踩坑才懂的、本项目独有的条目，没有任何能从 `git log` 或 `package.json` 查到的状态。

### SubAgent 也能有自己的 auto memory

官方文档提到，subagent 可以维护自己的 auto memory，作用域独立。这意味着你可以给某个专职子 agent（比如专门跑测试的）单独一份记忆，不污染主会话。

Giuseppe Gurgone 抓包还发现，自定义 agent 有 project、local、user 三个 memory 作用域。其中 project 作用域的 `.claude/agent-memory/` 可以提交进 git，全队共享。（[Claude Code's experimental memory system](https://giuseppegurgone.com/claude-memory)，社区，2026）✅

### "让它记"和"自己写"怎么选

让 Claude 记：在对话里直接说"记住 X""always use pnpm"，这些会进 auto memory。

自己写规则：说"把这条加进 CLAUDE.md"，或者用 `/memory` 手动编辑，这些会进 CLAUDE.md。

决策原则很简单：需要团队共享、需要稳定不变的规则，手写进 CLAUDE.md；属于你个人的踩坑经验、随时可以删的，就让它进 auto memory。✅

---

## 横向对比

| 维度 | Claude Code | Cursor | GitHub Copilot |
|------|------------|--------|----------------|
| **持久规则文件** | `CLAUDE.md`（4 层级）+ `.claude/rules/*.md`（可带 `paths`）| `.cursor/rules/*.mdc`（4 种激活模式，YAML frontmatter）| `.github/copilot-instructions.md`（仓库根单文件）|
| **自动记忆** | ✅ **auto memory**（`MEMORY.md`，Claude 自写，默认开启，前 200 行加载）| ⚠️ "Memories" toggle（需手动开启，不默认记住对话）| ✅ **Copilot Memory**（2025 末公测，2026-03 起 Pro/Pro+ 默认开启，会自动学 repo 事实和个人偏好）|
| **记忆透明度** | ⭐ 纯 markdown，`/memory` 可看可改 | MDC 文件可见；memories 可在 Settings 审计 | repo owner 可在 Settings → Copilot → Memory 审查/删除 ⭐ |
| **跨会话共享** | auto memory per-repo 本机本地；project-scope agent memory 可进 git | rules 进 git 共享；memories 偏个人 | Copilot Memory 跨会话/跨 repo（Pro 用户）|
| **上下文预算意识** | ⭐ 明确 200 行硬上限 + 「越短遵守率越高」官方建议 | 无文档化的明确上限 | 不透明 |

几个关键观察如下。

**Claude Code 最透明、最有上下文预算意识。** 它用纯 markdown，可以审计，有 200 行硬上限，官方也反复强调要"短"。auto memory 默认开启，但完全可控。✅

**GitHub Copilot 最"自动"，也最不透明。** 官方 changelog 确认，Copilot Memory 从 2026-03-04 起对 Pro/Pro+ 默认开启（此前是 opt-in 公测）。它会自动学 repo 级别的事实，比如约定、架构、跨文件依赖。记忆严格限定在单个 repo，应用前会对当前代码库校验，28 天自动过期，用户可以去 Repository Settings → Copilot → Memory 审查或删除。好处是零配置，风险是你不知道它到底记了什么。（[Copilot Memory now on by default — GitHub Changelog](https://github.blog/changelog/2026-03-04-copilot-memory-now-on-by-default-for-pro-and-pro-users-in-public-preview/)，官方，2026-03）✅

**Cursor 偏手动。** 它的 rules 体系很成熟，支持 glob 作用域，但持久记忆需要手动开启 memories toggle，不像 Claude Code 那样默认就有 auto memory。

**共性趋势：三家都在走向"自动学习 + 可审计"的混合模型。** 因为"每次都从零开始"的 agent 体验太差。但自动不等于免维护。越是自动的系统，越要养成定期审计的习惯。

来源：[Cursor Forum: Rules vs Memories](https://forum.cursor.com/t/best-way-to-provide-context-rules-vs-memories/132960)（社区）、[CC Docs: memory](https://code.claude.com/docs/en/memory)（官方）、[Copilot Memory now on by default — GitHub Changelog](https://github.blog/changelog/2026-03-04-copilot-memory-now-on-by-default-for-pro-and-pro-users-in-public-preview/)（官方，2026-03）。

---

## 反模式

- ❌ **把 git 能查的状态写进记忆。** 比如"当前分支是 X""依赖版本是 Y"。这些一查就有，写进记忆只会随时间失效、误导后续会话。状态类信息永远走 git 或代码，不走记忆。✅（官方 + Reddit 共识）
- ❌ **记忆只增不删，从不审计。** `MEMORY.md` 超过 200 行后，超出部分根本不加载，你写的等于白写。过时的命令还会让 Claude 自信地往不存在的目录里写文件。记忆必须有维护闭环。✅（官方 + Reddit 共识）
- ❌ **把记忆当垃圾桶，什么都往里塞。** 上下文是有限资源，塞太多会加速 context rot（见 [#012](./012-context-window-exploding.md)）。记忆越长，每条指令分到的注意力越薄。该按需检索的，别预先塞进记忆。✅
- ❌ **把一次性任务计划或待办写进记忆。** 计划变化太快，记忆很快变成化石。这类信息用 issue tracker 或 progress 文件，绝不进 CLAUDE.md 或 MEMORY.md。✅
- ❌ **指望记忆能"强制执行"。** 记忆是上下文，不是配置。想让"提交前必须跑测试"万无一失，应该写一个 `PreToolUse` hook，而不是写进记忆。✅（官方，2026-06）
- ❌ **写了记忆却不接失效条件。** 一条"用 Redis 5.x"的记忆，过了两年 Redis 早升到 7.x 了，它还躺在记忆里。写的时候顺手加一句"升级后本条作废"就能避免。⚠️（社区实践）
- ❌ **以为 auto memory 等于 Claude 在学习。** 它只是在做自动化配置。你才是最终的把关者，不审计就会积累噪音。✅（社区，2026-02）
- ❌ **把敏感信息（API key、密码、生产密钥）写进会被 git 跟踪的记忆。** project 级 `CLAUDE.md` 会进 git；auto memory 虽然在本机，但也容易被误分享。敏感信息应该用 `CLAUDE.local.md`（加进 `.gitignore`）或 secrets manager。⚠️（私有仓库可以放宽，但仍建议用 secrets manager）

---

## 延伸

**交叉引用：**
- [#010 CLAUDE.md 怎么写才真的生效？](./010-claude-md-how-to-make-it-work.md) —— CLAUDE.md 是记忆系统的手写层，写法直接决定遵守率
- [#011 Context Engineering 和 Prompt Engineering 到底什么区别？](./011-context-vs-prompt-engineering.md) —— 记忆是 context engineering 的「持久化」子环节
- [#012 上下文窗口要爆了怎么办？](./012-context-window-exploding.md) —— 记忆膨胀与 context rot 是同一枚硬币的两面

**参考资料：**
- [How Claude remembers your project — Claude Code Docs](https://code.claude.com/docs/en/memory) — 官方权威：CLAUDE.md vs auto memory 机制、`MEMORY.md` 200 行/25KB 上限、目录结构、`/memory` 命令（官方，2026-06）✅
- [Automatic Memory Is Not Learning — Brent W. Peterson](https://medium.com/@brentwpeterson/automatic-memory-is-not-learning-4191f548df4c) — auto memory 不是学习而是配置；12 行实战案例；记忆系统不自动打通（社区，2026-02）✅
- [What Is Claude Code Auto-Memory? — MindStudio](https://www.mindstudio.ai/blog/what-is-claude-code-auto-memory) — auto memory 的隐式筛选标准（recurrence/inferability/stability/specificity）（社区，2026-03）✅
- [Claude Code's experimental memory system — Giuseppe Gurgone](https://giuseppegurgone.com/claude-memory) — 抓包确认 200 行硬上限；subagent memory 三 scope（社区，2026）✅
- [r/ClaudeCode: claude.md doesn't scale. built a memory agent](https://www.reddit.com/r/ClaudeCode/comments/1qr9dws/claudemd_doesnt_scale_built_a_memory_agent_for/) — 膨胀与过时的社区实证（社区，2025-2026）✅
- [r/ClaudeCode: What's the point of /memory?](https://www.reddit.com/r/ClaudeCode/comments/1st5p7h/whats_the_point_of_memory/) — `/memory` 价值辩论（社区）
- [Claude Code Memory Explained — Jose Parreño Garcia](https://joseparreogarcia.substack.com/p/claude-code-memory-explained) — 记忆定义 Claude 作为协作者的行为（社区，2026-02）
- [Cursor Forum: Best way to provide context — Rules vs. Memories](https://forum.cursor.com/t/best-way-to-provide-context-rules-vs-memories/132960) — Cursor 记忆机制（社区）
- [GitHub Community 162797: Enable persistent memory in Copilot](https://github.com/orgs/community/discussions/162797) — Copilot Memory 透明度讨论（社区）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验——你往 memory 里写过什么后来发现该删/该留的条目，或 auto memory 自动记了什么让你意外的案例]`
