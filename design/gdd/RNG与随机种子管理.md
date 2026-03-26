# RNG与随机种子管理

> **Status**: Approved
> **Author**: 用户 + GitHub Copilot
> **Last Updated**: 2026-03-25
> **Implements Pillar**: 5分钟一局、低门槛高上限

## Overview

RNG与随机种子管理负责为整局提供统一、可复现、可隔离的随机数来源，服务商店刷新、波次生成、战斗内随机事件等子系统。系统目标是在保证“每局有变化”的同时，确保调试与回放可重复：同种子同输入必须得到同输出。

## Player Fantasy

玩家感知到的是“每局都不一样，但不是乱来”。随机性应带来新鲜度，而不是不可理解的波动；同一策略在统计上应稳定，失败可归因于决策与局势，而非随机黑箱。

## Detailed Design

### Core Rules

1. 每局在 `BOOT` 生成唯一 `match_seed`，并记录到会话上下文。
2. 所有系统随机请求必须通过 RNG 服务接口，不允许直接调用引擎全局随机。
3. 按子系统分配独立随机流（stream）：`shop`、`wave`、`battle`、`loot`、`debug`。
4. 每条随机流基于 `match_seed` + `stream_id` 派生，互不污染。
5. 随机调用需带 `context_key`，便于回放定位（如 `wave2_shop_roll_3`）。
6. 同输入（seed + stream + call_index + params）必须返回确定性结果。
7. 支持 `peek`（预览不推进）与 `next`（取值并推进）两种调用模式。
8. 当系统发生回滚/重放时，可按快照恢复各流游标。
9. 提供统一日志：记录每次随机调用来源、范围、结果、游标。
10. 调试模式支持固定种子、重放种子、批量跑种子。

### States and Transitions

- `Uninitialized`：尚未分配 match 种子。
- `Initialized`：已分配并注册所有随机流。
- `Running`：各系统持续请求随机值。
- `Snapshotting`：写出或恢复随机游标快照。
- `Closed`：对局结束，冻结随机状态供复盘。

合法转移：`Uninitialized -> Initialized -> Running <-> Snapshotting -> Closed`。

### Interactions with Other Systems

- `对局状态机`：在 `BOOT` 初始化种子，在终局关闭并归档。
- `招募商店与刷新经济`：使用 `shop` 流决定出货结果。
- `波次生成（普通/精英/Boss）`：使用 `wave` 流抽样敌方编队。
- `自动战斗结算`：使用 `battle` 流处理命中/暴击等随机事件（若开启）。
- `平衡参数配置表`：提供随机相关参数（保底阈值、权重分布）。
- `Playtest事件日志`：消费随机调用日志用于复盘与分布分析。
- `存档/读档（基础）`：保存/恢复随机流游标。

## Formulas

### 流种子派生

$$
Seed_{stream} = H(match\_seed, stream\_id)
$$

### 伪随机迭代（示意）

$$
state_{n+1} = (a\cdot state_n + c)\ \bmod\ m
$$

其中参数由实现固定，且版本化管理。

### 区间映射

$$
randInt(min,max)=min + (state \bmod (max-min+1))
$$

### 浮点映射

$$
randFloat01 = state / m
$$

### 加权抽样

$$
P(i)=w_i/\sum_j w_j
$$

使用累计权重区间映射到 `randFloat01`。

### 调用幂等键

$$
RngCallKey = (match\_id, stream\_id, call\_index, context\_key)
$$

## Edge Cases

