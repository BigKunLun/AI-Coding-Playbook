# 001. Claude Code、Codex、Cursor、Copilot 到底该用哪个？按你的活儿选，不按测评选

> 难度：基础
> 主题：心智与工具
> 工具：Claude Code · 横向(ChatGPT / Cursor / Copilot)
> 题型：决策题 + 配置题

## TL;DR

Claude Code 是 Anthropic 出的 agentic coding tool。agentic 指它能自己规划、自己动手，而不是等你一步步下命令。它在你的终端里自主完成一整套动作：读改文件、跑命令、跑测试、操作 Git。它不是一个一问一答的聊天框。

记住三点。

第一，本质区别是"自主执行"对"对话"。ChatGPT 在浏览器的沙箱里回答你，碰不到你本地的代码。Claude Code 直接在你的项目目录里动手改。

第二，形态决定工作流。Claude Code 以命令行为主，也能装 VS Code、JetBrains 插件、桌面 App 和 Web 版。这些入口共享同一套 `CLAUDE.md`、settings 和 MCP 配置。相比之下，ChatGPT 是网页对话，Cursor 是内嵌在 IDE 里，Copilot 是从代码补全插件演进来的。

第三，新手"差点放弃"的根子在于心智错位。很多人用 ChatGPT 的方式来用 Claude Code：下一个指令、等一个答案、再复制粘贴。但 Claude Code 期待你把它当队友，让它主动干活。用错了方式，自然觉得它不好用。

**我到底该不该装？** 用这四条判据，中三条以上就值得装：

1. 你要改的是**本地已有仓库**，不是从零写一段孤立代码。
2. 这件事**要跨多个文件**，或者要边改边跑测试才能确认对不对。
3. 你的项目有**可跑的验证命令**（`npm test`、`pytest`、`go build` 之类），能让 agent 自己判断改对没有。
4. 你**接受用终端**，也愿意逐行审 diff 再合并。

反过来，如果你只是想问"这段代码什么意思""这个 API 怎么用"，ChatGPT 或 Cursor 的聊天框就够了，装 Claude Code 是杀鸡用牛刀。

## 为什么

### 1. 它的本质是自主执行，不是对话补全

官方文档一句话给它定了性：Claude Code 是一个 agentic coding tool，它读你的代码库、改文件、跑命令，并接入你的开发工具。原文是 "an agentic coding tool that reads your codebase, edits files, runs commands, and integrates with your development tools"（来源见下）。

关键在 agentic 这个词。它会自己规划步骤，自己调用工具（比如读文件、改文件、跑命令、搜索），看执行结果，再决定下一步。整个过程是一个闭环，不需要你把它吐出来的代码手动粘回去。

> Claude Code Docs: Overview（官方，2026-06）
> https://code.claude.com/docs/en/overview

这和 ChatGPT 的对话式补全有根本差别。

ChatGPT 的代码跑在浏览器或云端的沙箱里。它读不到、也改不了你本地的文件，更不能在你机器上跑命令。你问它答，然后你自己复制、粘贴、运行。执行的人是你。

Claude Code 跑在你本地的终端里。它能直接访问文件系统、直接执行命令。它自己读代码、自己改、自己跑测试看结果、自己修。执行的是它。

Cloudflare 的 Kenton Varda 在 Hacker News 上一句话点破了这个落差：Claude Code 几乎没有学习成本，你只要在代码目录里打开终端，用英语告诉它你想要什么就行。原文是 "Claude Code has zero learning curve. You just open the terminal app in your code directory and you tell it what you want, in English."（来源见下）。"在代码目录里打开终端"这个动作，ChatGPT 永远做不到。

> Hacker News 44163063（社区，2025-06）
> https://news.ycombinator.com/item?id=44163063

### 2. 形态不同，工作流就根本不同

Claude Code 官方明确说，它不是单一形态，而是一组共享同一引擎的入口：命令行、VS Code、JetBrains、桌面 App、Web。每个入口都连到同一个 Claude Code 引擎，所以你的 `CLAUDE.md`、settings、MCP servers 在所有入口通用（来源：Claude Code Docs: Overview，官方，2026-06，链接同上）。

这正是它和另外三个工具在产品形态上的本质差异：ChatGPT 是纯网页，Cursor 是一个 IDE 的分叉版本，Copilot 是一个 IDE 插件。

四类工具对照如下。

