# 010. CLAUDE.md 怎么写才真的生效？

> 难度：中级
> 主题：上下文工程
> 工具：Claude Code · 横向(Cursor / Copilot / Cline)
> 题型：配置题

> ⏰ 时效声明：**2026-07-18** 复核。官方 memory 文档链接仍然存活。「以 user message 形式注入、不保证严格遵守、建议 <200 行」这几个核心机制，与现行文档一致。横向对比里说的「Cursor 旧的 `.cursorrules` 已弃用，改用 `.cursor/rules/*.mdc`」也符合 Cursor 现状（社区来源已标注）。第三方工具机制变化快，对比表的细节请以各家官方文档为准。

## TL;DR

`CLAUDE.md` 是 Claude Code 启动时自动读取的一个持久指令文件。每开一段新会话，它的内容都会被塞进上下文。

要让里面的指令真的被遵守，记住三件事。

第一，放对位置文件才会被加载。用户级放 `~/.claude/CLAUDE.md`，项目级放 `./CLAUDE.md`，个人项目级放 `./CLAUDE.local.md`，还有一层组织托管策略级。放错目录等于完全不生效。

第二，它是「上下文」不是「配置」。它的内容以对话消息的形式喂给 Claude，不是被强制执行的开关。写得越模糊、越长、越自相矛盾，遵守率越低。

第三，少即是多。目标写在 200 行以内，只放「每次都适用」的指令。其余细节下沉到 `.claude/rules/`，或用 `@import` 拆成多个文件。

一句话：把 CLAUDE.md 当成给 Claude 的入职文档，而不是垃圾桶或代码检查工具。

## 为什么

### 1. 大模型不记事，CLAUDE.md 是唯一「每次都注入」的入口

大模型在推理时权重是冻结的，不会跨会话学习你的项目。

Claude Code 的运行框架（harness，指管理会话、拼接上下文的外层程序）在每个新会话开始时，把 `CLAUDE.md` 的内容拼进对话消息里注入。它是默认进入每一段对话的唯一文件。

HumanLayer 博客把它称为整个 harness 里「杠杆最高的一个点」（社区权威，2025-11）。来源见 <https://www.humanlayer.dev/blog/writing-a-good-claude-md>。

### 2. 关键：它是「上下文」而非「配置」，这是大多数失效的根因

官方文档写得很明白：

