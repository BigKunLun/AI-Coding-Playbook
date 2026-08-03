# 014. CLAUDE.md、AGENTS.md、.cursor/rules 三份规则文件，改一处漏两处怎么办？

> 难度：中级
> 主题：上下文工程
> 工具：Claude Code · 横向(Codex / Cursor / Copilot)
> 题型：配置题

> ⏰ 时效声明：**2026-08-03** 核实。截至此日，Claude Code 官方 memory 文档明确写着「Claude Code reads `CLAUDE.md`, not `AGENTS.md`」，并给出 `@AGENTS.md` 导入和 `ln -s` 软链两种官方写法。社区要求原生读 AGENTS.md 的 issue（#6235 及其后续 #31005、#34235）仍处于 open 状态。本篇的「怎么做」以排查方法为主、版本相关的写法为辅；各家工具的规则文件支持变化较快，落地前请用文中的验证命令自己确认一遍。

## TL;DR

一份内容、多个文件名，靠人手抄同步必然漂移。正确做法是**选一个文件当唯一真源，其余文件只做指针**。

具体到今天的工具现状：

- **AGENTS.md 当真源**。它是跨工具的开放格式，Codex、Cursor、Copilot、Gemini CLI、Zed、Aider 等都直接读；agents.md 官网称已有 6 万多个开源项目在用。
- **CLAUDE.md 只写两行**：第一行 `@AGENTS.md` 把真源导进来，下面放 Claude Code 专属的补充。Claude Code 不读 AGENTS.md，但支持 `@路径` 导入，这是官方文档推荐的写法。
- **`.cursor/rules/` 别复制内容**，只留真正需要 `globs` 按路径触发的规则；通用规则交给 Cursor 自己读根目录的 AGENTS.md。
- **不要用软链接当团队方案**。`ln -s AGENTS.md CLAUDE.md` 官方支持、单机可用，但 Windows 上创建软链要管理员权限或开发者模式，跨平台团队会有人 clone 下来是坏的。
- **验证只有一句话**：开一个新会话跑 `/context`，看 **Memory files** 里有没有你期望的文件。没出现就是没加载，别猜。

一句话：真源放 AGENTS.md，CLAUDE.md 用 `@AGENTS.md` 引，改一处三家都生效。

## 为什么

### 1. 三份文件不是三种需求，是三家工具各起了各的名字

同一件事——「告诉 agent 这个项目怎么构建、什么规范、别碰哪些目录」——各家工具约定了不同的文件名：

| 工具 | 读的文件 |
|---|---|
| Claude Code | `CLAUDE.md`、`.claude/rules/*.md` |
| OpenAI Codex / Cursor / Copilot coding agent / Gemini CLI 等 | `AGENTS.md` |
| Cursor（带路径触发的规则） | `.cursor/rules/*.mdc` |
| GitHub Copilot（仓库自定义指令） | `.github/copilot-instructions.md` |

内容高度重叠，文件名不重叠。于是团队里同时装了三种工具的人，就得维护三份几乎一样的 markdown。

漂移不是「可能发生」，是默认结果：改构建命令的人只会改自己那份。下一个用另一个工具的人拿到的是旧指令，agent 照旧指令跑，出问题还很难查——因为文件本身看起来是对的，只是过期了。

### 2. Claude Code 确实不读 AGENTS.md，这不是配置问题

这一点必须说死，因为社区里有不少三方教程写「没有 CLAUDE.md 时 Claude Code 会回退读 AGENTS.md」——**这个说法是错的**，官方文档没有这句话，实际行为也不是这样。

官方 memory 文档原文：`Claude Code reads CLAUDE.md, not AGENTS.md.`

社区从 2025-08 就在提这个需求。issue #6235 至今 open、3000+ 反应、200+ 评论；后续的 #31005、#34235 也都还开着，#34235 被打上了 `duplicate` 标签。也就是说：**不要等原生支持，按现状搭方案。**

### 3. 官方给的解法是「导入」，不是「同步」

Claude Code 的 `@路径` 导入语法是把被导入文件在会话启动时展开进上下文，效果等同于把内容内联写在 CLAUDE.md 里。所以：

- 一份内容、一个物理文件，不存在两份副本对不上。
- 支持相对路径和绝对路径，相对路径相对于**写导入语句的那个文件**，不是当前工作目录。
- 可以递归导入，最多 4 层。

