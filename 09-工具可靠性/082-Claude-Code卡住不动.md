# 082. Claude Code 卡住不动 / Stream idle timeout / 长文件改到一半断了——怎么救回来？

> 难度：中级
> 主题：工具可靠性与供应商风险
> 工具：Claude Code · 横向(Cursor / Copilot / Gemini CLI)
> 题型：排错题

> ⏰ 时效声明：本篇分两层。**第一层「分诊流程」不依赖版本**，是长期有效的排查方法。**第二层「按症状的具体处置」引用了官方环境变量默认值与具体 issue 编号**，已于 **2026-08-03** 对照 [CC Docs: troubleshooting](https://code.claude.com/docs/en/troubleshooting)、[CC Docs: errors](https://code.claude.com/docs/en/errors)、[CC Docs: env-vars](https://code.claude.com/docs/en/env-vars) 核实。默认值和 issue 状态随版本变化即失效，照做前先看一眼官方页面。凡是「某版本有 bug、降级到某版本」这类结论，都写在最后一节并单独标了日期。

## TL;DR

**先分清是谁卡了，再动手。** 卡住不动有四种完全不同的原因，处置手段互相不通用：

| 你看到的现象 | 大概率是谁的问题 | 第一步做什么 |
|---|---|---|
| 转圈几分钟，token 计数**不涨** | 服务端 SSE 流卡住 | 随便再发一句话「踢」一下，或 Ctrl+C 后 `claude --resume` |
| 报 `API Error: Stream idle timeout` | 网络 / 流中断 | 调大 `API_TIMEOUT_MS`，检查网络与代理 |
| 报 `529 Overloaded` / 反复重试 | 供应商容量 | 看 status.claude.com，`/model` 换一个模型 |
| 某条 bash 命令挂住不返回 | 你的本地命令，不是 Claude Code | 调大 `BASH_DEFAULT_TIMEOUT_MS`，并让命令加 `--no-pager`、限定搜索目录 |

**别急着杀终端。** 官方明确说过：重启不会丢对话，在同一个目录跑 `claude --resume` 就能接回来。长文件改到一半断了，第一动作是 resume + 让它 `git diff` 自查改到哪了，而不是重来一遍。

**最容易被误诊的一类：token 计数还在涨的「卡住」其实不是卡住**，是模型在长思考。真卡住的判据是 token 计数停住不动。

**结构性预防只有两条真的有用**：把大任务拆小（单次输出别逼近上限），以及别让单条 bash 命令跑超过默认 2 分钟。其余都是止血。

---

## 为什么

### 1. 「卡住」是一个症状，不是一个故障

Claude Code 从你敲回车到出结果，中间至少经过四段：本地 CLI 进程 → 网络/代理 → Anthropic API 的流式响应（SSE）→ 本地工具执行（bash、文件读写、MCP）。任何一段停住，屏幕上看起来都一样：光标在转，什么都不发生。

所以「卡住怎么办」没有单一答案。你必须先定位是哪一段停了。好在这四段有很好区分的外部特征，下一节的分诊流程就是按这个来的。

### 2. 服务端流卡住是真实存在的，不是你配置错了

社区里量最大的一类反馈就是这个。[GH #26224](https://github.com/anthropics/claude-code/issues/26224)（社区，2026-02 起，约 150👍 / 126 评论）报告的现象是：会话卡在 thinking 状态 5–20 分钟以上，**token 用量在此期间完全不增长**，抓包看到的是在等 Anthropic 服务端的 SSE 数据。报告者试过全新安装、关掉所有 MCP 和扩展，没用。Anthropic 官方在该 issue 里有置顶回复确认正在排查（2026-02-23）。

这条对你的实际意义是：**当 token 计数停住时，检查自己的配置基本是浪费时间**。直接走「踢一下 / resume」这条路。

### 3. `Stream idle timeout` 有明确的官方阈值和对应变量

官方错误参考页把这类现象归为「Response stalled mid-stream」：流中断超过 20 秒会弹出等待横幅（advisor 调用是 90 秒），整个请求的超时由 `API_TIMEOUT_MS` 控制，默认 600000 毫秒（10 分钟）。官方给的判断标准很直接：如果这个横幅**每次尝试都出现**，那就按网络问题处理，而不是继续等。

同页还写明了哪些情况会自动重试、哪些不会：服务端错误、529、超时、响应开始前的连接中断会重试；TLS 证书失败、响应中途（某个 block 已完成后）的服务端错误不会重试。这解释了一个常见困惑——为什么有的错误自己就恢复了，有的直接把整轮丢掉。

### 4. bash 命令挂住是最常被误算到 Claude Code 头上的一类

`BASH_DEFAULT_TIMEOUT_MS` 默认 120000 毫秒（2 分钟），`BASH_MAX_TIMEOUT_MS` 默认 600000 毫秒。也就是说，你让它跑一个需要 5 分钟的构建，默认配置下 2 分钟就被掐掉，看起来像「Claude Code 卡住了又自己乱跳」。

反过来也有：在某些环境下（Windows 尤其常见）`find`、`ls`、`grep` 这类命令会因为扫到挂载点、网络盘、巨大目录而永不返回。这时卡住的是你的操作系统，Claude Code 只是在老实等。

### 5. 输出/思考触到上限时，报错和「还在跑」会同时发生

[GH #24055](https://github.com/anthropics/claude-code/issues/24055)（社区，约 85👍 / 139 评论，有 `has repro` 和 `oncall` 标签）记录了这个别扭的组合：任务跑了 8 分钟后弹出 `API Error: Claude's response exceeded the 32000 output token maximum`，但会话看起来还在继续跑，人完全不知道该等还是该停。错误信息本身提示了 `CLAUDE_CODE_MAX_OUTPUT_TOKENS` 这个变量。

这类的根因是单轮要产出的东西太多，把限制调大只是让它撞墙撞得晚一点。真正的解法在任务拆分，不在环境变量。

---

## 怎么做

### 第 0 步：先做 10 秒分诊，别乱按

看三个东西，顺序固定：

1. **token 计数在涨吗？** 状态行会显示类似 `↓ 35.0k tokens · thinking`。数字还在动 = 没卡，是长思考，继续等。数字停住超过 60 秒 = 真卡。
2. **有没有报错文字？** 有 `Stream idle timeout` / `529` / `exceeded ... token maximum` 就直接跳到对应小节，不要走通用流程。
3. **最后一个动作是什么？** 如果状态行停在某条 Bash 命令上，那是本地命令卡住，跟 API 无关。

**怎么判断做对了**：你能用一句话说出「卡在哪一段」。说不出来就别往下做，回来重看这三条。

### 第 1 步：会话卡住且 token 不涨 —— 先踢，再 resume

按顺序试，一步不通再试下一步：

```
# 1) 直接在输入框再发一句话（内容随意，比如 "status?"），有相当比例的卡死会被这一下踢活
# 2) 不行就 Ctrl+C 取消当前操作
# 3) 还是没反应，直接关掉终端窗口
# 4) 回到同一个目录，接回原会话：
claude --resume
```

官方 troubleshooting 页对这一段的原话是：先按 Ctrl+C 尝试取消；仍无响应就关闭终端重启；**重启不会丢对话**，在同一目录跑 `claude --resume` 就能接回来。

**怎么判断做对了**：`claude --resume` 列出会话列表，选中后能看到你刚才那轮的历史对话。看得到历史 = 上下文没丢。

### 第 2 步：resume 之后先对账，别接着往下改

这是「长文件改到一半断了」的关键动作。断点之后你不知道文件处于什么状态，直接让它继续改会叠加出更烂的结果。

```bash
git status
git diff
git stash list
```

然后在会话里给一句明确指令：

```
先不要写任何代码。跑 git diff，逐个文件告诉我：
1) 哪些改动已经落盘且是完整的
2) 哪些文件改了一半（比如函数没闭合、import 没补）
3) 你原计划要改但还没动的
列完等我确认再继续。
```

**怎么判断做对了**：它给出的「已完成 / 半截 / 未开始」三分清单，和你 `git diff` 看到的一致。不一致说明它在猜，重新让它逐文件读。

如果改到一半的文件已经语法都不成立，最省事的是把那个文件单独回退再重做这一个文件：

```bash
git checkout -- path/to/broken-file.ts
```

**怎么判断做对了**：`git diff` 里这个文件消失，项目能重新通过语法检查 / 构建。

### 第 3 步：报 `Stream idle timeout` / 流反复中断 —— 调超时 + 查网络

先把超时和重试放宽。推荐写进 settings.json 而不是临时 export，这样重启终端也在：

```jsonc
// ~/.claude/settings.json（对你所有项目生效）
{
  "env": {
    "API_TIMEOUT_MS": "1200000"
  }
}
```

配置文件的三个作用域，按需选：

| 文件 | 作用范围 |
|---|---|
| `~/.claude/settings.json` | 你，所有项目 |
| `.claude/settings.json` | 本项目所有人（提交进仓库） |
| `.claude/settings.local.json` | 你，仅本项目（不提交） |

**怎么判断做对了**：改完重启 Claude Code，跑 `/doctor`，确认设置被读到、没有 JSON 语法报错。

如果调大之后横幅**依然每次都出现**，按官方说法这就是网络问题，别再折腾变量了。这时查这几样：公司代理 / VPN、`HTTPS_PROXY` 环境变量、以及 status.claude.com 有没有在报事故。

### 第 4 步：报 `529 Overloaded` —— 换模型或等，别死磕

官方给的处置是三条：

1. 看 [status.claude.com](https://status.claude.com) 是否有事故
2. 过几分钟再试
3. 在会话里跑 `/model` 换一个模型——**容量是按模型分的**，Opus 满了不代表 Sonnet 也满

如果是 CI 或者无人值守的场景，官方提供了一个专门的开关，让它对 429/529 无限重试：

```jsonc
{
  "env": {
    "CLAUDE_CODE_RETRY_WATCHDOG": "1"
  }
}
```

注意这个变量的适用面：它适合跑批、无人盯着的任务；交互式使用时开着它，只会让你对着一个永远在重试的界面干等。相关的还有 `CLAUDE_CODE_MAX_RETRIES`（默认 10，上限 15；开了 watchdog 后这个上限被移除）。

**怎么判断做对了**：换模型后同一个请求能正常出结果 = 是容量问题，不是你的问题。

### 第 5 步：卡在某条 bash 命令 —— 放宽超时，同时改命令本身

两件事都要做，只做一件不够。

放宽超时：

```jsonc
{
  "env": {
    "BASH_DEFAULT_TIMEOUT_MS": "300000",
    "BASH_MAX_TIMEOUT_MS": "900000"
  }
}
```

改命令本身（这条更重要，因为超时调多大都救不了一个永不返回的命令）。在 CLAUDE.md 里写死约束，比每次口头提醒有效：

```markdown
## 命令执行约束
- 搜索一律用 rg 并限定目录，禁止在仓库根跑无限定的 find / grep
- git 命令带 --no-pager，禁止进入交互式分页器
- 任何可能超过 2 分钟的命令（构建、全量测试），先告诉我，由我在外部终端跑
```

**怎么判断做对了**：下次它跑搜索时用的是 `rg 'xxx' src/` 这种带目录限定的形式，而不是从仓库根开始扫。

顺带一个官方的相关项：如果 Search 工具、`@file` 补全找不到文件，可能是内置 ripgrep 在你的系统上跑不起来。装系统版并让它改用系统版：

```bash
brew install ripgrep          # macOS
# 然后在 settings.json 的 env 里设 USE_BUILTIN_RIPGREP=0
```

**怎么判断做对了**：终端跑 `claude doctor`，Search 那一行显示的是你系统 ripgrep 的路径，而不是 `OK (bundled)`。

### 第 6 步：报 `exceeded the 32000 output token maximum` —— 先拆任务，其次才是调上限

顺序不要反。正确的第一动作是把任务切开：

```
这个任务太大了，一轮做不完。先只做第一步：只改 src/auth/ 下的文件，
其他目录一个字都不要动。做完停下来等我确认。
```

确实需要更大的单轮输出时（比如一次要生成一个长文档），再调：

```jsonc
{
  "env": {
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "64000"
  }
}
```

**怎么判断做对了**：同样的任务不再中途报这个错。如果调大后还是撞，说明拆分没做够，回到第一动作。

### 第 7 步：怀疑是自己的配置搞出来的 —— 用干净配置对照一次

这一步是用来做二分定位的，怀疑插件 / MCP / hook 拖慢或卡住时用：

```bash
claude --safe-mode
```

它会关掉本次会话的所有自定义项。如果在 safe-mode 下问题消失，那就是你某个 MCP / 插件 / hook 的锅，接着逐个开回来定位。

配套的两个检查命令：

```
/doctor      # 检查安装、设置、扩展、上下文占用，会提出可确认执行的修复
/mcp         # 看各 MCP server 的连接状态
```

如果 `claude` 根本起不来，就在终端里跑 `claude doctor`（不带斜杠）。

**怎么判断做对了**：你能说出「开着 X 就卡，关掉 X 就不卡」这样的对照结论。

### 第 8 步：结构性预防（做完上面才做这个）

- **上下文别撑满**。上下文压到极限时更容易出现长时间无响应和 auto-compact 反复。官方对 `Autocompact is thrashing` 的处置是：让它按行范围分块读大文件、用带焦点的 `/compact`（如 `/compact keep only the plan and the diff`）、把大文件的活丢给 subagent 隔离、或者直接 `/clear`。
- **大任务先出计划再执行**，每步之间有落盘和确认点。这样任何一步断了，损失只有一步。
- **随手 commit**。断点恢复的成本，和你上次 commit 的距离成正比。

---

## Claude Code 实战

一份可以直接抄的 `~/.claude/settings.json`，把上面几个变量集中在一起（数值按自己情况调）：

```jsonc
{
  "env": {
    "API_TIMEOUT_MS": "1200000",
    "BASH_DEFAULT_TIMEOUT_MS": "300000",
    "BASH_MAX_TIMEOUT_MS": "900000"
  }
}
```

注意优先级：**shell 里 export 的环境变量优先于 settings.json 的 `env` 块**。如果你改了 settings.json 却不生效，先看看 shell 配置里是不是已经 export 过同名变量。

一段可复用的「断点恢复」提示词，卡死重启后直接贴：

```
上一轮执行被中断了。现在按顺序做，做完一步停一步：
1. 跑 git status 和 git diff，报告当前工作区的真实状态
2. 对照你上一轮的计划，标出「已完成 / 改了一半 / 未开始」
3. 对「改了一半」的文件，只说清楚缺什么，不要动手补
4. 等我确认后，从第一个未完成项继续

在我确认之前，不要写入任何文件。
```

---

## ⚠️ 版本相关的 workaround（时效性最强，2026-08-03 状态）

**这一节里的内容随版本更新即失效，看之前先确认你的版本和下面对不上。** 上面的分诊流程无论版本怎么变都成立，这一节只是补充。

- **`Stream idle timeout` 在 2.1.92 附近有一波集中报告**。[GH #46987](https://github.com/anthropics/claude-code/issues/46987)（社区，2026-04）报告者称 2.1.90 正常、2.1.92 开始复现，issue 被打了 `duplicate` 标签，说明是已知问题的一个实例。当时社区的做法是降级回上一个可用版本。**这个动作现在不建议无脑照抄**：降级会同时丢掉后续所有修复，只在你能明确复现「换版本就好 / 就坏」时才用。
- **「tool call could not be parsed（retry also failed）」**：[GH #63875](https://github.com/anthropics/claude-code/issues/63875)（社区，2.1.158）和 [GH #62123](https://github.com/anthropics/claude-code/issues/62123)（社区，2.1.150）都是这个，标记为 `area:model`，即模型侧问题。现象是工具调用直接被丢弃、内置重试也失败。目前没有官方 workaround，社区做法是手动重发、把大 payload 拆小、避免往参数里塞超长代码块。这类不需要你改任何配置。
- **v2.1.208 之前**，会话里如果有超大 Markdown 表格，resume 时会因为重新渲染每一行而卡住。新版本已经改成只渲染前 200 行。如果你卡在 resume 那一刻，先升级版本。

判断这一节还有没有效的方法：去对应 issue 页面看是否已关闭，以及自己跑一次 `claude doctor` 看当前版本。

---

## 反模式

- ❌ **一卡住就杀终端重开新会话** —— 官方明确说重启不丢对话，`claude --resume` 能接回来。开新会话等于把已经付过费的上下文全扔了，还要重讲一遍需求。
- ❌ **resume 之后直接说「继续」** —— 它不知道断在哪，会凭上一轮的计划猜，把已经改过的文件再改一遍，或者跳过实际没做完的那步。必须先对账再继续。
- ❌ **看到转圈就认定是自己配置错了，去翻 MCP、翻插件** —— token 计数不涨的那种卡死是服务端 SSE 问题（[GH #26224](https://github.com/anthropics/claude-code/issues/26224)），报告者全新安装、零 MCP 也照样复现。先看 token 计数再决定要不要查配置。
- ❌ **把 `CLAUDE_CODE_MAX_OUTPUT_TOKENS` 一路调大当成解法** —— 这只是让撞墙来得晚一点，而且单轮输出越长，中途出问题的损失越大。根因是任务没拆。
- ❌ **交互式使用时开着 `CLAUDE_CODE_RETRY_WATCHDOG=1`** —— 这个开关的设计场景是 CI / 无人值守。人盯着屏幕时开它，你会对着一个永远在重试的界面等下去，而不是尽早换模型。
- ❌ **看到社区 issue 说「降级到 X 版本」就照做** —— 降级会丢掉这期间所有的修复和安全更新，还可能撞上早就修好的老 bug。只在你能自己复现「换版本症状就变」时才用，并且尽快升回来。
- ❌ **只调 `BASH_DEFAULT_TIMEOUT_MS` 不改命令** —— 一个在仓库根跑 `find /` 的命令，超时给到 1 小时它也不会返回。超时是给「慢」用的，不是给「永不返回」用的。

---

## 延伸

**交叉引用：**
- [#012 上下文窗口要爆了怎么办？](../02-上下文工程/012-上下文窗口要爆了.md) —— 上下文压满时更容易触发 auto-compact 反复和长时间无响应，这一篇讲怎么从源头控住
- [#043 AI 改不对 bug、陷入 fix loop / 越改越糟，什么时候必须停、怎么跳出？](../05-质量保证/043-fix-loop什么时候必须停.md) —— 「反复重试不见效」的另一种形态，判停标准可以互相参考
- [#031 让 AI 改一个小功能，它却动了一堆无关文件怎么办？（plan → execute → review 循环）](../04-执行工作流/031-plan-execute-review循环.md) —— 计划分步执行是断点恢复成本最低的工作方式
- [#032 开几个 agent 并行跑，结果互相踩、被限流、token 指数级炸开——并行到底该开几个？](../04-执行工作流/032-SubAgent并行开几个.md) —— 并行度过高本身就会制造限流和「像卡住」的等待

**参考资料：**
- [Troubleshooting — Claude Code Docs](https://code.claude.com/docs/en/troubleshooting) — 官方的 hang/freeze 处置、`claude --resume` 不丢对话、`--safe-mode`、`/doctor`、ripgrep 与 auto-compact thrashing（官方，核实于 2026-08）
- [Error reference — Claude Code Docs](https://code.claude.com/docs/en/errors) — 「Response stalled mid-stream」阈值、529 处置、重试规则与 `CLAUDE_CODE_RETRY_WATCHDOG` / `CLAUDE_CODE_MAX_RETRIES`（官方，核实于 2026-08）
- [Environment variables — Claude Code Docs](https://code.claude.com/docs/en/env-vars) — `API_TIMEOUT_MS` / `BASH_DEFAULT_TIMEOUT_MS` / `BASH_MAX_TIMEOUT_MS` 的默认值、settings.json 三级作用域与优先级（官方，核实于 2026-08）
- [GH #26224：Claude Code 卡住 5–20 分钟、token 不增长](https://github.com/anthropics/claude-code/issues/26224) — 服务端 SSE 卡住的典型报告，Anthropic 有置顶回复确认在查（社区，2026-02）
- [GH #46987：API Error: Stream idle timeout - partial response received](https://github.com/anthropics/claude-code/issues/46987) — 2.1.92 附近的集中报告，标记为 duplicate（社区，2026-04）
- [GH #24055：response exceeded the 32000 output token maximum](https://github.com/anthropics/claude-code/issues/24055) — 输出上限报错但会话仍在跑的复合现象，带 has repro / oncall 标签（社区，核实于 2026-08）
- [GH #63875 / #62123：tool call could not be parsed (retry also failed)](https://github.com/anthropics/claude-code/issues/63875) — 模型侧工具调用解析失败，无配置层解法（社区，核实于 2026-08）
- [status.claude.com](https://status.claude.com) — 判断是不是供应商侧事故的第一站（官方）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
