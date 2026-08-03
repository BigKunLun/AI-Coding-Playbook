# 050. 代码库一大 agent 就开始瞎找文件、抓错同名符号——大仓库 / monorepo 怎么让它不迷路

> 难度：中级
> 主题：工程协作
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：配置题

> ⏰ 时效声明：本篇全部配置键（`claudeMdExcludes`、`permissions.deny` 的 Read 规则、`worktree.sparsePaths`/`symlinkDirectories`、`additionalDirectories`/`--add-dir` 及其加载差异表）已于 **2026-07-18** 对照官方 [large-codebases 文档](https://code.claude.com/docs/en/large-codebases)逐项核实，键名与语义准确。配置面随版本迭代快，动手前请以官方为准。

> 名词说明：Monorepo 指「一个 git 仓库里放多个相对独立的包/子项目」。本篇也叫它「多包单仓」。

## TL;DR

Monorepo 里 Claude「迷路」和「跨包裂开」是两个不同的问题，各有各的解法。

**问题一：不迷路，靠上下文切片。** 上下文指 Claude 一次能看到的信息窗口。别指望一个根目录的 `CLAUDE.md` 覆盖所有包。官方给了一整套按目录分层的配置：每个包一份 `CLAUDE.md` 写自己的约定、从包目录启动只加载该包和根目录的内容、用 `claudeMdExcludes` 排除永不碰的包、用 `Read` deny 规则和 `worktree.sparsePaths` 挡掉生成物、只签出需要的目录。这些设置可以叠加使用，按仓库情况挑着用。

**问题二：跨包不裂，靠原子改动加计划落盘。** 改一个共享类型要连带改所有调用方时，官方两条要求：把整个改动放在一个会话里做完、动手前先让 Claude 把计划写进 markdown 文件。社区再补一条：受影响的所有包一次性提交。

一句话切边界：本篇讲的是「利用 monorepo 的目录结构主动给上下文切片」的配置题。通用 CLAUDE.md 写法见 [#010](../02-context-engineering/010-claude-md-how-to-make-it-work.md)。上下文窗口爆掉的通用机制见 [#012](../02-context-engineering/012-context-window-exploding.md)。跨多个仓库（不是单仓多包）见 [#051](./051-working-across-multiple-repos.md)。跨包提交和 PR 的 git 侧见 [#052](./052-git-workflow-with-ai.md)。

## 为什么

### 1. Monorepo 的默认行为会把上下文喂脏

官方 large-codebases 文档开门见山点破根因：仓库变大后，为小项目调好的默认设置会把上下文窗口塞满与任务无关的指令和文件读取，既烧 token 又拉低 Claude 的表现。

> "as the codebase grows, the defaults tuned for smaller projects can **fill the context window with instructions and file reads unrelated to the task**, costing tokens and degrading Claude's performance."
> — [Claude Code Docs: Set up Claude Code in a monorepo or large codebase](https://code.claude.com/docs/en/large-codebases)（官方，2026-07）

举个例子：一个有 20 个包的 monorepo，你说「读一下代码库」，Claude 会把 15 个不相关包的约定和文件全塞进上下文。社区把这个后果说得很直白：把全部 15 个包灌进上下文，只会增加噪音，不会改善输出质量。

> "Flooding the context with all 15 packages increases noise without improving output quality."
> — [Phos AI Labs](https://phosailabs.com/blog/claude-code-monorepos)（社区，2026-04）

这和 [#012](../02-context-engineering/012-context-window-exploding.md) 讲的窗口爆炸是同一类病。但 monorepo 多给了一个通用仓没有的解法：用目录结构做切片。

### 2. 关键心智：从哪里启动，决定了 Claude 看得见什么

这是本篇最重要的一条，也是社区反复强调的第一条实践。官方把它做成一张表：

| 从哪启动 | 文件访问范围 | 启动时加载的 CLAUDE.md | 何时用 |
|---------|------------|----------------------|--------|
| 仓库根 | 每个文件 | 只有根；子目录文件按需加载 | 任务跨多个包/子系统 |
| 某个子目录 | 只有那个子树，除非再授权 | 该目录 + 所有祖先目录的 | 工作范围就在一个包内 |

来源：[Claude Code Docs](https://code.claude.com/docs/en/large-codebases)（官方，2026-07）。

官方对「从包目录启动」的描述是：从 `packages/api/` 启动时，Claude 会同时加载 `packages/api/CLAUDE.md` 和根目录的 `CLAUDE.md`，也就是既看到本包的局部指令、又看到全仓规则，但 `packages/web/` 的任何指令都不会进上下文。

> "When you start Claude from `packages/api/`, it loads both `packages/api/CLAUDE.md` and the root `CLAUDE.md`. Claude sees the local instructions alongside the repository-wide rules, **with no instructions from `packages/web/` in context**."

结论：单包任务就从那个包的目录启动。文件读取天然被框在包内，`web/` 的约定根本不进上下文。这是零配置就能拿到的最大收益。

### 3. 跨包改动为什么会裂开

社区把跨包改动列为 monorepo 开发里风险最高的一类操作。

> "the highest-risk category in monorepo development"
> — Phos AI Labs（社区，2026-04）

裂开有两种情况。

第一种是改一半丢了上下文。改共享类型时会话往往很长，中途 Claude 会做 compact（把旧对话压缩掉腾出空间），压缩后它可能忘了还有几个调用方没改。

第二种是 build 出现破窗。如果把改动拆成多个 commit，就会留下「改了共享类型、调用方还没跟上」的中间态，这个中间态的 build 是坏的。

> "cross-package changes that are split across multiple commits create windows where the build is broken"
> — [Phos AI Labs](https://phosailabs.com/blog/claude-code-monorepos)（社区，2026-04）

官方对这个问题给的是流程约束，不是配置项，具体见下面「怎么做」的 B 组：一个会话做完加上计划落盘。

## 怎么做

分两组。A 组让 Claude 不迷路，靠上下文切片配置。B 组让跨包改动不裂开，靠流程约束。A 组的设置可以叠加使用，按需挑用。

### A 组：上下文切片配置（checklist）

**1. 分层写 CLAUDE.md。** 根目录只放哪里都适用的内容，比如编码规范、commit 约定、仓库布局。每个包放自己那套技术栈的约定，比如跑测试的命令、路由在哪、禁止写裸 SQL 等。这些文件提交进 git，每个目录由它的 owner 维护自己那份。

**2. 单包任务从包目录启动。** 原理见上面「为什么」第 2 点。这是收益最大、成本最低的一步。

**3. 用 `claudeMdExcludes` 排除永不碰的包。** 适合排除别的团队的包、遗留代码、以及第三方拷进来的子树。注意它是静态排除，不是「今天聚焦这个包」的开关。要临时聚焦，靠「从包目录启动」，而不是天天改这个排除列表。

```json
// .claude/settings.local.json（个人用；手动创建的要自己加进 .gitignore）
{ "claudeMdExcludes": ["**/packages/admin-dashboard/**", "**/packages/legacy-*/**"] }
```

> 管理策略（managed policy，即组织统一下发的强制配置）级别的 CLAUDE.md 排除不掉，组织级指令永远生效。

**4. 用 `Read` deny 规则挡掉生成物和第三方代码。** `.gitignore` 里的目录（如 `node_modules/`、`dist/`）搜索时默认已跳过。但已经提交进仓库的生成代码、或拷进来的第三方 SDK，需要显式 deny。

```json
// .claude/settings.json（提交，全仓生效）
{ "permissions": { "deny": ["Read(./**/dist/**)", "Read(./**/build/**)", "Read(./**/*.generated.*)", "Read(./vendor/**)"] } }
```

> 注意：deny 会覆盖内建文件工具以及 `cat`/`grep`/`find` 等命令，但不会从递归搜索的结果里过滤掉这些文件，也管不住 Claude 自己开的子进程去读。

**5. 用 code intelligence 插件替代全文扫描。** 大仓里「找某个符号在哪定义、被谁调用」会烧掉大量文件读取。装一个 LSP 插件（语言服务器，能提供跳定义、找引用的能力），让 Claude 直接跳转，而不是逐个读文件去定位。安装命令是 `/plugin install typescript-lsp@claude-plugins-official`。它和第 3、4 步互补：那两步挡掉无关内容，这步让 Claude 不用逐个读文件。

**6. 用 per-directory skills 按需加载操作流程。** skills 指封装好的操作流程。把某个包专属的流程（比如 API 包的测试套路）放进 `packages/api/.claude/skills/`，Claude 只在该包工作时才加载，做前端任务时不占上下文。描述要写短，把请求会用到的关键词放在前面（例如 "writing or modifying tests in `packages/api/`"），因为 skill 一多，描述会被截断。

**7. 用 `worktree.sparsePaths` 只签出需要的目录。** 用 `--worktree` 隔离改动时，默认会签出整个仓库。`sparsePaths` 让它只签出列出的目录加根级文件，worktree 起得更快、更省磁盘。再配上 `symlinkDirectories: ["node_modules"]`，避免每个 worktree 各存一份依赖。

```json
{ "worktree": { "sparsePaths": [".claude", "packages/api", "packages/shared"], "symlinkDirectories": ["node_modules"] } }
```

> 坑：`sparsePaths` 的路径相对仓库根，不管你从哪个子目录启动。根级目录不会自动带上，想要根目录的 `.claude/`，必须把 `.claude` 显式列进去。

### B 组：跨包改动不裂开（流程）

**8. 整个改动放在一个会话里做。** 把共享类型的改动和它的调用方一起交给 Claude，别分包开会话。官方的理由是：一起交出去，每处改动背后的决策能保持一致；分包做会重新推导，决策就不一致了。

> "handing over the shared edit and its call sites together keeps the decisions behind each edit consistent, rather than re-deriving them per package"
> — [官方](https://code.claude.com/docs/en/large-codebases)

**9. 动手前先让 Claude 把计划写进 markdown 文件。** 长的跨包会话会一路 compact 掉上下文，而落盘的计划能活过对话历史。

> "A long cross-package session compacts its context along the way, and **the saved plan survives where conversation history may not**"
> — [官方](https://code.claude.com/docs/en/large-codebases)

**10. 跨包一次性提交。** 受影响的所有包一起提交，别拆开留破窗（[Phos AI Labs](https://phosailabs.com/blog/claude-code-monorepos)，社区，2026-04）。commit 和 PR 的 git 侧展开见 [#052](./052-git-workflow-with-ai.md)。

**11. 给一条 build 验证命令当终止条件。** prompt 里点名受影响的包，再给一条构建校验命令（如 `pnpm turbo build`），让 Claude 有明确的成功/失败信号，能自己闭环（社区，2026-04）。

## Claude Code 实战

### 跨包访问：从 `packages/api/` 改 `shared/`

从包目录启动是好，但真要改共享类型时，又需要碰到同级的其他包。官方给了两条路，关键区别在于：会不会连带加载那个目录的 CLAUDE.md 和 skills。

| 加法 | 加载 CLAUDE.md/rules | 加载 skills |
|------|---------------------|------------|
| `additionalDirectories` 设置 | 从不 | 从不 |
| `--add-dir` 标志 / `/add-dir` 命令 | 仅当设了下面的环境变量 | 会 |

来源：[Claude Code Docs](https://code.claude.com/docs/en/large-codebases)（官方，2026-07）。

```bash
# 临时给一个同级包读写权（只给文件访问，不带它的记忆/技能）
claude --add-dir ../shared

# 想连带加载 ../shared 的 CLAUDE.md 和 rules，加环境变量
CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude --add-dir ../shared
```

```json
// 固定给本包所有人的同级包访问，提交进 packages/api/.claude/settings.json
{ "permissions": { "additionalDirectories": ["../shared", "../web"] } }
```

临时跨包看一眼共享类型时，`--add-dir` 是社区推荐的轻量做法（[Phos AI Labs](https://phosailabs.com/blog/claude-code-monorepos)，社区，2026-04）。但要清楚一点：官方明确说，不管你用哪种方式加目录，Claude 都能读和改里面的文件，也就是 `--add-dir` 给的是读写权，不是只读。别指望它挡住对同级包的写入。

> "However you add a directory, Claude can read and edit files in it."
> — [官方](https://code.claude.com/docs/en/large-codebases)

### 一个跨包改动的完整对话骨架

任务：给 `shared` 的 `User` 类型加一个 `role` 字段，`api` 和 `web` 都要跟上。

```
# 从仓库根启动（跨包任务）
1. "先探明：packages/ 下哪些包 import 了 shared 的 User 类型？把受影响的调用点列出来，
    写进 docs/plan-user-role.md，先别改代码。"          ← 落盘计划（步骤 9）
2. 人审 plan 文件，确认调用点没漏。
3. "按 plan 一次性改完 shared + api + web 三个包，改完跑 `pnpm turbo build` 验证。"  ← 一个会话 + build 校验（步骤 8、11）
4. "三个包一起 commit，一条 message。"                    ← 原子 commit（步骤 10）
```

要点：探查、落盘、一次改完、一次提交，全程一个会话，计划写在文件里，兜底 compact。

### `claudeMdExcludes` 和「从子目录启动」，别搞混

两者都能让 `web/` 的约定不进上下文，但语义不同。`claudeMdExcludes` 是静态永久排除，意思是「这个包我永远不碰」。从子目录启动是本次会话的作用域，意思是「今天只干 `api/`」。官方明说：想「今天聚焦这个包、明天聚焦那个」，就用「从那个包目录启动」，而不是天天改排除列表。

## 横向对比

| 工具 | monorepo 上下文切片解法 | 差异 |
|------|----------------------|------|
| **Claude Code** | per-dir CLAUDE.md + 从包目录启动 + `claudeMdExcludes` + `Read` deny + `sparsePaths` + per-dir skills + `--add-dir` | 层级最全，配置项覆盖「记忆分层 / 文件读取 / worktree / 跨包访问」四条轴；官方有 monorepo 专档 |
| **Cursor** | `.cursor/rules/*.mdc`（`globs` frontmatter 按路径激活）+ `.cursorignore` | 靠 glob 规则做路径作用域，无「从子目录启动即切片」的会话作用域概念；索引整仓 |
| **GitHub Copilot** | `.github/copilot-instructions.md`（仓库根单文件）+ `.github/instructions/*.instructions.md`（可加 `applyTo` glob） | 单文件为主，路径作用域较新且弱；无 worktree/sparse-checkout 类物理切片 |

核心差异一句话：Claude Code 把「上下文切片」拆成四条各自独立、可以自由组合的轴——记忆分层（CLAUDE.md）、文件读取（deny 和 LSP）、磁盘签出（sparsePaths）、跨包授权（--add-dir）。Cursor 和 Copilot 主要只落在「按 glob 加载规则」这一条上。跨多个仓库的对比见 [#051](./051-working-across-multiple-repos.md)。

## 反模式

- ❌ **一个根 CLAUDE.md 塞下所有包的约定。** 要么膨胀到烧光上下文预算（官方原话：会用与任务无关的指令填满上下文窗口），要么泛到没用。应该分层，每个目录一份。
- ❌ **单包任务也从仓库根启动。** 白白让 15 个无关包的记忆和文件有机会进上下文。单包就从包目录启动，天然框住范围。
- ❌ **把 `claudeMdExcludes` 当「今天聚焦哪个包」的开关。** 它是静态排除，不是任务级开关。临时聚焦靠从包目录启动。
- ❌ **跨包改动分成多个会话、逐包改。** 会重新推导、决策不一致。共享类型的改动和它的调用方要在一个会话里一起给。
- ❌ **跨包改动拆成多个 commit。** 会留下 build 崩掉的破窗，也就是改了共享类型、调用方还没跟上的中间态。应该所有受影响的包一次提交。
- ❌ **长跨包会话不落盘计划。** 一旦 compact，计划就丢了，Claude 会漏掉没改的调用方。动手前先把计划写进 markdown 文件。
- ❌ **以为 `@import` 能省上下文。** `@` 引用只改善组织结构，被引用的文件在启动时仍会全量加载，不省 token（[#010](../02-context-engineering/010-claude-md-how-to-make-it-work.md) 已详述）。要做到按需加载，用带 `paths` 的 rules 或 per-dir skills。

## 延伸

**交叉引用：**
- [#010 CLAUDE.md 怎么写才真的生效？](../02-context-engineering/010-claude-md-how-to-make-it-work.md) —— 通用 CLAUDE.md 写法与加载层级，本篇是它在 monorepo 多层目录下的应用。
- [#012 上下文窗口要爆了怎么办？](../02-context-engineering/012-context-window-exploding.md) —— 窗口爆炸的通用机制，本篇是「用目录结构切片」这一类结构对策。
- [#051 前后端分仓，让 AI 改一个字段它只改了一边怎么办？（跨仓工作区 + 接口契约治理）](./051-working-across-multiple-repos.md) —— 跨多个仓库（非单仓多包）的 workspace 编排与契约同步。
- [#052 AI 写代码怎么和 git 流程配合？分支策略、commit、PR 怎么不让 AI 搞乱？](./052-git-workflow-with-ai.md) —— 跨包 commit/PR 的分支与提交流程侧展开。

**参考资料：**
- [Set up Claude Code in a monorepo or large codebase — Claude Code Docs](https://code.claude.com/docs/en/large-codebases) —— 本篇权威源，per-dir CLAUDE.md / claudeMdExcludes / Read deny / sparsePaths / per-dir skills / --add-dir / 跨包两条法则全部出自此（官方，2026-07）
- [Claude Code with Monorepos — Phos AI Labs](https://phosailabs.com/blog/claude-code-monorepos) —— 把跨包改动列为最高风险类，原子 commit、build 破窗、--add-dir 读写访问（社区，2026-04）
- [Claude Code for Monorepo Development — lowcode.agency](https://www.lowcode.agency/blog/claude-code-monorepo) —— 从包目录启动做上下文切片、分层 CLAUDE.md 的实践复述（社区，2026）⚠️
- [How I Organized My CLAUDE.md in a Monorepo — dev.to/anvodev](https://dev.to/anvodev/how-i-organized-my-claudemd-in-a-monorepo-with-too-many-contexts-37k7) —— CLAUDE.md 过大（47k 词）踩坑与拆分、@ 引用不省 load（社区）⚠️

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