> "CLAUDE.md content is delivered as a user message after the system prompt, not as part of the system prompt itself. Claude reads it and tries to follow it, but there's no guarantee of strict compliance, especially for vague or conflicting instructions."
> — [Claude Code Docs: Troubleshoot memory issues](https://code.claude.com/docs/en/memory)（官方，2026-06）

翻译过来：CLAUDE.md 的内容是作为一条用户消息放在系统提示之后送进去的，不是系统提示的一部分。Claude 会读它、会尽量遵守，但不保证严格照做，尤其是遇到模糊或互相冲突的指令时。

还有一个更关键的细节。Claude Code 在 `CLAUDE.md` 之后，会再附加一段叫 `important-instruction-reminders` 的提醒。其中一句是「Do what has been asked; nothing more, nothing less」（要求做什么就做什么，不多不少）。另一句更具决定性：

> "IMPORTANT: this context may or may not be relevant to your tasks. You should not respond to this context unless it is highly relevant to your task."

意思是：这段上下文可能和你的任务相关，也可能无关；除非高度相关，否则不要理会它。

结论就是：Claude 会自己判断 CLAUDE.md 里的指令跟当前任务是否相关，判定为不相关就直接忽略。

这个机制有两个来源印证。Reddit 社区帖子专门揭示了这一点（社区，2025-05），见 <https://www.reddit.com/r/ClaudeAI/comments/1ldugmg/this_is_why_claude_code_sometimes_ignore_your/>。HumanLayer 通过抓取 `ANTHROPIC_BASE_URL` 的请求，也独立验证了同样的注入逻辑（社区权威，2025-11）。

### 3. 指令越多，遵守率越低

HumanLayer 引用的研究表明：前沿的思考型模型能稳定跟随大约 150 到 200 条指令。

关键在于衰减方式。指令数量增加时，遵循质量是「均匀下降」的。不是只忽略排在后面的指令，而是所有指令都开始被差不多的概率忽视。

而 Claude Code 自身的系统提示已经占掉大约 50 条指令。所以留给你 CLAUDE.md 的「可靠跟随预算」其实很有限（社区权威，2025-11）。

### 4. 加载层级与优先级

官方文档和多个社区来源一致描述的加载顺序是：从宽到窄、从早到晚注入。

| 层级 | 位置 | 用途 | 是否进 git |
|------|------|------|-----------|
| 托管策略 (Managed policy) | macOS `/Library/Application Support/ClaudeCode/CLAUDE.md` 等 | 组织级（IT 管控，安全合规） | 否，机器级 |
| 用户级 (User) | `~/.claude/CLAUDE.md` | 个人跨项目偏好 | 否 |
| 项目级 (Project) | `./CLAUDE.md` 或 `./.claude/CLAUDE.md` | 团队共享的项目规范 | **是** |
| 项目本地 (Local) | `./CLAUDE.local.md` | 个人的、此项目专属（沙箱 URL 等） | 否（加 `.gitignore`）|

这里要点明一件事：所有层级的文件是「拼接进上下文」，不是互相覆盖。越靠近工作目录的文件越晚被读到。

来源：[Claude Code Docs: Choose where to put CLAUDE.md files](https://code.claude.com/docs/en/memory)（官方，2026-06）、[Jose Parreño Garcia: Claude Code Memory Explained](https://joseparreogarcia.substack.com/p/claude-code-memory-explained)（社区，2026-02）。

## 怎么做

按优先级排列的清单。

**1. 放对位置。**

根目录 `./CLAUDE.md` 是最常见的起点。个人私有偏好放 `./CLAUDE.local.md`，并加进 `.gitignore`。

想核对本会话到底加载了哪些文件，用 `/context`，这是官方排查「不生效」的第一步。`/memory` 则用来列出各层级文件的位置并打开编辑。

**2. 先手写，别用 `/init` 盲目生成。**

`/init` 适合冷启动时拿个草稿。但 HumanLayer 强烈建议逐行手工打磨，因为 CLAUDE.md 影响工作流的每个阶段，一行错的指令会被放大成大量错误代码（社区权威，2025-11）。

**3. 控制长度。**

官方建议每个 CLAUDE.md 文件写在 200 行以内。社区共识是 300 行以内，越短越好。HumanLayer 自己的根 CLAUDE.md 不到 60 行。（<200 行是官方说法；「越短越好」是社区流行看法，单源、偏主观。）

**4. 只放「每次都适用」的内容。**

三类内容值得放：技术栈和项目结构（是什么）、项目目的（为什么）、构建/测试/验证命令和工作流约定（怎么做）。

**5. 指令要具体、可验证。**

写「用 2 空格缩进」，不要写「格式化好」。写「提交前跑 `npm test`」，不要写「记得测试」。写「API handler 放在 `src/api/handlers/`」，不要写「保持文件整洁」。（官方 + SFEIR 双源。）

**6. 消除矛盾。**

定期审计：把 CLAUDE.md 贴进一个新会话，问它「哪些指令互相冲突？」。Claude 很擅长找出自己被喂的矛盾指令。

**7. 细节下沉。**

超过 200 行就拆，有两条路径。

一是 `.claude/rules/*.md`。它可以加 `paths` 这个头部字段做「路径作用域」，比如只在改动 `src/api/**/*.ts` 时才加载，能省上下文。

二是 `@path/to/file` 形式的 import。它适合组织文件结构。但要注意：被 import 的文件在启动时仍然会全量加载，并不省 token。

**8. 该用 Hook 的别写进 CLAUDE.md。**

必须强制执行的事情，比如提交前必须 lint、禁止改某个目录，应该用 `PreToolUse` 或 `Stop` 这类 hook（钩子，指在特定动作前后自动触发的脚本）。hook 是硬执行，和 Claude 的判断无关。

**9. 季度审计。**

每季度逐行问一遍「这条现在还成立吗？」，删掉死指令，比如指向已经不存在的脚本的 run 命令、已经重构掉的目录路径。

## Claude Code 实战

### 一个合格的项目级 CLAUDE.md 片段（<60 行示例）

```markdown
# Project: payments-service

## Stack
- Node 20 + TypeScript strict, Fastify, Prisma (PostgreSQL)
- 测试: Vitest; 单测 `npm run test:unit`, 集成 `npm run test:integration`（需本地 Redis）

## Architecture at a glance
- `src/api/handlers/` — HTTP 路由 handler，所有入参必须校验
- `src/domain/` — 领域逻辑，不依赖 HTTP 层
- `src/db/` — Prisma repository，所有数据库访问只走这里
- 详细规范见 @docs/architecture.md（需要时再读）

## Conventions
- 错误响应统一用 `src/api/errors.ts` 的 `ApiError`
- 提交前跑 `npm run lint && npm test`
- 金额一律用分（整数），禁止浮点

## Out of scope for CLAUDE.md
- 代码风格细节交给 Biome（已配 Stop hook 自动修复）
- 临时计划放 issue tracker，不要写进这里
```

这个示例有两个要点。

一是只放指针、不放拷贝：用 `@docs/architecture.md` 引用，而不是把整份架构文档复制进来。

二是具体到可验证：写清楚命令、目录和单位。

### `/context` 与 `/memory`：排查不生效的两个工具

排查「文件没生效」时，官方指定的第一步是 `/context`。

`/context` 显示本会话实际加载进上下文的内容。它能确认你的 `CLAUDE.md` 或 `CLAUDE.local.md` 是否真的被读进来。如果不在里面，Claude 根本看不到它。

`/memory` 则用来列出各层级的 `CLAUDE.md`、`CLAUDE.local.md` 以及自动记忆文件的位置，并直接打开编辑。两者配合用。（官方，2026-06。）

### `@import` 与 `.claude/rules/` 的取舍

| 机制 | 何时加载 | 省 token? | 典型用途 |
|------|---------|----------|---------|
| `@docs/x.md` import | 启动时全量 | ❌ 否 | 组织结构、复用 AGENTS.md |
| `.claude/rules/x.md`（无 paths） | 启动时全量 | ❌ 否 | 按主题拆分，便于维护 |
| `.claude/rules/x.md`（带 `paths:`） | **匹配文件时才加载** | ✅ 是 | API 规范、测试规范、前端规范 |
| `~/.claude/rules/` | 启动时（用户级，早于项目） | ❌ 否 | 个人偏好 |

> 社区流行技巧（⚠️ 单源，Reddit）：如果发现 Claude 反复忽略某条规则，把这条规则单独放进一个 `coderules.md`，再做一个 slash 命令，在会话开始或 compact 之后显式让 Claude 读它。这样能绕开系统提醒里那句「可能不相关」的判断。来源：r/ClaudeAI（社区，2025-05）。

### compact 之后哪些指令还活着

项目根目录的 `CLAUDE.md` 在 `/compact`（压缩上下文）之后，会从磁盘重新读取并重新注入。

但子目录里嵌套的 CLAUDE.md 不会自动重新注入，要等 Claude 再次读那个目录的文件时才加载。

所以「必须每次都生效」的指令，务必放根目录。（官方，2026-06。）

## 横向对比

| 工具 | 文件/机制 | 作用域与加载 | 关键差异 |
|------|----------|------------|---------|
| **Claude Code** | `CLAUDE.md`（多层级）+ `.claude/rules/*.md`（带 `paths`）+ `@import` | 4 层级拼接注入；rules 可按 glob 条件加载 | 层级最丰富；强调「上下文非配置」；<200 行官方建议 |
| **Cursor** | 旧 `.cursorrules`（已弃用）→ 新 `.cursor/rules/*.mdc` | 旧：每次请求全量注入；新：4 种激活模式（Always/Auto/Glob/Manual）| MDC 用 YAML frontmatter（`globs`/`alwaysApply`）；`alwaysApply:true` 等价旧 `.cursorrules`。来源：r/cursor（社区，2025-02）|
| **GitHub Copilot** | `.github/copilot-instructions.md` | 仓库根单文件，IDE 内自动注入 chat/inline | 无多层级、无条件加载机制；**GitHub.com 的 Code Review 可能不读它**。来源：[GitHub Docs](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)（官方）+ [GitHub Community 187926](https://github.com/orgs/community/discussions/187926)（社区）|
| **Cline** | `.clinerules`（项目根）| 类似旧 `.cursorrules`，线性加载 | 概念相同但更偏 agent 化；上下文窗口最大可达 1M token（取决于所选 provider/模型）。来源：[Arize 博客](https://arize.com/blog/optimizing-coding-agent-rules-claude-md-agents-md-clinerules-cursor-rules-for-improved-accuracy/)（社区，2025）|

共性与趋势：所有主流工具都在从「单文件全量注入」走向「按文件类型或路径条件加载」。

Cursor 的 glob、Claude Code 的 `paths` rules、Cline 的 memory bank，本质是同一件事：渐进式披露（Progressive Disclosure，指用到时才加载对应内容），目的是避免上下文膨胀。

社区实测：优化 rules 能把 agent 准确率提升 10 到 15%（Arize，2025，⚠️ 单源）。

## 反模式

**把 CLAUDE.md 当代码检查工具。**
代码风格细则应该交给 Biome、ESLint、Prettier，再用 Stop hook 自动修复。让大模型去当 linter 又慢又贵，还会污染上下文窗口。（HumanLayer + 官方双源。）

**用 `/init` 生成后从不手改。**
自动生成的文件往往啰嗦，还夹带一次性指令。CLAUDE.md 影响每个工作流阶段，值得逐行手工打磨。

**无限堆叠，从不删除。**
一旦超过 300 行这条社区共识的上限，遵守率会明显下降。架构已经重构、文件却没更新时，Claude 会自信地往不存在的目录里写文件。（官方 + aicodex 双源。）

**放错目录。**
放在子目录里的 CLAUDE.md，只有当 Claude 读那个目录的文件时才加载。放到 `.claude/CLAUDE.md` 之外的非标准路径，根本不加载。第一排查动作永远是 `/context`，先确认到底加载了什么。

**写矛盾指令。**
「永远用 async/await」和「工具目录用 .then()」同时存在，Claude 的行为就变得不可预测。

**把临时计划或运行清单塞进来。**
计划变化太快，CLAUDE.md 会变成过时的化石。这类东西用 issue tracker 或 skill 管理。

**指望它「强制执行」。**
想让「提交前必须跑测试」万无一失，应该写 hook，而不是写 CLAUDE.md。CLAUDE.md 是行为引导，hook 才是硬执行层。

## 延伸

**交叉引用：**
- [#013 压缩一次它就忘了刚定的方案——哪些决策必须写进 memory 才扛得住 compact](../02-上下文工程/013-哪些决策要写进memory.md)
- [#012 上下文窗口要爆了怎么办？](../02-上下文工程/012-上下文窗口要爆了.md)

**参考资料：**
- [How Claude remembers your project — Claude Code Docs](https://code.claude.com/docs/en/memory) — 官方 memory 章节权威参考（官方，2026-06）✅
- [Writing a good CLAUDE.md — HumanLayer Blog](https://www.humanlayer.dev/blog/writing-a-good-claude-md) — 上下文工程视角的最佳实践，含指令跟随衰减研究（社区权威，2025-11）✅
- [Why your CLAUDE.md stops working — aicodex.to](https://www.aicodex.to/articles/claude-md-maintenance) — CLAUDE.md 四种失效模式与维护习惯（社区，2026-04）✅
- [Claude Code Memory Explained — Jose Parreño Garcia](https://joseparreogarcia.substack.com/p/claude-code-memory-explained) — 层级加载心智模型 + 真实项目示例（社区，2026-02）✅
- [This is why Claude Code sometimes ignores your claude.md — r/ClaudeAI](https://www.reddit.com/r/ClaudeAI/comments/1ldugmg/this_is_why_claude_code_sometimes_ignore_your/) — 揭示 important-instruction-reminders 注入机制（社区，2025-05）
- [The CLAUDE.md Memory System — SFEIR Institute](https://institute.sfeir.com/en/claude-code/claude-code-memory-system-claude-md/faq/) — 结构化写法 FAQ（社区，2025）
- [Optimizing Coding Agent Rules — Arize Blog](https://arize.com/blog/optimizing-coding-agent-rules-claude-md-agents-md-clinerules-cursor-rules-for-improved-accuracy/) — 跨工具 rules 准确率对比（社区，2025）⚠️
- [Adding repository custom instructions for GitHub Copilot — GitHub Docs](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot) — Copilot 官方说明（官方）
- [r/cursor: .cursor/rules MDC files](https://www.reddit.com/r/cursor/comments/1idg434/anyone_else_finding_the_the_new_mdc_cursorrules/) — Cursor MDC 机制（社区，2025-02）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
