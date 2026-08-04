[简体中文](README.md) · [English](README.en.md)

![Sol 单一主控把有界任务路由给 Luna Max 或 Terra High，并接收 FILES、DIFF、TEST 证据](docs/assets/readme/hero-zh.svg)

# Sol Luna

**Sol 单一主控。Luna Max 与 Terra High 分级执行。真实文件与证据通过后才交付。**

`codex-sol-luna` 是一个小型、通用的 Codex 编排 Skill。简单任务由当前 Codex
直接完成；复杂任务由 Sol 理解、规划、分配和审核，再由合适的执行层处理有界工作。

| 普通明确任务 | 混合项目 | 复杂直接额度 | 综合中心 |
| --- | --- | --- | --- |
| **预算节省 72%–76%** | **预算节省 50%–60%** | **预算节省 33%–43%** | **约 56%** |

这些是基于官方模型比例、路由工作量与编排开销复算的预算区间，不是固定结果，也不是每个任务的保证。
简单 Direct 任务零委派，路由节省为 **0%**；新混合路由尚未完成匹配的 A/B 对照。
额度节省不等于时间一定更快，实际结果取决于 token 总量、上下文重复、Sol 审查和返工。

规范仓库地址是 [yehyakin/codex-sol-luna](https://github.com/yehyakin/codex-sol-luna)。
当任务复杂、跨模块或高风险时，显式调用 `$sol-luna` 选择这个 Skill。

## v0.3.0 发布状态

| 验证面 | 结果 |
| --- | --- |
| 本地仓库 | Skill Creator **PASS**；**106/106** tests PASS |
| 托管 CI | POSIX **PASS**；Windows Server 2022 / `windows-latest` × Windows PowerShell 5.1 / PowerShell 7 **PASS** |
| 编排模式 | **Compatibility 已验证**；Native Nested、全新 CLI child model/effort 身份与物理 Windows 11 尚未证明 |

证据绑定报告提交 `6895f06`：[POSIX CI](https://github.com/yehyakin/codex-sol-luna/actions/runs/30858707335) · [Windows CI](https://github.com/yehyakin/codex-sol-luna/actions/runs/30858707364) · [完整实施报告](ORCHESTRATE_SOL_LUNA_V2_IMPLEMENTATION_REPORT.md)

![Control Orbit 展示 Direct、Sol-only、Sol → Luna 与 Sol → Terra 路由，以及返回 Sol 的 PASS、FIX、BLOCKED 证据闭环](docs/assets/readme/control-plane-zh.svg)

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

## 单一主控，一座执行工坊

Sol 是唯一的 controller，负责目标理解、完成条件、阶段计划、文件所有权、路由和最终审查。
Luna Max 是低歧义、目标清楚、可证伪且小上下文任务的有界执行者；它只能修改分配的范围，
不得创建子代理。Terra High 是跨模块、长上下文、模糊调试、共享接口或高风险实现的执行者；
它同样只在精确 `write_scope` 内工作，不得创建子代理。Sol、Luna 与 Terra 不是固定三 Agent
团队：运行时按任务与实时容量选择需要的路径。

```text
用户目标 → Sol 单一主控计划并路由
          → Luna Max（低歧义）或 Terra High（跨模块/高风险）有界执行
          → Sol 审查真实文件、diff 与证据 → 交付或阻断
```

| 角色 | 模型 / effort | 职责 | 边界 |
| --- | --- | --- | --- |
| Sol | `gpt-5.6-sol` / `high` | controller、planner、router、最终 reviewer | 只做编排与最终决策 |
| Luna Max | `gpt-5.6-luna` / `max` | 清晰低歧义任务的实现与自验证 | 只能修改分配文件；不得创建子代理 |
| Terra High | `gpt-5.6-terra` / `high` | 跨模块、长上下文、模糊调试、共享接口、高风险实现 | 只能修改分配文件；不得创建子代理 |

## 选择路径

Skill 不会把每件事都委派出去。先判断任务是否值得规划、执行和复核的额外成本：

| 路径 | 适用情况 | 委派与结果 |
| --- | --- | --- |
| **Direct** | 小型、独立、目标清楚的工作 | 零委派，路由节省 **0%**，当前 Codex 直接完成 |
| **Sol-only** | 需要澄清、计划或审查，但不需要改文件 | Sol 规划/复核，停在执行工坊之前 |
| **Sol → Luna** | 低歧义、可分界、上下文较小且需要真实变更 | Luna 在独立 owner 范围内执行，返回证据给 Sol |
| **Sol → Terra** | 跨模块、长上下文、模糊调试、共享接口或高风险实现 | Terra 在精确 owner 范围内执行，返回证据给 Sol |

并行只发生在互不重叠的 owner 范围内；同一文件在整个运行期间只有一个 owner。依赖、共享
接口和不确定边界必须等待或交给同一个执行者。worker 数量由实时容量决定，而不是一个
对外承诺的固定上限。

## 工作流

每个委派工作走一条可审查的闭环：

1. **计划。** Sol 写下 `goal`、`done_when`、依赖、精确 `write_scope`、排除项和验证。
2. **执行。** Luna 或 Terra 收到包含 `Task ID`、`Task`、`Context`、`Write scope`、
   `Do not touch`、`Expected result` 和 `Verification` 的任务包，只改分配范围。
3. **自检。** 执行者运行指定验证，返回确切的 changed paths、diff、测试和构建证据。
4. **审核。** Sol 检查真实文件和新鲜证据，决定 `PASS`、一次 focused `FIX` 或 `BLOCKED`。

只有在 Luna 首次失败发生于 Luna 写入任何 owned file 之前，Sol 才能把同一任务、同一 scope
一次升级到 Terra；不得无限重试 Luna。若 Luna 在失败前写入过任一 owned file，Luna 保留全部
ownership；只能给原 Luna owner 一次 focused fix，否则返回 `BLOCKED`。Terra 的写入状态不是
升级门槛，升级仍由 Sol 复核且不能绕过证据门槛。

## 可靠性来自边界

可靠性来自可证明的身份、所有权、证据新鲜度和有界修正，而不是来自配置里的一行标签。

### 运行时身份与失败关闭

| Agent | Model | Reasoning effort | Effective sandbox |
| --- | --- | --- | --- |
| `sol-controller` | `gpt-5.6-sol` | `high` | `read-only` |
| `luna-max-worker` | `gpt-5.6-luna` | `max` | `workspace-write`，受 parent 边界限制 |
| `terra-high-worker` | `gpt-5.6-terra` | `high` | `workspace-write`，受 parent 边界限制 |

启动时必须证明所选 custom agent、精确 model、reasoning effort 和有效权限边界。如果任一
身份或权限无法证明，runtime 会**失败关闭（Fail Closed）**，不会静默替换成相近的 model、
角色、effort 或 sandbox。Luna Max 与 Terra High 都不得 spawn 或 create subagents，不得
扩大写入范围、重写 Sol 的计划、批准整体任务，或把部分结果当作交付。

### 阶段、所有权、证据与修正

worker 交付不是最终批准；只有 Sol 审核过真实 diff 后才算完成。Evidence 必须绑定最终候选
身份，可以使用 commit+diff identity 或精确的 changed-file snapshot。验证后候选发生变化时，
旧证据立即失效，必须重跑受影响的验证。transport/spawn 的 `completed` 只表示投递生命周期
完成，不能替代结构化结果或 Sol review。

Sol 最多可以向原 owner、原 scope 发出一次 focused correction。第二次失败、缺少依赖或扩大
scope 都是 `BLOCKED`。Correction Packet 必须带 `Failure class` 与 `Delta`；相同任务包且
没有新证据时不得重新 launch。长任务才生成含 `goal`、`completed`、`in_flight`、
`artifact_location`、`next_action` 的 resume packet；短任务和 Direct 任务不生成。

结果包保持可机器解析并且可证伪：

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

## 成本模型与证据边界

这个模型区分 API token 的美元价格与 subscription credit 所代表的容量。官方来源是
[OpenAI model comparison](https://developers.openai.com/api/docs/models/compare)和官方
[Codex rate card](https://help.openai.com/en/articles/20001106-codex-rate-card)。本快照日期为
**2026-08-03**；发布前请重新检查两个来源。

### 每 1M tokens 的 API 价格

| Model | Input | Cached input | Output |
| --- | ---: | ---: | ---: |
| GPT-5.6 Sol | $5.00 | $0.50 | $30.00 |
| GPT-5.6 Terra | $2.00 | $0.20 | $12.00 |
| GPT-5.6 Luna | $0.20 | $0.02 | $1.20 |

### 每 1M tokens 的 Codex credits

| Model | Input | Cached input | Output |
| --- | ---: | ---: | ---: |
| GPT-5.6 Sol | 125 | 12.5 | 750 |
| GPT-5.6 Terra | 50 | 5 | 300 |
| GPT-5.6 Luna | 5 | 0.5 | 30 |

以 Sol 为基线，当前相对比例是：Sol `1.0x`、Terra `0.4x`、Luna `0.04x`。简单可复算的
混合公式为：

```text
route_cost = sol_share * 1.0 + terra_share * 0.4 + luna_share * 0.04 + orchestration_overhead
saving = 1 - route_cost
```

其中三种 `*_share` 是按 token 口径分解的路由份额（每行合计为 1），
`orchestration_overhead` 是额外的 Sol 规划、审查、协调和必要返工相对成本。将下表各份额与
开销代入即可独立复算区间，不把额度比例误读成时间承诺：

| 场景 | 可复算假设（shares 合计 1） | route_cost → saving |
| --- | --- | --- |
| 普通明确任务 | `sol=.10, terra=.20, luna=.70, overhead=.03-.07` | `.208+(.03-.07)=.238-.278` → **72.2%-76.2%** |
| 混合项目 | `sol=.20, terra=.40, luna=.40, overhead=.02-.12` | `.376+(.02-.12)=.396-.496` → **50.4%-60.4%** |
| 复杂直接额度 | `sol=.25, terra=.60, luna=.15, overhead=.07-.17` | `.496+(.07-.17)=.566-.666` → **33.4%-43.4%** |

| 场景 | 当前公开预算区间 |
| --- | ---: |
| 普通明确任务 / Ordinary clear task | 72%–76% |
| 混合项目 / Mixed project | 50%–60% |
| 复杂直接额度 / Complex direct allocation | 33%–43% |
| 综合中心 / Composite center | 约 56% / about 56% |

这些区间是预算规划口径，不是匹配 A/B 的已完成实验，也不是每个任务的保证；新混合路由不能被描述为已完成 A/B。
额度节省不等于时间一定更快，实际取决于 token 总量、上下文重复、Sol 审查、并行等待和返工。
API 用户看到的是美元金额；subscription（订阅）用户主要获得可用容量或 credits，API 美元
节省与订阅容量不是同一个结论。

公开证据标签保持 `measured`（已有路由/验证记录）、`scenario_model_projection`（基于官方费率与场景份额复算的预算区间）和
`unavailable`（资料未暴露）。本页成本不是新匹配 A/B 实测，也不是样本验证成本；路由样本的实测记录与成本投影分开。

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
不宣称已有原生 Windows 11 证据。生命周期会保留 `~/.codex/config.toml` 和无关 agent，
卸载只删除记录的 `SHA256` 仍匹配的 owned targets；`-RestoreLatest` / `--restore-latest`
在移除 owned installation 后恢复最近一次有效备份。发布时的运行表面与证据状态见
[`docs/release/runtime-surface-matrix.md`](docs/release/runtime-surface-matrix.md)。

## 真实项目路由样本

这些是匿名的本地真实项目路由样本，用于说明 Direct、Sol-only 和有界 worker 路径；本地项目测试样本验证仅用于路由上下文，它们不是
新混合路由的成本 A/B 基准。我们只允许最少的只读探针补齐材料，没有修改任何业务项目。

| 匿名类别 | 路由 | Luna / Terra | 验证 | Sol 终审 | 耗时 |
| --- | --- | --- | --- | --- | ---: |
| 代码项目 | `sol_then_luna`（路由样本） | 不可得 | 有证据 | `BLOCKED` | 2340 秒 |
| 文档项目 | `sol_then_luna`（路由样本） | 不可得 | 有证据 | `PASS` | 379 秒 |
| 基础设施项目 | `direct`（路由样本） | 0 | 有证据 | 不适用 | 859 秒 |

路由样本不证明新 Terra 混合路径已经完成 A/B，也不把额度区间升级为时间或生产保证。
完整方法、匿名结果和限制见 [`tests/real-project-benchmark.md`](tests/real-project-benchmark.md)。

## 仓库与开发验证

### 仓库布局

```text
.agents/skills/sol-luna/       public Skill 与运行参考
.codex/agents/                 精确的 Sol、Luna 与 Terra custom-agent 定义
  sol-controller.toml
  luna-max-worker.toml
  terra-high-worker.toml
scripts/                       macOS/Linux 生命周期与验证脚本
tests/                         contract、forward-case 与生命周期测试
docs/assets/readme/            仓库自有本地化 Control Orbit hero 与 control-plane SVG
README.md                      默认简体中文指南
README.en.md                   完整的 English peer
```

公开 Skill 是 [`$sol-luna`](.agents/skills/sol-luna/SKILL.md)。精确的 agent 定义见
[`sol-controller.toml`](.codex/agents/sol-controller.toml)、[`luna-max-worker.toml`](.codex/agents/luna-max-worker.toml)
与 [`terra-high-worker.toml`](.codex/agents/terra-high-worker.toml)。全局 Skill 与 agent 目录
只是安装副本；GitHub 是事实来源。

### 测试

使用 Python 3.11 或更高版本运行文档、路由 contract 和 benchmark：

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest tests.test_readme -v
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest tests.test_hybrid_routing.ReadmeCostContractTests -v
python -m unittest tests/test_contract.py
python -m unittest tests/test_benchmark.py
```

文档 contract 检查双语语言切换与 parity、规范仓库链接、本地图片目标、可访问 SVG
元数据、章节顺序、当前价格行、混合公式、预算区间和适用边界。benchmark 报告区分
`measured`、`scenario_model_projection`、`unavailable` 三类证据；若 PowerShell 可用，
生命周期测试还会使用 `ORCHESTRATE_HOME` 验证隔离 home，并确认 `config.toml` 与无关 agent
的 hash 保持不变。

## 限制

- 预算区间用于路由规划，不保证每项任务或每个 token 组合得到相同节省。
- 委派会增加计划、上下文、审查和可能的 retry token；重试可能抵消或反转额度节省。
- 额度节省不等于时间一定更快；并行等待、上下文重复和返工会改变实际结果。
- GitHub 托管 Windows runner 建立的是 Windows Server 行为，不是原生 Windows 11 行为。
- Skill 只有一个 Sol controller，Luna Max 与 Terra High 是按风险分级的有界执行者；它不是固定
  三 Agent 团队，也不是通用的多 agent team 框架。
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
