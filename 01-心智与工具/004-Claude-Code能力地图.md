# 004. CLAUDE.md、skill、subagent、hooks、plan mode——这几个到底该用哪个？

> 难度：中级
> 主题：心智与工具
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：配置题 + 决策题

> ⏰ 时效声明：**2026-08-03** 复核。本篇的权限档、hooks JSON 结构、skill / subagent 文件路径与 frontmatter 字段，均已对照官方文档原页逐条核对（permission-modes / hooks / skills / sub-agents / memory / features-overview 六页）。分类框架是方法论，长期有效；具体路径、字段名、快捷键会随版本变化，以官方文档为准。本篇涉及版本行为的地方都标了最低版本号。

## TL;DR

001 讲了 Claude Code 是什么，003 讲了心智怎么转。真上手后你多半会撞到第二堵墙：Claude Code 里散着一堆"能力"——plan mode、skill、subagent、CLAUDE.md、hooks、权限档。文档里每个都查得到，但你分不清各自是什么、什么时候该想到哪个，于是要么全不用，要么把该写 CLAUDE.md 的事塞进 skill。

三点速记：

1. **按"解决什么问题"分四类，别按官方文档目录分。** 四类是：管上下文（CLAUDE.md / auto memory）、管节奏与闸门（permission modes 含 plan、hooks）、管复用（skill）、管并行与隔离（subagent）。先问"我要解决什么"，就知道该拿哪一类。
2. **每类都有一个可直接复制的最小起步件。** 下面那张表每行都带"最小可跑示例"——一条命令、一个路径、一段 JSON，查完就能动手，不用再跳文档。
3. **它们之间有明确的取舍关系。** CLAUDE.md 管事实、skill 管流程；CLAUDE.md 是建议、hooks 是硬执行；subagent 在隔离窗口跑、skill 在主会话加载。这三组取舍官方都有正面说法，见正文决策树。

一句话：本篇给地图、最小起步件和入口，每项怎么深用见指针（plan 见 031、subagent 见 032、skill 见 033、CLAUDE.md 与 hooks 见 010）。

## 为什么

### 1. 这堆能力为什么让人晕

003 讲到第 3 层 Orchestration 心智时留了一句指针：要从"和一个工程师结对"升级到"设计一个放大判断力的系统"，得用 skill / subagent / CLAUDE.md 这套工具（详见 [003 第 3 层](./003-AI代码审不动改不懂.md)）。

可读者真去查时会撞到两件事。

