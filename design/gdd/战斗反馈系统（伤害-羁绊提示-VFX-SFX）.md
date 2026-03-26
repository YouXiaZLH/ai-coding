# 战斗反馈系统（伤害/羁绊提示/VFX/SFX）

> **Status**: Approved
> **Author**: 用户 + GitHub Copilot
> **Last Updated**: 2026-03-25
> **Implements Pillar**: 羁绊优先、站位博弈、低门槛高上限

## Overview

战斗反馈系统负责把自动战斗中的关键事件转化为玩家可感知的视觉与听觉信息，包括伤害命中、技能释放、羁绊触发、击杀与阶段切换提示。系统目标是在不增加操作负担的前提下提升“可解释性”和“爽感”：玩家能快速看懂为什么赢/输，并从反馈中感知阵容与站位决策是否生效。

## Player Fantasy

玩家应感受到“我的阵容真的在发力”。当羁绊升档、核心技能命中、关键单位被击杀时，反馈要明显且层次分明；普通事件不喧宾夺主，关键事件一定被看见、被听见。失败也应有清晰信号，支持快速复盘和下一局调整。

## Detailed Design

### Core Rules

1. 反馈系统只消费事件流，不参与战斗数值计算与胜负判定。
2. 事件按优先级分层：`Critical`（终局/Boss/羁绊升档）> `Major`（技能/击杀）> `Minor`（普攻命中/受击）。
3. 同帧多事件采用“关键优先 + 普通合并”策略，防止屏幕与音频过载。
4. 伤害反馈至少包含：命中标记、数值飘字或受击闪烁（二选一可配置）。
5. 技能释放必须具备独立音效和可辨识视觉前摇（不低于 80ms）。
6. 羁绊层级变化必须触发统一提示事件 `synergy_tier_changed`，首次激活与升档表现强度不同。
7. 击杀反馈在单位死亡后 `<=300ms` 内完成，不阻塞战斗推进。
8. Boss 波与精英波反馈强度可提升，但持续时间受上限约束，避免拖慢节奏。
9. 所有反馈资源通过标签检索（`hit/skill/synergy/kill/wave/ui`），便于替换与扩展。
10. 低性能模式自动降级非关键特效，保留关键提示与音频层级。

### States and Transitions

- `Idle`：非战斗阶段，仅监听阶段切换提示。
- `Listening`：监听战斗事件并入队。
- `Dispatching`：按优先级分发到 VFX/SFX 渲染通道。
- `Cooling`：对重复事件执行冷却抑制，避免刷屏。
- `Stopped`：战斗结束，清空队列并保留摘要统计。

合法转移：`Idle -> Listening -> Dispatching <-> Cooling -> Listening -> Stopped -> Idle`。

### Interactions with Other Systems

- `自动战斗结算`：提供命中、技能、死亡、超时等关键事件。
- `羁绊判定与加成`：提供羁绊激活/升档/降档事件。
- `战斗HUD与商店UI`：提供反馈锚点位置信息与提示容器层级。
- `波次生成（普通/精英/Boss）`：提供波次类型用于反馈强度调制。
- `平衡参数配置表`：提供反馈开关、强度系数、冷却阈值。
- `对局状态机`：提供阶段切换事件（进入战斗、结算、终局）。
- `Playtest事件日志`：记录反馈触发频率、覆盖率与被抑制比率。

## Formulas

### 反馈强度分数

$$
FeedbackScore = EventWeight \cdot PhaseMul \cdot ImportanceMul
$$

其中 `EventWeight` 由事件类型确定，`PhaseMul` 由波次/Boss 状态调节。

### 同帧事件抑制

$$
DisplayCount_{frame} = \min(N_{max}, EventCount_{frame})
$$

超出部分进入合并队列或延后队列。

### 音量混合上限

$$
MixVolume = \min(V_{cap}, \sum_i v_i \cdot p_i)
$$

防止多音效叠加爆音，`p_i` 为优先级衰减系数。

### 重复提示冷却

$$
Allow(event_k) = \mathbf{1}[t_{now} - t_{last}(k) \ge cd_k]
$$

### 关键事件可见性约束

$$
CriticalVisibleRate = \frac{shown_{critical}}{total_{critical}} \ge 0.99
$$

### 低性能降级策略

$$
if\ FPS < FPS_{threshold} \Rightarrow disable(non\_critical\_vfx)
$$

## Edge Cases

