# 040. AI 说"做完了"、测试也全绿，怎么知道代码是真的对？

> 难度：中级
> 主题：质量保证
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：流程题

> ⏰ 时效声明：本篇的命令、配置片段与产品状态（Code Review 处于 research preview、仅 Team/Enterprise 可用、check run 恒为 neutral conclusion、`gh api` 解析 `bughunter-severity` 的写法、Stop hook 的 settings.json 结构）已于 **2026-08-03** 对照官方文档逐条核实。文中"Opus 4.7 抓到、Opus 4.6 漏掉"出自 Anthropic 2026-04 postmortem，是**当时代际的快照**，模型迭代后只作为"跨代 back-test 有效"的方法论证据。

## TL;DR

三个高频症状，本篇一次回答：

- **"测试全绿了还是有 bug"** → AI 给自己写的测试容易同义反复，绿灯只证明"代码做了代码做的事"。
- **"AI 说修好了，其实没修"** → 不看宣告看证据；用 Stop hook 把"跑过检查"变成硬条件。
- **"让 AI 自己 review 靠谱吗"** → 同上下文的 reviewer 有确认偏差，且官方机审的 check run 永远是中性结论，不拦 PR。

核心结论：**"验证"不等于"人读一遍"，它是一个有多层分工的体系。** 两条轴——谁来验证、用什么手段。任何单独一层都会漏，关键是按场景叠对层数；而无论叠多少层，最终负责（accountable）的永远是人。004 把 TDD + hooks 归为"验证闭合层"，本篇就是把那一层展开。

本篇给三件东西：验证体系框架表（谁 × 什么手段）、按场景的组合决策表、**一份可照做的「验证体系缺口自查清单」**（6 层，每层一个是/否问题 + 最小动作 + 判断做对了的证据）。

