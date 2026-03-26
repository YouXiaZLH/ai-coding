# 波次生成（普通/精英/Boss）

> **Status**: Approved
> **Author**: 用户 + GitHub Copilot
> **Last Updated**: 2026-03-25
> **Implements Pillar**: 5分钟一局、羁绊优先、站位博弈

## Overview

波次生成系统负责在每轮 `WAVE_PREPARE` 阶段生成敌方编队与战斗参数，形成“普通 -> 精英 -> Boss”递进压力曲线。系统目标是在短局中建立清晰的前中后节奏：第一波教学与试探、第二波检定转型、第三波终局挑战，并确保随机性可复现、难度可调、失败可解释。

## Player Fantasy

玩家应感受到“我在打有层次的军演，而不是三次重复战斗”。普通波让我快速建立优势，精英波要求我修正短板，Boss波检验我的构筑与站位是否真正成型。每波的敌人组合和机制都应有明确意图。

## Detailed Design

### Core Rules

1. 单局固定 3 波：`Wave1=普通`、`Wave2=精英`、`Wave3=Boss`。
2. 仅在状态机 `WAVE_PREPARE` 阶段生成波次，不在战斗中热切换。
3. 每波由三部分组成：`enemy_roster`（敌方单位清单）、`spawn_layout`（初始站位）、`wave_modifiers`（波次修正）。
4. 生成输入必须包含：`match_id`、`wave_index`、`seed`、`difficulty_profile`。
5. 普通波优先生成低复杂度敌人组合，保证新手可读。
6. 精英波引入“单点强势+配套前排”结构，测试玩家中期调整能力。
7. Boss 波必须包含 1 个 Boss 核心单位，并附带 2~4 个护卫或机制单位。
8. 敌方单位来源于武将/羁绊数据模型中的敌方可用池（可与玩家池不同）。
9. 波次强度通过目标战力区间控制，不直接硬编码固定阵容。
10. 所有波次生成结果写入日志，支持同种子回放与难度分析。

### States and Transitions

- `Idle`：非准备阶段，不响应生成请求。
- `Preparing`：读取参数、抽样候选、构建波次内容。
- `Validated`：完成合法性校验（数量、坐标、Boss存在性）。
- `Published`：输出 `wave_payload_ready` 给状态机。

合法转移：`Idle -> Preparing -> Validated -> Published -> Idle`。

### Interactions with Other Systems

- `对局状态机`：主调方，在 `WAVE_PREPARE` 请求生成并消费 `wave_payload_ready`。
- `武将/羁绊数据模型`：提供敌方单位模板、标签与基础属性。
- `RNG与随机种子管理`：提供可复现抽样序列。
- `平衡参数配置表`：提供各波目标战力、费用权重、Boss机制参数。
- `自动战斗结算`：消费 `enemy_roster` 与 `spawn_layout` 开始战斗。
- `局内资源与奖励流`：消费波次类型与难度系数用于奖励/惩罚映射。
- `战斗HUD与商店UI`：展示当前波次类型与预警标签（精英/Boss）。
- `Playtest事件日志`：记录每波生成摘要、实际耗时、胜负表现。

## Formulas

### 目标波次战力

$$
TargetPower_w = BasePower_w \cdot DiffMul \cdot RunMul
$$

MVP 默认：`BasePower = [120, 180, 260]`（Wave1/2/3）。

### 敌方编队战力

$$
RosterPower = \sum_{u\in enemy\_roster} Power(u)
$$

其中 `Power(u)` 来自数据模型的单位战力估算。

### 战力偏差约束

$$
|RosterPower - TargetPower_w| \le \epsilon_w
$$

MVP 建议：`ε = [25, 30, 40]`。

### 费用层抽样概率

$$
P(cost=k\mid wave=w)=W^{enemy}_{w,k}/\sum_j W^{enemy}_{w,j}
$$

建议（1~4费）：
- Wave1: `[70,25,5,0]`
- Wave2: `[45,35,18,2]`
- Wave3: `[20,35,30,15]`

### Boss 波校验

$$
BossValid = \mathbf{1}[\exists u\in enemy\_roster: isBoss(u)=true]
$$

若 `BossValid=0`，则强制替换一个槽位为 Boss 候选。

### 难度微调（可选动态）

$$
RunMul = 1 + \delta\cdot PerformanceIndex
$$

MVP 默认 `δ=0`（关闭动态难度，仅保留静态曲线）。

## Edge Cases

