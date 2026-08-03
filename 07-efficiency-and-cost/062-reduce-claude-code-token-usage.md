# 062. 怎么少烧 token？prompt caching / 精简 CLAUDE.md / 模型切换哪个最有效？

> 难度：中级
> 主题：效率与成本
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：流程题 + 配置题

> ⏰ 时效声明：本篇的缓存倍率（write 1.25×/2.0×、read 0.1×）、TTL 免费续期、前缀失效层级、最小可缓存前缀（Fable 5=512 / Opus 4.8=1024 / Opus 4.7=2048 / Opus 4.6=4096 等）、"最高省 ~90%"说法与官方 costs 页各项策略已于 **2026-07-18** 对照官方文档核实无误。倍率与最小前缀属可调定价参数，随官方更新即失效，请以官方页面为准。

## TL;DR

"哪个最有效"其实是个伪问题。这三个手段不在同一个层面上，作用各不相同，没法直接比。下面按它们各自的角色说清楚。

**第一，prompt caching 是自动的，默认就开着，你的任务是别打断它。**

prompt caching 指的是：系统提示、CLAUDE.md 这些每一轮都要重发的开头内容，Claude Code 会缓存下来，命中缓存时只按大约 0.1× 的输入价计费。官方称长提示最高能省约 90% 成本（✅）。你不需要手动"开启"它。你要做的是别去破坏它：中途连接或断开 MCP、换模型、改 CLAUDE.md，都会让缓存的前缀失效，被迫按全价重新计算。这一层收益最大，但也最容易被无意破坏。

**第二，精简 CLAUDE.md 加上主动清理上下文，是你手动能拿到的最大收益。**

CLAUDE.md 每一轮、每个会话都常驻在上下文里，是你唯一能完全控制的常驻成本。上下文随着对话越滚越大，则是长会话烧钱的主因。用 `/clear` 和 `/compact` 主动管理它。官方把这两条都列进了"reduce token usage"。

**第三，模型切换有效，但它是路由决策，不是单纯的省 token 动作。**