| 工具 | 形态 | 执行模式 | 文件系统 | 上下文怎么来 | 项目级规则文件 |
|------|------|---------|---------|-----------|-----------|
| **ChatGPT** | Web / App 对话 | 一问一答，沙箱执行 | ❌ 不能直接改本地 | 你手动粘贴 / 上传文件 | ❌ 无（只能靠自定义指令，跨项目共用） |
| **Cursor** | IDE 内嵌（VS Code 分叉版） | agent 模式，可多文件编辑并跑终端命令 | ✅ IDE 内 | 后台索引整个仓库 + `@文件/@符号` 手动指定 | ✅ `.cursor/rules/*.mdc`（或根目录 `AGENTS.md`），仅 Cursor 内生效 |
| **Copilot** | IDE 插件 + GitHub 云端（补全起家） | 补全 / agent mode / 云端 coding agent 三档并存 | ✅ IDE 内；云端 agent 在 GitHub 托管环境里改 | 打开的文件 + 仓库索引 | ✅ `.github/copilot-instructions.md` |
| **Claude Code** | **命令行原生** + 多入口 | **自主执行 + 工具链**（读写文件、跑命令、跑测试、操作 Git） | ✅ **终端直接** | 按需自己去读文件、grep、跑命令，不预先索引 | ✅ `CLAUDE.md`，命令行/IDE/桌面/Web 各入口共用 |

来源（均于 2026-08 复核）：Claude Code Docs: Overview（官方，链接同上）；GitHub Copilot 仓库级自定义指令（官方，https://docs.github.com/en/copilot/concepts/response-customization ）；Cursor Rules 文档（官方，https://cursor.com/docs/context/rules ）；SitePoint 的 2026 三方对比（社区，2026，https://www.sitepoint.com/claude-code-vs-cursor-vs-copilot-the-2026-developer-comparison/ ）。

"终端原生"不是一个小细节。Cursor 让你在编辑器里看改动对比，Copilot 让你在补全流里顺手用 agent。而 Claude Code 让你像指挥一个坐在旁边的工程师那样干活：它能在你的 shell 里跑任何命令、看任何文件、操作 Git。这就是为什么 HN 上有人说用它"像在和一位资深工程师结对"，原文是 "feels like pairing with a senior engineer"。

> Hacker News 44163063，MrDarcy 的评论（社区，2025-06）
> https://news.ycombinator.com/item?id=44163063

### 3. "新手差点放弃"的根子是用错了心智模型

社区里反复出现同一个现象：新手用 ChatGPT 的方式来用 Claude Code，结果差点放弃。

Reddit 的 r/ClaudeAI 有一篇帖子，标题就叫 "Claude Code Tips I Wish I Knew as a Beginner"。开篇作者直说他早期差点放弃，觉得全是炒作、没有真本事。原文是 "I almost gave up on it early on. Felt like it was all hype and no real edge."

> r/ClaudeAI 1m1ihia（社区，2025）
> https://www.reddit.com/r/ClaudeAI/comments/1m1ihia/claude_code_tips_i_wish_i_knew_as_a_beginner/

HN 上 matthewsinclair 的经历更典型。他走了一条从怀疑、上瘾、失望到转变的完整曲线。他说他一开始很怀疑，Claude Code 出来后完全被吸引，直到真去读那些代码，发现质量糟糕，于是又强烈反弹。后来某个点变了：他不再对它下命令，而是把它当成一只"虚拟橡皮鸭"来用，这带来了巨大差别；应当把它当协作者，或者说当一套需要牢牢控制的"机甲"。

> Hacker News 44163063，matthewsinclair 的评论（社区，2025-06）
> https://news.ycombinator.com/item?id=44163063
>
> 原文：「I started out very sceptical. When Claude Code landed, I got completely seduced... Then I actually read the code. It was shockingly bad. I swung back hard... Then something shifted. I stopped giving it orders and began using it more like a virtual rubber duck. That made a huge difference... treat it as a collaborator... or better yet, as a mech suit that needs firm control.」

根子在这里。ChatGPT 养成的习惯是：我给指令，它给答案，我来执行。开车的是人。Claude Code 期待的是：我给目标，它自己规划和执行，我来审查和把方向。开车的是它，人负责导航。两套心智一错位，新手就会觉得"它不如 ChatGPT 好用"，其实是把它当 ChatGPT 用了。

