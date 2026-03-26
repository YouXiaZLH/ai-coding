# 战斗HUD与商店UI

> **Status**: Approved
> **Author**: 用户 + GitHub Copilot
> **Last Updated**: 2026-03-25
> **Implements Pillar**: 低门槛高上限、5分钟一局、羁绊优先

## Overview

战斗HUD与商店UI负责把状态机各阶段的关键信息以“少而准”的方式呈现给玩家，并提供部署与运营所需的最小可操作入口。系统目标是在 5 分钟单局内实现低学习成本与高决策效率：玩家一眼看懂当前阶段、核心资源和下一步可执行动作，不被冗余信息干扰。

## Player Fantasy

玩家应感受到“我随时知道该做什么、为什么这么做”。战斗时看清胜负走势与关键触发，商店时快速判断买/刷/锁，结算时明确本波得失与下一波准备方向。信息应服务决策，而非制造负担。

## Detailed Design

### Core Rules

1. UI 展示严格跟随状态机阶段切换：`SHOP`、`DEPLOY`、`BATTLE`、`RESOLVE`。
2. 每阶段仅显示“决策必需信息”，非关键信息默认折叠到次级层。
3. 顶部常驻信息最小集：`wave`、`wave_type`、`gold`、`hp`、`phase_timer`。
4. `SHOP` 阶段开启商店面板与操作按钮；非 `SHOP` 阶段统一置灰并禁用写操作。
5. `DEPLOY` 阶段显示九宫格可落点、已上阵数、候场容量与锁阵入口。
6. `BATTLE` 阶段显示双方存活数、战斗计时、关键单位能量条与波次标签。
7. `RESOLVE` 阶段展示固定顺序：胜负 -> 生命变化 -> 金币变化 -> 连胜变化。
8. 所有数值显示必须基于最新 `revision`（economy/layout/resource）避免旧数据闪回。
9. 错误反馈统一样式：文本提示 + 图标 + 可选短音效，不弹阻塞弹窗。
10. 调试模式可显示扩展字段（seed、version、revision），正式模式隐藏。

### States and Transitions

- `Dormant`：系统未激活或非对局场景。
- `PhaseBound`：已绑定当前阶段 UI 布局。
- `Interactive`：允许玩家输入（商店/布阵）。
- `ReadOnly`：战斗中与结算中仅展示反馈。
- `Syncing`：接收事件流并刷新 UI 快照。

合法转移：`Dormant -> PhaseBound -> (Interactive | ReadOnly) <-> Syncing -> PhaseBound`。

### Interactions with Other Systems

- `对局状态机`：提供阶段切换、倒计时与状态事件。
- `九宫格布阵规则`：提供棋盘占位、可落点、layout_revision 与锁阵状态。
- `招募商店与刷新经济`：提供商店槽位、交易结果、economy_revision、锁店状态。
- `自动战斗结算`：提供战斗关键事件、双方存活、计时、结算摘要。
- `羁绊判定与加成`：提供已激活羁绊与下一档差值用于 HUD 标签。
- `波次生成（普通/精英/Boss）`：提供波次类型与敌情提示标签。
- `局内资源与奖励流`：提供 RESOLVE 明细与 resource_revision。
- `平衡参数配置表`：提供 UI 显示阈值（如低血警戒线、提示开关）。

## Formulas

### 经济预测（商店阶段）

$$
Gold_{next\,preview}=Gold_{current}-Spend_{planned}+Interest_{est}+Reward_{est}
$$

用于展示“下一波可用金币预测”，仅作预估不写回。

### 战斗进度条

$$
Progress = clamp(Elapsed / BattleTimeout, 0, 1)
$$

### 低血警戒

$$
LowHP = \mathbf{1}[HP \le HP_{warn}]
$$

`HP_warn` 由参数表提供，MVP 默认 `5`。

### 羁绊进度

$$
NeedNextTier = \max(0, Threshold_{next} - Count_{current})
$$

### UI 刷新一致性条件

$$
Apply(snapshot_{new}) \iff revision_{new} \ge revision_{current}
$$

### 结算面板排序规则

$$
Order = [Result, HP\Delta, Gold\Delta, Streak\Delta]
$$

## Edge Cases

1. 阶段切换与按钮点击同帧：以状态机阶段为准，过期输入拒绝。
2. 商店已关闭仍触发购买按钮：前端立即禁用并提示 `shop_closed`。
3. 候场已满购买：显示 `bench_full`，不刷新商店槽位。
4. 结算事件迟到导致旧值覆盖：按 `resource_revision` 丢弃旧包。
5. 战斗结束与超时提示同时出现：仅保留最终胜负原因文案。
6. 波次标签缺失：回退显示 `Wave {index}` 并记录日志。
7. 低端机帧率下降：降级关闭非关键动画，保留数值更新。
8. 后台恢复后 UI 状态错层：强制重新绑定当前阶段模板。
9. 调试字段在发布构建泄漏：构建检查阻断。
10. 文案键缺失：使用默认文案并上报 `missing_localization_key`。