1. 抽样后敌方数量为 0：回退到保底模板（最低普通波编队）。
2. Boss 波未抽到 Boss：强制插入 Boss 并重平衡护卫。
3. 敌方站位冲突：按布局优先级重排，仍冲突则回退默认阵型。
4. 敌方池配置缺失：终止本次生成并使用内置兜底波次。
5. 同帧重复请求生成：按 `match_id+wave_index` 幂等返回同一结果。
6. 战力偏差长期超阈值：增加重采样次数上限并记录告警。
7. 随机种子非法/缺失：回退到状态机派生种子并记录 `seed_recovered`。
8. 精英/Boss标签与实际阵容不符：发布前校验失败并阻止发布。
9. 后台恢复触发重复 `WAVE_PREPARE`：直接返回已发布缓存结果。
10. 敌方单位引用无效ID：剔除并补抽，最终仍无效则走兜底模板。

## Dependencies

### 上游依赖（Hard）

- `对局状态机`：提供波次索引与调用时机。
- `武将/羁绊数据模型`：提供敌方单位模板与战力字段。
- `RNG与随机种子管理`：保证生成可复现。
- `平衡参数配置表`：提供难度与抽样参数。

### 下游依赖

1. `自动战斗结算`（Hard）：消费敌方阵容与布局。
2. `局内资源与奖励流`（Hard）：消费波次类型和难度参数。
3. `战斗HUD与商店UI`（Hard）：显示波次提示与敌方预警。
4. `Playtest事件日志`（Soft）：消费波次生成摘要。

### 接口契约

- 输入最小字段：`match_id,wave_index,seed,difficulty_profile,player_snapshot`。
- 输出最小字段：`wave_type,enemy_roster,spawn_layout,wave_modifiers,wave_revision`。
- 同一输入键必须生成确定性输出（同 seed + 同参数）。

## Tuning Knobs

| Knob | 默认值 | 范围 | 说明 |
|---|---:|---:|---|
| `wave_count` | 3 | 3–5 | 总波次数 |
| `base_power_wave1` | 120 | 80–180 | 普通波目标战力 |
| `base_power_wave2` | 180 | 120–260 | 精英波目标战力 |
| `base_power_wave3` | 260 | 180–360 | Boss波目标战力 |
| `power_tolerance_wave1` | 25 | 10–50 | 普通波战力偏差 |
| `power_tolerance_wave2` | 30 | 10–60 | 精英波战力偏差 |
| `power_tolerance_wave3` | 40 | 15–80 | Boss波战力偏差 |
| `enemy_weights_wave1` | [70,25,5,0] | 总和100 | 普通波费率权重 |
| `enemy_weights_wave2` | [45,35,18,2] | 总和100 | 精英波费率权重 |
| `enemy_weights_wave3` | [20,35,30,15] | 总和100 | Boss波费率权重 |
| `boss_guard_count` | 3 | 2–5 | Boss护卫数量 |
| `resample_max_retry` | 5 | 1–20 | 战力重采样上限 |
| `dynamic_difficulty_delta` | 0.0 | 0–0.3 | 动态难度系数 |

## Visual/Audio Requirements

- 进入精英/Boss波前提供明确提示（标题+短音效）。
- Boss波开场有独立视觉标识，避免玩家误判难度。
- 波次切换反馈应轻量（<300ms），不拖慢节奏。

## UI Requirements

- 顶部显示当前波次与类型标签（普通/精英/Boss）。
- 在 `WAVE_PREPARE` 阶段显示简要敌情提示（例如“高前排压力”）。
- 调试面板可查看本波 `TargetPower`、`RosterPower` 与抽样结果。

## Acceptance Criteria

1. 三波生成均可在 `WAVE_PREPARE` 正常发布，且字段完整率 `100%`。
2. 同种子重复运行 1000 次，波次生成结果一致。
3. 普通/精英/Boss 三波难度递进明显，战力曲线无反转。
4. Boss 波必含 Boss 单位，不出现漏Boss。
5. 敌方站位无重叠，坐标合法率 `100%`。
6. 配置缺失或非法时可降级到兜底模板，不阻塞对局。
7. 单次波次生成耗时 `< 1ms`（MVP 规模）。
8. 生成结果可被自动战斗直接消费，无额外补丁字段。
9. 日志可追溯每波抽样过程与最终阵容。
10. 玩家可感知三波节奏差异并理解 Boss 为最终检定。

## Open Questions

1. 精英波是否应固定带“反制主流羁绊”的机制单位以提高策略深度？（Owner: `game-designer`）
2. Boss波是否允许出现随机副机制（例如护盾/召唤）还是保持固定模板？（Owner: `systems-designer`）
3. 动态难度 `RunMul` 是否在 MVP 就开启，还是留到平衡阶段？（Owner: `systems-designer`）
4. 敌情提示是否会剧透过多，需不需要简化为抽象标签？（Owner: `ux-designer`）