这就是「唯一真源 + 指针」能成立的机制基础。注意它只解决**一致性**，不解决上下文体积——导入的内容照样在启动时全量进上下文，所以真源本身也要控制在 200 行以内（见 [#010 CLAUDE.md 怎么写才真的生效](010-claude-md-how-to-make-it-work.md)）。

### 4. 规则文件是上下文，不是强制配置

顺带提醒一句，这三份文件不管怎么合并，都属于「喂给模型的话」，不是开关。官方文档明确说了：要无条件拦住某个动作，用 PreToolUse hook，别指望写在 CLAUDE.md 里。合并文件解决的是「说的话不一致」，不解决「说了不听」。

## 怎么做

### 第 0 步：先查清楚现在到底加载了什么（排查优先）

在动手改文件之前，先确认现状。任何「我明明写了它却不听」的问题，八成在这一步就能定位。

```bash
# 1. 列出仓库里所有规则文件，看看到底有几份
ls -la CLAUDE.md CLAUDE.local.md AGENTS.md .cursorrules 2>/dev/null
ls -la .claude/rules/ .cursor/rules/ .github/copilot-instructions.md 2>/dev/null

# 2. 找出被复制粘贴的重复内容（有几份就有几处会漂移）
find . -maxdepth 3 \( -name "AGENTS.md" -o -name "CLAUDE.md" \) -not -path "./node_modules/*"
```

然后开一个新的 Claude Code 会话，跑：

```
/context
```

**怎么判断做对了**：`/context` 输出里有一节 **Memory files**，列出本次会话实际加载的文件。你期望的文件出现在这里 = 加载了；没出现 = 没加载，改内容再多也没用。

想更细地看「哪个文件、什么时候、为什么被加载」，可以挂 `InstructionsLoaded` hook 打日志（官方文档提供的调试手段）。

### 第 1 步：把真源定为 AGENTS.md

把当前最完整的那份内容整理进根目录 `AGENTS.md`。选它当真源的理由很简单：直接读它的工具最多，指针要写的份数最少。

```bash
# 假设现在最全的是 CLAUDE.md
git mv CLAUDE.md AGENTS.md
```

**怎么判断做对了**：`git status` 显示重命名而不是删除+新增（历史保留）；Codex / Cursor 这类直接读 AGENTS.md 的工具，开会话后能复述出你写在里面的构建命令。

### 第 2 步：CLAUDE.md 改成两行的指针文件

```bash
cat > CLAUDE.md <<'EOF'
@AGENTS.md

## Claude Code 专属

- 改 `src/billing/` 下的代码前先进 plan mode
EOF
```

要点：

- `@AGENTS.md` 必须**不带反引号**。官方导入解析会跳过行内代码和代码块，写成 `` `@AGENTS.md` `` 就只是普通文字，不会导入。
- Claude 专属内容写在导入之后，位置更靠后，也更贴近「后读到的优先」的直觉。
- 别在 CLAUDE.md 里重抄 AGENTS.md 的任何一句话，一抄就回到漂移。

**怎么判断做对了**：新会话跑 `/context`，Memory files 里同时出现 `CLAUDE.md` 和 `AGENTS.md`；再问一句「本项目的测试命令是什么」，它能答出只写在 AGENTS.md 里的那条。

### 第 3 步：清理 .cursor/rules，只留路径触发的

Cursor 现在同时支持根目录 `AGENTS.md`（纯 markdown，无 frontmatter）和 `.cursor/rules/*.mdc`（带 frontmatter，支持 `globs` / `alwaysApply` / `description`）。注意 `.cursor/rules/` 下的纯 `.md` 文件因为没有 frontmatter 会被规则系统忽略。

分工原则：

- **全局通用规则** → 只留在 AGENTS.md，Cursor 自己会读，`.cursor/rules/` 里删掉。
- **只在改某类文件时才该出现的规则** → 留在 `.cursor/rules/*.mdc`，用 `globs` 限定。

```markdown
---
description: API 层的输入校验与错误格式约定
globs:
  - "src/api/**/*.ts"
alwaysApply: false
---

- 所有接口必须做入参校验
- 错误响应统一用标准 error 结构
```

Claude Code 侧对应的能力是 `.claude/rules/`，frontmatter 字段叫 `paths`：

```markdown
---
paths:
  - "src/api/**/*.ts"
---

- 所有接口必须做入参校验
```

这两个是各家自己的路径触发机制，目前没有跨工具统一格式，属于**必须各写一份**的部分。好消息是这部分体量小、变动少，漂移代价远低于把全局规则抄三遍。

**怎么判断做对了**：`.cursor/rules/` 里的每个文件，都能回答出「为什么它不能挪进 AGENTS.md」——答案必须是「它有 globs，不该常驻」。答不出来的就挪走。

### 第 4 步：monorepo 里用就近文件，不要一份大而全

AGENTS.md 和 Claude Code 的规则加载都遵循目录树逻辑，但**行为不同，别混淆**：

- AGENTS.md 生态（Codex / Cursor / Copilot）：agent 读**目录树上最近的那一份**，就近覆盖。
- Claude Code：从工作目录**向上逐级查找并拼接**，全部进上下文而不是互相覆盖；子目录下的 CLAUDE.md 则在 Claude 读到该目录文件时按需加载。

所以 monorepo 里的做法是：根目录放跨包共用的，各 package 目录下放自己的，两边都别写「全仓所有细节」。相关坑见 [#050 大仓库 / monorepo 怎么让它不迷路](../06-engineering-collab/050-claude-code-in-monorepo.md)。

Claude Code 侧如果被别的团队的 CLAUDE.md 污染了，用 `claudeMdExcludes` 排除（放在 `.claude/settings.local.json`，只影响你自己）：

```json
{
  "claudeMdExcludes": ["**/monorepo/other-team/CLAUDE.md"]
}
```

### 第 5 步：加一道 CI 防线，堵住重新抄回来

方案能不能活下去，取决于有没有人偷偷往 CLAUDE.md 里加内容。加一个几行的检查：

```bash
#!/usr/bin/env bash
# scripts/check-agent-rules.sh —— CLAUDE.md 必须是指针文件
set -euo pipefail

grep -q '^@AGENTS\.md' CLAUDE.md || {
  echo "✗ CLAUDE.md 缺少 @AGENTS.md 导入行"; exit 1; }

lines=$(grep -vc '^\s*$' CLAUDE.md)
if [ "$lines" -gt 20 ]; then
  echo "✗ CLAUDE.md 有 $lines 行非空内容，超过 20 行：通用规则请写进 AGENTS.md"
  exit 1
fi
echo "✅ CLAUDE.md 仍是指针文件"
```

**怎么判断做对了**：故意往 CLAUDE.md 里粘 30 行通用规范，跑脚本应该退出码非 0 并报错；恢复后应该通过。

## Claude Code 实战

**已有 AGENTS.md、想让 Claude Code 一次性接上：**

```bash
# 在项目根目录
claude
> /init
```

`/init` 会读已有的 Cursor 规则（`.cursor/rules/` 或 `.cursorrules`）和 Copilot 规则（`.github/copilot-instructions.md`），把相关部分并进生成的 CLAUDE.md。想让它同时读 `AGENTS.md`、`.devin/rules/`、`.windsurf/rules/`、`.clinerules`，要开新版 init：

```bash
CLAUDE_CODE_NEW_INIT=1 claude
> /init
```

注意 `/init` 是**一次性的引导工具**，它做的是合并快照，不是持续同步。跑完之后仍然要按第 2 步把 CLAUDE.md 改成指针文件，否则你只是又造了一份副本。

**查看和编辑所有规则文件：**

```
/memory
```

它会列出用户级、项目级的各个 memory 文件位置（包括还不存在的），选中即打开编辑器。

**注意 `/memory` 和 `/context` 的区别**：`/memory` 列的是「有哪些位置」，`/context` 列的是「本次会话真的加载了什么」。排查加载问题一律用 `/context`。

**跨 worktree 的个人偏好**：`CLAUDE.local.md` 被 gitignore 后只存在于你创建它的那个 worktree。要跨 worktree 共享，改成从家目录导入：

```markdown
# 个人偏好
- @~/.claude/my-project-instructions.md
```

项目级文件里出现指向工作目录之外的导入时，Claude Code 第一次会弹审批对话框——这是防止别人往共享项目里提交外部导入。选了拒绝之后就不再弹，也不会加载。

**软链接方案（可用但有前提）：**

```bash
ln -s AGENTS.md CLAUDE.md
```

成功时没有任何输出。下次开会话跑 `/context` 确认 `CLAUDE.md` 出现在 Memory files 里。

适用条件：**你完全没有 Claude 专属内容**，且团队全员非 Windows。Windows 上创建软链需要管理员权限或开发者模式，跨平台团队请用 `@AGENTS.md` 导入。git 侧还需要 `core.symlinks=true` 才能正确 clone 出软链。

## 横向对比

| 工具 | 读什么 | 要不要单独维护 | 备注 |
|---|---|---|---|
| Claude Code | `CLAUDE.md` + `.claude/rules/*.md` | 要一个两行指针文件 | 不读 AGENTS.md；`@路径` 导入最多 4 层 |
| OpenAI Codex | `AGENTS.md` | 不用 | 直接读真源 |
| Cursor | `AGENTS.md` + `.cursor/rules/*.mdc` | 只有 globs 规则要单写 | `.cursor/rules/` 下无 frontmatter 的 `.md` 被忽略 |
| GitHub Copilot | `AGENTS.md` + `.github/copilot-instructions.md`（coding agent 还会读 `CLAUDE.md` / `GEMINI.md`） | 不用 | 两者同属仓库级，个人指令优先级更高 |
| Gemini CLI / Zed / Aider / Windsurf 等 | `AGENTS.md` | 不用 | agents.md 官网列的支持工具还在增加 |

结论：把真源放在 AGENTS.md，需要额外写指针的只有 Claude Code 一家。

## 反模式

- ❌ **复制粘贴同步三份文件** —— 没有任何机制保证一致，改一处漏两处是默认结果，不是意外。
- ❌ **信「Claude Code 没有 CLAUDE.md 时会回退读 AGENTS.md」** —— 官方文档没这句话，实测也不是。按这个假设搭出来的项目，Claude Code 全程零指令在跑，你还以为它读到了。
- ❌ **写成 `` `@AGENTS.md` ``（带反引号）** —— 导入解析会跳过代码块和行内代码，加了反引号就变成一行普通文字，什么都不会导入。
- ❌ **团队方案用软链接** —— Windows 成员 clone 出来是坏的或需要提权，而且这个失败是静默的：文件看着在，内容却读不到。
- ❌ **等官方原生支持 AGENTS.md** —— 需求从 2025-08 提到现在，主 issue 3000+ 反应仍 open，没有官方承诺时间表。
- ❌ **合并完就以为规则会被严格执行** —— 这些文件是上下文不是配置，要硬拦某个动作得用 PreToolUse hook。
- ❌ **把 monorepo 全部细节堆进根目录一份文件** —— 上下文爆掉、遵守率下降，正确做法是按目录分层放。

## 延伸

**交叉引用：**

- [#010 CLAUDE.md 怎么写才真的生效？](010-claude-md-how-to-make-it-work.md) —— 真源本身怎么写才被遵守
- [#012 上下文窗口要爆了怎么办？](012-context-window-exploding.md) —— 导入不省 token，合并后仍要控体积
- [#050 大仓库 / monorepo 怎么让它不迷路](../06-engineering-collab/050-claude-code-in-monorepo.md) —— 分层放规则文件的完整做法
- [#075 团队的 AI coding 规范怎么立？哪些该强制、哪些该自由？](../08-team-and-org/075-team-ai-coding-standards.md) —— 规范内容本身怎么定

**参考资料：**

- [Claude Code 官方文档：How Claude remembers your project](https://code.claude.com/docs/en/memory) — 明确「不读 AGENTS.md」，给出 `@AGENTS.md` 导入与 `ln -s` 两种官方写法、`.claude/rules/` 的 `paths` 字段、`claudeMdExcludes`、`/context` 与 `/memory` 的区别（官方，2026-08 访问）
- [agents.md 官网](https://agents.md/) — AGENTS.md 格式说明、支持工具清单、6 万+ 项目采用、monorepo 就近覆盖行为（官方，2026-08 访问）
- [Cursor 官方文档：Rules](https://cursor.com/docs/context/rules) — `.cursor/rules/*.mdc` 的 frontmatter 字段与「无 frontmatter 的 .md 被忽略」（官方，2026-08 访问）
- [GitHub Changelog：Copilot coding agent now supports AGENTS.md](https://github.blog/changelog/2025-08-28-copilot-coding-agent-now-supports-agents-md-custom-instructions/) — Copilot 侧同时支持 AGENTS.md 与 copilot-instructions.md（官方，2025-08）
- [GH issue #31005：Support for AGENTS.md and .agents/skills/](https://github.com/anthropics/claude-code/issues/31005) — 汇总了从 2025-08 至今的 6 个相关 issue 及其状态（社区，2026-08 访问）
- [GH issue #34235：Support AGENTS.md as Native Context File](https://github.com/anthropics/claude-code/issues/34235) — open 且被标 `duplicate`，评论区给出「CLAUDE.md 只做文件清单」的变体写法（社区，2026-08 访问）
- [agyn.io：AGENTS.md vs CLAUDE.md, Does Claude Code or Codex Read Both?](https://agyn.io/blog/claude-md-agents-md-compatibility) — 手工维护两份一周就漂移的实践记录，以及「导入优于软链」的理由（实践，2026-08 访问）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