一句话切边界：某一层的深用见对应指针——人审看 [#041](./041-how-to-review-ai-generated-code.md)、幻觉 API 查防看 [#042](./042-hallucinated-apis-and-dependencies.md)、改不对何时停手看 [#043](./043-fix-loop-when-to-stop-debugging.md)、TDD 看 [#030](../04-execution-workflow/030-tdd-in-ai-coding.md)。

---

## 为什么

### 1. 症状一：测试全绿，bug 还在

AI 写代码，再让同一个 AI 给这份代码写测试，测试会天然贴着实现走。你会看到这样的东西：

```python
# 实现（AI 写的，有 bug：折扣上限没生效）
def apply_discount(price, rate):
    return price * (1 - rate)

# 测试（AI 接着写的）
def test_apply_discount():
    assert apply_discount(100, 0.2) == 80
    assert apply_discount(100, 0.0) == 100
```

绿灯。但需求里"折扣率不得超过 0.5"这条根本没被断言过——测试只覆盖了实现已经做到的事。HN 上 MickeyShmueli 的说法是这些测试字面上就是"代码有没有做代码做的事"（"the tests are literally just 'does the code do what the code does'"，社区，2026-02）✅。

**自查动作**：把测试和需求并排放，逐条问"这条需求对应哪个 assert"。对不上的就是缺口。TDD 的做法是先写会失败的测试，见 [#030](../04-execution-workflow/030-tdd-in-ai-coding.md)。

### 2. 症状二：AI 宣告"完成"，但没跑过

obra 的底线是："在没有验证的情况下宣称工作完成，是不诚实，不是高效。永远先有证据再有结论。"（[obra: verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md)，社区权威，2026）✅

官方 best-practices 有互补表述，且给了因果：

> "Claude stops when the work looks done. Without a check it can run, 'looks done' is the only signal available… Give Claude something that produces a pass or fail, and the loop closes on its own."
> （工作看起来做完了 Claude 就会停。没有它能跑的检查，"看起来做完了"就是唯一信号……给它一个能产出通过或失败的东西，这个循环就会自己闭合。）
> — [CC Docs: best-practices](https://code.claude.com/docs/en/best-practices)（官方，2026-08 核实）✅

同页还写：让 Claude 拿出证据而不是断言成功——测试输出、它跑的命令和返回结果，或者结果的截图✅。

### 3. 症状三：人审在规模化下退化成盖橡皮图章

AI 让代码产出速度远超验证速度。HN 用户 wyum 把这称为"验证复杂度壁垒"（Verification Complexity Barrier）：组件越多，验证它们能否协同工作所需的时间超线性增长。

> "I think verification is now *the* problem of agentic software engineering."
> — [HN 47234917 @wyum](https://news.ycombinator.com/item?id=47234917)（社区，2026-02）✅

同帖 roadbuster：大模型产出的代码太多，人类只能一路盖橡皮图章，然后就 merge、构建了✅。throwaw12 描述每天 20 个 PR、50-60 个分散文件的 review 瓶颈✅。

这跟"责任在人"并不矛盾。恰恰因为最终背锅的是人（"the dude/dudette who gets blamed is the one who verifies it"，[@signa11](https://news.ycombinator.com/item?id=47234917)）✅，盖橡皮图章才是整个体系里最危险的失效模式。

### 4. 那"叠六层"到底有没有用？

Anthropic 4-23 postmortem 记录：一个让 Claude 变"健忘"的 bug，"通过了多轮人工和自动代码审查，也通过了单元测试、端到端测试、自动化验证和内部试用"（[官方，2026-04](https://www.anthropic.com/engineering/april-23-postmortem)）✅。六层全穿。

读者的合理追问是：那我还叠个什么劲？三点回答：

1. **每层挡的是不同类的错，不是同一类的重复投票。** 类型系统挡的是幻觉 API，测试挡的是行为回归，人审挡的是业务意图错。漏掉那个 bug 说明这六层里没有一层的职责范围覆盖它，不说明层数无效。
2. **同一 postmortem 给了正面证据**：back-test 时 Opus 4.7 抓到了这个 bug、Opus 4.6 没抓到✅。换独立视角有效——这正是"对抗机审"这一层存在的理由。
3. **叠层是降低漏出概率，不是归零。** 所以决策标准是场景风险，不是"要不要全上"。低风险场景全套是浪费，高风险场景少一层就是赌。

结论：验证的目标不是消灭漏网，而是让漏网概率与场景风险匹配，同时保证**责任落点始终在人**。

---

## 怎么做

### 第一交付物：验证体系框架表

按两条轴切：谁来验证（人 / 机 / 对抗机 / 自动化），用什么手段（读 / 断言 / 约束 / 运行 / 流水线）。

#### 表 A：谁来验证（四类验证者）

| 验证者 | 一句话定位 | 挡什么错 | 盲区 | 何时用 | 深用指针 |
|--------|-----------|---------|------|--------|---------|
| **人（最终负责）** | 读 diff、设门禁、最终拍板 | 业务意图错、需求理解偏、跨系统副作用 | 规模化产出下会盖橡皮图章 | 任何生产代码 merge 前 | [#041](./041-how-to-review-ai-generated-code.md) |
| **机审（同上下文 / 同模型）** | Claude Code Review、本地 `/code-review`、静态分析器 | 逻辑错、安全漏洞、边界 case、回归 | 模型盲区和实现一致；上下文不全就漏 | 任何 PR、commit 前 | [#041](./041-how-to-review-ai-generated-code.md) |
| **对抗机（独立视角 / 跨模型）** | 独立上下文的 reviewer SubAgent、跨模型互查 | 同模型盲区、确认偏差（写代码的 agent 倾向说自己写得好） | 跨模型仍可能共享训练盲区 | 生产 / 关键路径；怀疑自评过于乐观时 | [#032](../04-execution-workflow/032-subagent-when-and-how.md) |
| **自动化（测试 + 运行 + CI）** | TDD 闭合环、build / lint / 截图对比、CI 卡门禁 | 行为正确性、回归、构建 / 类型错 | AI 写的测试可能同义反复；只能验证"你想到要测的" | 任何代码（最低验证基线） | [#030](../04-execution-workflow/030-tdd-in-ai-coding.md) |

**表 A 的三条关键事实**（正文补充，不塞进表格）：

- 官方对机审的定位是"一队专门的 agent 在完整代码库上下文里检查改动，找逻辑错误、安全漏洞、被破坏的边界情况和隐蔽的回归"，并且有一个验证步骤拿候选问题对照真实代码行为、过滤误报（[CC Docs: code-review](https://code.claude.com/docs/en/code-review)，官方，2026-08 核实）✅。
- 官方划了职责边界：Code Review 默认只关注正确性——会搞垮生产的 bug，**不管格式偏好和测试覆盖缺失**（同上）✅。想扩到别的，要写 `REVIEW.md`。
- 机审的盲区有实测数据：back-test 同一个 bug，Opus 4.6 漏掉、Opus 4.7 抓到（[4-23 postmortem](https://www.anthropic.com/engineering/april-23-postmortem)）✅。这是"必须有独立视角"的直接证据。

对抗机那一层的社区依据：带着"新鲜眼睛"的 agent 没有"被告知要写什么、然后自己写出来"的包袱，视角不同也更敢挑刺（[@pyridines](https://news.ycombinator.com/item?id=47234917)）✅；"CC 写代码、GPT 5.2/5.3 来 review，效果很好"（[@NitpickLawyer](https://news.ycombinator.com/item?id=47234917)）✅。

#### 表 B：用什么手段（五类信号类型）

| 手段 | 一句话定位 | 信号类型 | 指针 |
|------|-----------|---------|------|
| **读（人审）** | 人读 diff、读懂了才 merge | 主观判断、业务意图 | [#041](./041-how-to-review-ai-generated-code.md) |
| **断言（测试）** | 给 agent 一个通过 / 失败信号，让它自己闭合验证环 | 机器可读的"对 / 错" | [#030](../04-execution-workflow/030-tdd-in-ai-coding.md) |
| **约束（类型 / lint / schema）** | 编译器、类型系统、OpenAPI schema 作为独立于测试和实现的真值源，专门挡 AI 编出来的 API 和依赖 | 编译期 / 契约错、幻觉 API 或包 | [#042](./042-hallucinated-apis-and-dependencies.md) |
| **运行（实际跑）** | 跑命令、看输出、内部试用、截图对比，一切以证据为准 | 实际运行行为（不是"应该行"） | [obra Gate Function](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md) |
| **流水线（CI 门禁）** | 把上面的自动化串成必须通过的闸门 | 全套自动化的硬性闸门 | 见下方自查清单第 5 层 |

> ⚠️ 关于约束层的一个社区观点：在 JS / Python 这类弱约束语言里放手让大模型来，很容易整个失控（"everything goes off the rails"，[@waterTanuki](https://news.ycombinator.com/item?id=47234917)）✅。官方 best-practices 并未单列类型系统，这条属社区经验。

### 第二交付物：组合决策（不同场景叠哪几层）

| 场景 | 叠哪几层 | 依据 |
|------|---------|------|
| **原型 / Demo / 一次性脚本** | 轻量：跑通 + 人扫一眼 | "这不适用于原型、黑客松、概念验证……对这些低风险项目，你愿意的话就随便 vibe code"（[@holtkam2](https://news.ycombinator.com/item?id=47234917)）✅ |
| **内部工具 / 非关键路径** | TDD 闭合环 + 机审分流（机审打质量分，人只看低分） | "让 Claude Code 做代码审查并打一个质量分……然后连 C 及以下的活都不用看"（[@MrDarcy](https://news.ycombinator.com/item?id=47234917)）✅ |
| **生产 / 业务关键 / 安全敏感** | 全套六层（见下方自查清单） | 6 层仍漏 ≠ 层数无效，理由见"为什么"第 4 节；"瓶颈不是代码能多快写出来，而是人能多快建立起理解，再拿自己的职业生涯去担保"（[@holtkam2](https://news.ycombinator.com/item?id=47234917)）✅ |

**任何场景都适用的两条底线：**

1. **先有证据再下结论。** AI 说"我修好了"时要运行证据，不信宣告。obra（社区）与 best-practices（官方）互证✅。
2. **责任永远在人。** 官方机审给中性结论、不拦 PR，它是辅助信号不是门禁。

---

## Claude Code 实战

### 验证体系缺口自查清单（6 层）

从上往下过一遍，每层先答是/否。答"否"就照做最小动作，然后用"证据"那一列确认自己真的做对了。全部答"是"，说明你的验证体系没有结构性缺口。

---

#### 第 1 层｜断言：agent 有没有一个能跑的通过/失败信号？

**是/否问题**：你交给 Claude 的任务里，有没有一条它自己能跑、能读到结果的命令（测试 / build / lint）？

**最小动作**：把验证条件写进 prompt，让它跑完再停。

```text
写 validateEmail 函数。测试用例：user@example.com 为 true，
invalid 为 false，user@.com 为 false。实现完之后把测试跑一遍，
把测试输出原样贴出来。
```

**证据**：对话里出现真实测试输出（含 `passed` / `failed` 计数），而不是"我已经验证过了"这类话。看不到命令回显 = 这层没生效。

深用见 [#030](../04-execution-workflow/030-tdd-in-ai-coding.md)。

---

#### 第 2 层｜约束：类型 / schema 有没有独立跑一遍？

**是/否问题**：你的仓库里有没有一条与测试无关、与实现无关的真值源检查（tsc / pyright / OpenAPI 校验）？

**最小动作**：把类型检查加进 CLAUDE.md 的 workflow 区，让每次改完都跑：

```markdown
# Workflow
- 改完一组代码后必须跑 `npx tsc --noEmit`（或 `pyright`），有报错先修再继续
```

**证据**：故意让 AI 引一个不存在的方法（比如 `import { notReal } from './utils'`），跑检查应当报错：

```
error TS2305: Module '"./utils"' has no exported member 'notReal'.
```

报错 = 这层活着；静默通过 = 你的类型检查没覆盖到这里。幻觉查防的完整手法见 [#042](./042-hallucinated-apis-and-dependencies.md)。

---

#### 第 3 层｜运行：AI 宣告完成时，有没有硬性拦截？

**是/否问题**：AI 说"做完了"的时候，有没有一个机制**强制**它拿出运行证据，而不是靠你每次记得追问？

**最小动作（弱）**：把检查设成 `/goal` 条件——官方说明有一个独立的评估器在每一轮之后重新检查该条件，直到成立才罢休（[best-practices](https://code.claude.com/docs/en/best-practices)，官方，2026-08）✅。

**最小动作（强）**：配一个 Stop hook 当确定性闸门。官方 Stop hook 无 matcher，写在 `.claude/settings.json`：

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/require-tests.sh"
          }
        ]
      }
    ]
  }
}
```

`.claude/hooks/require-tests.sh`（记得 `chmod +x`）：

```bash
#!/usr/bin/env bash
# 回合结束前跑测试；不过就退 2，阻止 Claude 停下
set -uo pipefail
cd "$CLAUDE_PROJECT_DIR" || exit 0
if ! out=$(npm test --silent 2>&1); then
  echo "测试未通过，先修好再结束本回合：" >&2
  echo "$out" | tail -n 30 >&2
  exit 2
fi
exit 0
```

机制说明（官方，2026-08 核实）✅：exit code 2 会把 stderr 回喂给 Claude 并**阻止它停下**；也可以改成 exit 0 并输出 `{"decision":"block","reason":"..."}`。注意官方限制：**连续 8 次 block 后 Claude Code 会覆盖 hook 并结束回合**，所以 Stop hook 不能当死循环用。

**证据**：故意写一个失败的测试，然后让 Claude 随便改点别的并结束回合。你应当看到它没能停下、而是继续去修测试；`/hooks` 里能列出这条 Stop hook。如果它照常结束了，说明脚本没执行权限或路径写错。

---

#### 第 4 层｜对抗机：有没有一个不是"作者本人"的 reviewer？

**是/否问题**：review 你这段代码的，是不是刚刚写它的那个上下文？

**最小动作**：用官方自带的 `/code-review` 审当前 diff。自 **v2.1.218** 起，终端里默认把它丢到**后台 subagent** 跑（独立上下文）；但在少数情况下会退回前台/fork 会话执行——已经有一个 review 在跑时再次触发、`-p` 非交互模式、以及设了 `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`。前台执行意味着它和写代码那轮共享上下文，对抗性会打折。（官方文档，2026-08 核实）✅

```text
/code-review
```

它默认审"当前分支领先 upstream 的提交 + 未提交改动"；也可以传目标（文件路径 / PR 号 / 分支名 / `main...my-feature`）。可选 flag：`--fix`（把结论直接改进工作区）、`--comment`（发成 PR 行内评论）。（[CC Docs: code-review](https://code.claude.com/docs/en/code-review)，官方，2026-08 核实）✅

想对着计划审而不是找 bug，自己写 reviewer prompt（官方 best-practices 的示例结构）✅：

```text
用一个 subagent 把 rate limiter 的 diff 对照 PLAN.md 审一遍。
检查：每条需求是否都实现了、列出的边界 case 是否都有测试、
有没有改到任务范围之外的东西。只报缺口，不报风格偏好。
```

**证据**：findings 里出现了你和写代码那轮都没提过的问题（比如某个未被断言的边界 case）。如果结论清一色是"实现良好、无问题"，要么代码确实干净，要么你审的还是同一个上下文。

⚠️ 官方提醒：被要求找缺口的 reviewer 通常总能找出点什么，追着每条改会导致过度设计——明确告诉它只报影响正确性或既定需求的缺口✅。机制见 [#032](../04-execution-workflow/032-subagent-when-and-how.md)。

---

#### 第 5 层｜流水线：CI 里有没有把机审结论变成真门禁？

**是/否问题**：Claude Code Review 的 finding 在你的 CI 里，是"看看而已"还是能卡住 merge？

**先说前提**（官方，2026-08 核实）✅：托管版 Code Review 处于 **research preview，仅 Team / Enterprise 订阅可用**，开启了 Zero Data Retention 的组织不可用；其他 plan 只能用本地 `/code-review`。单次 review 平均耗时约 20 分钟、成本约 **$15-25**，走 usage credits 单独计费。

**关键机制**：check run **永远以 neutral conclusion 结束**，所以它不会通过分支保护规则拦住 merge。想卡门禁，得自己在 CI 里读它的严重度。

**最小动作**：官方给的两条命令。第一条拿 check run ID：

```bash
gh api repos/OWNER/REPO/commits/<commit-sha>/check-runs \
  --jq '.check_runs[] | {id, name}'
```

取名为 `Claude Code Review` 那条的 `id`，然后解析严重度：

```bash
gh api repos/OWNER/REPO/check-runs/CHECK_RUN_ID \
  --jq '.output.text | split("bughunter-severity: ")[1] | split(" -->")[0] | fromjson'
```

返回形如 `{"normal": 2, "nit": 1, "pre_existing": 0}`。`normal` 是 Important（🔴）的条数，非 0 意味着 Claude 至少找到一个该在 merge 前修掉的 bug。

串成 GitHub Actions 门禁（把 OWNER/REPO 换成你的）：

```yaml
      - name: Gate on Claude Code Review severity
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          set -euo pipefail
          SHA="${{ github.event.pull_request.head.sha }}"
          # 重跑 / 多次 review 会留下多条同名 check run，只取最新的一条
          ID=$(gh api "repos/${{ github.repository }}/commits/$SHA/check-runs" \
                --jq '.check_runs[] | select(.name=="Claude Code Review") | .id' | head -1)
          if [ -z "$ID" ]; then echo "尚无 Code Review check run"; exit 0; fi
          # 标记缺失时 split(...)[1] 为 null 会让 fromjson 报错，这里兜底成 normal=0
          SEV=$(gh api "repos/${{ github.repository }}/check-runs/$ID" \
                --jq '(.output.text // "") | split("bughunter-severity: ")[1] // "" | split(" -->")[0] | (fromjson? // {"normal":0})')
          echo "severity: $SEV"
          N=$(echo "$SEV" | jq -r '.normal')
          if [ "$N" -gt 0 ]; then
            echo "::error::有 $N 条 Important finding，先修掉再 merge"; exit 1
          fi
```

> 说明：这个 job 需要等 Code Review 跑完（平均 20 分钟）才有结果，实际用的时候要么放在单独的 workflow 里由 `check_run` 事件触发，要么在步骤里加轮询。上面的写法在 check run 还没出现时直接放行，避免误红。

**证据**：造一个含明显逻辑 bug 的测试 PR（比如把 `>=` 写成 `>` 导致边界越界），等 Code Review 跑完后重跑这个 job，应当看到 `severity: {"normal":1,...}` 且 job 变红；把 bug 改回去重跑，`normal` 归 0、job 变绿。两次都不变色 = jq 解析路径没匹配上，先手动跑一遍上面那条 `gh api` 看原始输出。

---

#### 第 6 层｜人：merge 前有没有人真读懂了这段 diff？

**是/否问题**：你能不能不看 AI 的说明，用自己的话讲清这段 diff 改了什么、为什么这么改、会影响哪些调用方？

**最小动作**：merge 前给自己三个问题，任一答不上就打回去问 AI 或自己读代码：

1. 这段改动的失败模式是什么？出错时线上会表现成什么样？
2. 有没有调用方依赖了被改掉的旧行为？
3. 如果这次 rollback，需要额外做什么（数据迁移？特性开关？）。

**证据**：你能在 PR 评论里用自己的话写出这三条的答案。写不出来就是橡皮图章。

人审的具体技巧（REVIEW.md、quality rubric、对抗式 reviewer persona）见 [#041](./041-how-to-review-ai-generated-code.md)。

---

> **怎么用这张清单**：原型只查第 1、6 层；内部工具查 1、2、4、6；生产 / 安全敏感六层全查。

> **多 agent 分工的社区模式**（指针，非本篇攻略）：turlockmike 的"乒乓结对编程"——第一个 agent 对着 spec 写一个最小的失败测试，第二个 agent 只写刚好能让它通过的最小实现，如此往复（[@turlockmike](https://news.ycombinator.com/item?id=47234917)）✅。机制归 [#032](../04-execution-workflow/032-subagent-when-and-how.md)。

---

## 横向对比

| 工具 | 验证体系对应物 | 差异 |
|------|--------------|------|
| Claude Code | Code Review（托管，多 agent）+ 本地 `/code-review` + Stop hook | 唯一同时提供"多 agent 机审"和"确定性 Stop 闸门"的组合；托管版需 Team/Enterprise |
| Cursor | Cursor Bot review | 同属机审，以单 agent 为主 |
| GitHub Copilot | Copilot review | 同属机审 |
| 各厂 SAST | 静态分析 | 约束层（类型 / lint 的子集），不看业务意图 |

核心差异在"对抗机审 + 跨模型"这一层。Claude Code 原生支持多 agent 编队（官方称"一队专门的 agent"），而跨模型互查目前还得靠人手动复制粘贴——社区做法是"把 Claude 的代码复制粘贴给 ChatGPT 和 Gemini，让它们互相检查"（[@lateforwork](https://news.ycombinator.com/item?id=47234917)）✅。机审工具的详细对比见 [#041](./041-how-to-review-ai-generated-code.md)。

---

## 反模式（验证体系的误用）

- ❌ **把"验证"等同于"人读一遍"。** 人读只是六层里的一层，规模化下还会退化成橡皮图章✅。
- ❌ **把"测试全绿"等同于"验证通过"。** AI 写的测试可能只是同义反复（见"为什么"第 1 节的折扣例子）✅。
- ❌ **信 AI 的"我修好了"宣告。** 没有运行证据就不算完成（obra ✅ + 官方 best-practices ✅ 互证）。配 Stop hook 把这条从"我记得追问"变成"系统强制"。
- ❌ **把托管 Code Review 当 merge 门禁。** 它的 check run 恒为 neutral conclusion，永远不会通过分支保护拦住 merge✅。要门禁必须自己在 CI 里解析 `bughunter-severity`（见自查清单第 5 层）。
- ❌ **指望机审管格式和测试覆盖。** 官方明确它默认只关注正确性，格式偏好和缺测试不在范围内✅；要扩范围得写 `REVIEW.md`。
- ❌ **让写代码的那个上下文给自己 review。** 确认偏差，且模型盲区与实现一致。用 `/code-review`（独立 subagent）或换模型。
- ❌ **原型和生产用同一套验证强度。** 原型全套是浪费，生产少一层是赌。
- ❌ **Stop hook 当死循环用。** 官方限制：连续 8 次 block 后 Claude Code 会覆盖 hook 直接结束回合✅。
- ❌ **验证一直不过、越改越糟还硬撑。** 这是调试侧的问题，见 [#043](./043-fix-loop-when-to-stop-debugging.md)。

---

## 延伸

**交叉引用：**
- [#004 Claude Code 的 plan / skill / subagent / CLAUDE.md 这堆"能力"到底是啥、什么时候用哪个？](../01-mindset-and-tools/004-claude-code-capabilities-map.md) —— "验证闭合层"的一句话定位（本篇是它的深入）。
- [#030 TDD 在 AI coding 里怎么做？](../04-execution-workflow/030-tdd-in-ai-coding.md) —— 自查清单第 1 层的攻略。
- [#031 plan → execute → review 的正确循环怎么做？](../04-execution-workflow/031-plan-execute-review-loop.md) —— 本篇的验证体系是 review 环的体系化。
- [#032 开几个 agent 并行跑，结果互相踩、被限流、token 指数级炸开——并行到底该开几个？](../04-execution-workflow/032-subagent-when-and-how.md) —— 自查清单第 4 层的机制。
- [#041 怎么 review AI 生成的代码？（人审 + 机审策略）](./041-how-to-review-ai-generated-code.md) —— 自查清单第 6 层的攻略、REVIEW.md 模板。
- [#042 AI 写的方法不存在、pip install 报 404、API 参数对不上——幻觉 API 和幻觉依赖怎么查、怎么防？](./042-hallucinated-apis-and-dependencies.md) —— 自查清单第 2 层的攻略。
- [#043 改不对、越改越糟，什么时候该停手？](./043-fix-loop-when-to-stop-debugging.md) —— 验证一直不过时怎么跳出 fix loop。

**参考资料：**
- [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices) — "给 Claude 一个能产出通过或失败的东西，循环就会自己闭合"、四档 gate 强度（prompt / `/goal` / Stop hook / verification subagent）、"让 Claude 拿出证据而不是断言成功"、对抗 review 的过度设计提醒（官方，2026-08 核实）✅
- [Code Review - Claude Code Docs](https://code.claude.com/docs/en/code-review) — research preview 与 Team/Enterprise 限制、"一队专门的 agent"、"默认只关注正确性"、"check run 恒为 neutral conclusion"、`gh api` 解析 `bughunter-severity` 的两条命令、`$15-25`/次、`/code-review` 的 `--fix` 与 `--comment`（官方，2026-08 核实）✅
- [Hooks reference - Claude Code Docs](https://code.claude.com/docs/en/hooks) — Stop hook 的 settings.json 结构（无 matcher）、exit code 2 阻断回合、`{"decision":"block"}` 写法、连续 8 次后被覆盖（官方，2026-08 核实）✅
- [An update on recent Claude Code quality reports（4-23 postmortem）](https://www.anthropic.com/engineering/april-23-postmortem) — "通过了多轮人工和自动代码审查，也通过了单测、E2E、自动化验证和内部试用" + Opus 4.7 抓到 / Opus 4.6 漏掉（官方，2026-04）✅
- [obra: verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md) — "永远先有证据再有结论"、"没有新鲜验证证据就不许宣称完成"（社区权威，2026）✅
- [HN: When AI writes the software, who verifies it?](https://news.ycombinator.com/item?id=47234917) — wyum（验证复杂度壁垒）/ roadbuster（橡皮图章）/ MickeyShmueli（同义反复的测试）/ pyridines（新鲜眼睛）/ NitpickLawyer 与 lateforwork（跨模型）/ MrDarcy（质量分）/ turlockmike（乒乓结对）/ lenerdenator 与 signa11（责任归属）/ holtkam2（原型 vs 生产）/ waterTanuki（类型系统）（社区，2026-02）✅

> 本篇个人实践（L4）：`[待补：BOSS 的验证体系实际叠了几层 / 哪层最先上 / 哪层最后才加 / 生产 vs 原型的真实组合]`
