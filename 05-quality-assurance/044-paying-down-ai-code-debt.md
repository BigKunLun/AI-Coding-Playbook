# 044. AI 写的代码上线三个月，300 行的函数没人敢动——怎么分批还债？

> 难度：中级
> 主题：质量保证
> 工具：Claude Code · 横向(Cursor / Copilot / …)
> 题型：流程题

> ⏰ 时效声明：本篇的排查方法（churn × 复杂度定位、重复块扫描、行为快照测试、小步切分）不依赖任何工具版本，长期有效，放在前面。后面涉及具体工具的命令与参数（jscpd、lizard、Claude Code 的 `--permission-mode plan` / `--worktree` / `-p`）以 **2026-08-03** 查到的官方文档为准，版本更新后请复核。引用的 GitClear「Maintainability Gap」数据发布于 **2026-07**，是一家代码分析厂商基于自家数据集的统计，方向可信、绝对值按厂商立场打折。

## TL;DR

还债不是"重构一遍"，是**先定位、再封锁、后小步改**，三步各有明确产出：

1. **定位**：别凭感觉挑文件。用「改得最频繁 × 最复杂」的交叉点排序，得到一张不超过 10 个文件的清单。改动频率是最强的问题信号，冷门的烂代码不值得动。
2. **封锁**：动手前给目标模块套一层**行为快照测试**（characterization test / golden master）——不管现在的行为对不对，先把它录下来当基准。没有这层网，重构就是在赌。
3. **小步改**：一次只做一类改动（先删重复、再拆函数、最后调接口），每步跑一次快照测试、提交一次。AI 负责执行和体力活，边界和验收标准由你定。

关键提醒：**AI 造的债，交给 AI 一把梭是最常见的失败姿势**。V2EX 上高赞的「谁污染谁治理」听着解气，但无边界地让 AI 重构一个它自己写乱的模块，只会把乱摊得更开。AI 在这里的正确用法是"带着快照测试和明确 diff 上限干活"。

## 为什么

**这不是错觉，是可测的趋势。** GitClear 与 GitKraken 分析了 2023–2026 年 6.23 亿次真实代码改动（2026-07 发布），几个数字解释了你为什么现在读不动自己三个月前的仓库：

| 信号 | 变化 | 对维护意味着什么 |
|---|---|---|
| 重复代码块（连续 5 行以上重复） | 比基线 **+81%**，2026 年是有记录以来最高 | 改一处要去找散落各处的兄弟副本 |
| 移动/重构行占比 | **−70%** | 没人在整理，只在堆 |
| 12 个月以上老代码的维护量 | 比 2023 年 **−74%** | 老代码进入无人区 |
| 跨文件函数调用（复用信号） | **−35%** | 不复用，直接重写一份 |
| 吞异常的 catch 等"掩盖错误"写法 | **+47%** | 故障被埋起来，出问题更难定位 |

GitClear 把重复叫作"传播税"：一处改动强制你在不熟悉的文件里找齐所有副本并逐个评估。这正好解释了"300 行的函数没人敢动"的体感——不是函数长，是**你不知道改了它会牵动谁**。

**需求已经量化成生意了。** HN 上一个波兰团队开帖「我们收 1 万美元一周删除 AI 生成的代码」（304 分 / 240 评论），同一个生意模式在 HN 上前后两次上榜。中文社区同样密集：V2EX「AI 代码后面怎么维护，心智负担太大了」71 条回复、1 万浏览，楼主的原话是"加两个函数多了 300 行"；另一帖「已经有屎山化倾向」里，楼主的处境是"公司追求效率，已不再逐行审查，不同人用不同 AI"。

**为什么事后还债需要单独一套方法。** 传统技术债是"当时赶工，知道欠在哪"；AI 债的特点是**欠债的人不知道自己欠了什么**——代码是生成的、没人完整读过、注释齐全但结构随意，看起来比人写的还体面。所以还债的第一步不是重构，是**测量**：把"我感觉这儿乱"换成"这个文件近 6 个月改了 47 次、780 行、和另外 3 个文件有 5 处重复块"。

