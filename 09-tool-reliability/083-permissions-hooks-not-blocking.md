# 083. 我配了 deny 规则，它照样删了我的东西——permissions / hooks 怎么配才真拦得住？

> 难度：中级
> 主题：工具可靠性与供应商风险
> 工具：Claude Code · 横向(Cursor / Copilot / …)
> 题型：排错题

## TL;DR

`permissions.deny` 里明明写了 `Bash(rm *)`，AI 还是把目录删了。绝大多数情况不是权限系统坏了，是**你的规则根本没匹配上那条实际执行的命令**。

30 秒结论，按这个顺序查：

1. **先看真实命令字符串**。权限规则是拿你写的模式去匹配 Claude 实际发出的**字面命令串**，不是理解语义。`rm -rf tmp` 匹配 `Bash(rm *)`，但 `/bin/rm -rf tmp`、`devbox run rm -rf .`、`find . -delete`、`python cleanup.py` 都不匹配。跑 `claude --verbose` 看它到底发了什么（[CC Docs: permissions](https://code.claude.com/docs/en/permissions)，官方，2026-08）。
2. **再看通配符的空格边界**。`Bash(ls *)` 匹配 `ls -la` 但不匹配 `lsof`；`Bash(ls*)` 两个都匹配。`:*` 只在模式**结尾**才被识别为通配，写在中间（`Bash(git:* push)`）里的冒号是字面字符。
3. **不可逆的动作不要只靠 deny 规则，要用 PreToolUse hook**。官方原文：hook 以 exit code 2 退出会**在权限规则被评估之前**就中止这次工具调用，所以即便有 allow 规则也拦得住（[CC Docs: permissions](https://code.claude.com/docs/en/permissions)，官方，2026-08）。
4. **真要保证「进程级别删不掉」，得上 sandbox**。deny 规则拦的是 Claude 的工具调用；`sandbox` 是操作系统层（macOS Seatbelt / Linux bubblewrap）限制，对所有子进程生效——一个 Python 脚本自己 `os.remove()`，只有 sandbox 拦得住（[CC Docs: sandboxing](https://code.claude.com/docs/en/sandboxing)，官方，2026-08）。

一句话记法：**deny 规则防手滑，hook 防特定危险动作，sandbox 防「命令干的事比名字多」。三层是叠加的，不是三选一。**

git 层的具体禁令清单见 [#052 怎么不让 AI 把 git 仓库搞乱？](../06-engineering-collab/052-git-workflow-with-ai.md)，本篇讲权限系统本身怎么配、以及它已知的失灵模式。

## 为什么

### 1. 权限规则匹配的是字符串，不是意图

这是所有「deny 没生效」问题的总根源。官方文档把 Bash 规则的匹配方式讲得很直白：`Bash(npm run test *)` 匹配「以 `npm run test ` 开头的命令」，`*` 可以出现在任意位置并跨多个参数。它没有做任何「这条命令语义上是不是在删文件」的判断。

于是同一个「删除」动作有无数种写法能绕开你的 `Bash(rm *)`：

| 实际命令 | `Bash(rm *)` 拦得住吗 | 为什么 |
|---|---|---|
| `rm -rf tmp/` | ✅ | 字面前缀匹配 |
| `FOO=bar rm -rf tmp/` | ✅ | deny/ask 规则会跨过任意前导环境变量赋值匹配 |
| `/bin/rm -rf tmp/` | ❌ | 字面串以 `/bin/rm` 开头，不匹配 `rm ` |
| `find . -name '*.log' -delete` | ❌ | 压根不是 `rm` |
| `devbox run rm -rf .` | ❌ | `devbox`、`npx`、`docker exec` 这类「环境运行器」**不在**内置的 wrapper 剥离列表里 |
| `python cleanup.py` | ❌ | 删除发生在子进程内部，权限系统看不见 |

第三行到第六行不是猜的，官方文档逐条写了：内置剥离的 wrapper 只有 `timeout`、`time`、`nice`、`nohup`、`stdbuf`、`command`、`builtin`、`noglob` 和无参数的 `xargs`，「这个 wrapper 列表是内置的、不可配置」；而 `devbox run`、`mise exec`、`npx`、`docker exec` 明确不在其中，所以 `Bash(devbox run *)` 这种 allow 规则「会匹配 `run` 后面的任何东西，包括 `devbox run rm -rf .`」。

Read / Edit 的 deny 规则也有同样的边界，官方带 Warning 标注：

> "Read and Edit deny rules apply to Claude's built-in file tools and to file commands Claude Code recognizes in Bash, such as `cat`, `head`, `tail`, and `sed`. They don't apply to arbitrary subprocesses that read or write files indirectly, like a Python or Node script that opens files itself."
> Read 和 Edit 的 deny 规则作用于 Claude 的内置文件工具，以及 Claude Code 能识别的 Bash 文件命令（`cat`/`head`/`tail`/`sed` 这类）。它们**不作用于**间接读写文件的任意子进程，比如自己打开文件的 Python 或 Node 脚本。
> — [CC Docs: permissions](https://code.claude.com/docs/en/permissions)（官方，2026-08）

### 2. 复合命令的处理，是这类问题里变化最频繁的地方

按当前文档，Claude Code 是**认识 shell 操作符**的：`&&`、`||`、`;`、`|`、`|&`、`&` 和换行都算分隔符，「一条规则必须独立匹配每个子命令」，所以 `Bash(safe-cmd *)` 不会让 `safe-cmd && other-cmd` 通过。这个方向是对的——deny 侧因此不容易被复合命令绕开。

但工程实现上这块反复出过问题，社区两个高热贴都指向它：

- [GH #16561](https://github.com/anthropics/claude-code/issues/16561)（feature request，标签 `area:security` / `has repro`）：早期版本把复合命令当**单个字符串**去匹配，导致 `cd /path && git status` 在 `Bash(cd:*)` 和 `Bash(git:*)` 都已 allow 的情况下仍然弹窗。
- [GH #28240](https://github.com/anthropics/claude-code/issues/28240)（2026-02 报告，标签 `bug` / `regression` / `area:permissions`，v2.1.52 起复现，截至 2026-08 仍 open）：反过来的 bug——`cd /some/path && git add x && git commit -m "msg"` 弹出的授权项是 `cd:*`，而不是真正需要判断的 `git add` / `git commit`，而且那个 `cd:*` 还没法加进会话白名单。

这两个 issue 合起来说明一件事：**别把「复合命令里每一段都会被正确识别」当成稳定假设去设计你的安全策略**。你的 deny 规则要能扛住实现细节变动，最稳的做法是把关键防线放到 hook 里（下一节）。

### 3. 还有一类：命令确实被拦了，但「同意」不是你点的

[GH #73125](https://github.com/anthropics/claude-code/issues/73125)（387 👍 / 143 评论，本轮相关议题里热度最高）报的是 v2.1.198 的行为：`AskUserQuestion` 在 60 秒无人应答后会自动返回「用户可能不在电脑前，请按你的判断继续」然后往下跑。而很多人正是拿 `AskUserQuestion` 当危险操作前的人工确认闸。

这个 issue 已经关闭，assignee 的说法是在 v2.100 改成不再默认开启、超时窗口在 `/config` 里可配。补充信息：该超时只在终端**没有焦点**时触发，按任意键即可取消倒计时。

留下的通用教训比这个具体 bug 重要：**任何依赖「人一定会看到弹窗并做选择」的护栏，都不是护栏**。真正不可逆的动作，要做成默认拒绝、显式放行，而不是默认询问。

## 怎么做

### 第一步：先确认规则到底有没有匹配上（排查，别急着改配置）

```bash
# 1. 看当前会话实际生效的规则和它们来自哪个文件
/permissions

# 2. 用 --verbose 启动，看 Claude 每次工具调用发出的确切参数字符串
claude --verbose
```

**怎么判断做对了**：`--verbose` 输出里能看到 Bash 工具的 `command` 原文。把这个原文和你的模式手工比一遍——十有八九你会发现它是 `cd apps/api && rm -rf dist`、`npx rimraf dist` 这类，跟你写的 `Bash(rm *)` 对不上。

还要确认规则在正确的文件里。权限规则的特殊之处是它**跨作用域合并而不是覆盖**（官方原文："Permission rules behave differently because they merge across scopes rather than override."），且「任何一层 deny 了，其他层都不能再 allow」。所以 deny 写在哪一层都会生效，写不生效通常是文件路径或 JSON 写错了——`/permissions` 里看不到它就是没加载。

### 第二步：修规则写法（覆盖真实变体）

`~/.claude/settings.json`：

```json
{
  "permissions": {
    "deny": [
      "Bash(rm *)",
      "Bash(/bin/rm *)",
      "Bash(/usr/bin/rm *)",
      "Bash(sudo *)",
      "Bash(* --force *)",
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)",
      "Edit(./.env*)"
    ],
    "ask": [
      "Bash(git push *)",
      "Bash(docker *)",
      "Bash(npx *)"
    ]
  }
}
```

几个写法要点，都对应上面踩过的坑：

- `*` 前有空格（`Bash(rm *)`）会强制词边界，只匹配 `rm ` 开头或 `rm` 本身；没空格（`Bash(rm*)`）会连 `rmdir` 一起匹配。想收严还是放宽，按这个来选。
- 全路径变体（`/bin/rm`、`/usr/bin/rm`）要单独写，前缀不同不会自动覆盖。
- 环境运行器（`npx` / `devbox run` / `docker exec`）不要用宽泛 allow，放进 `ask` 或者对具体内层命令写精确规则，比如 `Bash(devbox run npm test)`。
- Write / NotebookEdit / Glob 上写路径规则是**无效的**：Claude Code 只按 `Edit(path)` 和 `Read(path)` 做文件权限检查，写成 `Write(docs/**)` 会被接受但永不生效，v2.1.210 起启动时会给警告（官方文档，2026-08）。

**怎么判断做对了**：改完重启会话，在 Claude Code 里直接让它执行一条你期望被拦的命令（比如「运行 `/bin/rm -rf ./tmp-test`」）。看到明确的拒绝提示才算过；只是弹窗询问，说明落到了 `ask` 而不是 `deny`。

### 第三步：真正不可逆的动作，放进 PreToolUse hook

这是 deny 规则之上更硬的一层。官方原文：

> "A hook that exits with code 2 stops the tool call before permission rules are evaluated, so the block applies even when an allow rule would otherwise let the call proceed."
> exit code 2 的 hook 会在权限规则被评估之前中止这次工具调用，所以即使有 allow 规则本来会放行，这个拦截依然生效。
> — [CC Docs: permissions](https://code.claude.com/docs/en/permissions)（官方，2026-08）

而且 PreToolUse hook 对**除 `EndConversation` 之外的每一次工具调用**都会触发，不受权限模式影响。

`.claude/settings.json`：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/guard.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

`.claude/hooks/guard.sh`（记得 `chmod +x`）：

```bash
#!/usr/bin/env bash
# 从 stdin 读 hook 输入，取出这次要执行的命令原文
CMD=$(jq -r '.tool_input.command // ""')

# 用正则覆盖变体：rm / rmdir，含全路径，含拆开写的 -r -f
if printf '%s' "$CMD" | grep -Eq '(^|[[:space:]/])rm(dir)?([[:space:]]|$)'; then
  echo "guard: 拦截删除类命令 -> $CMD" >&2
  exit 2   # 关键：必须是 2。exit 1 是非阻塞的，不会拦下来
fi

# 数据库 / 生产环境这类你自己的红线，一并写在这里
if printf '%s' "$CMD" | grep -Eq 'drop (table|database)|kubectl .*(delete|prod)'; then
  echo "guard: 拦截高危运维命令 -> $CMD" >&2
  exit 2
fi

exit 0   # 不表态，交回正常权限流程
```

退出码语义（官方文档）：`0` = 成功，Claude Code 解析 stdout 里的 JSON；`2` = **阻断**，stderr 内容作为错误反馈给 Claude；其他值 = 非阻断错误，只提示、继续执行。**特别注意 `exit 1` 不阻断**——这是自己写 hook 时最常见的错。

如果你想给出结构化理由而不是硬阻断，也可以 exit 0 并输出 JSON：

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "删除类命令必须由人手工执行"
  }
}
```

`permissionDecision` 取值：`allow` / `deny` / `ask` / `defer`（defer = 交回正常权限流程）。但要清楚区别：**JSON 形式的 `allow` 不能越过 deny 规则**（「Hook decisions don't bypass permission rules」），只有 exit 2 具备「先于权限规则」的优先级。所以硬防线用 exit 2。

还可以用 `if` 字段做更细的预过滤，减少 hook 被调起的次数：

```json
{ "type": "command", "if": "Bash(rm *)", "command": "/path/to/guard.sh" }
```

按文档，`if` 用的是权限规则语法，且会拆开子命令和命令替换来检查——`Bash(rm *)` 对 `echo $(rm -rf /)` 也会命中。

**怎么判断做对了**：

```bash
# 1. 单独测脚本，不经过 Claude Code
echo '{"tool_input":{"command":"/bin/rm -rf ./x"}}' | .claude/hooks/guard.sh; echo "exit=$?"
# 期望：stderr 打出拦截信息，exit=2

echo '{"tool_input":{"command":"npm test"}}' | .claude/hooks/guard.sh; echo "exit=$?"
# 期望：无输出，exit=0

# 2. 在会话里用 /hooks 确认 hook 已被加载
/hooks
```

两条都对上，再去会话里让 Claude 实际试一条危险命令收尾。

### 第四步：需要「进程级别真的做不到」时，开 sandbox

hook 和 deny 规则都停在「Claude 发出的命令串」这一层。一旦命令跑起来、它干的事比名字多（`npm run build` 里藏了删除、脚本自己 `os.remove()`），只有操作系统层拦得住。

```bash
/sandbox    # 在会话里打开面板，选模式；配置会写进 .claude/settings.local.json
```

全局开启，`~/.claude/settings.json`：

```json
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["~/.kube"]
    },
    "credentials": {
      "files": [
        { "path": "~/.aws/credentials", "mode": "deny" },
        { "path": "~/.ssh", "mode": "deny" }
      ],
      "envVars": [
        { "name": "GITHUB_TOKEN", "mode": "deny" }
      ]
    }
  }
}
```

几个必须知道的事实（都出自官方 sandboxing 文档，2026-08）：

- 默认写入范围只有**当前工作目录 + 会话临时目录**；默认**读**范围是整台机器（`~/.aws/credentials`、`~/.ssh` 默认仍可读），所以 `credentials` 那段不是可选项。
- 平台：macOS 用 Seatbelt，开箱即用；Linux / WSL2 需要 `bubblewrap` 和 `socat`（`sudo apt-get install bubblewrap socat`）；**原生 Windows 不支持**。
- 默认行为是「沙箱起不来就带个警告继续裸跑」。要让它硬失败，设 `"failIfUnavailable": true`。
- 沙箱会自动禁止写入各层 `settings.json`，所以沙箱内的命令改不了自己的策略。
- 它不是完整隔离边界。官方明确列了限制：默认不解密 TLS，允许 `github.com` 这类宽泛域名可能被用来外传数据。

**怎么判断做对了**：开启后让 Claude 执行 `touch ~/sandbox-test-file`。应当失败（写入工作目录之外）。再执行 `cat ~/.aws/credentials`，配了 `credentials.deny` 后应当读不到。

### 第五步：团队场景，把口子用 managed settings 焊死

个人配置有个天然漏洞：开发者自己可以改。企业侧对应的是 managed settings（优先级最高，「can't be overridden by any other level, including command line arguments」）。

```json
{
  "permissions": {
    "deny": ["Bash(rm *)", "Bash(sudo *)"],
    "disableBypassPermissionsMode": "disable",
    "allowManagedPermissionRulesOnly": true
  },
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "allowUnsandboxedCommands": false
  }
}
```

- `disableBypassPermissionsMode: "disable"` 禁掉 `--dangerously-skip-permissions`；`disableAutoMode` 同理禁 auto 模式。
- `allowManagedPermissionRulesOnly: true` 让用户和项目设置里的 allow/ask/deny 全部失效，只认 managed 的规则。
- `allowUnsandboxedCommands: false` 关掉「命令在沙箱里失败后重试到沙箱外」的逃生口。

注意一个仍存在的口子：`sandbox.excludedCommands` 是数组、跨作用域合并，官方明说「没有对应的 managed-only 锁定，开发者总能追加条目让额外命令跑在沙箱外」。所以 managed 的 `excludedCommands` 要尽量短。

**怎么判断做对了**：在受管机器上执行 `claude --dangerously-skip-permissions`，应当被拒绝启动。

### 版本相关的具体行为（信息日期 2026-08，最易过期，请以你实际版本为准）

上面四步是排查和加固的通用方法，下面这些是特定版本的行为，**先按上面查，再来对版本**：

| 行为 | 版本 | 说明 |
|---|---|---|
| `rm -rf /` / `rm -rf ~` 的内置熔断 | v2.1.208 起 | 即便在 bypassPermissions 模式也会弹窗；v2.1.208 起还覆盖 `$(...)`、反引号、`<(...)` 里的形式。之前只有裸写的那一种会弹 |
| Read deny 规则连带拦住 Edit（含新建文件） | v2.1.208 起 | Write / NotebookEdit 不在覆盖内，要单独写 Edit deny |
| 对 Write/Glob 写路径规则会在启动时告警 | v2.1.210 起 | 之前是静默无效 |
| `AskUserQuestion` 60 秒自动继续 | v2.1.198 出现，v2.100 改为默认关闭、`/config` 可配 | 见 [GH #73125](https://github.com/anthropics/claude-code/issues/73125) |
| 复合命令授权项显示成 `cd:*` | v2.1.52 起复现，截至 2026-08 仍 open | 见 [GH #28240](https://github.com/anthropics/claude-code/issues/28240)，暂无官方 workaround；规避办法是让 Claude 不用 `cd &&` 拼接，改用绝对路径 |
| 沙箱关闭文件系统隔离（`filesystem.disabled`） | v2.1.216 起 | 会同时失去 `denyRead` 和 `credentials.files` 保护 |

## Claude Code 实战

一套「个人机器上够用」的最小组合，三个文件，五分钟配完：

```bash
# 1. 全局 deny + sandbox（跟着你走，不依赖某个项目）
$EDITOR ~/.claude/settings.json

# 2. 项目级 hook 注册
mkdir -p .claude/hooks && $EDITOR .claude/settings.json

# 3. 硬防线脚本
$EDITOR .claude/hooks/guard.sh && chmod +x .claude/hooks/guard.sh

# 4. 三项验证，缺一不可
echo '{"tool_input":{"command":"/bin/rm -rf ./x"}}' | .claude/hooks/guard.sh; echo "exit=$?"   # 期望 2
claude --verbose        # 会话里让它执行一条危险命令，看是否被拦
# 会话内：/permissions 确认规则来源，/hooks 确认 hook 已加载，/sandbox 确认沙箱状态
```

一条实用的建议来自官方文档本身：如果你的目标是「大部分 Bash 命令不弹窗，但少数几条必须拦死」，正确姿势不是写一长串 deny，而是——把 `"Bash"` 放进 allow 列表，然后注册一个 PreToolUse hook 专门拒绝那几条。因为 exit 2 优先于 allow 规则，这个组合既省心又拦得住。

日常还要养成的习惯：AI 一旦在做 `find -exec`、`xargs`、`npx`、`docker exec` 这类「命令套命令」的操作，就手工看一眼实际展开成了什么。这几类是权限系统覆盖最薄的地方。

## 反模式

- ❌ **把红线写进 `CLAUDE.md` 就当配好了** —— 官方原文：「Permission rules are enforced by Claude Code, not by the model. Instructions in your prompt or `CLAUDE.md` shape what Claude tries to do, but they don't change what Claude Code allows.」prompt 只影响它想干什么，不改变系统允许什么。
- ❌ **hook 里写 `exit 1` 表示拒绝** —— 1 是非阻断错误码，只会显示一条 hook 报错然后继续执行。必须是 `exit 2`。
- ❌ **hook 返回 `permissionDecision: "allow"` 就以为能免掉弹窗** —— deny 规则照样拦，ask 规则照样弹。只有 exit 2 拥有先于权限规则的优先级。
- ❌ **为图省事临时 allow `Bash(*)`** —— 它会让下面所有基于弹窗的判断形同虚设，而且「临时」通常会留到永远。
- ❌ **在容器/VM 外面用 `--dangerously-skip-permissions`** —— 该模式下连 `.git`、`.claude`、`.vscode`、`.husky` 的写入都不再询问，只有显式 ask 规则和根目录/家目录删除的熔断还会拦。
- ❌ **配完不验证** —— 权限配置属于「不触发就不知道错了」的一类，写完必须主动跑一条危险命令验收；等真出事再发现规则没匹配上，代价就是这篇文章的标题。
- ❌ **只加固个人 settings 却不管团队** —— 项目 `.claude/settings.json` 的 allow 规则受 workspace trust 约束，但开发者自己的 `settings.local.json` 不受，团队红线必须走 managed settings。

## 延伸

**交叉引用：**
- [#052 怎么不让 AI 把 git 仓库搞乱？（禁掉 force push / reset --hard，去掉 Co-Authored-By 署名）](../06-engineering-collab/052-git-workflow-with-ai.md) —— git 层的具体禁令清单，本篇是它依赖的权限系统底座
- [#072 AI coding 的安全红线怎么画？密钥泄露、数据外泄、第三方上传的真实事故与防护](../08-team-and-org/072-ai-coding-security-red-lines.md) —— 密钥与数据外泄侧的红线，与本篇的 sandbox credentials 配置互补
- [#075 团队的 AI coding 规范怎么立？哪些该强制、哪些该自由？](../08-team-and-org/075-team-ai-coding-standards.md) —— managed settings 属于「该强制」的那一类，规范怎么定见这篇

**参考资料：**
- [Claude Code Docs: Configure permissions](https://code.claude.com/docs/en/permissions) — Bash 通配符语义、复合命令、wrapper 剥离列表、deny 优先级、hook 与权限规则的关系（官方，2026-08）
- [Claude Code Docs: Hooks reference](https://code.claude.com/docs/en/hooks) — PreToolUse 的输入 JSON、退出码语义、`permissionDecision` 取值、`if` 字段（官方，2026-08）
- [Claude Code Docs: Configure the sandboxed Bash tool](https://code.claude.com/docs/en/sandboxing) — sandbox 开启方式、默认读写边界、credentials 保护、平台支持与安全限制（官方，2026-08）
- [Claude Code Docs: Settings](https://code.claude.com/docs/en/settings) — settings 文件优先级、权限规则跨作用域合并、`allowManagedPermissionRulesOnly`（官方，2026-08）
- [GH #28240 Permission prompt incorrectly triggers on `cd`](https://github.com/anthropics/claude-code/issues/28240) — 复合命令授权项指错的 regression，v2.1.52 起，截至 2026-08 仍 open（社区 issue，2026-02）
- [GH #16561 Parse compound bash commands for permission matching](https://github.com/anthropics/claude-code/issues/16561) — 复合命令按整串匹配导致误弹窗，含 repro（社区 issue，2026）
- [GH #73125 AskUserQuestion 60s 超时自动继续](https://github.com/anthropics/claude-code/issues/73125) — 安全确认闸被自动跳过，387 👍，已在 v2.100 改为默认关闭（社区 issue，2026）

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑]`