Phil Booth 从另一个角度佐证了这一点。他反对"把自动化调到最大、放任一群 agent 自主乱跑"的主流叙事，主张一种由 AI 开车、人来导航的结对编程模式。他说通常是模型开车、人导航，而且他会频繁按 `Esc` 打断 agent。原文是 "the LLM usually drives and the human usually navigates... I press `Esc` to interrupt the agent frequently"。这说明 agentic 不等于放任不管，而是"人导航、agent 执行"的协作。

> Agentic coding and mental models — Phil Booth（社区，2026-06-11）
> https://www.philbooth.me/blog/agentic-coding-and-mental-models
> ⚠️ 本轮该站点对自动抓取返回 403，未能实访复核。

## 怎么做

下面是一条 10 分钟能跑完、每步都有成功判据的上手路径。命令与预期输出均在 2026-08 依据官方 Quickstart / CLI reference 复核。

### 第 1 步：装（约 2 分钟）

```bash
# macOS / Linux / WSL
curl -fsSL https://claude.ai/install.sh | bash

# Windows PowerShell
irm https://claude.ai/install.ps1 | iex

# 或者 Homebrew（注意：brew 装的不会自动更新，要手动 brew upgrade claude-code）
brew install --cask claude-code

# 或者 Windows WinGet（同样不自动更新）
winget install Anthropic.ClaudeCode
```

**怎么判断做对了：**

```bash
claude --version
# 预期输出形如（版本号会变，关键是后面带 "(Claude Code)"）：
# 2.1.220 (Claude Code)
```

若提示 `command not found`，说明安装目录没进 `PATH`，重开一个终端窗口再试。

### 第 2 步：选登录方式（约 2 分钟）

这是最卡人的一步，先想清楚你走哪条路：

| 你的情况 | 选哪个 | 怎么登 |
|---------|-------|-------|
| 个人用，已有 Claude Pro / Max 订阅 | **订阅登录**（官方推荐，按订阅额度用，不再按 token 计费） | 直接跑 `claude`，浏览器完成授权 |
| 想按量付费、或要在 CI 里跑 | **Claude Console**（API 额度，预付费） | 同样跑 `claude` 选 Console 账号；首次登录会自动建一个 "Claude Code" workspace 便于对账 |
| 公司走云厂商 | **Bedrock / Google Cloud Agent Platform / Microsoft Foundry** | 按官方 third-party-integrations 文档配环境变量 |
| 公司自建网关 | **Claude apps gateway** | `/login` 会直接进 Cloud gateway 页，用公司 SSO 登 |

两个常见坑：

- 如果你已经设了 `ANTHROPIC_API_KEY` 环境变量，Claude Code **不会弹登录**，而是问你要不要用这个 key。想改用订阅登录，先 `unset ANTHROPIC_API_KEY` 再跑。
- 公司网络下浏览器回调打不开时，把终端里打印的授权 URL 手动复制到能上网的浏览器打开，再把回调里的 code 粘回终端。

登错了随时在会话里打 `/login` 换账号。

> 以上四种登录方式、Console 自动建 workspace、gateway 直接进 Cloud gateway 页，均出自官方 Quickstart 第 2 步（官方，2026-08 复核）
> https://code.claude.com/docs/en/quickstart

**怎么判断做对了：**

```bash
claude doctor
# 这是只读诊断，不开会话。预期能看到安装健康状况、
# settings 文件校验结果；有配置错误会逐条列出来。
```

### 第 3 步：在项目根目录启动（约 1 分钟）

```bash
cd /path/to/your-project   # 必须是有代码的 git 仓库，别在空目录或 home 目录启动
claude
```

**怎么判断做对了：** 提示符上方应显示版本号、当前模型和工作目录，且工作目录就是你的项目根目录。进去后打一句：

```text
> /context
```

`/context` 把当前上下文占用画成一张彩色格子图，并列出各项来源。预期能在里面看到 `CLAUDE.md`（有这个文件的话）等已加载的记忆内容——这就是"它认识你项目了"的证据。另外 `/status` 可以查当前账号和模型。

如果启动时显示的工作目录不对，退出重新 `cd` 再启动——目录错了，后面全都白干。

### 第 4 步：给目标，不给步骤（约 3 分钟）

```text
> 给 src/api/handlers/payment.ts 加输入校验，金额必须是正整数，
  参考 src/api/handlers/user.ts 里 validateUserInput 的写法。
  改完跑 npm test 确认没挂。
```