对照本库其他篇：[#003 为什么 AI 写的代码我审不动](../01-mindset-and-tools/003-prompt-to-agentic-mindset-shift.md) 讲的是**当下**读不动，[#023 Vibe coding 什么时候必须停下来规划](../03-spec-and-planning/023-vibe-coding-when-to-stop-and-plan.md) 讲的是**事前**别欠，本篇处理的是**已经欠了三个月**的那笔。

## 怎么做

### 第 1 步：拉一张 churn × 复杂度清单

先看哪些文件改得最频繁（改动频率是研究上公认最强的质量问题信号）：

```bash
# 近 12 个月每个文件的改动次数，取前 30
git log --format=format: --name-only --since=12.months \
  | grep -v '^$' \
  | sort | uniq -c | sort -rn | head -30
```

再拿复杂度：

```bash
# lizard：跨语言圈复杂度，pip install lizard
# 列出圈复杂度 > 15 或长度 > 100 行的函数
lizard -C 15 -L 100 src/

# 只想要规模，用 scc（brew install scc）
scc --by-file --sort complexity src/ | head -30
```

把两张表按文件名 join，**同时进前列的就是你的还债清单**。

> **怎么判断做对了**：清单应该 ≤ 10 个文件，且你看到文件名时能点头说"对，就是它们"。如果清单里全是 `package-lock.json`、生成代码、批量格式化过的文件，说明噪声没滤掉——把它们加进 `.gitignore` 式的排除列表，或用 `.git-blame-ignore-revs` 屏蔽大规模重排提交后重跑。

### 第 2 步：扫重复块，量化"传播税"

```bash
# jscpd：跨语言复制粘贴检测（npx 免安装）
npx jscpd ./src --min-lines 5 --min-tokens 50 \
  --reporters console,html,json --output ./report/

# 想知道每块重复是谁提交的
npx jscpd ./src --blame --reporters console-full
```

> **怎么判断做对了**：`./report/` 下有 HTML 报告，控制台给出重复百分比。记下这个数字当基线——它是你后面证明"债确实还了"的唯一硬指标。经验值：超过 10% 就明显偏高，但**基线比绝对值重要**，你要的是趋势下降。

### 第 3 步：先套行为快照，再动一行代码

行为快照测试（characterization test，也叫 golden master / approval test）的规则很简单：**不判断行为对不对，只把当前行为录下来**。Michael Feathers 提出的这套做法是处理"没人敢动的遗留代码"的标准前置动作。

做法：

1. 挑目标模块的入口函数，构造一组覆盖面尽量宽的输入（正常值、边界值、异常值）。
2. 跑一遍，把输出序列化成文本落盘（JSON / 文本快照均可）。
3. 人工扫一眼快照文件，**接受它作为基准**（ApprovalTests 系工具的流程是：首跑生成 `.received.txt`，你确认后改名为 `.approved.txt`）。
4. 之后每次改动都对比快照，不一致就说明行为变了。

> **怎么判断做对了**：故意在目标函数里改一个常量，跑测试——**必须失败**。不失败说明你的输入没覆盖到那条路径，网是漏的，继续补输入。这一步没验证过就往下走，等于裸奔。

### 第 4 步：按"改动类型"分批，一批一个 PR

顺序有讲究，从低风险到高风险：

| 批次 | 内容 | 风险 | 验收 |
|---|---|---|---|
| 1 | 删死代码、删未使用的依赖和导出 | 最低 | 快照测试全绿 + 构建通过 |
| 2 | 合并重复块，抽公共函数 | 低 | jscpd 重复率下降，快照全绿 |
| 3 | 拆长函数（纯提取，不改语义） | 中 | 快照全绿，且 diff 里没有新逻辑 |
| 4 | 补掩盖错误的地方（空 catch、无脑可选链） | 中 | 每个改动点补一条针对性测试 |
| 5 | 改接口 / 调整模块边界 | 高 | 需要单独评审，见 [#053](../06-engineering-collab/053-ai-prs-too-large-to-review.md) |

**每批单独 PR，单个 PR 控制在能一口气读完的规模。** 第 5 批之前的所有改动都应该是"行为不变"的，快照测试一旦红了就是你改坏了，直接 revert 重来，不要在红的状态上继续修。

> **怎么判断做对了**：还完一轮后重跑第 1、2 步。churn 清单里的文件复杂度下降、jscpd 重复率低于基线，才算数。没有前后对比数字的"我重构完了"不算完成。

### 第 5 步：把闸门装上，否则一个月后原样长回来

还债只是止血，不装闸门就是白干：

```yaml
# .github/workflows/debt-gate.yml 片段
- name: 重复率门禁
  run: npx jscpd ./src --threshold 5 --exitCode 1 --reporters console
```

`--threshold` 的含义是：重复率 ≥ 该百分比就以错误码退出。**把阈值设成你当前实测值，而不是理想值**，然后每季度往下调一档——一上来卡 5% 只会让全组把这条 CI 关掉。

> **怎么判断做对了**：故意提一个复制粘贴 50 行的 PR，CI 必须红。

## Claude Code 实战

AI 在还债里的角色是**执行者**，不是决策者。以下每条都对应上面的某一步。

**定位阶段：让 subagent 去读，别把上下文烧在探索上**（官方文档明确推荐这个用法：子 agent 在自己的上下文里读文件，只把结论带回来）：

```text
用一个 subagent 调查 src/order/ 下 handleOrder 这个函数的所有调用方和副作用，
只回报：调用点清单、外部依赖（DB/网络/全局状态）、可能的隐式契约。不要改任何代码。
```

**动手前先出计划，别让它直接落盘**：

```bash
claude --permission-mode plan
```

会话中按 `Shift+Tab` 也能切换（循环顺序 `default` → `acceptEdits` → `plan`），状态栏显示 `⏸ plan mode on`。在 plan 模式里让它输出还债批次拆分，你逐条砍到能审的粒度再批准。

**生成行为快照测试的提示词**（关键是把"不许判断对错"写死）：

```text
给 src/order/handleOrder.ts 写 characterization test（行为快照测试）。
规则：
1. 不要判断现有行为是否正确，只记录当前输出作为基准
2. 输入要覆盖：正常路径、每个 if 分支、空值/边界、会抛异常的输入
3. 输出序列化成 JSON 快照文件，不要写内联断言
4. 不许修改 handleOrder.ts 本身，一行都不能改
写完运行测试，确认全部通过后停下来等我确认。
```

**每批还债在独立 worktree 里做，互不干扰**：

```bash
claude --worktree debt-dedup-order
```

每个 worktree 是独立分支的独立检出，一个批次一个 worktree，还债和日常需求可以并行推进而不打架。

**约束单次改动幅度**——写进项目的 `CLAUDE.md`：

```markdown
## 还债任务约束
- 单次改动只做一类：删死代码 / 合重复 / 拆函数，不要混做
- 每次改完必须跑 `npm run test:snapshot`，红了立刻停下报告，不要自行"顺手修好"
- 不许修改快照基准文件（*.approved.*），需要更新时先问我
- 单个 PR diff 不超过 300 行
```

**批量体力活走 headless 模式**：

```bash
npx jscpd ./src --reporters json --output ./report/ \
  && cat ./report/jscpd-report.json \
  | claude -p "按'合并收益 / 改动风险'给这些重复块排序，输出前 10 条，每条注明涉及文件和建议做法。不要改代码。"
```

> **怎么判断做对了**：每一步 AI 的产出你都能在 1 分钟内判断接不接受。做不到就是粒度太大了，回去拆。

## 反模式

- ❌ **直接说"帮我重构这个模块，让它更清晰"** —— 没有快照测试、没有 diff 上限、没有验收标准，AI 会顺手改掉行为并给你一份看起来很专业的说明。这是"谁污染谁治理"最常见的翻车方式。
- ❌ **一个大 PR 把 5 类改动全做完** —— 出问题时你无法二分定位是哪类改动引入的，只能整体回滚，前面的收益一起赔进去。
- ❌ **按"看着最难受"挑还债目标** —— 一年没人碰的模块再丑也不产生成本。不看改动频率，你很可能花一周整理了一段没人会再打开的代码。
- ❌ **快照测试写完不做失效验证** —— 没验证过"改坏了会不会红"的测试网，等于没有网，而且比没有更危险，因为它给了你虚假的安全感。
- ❌ **还完债不装 CI 门禁** —— GitClear 的数据说明重复是持续累积的趋势而非一次性事故，不装闸门，下个季度你会原地再还一次。
- ❌ **把还债做成一次性"重构冲刺"，之后回到老节奏** —— 债的产生速度取决于日常协作方式，不改协作方式，冲刺只是把还款日往后推。

## 延伸

**交叉引用：**
- [#003 为什么 AI 写的代码我审不动、改完自己看不懂？](../01-mindset-and-tools/003-prompt-to-agentic-mindset-shift.md) —— 本篇的"事前"版本：当下就读不动时怎么办
- [#023 Vibe coding 为什么会翻车？什么时候必须停下来规划？](../03-spec-and-planning/023-vibe-coding-when-to-stop-and-plan.md) —— 从源头少欠债
- [#040 AI 说"做完了"、测试也全绿，怎么知道代码是真的对？](./040-who-verifies-ai-code-and-how.md) —— 快照测试全绿之后还需要哪些验证层
- [#041 怎么 review AI 生成的代码？](./041-how-to-review-ai-generated-code.md) —— 还债 PR 本身也要过评审
- [#052 怎么不让 AI 把 git 仓库搞乱？](../06-engineering-collab/052-git-workflow-with-ai.md) —— 还债过程中安全回滚的前提
- [#053 AI 生成的 PR 太大太多，review 机制怎么扛住不崩？](../06-engineering-collab/053-ai-prs-too-large-to-review.md) —— 高风险批次的评审组织方式

**参考资料：**
- [GitClear：The Maintainability Gap（2026 AI 代码质量研究）](https://www.gitclear.com/the_ai_code_quality_maintainability_gap) — 6.23 亿次代码改动的统计，重复 +81%、重构行 −70% 等信号出处（实践/厂商研究，2026-07）
- [LeadDev：Code maintainability plummets in the AI coding era](https://leaddev.com/ai/code-maintainability-plummets-in-the-ai-coding-era) — 第三方媒体对上述研究的复核报道与数字汇总（社区/媒体，2026-07）
- [HN：We charge $10k a week to delete AI-generated code](https://news.ycombinator.com/item?id=48823359) — 304 分 / 240 评论，"删 AI 代码"已成付费服务的需求证据（社区，2026）
- [HN：同一生意模式的早前讨论](https://news.ycombinator.com/item?id=45320431) — 该模式两次登上 HN 首页（社区，2025）
- [V2EX：AI 代码后面怎么维护，心智负担太大了](https://www.v2ex.com/t/1207049) — 71 回复，"加两个函数多了 300 行"，高赞回复「谁污染谁治理」（社区，中文）
- [V2EX：自从项目中大量引入 AI 开发后，已经有屎山化倾向](https://www.v2ex.com/t/1215790) — "不同人用不同 AI、不再逐行审查"的真实团队处境（社区，中文）
- [Claude Code 官方文档：Common workflows](https://code.claude.com/docs/en/common-workflows) — `--permission-mode plan`、`--worktree`、subagent 委派、`claude -p` 管道用法出处（官方，2026-08 核对）
- [jscpd 官方文档](https://jscpd.dev/) — `--min-lines` / `--min-tokens` / `--threshold` / `--reporters` 参数出处（官方，2026-08 核对）
- [Wikipedia：Characterization test](https://en.wikipedia.org/wiki/Characterization_test) — 行为快照测试的定义与 Michael Feathers 的出处（社区/百科）
- [Understand Legacy Code：Focus refactoring on what matters with Hotspots Analysis](https://understandlegacycode.com/blog/focus-refactoring-with-hotspots-analysis/) — churn × 复杂度定位法与 `git log` 统计命令（实践）
- [CodeScene 文档：Hotspots](https://docs.enterprise.codescene.io/versions/4.0.16/guides/technical/hotspots.html) — "改动频率是最强质量信号"的方法论依据（官方）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
