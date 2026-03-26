# 敌方AI目标选择

> **Status**: Approved
> **Author**: 用户 + GitHub Copilot
> **Last Updated**: 2026-03-25
> **Implements Pillar**: 站位博弈、羁绊优先、低门槛高上限

## Overview

敌方AI目标选择负责在自动战斗期间，为敌方单位按规则挑选攻击与技能目标。系统目标是让“站位、前后排保护、威胁管理”形成可感知博弈，同时保证行为稳定、可复现、可解释。该系统不直接结算伤害，只输出目标决策（target_id、reason_code、score_breakdown）供自动战斗执行。

## Player Fantasy

玩家应感受到“敌人很聪明，但不作弊”。当我把核心输出保护在后排时，敌方会优先处理前排；当我把脆皮暴露在危险位时，会被明显针对。玩家能从战后摘要理解敌方为什么换目标，而不是觉得随机乱打。

## Detailed Design

### Core Rules

1. 仅在 `BATTLE` 阶段运行；由自动战斗在单位行动时调用。
2. 每次决策输入包含：己方攻击者、候选目标列表、战场快照、随机种子、当前策略参数。
3. 候选池默认仅包含“存活且可达”的敌方单位。
4. 对每个候选目标计算威胁分（ThreatScore），选择最高分目标。
5. 若多目标同分，按稳定顺序决策：`distance` 更近优先，仍同则 `instance_id` 字典序。
6. 目标锁定窗口内（`retarget_lock_ms`）优先保持当前目标，避免抖动换目标。
7. 当目标死亡、不可达或脱离可选池时，立即触发重选。
8. 技能可使用独立策略（如“最低血量优先”或“后排优先”），若未配置则复用普攻策略。
9. AI不得读取隐藏信息（例如未来随机结果、玩家未公开意图）。
10. 所有目标切换需输出 `reason_code`（如 `target_dead`、`higher_threat_found`、`forced_retarget`）。

### States and Transitions

- `Idle`：非战斗阶段，不接收目标查询。
- `Ready`：战斗中，等待自动战斗发起查询。
- `Evaluating`：计算候选评分并生成决策。
- `Locked`：短时间目标锁定，直到失效条件触发。

合法转移：`Idle -> Ready -> Evaluating -> Locked -> Evaluating`（循环）-> `Idle`。

### Interactions with Other Systems

- `自动战斗结算`：主调方；传入候选池与上下文，消费 `target_id` 与解释字段。
- `九宫格布阵规则`：提供前后排、邻接、距离等空间上下文。
- `武将/羁绊数据模型`：提供单位角色标签、当前生命、威胁权重所需属性。
- `羁绊判定与加成`：可提供目标偏好修正（例如“优先攻击召唤物/后排”）。
- `Playtest事件日志`：记录目标选择轨迹，用于复盘与参数调优。
- `战斗HUD与商店UI`：调试模式展示“当前仇恨目标”和换目标原因。

## Formulas

### 基础威胁分

$$
Threat(t)=w_{dps}\cdot DPS(t)+w_{lowhp}\cdot (1-HP\%_t)+w_{back}\cdot Backline(t)+w_{near}\cdot Near(t)+w_{focus}\cdot Focus(t)
$$

其中：
- $HP\%_t=HP_t/HP_{max,t}$
- $Backline(t)\in\{0,1\}$（后排为1）
- $Near(t)=1/(1+dist(attacker,t))$
- $Focus(t)$ 为已有友军集火度（0~1）

### 可达性过滤

$$
Candidate(t)=Alive(t)\land Reachable(attacker,t)
$$

仅当 `Candidate(t)=true` 才参与评分。

### 锁定惩罚（减少频繁换目标）

$$
Threat'(t)=Threat(t)-\lambda\cdot SwitchPenalty(t)
$$

$$
SwitchPenalty(t)=\begin{cases}
0, & t=current\_target \\
1, & t\neq current\_target
\end{cases}
$$

### 重选触发条件

$$
Retarget = TargetDead \lor TargetUnreachable \lor \Delta Threat > \theta
$$

### 技能目标评分（默认）

$$
SkillScore(t)=a\cdot Threat(t)+b\cdot ClusterValue(t)+c\cdot KillPotential(t)
$$

用于 AOE/斩杀技能的目标偏好。

## Edge Cases

