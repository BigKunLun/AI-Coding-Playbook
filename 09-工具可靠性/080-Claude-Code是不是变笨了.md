# 080. 今天 Claude Code 是不是变笨了？——怎么分清模型降级、effort 降档和自己用法退步

> 难度：中级
> 主题：工具可靠性与供应商风险
> 工具：Claude Code · 横向(Cursor / Copilot / Gemini CLI)
> 题型：排错题

## TL;DR

**信息日期：2026-08。涉及具体版本号与配置项，请以官方文档当前内容为准。**

「变笨了」是 anthropics/claude-code 仓库热度第一的话题，也是 2026 上半年 HN 上榜三次以上的周期性帖子。它有时是真的，有时不是。三十秒结论：

1. **先别急着写长帖，先看四个客观量**：`claude --version`（是不是刚自动更新过）、会话头上的 effort 标记（是不是从 high 掉到了 medium）、[status.claude.com](https://status.claude.com/) （是不是平台事故）、你这次会话的上下文有没有被压缩过。四个里任意一个变了，就够解释「变笨」。
2. **主观感受不能当证据**。官方两次复盘都写明：变更只影响部分流量切片，早期报告根本无法和正常波动区分，连内部 evals 一开始都复现不出来。你需要的是**一组固定题目 + 固定 prompt 的回归集**，不是体感。
3. **确实发生过真降级，但降的是客户端脚手架，不是模型权重**。2026 年 4 月那次，Anthropic 复盘认定三项变更：3 月 4 日把 Claude Code 默认 reasoning effort 从 high 降到 medium；3 月 26 日清理闲置会话旧思考的改动有 bug，变成每轮都清；4 月 16 日一条「减少啰嗦」的系统提示词让编码质量掉了 3%。**API 直连全程未受影响**——这条信息本身就是最有用的对照实验设计。
4. **能自己兜住的三件事**：把模型钉到具体版本名而不是别名、把 effort 显式写进配置、把自动更新切到 `stable` 频道。三条都是官方文档里的正式配置项。
5. **大多数「变笨」是第三种情况**：上下文脏了、任务变难了、你开始把更大的活一次性丢给它了。这类不用等官方修，改用法就好。

## 为什么

「今天是不是变笨了」之所以特别难判断，是因为四个原因同时长得一模一样。

**第一，模型输出本身有方差。** 同一个 prompt 跑两次结果不同是常态。人在心情好的时候把好结果记成「正常水平」，心情差的时候把差结果记成「降级了」。单次体验的信噪比接近零。

**第二，客户端会悄悄变。** 你用的不是模型，是「模型 + 系统提示词 + 上下文管理策略 + effort 配置」这一整套脚手架。Claude Code 默认后台自动更新，装完下次启动生效——也就是说昨天和今天你跑的可能根本不是同一个客户端。2026 年 4 月的三项变更全部在这一层：effort 默认值、思考token 清理逻辑、系统提示词。模型权重一个字没动，但用起来确实变差了。

**第三，事故只影响一部分人。** 2025 年 8 月那次，部分 Sonnet 4 请求被误路由到为 100 万上下文配置的服务器；8 月 31 日最差时段约 16% 的 Sonnet 4 请求受影响。这意味着：同一时刻，你的同事可能完全没感觉。「只有我一个人觉得变笨」不构成「是我的错」的证据，反过来「群里一片说变笨了」也不构成「一定是官方的锅」。

**第四，你的用法在漂移。** 项目变大了、CLAUDE.md 越写越长、会话跑到 80% 上下文才想起来清、开始一句话让它改十个文件。这些变化是渐进的，人察觉不到，但对模型来说难度是阶跃上升的。

社区里有人做过量化尝试：有人分析了自己 6852 个会话的 JSONL 日志，统计「读文件次数 / 编辑次数」的比值、循环推理次数、用户打断次数这些行为指标（[GH #42796](https://github.com/anthropics/claude-code/issues/42796)，这是该仓库 reaction 最高的 issue，583 条评论）。有人每天跑 SWE-bench 子集追踪曲线（[HN 46810282](https://news.ycombinator.com/item?id=46810282)，760 分）。这两种做法的方向是对的——**把感觉换成能重放的数字**——但也各有坑：前者的 thinking 长度指标被官方指出理解错了（`redact-thinking` 是纯 UI 层隐藏，不改思考预算）；后者用 50 道题的样本量，被 SWE-bench 作者当场指出方差太大，建议 300 题、每天跑 5 到 10 次才有统计意义。

结论很朴素：**你不需要做统计学意义上严谨的 benchmark，你需要的是一组能重放、能对照的固定题目**，够你分清「工具变了」还是「我变了」就行。

## 怎么做

顺序很重要：先排查，后 workaround。前四步不依赖任何版本，长期有效；第五步是版本相关的补救，会过期。

### 第 1 步：抓四个客观量（2 分钟）

在觉得不对劲的当下，立刻记录：

```bash
claude --version            # 例如 2.1.211 (Claude Code)
claude doctor               # 安装健康度、settings 校验错误、最近一次更新结果
```

`claude doctor` 会打印只读诊断，包含最近一次自动更新是否发生、settings 文件有没有解析错误。同时在会话里看两处：

- **会话头部**：模型名旁边会显示当前 effort，例如 `with low effort`。启动时和 effort 变化时页脚也会短暂提示。
- **`/status`**：确认账号、模型、上下文占用。

再开浏览器看 [status.claude.com](https://status.claude.com/)，它按 claude.ai / Claude API / Claude Code 分服务列出状态。

**怎么判断做对了**：你手上应该有四个具体值——版本号、effort 级别、状态页是否有 incident、上下文使用百分比。如果四个你一个都说不出，那你现在还没有资格说「变笨了」。

### 第 2 步：做客户端 vs API 对照（10 分钟）

这是从 4 月复盘里直接抄来的实验设计：那次事故 **API 直连全程正常，只有 Claude Code / Agent SDK / Cowork 受影响**。所以：

1. 把一个能稳定复现问题的任务，写成一段自包含的 prompt（含必要代码片段）。
2. 在 Claude Code 里跑一次，记录结果。
3. 把同一段 prompt 直接发给 API 或 claude.ai，用同一个模型。

**怎么判断做对了**：

- 两边都差 → 大概率是模型侧或你的 prompt 本身有问题，去看第 4 步。
- Claude Code 差、API 好 → 问题在客户端脚手架（系统提示词、上下文管理、effort），去看第 3、5 步。
- 两边都好 → 你原来那次会话有上下文污染，去看第 4 步。

### 第 3 步：把变量钉死（一次性配置，长期收益）

「变笨」难查的根因是变量太多。把能钉的都钉住：

**钉模型版本**。别名（`opus` / `sonnet`）会随时间指向新版本，写进配置的就不是你以为的那个模型了。用完整模型名，或设对应环境变量：

```json
// ~/.claude/settings.json
{
  "model": "claude-opus-5",
  "effortLevel": "high",
  "env": {
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5"
  }
}
```

注意 `effortLevel` 在 settings 文件里只接受 `low` / `medium` / `high` / `xhigh`；`max` 和 `ultracode` 是会话级的，settings 不收。要长期用 `max`，得走环境变量 `CLAUDE_CODE_EFFORT_LEVEL`（环境变量优先级最高，高于所有其他设置方式）。

**钉客户端版本节奏**。把自动更新切到 stable 频道，它比 latest 大约晚一周，会跳过有重大回归的版本：

```json
{
  "autoUpdatesChannel": "stable",
  "minimumVersion": "2.1.100"
}
```

`minimumVersion` 是下限：后台自动更新和 `claude update` 都不会装低于这个值的版本，所以从 latest 切到 stable 时不会把你降级。

**怎么判断做对了**：重启 Claude Code，`/model` 里显示的是你写的完整模型名而不是别名；会话头显示的 effort 是你配的级别；`claude doctor` 不报 settings 校验错误。

### 第 4 步：建一个你自己的回归集（最值钱的一步）

不用 300 道 SWE-bench。三到五道**你自己项目里的真实题目**就够，标准是：

- 能在 5 分钟内跑完；
- 有明确的对错判据（测试通过 / 输出匹配 / 改动文件数正确）；
- 覆盖不同类型：一道纯理解题（「解释这个函数为什么这样写」）、一道多文件改动题、一道要求遵守 CLAUDE.md 约定的题。

放到仓库里，比如 `bench/` 目录，每题一个 `prompt.md` + 一个期望说明。感觉不对时在**干净会话**里跑一遍：

```bash
cd /path/to/your/repo
claude -p "$(cat bench/01-explain/prompt.md)" --model claude-opus-5 --effort high
```

`-p` 是非交互模式，一次性出结果，方便对比和存档。注意非交互模式下用 `/effort` 设的级别只对当前会话生效、不保存为默认，所以显式带 `--effort` 更稳。

**怎么判断做对了**：你能拿出「同一道题，上周这样答，今天这样答」的两份文本，而不是「感觉不如以前」。如果回归集全过，那问题在你这次会话的上下文，不在工具——清掉重开（见 [#012 上下文窗口要爆了怎么办？](../02-上下文工程/012-上下文窗口要爆了.md)）。

### 第 5 步：确认是官方问题后怎么办（时效相关，会过期）

**信息日期：2026-08。以下版本号只是历史示例，不要照抄到今天的环境。**

确认是客户端回归后，能做的事按优先级：

1. **提 `/feedback`**。官方在 4 月复盘里明确说，`/feedback` 是他们定位问题的关键渠道。带上第 1 步的四个客观量和第 4 步的回归集对比，比「变笨了」有用一百倍。
2. **回滚到已知好的版本**。原生安装器支持指定版本号：

   ```bash
   curl -fsSL https://claude.ai/install.sh | bash -s 2.1.89
   claude --version   # 应打印 2.1.89 (Claude Code)
   ```

   npm 装的话是 `npm install -g @anthropic-ai/claude-code@<版本>`。回滚后必须同时停掉自动更新，否则第二天又被更回去：

   ```json
   {
     "env": { "DISABLE_AUTOUPDATER": "1" }
   }
   ```

   `DISABLE_AUTOUPDATER` 只停后台检查，`claude update` 仍然能手动跑；要连手动路径一起封死才用 `DISABLE_UPDATES`。
3. **等修复，别硬扛**。4 月那次三项问题分别在 4 月 7 日、4 月 10 日（v2.1.101）、4 月 20 日（v2.1.116）修完。硬用一个已知有回归的版本干重活，性价比很低——把重活推后一天，损失通常比反复重试小。

**怎么判断做对了**：回滚后跑你的回归集，指标回到旧水平。如果回滚了还是差，那就不是版本问题，回到第 2 步重新对照。

## Claude Code 实战

一个可以直接抄的最小配置组合，目标是「让每次会话可复现」：

```json
// ~/.claude/settings.json
{
  "model": "claude-opus-5",
  "effortLevel": "high",
  "autoUpdatesChannel": "stable",
  "env": {
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5"
  }
}
```

配套的排查命令清单，出问题时按顺序跑：

```bash
claude --version                 # 版本
claude doctor                    # 安装与配置诊断、最近更新结果
claude -p "1+1=?" --model claude-opus-5   # 最小连通性验证
```

会话内：`/status` 看账号与上下文，`/model` 看当前模型和 effort 滑块，`/effort` 直接设级别（`/effort auto` 恢复模型默认），`/feedback` 提报。

三个容易被忽略的行为细节，都可能被误当成「变笨」：

- **effort 的默认值随模型不同**。支持 effort 的模型默认是 `high`，但 Opus 4.7 默认 `xhigh`。切模型时 effort 会跟着变，你没动任何配置，行为却变了。
- **effort 级别不是跨模型可比的**。同一个名字在不同模型上代表的实际值不同；模型不支持你设的级别时，会自动落到它支持的最高档（比如 `xhigh` 在 Opus 4.6 上跑成 `high`）。
- **prompt 里写 `ultrathink` 只是加一条上下文指令**，发给 API 的 effort 级别不变；而 `think hard` / `think more` 这类说法完全不是关键词，就是普通文本。别把这个当成提升算力的开关。

## 横向对比

| 工具 | 「变笨」的可查性 | 差异 |
|------|------|------|
| Claude Code | 有官方状态页、有公开事故复盘（两次）、客户端版本可指定安装与回滚、effort 与模型版本可显式钉死 | 可查性最好，但也因为用户体量大、脚手架变更频繁，「变笨」讨论最密集 |
| Cursor | 模型可选但底层路由与系统提示词不透明，版本回滚依赖旧安装包 | 出现同类问题时更难自证，社区讨论常停留在体感层面 |
| GitHub Copilot | 模型与提示词由服务端控制，客户端是 IDE 插件，行为变更基本不可观测 | 排查手段最少，基本只能提 issue 等官方 |
| Gemini CLI | 开源、可读代码，能自己 diff 版本间的 prompt 变化 | 可查性理论上最高，但同样有「跑一半卡住」这类跨工具共性故障 |

共同点：**所有闭源 agent 客户端的「变笨」都是同一类问题——你观测不到脚手架层的变更**。因此第 3、4 步（钉版本 + 自建回归集）在哪个工具上都适用，这是唯一不依赖厂商配合的方法。

## 反模式

- ❌ **凭一次糟糕的会话下结论并发帖** —— 单次输出方差本来就大，官方自己都说早期报告无法与正常波动区分。你至少需要同一道题的两次对照。
- ❌ **把「变笨」当成加大剂量的理由** —— 觉得不行就换更贵的模型、开更高 effort、把整个仓库塞进上下文。这三招都在提高成本的同时增加变量，之后你更查不清原因了。
- ❌ **回滚版本却忘了关自动更新** —— 后台更新会在下次启动时把你送回新版本，你以为回滚无效，实际上是根本没回滚成功。
- ❌ **拿 thinking 显示长度当降级证据** —— 官方明确说 `redact-thinking` 是 UI 层隐藏，不改思考预算。用一个自己不理解的指标做结论，会把整个分析带偏。
- ❌ **默认「一定是官方在偷偷降级省算力」** —— Anthropic 公开表态从不因需求、时段或负载降低模型质量，两次复盘归因都是具体的工程 bug 和配置变更。抱着阴谋论排查，你会跳过第 4 步，也就永远查不出真正原因。
- ❌ **把回归集建成 300 道 SWE-bench** —— 你不是在做研究，跑不动的基准等于没有基准。三到五道自己项目的真题，跑得起来才有用。

## 延伸

**交叉引用：**
- [#043 AI 改不对 bug、陷入 fix loop / 越改越糟，什么时候必须停、怎么跳出？](../05-质量保证/043-fix-loop什么时候必须停.md)
- [#012 上下文窗口要爆了怎么办？](../02-上下文工程/012-上下文窗口要爆了.md)
- [#063 什么时候该用 Opus、什么时候该用 Sonnet/Haiku？怎么按任务路由模型才不浪费？](../07-效率与成本/062-什么时候用Opus什么时候用Sonnet.md)
- [#060 额度怎么突然就没了？20x Max 也撑不过一上午——先算清自己一天该烧多少](../07-效率与成本/060-一天该烧多少额度.md)

**参考资料：**
- [An update on recent Claude Code quality reports](https://www.anthropic.com/engineering/april-23-postmortem) — 官方复盘，三项变更（effort 默认降档、思考清理 bug、冗长度系统提示词）及各自修复版本（官方，2026-04）
- [A postmortem of three recent issues](https://www.anthropic.com/engineering/a-postmortem-of-three-recent-issues) — 2025 年 8 月的路由错配事故复盘，含受影响流量比例（官方，2025-09）
- [Model configuration](https://code.claude.com/docs/en/model-config) — 模型别名与版本钉死、effort 级别与设置优先级、thinking 相关配置（官方，2026-08 访问）
- [Advanced setup](https://code.claude.com/docs/en/setup) — 指定版本安装、`autoUpdatesChannel` / `minimumVersion` / `DISABLE_AUTOUPDATER`、`claude doctor`（官方，2026-08 访问）
- [Claude Status](https://status.claude.com/) — 按服务分列的状态页，排查第一站（官方，持续更新）
- [GH #42796 [MODEL] Claude Code is unusable for complex engineering tasks](https://github.com/anthropics/claude-code/issues/42796) — 基于 6852 个会话日志的行为指标分析，及 Anthropic 关于 `redact-thinking` 是 UI 层变更的澄清（社区 + 官方回复，2026-04）
- [HN 47878905：An update on recent Claude Code quality reports](https://news.ycombinator.com/item?id=47878905) — 官方回应帖的社区讨论，942 分 / 732 评论（社区，2026-04）
- [HN 46810282：每日 benchmark 追踪退化](https://news.ycombinator.com/item?id=46810282) — 每日跑 SWE-bench 子集的做法，及 SWE-bench 作者关于样本量的评论（社区，2026-02）
- [HN 47660925](https://news.ycombinator.com/item?id=47660925) / [HN 46978710](https://news.ycombinator.com/item?id=46978710) — 同一主题两次上榜，1364 分 / 1085 分，佐证这是周期性复发话题（社区，2026 上半年）
- [V2EX 1213794](https://www.v2ex.com/t/1213794) — 中文社区讨论，有人开源 `llm-iq-test` 做固定题目回测（社区，2026）
- [Reddit r/ClaudeCode：Anyone else's Claude Code terrible lately](https://www.reddit.com/r/ClaudeCode/comments/1t6wdjy/anyone_elses_claude_code_terrible_lately) — 典型症状帖，可对照自己的描述（社区，2026）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