第一，文档是按机制分页的。[permission-modes](https://code.claude.com/docs/en/permission-modes)、[sub-agents](https://code.claude.com/docs/en/sub-agents)、[skills](https://code.claude.com/docs/en/skills)、[memory](https://code.claude.com/docs/en/memory)、[hooks](https://code.claude.com/docs/en/hooks) 各占一页，每页都在讲"这个机制怎么配"，不讲"我这个场景该选哪个"。

第二，即使官方后来补了一页汇总（[Extend Claude Code](https://code.claude.com/docs/en/features-overview)，官方，访问日期 2026-08），那页也是从"扩展点"视角切的，把 code intelligence、artifacts、plugins 一并列进来，一次要消化十来个概念。对只想知道"我现在这个活该用哪个"的人来说还是太宽。

本篇要补的就是中间那一层：按"解决什么问题"收成四类，每类给一个能直接跑的最小件，再给一棵有分支的决策树。攻略细节一律归 04 / 02 段。

### 2. 按"解决什么问题"分类，比按文档目录分更好决策

官方的 [Extend Claude Code](https://code.claude.com/docs/en/features-overview) 页里有一节 "Build your setup over time"，用的正是"触发条件 → 加什么"的写法，比如"Claude gets a convention or command wrong twice → Add it to CLAUDE.md"（Claude 同一个约定或命令错了第二次，就写进 CLAUDE.md）、"A side task floods your conversation with output you won't reference again → Route it through a subagent"（一个支线任务用你不会再看的输出淹了会话，就走 subagent）（官方，访问日期 2026-08）。

这说明"按触发场景选，而不是按机制学"是官方认的路子。本篇在此之上再收一层，归成四类：

- **管上下文**：CLAUDE.md（你写的、每次会话自动加载的常驻指令）和 auto memory（Claude 自己写的跨会话笔记），解决"有些事每次都要让它知道"。
- **管节奏与闸门**：permission modes（含 plan 在内的权限档）、hooks（生命周期事件上的确定性闸门），解决"我要在哪个环节按住它、放多少权"。
- **管复用**：skill（按需加载的流程和参考资料），解决"这套流程我反复粘贴"。
- **管并行与隔离**：subagent（独立上下文窗口的 worker），解决"这段活会淹没主会话"或"我想并行干"。

> 边界说明：001 答"它是什么、和别的工具有什么区别"，003 答"心智怎么转"，004 答"内部这堆能力各是啥、何时想到哪个"。本篇每项只给定位、何时用、最小起步件和指针。

## 怎么做

### 第一交付物：能力地图（四类分类表）

下表是本篇核心。「最小可跑示例」那列是拿来直接抄的，抄完照后面的验证方法确认一下就行。

| 能力 | 分类 | 一句话定位（官方依据） | 何时用 | 最小可跑示例 | 深用指针 |
|------|------|------------------------|--------|--------------|----------|
| **CLAUDE.md** | 管上下文 | 你写的持久指令，每次会话开始时自动加载全文（[CC Docs: memory](https://code.claude.com/docs/en/memory)，官方，2026-08）。 | 项目事实、技术栈、构建命令、团队约定要每次生效时写进去。目标 200 行以内。 | 项目级放 `./CLAUDE.md` 或 `./.claude/CLAUDE.md`；个人级放 `~/.claude/CLAUDE.md`。不想手写就在会话里跑 `/init` 生成初稿。 | [010 CLAUDE.md 怎么写才真的生效](../02-上下文工程/010-CLAUDE-md怎么写才生效.md) |
| **auto memory** | 管上下文 | Claude 自己写的跨会话笔记，默认开启，存在 `~/.claude/projects/<project>/memory/`，每次会话只加载 `MEMORY.md` 的前 200 行或 25KB（官方，2026-08）。与 CLAUDE.md 的差别就一句：**CLAUDE.md 是你写规则，auto memory 是它记发现**。 | 你不想手动维护、但希望它自己攒下来的东西：构建命令、调试踩坑、你纠正过的偏好。 | 会话里跑 `/memory` 浏览和开关；单个项目关掉就在 `.claude/settings.json` 写 `{"autoMemoryEnabled": false}`。 | [013 哪些决策要写进 memory](../02-上下文工程/013-哪些决策要写进memory.md) |
| **permission modes**（含 plan） | 管节奏 | 控制 Claude 多频繁停下来问你的权限档，官方表里共 6 档：`default`（只读，CLI 里标签叫 Manual）、`acceptEdits`、`plan`、`auto`、`dontAsk`、`bypassPermissions`。**plan 就是其中一档**，不是叠在别的档上的修饰（[CC Docs: permission-modes](https://code.claude.com/docs/en/permission-modes)，官方，2026-08）。 | 敏感活用 `default`；迭代改代码用 `acceptEdits`；动手前先想清楚用 `plan`；长任务减少打断用 `auto`；CI 脚本用 `dontAsk`；`bypassPermissions` 只在容器或虚拟机里用。 | 启动时带档：`claude --permission-mode plan`。会话里按 `Shift+Tab` 循环 `default → acceptEdits → plan`，所以进 plan 是连按两次。也可以只给一条 prompt 加 `/plan` 前缀。 | [031 plan→execute→review 循环](../04-执行工作流/031-plan-execute-review循环.md) |
| **hooks** | 管节奏 | 写在 settings.json 的 `hooks` 键下的确定性闸门，在 `PreToolUse`、`PostToolUse`、`Stop`、`SessionStart` 等生命周期事件上跑东西，由 Claude Code 本身执行，不靠 Claude 自觉。官方原话：一条"never edit `.env`"写在 CLAUDE.md 或 skill 里 "is a request, not a guarantee"（是个请求，不是保证），而 `PreToolUse` hook 才是 enforcement（强制）（[CC Docs: features-overview](https://code.claude.com/docs/en/features-overview)，官方，2026-08）。 | 必须每次都发生、且不需要 Claude 动脑的事：编辑后跑 lint、拦掉危险命令、会话结束发通知。 | 见下方「hooks 最小可跑配置」代码块，直接贴进 `.claude/settings.json`。 | 本库暂无 hooks 独立篇；配置写法见 [010 的「该用 hook 的别写进 CLAUDE.md」](../02-上下文工程/010-CLAUDE-md怎么写才生效.md)，跑测试类 hook 的用法见 [033](../04-执行工作流/033-Skill与superpowers怎么用.md)。官方全表见 [CC Docs: hooks](https://code.claude.com/docs/en/hooks) |
| **skill** | 管复用 | 按需加载的流程和参考资料，会话开始只加载描述、用到才加载正文。官方触发信号逐字："Create a skill when you keep pasting the same instructions, checklist, or multi-step procedure into chat, or when a section of CLAUDE.md has grown into a procedure rather than a fact"，意思是"当你反复往聊天里粘同一套指令、清单或多步流程，或者 CLAUDE.md 里某节从一条事实长成了一套流程时，就该做一个 skill"（[CC Docs: skills](https://code.claude.com/docs/en/skills)，官方，2026-08）。 | 同一段流程或检查清单反复粘贴（3 次以上），或 CLAUDE.md 某节变成了流程。 | 项目级：`.claude/skills/<名字>/SKILL.md`；个人级：`~/.claude/skills/<名字>/SKILL.md`。见下方「skill 最小可跑骨架」。目录名就是斜杠命令名。 | [033 skill 与 superpowers 怎么用](../04-执行工作流/033-Skill与superpowers怎么用.md) |
| **subagent** | 管并行 | 独立上下文窗口的 worker，只把摘要回给主会话。官方原文 "a side task would flood your main conversation with search results, logs, or file contents you won't reference again: the subagent does that work in its own context and returns only the summary"，意思是"一个支线任务会拿你不会再看的搜索结果、日志、文件内容淹掉主会话；subagent 在自己的上下文里干完，只回摘要"（[CC Docs: sub-agents](https://code.claude.com/docs/en/sub-agents)，官方，2026-08）。 | 冗长输出要隔离（跑测试、读大量日志）、有两个以上独立子任务要并行、或需要一个工具受限的专用 worker。 | 临时用不用建文件，直接在 prompt 里点名：`Use the code-reviewer subagent to review the authentication module`（官方示例句式）。要固化就建 `.claude/agents/<名字>.md`，骨架见下方。 | [032 SubAgent 何时派、怎么派](../04-执行工作流/032-SubAgent并行开几个.md) |

> **表里为什么没有 TDD。** TDD 是你的工作方法，不是 Claude Code 的一项能力，放进这张"能力表"会让人以为 CC 里有个叫 TDD 的功能。它的正确位置是上面两项的配套做法：先写一个会失败的测试当终止条件，再用 `PostToolUse` 或 `Stop` hook 把"跑测试"变成每次必发生的事。官方在 best-practices 里的说法是 "Give Claude something that produces a pass or fail, and the loop closes on its own"，意思是"给 Claude 一个能判定通过或失败的东西，循环就会自己收口"（[CC Docs: best-practices](https://code.claude.com/docs/en/best-practices)，官方，访问日期 2026-08）。做法见 [030 TDD 在 AI coding 里怎么做](../04-执行工作流/030-AI写的测试不可信.md)。

> **表里也没有 MCP 和 agent team。** MCP 是"接外部数据和工具"，官方定位 "MCP connects Claude to data; Skills teach Claude what to do with that data"（MCP 把 Claude 接到数据，skill 教 Claude 拿这数据干什么）。agent team 是多个独立会话互相通信的形态，官方标注为实验性、默认关闭，和 subagent 的差别是"队友之间能直接对话"，细节归 032。

#### hooks 最小可跑配置

贴进项目的 `.claude/settings.json`（没有就新建）。这段的作用是：Claude 每次要跑 `rm ` 开头的 Bash 命令时，先跑你的脚本，脚本退出码非 0 就拦下。结构与字段名照 [CC Docs: hooks](https://code.claude.com/docs/en/hooks) 的官方示例（访问日期 2026-08）：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(rm *)",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.sh",
            "timeout": 30,
            "statusMessage": "检查危险删除命令…"
          }
        ]
      }
    ]
  }
}
```

字段含义：`matcher` 是工具名；`if` 是权限规则语法的过滤条件（比如 `Bash(git *)`、`Edit(*.ts)`），不写就对该工具的所有调用都跑；`type` 除了 `command` 还支持 `http` / `mcp_tool` / `prompt` / `agent`；`timeout` 单位是秒，command 类默认 600。

**怎么判断做对了**：在会话里输入 `/hooks`。它会打开一个只读浏览器，按事件列出所有已配置的 hook、匹配器、处理器类型，以及每条来自哪个设置文件（User / Project / Local / Plugin）。你的这条应该出现在 `PreToolUse` 下、来源标 Project Settings。如果 `/hooks` 里根本看不到它，通常是 JSON 语法错了或者放错了文件，不是 hook 没触发。注意这个菜单是只读的，改还是得改 JSON。

#### skill 最小可跑骨架

```bash
mkdir -p .claude/skills/pr-check
cat > .claude/skills/pr-check/SKILL.md <<'EOF'
---
name: pr-check
description: 提 PR 前的自检清单：跑测试、跑 lint、检查是否漏了 changelog
---

依次执行并逐条汇报结果：

1. 跑 `npm test`，全绿才继续。
2. 跑 `npm run lint`，有 error 先修。
3. 检查本次改动是否需要更新 CHANGELOG.md，需要就补上。
4. 输出一段可直接粘进 PR 描述的改动摘要。
EOF
```

`name` 和 `description` 是必填字段，可选的还有 `allowed-tools`（这一轮内免权限提示的工具）、`disallowed-tools` 等。目录名决定命令名，所以上面这个装完就是 `/pr-check`。

**怎么判断做对了**：在会话里敲 `/pr-`，自动补全里应该出现 `pr-check` 并显示你写的 description。Claude Code 会监听 `~/.claude/skills/`、项目 `.claude/skills/` 的文件变化，本会话内即时生效，不用重启——唯一的例外是这个顶层 skills 目录在会话启动时还不存在，那种情况要重启一次。

#### subagent 最小可跑骨架

固化一个 worker 就建 `.claude/agents/code-reviewer.md`（个人级放 `~/.claude/agents/`）：

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Glob, Grep
model: sonnet
---

你是代码评审员。被调用时，分析改动并就质量、安全性、最佳实践给出具体、可执行的反馈。
```

`tools` 限定它能用哪些工具（这里没给写工具，所以它改不了代码）；`model` 可以指到更便宜的模型控成本；正文成为它的系统提示。

**怎么判断做对了**：Claude Code 会监听这两个目录，几秒内生效，下次派发就用新定义。想验证就直接在主会话里说 `Use the code-reviewer subagent to review the authentication module`，看它是否以 subagent 形式跑、且只回摘要。注意 v2.1.198 起 `/agents` 不再是创建向导，敲它只会提示你去问 Claude 或直接编辑 `.claude/agents/`；文件位置和字段没变。如果找不到新建的 subagent，多半是 `~/.claude/agents/` 在会话启动前还不存在，重启一次即可。

### 第二交付物：何时用哪个决策树

先看主干四问，再看两个真会卡住人的岔口。

**主干（按顺序自问，第一个答"是"的就是答案）：**

1. **这件事必须每次都发生、且不需要 Claude 动脑吗？**（提交前 lint、拦危险命令）→ **hooks**。别的机制都是"建议"，只有 hooks 是执行。
2. **这是每次会话都得知道的事实或约定吗？**（构建命令、目录约定、金额用分）→ **CLAUDE.md**。
3. **这段活会产生我不会再看的大量输出，或者能拆成几条独立线并行跑吗？** → **subagent**。
4. **这套步骤我已经粘贴第三次了吗？** → **skill**。

以上四问都答"否"，那你要的多半不是新增配置，而是换个权限档：动手前想清楚方向用 `plan`，正在迭代改代码用 `acceptEdits`，长任务想少被打断用 `auto`。

**岔口一：一段流程既要复用、又会产生大量输出，选 skill 还是 subagent？**

先按"复用"做成 skill，因为 skill 是内容、subagent 是执行环境，两者不互斥。等你发现这个 skill 每次跑都把主会话塞满，再让它在隔离上下文里跑——官方的说法是 skill 可以用 `context: fork` 在隔离上下文执行，subagent 也可以用 `skills:` 字段预加载 skill。所以不是二选一，是"内容归 skill，要不要隔离另说"。反过来的官方信号也在 sub-agents 页里：`Consider Skills instead when you want reusable prompts or workflows that run in the main conversation context rather than isolated subagent context`，意思是"如果你要的是在主会话上下文里跑的可复用提示或流程，而不是隔离的 subagent 上下文，就改用 skill"（官方，2026-08）。

**岔口二：一条规则该写 CLAUDE.md 还是做成 skill？**

看它是一条事实还是一套步骤。"API handler 放在 `src/api/handlers/`"是事实，写 CLAUDE.md；"发版要依次做这七件事"是流程，做成 skill。官方给的分界线就是 skills 页那句 "when a section of CLAUDE.md has grown into a procedure rather than a fact"（当 CLAUDE.md 里某节从一条事实长成了一套流程时）。判断不了就看长度：CLAUDE.md 官方建议控制在 200 行以内，超了就是该往外拆的信号。

**岔口三：CLAUDE.md 里写了规则，Claude 还是不听，加强语气有用吗？**

没用，换机制。官方在 memory 页的排查章节写得很直：CLAUDE.md 是在系统提示之后以用户消息形式送进去的，`there's no guarantee of strict compliance`（不保证严格遵守）。正确动作是先跑 `/context` 确认文件真的加载了（看 **Memory files** 那一栏），再判断这条规则是不是本来就该做成 hook。

## Claude Code 实战

同一个任务，串起四类能力。每步都给能直接敲的东西和验证方法。

**任务：给一个已有的 Node 项目加一个"导出本月账单 PDF"的功能模块。**

**第 1 步：先把项目事实固化进 CLAUDE.md。**

```bash
cat >> CLAUDE.md <<'EOF'

## 账单模块约定
- 金额一律用「分」为单位的整数，禁止浮点
- 时间一律 UTC，展示层才转时区
- 导出文件名格式：`bill-YYYY-MM.pdf`
EOF
```

验证：会话里跑 `/context`，在 **Memory files** 一栏里应该能看到 `CLAUDE.md`。看不到就是路径不对——项目级只认 `./CLAUDE.md` 和 `./.claude/CLAUDE.md`。

**第 2 步：动手前进 plan mode 摸清楚。**

```bash
claude --permission-mode plan
```

已经在会话里就连按两次 `Shift+Tab`，状态栏会显示 `⏸ plan mode on`。然后问：

```
不要改任何文件。先摸清三件事再给方案：
1. 现有账单数据的读取入口在哪个模块、什么签名
2. 项目里有没有已经在用的 PDF 库，装在哪、怎么调
3. 现有导出类接口的鉴权是怎么做的，走哪个中间件
最后给一份分步实施计划，标出每步要改哪些文件。
```

验证：这一步做对的标志是它只读不写。如果中途出现了文件编辑，说明你不在 plan 里（或者这个会话是带 bypass permissions 起的——那种会话里官方明确说 plan 的拦截不生效）。看计划满意后回答里选 "Yes, manually approve edits" 或 "Yes, auto-accept edits" 退出 plan 开始动手。

**第 3 步：先写一个会失败的测试当终止条件。**

```
先只写测试，不要写实现：新增 test/bill-export.test.js，断言导出的 PDF 包含
本月全部交易、且金额字段是分为单位的整数。写完直接跑 npm test，
我要看到它因为实现不存在而失败。
```

验证：`npm test` 输出里这条新用例是 fail 而不是 error 找不到文件。有了这个红灯，后面"做完了没"才有客观判据。

**第 4 步：探索量大就派 subagent。**

```
Use a subagent to survey how the three existing export endpoints handle
auth, pagination and file streaming. Return only a comparison table and
a recommended pattern — do not paste the source.
```

验证：主会话里应该只多出一段摘要，而不是几百行源码。想量化就在派之前和之后各跑一次 `/context`，对比 token 占用。

**第 5 步：把"每次必须跑"的事交给 hook。**

把上面那段 `PreToolUse` 换成 `PostToolUse` 就是"编辑后自动 lint"。写完跑 `/hooks` 确认它出现在列表里、来源标 Project Settings。

**第 6 步：流程粘第三次了就抽成 skill。**

如果"新增一个功能模块"这套 plan → 写红灯测试 → 实现 → review 的动作你在第三个任务里又原样敲了一遍，按前面的骨架建 `.claude/skills/new-module/SKILL.md`，之后一句 `/new-module` 就够。验证：敲 `/new-` 能补全。

注意这个导览里发生了什么：你不是在学六个功能，而是在用一个任务把四类能力按需串起来。每一步的起点都是一个问题（要每次生效、要先想清楚、要闭合验证、要隔离输出、要强制执行、要复用），答案自然指向某一类。这就是能力地图的用法——它不是清单，是决策入口。

## 横向对比

001 已做过四工具完整横向表，本篇不重复，只回答一个能力层问题：这些维度别的工具有没有对应物？

| 维度 | Claude Code | Cursor | Copilot |
|------|-------------|--------|---------|
| 常驻项目指令 | `CLAUDE.md` | `.cursor/rules`（规则文件，可带路径作用域） | `.github/copilot-instructions.md` |
| 按需加载的流程 | `skill`（`.claude/skills/<名>/SKILL.md`，`/名字` 触发） | 混在 rules 里，没有独立的按需加载层 | 无独立机制 |
| 隔离上下文的 worker | `subagent`（`.claude/agents/*.md`） | Cloud Agents（环境级隔离，粒度更粗） | 无对应物 |
| 确定性闸门 | `hooks`（settings.json 生命周期事件） | 无对应物，靠 rules 文字约束 | 无对应物 |
| 权限档 | 6 档，`Shift+Tab` 切 | 有 auto-run 开关，档位更少 | 无 |

Claude Code 的差异在于这四类是各自独立的机制，而不是揉进一个 rules 文件——代价是要学四套东西，收益是"建议"和"强制"能分开表达。（第三方产品形态变动快，以上为 2026-08 观察，以各家官方文档为准。）

## 反模式

- ❌ **把这堆能力当散装功能各学各的。** 它们是四类解决不同问题的机制。不先问"我要解决什么"就会用错，最典型的是把该写 CLAUDE.md 的事实塞进 skill——事实塞进按需加载层，结果就是它经常想不起来加载。
- ❌ **该用 hook 的写进 CLAUDE.md。** 官方逐字：CLAUDE.md 里的 "never edit `.env`" `is a request, not a guarantee`（是个请求，不是保证）。必须每次生效的用 `PreToolUse` hook 拦。
- ❌ **规则不生效就加粗、加"务必"、加全大写。** 先跑 `/context` 看文件到底加载了没，再看是不是本来就该换成 hook。语气不解决机制问题。
- ❌ **以为 plan mode 只是"叠在 default 上的只读开关"。** 它就是官方 6 档权限模式里的一档，配置值 `plan`，可以 `claude --permission-mode plan` 起、也可以在 `.claude/settings.json` 里写 `{"permissions": {"defaultMode": "plan"}}` 设成项目默认。（另外注意一个坑：会话若是带 bypass permissions 起的，plan 的编辑拦截不生效，Claude 仍被"要求"只规划，但它真动手也不会被拦。）
- ❌ **该留主会话的丢给 subagent。** 需要频繁来回、共享大量上下文的任务留主会话。subagent 适合自包含、输出冗长的活——它不继承你的对话历史，来回一多，光交代背景就比自己干还贵。
- ❌ **CLAUDE.md 越写越长当成"上下文更充分"。** 官方建议单个文件 200 行以内，超了会稀释遵守度。长了就往 `.claude/rules/`（可按 `paths` 作用域加载）或 skill 里拆。
- ❌ **以为"装了 skill、派了 subagent"就等于 Orchestration 心智转过来了。** 工具是表象，心智是底。详见 [003](./003-AI代码审不动改不懂.md)。

## 延伸

**交叉引用：**
- [#001 Claude Code、Codex、Cursor、Copilot 到底该用哪个？按你的活儿选，不按测评选](./001-AI编程工具怎么选.md) —— agentic 本质、四工具形态（本篇前提，必引）。
- [#003 为什么 AI 写的代码我审不动、改完自己看不懂？](./003-AI代码审不动改不懂.md) —— 第 3 层 Orchestration 心智指向本篇（本篇是它的工具展开，必引）。
- [#010 CLAUDE.md 怎么写才真的生效？](../02-上下文工程/010-CLAUDE-md怎么写才生效.md) —— CLAUDE.md 与 hooks 攻略（本篇这两项的攻略指针，必引）。
- [#013 压缩一次它就忘了刚定的方案——哪些决策必须写进 memory 才扛得住 compact](../02-上下文工程/013-哪些决策要写进memory.md) —— auto memory 攻略（本篇 auto memory 项的攻略指针）。
- [#030 TDD 在 AI coding 里怎么做？](../04-执行工作流/030-AI写的测试不可信.md) —— TDD 攻略（本篇「配套做法」注解的指针，必引）。
- [#031 plan → execute → review 的正确循环怎么做？](../04-执行工作流/031-plan-execute-review循环.md) —— plan mode 攻略（必引）。
- [#032 开几个 agent 并行跑，结果互相踩、被限流、token 指数级炸开——并行到底该开几个？](../04-执行工作流/032-SubAgent并行开几个.md) —— subagent 攻略（必引）。
- [#033 Skill / superpowers 怎么用、怎么写？](../04-执行工作流/033-Skill与superpowers怎么用.md) —— skill 攻略（必引）。

**参考资料：**
- [CC Docs: Extend Claude Code（features-overview）](https://code.claude.com/docs/en/features-overview) —— "Build your setup over time" 触发表、Skill vs Subagent / CLAUDE.md vs Skill / Hook vs Skill 三组对照、各能力上下文开销表（官方，访问日期 2026-08）。✅ 全文逐字复核，本篇分类框架的主要官方依据
- [CC Docs: Choose a permission mode](https://code.claude.com/docs/en/permission-modes) —— 6 档权限模式表、`plan` 是其中一档、`Shift+Tab` 循环顺序、`--permission-mode` 与 `defaultMode`、bypass 会话下 plan 拦截失效（官方，访问日期 2026-08）。✅ 全文逐字复核（本次修正：旧版本把 plan 描述成"非独立权限档"，与现行官方表不符，已改）
- [CC Docs: Hooks reference](https://code.claude.com/docs/en/hooks) —— settings.json 的 `hooks` 结构、`PreToolUse` 示例、事件名全表、`type` / `if` / `timeout` / `statusMessage` 字段、`/hooks` 只读浏览器（官方，访问日期 2026-08）。✅ 本篇 JSON 片段照该页示例
- [CC Docs: Extend Claude with skills](https://code.claude.com/docs/en/skills) —— skill 存放路径表、SKILL.md frontmatter 字段、"Create a skill when you keep pasting..."、目录名即命令名、文件变更即时生效（官方，访问日期 2026-08）。✅ 全文逐字复核
- [CC Docs: Create custom subagents](https://code.claude.com/docs/en/sub-agents) —— `.claude/agents/` 路径、frontmatter 示例、"a side task would flood your main conversation..."、"Consider Skills instead..."、v2.1.198 起 `/agents` 不再是向导（官方，访问日期 2026-08）。✅ 全文逐字复核
- [CC Docs: How Claude remembers your project](https://code.claude.com/docs/en/memory) —— CLAUDE.md vs auto memory 对照表、四类存放位置、200 行建议、`/context` 的 Memory files 排查法、"no guarantee of strict compliance"（官方，访问日期 2026-08）。✅ 全文逐字复核
- [CC Docs: Best practices for Claude Code](https://code.claude.com/docs/en/best-practices) —— TDD "Give Claude something that produces a pass or fail"（官方，访问日期 2026-08）。✅ 经 030 / 031 正文逐字复核
- [Anthropic Blog: Steering Claude Code—when to use CLAUDE.md, skills, hooks, rules, subagents and more](https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more) —— 官方博客版的选型走查，官方 features-overview 页在"Compare similar features"一节点名推荐（官方博客，2026）。
- [Anthropic: Skills explained](https://claude.com/blog/skills-explained) —— MCP 与 skill 的边界，"MCP connects Claude to data; Skills teach Claude what to do with that data"（官方，2026-03）。✅ 经 033 正文逐字复核

> 本篇个人实践（L4）：`[待补：BOSS 的能力地图使用顺序 / 哪个能力最先上手 / 哪个最后才用]`
