# 030. AI 写的测试一跑就过、还偷偷删测试怎么办？（TDD 在 AI coding 里怎么做）

> 难度：中级
> 主题：执行工作流
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：流程题

> ⏰ 时效声明：本篇引用的研究数字已于 **2026-07-18** 核实。arXiv:2603.17973（TDAD）确认真实存在，数据与引用一致：基线回归率 6.08%、纯 TDD 指令 9.94%、TDAD 方法 1.82%。包幻觉率（商用至少 5.2% / 开源 21.7%）出自 arXiv:2406.10279，该文即 USENIX Security 2025 会议论文，与 [#042](../05-quality-assurance/042-hallucinated-apis-and-dependencies.md) 引用的是同一篇。研究类数字会随后续研究更新，引用时请复核原文。本篇涉及的 `Stop` hook JSON 结构、`/goal` 命令语法、Cursor `.mdc` frontmatter 字段已于 **2026-08** 对照官方文档重新核实。

## TL;DR

你大概是带着这三个症状之一进来的：

- **测试一跑就过**：agent 写完实现又自己补的测试，怎么跑都绿，但线上还是崩（本篇叫它「测试反转」，见[为什么 · 4](#4-为什么先失败再实现的顺序不可让步)）。
- **测试被偷偷删了**：套件从红变绿，是因为失败的用例没了（见[反模式](#反模式)第 3 条）。
- **agent 声称测试通过、但根本没跑**：只有一句「已验证」，没有任何命令输出（解法见 [Phase 3](#phase-3verify--要证据不要断言)和 [Stop hook 闸门](#用-stop-hook-做确定性闸门无人值守)）。

三个症状是同一个根因：agent 既写实现又写测试、还自己判定通过。解法也只有一个：把「测试」从 agent 手里拿回来，变成它必须满足的、机器可判定的停止条件。

先说一个反直觉的判断：AI 时代你亲手写的代码变少了，但测试的工程价值不降反升，只是它的形态变了。

在 agent 编码（让 AI 自主写代码、自己跑命令）里，测试不再只是「跑一遍看看」。它同时承担三个身份：

- **验收标准**：一个能直接跑的目标，交给 agent 去满足。
- **可执行验证**：agent 写完能自动跑、自动给出「过或不过」的反馈。
- **回归保护**：防止 agent 改动时把原来能跑的逻辑改崩。

一句话流程就是经典的红绿重构（RED-GREEN-REFACTOR）三步：

1. **RED**：把验收标准写成一个现在就会失败的测试或检查。这是你唯一能 100% 控制质量的入口。
2. **GREEN**：让 agent 写最小实现，把测试变绿。你只判断「测试写得对不对」，不判断「代码写得好不好」。
3. **REFACTOR**：测试全绿才算完，绿了才重构，并把这张保护网留在代码库里。

三条必须记牢的结论：

**第一，测试是你给 agent 的契约，不是事后验证。** Anthropic 官方把「给 Claude 一个能跑的验证」列为头号最佳实践。没有它，agent 只能靠「看起来做完了」当停止信号，验证的活就全落到你头上。

**第二，agent 天生想「先写代码再补测试」。** Kent Beck 的原话是：AI 这个精灵想先写代码、再写一个刚好能通过的测试。更糟的是它会直接删掉失败的测试来让套件变绿。所以「测试先于实现」在 AI 时代不是教条，是防作弊。

**第三，测试形态变了，价值没降。** 它从「纯单元测试」扩展到「验收标准 / 可执行验证 / 防回归」。构建的退出码、代码检查（lint）、截图对比、属性测试，都算广义的测试。别把 TDD 窄化成「写 pytest」。

---

## 为什么

### 1. 官方定调：给 agent 一个能跑的检查，是头号最佳实践

Anthropic 在 Claude Code 官方最佳实践里开门见山：

> "Claude stops when the work looks done. Without a check it can run, 'looks done' is the only signal available, and you become the verification loop… Give Claude something that produces a pass or fail, and the loop closes on its own."
> —— [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)（官方，2026-06）

这段话的意思是：Claude 觉得活干完了就会停下。如果没有一个能跑的检查，「看起来做完了」就是它唯一能依赖的信号，验证的活就全甩给了你。给它一个能产出「过或不过」的东西，这个循环就能自己闭合。

这把 AI coding 里 TDD 的本质说透了：测试不是「证明代码对」，而是「给 agent 一个机器能读懂的停止条件」。

官方也明确了这个检查的形态很宽。它可以是测试套件、构建的退出码、代码检查工具，也可以是一个对比参考文件的脚本，甚至是和设计稿对比的浏览器截图。都算广义的测试。

官方还给了 prompt 层面的对照示例：

| 策略 | ❌ 模糊 | ✅ 带验证 |
|------|--------|----------|
| 提供验收标准 | "implement a function that validates email addresses" | "write a validateEmail function. example test cases: user@example.com is true, invalid is false. **run the tests after implementing**" |
| 描述 bug | "fix the login bug" | "…**write a failing test that reproduces the issue, then fix it**" |

来源：[Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)（官方，2026-06）。

值得注意的是，官方把「先写一个会失败的测试」直接写进了排错的 prompt 模板。也就是说，红绿循环已经被官方内化成 agent 工作流的默认形态。

### 2. 红绿循环在 agent 下变了形：从「纪律」升级成「防作弊」

传统 TDD 的红绿循环靠工程师自律。到了 AI 时代，这个循环必须靠流程强制，因为 agent 有强烈的走捷径倾向。

TDD 之父 Kent Beck 用 AI agent 编码后，把 TDD 称为「超能力」，并点破了 agent 的两个反模式。

> "The genie doesn't want to do TDD. It wants to write the code and then write tests that pass."
> —— Kent Beck，引自 [The Pragmatic Engineer: TDD, AI agents and coding with Kent Beck](https://newsletter.pragmaticengineer.com/p/tdd-ai-agents-and-coding-with-kent)（社区权威，2025-06）

这句话是说：这个精灵不想做 TDD，它想先写代码，再写一些刚好能通过的测试。

> "AI agents can (and do!) introduce regressions. An easy way to ensure this does not happen is to have unit tests for the codebase… he's having trouble stopping AI agents from **deleting tests in order to make them 'pass'**!"
> —— 同上（社区权威，2025-06）

意思是：AI agent 会引入回归 bug。防止这一点的简单办法是给代码库配单元测试。但 Beck 也坦言，他很难阻止 agent 直接删掉测试来让它们「通过」。

Augment Code 的工程指南独立引用了同一组观察，并补了量化背景。他们指出，AI 生成的代码「看起来对」，但常常悄悄偏离了行为契约。USENIX Security 2025 的一项研究显示，商用模型的包幻觉率至少 5.2%，开源模型 21.7%。来源：[Spec + TDD: The Combination That Actually Produces Shippable AI Code](https://www.augmentcode.com/guides/spec-tdd-shippable-ai-generated-code)（社区，2026-03）转引自 [We Have a Package for You!（arXiv:2406.10279，即 USENIX Security 2025 会议论文）](https://arxiv.org/abs/2406.10279)（学术，2024）。注意这和 [#042](../05-quality-assurance/042-hallucinated-apis-and-dependencies.md) 引的是同一篇论文，不是两项独立研究。

「agent 会走捷径、TDD 是防回归超能力」这个论断有两个以上独立来源支撑。

> 个人观点（小C）：理解这一点，就能解释为什么社区里很多人觉得「AI 写的测试都是假测试」。根因不是模型不行，而是默认流程让 agent 既当运动员又当裁判。你把「写测试」和「写实现」交给同一个 agent、在同一个上下文里干，它写出的测试天然会贴合它自己的实现，这种测试怎么跑都过（tautological test，同义反复的测试）。唯一的解法是让测试先于实现存在，并强制 agent 亲眼看着测试失败。

### 3. 「现在没测试了，但测试工作还在」——形态变化的真相

这是本篇最核心的认知纠偏。很多人误以为「AI 把代码写完了，测试就能省了」。恰恰相反。

| 传统 TDD 里测试的角色 | AI 时代测试的新角色 | 变与不变 |
|------|------|---------|
| 设计反馈（写不出测试＝设计差） | **验收标准**：给 agent 的可执行目标 | 形态从「单测」扩到「任何过/不过检查」 |
| 防回归 | **防回归**（更重要了：agent 一次改多文件，回归是常态） | 价值**上升** |
| 文档 | **契约**：规格与实现的桥梁 | 价值上升 |
| 重构安全网 | **重构安全网**（agent 重构最易改坏语义） | 价值上升 |

社区已经形成一个高度共识的说法：**测试即规范（tests as the spec）**。意思是不写散文式需求，而是写一个会失败的测试，把它当作 agent 的规格。红绿循环里「让测试通过」这一步直接交给 agent。来源：[Socratopia: TDD vs Test-After](https://www.socratopia.app/library/software-engineering-craft-en/chapter-8) 和 [vibehackers: Learn Vibe Coding 2026](https://vibehackers.io/blog/learn-vibe-coding)（社区，2025-2026）。这两个来源概念一致，但都偏教程站，权威性中等。

Anthropic 官方对「广义测试」的表述支撑了这种扩张：构建、代码检查、截图对比都算。来源：[Best practices](https://code.claude.com/docs/en/best-practices)（官方，2026-06）。

所以别把「AI 里的 TDD」窄化成「让 agent 写 pytest」。只要一个检查能产出「过或不过」的信号，并且先于实现存在，它就是 AI 时代的测试。

### 4. 为什么「先失败、再实现」的顺序不可让步

superpowers 里的 `test-driven-development` 技能把这条铁律写得很直白：

> "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST… **If you didn't watch the test fail, you don't know if it tests the right thing.**"
> —— [obra/superpowers: test-driven-development SKILL.md](https://github.com/obra/superpowers/blob/main/skills/test-driven-development/SKILL.md)（社区/开源，2025-2026）

意思是：没有先写一个失败的测试，就不准写生产代码。如果你没亲眼看着测试失败，你就不知道它到底测没测对东西。

它甚至要求：如果 agent 先写了实现，就删掉重来。听起来极端，但逻辑链很硬。

第一，事后补的测试一跑就过，证明不了任何事。它可能测错了对象，可能测的是实现细节而非行为，也可能漏掉了你自己都忘了的边界情况。来源：[superpowers SKILL.md](https://github.com/obra/superpowers/blob/main/skills/test-driven-development/SKILL.md)（社区）。

第二，agent 写完代码再补测试，测试天然会贴合实现。这就是 Augment Code 点名的「测试反转（test inversion）」失败模式：

> "test inversion occurs when AI generates both code and tests. The result is tautological tests that confirm whatever the implementation does while leaving the system's real requirements unverified"

意思是：当 AI 同时生成代码和测试时，就会出现测试反转。结果是一堆同义反复的测试，它们只会确认「实现做了什么」，而系统真正的需求根本没被验证。来源：[Spec + TDD](https://www.augmentcode.com/guides/spec-tdd-shippable-ai-generated-code)（社区，2026-03）。

一句话总结：「先写测试」在传统 TDD 里是纪律，在 AI 时代的 TDD 里是防伪造。顺序错了，整个验证环就塌了。

### 5. 反向证据：只在 prompt 里喊「请用 TDD」，回归反而变多

这是本篇最需要单独拎出来的一条，因为它推翻了很多人的做法（在 CLAUDE.md 里写一句「遵循 TDD」就当配好了）。

arXiv 的一项研究在 SWE-bench Verified 上，用消费级硬件跑 Qwen3-Coder 30B 等开源小模型。研究发现，如果只给 TDD 流程指令、却不告诉模型「该验哪些测试」，对小模型反而有害：回归率从基线的 6.08% 被推高到 9.94%，比不干预还差。而该研究提出的 TDAD 影响分析方法（先分析这次改动会影响哪些测试，再把这批测试喂给模型）能把回归率降到 1.82%。作者的解读是，小模型更吃「上下文信息」，而不是「流程说教」。

来源：[TDAD: Test-Driven Agentic Development](https://arxiv.org/abs/2603.17973)（研究，2026-03，单源，编号与数据已于 2026-07-18 核实）。

对你的直接影响：光写「请用 TDD」没用，甚至有害。必须给出**具体要跑的命令和具体要绿的测试文件**，并且让 agent 真的跑、真的贴输出。下面「怎么做」的每个 Phase 都围绕这一点设计。

---

## 怎么做

下面是 AI 时代 TDD 的步骤化流程。核心心法只有一句：你掌控测试（契约），agent 掌控实现（填空）。

### Phase 0：把验收标准做成可执行检查（你来做）

在让 agent 动任何实现代码之前，先产出至少一个会失败的检查。形态按性价比选：

- 纯逻辑函数：用单元测试（pytest / vitest / jest）。
- API 行为：用契约测试或集成测试，形式是「输入 → 预期输出」。
- UI 改动：用「实现后截图，与设计稿对比，列出差异并修复」，这是官方推荐的 prompt 模式。
- 没有现成测试框架：构建退出码、代码检查、或一个 `diff` 对比脚本都算。

关键标准是：这个检查必须现在就失败（RED）。如果你连一个会失败的检查都写不出来，说明验收标准还没清晰到能交给 agent。先回去把规格弄清楚。相关做法可参见 [#031 plan-execute-review 循环](./031-plan-execute-review-loop.md)。

### Phase 1：RED —— 让 agent 写失败测试，并跑给你看

把验收标准交给 agent，要求它做两件事：

1. 写出测试。
2. 运行测试，把失败输出贴给你。要的不是「我写好了」，而是「这是它失败的证据」。

这一步是防作弊的关键。Anthropic 官方反复强调，要让 Claude 拿出证据，而不是口头声称成功：贴出测试输出，贴出它跑过的命令。来源：[Best practices](https://code.claude.com/docs/en/best-practices)（官方，2026-06）。你要确认的是失败信息符不符合预期，也就是它失败的原因是「功能还没实现」，而不是「拼写错了」或「import 写错了」。

### Phase 2：GREEN —— 让 agent 写最小实现

指令要明确：写最小的代码让测试通过，不要加额外功能，不要顺手重构。superpowers 把这一步叫「刚好能通过的最小代码」，并警告最常见的过度设计反模式（YAGNI，你不会需要它）。来源：[SKILL.md](https://github.com/obra/superpowers/blob/main/skills/test-driven-development/SKILL.md)（社区）。

让 agent 实现后自己跑测试，全绿了再进下一步。如果 agent 跑测试发现失败，它应该改代码，而不是改测试。这一条要写进 prompt，因为 agent 的默认倾向就是改测试去迁就实现（对应 Kent Beck 的「删测试」警告）。

### Phase 3：VERIFY —— 要证据，不要断言

要求 agent 贴出三样东西：测试通过的输出、它跑过的命令、以及（如果是 UI 场景）结果截图。官方的原话是，审查证据比你自己重跑一遍验证更快。来源：[Best practices](https://code.claude.com/docs/en/best-practices)（官方，2026-06）。

进阶做法：对长任务或无人值守任务，用对抗式验证。做法是让一个全新的子 agent（fresh context，全新上下文），只看代码差异和验收标准来挑刺。因为一个跑在全新上下文里的审查者，只能看到差异本身，看不到产生这次改动的推理过程，所以不会替它辩护。来源：[Best practices](https://code.claude.com/docs/en/best-practices)（官方）。写代码的人和打分的人，不能是同一个上下文。

### Phase 4：REFACTOR —— 全绿才重构，一直绿着才算完

测试全绿后，可以让 agent 重构，比如去重、改名、抽函数。铁律是：重构期间测试必须始终保持全绿。

可复制的重构指令：

```
现在重构 src/utils/email.ts：去重、改名、抽小函数。约束：
1. 不准修改 tests/ 下的任何文件
2. 每完成一处改动就跑一次 npm test，贴出输出
3. 任何一次出现红色，立刻回滚这一处改动，不要改测试去迁就
4. 结束时贴 `git diff --stat`，确认 tests/ 下 0 changed
```

怎么判断做对了：`git diff --stat -- tests/` 输出为空（测试文件一行没动），且 `npm test` 全绿。

这张回归保护网，是 agent 重构时唯一能拦住「语义漂移」的东西。语义漂移指的是函数签名没变、行为却悄悄变了。Augment Code 点名这是「最安静的失败模式」，单元测试和类型检查都抓不住，需要属性测试或契约边界测试才行。来源：[Spec + TDD](https://www.augmentcode.com/guides/spec-tdd-shippable-ai-generated-code)（社区，2026-03）。

属性测试指的是不写具体用例，而是描述「对任意输入都该成立的性质」，由框架自动生成大量输入去撞。常用框架（截至 2026-08）：Python 用 [Hypothesis](https://hypothesis.readthedocs.io/)，JS/TS 用 [fast-check](https://fast-check.dev/)，Java 用 jqwik。举个 fast-check 的最小例子，验证「归一化函数是幂等的」这个性质，语义漂移会当场被抓出来：

```ts
import fc from 'fast-check';
import { normalizeEmail } from '../src/utils/email';

test('normalizeEmail 是幂等的', () => {
  fc.assert(fc.property(fc.emailAddress(), (e) => {
    expect(normalizeEmail(normalizeEmail(e))).toBe(normalizeEmail(e));
  }));
});
```

### Phase 5：把回归保护网留在代码库里

每个循环结束后，新增的测试要留在仓库里，成为下次 agent 改动时的防回归网。落地动作有两个：

1. **测试必须和实现同一个 commit 进仓库**，否则下次 `/clear` 之后这层保护就不存在了。
2. **把测试命令写进 CLAUDE.md**，让每个新会话的 agent 都知道该跑什么。例如：

```markdown
# Testing
- 全量：`npm test`；单文件：`npm test -- tests/email.test.ts`
- 提交前必须 `npm test && npm run lint` 全绿
- 测试失败时修实现，禁止修改或删除 tests/ 下的文件
```

怎么判断做对了：开一个新会话，问 `我们项目怎么跑测试？`，agent 应当直接回出上面的命令，而不是去猜或去翻 package.json。

这是 TDD 在 AI 时代产生复利的来源：测试库越厚，agent 越不敢、也越不能把既有逻辑改崩。

### 让验证「硬闭合」的四个档位（官方）

官方给了从轻到重的四档验证闭合方式，按无人值守程度递增。来源：[Best practices](https://code.claude.com/docs/en/best-practices)（官方，2026-06）。

| 档位 | 机制 | 适用 |
|------|------|------|
| 单 prompt 内 | 让 Claude 在同一条消息里跑检查并迭代 | 任何任务，今天就能用 |
| 跨会话 | 设成 `/goal` 条件，每轮后由独立评估器复查 | 中等长度任务 |
| 确定性闸门 | 用 `Stop` hook 跑你的检查脚本，脚本退出码 2 就不让停（连续被挡 8 次后 Claude Code 覆盖 hook 强制结束）| 无人值守任务 |
| 第二意见 | 用验证子 agent 或动态工作流，换个新模型来反驳结果 | 正确性要求高 |

---

## Claude Code 实战

### 最小可用流程：一段 prompt 走完 RED→GREEN→VERIFY

```
给 src/utils/email.ts 实现 validateEmail。

先写测试（vitest），覆盖：
- user@example.com → true
- invalid → false
- user@.com → false
- "" → false

要求：
1. 先写测试，运行 npm test，把失败输出贴给我
2. 确认失败原因是「函数不存在」，不是 typo
3. 写最小实现让测试通过，不要加 trim/normalize 之外的功能
4. 再跑一次 npm test，贴通过的证据
5. 如果中途测试失败，修代码不修测试
```

这段 prompt 把官方的「提供验证标准」范式，和 superpowers 的「亲眼看它失败」铁律揉在了一起。

### 用 `/goal` 把验证设成会话级停止条件

这是官方推荐的中档方案。把「测试全绿 + 代码检查通过」写成一个条件，Claude 每轮结束后由一个独立的小模型评估器复查，没达标就自动开下一轮，达标了自动清除。适合你不想全程盯着的中等任务。

三条命令就是全部（截至 2026-08，`/goal` 需要 Claude Code v2.1.139 及以上）：

```
# 设置：/goal 后面直接跟条件，回车即刻开跑，不用再发一条 prompt
/goal tests/email.test.ts 全部通过（npm test 退出码 0），且 npm run lint 无报错，过程中不修改 tests/ 下任何文件

# 查看：不带参数，显示条件、已跑轮数、token 花费、评估器最近一次的判定理由
/goal

# 取消：stop / off / reset / none / cancel 都是它的别名
/goal clear
```

写条件的三个要点（官方原文要求）：一个可测量的终态、一句「怎么证明」（如「`npm test` 退出 0」）、以及不许改动什么。条件上限 4000 字符。想限制跑多久，就在条件里加一句 `or stop after 20 turns`。

一个关键坑：评估器**不会自己跑命令、也不会读文件**，它只看 Claude 在对话里已经贴出来的内容。所以条件必须写成「Claude 的输出能证明的东西」——这也是为什么必须要求 agent 贴测试输出。另外 `/goal` 不改权限，默认权限模式下每个工具调用还是会问你；要真无人值守得配合 auto mode。

怎么判断生效了：设完之后界面上会出现 `◎ /goal active` 指示器，并显示已运行时长。

来源：[Keep Claude working toward a goal](https://code.claude.com/docs/en/goal)（官方，2026-08 核实）。

### 用 `Stop` hook 做确定性闸门（无人值守）

`/goal` 靠模型判定，Stop hook 靠退出码判定，后者是确定性的。做法是在 `.claude/settings.json` 里配一个 Stop hook，每次 Claude 想结束回合时跑你的检查脚本，脚本退出码为 2 就把这一轮挡回去、让它继续干。

**第一步：写检查脚本** `.claude/hooks/check-tests.sh`（记得 `chmod +x`）。

```bash
#!/bin/bash
# .claude/hooks/check-tests.sh
# 退出 0 = 允许 Claude 结束；退出 2 = 挡住，让它继续修

input=$(cat)
# 防死循环：如果本次已经处在 Stop hook 触发的续跑里，就直接放行
if echo "$input" | jq -e '.stop_hook_active == true' > /dev/null 2>&1; then
  exit 0
fi

if ! { npm test --silent && npm run lint --silent; }; then
  # stderr 的内容会作为反馈回灌给 Claude，写清楚要它干什么
  echo "测试或 lint 未通过。请修复实现代码，禁止修改或删除 tests/ 下的文件。" >&2
  exit 2
fi

exit 0
```

**第二步：配 `.claude/settings.json`**（完整可复制，直接放项目根目录的 `.claude/` 下）。

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/check-tests.sh",
            "timeout": 300,
            "statusMessage": "正在校验测试与 lint..."
          }
        ]
      }
    ]
  }
}
```

三个字段说明（截至 2026-08 官方 hooks 文档）：

- `Stop` 事件**不支持 `matcher`**，写了也会被忽略，所以上面直接省略。
- `type` 除 `"command"` 外还支持 `"prompt"`（让模型判定）等，确定性闸门用 `"command"`。
- `timeout` 单位是秒，command 类 hook 默认 600 秒；测试慢的项目要往上调，别让 hook 自己超时。

**第三步：确认生效。** 别信配置文件，跑一遍：

1. 在 Claude Code 里运行 `/hooks`，应该能在 `Stop` 下看到你这条命令。
2. 手动把一个测试改挂（比如把断言的期望值改错），然后让 Claude 做一件小事并结束回合。
3. 预期现象：Claude 不会停下，终端显示 hook 的 statusMessage，紧接着它会拿着 stderr 里的那句话继续去修实现。
4. 手动验证脚本本身：`echo '{}' | .claude/hooks/check-tests.sh; echo "exit=$?"`，测试挂着时应输出 `exit=2`，全绿时应输出 `exit=0`。

**「连续 8 次」是什么意思。** 官方原话是 Claude Code 在连续 8 次被挡之后会**覆盖这个 hook、强行结束回合**。也就是说 Stop hook 不是死循环保险丝，是「最多再逼它修 8 轮」。所以当你发现回合最终还是结束了、但测试仍然是红的，不是 hook 没配好，而是撞到了这个上限——通常意味着 agent 陷在同一个错误里出不来，该你介入了。

hook 是确定性的，能保证这个动作一定发生，这和 CLAUDE.md 的「建议性」完全不同。来源：[Hooks reference](https://code.claude.com/docs/en/hooks)、[Best practices](https://code.claude.com/docs/en/best-practices)（官方，2026-08 核实）。详见 [#033 skill/superpowers](./033-skill-superpowers-usage.md)。

### superpowers 的 `test-driven-development` 技能：把铁律变成强制流程

装了 `obra/superpowers` 插件后，`test-driven-development` 技能会在任何新功能或修 bug 之前，强制走一遍 RED→GREEN→REFACTOR。核心是两条硬约束。来源：[SKILL.md](https://github.com/obra/superpowers/blob/main/skills/test-driven-development/SKILL.md)（社区，2025-2026）。

1. **铁律（Iron Law）**：没有失败测试，就不准写生产代码。先写了实现，就删掉重来。
2. **验证 RED 和验证 GREEN 都是强制项**：必须真的跑测试、看输出，而不是声称通过。

它甚至维护一张「常见借口（Common Rationalizations）」表，用来识别 agent 的偷懒话术，比如「这太简单了不用测」「我等下再测」「删掉太浪费了」。每一条都对应同一个处理：删掉重来。这是目前把 AI 时代 TDD 流程化得最彻底的开源实现。

### 双 session：写测试的人 ≠ 写实现的人

这是官方在并行会话里点名的质量玩法：一个 Claude 写测试，另一个 Claude 写实现。来源：[Best practices: Run multiple Claude sessions](https://code.claude.com/docs/en/best-practices)（官方，2026-06）。全新上下文的审查者不会偏向自己刚写的代码。这对正确性敏感的逻辑特别有效，比如金额计算、鉴权。

### 排错场景：先写一个复现 bug 的失败测试

官方给了排错的 prompt 模板。来源：[Best practices](https://code.claude.com/docs/en/best-practices)（官方，2026-06）：

> "users report that login fails after session timeout. check the auth flow in src/auth/, especially token refresh. **write a failing test that reproduces the issue, then fix it**"

意思是：用户反馈会话超时后登录失败，检查 src/auth/ 里的鉴权流程，尤其是 token 刷新，先写一个能复现问题的失败测试，然后再修。

这就是修 bug 的 TDD 变体：先写复现测试（RED），再修复（GREEN），最后把测试留在仓库防回归。比起「让 agent 直接改」，这多了一层保证：这个 bug 再也不会悄悄回来。

---

## 横向对比

| 维度 | Claude Code | Cursor | GitHub Copilot |
|------|------------|--------|----------------|
| **TDD 内置程度** | 官方最佳实践明确推荐「先写失败测试」；superpowers 技能可强制 | 靠 rules / `.cursor/rules` 引导；社区有 TDD 自定义规则 | 无内置 TDD 工作流；靠 instructions 文件 |
| **验证闭合机制** | `/goal` + `Stop` hook（确定性闸门）+ 验证子 agent | 无原生 hook 闸门；靠 agent 自检 | 无 |
| **对抗式验证** | 原生子 agent / 双 session 写测试与审查分离 | Composer 支持多文件，但无独立打分者 | 无 |
| **测试作为停止条件** | 官方范式：把「实现后跑测试」写进 prompt 模板 | 用户自建 | 无 |

共性观察：所有工具的 agent 都有「先写代码再补测试」的天然倾向。Kent Beck 的「精灵」观察适用于全部 LLM agent。

差异在于「强制力」。Claude Code 的 hook 加子 agent 组合，目前是把 TDD 流程闭合得最硬的工具；Cursor 和 Copilot 更多依赖人工纪律。

Cursor 上能做到的最接近的东西，是在 `.cursor/rules/` 下放一个 `.mdc` 规则文件。frontmatter 有三个字段：`description`（让 agent 自行判断何时套用）、`globs`（按文件路径自动挂载）、`alwaysApply`（设为 `true` 时每次会话都加载，此时另外两个字段被忽略）。可直接复制：

```markdown
---
description: TDD 红绿重构工作流
alwaysApply: true
---
# TDD
- 写实现代码之前，先写一个会失败的测试，并运行它、贴出失败输出。
- 确认失败原因是「功能未实现」，不是拼写或 import 错误。
- 只写刚好能让测试通过的最小实现，不要顺手加功能。
- 测试失败时修实现代码。禁止修改、跳过或删除任何已有测试。
- 结束前重新运行测试，贴出通过的命令与输出，不要只说「已通过」。
```

两个已知限制：规则在启动时缓存，改完 `.mdc` 需要重开窗口才生效；而且它和 CLAUDE.md 一样是建议性的，没有 Stop hook 那种「不过就不让停」的强制退出码闸门。

来源：[Cursor Docs: Rules](https://cursor.com/docs/context/rules)（官方，2026-08 核实 frontmatter 字段）、[Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)（官方，2026-08 核实）。

---

## 反模式

❌ **让 agent 写完代码再补测试。** 这是 AI 时代 TDD 的头号反模式。事后测试一跑就过、证明不了任何事，而且天然贴合 agent 自己的实现（测试反转）。Kent Beck 的话：精灵想先写代码，再写能通过的测试。这条有官方、Beck、Augment 三个来源支撑。

❌ **测试只测 mock、不测真实行为。** superpowers 举了个反例：一个叫 `test('retry works')` 的测试全程用 `jest.fn()`，测的是 mock，不是真实代码。AI 特别爱这么干，因为 mock 不依赖真实实现、写起来容易。要求它「用真实代码，非必要不用 mock」。来源：superpowers SKILL（社区）。

❌ **agent 跑测试失败时，让它改测试去迁就实现。** 这是 agent 的默认倾向，包括直接删测试。要明确写进 prompt：测试失败时修代码，不许改测试。来源：Kent Beck 的观察。

❌ **只在 prompt 里喊「请用 TDD」，却不让它真跑测试。** arXiv 的 TDAD 研究显示，只给流程说教、不给「该验哪些测试」的上下文，对开源小模型反而增加回归（基线 6.08% 升到 9.94%）。TDD 的价值来自「看测试失败 → 实现 → 看测试通过」的闭环，不是 prompt 里的一句话。来源为单源研究。

❌ **把 TDD 窄化成「写 pytest」。** AI 时代的「测试」包括构建退出码、代码检查、截图对比、契约测试。UI 改动用「实现后截图对比设计稿」就是合格的 TDD 检查。来源：官方。

❌ **接受 agent「声称通过」而不看证据。** 要求它贴出测试输出、命令、截图。官方原话：让 Claude 拿出证据，而不是口头断言成功。来源：官方。

❌ **写测试的人和打分的人是同一个上下文。** agent 自己评自己，必然偏向刚写的代码。长任务要用全新上下文的子 agent 做对抗式审查。来源：官方。

❌ **重构时不保持测试全绿。** agent 重构最容易引入「语义漂移」：签名没变，行为变了。单元测试和类型检查都抓不住。重构期间测试必须始终绿，且对关键逻辑补上属性测试或契约边界测试。来源：Augment。

---

## 延伸

**交叉引用：**
- [#031 plan → execute → review 的正确循环怎么做？](./031-plan-execute-review-loop.md) —— TDD 的 RED 阶段本质是「把验收标准前置」，和先规划工作流同源
- [#033 Skill / superpowers 怎么用、怎么写？](./033-skill-superpowers-usage.md) —— `test-driven-development` 技能把 TDD 铁律强制化；`Stop` hook 做确定性验证闸门
- [#012 上下文窗口要爆了怎么办？](../02-context-engineering/012-context-window-exploding.md) —— 长任务用验证子 agent 既保证质量又隔离主上下文

**参考资料：**
- [Best practices for Claude Code — Claude Code Docs](https://code.claude.com/docs/en/best-practices) —— 官方头号参考：「给 Claude 一个能验证自己工作的方法」、`/goal`、`Stop` hook、验证子 agent、双 session 写测试与审查分离（官方，2026-06）
- [Hooks reference — Claude Code Docs](https://code.claude.com/docs/en/hooks) —— `Stop` hook 的 settings.json 结构、退出码 2 的语义、`stop_hook_active` 防死循环字段（官方，2026-08 核实）
- [Keep Claude working toward a goal — Claude Code Docs](https://code.claude.com/docs/en/goal) —— `/goal` 的设置 / 查看 / `clear` 用法、条件写法、评估器不跑命令的限制（官方，2026-08 核实）
- [Cursor Docs: Rules](https://cursor.com/docs/context/rules) —— `.cursor/rules/*.mdc` 的 `description` / `globs` / `alwaysApply` 字段语义（官方，2026-08 核实）
- [TDD, AI agents and coding with Kent Beck — The Pragmatic Engineer](https://newsletter.pragmaticengineer.com/p/tdd-ai-agents-and-coding-with-kent) —— Kent Beck 论 TDD 是 AI agent 的超能力；agent 会删测试让套件通过（社区权威，2025-06）
- [Spec + TDD: The Combination That Actually Produces Shippable AI Code — Augment Code](https://www.augmentcode.com/guides/spec-tdd-shippable-ai-generated-code) —— 五阶段 Spec+TDD 工作流；测试反转、语义漂移等四种失败模式；引用 Beck 原话（社区，2026-03）
- [test-driven-development SKILL.md — obra/superpowers](https://github.com/obra/superpowers/blob/main/skills/test-driven-development/SKILL.md) —— 铁律、验证 RED/GREEN 强制、常见借口表（社区/开源，2025-2026）
- [Claude Code and the Art of Test-Driven Development — The New Stack](https://thenewstack.io/claude-code-and-the-art-of-test-driven-development/) —— 实战演示 Claude Code 走完整 TDD 循环；人定质量门槛、agent 填实现（社区，2025-04）
- [Demystifying evals for AI agents — Anthropic Engineering](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) —— 官方对 agent 验证与评估的方法论（把评估当成给 AI 的测试）（官方，2025）
- [TDAD: Test-Driven Agentic Development — arXiv](https://arxiv.org/abs/2603.17973) —— 反向证据：只给 TDD 流程指令、不给测试上下文，对开源小模型增加回归（基线 6.08% 升到 9.94%；TDAD 方法本身降至 1.82%）（研究，2026-03，编号已核实真实存在，单源）
- [r/ClaudeCode: I got obsessed with making AI agents follow TDD](https://www.reddit.com/r/ClaudeCode/comments/1mjg1m1/i_got_obsessed_with_making_ai_agents_follow_tdd/) —— 让 agent 真正走 TDD 的社区踩坑（社区，2025）
- [TDD vs Test-After — Socratopia](https://www.socratopia.app/library/software-engineering-craft-en/chapter-8) —— 测试即规范，以及红绿循环在 agent 下的变形（社区，2025-2026）
- [We Have a Package for You! — arXiv:2406.10279（USENIX Security 2025）](https://arxiv.org/abs/2406.10279) —— 包幻觉率：商用模型至少 5.2%、开源模型 21.7%。本篇经 Augment Code 转引，原文详解见 [#042](../05-quality-assurance/042-hallucinated-apis-and-dependencies.md)（学术，2024）

> 本篇个人实践（L4）：

<!-- 待补：Claude Code 里用 TDD 走通/走崩的真实案例；superpowers TDD skill 启用前后的对比；agent 删测试被抓到的瞬间 -->