1. 种子缺失：回退到时间戳派生种子并记录 `seed_recovered` 高优先级日志。
2. 同一调用被重复执行：通过 `RngCallKey` 返回缓存值，避免游标漂移。
3. 子系统误用全局随机：检测到后报警并拒绝上线构建（CI规则）。
4. 权重全为0或负数：拒绝抽样并回退默认权重。
5. 游标恢复失败：回退到最近一次有效快照并标记结果不可信。
6. 不同平台浮点差异：关键抽样统一使用整数路径避免分叉。
7. 回放过程中版本不一致：需校验 `rng_schema_version`，不一致则阻止精确回放。
8. 随机流越界访问：返回错误并记录 `invalid_stream_id`。
9. 并发请求同一流：按单线程队列顺序处理，保证调用序列稳定。
10. 调试固定种子未关闭：发布构建禁止 `debug_fixed_seed=true`。

## Dependencies

### 上游依赖（Hard）

- `对局状态机`：提供对局生命周期与 `match_id`。
- `平衡参数配置表`：提供抽样权重与随机相关阈值。

### 下游依赖

1. `招募商店与刷新经济`（Hard）：消费 `shop` 随机流。
2. `波次生成（普通/精英/Boss）`（Hard）：消费 `wave` 随机流。
3. `自动战斗结算`（Hard/Config）：消费 `battle` 随机流。
4. `Playtest事件日志`（Soft）：消费随机调用轨迹。
5. `存档/读档（基础）`（Soft→后续Hard）：消费游标快照。

### 接口契约

- 输入最小字段：`match_id,stream_id,context_key,mode,min,max/weights`。
- 输出最小字段：`value,call_index,stream_cursor,rng_schema_version`。
- 同一幂等键请求必须返回相同结果且不重复推进游标。

## Tuning Knobs

| Knob | 默认值 | 范围 | 说明 |
|---|---:|---:|---|
| `rng_algorithm` | lcg_v1 | enum | 随机算法版本 |
| `stream_count` | 5 | 3–12 | 默认随机流数量 |
| `rng_log_sample_rate` | 1.0 | 0–1.0 | 随机日志采样率 |
| `debug_fixed_seed` | false | bool | 是否固定种子 |
| `default_seed_fallback` | timestamp_hash | enum | 缺种子兜底策略 |
| `max_rng_calls_per_match` | 200000 | 1000–1e7 | 单局调用上限 |
| `weighted_pick_precision` | 10000 | 1000–1e6 | 权重离散精度 |
| `rng_snapshot_interval` | state_change | enum | 快照触发策略 |
| `strict_determinism_mode` | true | bool | 严格确定性开关 |
| `allow_debug_stream` | true | bool | 调试流开关 |

## Visual/Audio Requirements

- 正式构建无可见表现要求。
- 调试构建可显示当前 `match_seed` 与各流 `call_index`（开发面板）。

## UI Requirements

- 调试页支持输入种子并重开同局。
- 回放页可展示随机调用摘要（按系统分组）。
- 出现随机回放不一致时，UI 提示 `rng_schema_version mismatch`。

## Acceptance Criteria

1. 同种子同输入，1000 次回放结果一致。
2. 商店、波次、战斗三条随机流互不干扰（修改一条不影响其他）。
3. 所有随机调用都可追溯到 `context_key`。
4. 游标快照可在恢复后继续得到一致序列。
5. 发布构建中不存在固定种子泄漏。
6. 权重抽样分布在 10 万次采样下逼近目标分布（误差可控）。
7. 关键随机路径跨平台一致（Windows/Android）。
8. 出现非法权重、非法流ID时系统可降级且不崩溃。
9. 单次随机调用平均耗时 `< 0.01ms`（MVP 规模）。
10. 可用指定种子稳定复现一局关键问题。

## Open Questions

1. `battle` 流是否在 MVP 全量接管战斗随机，还是先保留部分内置随机？（Owner: `gameplay-programmer`）
2. 抽样日志是否全量保留，还是按采样率压缩以节省存储？（Owner: `qa-tester`）
3. RNG 算法是否直接采用 PCG/Xoroshiro 以提升统计质量？（Owner: `systems-designer`）
4. 回放是否要求“逐调用完全一致”，还是“统计一致”即可通过？（Owner: `producer`）