## Dependencies

### 上游依赖（Hard）

- `对局状态机`：提供阶段与计时生命周期。
- `九宫格布阵规则`：提供部署态数据与写入反馈。
- `招募商店与刷新经济`：提供商店数据与经济写回反馈。
- `自动战斗结算`：提供战斗事件与结果摘要。
- `局内资源与奖励流`：提供结算数据与资源修订号。

### 下游依赖

1. `战斗反馈系统（伤害/羁绊提示/VFX/SFX）`（Hard）：消费 UI 事件锚点触发表现。
2. `新手引导与失败复盘`（Hard）：消费 HUD 结构与关键节点埋点。
3. `Playtest事件日志`（Soft）：消费玩家操作轨迹与提示触发数据。

### 接口契约

- 输入最小字段：`phase,wave,wave_type,gold,hp,timer,revisions`。
- 输出最小字段：`ui_state,disabled_actions,ui_event_log`。
- 交互请求必须携带当前 `phase` 与对应 `revision`，后端只接受匹配版本。

## Tuning Knobs

| Knob | 默认值 | 范围 | 说明 |
|---|---:|---:|---|
| `hud_minimal_mode` | true | bool | 是否启用极简 HUD |
| `hp_warn_threshold` | 5 | 1–10 | 低血警戒阈值 |
| `show_enemy_hint` | true | bool | 是否显示敌情标签 |
| `shop_preview_next_gold` | true | bool | 显示下一波金币预测 |
| `resolve_panel_auto_close_sec` | 2.0 | 1.0–4.0 | 结算面板自动关闭时间 |
| `ui_error_toast_duration_sec` | 1.2 | 0.6–3.0 | 错误提示显示时长 |
| `battle_hud_energy_focus_count` | 1 | 1–3 | 显示能量条的关键单位数量 |
| `disable_non_critical_animations_low_fps` | true | bool | 低帧率降级开关 |
| `debug_overlay_enabled` | false(prod) | bool | 调试覆盖层开关 |
| `ui_refresh_throttle_ms` | 50 | 16–120 | UI 刷新节流 |

## Visual/Audio Requirements

- `SHOP`：刷新与购买使用轻量过渡（<200ms），失败操作有统一负反馈音。
- `DEPLOY`：可落点高亮、非法格红色禁用提示、锁阵按钮确认反馈。
- `BATTLE`：顶部 HUD 稳定显示存活数与计时，不被次要特效遮挡。
- `RESOLVE`：固定顺序展示奖励与惩罚，Boss 波可附加强化反馈（<300ms）。

## UI Requirements

- 常驻顶栏：波次、类型、金币、生命、阶段倒计时。
- 商店区：5 槽位卡片、刷新按钮、锁店按钮、预计利息/下一波金币预估。
- 布阵区：3x3 棋盘、候场 `x/8`、已上阵 `x/9`、锁阵按钮。
- 战斗区：双方存活计数、战斗进度条、我方关键单位能量条。
- 结算区：胜负标题、HP变化、金币变化、连胜变化、继续按钮/自动进入下一阶段。
- 调试区（开发模式）：显示 `match_seed`、`balance_data_version`、各 revision。

## Acceptance Criteria

1. 四阶段 UI 切换正确，无错层和按钮越权。
2. `SHOP/DEPLOY` 可交互，`BATTLE/RESOLVE` 只读展示稳定。
3. 商店与布阵的非法操作提示可达且不阻塞流程。
4. 所有关键数值显示与后端 revision 对齐，无旧值覆盖。
5. 结算面板顺序固定且字段完整率 `100%`。
6. 低端设备在降级模式下仍保持核心信息可读。
7. 新手 3 局内可理解“看哪里、点哪里、下一步做什么”。
8. 调试字段不会出现在发布构建。
9. 与战斗反馈系统事件锚点接口稳定（事件命名一致）。
10. 平均 UI 交互响应时间 `< 100ms`（MVP 目标机）。

## Open Questions

1. 是否在 MVP 显示“敌情摘要”（高前排压力/高爆发）还是仅显示波次类型？（Owner: `ux-designer`）
2. 商店是否需要“锁店成功”单独动画，还是只用图标状态变更？（Owner: `ui-programmer`）
3. 战斗中能量条显示 1 名核心单位还是前 3 名更易理解？（Owner: `game-designer`）
4. 结算面板是否允许一键跳过，还是保持固定停留时长？（Owner: `producer`）
