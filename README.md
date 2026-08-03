[简体中文](README.md) · [English](README.en.md)

![Sol 主控向 Luna Max 工作节点分配有边界任务，FILES、DIFF、TEST 证据返回审核](docs/assets/readme/hero-zh.svg)

# Sol Luna

**Sol 单一主控。Luna Max 有界执行。真实文件与证据通过后才交付。**

`codex-sol-luna` 是一个小型、通用的 Codex 编排 Skill。简单任务由当前 Codex
直接完成；复杂任务由 Sol 理解、规划、分配和审核，Luna Max 负责执行清晰的子任务。

| 典型测试样本 | 复杂测试样本 |
| --- | --- |
| **普通任务（适合有边界委派）约节省 59%** | **复杂且容易返工任务约节省 65%** |

两项均基于本地已完成项目样本、公开模型费率和可复算公式验证。这些结果不是保证，也不表示
每个任务都会得到固定结果。59% 对应适合有边界委派的典型任务；简单 Direct 任务零委派，路由节省为
**0%**。65% 对应复杂且容易返工、能够从失败关闭与有界修正中受益的任务。

规范仓库地址是 [yehyakin/codex-sol-luna](https://github.com/yehyakin/codex-sol-luna)。
当任务复杂、可并行或高风险时，显式调用 `$sol-luna` 选择这个 Skill。

![Control Orbit 的 Direct、Sol-only、Sol → Luna 路由与 PASS、FIX、BLOCKED 证据闭环](docs/assets/readme/control-plane-zh.svg)

## 60 秒开始

在 [codex-sol-luna](https://github.com/yehyakin/codex-sol-luna) checkout 中，先
验证再安装：

```sh
bash scripts/validate.sh
bash scripts/install.sh
```

安装后，向 Codex 描述目标、`done_when`、文件所有权和验证命令，并显式调用
`$sol-luna`。小型、独立或仅需说明的任务保持 Direct；完整的平台命令和卸载/回滚
路径见[平台与生命周期](#平台与生命周期)。

## 选择路径

Skill 不会把每件事都委派出去。先判断任务是否值得规划、执行和复核的额外成本：

| 路径 | 适用情况 | 委派与结果 |
| --- | --- | --- |
| **Direct** | 小型、独立、目标清楚的工作 | 零委派，路由节省 **0%**，当前 Codex 直接完成 |
| **Sol-only** | 需要澄清、计划或审查，但不需要改文件 | Sol 规划/复核，停在执行工坊之前 |
| **Sol → Luna** | 清晰、可分界、需要真实变更的复杂工作 | Luna 在独立 owner 范围内执行，返回证据给 Sol |

适合 `$sol-luna` 的任务通常有清晰的 `write_scope`、不应触碰的路径、可观察的
`done_when` 和可复现的验证命令。目标尚不明确、上下文重复成本过高或复核收益不足
时，保持 Direct 更可靠。

Sol 是唯一的 controller，负责目标理解、完成条件、阶段计划、文件所有权、路由和最终审查。
Luna Max worker 只执行收到的有边界任务，验证自己的变更并返回证据。并行只发生在互不重叠
的 owner 范围内；worker 数量由实时容量决定，而不是一个对外承诺的固定上限。运行时默认使用简体中文；
用户明确指定其他语言时，改用用户指定的语言。代码、命令、路径、标识符和原始证据
按需保留原文。

```text
用户目标 → Sol 计划并路由 → Luna Max 执行有边界的任务
          → Sol 审查文件、diff 与证据 → 交付
```

| 角色 | 职责 | 边界 |
| --- | --- | --- |
| Sol | controller、planner、router 和 reviewer | 只做编排与最终决策 |
| Luna Max | 有边界的实现与自验证 | 只能修改分配的文件；不得递归委派 |

## 可靠性来自边界

可靠性来自可证明的身份、所有权、证据新鲜度和有界修正，而不是来自配置里的一行标签。

每个委派工作走一条可审查的闭环：

1. **计划。** Sol 写下 `goal`、`done_when`、依赖、精确 `write_scope`、排除项和验证。
2. **执行。** Luna 收到包含 `Task ID`、`Task`、`Context`、`Write scope`、`Do not touch`、
   `Expected result` 和 `Verification` 的任务包，只改分配范围。
3. **自检。** Luna 运行指定验证，返回确切的 changed paths、diff、测试和构建证据。
4. **审核。** Sol 检查真实文件和新鲜证据，决定 `PASS`、一次 focused `FIX` 或 `BLOCKED`。

worker 交付不是最终批准；只有 Sol 审核过真实 diff 后才算完成。一个文件在整个运行
期间只有一个 owner。互不重叠的范围可以并行；不确定或重叠的范围必须等待。

### 运行时身份与失败关闭

| Agent | Model | Reasoning effort | Effective sandbox |
| --- | --- | --- | --- |
| `sol-controller` | `gpt-5.6-sol` | `high` | `read-only` |
| `luna-max-worker` | `gpt-5.6-luna` | `max` | `workspace-write`，受 parent 边界限制 |

启动时必须证明所选 custom agent、精确 model、reasoning effort 和有效权限边界。
如果任一身份或权限无法证明，runtime 会**失败关闭（Fail Closed）**，不会静默替换
成相近的 model、角色、effort 或 sandbox。Luna Max 不得 spawn 或 create subagents，
不得扩大写入范围、重写 Sol 的计划、批准整体任务，或把部分结果当作交付。

### 阶段、所有权、证据与修正

流程包含四个环节：Sol 计划并路由；Sol 分配、Luna 执行；Luna 自检并返回证据；Sol 最终审查并交付。结果包保持
可机器解析并且可证伪：

```text
Task ID: <stable task id>
Status: PASS | BLOCKED
Summary: <what happened>
Changed: <exact files, or None>
Verification: <commands, exit status, and concise output>
Evidence: <diff, test, build, log, or artifact location bound to the final candidate>
Failure class: runtime | model_identity | permission | dependency | scope | verification | conflict | none
Blocker: <None or the concrete blocker>
```

Evidence 必须绑定最终候选身份，可以使用 commit+diff identity 或精确的 changed-file
snapshot。验证后候选发生变化时，旧证据立即失效，必须重跑受影响的验证；transport/
spawn 的 `completed` 只表示投递生命周期完成，不能替代结构化 Luna `PASS`、
Verification/Evidence/changed-path proof 或 Sol review。

Sol 最多可以向原 owner、原 scope 发出一次 focused correction。第二次失败、缺少依赖
或扩大 scope 都是 `BLOCKED`。Correction Packet 必须带 `Failure class` 与 `Delta`；
相同任务包且没有新证据时不得重新 launch。

Resume packet 只用于预计跨上下文压缩、会话中断或长时间运行的任务，只含
`goal`、`completed`、`in_flight`、`artifact_location`、`next_action`。短任务和 Direct
任务不生成 resume packet。实时容量决定批次大小，计划从不假设固定的 Luna 最大数量。

## 成本测算与测试口径

这个模型区分 API token 的美元价格与 subscription credit 所代表的容量。官方来源是
[OpenAI API pricing 页面](https://developers.openai.com/api/docs/pricing)和官方
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

在这些 token 类别中，Luna 的成本是 Sol 的 `1/25`。把其他条件相同的 worker-token
segment 从 Sol 移到 Luna，会让该 segment 降低 **96%**；这只是片段比较，不是整项
任务的承诺。

透明测算公式为：

```text
savings = delegated_share * (1 - luna_duplication / 25) - sol_overhead
```

其中 `delegated_share` 是转交给 Luna 的工作份额，`luna_duplication` 是 Luna token
相对委派基线的倍数，`sol_overhead` 是新增的 Sol 计划与审查开销。

| Scenario / 场景 | Delegated share | Luna duplication | Added Sol overhead | Sample-validated saving |
| --- | ---: | ---: | ---: | ---: |
| Conservative / 保守 | 50% | 125% | 10% | about 38% |
| Typical / 典型 | 70% | 115% | 8% | about 59% |
| Reliability-gated complex / 可靠性门槛复杂 | condition-based | 15% avoided invalid rework | 41% after typical | about 65% |

典型测算留下 41% 成本；在可靠性门槛下避免相当于剩余成本 15% 的无效返工：
41% * 85% = 34.85%，因此约节省 65%。这个口径与本地复杂任务样本中的失败关闭、
验证和有界修正链路一致。

作为简单参考，一个全 Sol 的 short-context 工作负载（1M input、0.1M output）约为
**$8.00** 或 **200 ChatGPT credits**；典型假设下的等价工作约为 **$3.30** 或
**82.4 credits**，约降低 59%。Direct task / 直接任务零委派，路由节省为 **0%**。

这些测算基于本地项目测试样本与公开费率，不是每个任务的固定保证。任务拆分不佳、
重复上下文、异常大的 Sol 审查、较低委派比例或重试都可能降低、反转甚至抵消节省。API 用户可能看到美元金额上的
节省；subscription（订阅）用户主要获得更多可用容量或额度，除非路由同时避免购买
额外 credits 或升级套餐。API 的美元节省与 subscription 的容量不是同一个结论。

## 平台与生命周期

| 目标 | Shell | 状态边界 |
| --- | --- | --- |
| macOS | POSIX shell | 由 `bash` 生命周期脚本支持 |
| Linux | POSIX shell | 由 `bash` 生命周期脚本支持 |
| Windows 11 | Windows PowerShell 5.1 与 PowerShell 7.x | 支持目标；原生 Windows 11 证据仍是独立发布门槛 |
| Windows Server 2022 | Windows PowerShell 5.1 与 PowerShell 7.x | 支持目标；GitHub 托管 CI 只属于 Server 证据 |

GitHub Actions 使用 `windows-latest` 和固定的 `windows-2022` Windows 矩阵。这些托管
runner 提供 Windows Server 证据，不能被描述为原生 Windows 11 证据。

### macOS 与 Linux

```sh
bash scripts/validate.sh
bash scripts/install.sh
bash scripts/uninstall.sh
bash scripts/uninstall.sh --restore-latest
```

在隔离测试目录运行前，将 `ORCHESTRATE_HOME` 设置为唯一的临时目录。安装器会在首次
修改前验证源文件，备份精确目标并原子安装，保留无关 agent 与 `~/.codex/config.toml`。

### Windows 11 与 Windows Server 2022

Windows 生命周期使用原生 PowerShell，兼容 PowerShell 5.1 和 PowerShell 7.x。Windows
PowerShell 5.1 使用 `powershell.exe`，PowerShell 7 使用 `pwsh`：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/validate.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/uninstall.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/uninstall.ps1 -RestoreLatest
pwsh -NoProfile -File scripts/validate.ps1
pwsh -NoProfile -File scripts/install.ps1
pwsh -NoProfile -File scripts/uninstall.ps1
pwsh -NoProfile -File scripts/uninstall.ps1 -RestoreLatest
```

运行隔离的 Windows 生命周期测试时，将 `$env:ORCHESTRATE_HOME` 设置为唯一临时 home。
Windows Server CI 只证明 Server 行为；在记录真实 Windows 11 运行结果以前，本 README
不宣称已有原生 Windows 11 证据。

生命周期会保留 `~/.codex/config.toml` 和无关 agent。未修改的 legacy v0.1 安装可以
迁移；已修改的 legacy target 会被保留，而不是静默删除。卸载只删除记录的 `SHA256`
仍匹配的 owned targets。`-RestoreLatest` / `--restore-latest` 在移除 owned installation
后恢复最近一次有效备份。发布时的运行表面与证据状态见
[`docs/release/runtime-surface-matrix.md`](docs/release/runtime-surface-matrix.md)。

## 真实项目路由样本

这些是匿名的本地真实项目测试样本。我们复用了已经完成的 Sol Luna 任务证据，只允许
最少的只读探针补齐材料；没有修改任何业务项目。

| 匿名类别 | 路由 | Luna 数量 | Wave | 验证 | Sol 终审 | 耗时 |
| --- | --- | ---: | ---: | --- | --- | ---: |
| 代码项目 | `sol_then_luna`（实测） | 不可得 | 不可得 | 有证据（实测） | `BLOCKED`（实测） | 2340 秒（实测） |
| 文档项目 | `sol_then_luna`（实测） | 不可得 | 不可得 | 有证据（实测） | `PASS`（实测） | 379 秒（实测） |
| 基础设施项目 | `direct`（实测） | 0（实测） | 0（实测） | 有证据（实测） | 不适用（实测） | 859 秒（实测） |

路由、耗时、验证和 Sol 终审来自真实记录；59% 与 65% 使用这些本地项目样本、公开
模型费率和下方公式进行统一口径测算。完整方法、匿名结果和限制见
[`tests/real-project-benchmark.md`](tests/real-project-benchmark.md)。

## 仓库与开发验证

### 仓库布局

```text
.agents/skills/sol-luna/       public Skill 与运行参考
.codex/agents/                 精确的 Sol 与 Luna custom-agent 定义
scripts/                       macOS/Linux 生命周期与验证脚本
tests/                         contract、forward-case 与生命周期测试
docs/assets/readme/            仓库自有本地化 Control Orbit hero 与 control-plane SVG
README.md                      默认简体中文指南
README.en.md                   完整的 English peer
```

公开 Skill 是 [`$sol-luna`](.agents/skills/sol-luna/SKILL.md)。精确的 agent 定义见
[`sol-controller.toml`](.codex/agents/sol-controller.toml) 与
[`luna-max-worker.toml`](.codex/agents/luna-max-worker.toml)。全局 Skill 与 agent 目录
只是安装副本；GitHub 是事实来源。

### 测试

使用 Python 3.11 或更高版本运行文档 testing contract、仓库 URL contract 和 benchmark：

```sh
python -m unittest tests/test_readme.py
python -m unittest tests/test_contract.py
python -m unittest tests/test_benchmark.py
```

文档 contract 检查双语语言切换与 parity、规范仓库链接、本地图片目标、可访问 SVG
元数据、章节顺序、价格行、公式假设、场景测算和适用边界。benchmark 报告区分
`measured`、`sample_validated_projection`、`unavailable` 三类证据；若 PowerShell 可用，生命周期测试
还会使用 `ORCHESTRATE_HOME` 验证隔离 home，并确认 `config.toml` 与无关 agent 的 hash
保持不变。

## 限制

- 上述成本结果经过本地项目样本验证，但不声称每项路由任务都会得到完全相同的结果。
- 委派会增加计划、上下文、审查和可能的 retry token；重试可能完全抵消节省。
- GitHub 托管 Windows runner 建立的是 Windows Server 行为，不是原生 Windows 11 行为。
- Skill 刻意保持双角色：Sol 控制，Luna Max 执行；它不是通用的多 agent team 框架。
- 最终决策依赖真实文件和新鲜验证；仅凭配置中的标签无法证明运行时身份。

## 先例与许可证

### 先例

本设计参考了若干项目的已审查快照，它们探索了路由、有边界委派、并行调度和基于证据
的审查；没有复制这些项目的 prose 或 code：

- [orchestrate-sol-luna](https://github.com/joeke80215/orchestrate-sol-luna/tree/eba163a9d48f023aeb3638b6809f0f8fb343f472) — Apache-2.0。
- [codex-parallel-subagent-planner](https://github.com/manhua-man/codex-parallel-subagent-planner/tree/ea3d8db9081e2f4159a6c40100fc1ca8d229e7dc) — 审查快照未发现许可证文件；仅作思想参考。
- [codex-dispatch-skill](https://github.com/yinguangyao/codex-dispatch-skill/tree/00630de4c8ad01cb51bae3a89044d55cc6433158) — 审查快照未发现许可证文件；仅作思想参考。
- [codex-orchestrate](https://github.com/douglasmonsky/codex-orchestrate/tree/f2954a066e2607deef3963465562193a220dee70) — MIT。
- [subagent-orchestrator-skill](https://github.com/Glaicer/subagent-orchestrator-skill/tree/96eaeb16f19b789fd004b588858fb846cc674147) — MIT。

### 许可证

本仓库采用 [Apache License 2.0](LICENSE)。审查过的先例的归属说明记录在
[NOTICE](NOTICE) 中。

**致谢 / Thanks**

感谢 [LINUX DO 论坛](https://linux.do/) 社区的关注、反馈与支持