贵模型单价高，但往往更省 token，因为它试错更少。本篇只给经济上的注脚，具体怎么选模型归 [#063](./063-model-routing-when-to-use-opus.md)。

一句话总结：caching 是地基，别去拆它；精简 CLAUDE.md 和 `/clear` 是你每天都要拧的两颗螺丝；模型切换是另一道题。想先量化自己烧了多少，看 [#060](./060-how-much-does-claude-code-cost-per-day.md)。

## 为什么

### 1. 你在为"每一轮重发的前缀"反复付费

Claude Code 每发一条消息，模型都要重新处理整个上下文。这包括系统提示、CLAUDE.md、全部历史、MCP 工具定义，再加上你的新输入。

之所以每轮都要重发，是因为 API 是无状态的，它不记得上一轮。所以这些开头内容每一轮都要原样送一遍。

这就解释了为什么"打个招呼"也不便宜。真正的开销来自启动时就加载的固定内容，而不是你打的那几个字。社区里反复出现类似吐槽：有人测出非交互式发一句"你好"就吃掉约 15 万 token（[V2EX 1153108](https://v2ex.com/t/1153108)，2025-08，⚠️ 单源个例）；也有人说跟 Claude 说声 hello 就烧掉约 2% 的会话额度（[r/ClaudeCode](https://www.reddit.com/r/ClaudeCode/comments/1s54q0d/it_costs_you_around_2_session_usage_to_say_hello/)，⚠️）。

### 2. prompt caching：默认已开的省钱地基（机制速查）

官方 costs 文档写得很清楚：Claude Code 会自动用 prompt caching 降低重复内容（例如系统提示）的成本，并配合 auto-compaction 在接近上限时压缩历史（[CC Docs: Manage costs](https://code.claude.com/docs/en/costs)，官方，2026-06 ✅）。

机制只有三块：倍率、TTL（time to live，缓存的有效期）、前缀失效。

**倍率。** 以 Anthropic 官方为准，社区口口相传的数字一律存疑。

| 动作 | 计费倍率（相对基础输入价） |
|------|--------------------------|
| cache read（命中） | **0.1×** ✅ |
| cache write（5 分钟 TTL） | **1.25×** ✅ |
| cache write（1 小时 TTL） | **2.0×** ✅ |

来源：[Anthropic Prompt Caching 文档](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)（官方）。

经济含义就是回本点：5 分钟 TTL 下写一次 1.25×、再命中一次 0.1×，两次合计 1.35×，低于两次全价的 2×，第二次请求就回本。1 小时 TTL 写贵一倍，两次合计 2.1× 反而超过 2×，要到第三次（2.0× + 两次 0.2× = 2.2× < 3×）才回本。所以 TTL 是按请求间隔选的经济题，不是越长越省。

**TTL 会自动免费续期。** 官方原文是 "The cache is refreshed for no additional cost each time the cached content is used"，缓存内容每被用一次就免费续一次期。只要请求间隔小于 TTL，缓存一直是热的，绝大部分前缀按 0.1× 计费；一旦冷掉就要重新付写入费。这也是为什么真实账单里 cache read 往往占大头。HN 上一位实测者复盘 70 天的完整账单，缓存命中率高达 88.8%（[HN 45914307](https://news.ycombinator.com/item?id=45914307)，2025-11，⚠️ 单源个例；该帖标题写的是「6 周 $638」，88.8% 出自作者评论里覆盖 70 天的那组统计，口径差异见 [#060](./060-how-much-does-claude-code-cost-per-day.md)）。这个个例和官方"多数用量来自缓存"的定调一致。

**前缀失效。** 缓存是前缀精确匹配，官方原文是 "Cache hits require 100% identical prompt segments"，逐字节一致才算命中。渲染顺序是 `tools → system → messages`，哪一层变了，该层及其之后全部失效：

| 改动 | tools 缓存 | system 缓存 | messages 缓存 |
|------|:---:|:---:|:---:|
| 工具定义（增删改/重排）、切模型 | ✘ | ✘ | ✘ |
| system prompt 内容、web search / citations 等开关 | ✓ | ✘ | ✘ |
| message 内容、`tool_choice`、图片有无、thinking 参数 | ✓ | ✓ | ✘ |

✓ 表示该层缓存仍有效，✘ 表示失效。来源：[Anthropic Prompt Caching 文档](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)（官方）。

这张表落到日常，就是三个会意外拆掉地基的动作：中途连接或断开 MCP server（改了排在最前的 tools，整段作废）、中途切换模型（缓存按模型隔离，等于冷启动重写）、每轮改 CLAUDE.md 或往里注入时间戳（CLAUDE.md 在 system 段，其后全失效）。

另外，能被缓存的前缀有个最小长度，且随模型不同：Fable 5 是 512，Opus 4.8 / Sonnet 5 / Sonnet 4.6 / Sonnet 4.5 是 1024，Opus 4.7 是 2048，Opus 4.6 / Opus 4.5 / Haiku 4.5 是 4096（✅）。前缀短于这个值会被静默地不缓存，而且不报错。

想逐请求确认到底有没有命中，看 API 响应 `usage` 里的 `cache_creation_input_tokens`（这次是写入）和 `cache_read_input_tokens`（这次是命中读取）两个字段。

### 3. CLAUDE.md 是你唯一能完全控制的常驻成本

官方在"reduce token usage"里专门列了一条：CLAUDE.md 在会话启动时就载入上下文；如果里面塞了特定工作流的详细指令（比如 PR 审查、DB 迁移的步骤），那么即使你在做无关的活，这些 token 也一直占着。官方给的建议是把专项指令移进 skills 按需加载，并把 CLAUDE.md 控制在 200 行以内（[CC Docs: Manage costs](https://code.claude.com/docs/en/costs)，官方 ✅）。

CLAUDE.md 每个会话、每一轮都常驻，同时又是你能直接删改的最大一块，所以它是最值得优化的目标。

社区有过实测：把一份约 3800 token 的 CLAUDE.md 砍到 300 出头，只保留 Claude 无法从代码里推断出来的信息，结果拿到了大幅的上下文缩减，而且没有质量回退（[firecrawl: 12 Ways to Cut Token Consumption](https://www.firecrawl.dev/blog/claude-code-token-efficiency)，⚠️ 社区个例）。

CLAUDE.md 具体怎么写才生效，见 [#010](../02-context-engineering/010-claude-md-how-to-make-it-work.md)。

### 4. 上下文越滚越大，才是长会话真正烧钱的地方

官方点名了两个最该纠正的高开销习惯：跨不相关的任务不清空历史，以及把 Opus 一直留作默认模型（[CC Docs: Manage costs](https://code.claude.com/docs/en/costs)，官方 ✅）。

前者对应 `/clear`，后者对应模型路由。

上下文膨胀本身的机制（窗口塞不下时怎么用 `/compact`、`/clear`）见 [#012](../02-context-engineering/012-context-window-exploding.md)。本篇只讲它的降本一面。

## 怎么做

下面这份 checklist 按"性价比 × 你能控制的程度"排序。先做不花力气就有收益的（1–2），再拧手动螺丝（3–6），最后才是进阶手段（7–9）。

1. **别拆掉缓存地基。** MCP server 只在会话开始时连好，不要中途连或断；一段会话内不要频繁切模型；不要每轮把时间戳或 UUID 注进 CLAUDE.md 或系统提示。这条不需要你多做什么，只需要不做破坏动作。（✅）

2. **少挂 MCP。** MCP 工具定义默认是延迟加载的，也就是只有工具名进上下文，用到时才载入完整 schema，但它仍然是开销。官方建议：能用命令行工具（`gh`、`aws`、`gcloud`）就别用 MCP，因为 CLI 不占用工具列表；用 `/mcp` 看已配置的，停掉没在用的（[CC Docs](https://code.claude.com/docs/en/costs)，官方 ✅）。

3. **把 CLAUDE.md 精简到 200 行以内。** 原则是：Claude 能从读代码推断出来的，删掉；专项工作流指令下沉到 skills 按需加载。（✅）

4. **切换到不相关的任务时就 `/clear`。** 别把四小时的历史拖进后续的每一条消息。官方原话是"stale context wastes tokens on every subsequent message"（陈旧的上下文会在之后每条消息上都浪费 token）。清空后想找回旧会话，用 `/rename` 配 `/resume`。（✅）

5. **主动 `/compact`，并告诉它保留什么。** 不要等窗口爆了才压缩。用 `/compact Focus on code samples and API usage` 这样的写法指定要保留的内容；也可以写进 CLAUDE.md 的 `# Compact instructions` 段固化下来（[CC Docs](https://code.claude.com/docs/en/costs)，官方 ✅）。

6. **写具体的 prompt。** "improve this codebase" 会触发全库扫描；"add input validation to the login function in auth.ts" 则让它读最少的文件就开工（官方 ✅）。改动前先用 plan mode（连按两次 `Shift+Tab`）探一探再动手，避免走错方向后的昂贵返工。

7. **用 hooks 预处理，把冗长操作丢给 subagent。** PreToolUse hook 可以先 `grep ERROR` 再把结果喂给 Claude，把一万行日志压到几百 token。跑测试、抓文档、处理日志这类会产生大量输出的活，交给 subagent 去做，冗长内容留在子上下文里，只把摘要回给主上下文（官方 ✅）。

8. **调低 extended thinking。** thinking token 按 output 价计费，默认预算每请求可达数万。简单任务可以用 `/effort` 降级、用 `/config` 关掉思考，或设 `MAX_THINKING_TOKENS=8000`（官方 ✅）。成本机制的细节另见成本主题专篇。

9. **给类型语言装 code intelligence 插件。** code intelligence 指的是像 IDE 那样精确跳转符号定义的能力。它能替代文本搜索，一次"go to definition"就省下 grep 加上翻阅多个候选文件的 token（官方 ✅）。

### 用哪个命令查"钱花哪了"

三条内建命令是排查的第一步：

- `/context`：显示上下文窗口里每个元素的 token 占比，包括系统提示、CLAUDE.md、MCP、历史。
- `/usage`：把近期用量归因到 skills、subagents、plugins 和各个 MCP server（订阅计划下按占比显示），用 `d` 和 `w` 切换 24 小时和 7 天视图。
- `/memory`：列出各层级 CLAUDE.md 和 memory 文件的位置并打开编辑。官方现在明确它只负责列位置和开关，不显示"本会话实际加载了什么"，那是 `/context` 的活（[CC Docs: Memory](https://code.claude.com/docs/en/memory)，官方 ✅）。

## Claude Code 实战

### 一个 hook：把测试输出过滤成只剩失败行（官方示例）

这个 hook 在跑测试时改写命令，只回 FAIL/ERROR 附近的行，把测试输出从上万 token 压到几百。

先在 `settings.json` 里注册 hook：

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [
        { "type": "command", "command": "~/.claude/hooks/filter-test-output.sh" }
      ]}
    ]
  }
}
```

再写 `~/.claude/hooks/filter-test-output.sh`（节选）：

```bash
#!/bin/bash
input=$(cat); cmd=$(echo "$input" | jq -r '.tool_input.command')
if [[ "$cmd" =~ ^(npm test|pytest|go test) ]]; then
  filtered="$cmd 2>&1 | grep -A 5 -E '(FAIL|ERROR|error:)' | head -100"
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"updatedInput\":{\"command\":\"$filtered\"}}}"
else echo "{}"; fi
```

来源：[CC Docs: Manage costs](https://code.claude.com/docs/en/costs)（官方，2026-06 ✅）。

### 一个 `/clear` 加交接文件的工作流

`/clear` 会整段清空历史，所以"不心疼"的做法是先落盘再清。

具体做法：干完一段活后，让 Claude 写一个 `session-handoff.md`，记下当前目标、改过的文件、关键决策、失败的测试和下一步；然后 `/clear`；开新会话时说 "Read session-handoff.md and continue."。

一份交接文件比把四小时对话拖进每条后续消息便宜得多（[firecrawl blog](https://www.firecrawl.dev/blog/claude-code-token-efficiency)，⚠️ 社区实践）。

### CLAUDE.md 该放什么、不该放什么（成本视角）

| 放进 CLAUDE.md（每轮常驻，值这个价） | 移出去（按需加载才划算） |
|------|------|
| 技术栈、构建/测试命令、核心目录约定 | PR 审查清单 / DB 迁移步骤 → skill |
| 每次都适用的红线（如"金额用整数分"） | 临时计划 → issue tracker |
| 指针（`@docs/architecture.md`，用时才读） | Claude 能从代码推断的一切 → 删 |

## 横向对比

| 工具 | 省 token 的主要机制 | 与 Claude Code 的差异 |
|------|--------------------|----------------------|
| **Claude Code** | 自动 prompt caching（0.1× read）+ auto-compaction + `/clear`/`/compact`/CLAUDE.md 瘦身 + MCP 延迟加载 + hooks/subagent 预处理 | 缓存是默认地基、可用命令细粒度归因（`/context`/`/usage`）；控制点最丰富 |
| **Cursor** | 上下文按需检索（codebase index）+ 手动 @ 引用 + 模型档位选择 | 更偏"选对上下文喂进去"，没有等价的 per-session 缓存纪律概念；成本多按订阅额度/请求计 |
| **GitHub Copilot** | 主要靠订阅/席位（月费固定），无逐 token 计费暴露给用户 | 用户几乎不直接管 token；省钱空间小，代价是控制力也小 |

核心差异在于控制权的位置。Claude Code 把 token 成本的控制权大量交给用户：能看、能清、能改前缀、能配 hook。Cursor 偏向帮你"选对上下文"。Copilot 则把成本封装进订阅，用户基本不感知。控制力越强，"会不会用"造成的账单差异就越大。

## 反模式

- ❌ **中途连接或断开 MCP server。** 一次操作就作废整段 prompt cache，之后每一轮都全价重写，比一直多挂那个 server 还贵。MCP 要在会话开始时就配好。（✅）
- ❌ **一段会话里反复切模型。** 缓存按模型隔离，切一次就等于冷启动。想用便宜模型跑苦力，就派 subagent 并配 `model: haiku`，别在主循环里换。（✅）
- ❌ **无脑上 1 小时 TTL 想更省。** 1 小时写入是 2.0×，要三次以上请求才回本；请求密集时反而不如默认的 5 分钟（1.25×、两次就回本）。TTL 按请求间隔选，不是越长越省。（✅）
- ❌ **把 CLAUDE.md 当垃圾桶。** 塞满一次性指令、能从代码推断的东西、临时计划。它每轮每会话都常驻，300 行的 CLAUDE.md 就是持续的 token 税，而且内容越多遵守率还越低（见 [#010](../02-context-engineering/010-claude-md-how-to-make-it-work.md)）。
- ❌ **等窗口爆了才 `/compact`，跨任务从不 `/clear`。** 官方点名"长会话不清空"是最该纠正的高开销习惯之一。应该在完成子任务后就主动压缩或清空。（✅）
- ❌ **让 Claude 先"确认理解"或"复述需求"。** 这类"summarize the requirements before you start"会让它把你整段 prompt 复述回来，纯浪费。直接让它开工就行。（⚠️ 社区共识）
- ❌ **无脑并行一堆 subagent 或 agent team。** agent team（plan mode）大约要用 7× 的 token（官方 ✅），消耗和队友数量成正比。并行的经济账另见成本主题；不是所有活都值得铺开并行。
- ❌ **把"少烧 token"等同于"用最便宜的模型"。** 贵模型单价高，但往往更省 token，因为试错更少。这是路由题，不是省 token 题，见 [#063](./063-model-routing-when-to-use-opus.md)。

## 延伸

**交叉引用：**
- [#060 额度怎么突然就没了？20x Max 也撑不过一上午——先算清自己一天该烧多少](./060-how-much-does-claude-code-cost-per-day.md) —— 先测自己的消耗基准，再谈省。
- [#063 什么时候该用 Opus、什么时候该用 Sonnet/Haiku？怎么按任务路由模型才不浪费？](./063-model-routing-when-to-use-opus.md) —— 本篇第 3 条"模型切换"的完整决策篇。
- [#010 CLAUDE.md 怎么写才真的生效？](../02-context-engineering/010-claude-md-how-to-make-it-work.md) —— 本篇"精简 CLAUDE.md"的写法攻略。
- [#012 上下文窗口要爆了怎么办？](../02-context-engineering/012-context-window-exploding.md) —— `/compact`/`/clear` 的机制侧（本篇讲降本侧）。

**参考资料：**
- [Manage costs effectively — Claude Code Docs](https://code.claude.com/docs/en/costs) — 全套省 token 策略：caching、auto-compaction、`/clear`/`/compact`、CLAUDE.md 移入 skills、MCP 降噪、hooks/subagent、extended thinking、模型选择（官方，2026-06）✅
- [Prompt caching — Anthropic Docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) — 倍率（write 1.25×/2.0×、read 0.1×）、TTL 免费续期、前缀匹配不变量、缓存失效层级、最小可缓存前缀（官方）✅
- [firecrawl: 12 Ways to Cut Token Consumption in Claude Code](https://www.firecrawl.dev/blog/claude-code-token-efficiency) — CLAUDE.md 瘦身、handoff 文件、`/context`/`/usage`/`/memory` 用法（社区，⚠️ 个例数据待核）
- [HN 45914307: I spent $638 on AI coding agents in 6 weeks](https://news.ycombinator.com/item?id=45914307) — 6 周实测（作者评论另给出覆盖 70 天的统计）、缓存命中率 88.8%、"50k tokens 探死路才换来 5k 的解"（社区，2025-11，⚠️ 单源个例）
- [V2EX 1153108: Claude Code 使用 API 费用消耗很大](https://v2ex.com/t/1153108) — 非交互式一句"你好" ~15 万 token（社区，2025-08，⚠️ 单源个例）
- [r/ClaudeCode: It costs you around 2% session usage to say hello](https://www.reddit.com/r/ClaudeCode/comments/1s54q0d/it_costs_you_around_2_session_usage_to_say_hello/) — 固定启动开销的社区吐槽（社区，⚠️）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