1. 同一目标同 tick 多段伤害：合并为单个飘字组，保留总伤害和段数标记。
2. 技能释放与单位死亡同帧：先展示死亡，再展示技能失败/空放提示（若存在）。
3. 羁绊升档与降档连续抖动：对同羁绊提示加冷却，避免闪烁刷屏。
4. 资源缺失（特效或音效文件找不到）：回退通用反馈并记录 `feedback_asset_missing`。
5. 低帧率下事件堆积：仅保留 `Critical/Major`，`Minor` 走摘要模式。
6. 静音模式：保留视觉反馈，音频通道不派发但照常记日志。
7. 后台恢复触发延迟事件：丢弃过期事件（超出时窗）并重置队列。
8. HUD 锚点失效：回退到屏幕安全区统一提示层。
9. 同名事件重复上报：按 `event_id + tick` 幂等去重。
10. Boss 过场与战斗事件冲突：过场优先，战斗反馈延后队列最多 `500ms`。

## Dependencies

### 上游依赖（Hard）

- `自动战斗结算`：提供战斗事件主流。
- `羁绊判定与加成`：提供羁绊触发事件。
- `战斗HUD与商店UI`：提供表现锚点与层级容器。

### 下游依赖

1. `新手引导与失败复盘`（Hard）：消费关键反馈事件用于教学与复盘指引。
2. `设置与可访问性增强`（Hard）：消费反馈分组开关（音量、强度、闪烁简化）。
3. `Playtest事件日志`（Soft）：消费反馈覆盖与抑制统计。

### 接口契约

- 输入最小字段：`event_id,event_type,tick,actor_id,target_id,priority,payload`。
- 输出最小字段：`feedback_dispatched,channel(vfx/sfx/ui),intensity,cooldown_applied`。
- 同一 `event_id + tick` 只允许一次有效派发，重复请求必须幂等。

## Tuning Knobs

| Knob | 默认值 | 范围 | 说明 |
|---|---:|---:|---|
| `feedback_minor_max_per_frame` | 4 | 1–12 | 单帧普通反馈最大显示数 |
| `feedback_major_max_per_frame` | 2 | 1–6 | 单帧重要反馈最大显示数 |
| `critical_event_cooldown_ms` | 0 | 0–500 | 关键事件冷却 |
| `minor_event_cooldown_ms` | 120 | 50–400 | 普通事件冷却 |
| `vfx_intensity_scale` | 1.0 | 0.5–1.5 | 特效强度系数 |
| `sfx_master_scale` | 1.0 | 0–1.5 | 音效总强度系数 |
| `synergy_flash_duration_ms` | 220 | 100–500 | 羁绊提示持续时间 |
| `kill_banner_duration_ms` | 280 | 150–600 | 击杀提示持续时间 |
| `low_fps_threshold` | 28 | 20–45 | 低帧率降级阈值 |
| `fallback_feedback_enabled` | true | bool | 资源缺失时是否启用通用反馈 |

## Visual/Audio Requirements

- 命中反馈：默认飘字 + 轻受击闪烁，暴击使用强化色与独立音效。
- 技能反馈：施放前摇、命中落点、收束音效三段式（可按技能裁剪）。
- 羁绊反馈：首次激活中强度，升档高强度，降档弱提示。
- 击杀反馈：单位退场 + 击杀标识 + 短促确认音。
- 波次反馈：精英/Boss 开场提示不超过 `300ms`，避免打断输入节奏。

## UI Requirements

- 战斗中反馈层位于 HUD 下方、单位层上方，不遮挡顶栏核心数值。
- 提供反馈开关（开发模式）：`show_hit_number`、`show_synergy_popup`、`sfx_only_critical`。
- 超时结算时必须展示“超时按剩余战力判定”的统一文案反馈。
- 调试面板可查看最近 `N` 条反馈派发记录和被抑制原因。

## Acceptance Criteria

1. 命中/技能/羁绊/击杀四类反馈可稳定触发，字段完整率 `100%`。
2. 同种子回放下关键反馈时间轴一致（允许普通反馈合并差异）。
3. 关键事件可见率 `>=99%`，普通事件不会造成刷屏。
4. 低帧率降级生效后，战斗可读性仍满足 MVP 要求。
5. 资源缺失场景可自动回退通用反馈且不崩溃。
6. 音频混音无爆音、无明显削波，峰值受 `V_cap` 约束。
7. 与 HUD 层级不冲突，不遮挡波次/血量/金币核心信息。
8. 反馈系统平均派发耗时 `<0.3ms`（MVP 规模）。
9. 幂等去重生效，不出现同事件重复派发。
10. 玩家可在 3 局内通过反馈识别至少一种羁绊触发与一次关键击杀时机。

## Open Questions

1. MVP 是否保留完整伤害飘字，还是仅保留暴击与技能伤害以降低噪声？（Owner: `ux-designer`）
2. 羁绊升档提示是否需要独立语音/播报，还是仅视觉+短音效？（Owner: `sound-designer`）
3. 低性能模式下优先保留哪些反馈（技能、击杀、羁绊）的排序是否固定？（Owner: `technical-artist`）
4. 关键击杀是否需要“慢放/顿帧”效果，还是保持纯实时避免打断节奏？（Owner: `game-designer`）
