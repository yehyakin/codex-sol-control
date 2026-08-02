[简体中文](README.md) · [English](README.en.md)

# Sol Luna

`codex-sol-luna` 是一个刻意保持小型、清晰的 Codex 编排 Skill：Sol 是唯一
主控，负责理解、规划、拆分、分配和审核；Luna Max 只执行有边界的任务、完成
自检并返回证据。

## 成本约节省 59%

在当前典型模型中，把约 70% 的执行工作交给 Luna Max，即使 Luna 为完成这些
工作使用约 115% 的相对 token，并增加约 8% 的 Sol 规划与审核开销，整个工作流
的估算成本仍可下降约 **59%**。

**保守场景约节省 38% · 执行密集场景约节省 74%**

这是基于 2026-08-02 价格快照和公开公式得到的估算，不是每个任务的保证。
简单 Direct 任务的路由节省为 0%；重复上下文、错误拆分、重试或过重的 Sol
审核都可能降低甚至抵消节省。完整价格、公式和证据边界见后文。

![Sol Luna 英雄图：Sol 控制闭环，Luna Max 执行有边界的工作](docs/assets/sol-luna-hero.svg)

> 一个控制器。有边界的执行。可审查的证据。

规范仓库地址是 [yehyakin/codex-sol-luna](https://github.com/yehyakin/codex-sol-luna)。
当任务复杂、可并行或高风险时，显式调用 `$sol-luna` 选择这个 Skill。

## 架构

![Sol Luna 架构图：用户目标经过 Sol、并行 Luna worker、Sol 审查后交付](docs/assets/sol-luna-architecture.svg)

Sol 是唯一的 controller，负责控制目标理解、完成条件、阶段计划、文件所有权、
路由和最终审查。Luna Max worker 只执行收到的有边界任务，验证自己的变更并
返回证据。Luna 不得创建 subagents，worker 数量由实时容量决定，而不是一个
对外承诺的固定上限。

```text
用户目标 → Sol 计划并路由 → Luna Max 执行有边界的任务
          → Sol 审查文件、diff 与证据 → 交付
```

对外接口保持刻意简洁：

| 角色 | 职责 | 边界 |
| --- | --- | --- |
| Sol | controller、planner、router 和 reviewer | 只做编排与最终决策 |
| Luna Max | 有边界的实现与自验证 | 只能修改分配的文件；不得递归委派 |

## 何时使用，以及何时保持直接执行

适合使用 `$sol-luna` 的情况：

- 具有清晰边界和独立工作的多部分变更；
- 每个文件都可以指定一个 owner 的可并行实现；
- 需要审查真实 diff 和证据的高风险工作；
- 需要明确阶段、依赖和可证伪 `done_when` 的计划。

适合保持直接执行的情况：

- 小型、独立的编辑或快速说明；
- 目标还不够明确，无法拆成有边界的任务包；
- 委派、重复上下文或复核成本可能超过收益；
- 只需要计划或审查，不需要执行。仅计划的工作可以使用零个 Luna worker，
  Direct task / 直接任务的路由节省声明为 0%。

显式调用 `$sol-luna` 始终从 Sol 开始。没有明确选择这个 Skill 时，普通简单
工作保持直接执行。

运行时默认使用简体中文输出 Sol 计划与审查、Luna 任务结果和状态更新。
用户明确指定其他语言时，以用户要求为准。代码、命令、路径、标识符和原始证据
可按需保留原文。

## 平台支持与快速开始

生命周期提供两类命令：

| 目标 | Shell | 状态边界 |
| --- | --- | --- |
| macOS | POSIX shell | 由 `bash` 生命周期脚本支持 |
| Linux | POSIX shell | 由 `bash` 生命周期脚本支持 |
| Windows 11 | Windows PowerShell 5.1 与 PowerShell 7.x | 支持目标；原生 Windows 11 证据仍是独立的发布门槛 |
| Windows Server 2022 | Windows PowerShell 5.1 与 PowerShell 7.x | 支持目标；GitHub 托管 CI 只属于 Server 证据 |

GitHub Actions 使用 `windows-latest` 和固定的 `windows-2022` Windows 矩阵。
这些托管 runner 提供 Windows Server 证据，不能被描述为原生 Windows 11 证据。

### macOS 与 Linux

在 [codex-sol-luna](https://github.com/yehyakin/codex-sol-luna) checkout 中运行：

```sh
bash scripts/validate.sh
bash scripts/install.sh
```

卸载，或恢复最近一次有效备份：

```sh
bash scripts/uninstall.sh
bash scripts/uninstall.sh --restore-latest
```

要使用隔离测试目录，请在运行命令前将 `ORCHESTRATE_HOME` 设置为唯一的临时
目录。安装器会备份精确的现有目标、原子安装，并保留无关 agent 与
`~/.codex/config.toml`。

### Windows 11 与 Windows Server 2022

Windows 生命周期使用原生 PowerShell，并保持与 PowerShell 5.1 和 PowerShell 7.x
兼容。Windows PowerShell 5.1 使用 `powershell.exe`，PowerShell 7 使用 `pwsh`：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/validate.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/uninstall.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/uninstall.ps1 -RestoreLatest
```

对应的 PowerShell 7 命令：

```powershell
pwsh -NoProfile -File scripts/validate.ps1
pwsh -NoProfile -File scripts/install.ps1
pwsh -NoProfile -File scripts/uninstall.ps1
pwsh -NoProfile -File scripts/uninstall.ps1 -RestoreLatest
```

运行隔离的 Windows 生命周期测试时，将 `$env:ORCHESTRATE_HOME` 设置为唯一的
临时 home。Windows Server CI 通过只证明 Server 行为；在记录真实 Windows 11
运行结果以前，本 README 不宣称已有原生 Windows 11 证据。

## 为什么可靠：身份、所有权、证据与修正

### 运行时身份与失败关闭行为

运行时身份必须精确且保持简单：

| Agent | Model | Reasoning effort | Effective sandbox |
| --- | --- | --- | --- |
| `sol-controller` | `gpt-5.6-sol` | `high` | `read-only` |
| `luna-max-worker` | `gpt-5.6-luna` | `max` | `workspace-write`，受 parent 边界限制 |

Sol 是唯一的 controller；Luna Max worker 执行有边界的任务并返回证据。运行时
启动时必须证明所选 custom agent、精确 model、reasoning effort 和有效权限边界。
配置文本或 agent 名称本身不是证明。如果任何身份或权限无法证明，运行时会
**失败关闭（Fail Closed）**，不会静默替换成相近的 model、角色、effort 或 sandbox。

Luna Max 不得 spawn 或 create subagents，也不得扩大写入范围、重写 Sol 的计划、
批准整体任务，或把部分结果当作交付。

### 阶段、所有权、证据与修正

Sol 的计划包含四项小而明确的职责：

1. **计划与路由。** Sol 记录具体的 `goal`、可观察的 `done_when` 条件、有边界
   的任务、精确的 `write_scope`、排除项、依赖和验证命令。
2. **执行。** Luna 收到包含稳定 `Task ID`、`Task`、可选 `Context`、`Write scope`、
   `Do not touch`、`Expected result` 和 `Verification` 的任务包。整个运行期间一个
   文件只有一个 owner。互不重叠的独立范围可以并行；不确定或重叠的范围必须等待。
3. **审查。** Sol 检查真实文件、完整 diff、测试输出和返回的证据。worker 的结果
   不能替代 Sol 的审查。
4. **修正或交付。** Sol 最多可以在原 owner 的原始范围内发出一次 focused
   correction。第二次失败、缺少依赖或扩大范围都应为 `BLOCKED`；只有 Sol 能对
   整体任务作出 `PASS` 决策。

实时容量决定批次大小，但不改变架构。可用 worker 较少时，准备好的任务留在
队列中；计划从不假设一个固定的 Luna 最大数量。

worker 结果必须可证伪：

```text
Task ID: <stable task id>
Status: PASS | BLOCKED
Summary: <what happened>
Changed: <exact files, or None>
Verification: <commands, exit status, and concise output>
Evidence: <diff, test, build, log, or artifact location>
Blocker: <None or the concrete blocker>
```

### 安装、验证、卸载、备份与回滚

安装器在第一次修改之前验证源文件，使用精确 literal path，拒绝不安全的根路径
和 reparse point，并使用 checksum 保护已拥有的目标。替换前先备份现有目标；
staging 与 rollback 防止失败安装留下半成品。

生命周期会保留 `~/.codex/config.toml` 和无关 agent。未修改的 legacy v0.1 安装
可以迁移；已修改的 legacy target 会被保留，而不是静默删除。卸载只删除记录的
`SHA256` 仍匹配的 owned targets。若目标已被修改，操作会拒绝而不是覆盖。
`-RestoreLatest` / `--restore-latest` 会在移除 owned installation 后恢复最近一次
记录且有效的备份。

macOS/Linux 命令：

```sh
bash scripts/validate.sh
bash scripts/install.sh
bash scripts/uninstall.sh
bash scripts/uninstall.sh --restore-latest
```

Windows 命令：

```powershell
pwsh -NoProfile -File scripts/validate.ps1
pwsh -NoProfile -File scripts/install.ps1
pwsh -NoProfile -File scripts/uninstall.ps1
pwsh -NoProfile -File scripts/uninstall.ps1 -RestoreLatest
```

PowerShell 验证和生命周期文件由 Windows 工作流独立负责。这里先说明支持的
目标和命令，不把 Server 结果推断为原生 Windows 11 证据。

## 真实项目基准

真实项目基准优先复用已完成的 Sol Luna 任务证据，仅对证据缺口运行最少的
只读探针。公开结果只保留匿名类别，严格区分 `measured（实测）`、
`estimated（估算）` 和 `unavailable（不可得）`。在精确分模型用量不可得时，
**59%** 仍属于 `estimated`，不会被写成实测成本节省。

## 成本模型与价格快照

这个模型区分 API token 的美元价格与 subscription credit 所代表的容量。官方来源
是 [OpenAI API pricing 页面](https://developers.openai.com/api/docs/pricing) 和官方
[Codex/ChatGPT rate card](https://learn.chatgpt.com/docs/pricing)。本快照日期为
**2026-08-02**；发布前请重新检查两个来源。

### 每 1M tokens 的 standard short-context API 价格

| Model | Input | Cached input | Cache write | Output |
| --- | ---: | ---: | ---: | ---: |
| GPT-5.6 Sol | $5.00 | $0.50 | $6.25 | $30.00 |
| GPT-5.6 Luna | $0.20 | $0.02 | $0.25 | $1.20 |

### 每 1M tokens 的 ChatGPT credits

| Model | Input | Cached input | Output |
| --- | ---: | ---: | ---: |
| GPT-5.6 Sol | 125 | 12.5 | 750 |
| GPT-5.6 Luna | 5 | 0.5 | 30 |

在这些 token 类别中，Luna 的成本是 Sol 的 `1/25`。因此，把一个其他条件相同的
worker-token segment 从 Sol 移到 Luna，会让该 segment 降低 **96%**。这只是片段
比较，不是对整项任务的承诺。

完整工作流仍会使用 Sol 做计划和审查，Luna 也可能读取重复上下文。透明估算公式为：

```text
savings = delegated_share * (1 - luna_duplication / 25) - sol_overhead
```

其中：

- `delegated_share` 是原本由全 Sol 运行完成、现在改由 Luna 执行的工作份额；
- `luna_duplication` 是 Luna token 量相对于该委派基线的倍数；
- `sol_overhead` 是相对于全 Sol 基线新增的 Sol 计划与审查开销。

| Scenario / 场景 | Delegated share | Luna duplication | Added Sol overhead | Estimated saving |
| --- | ---: | ---: | ---: | ---: |
| Conservative / 保守 | 50% | 125% | 10% | about 38% |
| Typical / 典型 | 70% | 115% | 8% | about 59% |
| Execution-heavy / 执行密集型 | 85% | 110% | 7% | about 74% |

作为简单参考，一个全 Sol 的 short-context 工作负载（1M input、0.1M output）约为
**$8.00** 或 **200 ChatGPT credits**。在典型假设下，路由后的等价工作约为
**$3.30** 或 **82.4 credits**，约降低 **59%**。

这些估算是模型，不是基准，也不是保证。Direct task / 直接任务声明为 **0%**
路由节省。任务拆分不佳、重复重试、异常大的 Sol 审查或较低委派比例，都可能降低
甚至反转收益；重试可能完全抵消节省。API 用户可能看到美元金额上的节省；
subscription（订阅）用户主要获得更多可用容量或额度，除非路由同时避免购买额外
credits 或升级套餐。API 的美元节省与 subscription 的容量不是同一个结论。

## 仓库布局、测试、限制、先例与许可证

### 仓库布局

```text
.agents/skills/sol-luna/       public Skill 与运行参考
.codex/agents/                 精确的 Sol 与 Luna custom-agent 定义
scripts/                       macOS/Linux 生命周期与验证脚本
tests/                         contract、forward-case 与生命周期测试
docs/assets/                   仓库自有 hero 与 architecture SVG
README.md                      默认简体中文指南
README.en.md                   完整的 English peer
```

公开 Skill 是 [`$sol-luna`](.agents/skills/sol-luna/SKILL.md)。精确的 agent 定义见
[`sol-controller.toml`](.codex/agents/sol-controller.toml) 与
[`luna-max-worker.toml`](.codex/agents/luna-max-worker.toml)。全局 Skill 与 agent
目录只是安装副本；GitHub 是事实来源。

### 测试

使用 Python 3.11 或更高版本运行文档 contract 与仓库 URL contract：

```sh
python -m unittest tests/test_readme.py
python -m unittest tests/test_contract.py
```

文档 contract 检查双语语言切换与 parity、规范仓库链接、本地图片目标、可访问的
SVG 元数据、章节顺序、价格行、公式假设、场景估算和免责声明。仓库 contract
检查运行时名称与 Windows contract artifacts。若 PowerShell 可用，生命周期测试还
会使用 `ORCHESTRATE_HOME` 验证隔离 home，并确认 `config.toml` 与无关 agent 的
hash 保持不变。

### 限制

- 上述估算是假设，不是 benchmark、保证，也不声称每项路由任务都会更便宜。
- 委派会增加计划、上下文、审查和可能的 retry token。
- GitHub 托管 Windows runner 建立的是 Windows Server 行为，不是原生 Windows 11
  行为。
- Skill 刻意保持双角色：Sol 控制，Luna Max 执行；它不是通用的多 agent team 框架。
- 最终决策仍依赖真实文件和新鲜验证；仅凭配置中的标签无法证明运行时身份。

### 先例

本设计参考了若干项目的已审查快照，它们探索了路由、有边界委派、并行调度和基于
证据的审查。没有复制这些项目的 prose 或 code：

- [orchestrate-sol-luna](https://github.com/joeke80215/orchestrate-sol-luna/tree/eba163a9d48f023aeb3638b6809f0f8fb343f472) — Apache-2.0。
- [codex-parallel-subagent-planner](https://github.com/manhua-man/codex-parallel-subagent-planner/tree/ea3d8db9081e2f4159a6c40100fc1ca8d229e7dc) — 审查快照未发现许可证文件；仅作思想参考。
- [codex-dispatch-skill](https://github.com/yinguangyao/codex-dispatch-skill/tree/00630de4c8ad01cb51bae3a89044d55cc6433158) — 审查快照未发现许可证文件；仅作思想参考。
- [codex-orchestrate](https://github.com/douglasmonsky/codex-orchestrate/tree/f2954a066e2607deef3963465562193a220dee70) — MIT。
- [subagent-orchestrator-skill](https://github.com/Glaicer/subagent-orchestrator-skill/tree/96eaeb16f19b789fd004b588858fb846cc674147) — MIT。

### 许可证

本仓库采用 [Apache License 2.0](LICENSE)。审查过的先例的归属说明记录在
[NOTICE](NOTICE) 中。