而不是"打开文件、找到第 42 行、加个 if"。目标 + 参考 + 验证方式三件套齐了，agent 才能自己闭环。

**怎么判断做对了：** 它应该先去读那两个文件，再改，再自己跑 `npm test`，最后把 diff 摊给你看，而不是直接甩一段代码让你复制。

### 第 5 步：审 diff 再决定（约 2 分钟）

Claude Code 改完会展示改动对比，你逐行看。看到跑偏就按 `Esc` 打断、重新说清楚方向——Phil Booth 的做法就是频繁打断（见前文）。最终合并进 main 的代码责任在你，不在它。

顺带调好预期：agent 会跑偏、会卡住、会产出要大改的代码。tptacek 在《My AI skeptic friends are all nuts》里描述的异步用法就是如此：一批产出里，有的推翻重来，有的像给初级开发者反馈那样改，有的直接合并。只有一部分能直接合并是常态，不必怕让它试。

> fly.io: youre-all-nuts（社区，2025-06）
> https://fly.io/blog/youre-all-nuts/

### 可选：想要 IDE 体验就装插件

喜欢在编辑器里看行内改动的，装 Claude Code 的 VS Code / JetBrains 扩展（VS Code 里 `Cmd+Shift+X` 搜 "Claude Code"）。它和命令行共享同一套 `CLAUDE.md`、settings 和 MCP 配置，不用重配一遍。

## Claude Code 实战

### 起步：第一次会话长什么样

```bash
# 1. 进项目目录启动
cd ~/my-project
claude

# 2. 用自然语言给目标（不是步骤）
> 给 src/api/handlers/payment.ts 加输入校验，金额必须是正整数，
  参考 src/api/handlers/user.ts 里 validateUserInput 的写法。
  改完跑一下 npm test 看有没有挂。

# 3. Claude Code 会自己：读两个文件 → 规划 → 改 payment.ts
#    → 跑 npm test → 看结果 → 如果挂了自己修 → 再跑
#    → 最后给你看 diff，你决定接不接受
```

关键在于：你给的是目标、参考和验证方式，不是操作步骤。这就是自主执行和对话式的分水岭。

### `/init`：冷启动 CLAUDE.md

```bash
claude
> /init
```

