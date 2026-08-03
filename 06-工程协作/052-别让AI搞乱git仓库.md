# 052. 怎么不让 AI 把 git 仓库搞乱？（禁掉 force push / reset --hard，去掉 Co-Authored-By 署名）

> 难度：中级
> 主题：工程协作
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：流程题

## TL;DR

AI 几分钟改一大片代码，git 流程（分支、commit、PR）却是照人的协作节奏设计的。防它搞乱靠的不是嘱咐，是三样能落地的东西：

**一、把破坏性 git 命令写进 `permissions.deny`。** 这是唯一真正拦得住的手段。官方明确说：权限规则由 Claude Code 执行，不由模型执行，写在 prompt 或 CLAUDE.md 里的话不改变它被允许做什么（[CC Docs: permissions](https://code.claude.com/docs/en/permissions)，官方，2026-08）。完整可复制配置见"治理层"。

**二、去掉 AI 署名用 `attribution`。** 默认 commit 带 `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`，PR 带 `🤖 Generated with [Claude Code](...)`。关掉是把 `attribution.commit` 和 `attribution.pr` 设为空串，再把 `sessionUrl` 设 `false`（[CC Docs: settings](https://code.claude.com/docs/en/settings)，官方，2026-08）。旧开关 `includeCoAuthoredBy` 已被官方标记为 deprecated，`attribution` 优先级更高。

**三、分支短命 + PR 人审。** 分支活几小时不是几天，main 一往前走 AI 当初的假设就过期；PR 提交前人必须读懂 diff——官方原话"Review Claude's generated PR before submitting"（[CC Docs: common-workflows](https://code.claude.com/docs/en/common-workflows)，官方，2026-08）。

本篇只讲 git 这个载体：分支、commit、PR、署名、权限。PR 大到没法 review 见 [#053](./053-AI的PR太大没法review.md)。谁来验证代码见 [#040](../05-质量保证/040-怎么验证AI代码是真的对.md)。跨仓协作见 [#051](./051-跨仓改动只改了一边.md)。

## 为什么

### 1. AI 打破了 git 流程的一个隐含前提

传统 git 流程默认"写代码"是最慢的瓶颈，所以才有开 feature 分支、慢慢攒 commit、PR 排队 review 这一套。

AI 把写代码压到了几分钟，瓶颈立刻移到另一头：人能多快理解并合并这些改动。

> "The agent writes code against the branch state. Main moves on. By the time you merge, half the agent's assumptions are wrong."
> AI 基于当时的分支状态写代码。main 却在继续往前走。等你合并时，AI 当初一半的假设已经不成立了。
> — [dev.to: Trunk-Based Development with Short-Lived Branches](https://dev.to/tacoda/trunk-based-development-with-short-lived-branches-5f74)（社区，2026）

结论：分支活得越久，AI 的产出越危险。所以 AI 时代分支策略要往短命分支 / trunk-based 偏。

### 2. checkpoint 不是 git，兜不住破坏性命令

有一个反直觉的点：官方明确说 Claude Code 的 checkpoint（用 `/rewind` 回退的存档点）不能替代 git。

> "Checkpoints only track changes made through Claude's file editing tools. Changes made through Bash commands or external processes are not captured. **This isn't a replacement for git.**"
> checkpoint 只记录 Claude 通过文件编辑工具做的改动。通过 Bash 命令或外部进程做的改动不会被记录。这不是 git 的替代品。
> — [CC Docs: best-practices](https://code.claude.com/docs/en/best-practices)（官方，2026-08）

也就是说：`git reset --hard`、`git push --force`、`git rebase` 这些走 Bash 的操作，checkpoint 完全看不见，也回退不了。它们一旦执行，你只剩 reflog 这条命（远端 force push 之后连 reflog 都救不了别人）。

### 3. 嘱咐没有强制力，只有权限规则有

官方在权限文档里把这句话写死了：

> "Permission rules are enforced by Claude Code, not by the model. Instructions in your prompt or `CLAUDE.md` shape what Claude tries to do, but they don't change what Claude Code allows."
> 权限规则由 Claude Code 强制执行，不是由模型执行。写在 prompt 或 CLAUDE.md 里的指令只影响 Claude 想做什么，不改变 Claude Code 允许它做什么。
> — [CC Docs: permissions](https://code.claude.com/docs/en/permissions)（官方，2026-08）

所以"怎么不让 AI 搞乱"这个问题，答案在 settings.json 的 `permissions.deny`，不在 CLAUDE.md 的措辞。

### 4. 署名是团队治理问题，不是技术问题

留不留 `Co-Authored-By` 没有技术上的对错，但开源社区已经把它吵成了决策题。Kubernetes 官方政策直接禁掉 AI 署名和 AI 写的 commit message，详见"横向对比"。所以团队要先定政策再配置。

## 怎么做

三层 checklist，同一个原则：AI 干快的那部分，人守慢的那道闸。

### 分支层

**1. 优先用短命分支 / trunk-based。** 一个 AI 任务对应一个分支，几小时内 merge 掉（[dev.to](https://dev.to/tacoda/trunk-based-development-with-short-lived-branches-5f74)，社区）。分支越短，AI 基于的 main 状态越新。

**2. 把分支命名约定写进 CLAUDE.md。** 官方把"Repository etiquette（branch naming, PR conventions）"列为 CLAUDE.md 该放的内容（[best-practices](https://code.claude.com/docs/en/best-practices)，官方）。注意这是软约束，只能规范"怎么命名"这种没有破坏性的事；防破坏靠下面的 deny。

**3. 并行跑多个 AI 时用 worktree 隔离。** `claude --worktree feature-auth`（短写 `-w`）会在仓库根的 `.claude/worktrees/feature-auth/` 建一份独立检出，分支名默认 `worktree-feature-auth`（[CC Docs: worktrees](https://code.claude.com/docs/en/worktrees)，官方，2026-08）。记得把 `.claude/worktrees/` 加进 `.gitignore`，否则主检出里会冒出一堆未跟踪文件（官方明确提示）。

### commit / PR 层

**4. 让 AI 写 message，人定 commit 边界。** 官方工作流收尾就是"commit with a descriptive message and open a PR"（[best-practices](https://code.claude.com/docs/en/best-practices)，官方）。但这次提交包含哪些文件、拆成几个 commit 由你把关——AI 容易把一次会话的所有改动堆进一个巨型 commit。想拆就明说"把重构和功能改动拆成两个 commit"。

**5. AI 生成 PR，人读懂了才提。** 直接说"create a pr"，或用 `gh pr create`；官方建议装 `gh` CLI，因为它最省上下文（[common-workflows](https://code.claude.com/docs/en/common-workflows)，官方）。铁律是官方原话："Review Claude's generated PR before submitting and ask Claude to highlight potential risks or considerations"。

**6. 提 PR 前先过一遍对抗审。** 跑内置的 `/code-review`，它会开一个只看 diff 的全新子 agent。深入见 [#040](../05-质量保证/040-怎么验证AI代码是真的对.md) 和 [#041](../05-质量保证/041-怎么审查AI生成的代码.md)。PR 别贪大，见 [#053](./053-AI的PR太大没法review.md)。

### 治理层（防"搞乱"的真正闸门）

**7. 把破坏性 git 命令写进 `permissions.deny`。** 复制进项目根的 `.claude/settings.json`（提交进仓库，全队生效）：

```json
{
  "permissions": {
    "allow": [
      "Bash(git status *)",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(git checkout -b *)",
      "Bash(git stash *)"
    ],
    "ask": [
      "Bash(git push *)",
      "Bash(git merge *)"
    ],
    "deny": [
      "Bash(git push --force *)",
      "Bash(git push --force*)",
      "Bash(git push -f *)",
      "Bash(git push --force-with-lease *)",
      "Bash(git reset --hard *)",
      "Bash(git reset --hard*)",
      "Bash(git rebase *)",
      "Bash(git clean -fd *)",
      "Bash(git clean -fd*)",
      "Bash(git branch -D *)",
      "Bash(git filter-branch *)",
      "Bash(git update-ref *)",
      "Bash(git reflog delete *)"
    ]
  }
}
```

三个必须知道的匹配规则，都来自官方 permissions 文档（官方，2026-08）：

- **求值顺序是 deny → ask → allow，先匹配到的说了算，规则的具体程度不影响顺序。** 所以上面 `allow` 里再宽的 git 规则也解不开 deny。
- **`*` 前有没有空格不一样。** `Bash(ls *)` 匹配 `ls -la` 但不匹配 `lsof`；`Bash(ls*)` 两个都匹配。所以上面对 `--force` / `--hard` / `-fd` 各写了带空格和不带空格两条，覆盖 `git push --force` 这种末尾没有参数的写法。（官方也说 `Bash(x:*)` 等价于 `Bash(x *)`，只在模式结尾有效。）
- **复合命令要逐段匹配。** 官方说 Claude Code 认识 `&&`、`||`、`;`、`|`、`&`、换行这些分隔符，`git status && git reset --hard` 里的 `git reset --hard` 会被单独拿去匹配 deny，不会因为前半段被允许就整条放行。

需要注意的两个边界，别以为配完就万事大吉：

- 环境运行器不在官方的 wrapper 剥离名单里。`Bash(devbox run *)`、`docker exec`、`npx` 这类会执行任意内层命令，deny 规则看不到里面。别给它们开宽泛的 allow。
- 官方剥离的 wrapper 只有 `timeout`、`time`、`nice`、`nohup`、`stdbuf`、`command`、`builtin`、`noglob`、无参数的 `xargs`。deny 规则会穿过任意前置环境变量赋值，`FOO=bar rm -rf tmp/` 仍会被 `Bash(rm *)` 拦下。

**怎么判断做对了（必做）：**

```bash
# 1. 看规则确实被加载了，以及来自哪个文件
claude
> /permissions

# 2. 直接让它试一次危险命令
> 帮我执行 git reset --hard HEAD~1
```

预期：`/permissions` 列表里能看到上面这些 deny 条目并标注来源文件；第二步 Claude 不会弹权限确认框，而是直接报告该命令被权限规则拒绝、拒绝执行。如果它弹出了"是否允许"的确认框，说明规则没匹配上（最常见原因是漏了不带空格的那条，或者配置写在了没被加载的文件里）。

**8. 无人值守时再收一层。** 批处理 / CI 里用 `--allowedTools` 把能力收窄到安全子集，官方示例是 `--allowedTools "Edit,Bash(git commit *)"`（[best-practices](https://code.claude.com/docs/en/best-practices)，官方）。注意 `--allowedTools` 只是"免确认"，要限制哪些工具可用官方指向 `--tools`（[cli-reference](https://code.claude.com/docs/en/cli-reference)，官方，2026-08）。

**9. "提交前必跑测试"这种硬门禁用 hook，不用嘱咐。** 写进 CLAUDE.md 会被忽略。官方 hook 的 settings.json 结构如下（`if` 字段用的就是权限规则语法）：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(git commit *)",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-commit-test.sh",
            "timeout": 300
          }
        ]
      }
    ]
  }
}
```

配套脚本 `.claude/hooks/pre-commit-test.sh`（记得 `chmod +x`）：

```bash
#!/bin/bash
# 测试不过就拦下这次 commit
if ! npm test --silent >/tmp/cc-pretest.log 2>&1; then
  jq -n --rawfile log /tmp/cc-pretest.log '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("测试未通过，commit 被拦下：\n" + $log)
    }
  }'
  exit 0
fi
exit 0   # 不打印 JSON = 不做决定，走正常权限流程
```

官方给了两种拦截方式：退出码 2（stderr 作为原因回给 Claude），或退出码 0 加上面这段 `permissionDecision: "deny"` 的 JSON。退出码 2 时 JSON 会被忽略（[CC Docs: hooks](https://code.claude.com/docs/en/hooks)，官方，2026-08）。

**验证：** 故意改坏一个测试，然后让 Claude 提交。预期它执行 `git commit` 失败，并把测试失败日志读回来。跑 `git log -1` 确认没有产生新 commit。

### 回滚层（护栏的正向解法：出事之后怎么退回去）

前面几条是"别让它搞乱"，这一层是"搞乱了怎么退"。社区在这件事上的诉求很集中：Codex 那边一个"把 `/undo` 还回来"的请求拿到 369 个 👍，提的人说的场景是"AI 删了没被 git 跟踪的文件""AI 改了还没 commit 的东西"（[Codex issue #9203](https://github.com/openai/codex/issues/9203)，社区，2026-01）；Claude Code 这边则有 161 👍 的请求，要 VS Code 插件做像 Copilot Edits Review 那样的 diff 审查界面——按文件、按块 accept / reject，不用切到 Source Control 面板再切回来（[GitHub issue #33932](https://github.com/anthropics/claude-code/issues/33932)，社区，2026-03，截至 2026-08 仍为 open）。

这两个诉求指向同一件事：AI 改完一片代码，你需要一个能逐块看、逐块决定要不要的退路。功能没落地之前，用 git 自己搭三层：

**10. 先保持工作区干净，再放 AI 试错。** 动手前 `git status` 确认干净（或先 commit / stash），出问题就能 `git checkout .` 退回去。这是三层里唯一兜得住"AI 用 Bash 删了文件"的一层——checkpoint 只记录文件编辑工具的改动，Bash 层看不见。未跟踪文件更要注意：`git stash -u` 才会连未跟踪文件一起存。

**11. 会话内的小回退用 `/rewind`。** 它能退回 Claude 用文件编辑工具做的改动，适合"这一轮改歪了，退到上一步重来"。但别把它当 git 用：走 Bash 的改动、外部进程的改动它都不记录（官方原话见"为什么"第 2 节）。

**12. 逐块审查用 `git add -p` 代替全盘接受。** 这是"逐块 diff 审查"在命令行里现成的等价物：

```bash
git diff                 # 先整体扫一遍 AI 改了什么
git add -p               # 逐块过：y 收下 / n 丢弃 / s 拆更小 / e 手改这一块
git checkout -- .        # 没 add 的（即你不要的那些块）一次性丢掉
```

`git add -p` 的 `s` 能把一个大 hunk 拆成更小的块，`e` 能直接编辑这一块再收；`git restore -p`（新版 git）则是反过来逐块丢弃。搭配上面第 4 条"人定 commit 边界"，一次 AI 大改就能拆成几个各自能单独 revert 的 commit——回滚粒度是在 commit 阶段挣来的，不是出事之后。

**验证：** 让 AI 改三个文件，然后跑 `git add -p` 只收其中一块，再跑 `git stash -u && git stash drop` 丢掉其余改动。预期 `git diff --cached` 只剩你收的那一块，`git status` 工作区干净。

## Claude Code 实战

### 去掉 `Co-Authored-By` 和 PR 署名

官方给出的默认值（[CC Docs: settings](https://code.claude.com/docs/en/settings)，官方，2026-08）：

- commit 默认加 git trailer：`Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`，trailer 里的模型名跟随当前会话使用的模型变化。
- PR 描述默认加：`🤖 Generated with [Claude Code](https://claude.com/claude-code)`。

全部关掉：

```json
{
  "attribution": {
    "commit": "",
    "pr": "",
    "sessionUrl": false
  }
}
```

三个键的官方含义：`commit` 是 commit 的署名内容（含 trailer），空串隐藏；`pr` 是 PR 描述的署名，空串隐藏；`sessionUrl` 控制在 cloud / Remote Control 会话里要不要追加 claude.ai 会话链接（commit 上是 `Claude-Session` trailer，PR 里是一个链接），默认 `true`，设 `false` 去掉。官方原话："To hide all attribution, set `commit` and `pr` to empty strings and `sessionUrl` to `false`."

也可以改成自定义署名而不是删掉，官方示例：

```json
{
  "attribution": {
    "commit": "Generated with AI\n\nCo-Authored-By: AI <ai@example.com>",
    "pr": ""
  }
}
```

**关于旧开关 `includeCoAuthoredBy`：** 官方文档目前标注它为 deprecated，并写明"The `attribution` setting takes precedence over the deprecated `includeCoAuthoredBy` setting"（官方，2026-08）。所以直接用 `attribution`，别再碰旧开关。社区有过旧布尔开关偶发不生效的反馈（[GitHub issue #4224](https://github.com/anthropics/claude-code/issues/4224)），这也是迁移的理由。

**放哪一层：** 项目级 `.claude/settings.json` 会覆盖全队，包括本想保留署名的人；个人偏好放 `~/.claude/settings.json`，机器级一次性设置放被 gitignore 的 `.claude/settings.local.json`。

**验证：** 配完让 Claude 提交一次，然后跑：

```bash
git log -1 --format='%B'
```

预期输出里没有任何 `Co-Authored-By:` 或 `Claude-Session:` 行。

### 一个"人守闸"的完整会话（含可复制 prompt）

| 阶段 | 你说什么（可直接复制） | AI 干什么 | 人守哪道闸 |
|------|------------------------|-----------|-----------|
| 开分支 | `按 CLAUDE.md 的命名约定开一个新分支，任务是 <一句话描述>` | `git checkout -b feat/xxx` | 命名约定写死在 CLAUDE.md |
| 实现前 | `先跑 git status 确认工作区干净，脏的话停下来告诉我` | 报告工作区状态 | 干净才动手，保证能回滚 |
| 实现 | plan→implement（[#031](../04-执行工作流/031-plan-execute-review循环.md)） | 改代码、跑测试 | 分支短命，几小时内合掉 |
| commit | `按逻辑边界把这些改动拆成多个 commit：先列出你打算怎么拆和每个 commit 包含哪些文件，等我确认后再提交` | 先出拆分方案，确认后分批 `git add -p` + commit | **人定 commit 边界**，别让它堆巨型 commit |
| 自审 | `/code-review` | 全新子 agent 只看 diff | 对抗审在提 PR 之前 |
| 提 PR | `create a pr，描述里写清楚改了什么、为什么这么改、有哪些风险点和没覆盖到的场景` | `gh pr create` + 写描述 | **人读懂 diff 才点提交**（官方铁律） |

> `gh pr create` 之后 session 会自动关联到那个 PR，用 `claude --from-pr 1234` 能找回。该参数也接受 GitHub / GitHub Enterprise PR URL、GitLab MR URL、Bitbucket PR URL（[cli-reference](https://code.claude.com/docs/en/cli-reference)，官方，2026-08）。

## 横向对比

### 官方 vs 开源社区：AI 的 git 政策光谱

宽松的一端是 Anthropic 官方工作流：AI 写 commit message、生成 PR，人 review 后提交，署名默认带（[best-practices](https://code.claude.com/docs/en/best-practices)，官方）。

严格的一端是 Kubernetes 官方政策：明令禁止 AI 写 commit message、禁止 AI 署名 co-author、禁止大型 AI 生成的 PR，并要求在 PR 描述里披露是否使用了 AI。原话是"if you cannot explain why a change was made, the PR will be closed"——解释不了改动为什么这么改，PR 直接关掉，作者不能把理解的责任甩给 reviewer（[kubernetes.dev: Pull Request Process](https://www.kubernetes.dev/docs/guide/pull-requests/)，官方项目政策，2026）。

取舍：内部私有仓可以偏宽松。对外贡献开源前先查清该项目的 AI 政策——注意这里有个坑，为了"隐藏 AI 使用"而关掉署名，可能反过来违反目标项目的披露要求。政策制度层见 [#072](../08-团队与组织/072-AI-coding安全红线.md)。

### 三家工具的 git 配合能力

| 工具 | commit / PR 配合 | 差异 |
|------|-----------------|------|
| **Claude Code** | 会话内直接 `git commit` / `gh pr create`；`attribution` 可配；`--worktree` 并行；`permissions.deny` + PreToolUse hook 双层收窄 | agent 化最深，能跑整条流程，也因此最需要权限边界 |
| **Cursor** | 内置 Generate Commit Message（读 staged diff 生成）；Agent 可提 PR | 以生成 message 为主，git 高危操作仍走人手 |
| **GitHub Copilot** | 生成 commit message；coding agent 可开分支提 PR | 与 GitHub 原生流程绑定最紧，PR 里带 Copilot 署名 |

共性：三家都把"生成 commit message / PR 描述"做成标配，这是 AI 稳赢人的部分。差异在于谁更敢让 AI 碰 git 的破坏性操作，以及给不给你收窄的手段。

## 反模式

- ❌ **靠 CLAUDE.md 嘱咐"别 force push""提交前必跑测试"。** 官方原话：权限规则由 Claude Code 执行，不由模型执行，prompt 和 CLAUDE.md 不改变允许做什么。硬门禁只能用 `permissions.deny` 或 PreToolUse hook。
- ❌ **deny 规则只写一条 `Bash(git push --force *)` 就收工。** 漏掉 `-f`、`--force-with-lease`、以及末尾无参数的 `git push --force`（空格通配符要求后面还有内容）。要么按上面那份清单逐条写全，要么干脆把 `Bash(git push *)` 整个放进 `ask`。
- ❌ **在脏工作区上放 AI 大改。** checkpoint 只记录文件编辑工具的改动，Bash 层的改动它看不见，出问题没法干净回滚。
- ❌ **把 `/rewind` 当回滚的全部依靠。** 它只覆盖文件编辑工具的改动，AI 用 Bash 删掉的、尤其是没被 git 跟踪的文件，它退不回来——社区那批"求 `/undo`"的帖子说的就是这个场景。真正的兜底是动手前工作区干净，加上 `git stash -u`。
- ❌ **AI 生成的 PR 不读 diff 就直接提，或把整个会话堆成一个巨型 commit。** 前者违反官方铁律"Review before submitting"，Kubernetes 会直接关掉这类 PR；后者是 review 灾难，也丢掉了回滚粒度。
- ❌ **在项目级 settings 里一刀切关掉署名。** 会覆盖全队偏好；对外贡献时还可能撞上目标项目的 AI 披露要求。个人偏好放 `~/.claude/settings.json` 或 `.claude/settings.local.json`。

## 延伸

**交叉引用：**
- [#053 AI 生成的 PR 太大太多，review 机制怎么扛住不崩？](./053-AI的PR太大没法review.md) —— 本篇 PR 层的深入篇。
- [#051 前后端分仓，让 AI 改一个字段它只改了一边怎么办？（跨仓工作区 + 接口契约治理）](./051-跨仓改动只改了一边.md) —— 跨仓的 git 协调（本篇聚焦单仓流程）。
- [#050 代码库一大 agent 就开始瞎找文件、抓错同名符号——大仓库 / monorepo 怎么让它不迷路](./050-大仓库monorepo里不迷路.md) —— worktree / 目录级配置的深入。
- [#040 AI 说"做完了"、测试也全绿，怎么知道代码是真的对？](../05-质量保证/040-怎么验证AI代码是真的对.md) / [#041 怎么 review AI 生成的代码？（人审 + 机审策略）](../05-质量保证/041-怎么审查AI生成的代码.md) —— 提 PR 前对抗审的攻略。
- [#031 plan → execute → review 的正确循环怎么做？](../04-执行工作流/031-plan-execute-review循环.md) —— commit 前的执行环。
- [#010 CLAUDE.md 怎么写才真的生效？](../02-上下文工程/010-CLAUDE-md怎么写才生效.md) —— 分支命名约定放哪、hook vs 嘱咐。
- [#072 AI coding 的安全红线怎么画？密钥泄露、数据外泄、第三方上传的真实事故与防护](../08-团队与组织/072-AI-coding安全红线.md) —— AI git 政策的制度层。

**参考资料：**
- [Configure permissions - Claude Code Docs](https://code.claude.com/docs/en/permissions) — deny→ask→allow 求值顺序、Bash 通配符空格语义与 `:*` 等价写法、复合命令逐段匹配、wrapper 剥离名单、"规则由 Claude Code 执行不由模型执行"（官方，2026-08）
- [Hooks reference - Claude Code Docs](https://code.claude.com/docs/en/hooks) — PreToolUse 的 settings.json 结构、`matcher` / `if` / `timeout` 字段、退出码 2 与 `permissionDecision: deny` 两种拦截方式（官方，2026-08）
- [Claude Code settings](https://code.claude.com/docs/en/settings) — `attribution` 的 `commit` / `pr` / `sessionUrl` 三键、默认署名文本、`includeCoAuthoredBy` 已 deprecated 且优先级低于 `attribution`（官方，2026-08）
- [Git worktrees - Claude Code Docs](https://code.claude.com/docs/en/worktrees) — `--worktree` / `-w`、`.claude/worktrees/<name>/` 路径、`worktree-<name>` 分支名、加 `.gitignore` 的提示（官方，2026-08）
- [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices) — Explore→Plan→Implement→Commit 收尾；CLAUDE.md 该放 branch naming / PR conventions；`--allowedTools "Bash(git commit *)"`；checkpoint "not a replacement for git"（官方，2026-08）
- [Common workflows - Claude Code Docs](https://code.claude.com/docs/en/common-workflows) — "create a pr" / `gh pr create`；"Review Claude's generated PR before submitting"（官方，2026-08）
- [CLI reference - Claude Code Docs](https://code.claude.com/docs/en/cli-reference) — `--from-pr` 接受 PR 号与 GitHub / GitLab / Bitbucket URL；`--allowedTools` 是免确认而非限制可用工具（官方，2026-08）
- [Pull Request Process - kubernetes.dev](https://www.kubernetes.dev/docs/guide/pull-requests/) — 禁 AI commit message / AI 署名 / 大型 AI PR，要求披露，作者须能解释改动（官方项目政策，2026）
- [Trunk-Based Development with Short-Lived Branches - dev.to](https://dev.to/tacoda/trunk-based-development-with-short-lived-branches-5f74) — "agent writes code against the branch state"，分支应活几小时而非几天（社区，2026）
- [GitHub issue #4224 - anthropics/claude-code](https://github.com/anthropics/claude-code/issues/4224) — 旧署名开关偶发不生效（社区，2026）
- [Codex issue #9203 - openai/codex](https://github.com/openai/codex/issues/9203) — "把 `/undo` 还回来"，369 👍；触发场景是 AI 删了未跟踪文件、改了未 commit 的内容（社区，2026-01）
- [GitHub issue #33932 - anthropics/claude-code](https://github.com/anthropics/claude-code/issues/33932) — 要求 VS Code 插件提供逐文件 / 逐块 accept-reject 的 diff 审查界面，161 👍，截至 2026-08 仍 open（社区，2026-03）

> ⏰ 时效声明：本篇所有配置片段与命令行参数已于 **2026-08-03** 逐条对照官方文档核实——`permissions` 的 allow/ask/deny 语法与求值顺序、`hooks.PreToolUse` 的字段结构、`attribution` 的三个键、`--worktree` / `--from-pr` / `--allowedTools`。上一版依赖社区单源的两处（`includeCoAuthoredBy` 的弃用状态、`sessionUrl` 键）本次已在官方 settings 文档中找到出处，社区来源仅保留为佐证。"自 v2.0.62 起弃用"这个具体版本号官方未标注，本版已删除。配置键随版本迭代很快，动手前请以官方文档为准。

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
