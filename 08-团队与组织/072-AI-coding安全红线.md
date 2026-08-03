# 072. AI coding 的安全红线怎么画？密钥泄露、数据外泄、第三方上传的真实事故与防护

> 难度：高级
> 主题：团队与组织
> 工具：Claude Code · 横向(Cursor / Copilot)
> 题型：决策题 + 排错题

> ⏰ 时效声明：本篇涉及的数据政策事实，已于 **2026-07-18** 对照官方 [data-usage 文档](https://code.claude.com/docs/en/data-usage) 逐项核实无误。核实范围包括：商用默认不训练、标准留存 30 天，消费版开训练留 5 年，ZDR 不含在标准 Enterprise、需按组织开通，本地明文 transcript 与 `cleanupPeriodDays`，AES-256/KMS/CMEK 加密，Development Partner Program 在 Bedrock/Vertex 不可用，第三方平台 telemetry 默认关闭。另有一组条款与出境相关的事实核实于 **2026-08**：ZDR 不覆盖 Bedrock/Vertex/Foundry 且需按 organization 由销售开通、Anthropic 商用条款赔偿只覆盖 paid use、Copilot IP 赔偿只给 Business/Enterprise。政策条款随官方更新即失效。签约或合规决策前，请以官方页面与商业条款为准；CVE 细节以各研究者原文为准。

> 本篇开发者与团队负责人都相关：技术护栏部分人人能自己配，部署选型和组织政策需要负责人拍板。

## TL;DR

AI coding 的安全风险，重点不是"AI 会不会写出 bug"（那是 05 质量篇的事），而是**组织级的三条红线**：密钥泄露、数据外泄、第三方上传。这三条线各有真实已披露的事故，也各有明确的防护手段。

给忙人的三条速查：

1. **先分清"数据去哪了"，再谈别的。** 商用版（Team / Enterprise / API）默认不拿你的代码训练模型，标准留存 30 天。消费版（Free / Pro / Max）默认让你选是否用于训练，一旦开了训练就留 5 年。ZDR（零数据留存）只对合格的 Enterprise 逐个开通，不含在标准 Enterprise 套餐里。这些都是 Anthropic 官方文档写明的边界。✅

2. **最狠的事故是"间接提示注入 + 自动放行命令 → 偷密钥"。** CVE-2025-55284 就是让 Claude 读 `.env`，再用 `ping` 把密钥编码进 DNS 请求发出去，全程无需你点确认。漏洞已修复，但攻击模式是通用的：读敏感文件，再找一条能出网的通道。✅

3. **画红线要做三件事。** 一是部署模式选型（默认 API、ZDR Enterprise、或自托管 Bedrock/Vertex）。二是技术护栏（permissions deny + sandbox + hooks + secret 扫描）。三是组织政策（managed settings 全员强制，禁止把生产密钥和客户数据喂进去）。出口再补一道许可证扫描，防 AI 吐回来的代码带许可证污染。

**本篇画的是数据和密钥层面的组织红线，以及事故防护。** 它不重复讲单次产出的代码正确性校验，那在 [#040 谁来验证 AI 代码](../05-质量保证/040-怎么验证AI代码是真的对.md)。它也不重复团队规范怎么立（[#075](./074-团队AI-coding规范怎么立.md)）和成本（[#060](../07-效率与成本/060-一天该烧多少额度.md)）。

---

## 为什么

### 1. 三条红线，各自的风险面

AI coding agent 和传统"补全式"AI 的根本区别，是它能读你整台机器的文件、能跑命令、能出网。这三种能力把三个老问题放大了。

| 红线 | 风险面 | 为什么 AI 放大了它 |
|------|--------|-------------------|
| **密钥泄露** | `.env`、`~/.aws/credentials`、CI secret 被读走 | agent 为完成任务会主动 `grep` 密钥，还能被注入的指令诱导外发 |
| **数据外泄** | 源码、对话历史、客户数据经"能出网的通道"流出 | agent 有 WebFetch、Bash、MCP 等多条出网路径，堵一条还有一条 |
| **第三方上传** | 代码和 prompt 上传到模型厂商，被留存甚至用于训练 | 默认就在上传，这是 SaaS LLM 的工作方式，问题在于"留多久、训不训、谁能看" |

### 2. 第三方上传：先搞清官方数据政策的准确边界

这是最多人搞错、也最该先对齐的一条。下面以 Anthropic 官方 [Data usage 文档](https://code.claude.com/docs/en/data-usage)（官方，2026-07）为准。✅

**商用版默认不拿你的代码训练。** 覆盖 Team、Enterprise、API 和第三方平台。官方原文是 "Anthropic does not train generative models using code or prompts sent to Claude Code under commercial terms"，意思是商用条款下默认不用你的代码或 prompt 训练模型，除非你主动加入 Development Partner Program。标准留存 30 天。✅

**消费版一旦开训练，就留 5 年。** 覆盖 Free、Pro、Max。它给你一个开关选是否用于改进模型。开了留 5 年，不开留 30 天。用 Claude Code 登录消费账号同样适用这条规则。✅ 这是团队最容易踩的坑：用个人 Pro 或 Max 账号在公司代码上跑，又没关训练开关，等于把代码交出去、留存 5 年。

**ZDR 不是买了 Enterprise 就自动有。** ZDR 指 Zero Data Retention，即零数据留存。官方原文是 "available to qualified accounts for Claude Code on Claude for Enterprise. ZDR is not included in the standard Enterprise plan; it is enabled on a per-organization basis by your account team"，意思是它只面向合格账号，不含在标准 Enterprise 套餐里，要由客户团队按组织单独开通。所以想要 ZDR，得单独谈、逐组织开。✅

**还有一个常被忽略的本地面：会话记录明文存在你自己的机器上。** Claude Code 会把会话记录明文存进本地 `~/.claude/projects/`，默认留 30 天，可用 `cleanupPeriodDays` 调整。✅ 这意味着密钥可能落进本地明文 transcript，所以磁盘加密和访问控制也得跟上。

社区对"第三方上传能不能真保密"本就悲观。HN 用户 Terr_ 的说法有代表性，他认为"送进去的 prompt 和数据没法可靠保密"（原文 "no prompts/data that go in can reliably be kept secret"）。这条是单源、偏观点，仅供参考。但它提醒了一件事：保密的正解不是"信任厂商不看"，而是根本不把该保密的东西喂进去，再加上合同层的 ZDR 或自托管。

> 来源：[HN 47949750 @Terr_](https://news.ycombinator.com/item?id=47949750)，社区，2026 ⚠️

### 3. 密钥泄露 + 数据外泄：真实已披露的事故

这不是理论风险，是有 CVE 的真事故。下面看三个代表。

**事故 A：CVE-2025-55284，Claude Code 经 DNS 偷密钥。** 攻击链分四步：

1. Claude Code 早期把 `ping`、`nslookup`、`dig`、`host` 放进了无需确认就能跑的白名单。
2. 攻击者在一个"请 Claude review 一下"的文件里，藏了间接提示注入指令。
3. 被注入的 Claude 去读 `.env` 和 `/proc/PID/environ`，用 `strings` 加 `grep` 抠出 API key。
4. 它把密钥编码成 DNS 子域名，用 `ping` 发给攻击者的服务器，全程零人工确认。

官方的修复方式，是把这几个命令移出自动白名单。但要记住研究者的点评：直接让 Claude 干坏事会被拒，绕一下（用 `strings` 加 `grep` 混淆）就绕过了安全判断。所以防护不能只靠模型自觉。

> 来源：[embracethered](https://embracethered.com/blog/posts/2025/claude-code-exfiltration-via-dns-requests/)，社区安全研究。披露 2025-05-26，修复 2025-06-06（v1.0.4），CVSS 7.1 ✅

**事故 B：IDEsaster，30+ 漏洞横扫所有主流 AI IDE。** 研究者 Ari Marzouk 半年挖出 30 多个漏洞、24 个 CVE，涉及 Cursor、Windsurf、GitHub Copilot、Claude Code 等。他的核心论断是"所有 AI IDE 实际上都在威胁模型里忽略了底层软件即 IDE 本身"（原文 "All AI IDEs…effectively ignore the base software (IDE) in their threat model"，省略处后接 "They treat their features as inherently safe"，即它们把自己的功能当作天然安全）。

攻击手法覆盖多种：提示注入（藏在不可见 Unicode、HTML 注释、投毒的 MCP 里）、数据外泄、改 `.vscode/settings.json` 实现 RCE（CVE-2025-53773，Copilot）、密钥收割。这说明安全问题是整个品类的系统性问题，不是某一家的个案。

> 来源：[The Hacker News](https://thehackernews.com/2025/12/researchers-uncover-30-flaws-in-ai.html)，社区，2025-12-06 ✅

**事故 C：Claudy Day，出网通道就是内置能力。** 三个漏洞链成一次完整攻击：URL 参数里的隐形提示注入，加上用 Files API 外泄，再加上 claude.com 的开放重定向。这里的关键是，沙箱本身"受限但允许连到 `api.anthropic.com`"（原文 "restricted... but allows connections to api.anthropic.com"），于是内置能力被变成了外泄通道。漏洞已披露修复。

它的教训是：只堵"明显的出网命令"不够。任何被允许的连接，哪怕是发往官方 API，都可能被当成外泄通道。

> 来源：[OASIS Security](https://www.oasis.security/blog/claude-ai-prompt-injection-data-exfiltration-vulnerability)，社区安全研究，2026-03-18 ✅

### 4. 别忘了"AI 写的代码本身不安全"

即使数据不外泄，AI 产出的代码也可能自带漏洞。Veracode 分析了 100 多个模型和 80 个编码任务，结论是 45% 的 AI 生成代码引入了 OWASP Top 10 类漏洞。Java 场景失败率超过 70%，而且新模型并没有变得更安全。CTO Jens Wessling 把原因指向 vibe coding，他说"开发者依赖 AI 生成代码，通常不会明确定义安全要求"（原文 "developers rely on AI to generate code, typically without explicitly defining security requirements"）。

这条归 05 质量篇深讲，本篇只提示一点：安全红线里得有一层"AI 代码上线前过 SAST"（静态应用安全测试，即在不运行代码的情况下扫描源码找漏洞）。

> 来源：[Veracode GenAI Code Security Report](https://www.veracode.com/blog/genai-code-security-report/)，行业，2025，与 Help Net Security 多源交叉一致 ✅

顺带一个组织侧的量化背景。ProjectDiscovery 调研了 200 名安全从业者，只有 38% 认为能跟上 AI 出码的速度，78% 担心公司密钥暴露。另有"43% 员工往 AI 工具输入过敏感数据"一说，它实际出自该报道转引的一份 2025 National Cybersecurity Alliance 报告，并非 ProjectDiscovery 本次调研，此处标明来源以免张冠李戴 ⚠️。可见红线不是杞人忧天，而是行业普遍焦虑。

> 来源：[Cybersecurity Dive](https://www.cybersecuritydive.com/news/ai-coding-security-concerns-projectdiscovery/818319/)，行业，2026-04 ✅

---

## 怎么做

画红线的方法是三层同时上：部署模式管"数据去哪"，技术护栏管"agent 能干什么"，组织政策管"人不能干什么"。三层之外再补一道出口检查：代码进生产库前扫许可证。

### 第一层：部署模式选型（决策题核心）

按"数据敏感度加合规要求"分三档选，别一刀切。

| 场景 | 选什么 | 依据 |
|------|--------|------|
| 个人项目 / 开源 / 非敏感 | 默认 Claude API（Pro/Max/API），但要关掉训练开关 | 商用条款默认不训练；消费版务必手动关 ✅ |
| 一般企业代码 | Team 或 Enterprise 商用条款，标准 30 天留存 | 商用默认不训练、不留 5 年 ✅ |
| 强敏感 / 强合规（金融、医疗、SOX/PCI） | ZDR Enterprise（单独谈），或自托管 Bedrock / Vertex / Microsoft Foundry | ZDR 无服务端持久化；Bedrock/Vertex 数据留在你的云租户，可用 KMS/CMEK 客户托管密钥 ✅ |

几个关键取舍点，都来自官方 [Data usage 文档](https://code.claude.com/docs/en/data-usage)。✅

- **静态加密。** Anthropic API 用 AES-256 做基础设施加密。Bedrock 可上 AWS KMS 客户托管密钥。Vertex 支持 CMEK。合规要求"密钥由我方持有"时，就走后两者。
- **Bedrock、Vertex、Foundry 默认更安静。** 在这些 provider 上，telemetry、error report 和 `/feedback` 都默认关闭。
- **Development Partner Program 在 Bedrock、Vertex 上不可用。** 这个项目就是会拿你数据训练的那个。想彻底避开训练风险，自托管天然隔绝。

**数据出境这条路径要定死，尤其是国内公司用国外 agent。** 社区里真在用的就三条，按控制力从强到弱：

1. **完全不接外部。** 核心和机密代码库明令禁止接任何外部模型，只放边缘业务代码走 AI。V2EX 帖里的原话是"核心和机密代码肯定不会让你接外部的服务"。
2. **走云厂商中间层。** Claude 通过 Amazon Bedrock、Google Cloud（Vertex）、Microsoft Foundry 接入，数据保留按这些平台各自的策略走。这里有个高频误解要点名：**走了 Bedrock 不等于 ZDR**。官方文档写明 ZDR 只适用于 Anthropic 自家平台，Bedrock / Vertex / Foundry 那边看它们自己的政策（信息日期 2026-08）。
3. **企业版 + ZDR。** 前面说过，它不在标准 Enterprise 套餐里，管理员后台自己开不了，必须联系 Anthropic 销售或客户团队单独开通，而且按 organization 逐个开，新建的 org 不自动继承（信息日期 2026-08，来源 code.claude.com 官方文档）。

**还有一条合同层的：个人卡付的订阅，写公司生产代码等于没有保障。** 这不只是训练开关的问题，是赔偿条款根本不覆盖你：

- Anthropic 商用条款（Effective 2025-06-17）的赔偿条款只覆盖 **paid use**，即付费商用用量。
- GitHub Copilot 的 IP 赔偿（Copilot Copyright Commitment）只给 **Business 和 Enterprise**，Free / Pro 不覆盖。

也就是说，个人 Pro 出了第三方 IP 索赔，合同上没人替你兜。这不是法律意见，签约前找你们法务核当前版本条款。

**怎么判断做对了**：

第一，打开账单页，确认是公司主体签的商用或企业订阅，不是个人卡付的 Pro。

第二，别信"公司说走内网了"，自己查实际通道：

```bash
# 看 Claude Code 当前配置
claude config list

# 直接看环境变量：走 Bedrock/Vertex 时这些会被置位
env | grep -E 'CLAUDE_CODE_USE_BEDROCK|CLAUDE_CODE_USE_VERTEX|ANTHROPIC_BASE_URL|ANTHROPIC_MODEL'
```

看到 `CLAUDE_CODE_USE_BEDROCK=1` 就是走 AWS，什么都没有就是直连 Anthropic。这一步很多人从没查过。

### 第二层：技术护栏（Claude Code 实战配置）

1. **最小权限。** Claude Code 默认只读，改文件或跑命令都要批准。别图省事全 auto-approve。✅
2. **deny 掉出网命令和危险目录。** `curl`、`wget` 默认就不自动放行，但要显式 `deny` 兜底。密钥目录加 denyRead。
3. **开沙箱。** 用 `/sandbox` 给 Bash 加文件系统和网络隔离，把 agent 关进笼子里再让它自主跑。
4. **加 secret 扫描 hook。** 用 PreToolUse hook 拦截含密钥的提交和外发，配合 gitleaks 或 trufflehog。
5. **别把生产密钥放进 agent 够得到的地方。** CVE-2025-55284 的根因，就是 `.env` 就在工作目录里。用 secret manager，运行时才注入。

### 第三层：组织政策（用 managed settings 强制，不靠自觉）

1. **用 managed settings 全员强制，而不是写进 CLAUDE.md 建议。** CLAUDE.md 是上下文而非配置，可被忽略（见 [#010](../02-上下文工程/010-CLAUDE-md怎么写才生效.md)）。托管策略层用来放组织安全基线。
2. **写死红线清单。** 禁止把生产密钥、客户 PII、未脱敏数据喂进任何 AI 工具。禁用个人消费账号跑公司代码。
3. **审计与监控。** 用 `ConfigChange` hook 拦会话内改配置，用 OpenTelemetry 监控用量和异常。
4. **MCP 白名单。** 官方明确"Anthropic 不对任何 MCP server 做安全审计"（原文 "does not security-audit"）。所以 MCP server 清单要入 git，只用自己写的或可信来源的。✅
5. **事故响应预案（排错题）。** 见下节。

### 出口检查：AI 代码进生产库前的许可证扫描

前三层管的是"数据别流出去"，这一层管的是反向风险："模型吐回来的东西干不干净"。模型可能复现训练数据里的片段，跟你是否拥有这段输出无关，第三方的侵权主张是独立成立的。这是唯一能把这类风险变成可检测项的动作。

先破一个误解：**大家一提许可证污染就只盯 GPL，其实没有 license 的公开代码风险更高。** MIT / BSD / Apache 都有署名要求；而没标 license 的公开代码按默认全权保留，等于什么都不许你做，比 GPL 还麻烦。

用 ScanCode Toolkit（AboutCode 的开源项目，被 Eclipse 基金会、FSF、ClearlyDefined 采用）：

```bash
pip install scancode-toolkit

# -l 许可证 -c 版权 -p 包清单 -i 文件信息
scancode -clpi --json-pp scan.json ./src

# 只看命中了哪些许可证
python -c "import json;d=json.load(open('scan.json'));\
print(sorted({m['license_expression'] for f in d['files'] for m in f.get('license_detections',[])}))"
```

接进 CI（GitLab CI 示例，GitHub Actions 同理）：

```yaml
license-scan:
  script:
    - pip install scancode-toolkit
    - scancode -cl --json-pp scan.json ./src
    - python scripts/check_license.py scan.json   # 命中黑名单许可证则 exit 1
  allow_failure: false
```

**怎么判断做对了**：两步。一是输出里的许可证集合跟你们的允许清单一致（典型允许清单：MIT / Apache-2.0 / BSD-3-Clause），冒出 GPL-3.0、AGPL-3.0 或 ScanCode 报了行号说某文件带第三方版权声明，就停下来人工看那几行。二是故意往测试分支粘一段带 GPL 头的文件，push，CI 必须红——光配上不验证等于没配，`allow_failure: true` 忘删就静默失效了。

---

## Claude Code 实战

### 团队级 `.claude/settings.json`（安全基线示例）

```json
{
  "permissions": {
    "deny": [
      "Bash(curl:*)", "Bash(wget:*)",
      "Bash(ping:*)", "Bash(nslookup:*)", "Bash(dig:*)", "Bash(host:*)",
      "Read(./.env)", "Read(./.env.*)", "Read(~/.aws/**)", "Read(~/.ssh/**)"
    ],
    "ask": ["Bash(git push:*)"]
  },
  "sandbox": true,
  "enableAllProjectMcpServers": false
}
```

> 说明：`deny` 里手动补上 `ping`、`nslookup`、`dig`、`host`，是对 CVE-2025-55284 那类"DNS 外泄"做纵深防御。即便官方已把它们从自动白名单移除，显式 deny 能让它们连"批准一次"的机会都没有。密钥目录 denyRead 则是堵住"读了才能外发"的第一步。具体配置项以你所在版本的 [permissions 文档](https://code.claude.com/docs/en/permissions) 为准。

### 排错题：怀疑发生数据外泄或密钥泄露，怎么响应

| 步骤 | 动作 | 为什么 |
|------|------|--------|
| 1 | 立即轮换所有可能被读到的密钥（`.env`、CI secret、云凭证） | 先假设已泄露，轮换密钥是最快的止血手段 |
| 2 | 查本地 `~/.claude/projects/` 明文 transcript，和系统 shell 历史 | 看 agent 实际读了什么、发了什么（官方确认这里存明文）✅ |
| 3 | 查出网记录：DNS 查询日志、`api.anthropic.com` 之外的异常连接、MCP server 流量 | CVE-2025-55284 走 DNS，Claudy Day 走 Files API，出网通道是多样的 |
| 4 | 定位注入源：最近 review 过的外部 PR、文件、网页、MCP | 间接提示注入藏在"让 AI 读的内容"里 |
| 5 | 升级 Claude Code 到最新版，收紧 permissions deny，开 sandbox | 已知 CVE 靠自动更新修复，护栏防下一次 |
| 6 | 若涉及客户数据或合规范围，走正式 incident 流程加合规上报 | SOX、PCI、GDPR 都有强制披露时限 |

> 上报安全漏洞本身走官方 [HackerOne program](https://code.claude.com/docs/en/security)，不要公开披露未修复的漏洞。

---

## 横向对比

| 工具 | 数据/训练默认 | 密钥·外泄护栏 | 合规部署选项 |
|------|-------------|--------------|-------------|
| **Claude Code** | 商用默认不训练、30 天留存；消费版可选，开则 5 年 ✅ | 默认只读 + 权限批准 + `/sandbox` + deny 规则 + WebFetch 独立上下文 + 域名安全检查 ✅ | ZDR Enterprise（单谈）/ Bedrock（KMS）/ Vertex（CMEK）/ Foundry ✅ |
| **Cursor** | 有 Privacy Mode；企业版可保证不训练 | IDE 内权限模型；CVE-2025-49150 曾被曝数据外泄 ✅ | 自托管选项有限，多依赖其云 |
| **GitHub Copilot** | 企业版不用你代码训练；有 content exclusion | CVE-2025-53773 曾被曝改 settings 实现 RCE ✅ | 走 GitHub / Azure 合规体系 |

三家在 IDEsaster 研究里都中招，所以没有哪家能靠"选它"就免除组织侧的防护。核心差异在两点：Claude Code 的护栏更细（sandbox、分层 permissions、managed settings 全员强制），合规部署路径也更明确（ZDR 加三大云自托管）。跨工具的准确定价和条款，请以各自官方为准，社区口径标 ⚠️。

---

## 反模式

- ❌ **用个人 Pro/Max 账号跑公司代码，且没关训练开关。** 消费版开了训练，留存 5 年，等于把代码交出去。公司代码必走商用条款。✅
- ❌ **以为"买了 Enterprise 就有 ZDR"。** 官方明确 ZDR 不含在标准 Enterprise，要单独谈、逐组织开通。✅
- ❌ **把 `.env` 和生产密钥留在工作目录里，让 agent 随手能读。** 这是 CVE-2025-55284 的直接前提。用 secret manager，运行时注入。✅
- ❌ **只堵"明显的出网命令"（curl、wget）就以为安全。** DNS（ping）和 Files API 都是外泄通道。Claudy Day 证明，发往官方 API 也能被滥用。要纵深防御加 sandbox。✅
- ❌ **无脑 auto-approve 或全量放行 MCP。** 官方不对 MCP server 做安全审计，全放行等于把出网和执行权白送。✅
- ❌ **把安全红线写进 CLAUDE.md 当"强制"。** CLAUDE.md 是可被忽略的上下文（[#010](../02-上下文工程/010-CLAUDE-md怎么写才生效.md)）。要强制，就用 managed settings 加 hook。✅
- ❌ **信"AI 写的代码默认安全"就直接上线。** 45% 的 AI 代码引入 OWASP 漏洞，且新模型没变好，上线前必须过 SAST。✅
- ❌ **把"走了 Bedrock"当成"零数据保留"。** 官方文档明说 ZDR 不适用于 Bedrock / Vertex / Foundry，那边按各自平台策略走。✅
- ❌ **用个人卡付的 Pro 写公司生产代码。** 除了训练开关问题，Anthropic 赔偿只覆盖 paid use、Copilot IP 赔偿只给 Business / Enterprise，个人档合同保障基本为零。✅
- ❌ **防许可证污染只盯 GPL。** MIT/BSD/Apache 有署名要求，没标 license 的公开代码默认全权保留，比 GPL 更麻烦。
- ❌ **配了 CI 许可证扫描但从没验证过能拦住。** 规则写错、路径写错、`allow_failure: true` 忘删，都会让门禁静默失效。

---

## 延伸

**交叉引用：**
- [#040 AI 说"做完了"、测试也全绿，怎么知道代码是真的对？](../05-质量保证/040-怎么验证AI代码是真的对.md) —— 本篇"AI 代码本身不安全"那层的验证体系归它，本篇只画红线，不讲校验手法。
- [#075 团队的 AI coding 规范怎么立？哪些该强制、哪些该自由？](./074-团队AI-coding规范怎么立.md) —— 安全基线是规范里最该强制的一档，规范怎么写、怎么强制归它。
- [#071 AI coding 的效能到底怎么度量？DORA / SPACE / 代码量 / AI 生码率，哪个不是 vanity metric？](./071-AI-coding效能怎么度量.md) —— 安全事故数可作为度量的反向指标之一。
- [#010 CLAUDE.md 怎么写才真的生效？](../02-上下文工程/010-CLAUDE-md怎么写才生效.md) —— 为什么红线要用 managed settings 而非 CLAUDE.md。
- [#060 额度怎么突然就没了？20x Max 也撑不过一上午——先算清自己一天该烧多少](../07-效率与成本/060-一天该烧多少额度.md) —— 自托管 Bedrock/Vertex 的成本取舍归成本篇。

**参考资料：**
- [Claude Code Data usage — Claude Code Docs](https://code.claude.com/docs/en/data-usage) — 训练政策、留存周期、ZDR 适用范围、本地明文缓存、静态加密（官方，2026-07）✅
- [Claude Code Security — Claude Code Docs](https://code.claude.com/docs/en/security) — 权限模型、sandbox、提示注入防护、MCP 不做安全审计、事故上报（官方，2026-07）✅
- [Claude Code: Data Exfiltration with DNS (CVE-2025-55284) — embracethered](https://embracethered.com/blog/posts/2025/claude-code-exfiltration-via-dns-requests/) — DNS 外泄真实攻击链，披露 2025-05 / 修复 2025-06（社区安全研究）✅
- [Researchers Uncover 30+ Flaws in AI Coding Tools — The Hacker News](https://thehackernews.com/2025/12/researchers-uncover-30-flaws-in-ai.html) — IDEsaster 研究，24 CVE 横扫主流 AI IDE（社区，2025-12）✅
- [Claude.ai Prompt Injection Data Exfiltration ("Claudy Day") — OASIS Security](https://www.oasis.security/blog/claude-ai-prompt-injection-data-exfiltration-vulnerability) — 三漏洞链、Files API 外泄通道（社区安全研究，2026-03）✅
- [AI-written software creates hassles for security teams — Cybersecurity Dive](https://www.cybersecuritydive.com/news/ai-coding-security-concerns-projectdiscovery/818319/) — ProjectDiscovery 调研：38% 跟得上、78% 担心密钥暴露（行业，2026-04）✅
- [GenAI Code Security Report — Veracode](https://www.veracode.com/blog/genai-code-security-report/) — 45% AI 代码引入 OWASP 漏洞、新模型未改善（行业，2025，多源交叉）✅
- [HN: Why AI companies want you to be afraid of them](https://news.ycombinator.com/item?id=47949750) — "no prompts/data that go in can reliably be kept secret"（社区，2026）⚠️
- [Zero data retention — Claude Code 官方文档](https://code.claude.com/docs/en/zero-data-retention) — ZDR 适用范围、需销售单独开通、不覆盖 Bedrock/Vertex/Foundry（官方，查证于 2026-08）✅
- [Anthropic Commercial Terms of Service](https://www.anthropic.com/legal/commercial-terms) — 赔偿条款只覆盖 paid use（K.1）与其排除项（K.3）（官方，Effective 2025-06-17，查证于 2026-08）✅
- [GitHub Copilot Trust Center FAQ](https://copilot.github.trust.page/faq) — Copilot Copyright Commitment 只覆盖 Business / Enterprise（官方，查证于 2026-08）✅
- [ScanCode Toolkit](https://github.com/aboutcode-org/scancode-toolkit/) — 许可证/版权扫描命令行工具，输出带行号定位（官方/开源项目，查证于 2026-08）✅
- [ScanCode license detection 原理说明](https://scancode-toolkit.readthedocs.io/en/latest/explanation/scancode-license-detection.html) — 为什么它能定位到许可证片段的起止行（官方，查证于 2026-08）✅
- [不懂就问-AI 开发 — V2EX](https://www.v2ex.com/t/1219306) — 34 回复，国内公司用国外 agent 的真实做法：内网部署 / 企业合同 / 分级管理 / 云厂商中间层（社区，2026-06）⚠️
- [生成式人工智能服务管理暂行办法 — 中央网信办](https://www.cac.gov.cn/2023-07/13/c_1690898327029107.htm) — 国内生成式 AI 监管基础规章，第二十条涉及境外来源服务（官方，2023-07）✅

> 本篇个人实践（L4）：`[待补：BOSS 的实战经验/踩坑——部署模式实际怎么选、密钥外泄有没有踩过坑、managed settings 红线清单长啥样]`