1. 候选池为空：返回 `no_target`，本次攻击跳过并记录日志。
2. 同分目标过多：使用稳定 tie-break，保证同种子可复现。
3. 目标在命中前死亡：立即重选；若仍无目标则动作作废。
4. 距离函数返回异常（负值/NaN）：该目标记为不可达并报警。
5. 锁定期间出现极高威胁新目标：仅当 `ΔThreat > θ` 允许打破锁定。
6. 单位被控制（嘲讽/致盲等后续机制）：优先服从控制规则覆盖普通决策。
7. 切后台恢复导致时间跃迁：锁定计时按恢复后的逻辑时钟重算。
8. AOE 技能无合法中心点：回退到普攻策略目标。
9. 大量召唤物导致评分开销上升：启用候选截断（Top-K 预筛）。
10. 重复查询同一帧：使用 `match_id+wave+tick+attacker_id` 幂等缓存。

## Dependencies

### 上游依赖（Hard）

- `自动战斗结算`：提供查询时机、候选池与执行上下文。
- `武将/羁绊数据模型`：提供单位实时状态与标签。
- `九宫格布阵规则`：提供空间信息（前后排、距离、邻接）。

### 下游依赖

1. `Playtest事件日志`（Soft）：消费目标决策轨迹。
2. `战斗HUD与商店UI`（Soft/Debug）：展示目标箭头、原因码。
3. `战斗反馈系统（伤害/羁绊提示/VFX/SFX）`（Soft）：可消费“被锁定/被集火”事件。

### 接口契约

- 输入最小字段：`match_id,wave,tick,attacker_id,candidate_ids,battle_snapshot,seed`。
- 输出最小字段：`target_id,reason_code,score_breakdown,retargeted`。
- 同一输入键必须返回确定性结果（同 seed + 同快照）。

## Tuning Knobs

| Knob | 默认值 | 范围 | 说明 |
|---|---:|---:|---|
| `w_dps` | 0.45 | 0–1.5 | 优先攻击高输出目标权重 |
| `w_lowhp` | 0.20 | 0–1.0 | 收割低血目标权重 |
| `w_back` | 0.15 | 0–1.0 | 后排偏好权重 |
| `w_near` | 0.10 | 0–1.0 | 近距离偏好权重 |
| `w_focus` | 0.10 | 0–1.0 | 集火倾向权重 |
| `retarget_lock_ms` | 800 | 0–2000 | 目标锁定时长 |
| `retarget_threshold` | 0.25 | 0–1.5 | 打破锁定阈值 θ |
| `switch_penalty_lambda` | 0.18 | 0–1.0 | 换目标惩罚 λ |
| `candidate_top_k` | 6 | 3–12 | 候选预筛数量 |
| `skill_target_policy` | default | enum | 技能目标策略模板 |

## Visual/Audio Requirements

- 调试模式可显示敌方当前目标连线（细线，不影响正式 HUD）。
- 换目标事件可触发轻量提示（仅调试构建开启）。
- 被集火单位可有弱提示标记，便于复盘目标逻辑。

## UI Requirements

- 战后面板提供“敌方目标偏好摘要”：前3条目标切换原因。
- 开发调试页支持查看单单位最近 N 次目标选择记录。
- 若触发 `no_target`，调试 UI 显示候选过滤原因（死亡/不可达/控制覆盖）。

## Acceptance Criteria

1. 同种子同输入下，1000 次回放目标选择完全一致。
2. 目标选择单次开销在 MVP 规模下 `< 0.2ms`（9v9）。
3. 候选池为空、目标死亡、不可达等场景都能稳定收束且无崩溃。
4. 目标切换日志具备 `reason_code`，缺失率 `0`。
5. 锁定机制生效：无异常抖动换目标（阈值内不频繁切换）。
6. AI 仅使用公开战场信息，不读取隐藏/未来数据。
7. 自动战斗集成后，不出现“非法目标ID导致战斗中断”。
8. 调试模式可追溯任一单位最近目标决策链路。
9. 200 局模拟中目标策略调用无死循环、无超时。
10. 玩家复盘可理解至少一条“被针对原因”（后排暴露/低血收割/集火）。

## Open Questions

1. MVP 是否启用“后排强偏好”还是保持均衡偏好？（Owner: `game-designer`）
2. `Focus(t)` 是否按距离衰减，避免全图不合理集火？（Owner: `ai-programmer`）
3. 技能目标策略是否按角色类型配置（坦克/刺客/法师）？（Owner: `systems-designer`）
4. 调试可视化是否在移动端开发包默认关闭以节省性能？（Owner: `ui-programmer`）
