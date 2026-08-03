# 012. 上下文窗口要爆了怎么办？

> 难度：中级
> 主题：上下文工程
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：排错题

> ⏰ 时效声明：本篇的窗口与机制事实（默认 200K、1M 支持列表与 `[1m]` 激活、compact 有损原文、compact 后哪些内容会被重新注入、skill 重注入 5000/25000 预算、auto-compact 触发点、环境变量与 statusline 字段名）已于 **2026-08-03** 对照官方 [context-window](https://code.claude.com/docs/en/context-window)、[model-config](https://code.claude.com/docs/en/model-config)、[env-vars](https://code.claude.com/docs/en/env-vars)、[sessions](https://code.claude.com/docs/en/sessions)、[statusline](https://code.claude.com/docs/en/statusline) 五份文档逐项核实。**易变内容**：支持 1M 的模型清单、Sonnet 5 的 967K 默认压缩点，随模型迭代必然变化，用前请回查 model-config。

## TL;DR

上下文窗口不是「越大越好」的垃圾桶。它是一个有限资源，而且塞得越满、质量越差。

窗口快满时，你会看到三种症状：

1. 响应变慢。每条新消息都要把全部历史重新计算一遍，也重新计费。
2. 质量下降。关键信息被大量内容淹没，模型回忆不准。这个现象叫 context rot，下面会解释。
3. auto-compact 突然触发。它把你的工作现场压成一段摘要，可能丢掉你正需要的细节。

对应的处置办法，记住这张「诊断 → 处置」表：

| 症状 | 一线处置 | 根治 |
|------|---------|------|
| 上下文 60–80%，质量开始下降 | 手动 `/compact` 并给焦点指令 | 用 SubAgent 隔离产生大量输出的操作 |
| 任务已切换，旧上下文是噪声 | `/clear`（先 `/rename`） | 在任务边界养成 clear 习惯 |
| 上下文满，auto-compact 即将或已触发 | 让它压，或手动 `/compact` 后校验 | 开新会话 + 用笔记做结构化交接 |
| 反复因长程任务爆窗口 | 拆任务 / 分层 Agent | 写进度文件 + git commit 做交接 |

一句话流程：用 `/context` 看占用；到 60% 前主动 `/compact`；任务切换必 `/clear`；长程任务用 SubAgent 隔离加笔记交接。✅

---

## 为什么

### 1. 上下文窗口是有限资源，塞得越满质量越差

先讲结论：上下文不是「填满才出问题」，而是每多一个 token，所有信息的被回忆概率都在下降。

这个现象官方称为 context rot（可理解为「上下文腐烂」）。Anthropic 官方工程博客的定义是：

> "Studies on needle-in-a-haystack style benchmarking have uncovered the concept of context rot: as the number of tokens in the context window increases, the model's ability to accurately recall information from that context decreases... Context, therefore, must be treated as a **finite resource with diminishing marginal returns**."
> —— 大意：随着上下文里 token 数量增加，模型准确回忆信息的能力下降；因此上下文必须被当作一种边际收益递减的有限资源。出自 [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)（官方，2025-09）✅

官方给的原因是「注意力预算」（attention budget）。Transformer 的注意力开销和 token 数量是平方关系，上下文越长，每个 token 能分到的注意力就越稀薄（官方，2025-09）。

学界很早就有实证支持。Liu et al. 的论文证实，模型对位于上下文中间的信息回忆明显变差，作者称之为「lost in the middle」（迷失在中间）。即使是专为长上下文设计的模型也一样（[arXiv:2307.03172](https://arxiv.org/abs/2307.03172)，学术，2023-07，TACL 2024 正式发表）✅。这一论断有官方和学术两个来源支撑 ✅。

Chroma Research 的独立研究进一步确认：性能下降不是因为任务变难，而是因为上下文变长（[Context Rot](https://www.trychroma.com/research/context-rot)，研究，2025）✅。

### 2. Agent 的上下文是「活的」，会快速膨胀

Agent 场景比普通对话更容易爆窗口，因为每次工具调用都会往上下文里塞结果。

LangChain 官方博客点出了这个问题：

> "long-running tasks and accumulating feedback from tool calls mean that agents often utilize a large number of tokens. This can cause numerous problems: it can exceed the size of the context window, **balloon cost / latency, or degrade agent performance**."
> —— 大意：长任务加上工具调用不断累积的反馈，让 agent 用掉大量 token，可能撑爆窗口、推高成本和延迟，或拖垮性能。出自 [Context Engineering for Agents](https://www.langchain.com/blog/context-engineering-for-agents)（社区权威，2025-07）✅

膨胀有多快？Manus 团队披露，一个典型 agent 任务大约需要 50 次工具调用（[Latent Space: Lance Martin](https://www.latent.space/p/context-engineering-for-agents-lance)，社区，2025-09）。

膨胀带来的成本是线性上涨的。因为每个 token 在每一轮都要重新计费（Anthropic 按 token 计费，见 [pricing](https://www.anthropic.com/pricing)，官方）。这一成本论断有两个来源支撑 ✅。

还有一点要注意：上下文失效往往在窗口远未填满时就发生。社区研究者 Drew Breunig 总结了四种失效模式，这个框架后来被 LangChain 转载：

- Context Poisoning：幻觉内容混进上下文。
- Context Distraction：信息过载。
- Context Confusion：无关上下文造成干扰。
- Context Clash：上下文内部自相矛盾。

来源：[How Contexts Fail](https://www.dbreunig.com/2025/06/22/how-contexts-fail-and-how-to-fix-them.html)（社区，2025-06）✅。

### 3. compact 会真的丢信息

先说结论：`/compact` 是一种有损操作，别把它当万能解药。

Claude Code 官方文档对此描述得很直白。它把对话替换成摘要，丢弃逐字内容：

> "Compaction replaces the conversation with a structured summary. System prompt, CLAUDE.md, memory, and MCP tools reload automatically... It **replaces the verbatim conversation: full tool outputs and intermediate reasoning are gone**."
> —— 大意：压缩用结构化摘要替换对话，系统提示、CLAUDE.md、记忆和 MCP 工具会自动重新加载，但逐字对话被替换掉——完整的工具输出和中间推理都没了。出自 [Claude Code Docs: Explore the context window](https://code.claude.com/docs/en/context-window)（官方，2026-06；两句在原文非相邻，用 `...` 标注拼接）✅

具体哪些会保留、哪些会丢？官方「What survives compaction」表列出了会被重新注入的项：系统提示、根目录 CLAUDE.md、auto memory、已调用的 skill 等。其余进入消息历史的内容都会被摘要替代，包括完整工具输出、带 `paths:` frontmatter 的路径作用域规则、子目录里嵌套的 CLAUDE.md——后两者要等下次读到匹配文件才会重新加载。中间推理步骤也会随之丢失。

官方那张表的逐项结论（官方 context-window，2026-08 核实）：

| 机制 | compact 之后 |
|------|-------------|
| 系统提示、output style | 不变（本就不在消息历史里） |
| 项目根 CLAUDE.md、无 `paths:` 的规则 | 从磁盘重新注入 |
| auto memory（MEMORY.md） | 从磁盘重新注入 |
| 带 `paths:` frontmatter 的规则 | 丢失，直到再次读到匹配文件 |
| 子目录里的嵌套 CLAUDE.md | 丢失，直到再次读到该目录下的文件 |
| 已调用的 skill 正文 | 重新注入，每个 skill 上限 5000 token、总额 25000 token，超了先丢最旧的 |
| hooks | 不受影响（hook 是代码，不占上下文） |

一条能直接照做的推论：**如果某条规则必须扛过 compact，就删掉它的 `paths:` frontmatter，或者把它挪进项目根 CLAUDE.md。** skill 同理——重要指令写在 `SKILL.md` 最前面，因为截断是从后往前砍的。

Anthropic 工程博客也警告过度激进的压缩风险：

> "The art of compaction lies in the selection of what to keep versus what to discard, as **overly aggressive compaction can result in the loss of subtle but critical context** whose importance only becomes apparent later."
> —— 大意：压缩的艺术在于取舍，压得太狠会丢掉那些微妙但关键、之后才显出重要性的上下文。出自 [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)（官方，2025-09）✅

所以，compact 救急可以，但你丢掉的那个「不重要」的细节，可能正是 10 轮之后你需要的东西。这一有损论断有两个来源支撑 ✅。

### 4. 关键决策：compact、clear 还是开新会话

三种动作各有适用场景。下面这张表综合了官方指引和社区共识（多源趋同 ✅）：

| 动作 | 何时用 | 保留什么 | 来源 |
|------|--------|---------|------|
| `/compact` | 同一任务的长对话，想继续推进 | 摘要 + 根 CLAUDE.md（从磁盘重注入）+ auto memory + 已调用的 skill（每个 skill 5000 token、总额 25000 token 内重注入） | [CC Docs: context-window](https://code.claude.com/docs/en/context-window)（官方）✅ |
| `/clear` | 切换到不相关的任务 | 清空；旧会话归档到 `/resume` | [CC Docs: commands](https://code.claude.com/docs/en/commands)（官方）、[costs](https://code.claude.com/docs/en/costs)（官方）✅ |
| 开新会话 | 上下文已被污染、任务完全不同、或想彻底干净 | 只剩磁盘上的文件、git 历史、你手写的笔记 | 官方 + [MindStudio](https://www.mindstudio.ai/blog/claude-code-compact-command-context-management)（社区，2025）、[Reddit 共识](https://www.reddit.com/r/ClaudeAI/comments/1p8jkqx/)（社区）✅ |

官方工程博客给了最清晰的选择框架：

> "Compaction maintains conversational flow for tasks requiring extensive back-and-forth; note-taking excels for iterative development with clear milestones; multi-agent architectures handle complex research and analysis where parallel exploration pays dividends."
> —— 大意：需要大量来回对话的任务用压缩来保持连续性；有明确里程碑的迭代开发用笔记更好；需要并行探索的复杂研究和分析用多 Agent 架构。出自 [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)（官方，2025-09）✅

> 个人观点（小C）：对大多数人，默认动作应该是 compact，不是 clear。只有当你感觉这个上下文已经被污染（Claude 开始重复或跑偏）时，才 clear 或开新会话。盲目 clear 会丢掉你还需要的上下文。

---

## 怎么做

排错的核心是「诊断 → 处置 → 根治」，按这个顺序走。

### 第一步：诊断，用 `/context` 看清占用

1. 运行 `/context`。它用彩色网格展示当前上下文被什么填满，包括系统提示、工具、CLAUDE.md、对话历史，并给出优化建议。这是排错的第一动作。✅（[CC Docs: commands](https://code.claude.com/docs/en/commands)，官方，2026-06）
2. 看状态栏。配置 statusline 持续显示 `used_percentage`，就不用反复手动查。✅（[CC Docs: statusline](https://code.claude.com/docs/en/statusline)，官方，2026-06）

### 第二步：处置，按症状选动作

**60–80% 且质量开始下降 → 手动 `/compact` 并给焦点指令。** 别等 auto-compact。社区共识是在约 60% 主动压缩效果最好（[MindStudio](https://www.mindstudio.ai/blog/claude-code-compact-command-context-management)，社区，2025）。官方也建议在工作的自然停顿点运行 `/compact`，而不是等 auto-compact（[CC Docs: prompt-caching](https://code.claude.com/docs/en/prompt-caching)，官方，2026-06）✅。

**任务切换 → `/clear`，切换前先 `/rename <名字>` 给当前会话起个名。** 旧会话保留在 `/resume`，之后用 `/resume <名字>` 或 `claude --resume <名字>` 随时可回（[CC Docs: sessions](https://code.claude.com/docs/en/sessions)，官方，2026-08）✅。官方原话：切换到不相关的工作时用 `/clear` 重新开始，因为过期的上下文会在之后每条消息上白白烧 token（[CC Docs: costs](https://code.claude.com/docs/en/costs)，官方，2026-06）✅。

**上下文已满或 auto-compact 触发中 → 接受压缩，然后校验。** 如果 auto-compact 在你不希望的时刻触发（比如重构中途），有两个选择：让它压完，然后快速核对关键信息还在不在；或用 `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` 调整触发点（见下文）。

**长程任务反复爆窗口 → 用结构化笔记加 git 交接。** Anthropic 官方给的范式是：每段会话结束前写进度文件并 git commit；下一段会话开头先读 git log、读进度文件，再干活。这是跨上下文窗口唯一可靠的交接方式（[Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)，官方，2025）✅。

### 第三步：根治，预防优于救火

**把产生大量输出的操作丢给 SubAgent。** 跑测试、读日志、爬文档这类操作会产生大量输出。丢给 SubAgent，这些输出留在它的独立上下文里，只回传摘要给你。✅（[CC Docs: sub-agents](https://code.claude.com/docs/en/sub-agents)，官方，2026-06）

**用 Plan mode 探索。** 连按两次 `Shift+Tab` 进入 Plan mode，Claude 会在只读模式下探索代码库，探索输出留在独立上下文，不污染主对话。✅（官方，2026-06）

**砍掉多余的 MCP 工具开销。** 用 `/mcp` 看哪些 server 占上下文，关掉不用的。优先用 `gh`、`aws` 等命令行工具而不是 MCP server，因为命令行工具不占用每个工具的清单空间。✅（[CC Docs: costs](https://code.claude.com/docs/en/costs)，官方，2026-06）

**写具体的 prompt。** 「改进这个代码库」会触发大范围扫描；「给 auth.ts 的 login 函数加输入校验」让 Claude 精准定位，省 token。✅（官方，2026-06）

---

## Claude Code 实战

### 三条核心命令速查

| 命令 | 作用 | 关键参数 |
|------|------|---------|
| `/context` | 用彩色网格可视化上下文占用，并给优化建议 | `/context all` 展开全部分项 |
| `/compact [instructions]` | 摘要当前对话释放空间，同一会话继续 | 焦点指令：`/compact focus on the API schema and pending todos` |
| `/clear [name]` | 清空并开始新会话，旧会话归档到 `/resume` | `name` 是给**被清掉的那个旧会话**贴的标签，方便在 `/resume` 里找；别名 `/reset`、`/new` |
| `/rename <name>` | 给**当前**会话改名，名字同时显示在提示栏上 | 改完可以用 `/resume <name>` 或 `claude --resume <name>` 直接回来 |

两个命令都涉及"名字"，但方向相反：`/clear old-thing` 命名的是你正要丢下的会话，`/rename old-thing` 命名的是你正在用的会话。想在切任务前留个记号，两种写法都行，`/rename` 更直观一些。另外，用 `--name` 或 `/rename` 设的名字会跨 `/clear` 保留下来，AI 自动生成的标题则不会。

来源：[CC Docs: commands](https://code.claude.com/docs/en/commands)、[sessions](https://code.claude.com/docs/en/sessions)（官方，2026-08 核实）✅。

### `/compact` 焦点指令：控制压缩保留什么

裸 `/compact` 用默认摘要逻辑。带焦点指令能告诉它优先保留什么：

```
/compact focus on the database schema decisions and the failing test cases
```

你还可以把压缩偏好写进 CLAUDE.md，之后每次 compact 自动生效：

```markdown
# Compact instructions

When you are using compact, please focus on test output and code changes
```

来源：[CC Docs: costs](https://code.claude.com/docs/en/costs)（官方，2026-06）✅。

### auto-compact 阈值调优：两个环境变量

Claude Code 默认在接近上限时自动压缩，这个行为叫 auto-compact。

**先把默认触发点说清楚，别再传"95%"这个数。** 官方没有公布一个统一百分比，因为触发点按模型不同（截至 2026-08，官方 env-vars 与 model-config）：

| 场景 | 默认什么时候压 | 相当于窗口的 |
|------|--------------|------------|
| Sonnet 4.6 / Opus 4.6，未开扩展上下文 | 200K 边界 | 100% |
| Sonnet 5（默认 1M） | 约 967K token | 约 97% |
| 本地会话 Opus 4.8 | 对话达到模型上下文上限才压 | 100% |
| 设了 `CLAUDE_CODE_AUTO_COMPACT_WINDOW` / 云端会话 | 按你设的窗口 × 百分比 | 你说了算 |

结论一句话：**默认触发点都在窗口 95% 以上，指望它保住质量是不现实的。** 你要主动往前调。

三个可调项：

| 变量 | 作用 | 取值 |
|------|------|------|
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | 触发压缩的百分比。官方原文「The override can only lower the threshold」——只能调低，设得比默认高无效。主对话和 subagent 都生效 | 1–100 |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | 用来算阈值的窗口容量（token 数），上限是模型真实窗口。设了它，压缩阈值就和 statusline 的 `used_percentage` 解耦——后者永远按模型完整窗口算 | 如 `500000` |
| `DISABLE_AUTO_COMPACT`（等价于 settings.json 的 `autoCompactEnabled: false`） | 完全关闭自动压缩 | `1` |

注意一个坑：`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` **只在 Claude Code「主动压缩」的场景下才把时间提前**——即设了 `CLAUDE_CODE_AUTO_COMPACT_WINDOW` 时、云端会话、以及未开扩展上下文的 Sonnet 4.6/Opus 4.6。本地 Opus 4.8 单独设百分比不会有效果。所以稳妥写法是**两个一起设**。

#### 可复制的设置：写进 settings.json 的 `env` 字段

环境变量有两种设法：shell 里 `export`（临时），或写进 settings.json 的 `env`（持久，且启动时会覆盖 shell 继承的同名值）。推荐后者。

选一个文件写（作用域不同）：

| 文件 | 作用范围 |
|------|---------|
| `~/.claude/settings.json` | 你本人，所有项目 |
| `<项目>/.claude/settings.json` | 项目全员，进版本库 |
| `<项目>/.claude/settings.local.json` | 你本人，仅本项目，被 gitignore |

内容（以 1M 模型上按 500K 窗口的 65% 触发为例）：

```json
{
  "env": {
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "500000",
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "65"
  }
}
```

200K 模型上就把窗口写 `"200000"`，实际触发点 = 200000 × 65% = 130K。

**改完怎么确认生效？** 三步，每步都有明确预期：

1. **重启 Claude Code。** 环境变量只在启动时读一次，改完不重启等于没改。
2. **在会话里跑 `echo $CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`**（Bash 工具）。预期输出 `65`。空行说明 JSON 没被加载——检查文件路径和 JSON 语法（`cat ~/.claude/settings.json | jq .` 应该能正常解析）。
3. **跑 `/context`。** 看容量警告那一行：设置生效后，它会在你远未到模型上限时就开始提示接近压缩点。真正的确认是继续工作，观察 auto-compact 是否在 statusline 显示约 32%（500K×65% ÷ 1M 完整窗口）时触发——注意 statusline 的百分比是按模型完整窗口算的，和你设的阈值口径不一样，别以为没生效。

> 实战建议：社区普遍反映 Claude 在约 50% 后质量就开始下滑（[Reddit](https://www.reddit.com/r/ClaudeAI/comments/1r4tu3n/)，社区，2025，⚠️ 社区经验非官方数据）。结合上面官方的默认触发点（95% 以上），结论很清楚：把阈值调到 60–70，或者养成手动 `/compact` 的习惯，两者选一，别裸奔。

#### 配套：让 statusline 一直显示上下文占用

不想反复敲 `/context`，就配一行 statusline。最小可用版本，直接写进 `~/.claude/settings.json`：

```json
{
  "statusLine": {
    "type": "command",
    "command": "jq -r '\"[\\(.model.display_name)] \\(.context_window.used_percentage // 0)% context\"'"
  }
}
```

**验证**：重启后底部应出现类似 `[Opus 4.8] 8% context` 的一行。没出现就先确认 `jq` 装了（`jq --version`）。字段名是 `context_window.used_percentage`，会话刚开始时可能为 `null`，所以上面用了 `// 0` 兜底（[CC Docs: statusline](https://code.claude.com/docs/en/statusline)，官方，2026-08 核实）✅。

来源：[CC Docs: env-vars](https://code.claude.com/docs/en/env-vars)、[settings](https://code.claude.com/docs/en/settings)、[model-config](https://code.claude.com/docs/en/model-config)、[statusline](https://code.claude.com/docs/en/statusline)（官方，2026-08 核实）✅。

### SubAgent 隔离：最高效的防爆手段

官方描述了 SubAgent 的隔离原理：

> "Each subagent runs in its own context window with a custom system prompt, specific tool access, and independent permissions... A subagent starts in a fresh, isolated context window. It does not see your conversation history."
> —— 大意：每个 subagent 在自己的上下文窗口里运行，有独立的系统提示、工具权限和许可；它从一个全新、隔离的上下文窗口开始，看不到你的对话历史。出自 [CC Docs: sub-agents](https://code.claude.com/docs/en/sub-agents)（官方，2026-06）✅

更关键的一点：SubAgent 的 transcript 存在独立文件里，主对话 compact 时不受影响（官方，2026-06）。这给了你一个能扛住 compact 的工作面。

典型用法：

```
# 让 SubAgent 跑测试，只回传失败用例
Use a subagent to run the test suite and report only the failing tests with their error messages

# 并行调研，每个 SubAgent 独立上下文
Research the authentication, database, and API modules in parallel using separate subagents
```

Anthropic 的多 Agent 研究系统博客也验证了这一点：SubAgent 在独立上下文里并行探索，最终只把凝练的摘要交给主 Agent（[How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)，官方）✅。这一隔离论断有两个来源支撑 ✅。

### stash 模式：compact 或 clear 前暂存现场（社区实践）

Claude Code 没有原生的 `/stash` 命令。社区的做法是用文件来辅助暂存：

- **progress 文件。** Anthropic 官方推荐用 `claude-progress.txt`，记录已完成、待办、已知 bug（[Effective harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)，官方，2025）✅。
- **TodoWrite 或活日志。** 社区用 TodoWrite 做检查点（[Reddit: 活日志模式](https://www.reddit.com/r/ClaudeCode/comments/1qps9xj/)，社区）。
- **`/rename` + `/resume`。** clear 前先 `/rename <名字>` 给当前会话命名，事后 `/resume <名字>` 精确回来（[CC Docs: sessions](https://code.claude.com/docs/en/sessions)，官方，2026-08）✅。
- **skill 化。** 把「暂存现场」封装成一个 skill，一句话触发。最小可用版本，存成 `~/.claude/skills/save/SKILL.md`：

```markdown
---
name: save
description: 上下文快满、准备 /compact 或 /clear 前，把当前工作现场落盘到文件。当用户说"save""存一下""要爆了"时使用。
---

把当前现场写入 `./.claude-stash.md`，覆盖旧内容。必须包含这五项：

1. 正在做什么：一句话任务目标
2. 已完成：改了哪些文件，每个文件一句话说明改了什么
3. 下一步：具体到"打开哪个文件、做什么动作"
4. 关键路径与命令：本次涉及的文件绝对路径、跑过的验证命令
5. 已知坑：踩过的错和结论，避免下次重复

写完把文件路径打印出来，并提醒用户可以 /compact 了。
```

恢复端再写一个 `restore` skill，内容就是"读 `./.claude-stash.md`，复述五项内容跟我对齐，等我确认再动手"。skill 的 frontmatter 字段和加载优先级见 [#033 skill 和 superpowers 怎么用？](../04-execution-workflow/033-skill-superpowers-usage.md)。

**验证 skill 生效**：跑 `/context`，在 skill 分项里应能看到 `save` 被列出；或直接说一句"save 一下"，看它有没有真的生成 `.claude-stash.md`（`ls -l .claude-stash.md` 应看到刚写入的时间戳）。别忘了把 `.claude-stash.md` 加进 `.gitignore`。（社区实践）

> 个人观点（小C）：compact 前花 10 秒，让 Claude 把当前任务状态、下一步、关键文件路径写进一个文件。这比压完之后痛苦地回忆丢了什么，性价比高得多。

### Plan mode：不污染主上下文的探索

连按两次 `Shift+Tab` 进入 Plan mode，Claude 会把探索工作委托给内置的 Plan SubAgent，后者有独立的上下文窗口，主对话保持只读。探索完成后它给你一个计划等你批准，大量的探索输出留在 SubAgent 里，不进主上下文（[CC Docs: sub-agents](https://code.claude.com/docs/en/sub-agents)，官方，2026-06）✅。

### 1M 上下文窗口：更大不等于不用管

部分模型支持 1M token 上下文。激活方式是在 `/model` 后加 `[1m]`，比如 `/model opus[1m]`。

> ⚠️ **易变清单，别背**：截至 **2026-08**，官方列出 Fable 5、Sonnet 5、Opus 4.6 及以后、Sonnet 4.6 支持 1M。Sonnet 5 是例外，在 Anthropic API 上永远跑 1M，没有 200K 变体也没有 `[1m]` 后缀可选，且不消耗额外用量额度。**查当前清单的正确姿势**：跑 `/model` 看选择器里哪些条目带 `[1m]`，这比记文章里的型号列表可靠。（[CC Docs: model-config](https://code.claude.com/docs/en/model-config)，官方，2026-08 核实）✅

两个和 Sonnet 5 相关的坑：走 LLM 网关（设了 `ANTHROPIC_BASE_URL`）时，Claude Code 无法确认对端支持 1M，会按 200K 预算并在该边界压缩，要用满 1M 得在选择器里显式选 "Sonnet 5 (1M context)"；设了 `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` 也会被按 200K 处理。

但窗口更大不等于不用管理上下文。Anthropic 明确指出，所有大小的窗口都受 context rot 影响，1M token 塞满照样衰减（[Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)，官方，2025-09）✅。1M 只是给了你更多缓冲，不是免死金牌。

---

## 横向对比

| 维度 | Claude Code | Cursor | GitHub Copilot |
|------|------------|--------|----------------|
| **显式 `/compact`** | ✅ `/compact [focus]`（官方） | ⚠️ 无官方 slash 命令；社区称约 100% 时自动摘要（[Cursor Forum](https://forum.cursor.com/t/compact-compress-chat/132097)，社区，2025-08） | ✅ `/compact`（CLI 支持手动触发；官方文档未提焦点指令参数） |
| **显式 `/clear`** | ✅ `/clear`（旧会话归档到 `/resume`） | ❌ 仅靠开新 chat，无文档化命令 | ❌ 官方建议开新 chat，无 `/clear` 命令 |
| **auto-compact** | ✅ 按模型定触发点（Sonnet 5 约 967K/1M；Opus 4.8 本地到上限），阈值可用 `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` + `CLAUDE_CODE_AUTO_COMPACT_WINDOW` 调低 | ✅ 社区报告约 100% 触发（⚠️ 非官方证实） | ✅ VS Code 窗口满时自动；CLI 在约 80% 触发，留 20% 缓冲（[Copilot CLI Docs](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/context-management)，官方） |
| **上下文隔离** | ⭐ Subagents，独立上下文窗口加独立系统提示，只回传摘要 | ⚠️ 有多 tab，但无文档化的 subagent 模型 | ⚠️ 无文档化的显式隔离特性 |
| **上下文可视化** | ⭐ `/context` 彩色网格加优化建议 | 上下文填充百分比指示器（社区记录） | 上下文窗口控制条加 `/context` 命令（官方） |
| **更大窗口** | 200K 默认，`[1m]` 激活 1M（官方） | Max Mode：更大窗口加 200 次工具调用加读 750 行（[Cursor Docs: max-mode](https://docs.cursor.com/context/max-mode)，官方） | 可配置，最高 1M（[GitHub Changelog 2026-06-04](https://github.blog/changelog/2026-06-04-larger-context-windows-and-configurable-reasoning-levels-for-github-copilot/)，官方） |
| **压缩检查点** | SubAgent transcript 独立持久化 | 无文档化特性 | ⭐ `/session checkpoints`，每次压缩存一个带编号的摘要，可回看（[Copilot CLI Docs](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/context-management)，官方） |

几点关键观察：

- Claude Code 的差异化优势是 SubAgent 隔离。它把上下文隔离做成了一等公民的产品特性，直接对应 Anthropic 官方博客的 isolate 原则。✅（官方文档加官方博客双源）
- Copilot 给的是一个统一的 80% 阈值，简单好记；Claude Code 给的是按模型分档的绝对 token 数（如 Sonnet 5 的 967K），更精确但读者要自己换算成百分比。两家都算透明，只是口径不同。
- Cursor 偏向撑大窗口而非精细管理。Max Mode 给你更大窗口和更多工具调用额度，但缺乏精细的 compact 和 clear 控制，也没有 subagent 隔离。它的压缩机制几乎全靠社区报告，官方文档缺失。⚠️
- 三家的共性趋势：都有 auto-compact、都有更大窗口选项、都有上下文可视化，都在往「渐进式披露」靠拢，因为没人能逃过 context rot。

来源：[VS Code Copilot Chat Context](https://code.visualstudio.com/docs/chat/copilot-chat-context)（官方，2026-06）、[Cursor Docs: Max Mode](https://docs.cursor.com/context/max-mode)（官方）、[Copilot CLI Context Management](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/context-management)（官方）✅。

---

## 反模式

- ❌ **把上下文窗口当无限垃圾桶。** context rot 意味着塞得越多、质量越降，1M 窗口填满照样衰减。官方明确反对把所有东西预塞进去。✅（官方加学术双源）
- ❌ **只等 auto-compact，从不手动 compact。** 官方没公布统一百分比，但按模型看默认触发点都在窗口 95% 以上（Sonnet 5 约 967K/1M，本地 Opus 4.8 到上限才压），而质量在约 50% 就开始下滑。等它触发时，你的工作可能已经进行到一半就崩了。✅（官方 env-vars/model-config，2026-08；50% 那个数是社区经验 ⚠️）
- ❌ **任务切换不 `/clear`。** 过期的上下文会在后续每条消息白白烧 token，还可能让 Claude 混淆任务边界。切换任务就立刻 `/clear`，切换前先 `/rename`。✅（官方，2026-06）
- ❌ **把 compact 当无损操作。** compact 会用摘要替代完整工具输出、路径作用域规则、嵌套 CLAUDE.md 等内容，只保留摘要层面的叙述。那个被压掉的「不重要」细节，可能正是你后面需要的。compact 前先暂存关键信息。✅（官方，2026-06 加 2025-09）
- ❌ **让产生大量输出的操作直接在主上下文跑。** 跑全量测试套件、读 10 万行日志、爬一堆文档，这些输出会全进主上下文。丢给 SubAgent，只回传摘要。✅（官方，2026-06）
- ❌ **盲目禁用 auto-compact。** 有人设 `DISABLE_AUTO_COMPACT`，觉得自己管更好。但禁了之后到顶会直接卡死，且手动管理负担重。官方较新的工程指引倾向于「做能用的最简单方案」，让它自动跑就行，Claude Code 已改进了压缩时对关键上下文的保护（[Hyperdev](https://hyperdev.matsuoka.com/p/how-claude-code-got-better-by-protecting)，社区，2025）⚠️（社区分析，单源偏观点）。
- ❌ **指望 compact 能救一个已经混乱的对话。** 压一个垃圾对话，得到的只是更浓缩的垃圾。如果上下文已经被污染（Claude 开始重复、跑偏），就 clear 或开新会话，别 compact。✅（[Reddit 共识](https://www.reddit.com/r/ClaudeAI/comments/1p05r7p/)，社区）。
- ❌ **长程任务只靠上下文，不做笔记交接。** 上下文窗口填满只是时间问题。不写进度文件、不 git commit，新会话或 compact 之后就要从头猜之前干了什么。✅（[Effective harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)，官方，2025）。

---

## 延伸

**交叉引用：**
- [#010 CLAUDE.md 怎么写才真的生效？](./010-claude-md-how-to-make-it-work.md)：CLAUDE.md 在 compact 后会重新注入，根目录文件最稳。
- [#011 Context Engineering 和 Prompt Engineering 到底什么区别？](./011-context-vs-prompt-engineering.md)：上下文管理的理论框架。
- [#013 压缩一次它就忘了刚定的方案——哪些决策必须写进 memory 才扛得住 compact](./013-memory-what-to-remember.md)：记忆膨胀与 context rot 同源。

**参考资料：**
- [Effective context engineering for AI agents — Anthropic](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)：context rot、最小高信号 token 集、compaction 与 isolate 原理、何时用哪种策略（官方，2025-09）✅
- [Effective harnesses for long-running agents — Anthropic](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)：跨上下文窗口交接，即进度文件加 git commit 范式（官方，2025）✅
- [How we built our multi-agent research system — Anthropic](https://www.anthropic.com/engineering/multi-agent-research-system)：SubAgent 隔离与并行压缩原理；token 消耗 15 倍代价（官方）
- [Claude Code Docs: commands](https://code.claude.com/docs/en/commands) / [costs](https://code.claude.com/docs/en/costs) / [context-window](https://code.claude.com/docs/en/context-window) / [sub-agents](https://code.claude.com/docs/en/sub-agents) / [env-vars](https://code.claude.com/docs/en/env-vars) / [settings](https://code.claude.com/docs/en/settings) / [sessions](https://code.claude.com/docs/en/sessions) / [model-config](https://code.claude.com/docs/en/model-config) / [statusline](https://code.claude.com/docs/en/statusline)：`/compact`、`/clear`、`/rename`、`/context`、SubAgent、auto-compact 阈值与环境变量、statusline 字段的官方文档（官方，2026-08 核实）✅
- [Context Engineering for Agents — LangChain](https://www.langchain.com/blog/context-engineering-for-agents)：write/select/compress/isolate 四分法（社区权威，2025-07）✅。⚠️ 文中「Claude Code 约 95% 触发 auto-compact」是 2025 年的观测值，与 2026-08 官方文档口径不一致，本篇不采用。
- [Context Engineering for Agents — Latent Space (Lance Martin)](https://www.latent.space/p/context-engineering-for-agents-lance)：五类上下文操作加 Manus 50 次工具调用数据（社区，2025-09-11）
- [How Contexts Fail — Drew Breunig](https://www.dbreunig.com/2025/06/22/how-contexts-fail-and-how-to-fix-them.html)：四种上下文失效模式，即 poisoning、distraction、confusion、clash（社区，2025-06）✅
- [Lost in the Middle — arXiv:2307.03172](https://arxiv.org/abs/2307.03172)：长上下文中间信息回忆衰减的奠基论文（学术，2023-07）✅
- [Context Rot — Chroma Research](https://www.trychroma.com/research/context-rot)：性能下降源于上下文长度而非任务难度（研究，2025）✅
- [How to Use the /compact Command — MindStudio](https://www.mindstudio.ai/blog/claude-code-compact-command-context-management)：60% 主动压缩建议；compact 与新会话的决策（社区，2025）
- [How Claude Code Got Better by Protecting More Context — Hyperdev](https://hyperdev.matsuoka.com/p/how-claude-code-got-better-by-protecting)：Claude Code 压缩时对关键上下文保护的改进（社区，2025）
- [Reddit: Stop Claude Code from going dumb — auto-compact](https://www.reddit.com/r/ClaudeAI/comments/1r4tu3n/)：50% 后质量下滑的社区共识加 `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` 用法（社区，2025）
- [Cursor Docs: Max Mode](https://docs.cursor.com/context/max-mode)：Cursor 大窗口模式官方说明（官方）
- [VS Code Copilot Chat Context](https://code.visualstudio.com/docs/chat/copilot-chat-context) / [Copilot CLI Context Management](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/context-management)：Copilot `/compact`、auto-compact 80% 阈值、checkpoints（官方，2026-06）✅
- [GitHub Changelog: Larger context windows for Copilot](https://github.blog/changelog/2026-06-04-larger-context-windows-and-configurable-reasoning-levels-for-github-copilot/)：Copilot 1M token 上下文（官方，2026-06-04）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验——你在 Claude Code 里哪次上下文爆掉/compact 丢关键信息/靠 SubAgent 救场的踩坑案例]`