`/init` 会扫描你的项目，生成一份 `CLAUDE.md` 草稿，包含技术栈、构建命令、目录结构和约定。但别盲信自动生成的内容，社区强烈建议逐行手工打磨（详见 [#010 CLAUDE.md 怎么写才真的生效](../02-context-engineering/010-claude-md-how-to-make-it-work.md)）。在 001 这里你只需要知道：`CLAUDE.md` 是 Claude Code 在所有入口自动加载的持久指令文件，是它"认识你项目"的入口。

### `claude -p`：非交互模式

```bash
# 非交互式，适合脚本 / CI
claude -p "找出 auth.py 里的 bug 并修复" \
  --allowed-tools "Read" "Edit" "Bash(pytest *)"
```

`-p`（等价于 `--print`）让 Claude Code 跑完就退出，适合塞进 CI/CD 流水线或 shell 脚本。

关于 flag 写法，两个容易踩的点（2026-08 依据官方 CLI reference 复核）：

- **`--allowed-tools` 和 `--allowedTools` 两种拼法官方都接受**，不用纠结。网上老文章里的 `--allowedTools` 现在照样能跑。
- **逗号分隔和空格分隔两种写法官方都接受**。`claude --help` 里这个 flag 的原文就是 "Comma or space-separated list of tool names to allow"，所以 `--allowed-tools "Read,Edit,Bash"` 和 `--allowed-tools "Read" "Edit" "Bash"` 都能跑。但推荐用空格分隔：括号里可以写 `Bash(pytest *)` 这类含空格的命令模式，做到"只允许跑 pytest，不允许跑别的 Bash 命令"，这种模式塞进逗号串里容易读错。

如果你不想逐个列工具，改用 `--permission-mode`，取值有 `default`、`acceptEdits`、`plan`、`auto`、`dontAsk`、`bypassPermissions`，以及 `manual`（`default` 的别名，需 v2.1.200 以上）。CI 里常用 `acceptEdits`；`bypassPermissions` 跳过所有确认，只在隔离容器里用。

**怎么判断做对了：** 先拿一条无副作用的命令试跑，确认权限配置生效而不是被静默拦下：

```bash
claude -p "用一句话说明 README.md 讲的是什么" --allowed-tools "Read"
# 预期：直接输出一句话摘要，退出码 0（echo $? 应为 0）。
# 如果输出的是"我没有权限读取文件"之类的说明，说明 --allowed-tools 没写对。
```

### 一张能力地图

Claude Code 能做的事远不止改代码。它能管理上下文与记忆（`CLAUDE.md` 和自动记忆），能跑"规划、执行、审查"的循环，能派子 agent 隔离上下文，能用 skill 复用工作流。这些是 004 的地盘，这里不展开。001 只给你一句话地图：它是一个能读、能写、能跑命令、能规划、能协作的工程师队友，不是一个聊天机器人。

## 横向对比

| 工具 | 解法 | 差异 |
|------|------|------|
| **ChatGPT** | Web 对话，沙箱跑代码，**不能改你本地文件** | 适合学习、查 API、要解释。不适合直接改项目代码，你得手动复制粘贴，执行的人是你。 |
| **Cursor** | IDE 内嵌 AI，agent 模式可多文件编辑，看行内改动 | 适合喜欢"在编辑器里看改动"的人。自主性弱于 Claude Code，更像一个聪明的结对伙伴。来源：SitePoint 2026 对比（社区，链接同上）。 |
| **Copilot** | 三档并存：行内补全 / IDE 内 agent mode / GitHub 云端 coding agent（可自主规划、执行、开 PR，2025-09 正式发布） | 适合已深度用 GitHub 生态的团队。云端 agent 的自主度已经不低，但主入口仍是 IDE 插件与 GitHub 网页，不在你本地终端里。来源：GitHub Blog 的 Agent Mode 101（官方，2025-05，https://github.blog/ai-and-ml/github-copilot/agent-mode-101-all-about-github-copilots-powerful-mode/ ）。 |
| **Claude Code** | **命令行原生的自主执行**，终端直接跑命令、改文件、操作 Git，多入口共享配置 | 适合愿意用终端、想让 AI 在项目里直接动手的人。自主性最高，但需要你当导航者来审查。 |

一个共同趋势：所有主流工具都在从"补全或对话"走向"agent 自主执行"。Cursor 的 agent 模式、Copilot 的 coding agent、Claude Code 本身，本质都是把模型放进一个"调用工具、拿反馈验证"的闭环里。差别只在两点：入口形态（终端、IDE 还是网页）和自主程度。Claude Code 选的是"终端原生 + 最高自主性"这条路。

## 反模式

**把 Claude Code 当 ChatGPT 用。** 一问一答、等它给完整代码、自己复制粘贴，这样你完全没用到它的自主能力，还会嫌它"不如 ChatGPT 快"。根子是心智模型错位，参见前面的论断 3。

**放任 agent 跑不管。** agent 产出的代码你不审查就合并，最后攒成一堆没人看得懂的乱麻——本质是技术债，只是攒得比人手写快得多。matthewsinclair 的原话是他真去读那些代码时发现"质量糟糕"（原文 "It was shockingly bad."），而转变发生在他不再下命令、开始把它当协作者之后。Phil Booth 的做法是频繁按 `Esc` 打断。你是导航者，不是甩手掌柜。

> Hacker News 44163063，matthewsinclair 的评论（社区，2025-06）
> https://news.ycombinator.com/item?id=44163063

**在空目录或 home 目录启动。** Claude Code 需要项目上下文（代码、CLAUDE.md、git 状态）才能干活。空目录启动等于让一个工程师在白纸上凭空写，必然跑偏。

**给步骤而不是给目标。** "打开文件、找到第几行、改成什么"是在浪费 agent 的规划能力。应该说"加输入校验，参考某处的写法，跑测试验证"。

**期望它每次都成功。** agent 会卡住、会产出垃圾代码。tptacek 的异步实践里，一批产出只有一部分能直接合并，其余要么推翻重来，要么按初级开发者的标准反馈重写。失败成本低，让它试、你审查、不行就重来。

> fly.io: youre-all-nuts（社区，2025-06）
> https://fly.io/blog/youre-all-nuts/

**因为它写过一坨烂代码就全盘否定。** matthewsinclair 那条"上瘾、失望、转变"的曲线是典型路径。在失望期别放弃，把心智从"下命令"调成"协作"，通常就过去了。

## 延伸

**交叉引用：**
- [#010 CLAUDE.md 怎么写才真的生效？](../02-context-engineering/010-claude-md-how-to-make-it-work.md) —— `/init` 生成的草稿怎么手工打磨
- [#011 Context Engineering 和 Prompt Engineering 到底什么区别？](../02-context-engineering/011-context-vs-prompt-engineering.md) —— 为什么给 agent 目标比给指令更高效
- [#030 TDD 在 AI coding 里怎么做？](../04-execution-workflow/030-tdd-in-ai-coding.md) —— 怎么让 agent 自己跑测试验证
- [#031 plan → execute → review 的正确循环怎么做？](../04-execution-workflow/031-plan-execute-review-loop.md) —— 导航者和开车者协作的标准节奏

**参考资料：**
- [Claude Code Docs: Overview](https://code.claude.com/docs/en/overview) —— 官方产品定位权威源，明确"agentic coding tool"定性与多入口架构（官方，访问日期 2026-06）
- [My AI skeptic friends are all nuts — Hacker News 44163063](https://news.ycombinator.com/item?id=44163063) —— 2826 条社区大讨论，kentonv、matthewsinclair 等多人实测经历（社区，2025-06）
- [My AI skeptic friends are all nuts — fly.io（原文）](https://fly.io/blog/youre-all-nuts/) —— tptacek 原文：责任在合并的人、一批产出只有一部分可合并（社区，2025-06）
- [Agentic coding and mental models — Phil Booth](https://www.philbooth.me/blog/agentic-coding-and-mental-models) —— 开车者与导航者的结对实践，反对盲目放权（社区，2026-06）⚠️ 站点对自动抓取返回 403，本轮未能实访复核
- [Claude Code Tips I Wish I Knew as a Beginner — r/ClaudeAI 1m1ihia](https://www.reddit.com/r/ClaudeAI/comments/1m1ihia/claude_code_tips_i_wish_i_knew_as_a_beginner/) —— 新手"差点放弃"的根因与转变（社区，2025）⚠️ Reddit 反爬严重，已通过多次搜索交叉确认其存在
- [Claude Code vs Cursor vs Copilot: 2026 Developer Comparison — SitePoint](https://www.sitepoint.com/claude-code-vs-cursor-vs-copilot-the-2026-developer-comparison/) —— 横向的形态与自主性对比（社区，2026）
- [Agent Mode 101 — GitHub Blog](https://github.blog/ai-and-ml/github-copilot/agent-mode-101-all-about-github-copilots-powerful-mode/) —— Copilot 从补全到 agent 的官方表述（官方，2025-05-22，访问日期 2026-07）
- [Claude Code Docs: Quickstart](https://code.claude.com/docs/en/quickstart) —— 安装命令、登录方式选择、`claude --version` 验证（官方，访问日期 2026-08）
- [Claude Code Docs: CLI reference](https://code.claude.com/docs/en/cli-reference) —— `--allowed-tools` / `--permission-mode` / `claude doctor` 的现行写法（官方，访问日期 2026-08）
- [GitHub Copilot: 自定义响应](https://docs.github.com/en/copilot/concepts/response-customization) —— `.github/copilot-instructions.md` 的官方说明（官方，访问日期 2026-08）
- [Cursor Docs: Rules](https://cursor.com/docs/context/rules) —— `.cursor/rules/*.mdc` 与 `AGENTS.md` 的官方说明（官方，访问日期 2026-08）

**⏰ 时效声明（2026-08）：**

- 两个核心论断——Claude Code 是"自主执行"而非"对话"、多个入口共享同一套配置——依据官方 Overview 文档，2026-08 复核仍成立。
- 「怎么做」里的安装命令、登录方式、`claude --version` / `claude doctor` / `/context` 以及 `--allowed-tools`、`--permission-mode` 取值，均在 2026-08 依据官方 Quickstart 与 CLI reference 复核；`--version` 的实测输出取自本地 v2.1.220。CLI flag 会随版本变化，报错时以 `claude --help` 为准。
- 四工具对比表是定性描述，各产品演进快，具体特性以各自官方文档为准。
- 心智错位相关的论断依赖社区经验帖，其中 Reddit 帖反爬、Phil Booth 站点对自动抓取返回 403，本轮未能实访逐字复核，已在引用处标注；这部分请当作他人经验参考，而非官方结论。

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
