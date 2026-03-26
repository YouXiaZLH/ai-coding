# Playtest事件日志

> **Status**: Approved
> **Author**: 用户 + GitHub Copilot
> **Last Updated**: 2026-03-25
> **Implements Pillar**: 低门槛高上限、5分钟一局

## Overview

Playtest事件日志负责采集、标准化、存储并导出对局中的关键行为与系统事件，用于复盘可解释性、平衡迭代和体验诊断。系统目标是“低侵入、高可追溯、可对比”：不干扰主循环性能，且能在一次测试后回答“玩家为何输赢、卡在何处、哪些参数需要调整”。

## Player Fantasy

玩家不会直接感知日志系统，但间接感受到“问题被快速修复、体验越来越顺”。开发与测试团队能基于统一证据定位痛点，而不是凭印象争论；每次调整都有前后对比，减少盲目调参。

## Detailed Design

### Core Rules

1. 仅采集对设计决策有价值的事件，禁止无上限全量明细刷写。
2. 事件统一结构：`event_id,match_id,wave,phase,timestamp,event_type,payload,revision`。
3. 事件分级：`critical`（状态切换/结算/异常）、`major`（战斗关键/经济关键）、`minor`（常规操作）。
4. 采集默认异步写入，主线程只做轻量入队与采样判定。
5. 关键事件（critical）必须 `100%` 记录；major/minor 支持采样。
6. 同一幂等键事件重复上报时去重：`match_id+wave+event_type+source_key`。
7. 对局结束后生成结构化摘要（胜负、时长、经济曲线、关键击杀、羁绊变化）。
8. 日志版本化：`log_schema_version` 与 `balance_data_version` 必须绑定。
9. 导出能力至少支持 JSON；调试构建可选 CSV 二次导出。
10. 日志写入失败不能阻塞对局，需降级并上报失败计数。

### States and Transitions

- `Idle`：未开始采集。
- `Collecting`：对局进行中，持续接收事件。
- `Buffering`：内存缓冲，等待批量刷写。
- `Flushing`：批量持久化中。
- `Closed`：对局结束，写摘要并封存。

合法转移：`Idle -> Collecting <-> Buffering -> Flushing -> Collecting -> Closed`。

### Interactions with Other Systems

- `对局状态机`：提供 phase 进出与转移拒绝事件。
- `自动战斗结算`：提供战斗摘要、关键事件 TopN、超时判定原因。
- `招募商店与刷新经济`：提供买/卖/刷/锁及经济变化轨迹。
- `波次生成（普通/精英/Boss）`：提供波次构成、目标战力与偏差。
- `局内资源与奖励流`：提供每波奖励惩罚结果与 `resource_revision`。
- `战斗反馈系统（伤害/羁绊提示/VFX/SFX）`：提供反馈触发覆盖率与抑制统计。
- `存档/读档（基础）`：提供 save/load 成功率、恢复耗时与失败原因。
- `战斗HUD与商店UI`：提供关键交互失败类型（按钮禁用命中、非法操作提示触发）。

## Formulas

### 事件采样率

$$
Log(event)=\begin{cases}
1,& level=critical\\
\mathbf{1}[rand < p_{major}],& level=major\\
\mathbf{1}[rand < p_{minor}],& level=minor
\end{cases}
$$

### 单局日志体积估算

$$
Size_{match} = \sum_i count_i \cdot avg\_bytes_i
$$

### 写入批次触发

$$
Flush = \mathbf{1}[buffer\_count \ge N_{batch}] \lor \mathbf{1}[elapsed \ge T_{flush}]
$$

### 对局胜率（样本窗口）

$$
WinRate = \frac{wins}{matches}
$$

### 经济花费率

$$
SpendRate = \frac{\sum refresh\_cost + \sum buy\_cost}{match\_duration\_sec}
$$

### 反馈覆盖率

$$
FeedbackCoverage = \frac{shown\_major+shown\_critical}{total\_major+total\_critical}
$$

## Edge Cases

1. 事件风暴（短时高频）：触发背压，minor 级别优先丢弃并记录丢弃计数。
2. 磁盘不可写：切换内存环形缓冲，结束时尝试一次导出恢复。
3. schema 版本不匹配：拒绝写入该条并记录 `log_schema_mismatch`。
4. 同事件多源重复上报：按幂等键去重，仅保留第一条。
5. 会话中断（闪退/杀进程）：下次启动尝试恢复未刷写缓冲（若存在）。
6. 时间戳回拨：改用单调递增序列号排序。
7. payload 超限：裁剪超长字段并打 `payload_truncated` 标记。
8. 导出中断：保留临时文件并允许重试导出。
9. 调试模式全量日志误开到发布构建：构建检查阻断。
10. 个人信息误写入：字段白名单过滤，禁止写入敏感文本。

## Dependencies

### 上游依赖（Hard）

- `对局状态机`：提供全局时间轴与阶段上下文。
- `自动战斗结算`：提供战斗关键事件摘要。
- `招募商店与刷新经济`：提供经济行为流。

### 下游依赖

1. `新手引导与失败复盘`（Hard）：消费日志做失败原因分类与指引。
2. `平衡参数配置表`（Soft）：基于日志结果驱动参数调整。
3. `milestone-review/retrospective`（Soft）：消费聚合指标输出阶段报告。

### 接口契约

- 输入最小字段：`event_type,match_id,wave,phase,timestamp,payload,source_system`。
- 输出最小字段：`log_id,write_result,drop_reason(optional),summary_ref`。
- 保证：critical 事件写入成功率目标 `>=99.9%`（不可达时必须报警）。

## Tuning Knobs

| Knob | 默认值 | 范围 | 说明 |
|---|---:|---:|---|
| `log_schema_version` | 1 | 整数递增 | 日志结构版本 |
| `major_sample_rate` | 1.0 | 0.1–1.0 | 重要事件采样率 |
| `minor_sample_rate` | 0.3 | 0.0–1.0 | 普通事件采样率 |
| `buffer_batch_size` | 128 | 16–1024 | 批量刷写阈值 |
| `flush_interval_ms` | 1000 | 100–5000 | 定时刷写间隔 |
| `max_payload_bytes` | 2048 | 256–8192 | 单条payload上限 |
| `max_log_size_per_match_kb` | 512 | 64–4096 | 单局日志体积上限 |
| `critical_drop_alert_threshold` | 1 | 0–10 | 关键事件丢失报警阈值 |
| `export_format` | json | enum | 导出格式 |
| `pii_filter_enabled` | true | bool | 敏感字段过滤开关 |

## Visual/Audio Requirements

- 正式构建无直接视觉/音频表现。
- 调试构建可显示“日志采集中/导出完成/写入失败”轻提示。
- 发生 critical 日志连续写入失败时显示开发警告横幅（仅调试）。

## UI Requirements

- 调试菜单提供：开始/停止采集、导出当前局日志、查看最近失败原因。
- 复盘页（后续）可按波次筛选关键事件时间轴。
- 导出结果展示文件路径与摘要统计（条数、丢弃数、体积）。

## Acceptance Criteria

1. 可完整记录单局 phase 时间轴、经济轨迹、战斗摘要与结算结果。
2. critical 事件在 1000 局压测下写入成功率 `>=99.9%`。
3. 对局主线程性能影响可控（平均开销 `<0.2ms`/帧）。
4. 事件去重生效，不出现同幂等键重复计数。
5. 日志导出文件可被脚本稳定解析，schema 校验通过率 `100%`。
6. 磁盘异常/写入失败场景下系统不崩溃且可降级。
7. 日志可支持至少 3 类平衡问题定位：经济过紧、波次断层、反馈过载。
8. 发布构建不泄漏调试专用详细字段。
9. 与存档恢复联动时能标记“恢复前后”的事件边界。
10. 一次 playtest 后可自动产出可读摘要（胜率、平均局时、常见失败波次）。

## Open Questions

1. Vertical Slice 阶段是否默认开启 major 全量采集（便于早期调优）？（Owner: `qa-tester`）
2. 摘要聚合在客户端生成还是离线脚本生成更稳妥？（Owner: `gameplay-programmer`）
3. 日志保留周期应按日期清理还是按容量滚动清理？（Owner: `producer`）
4. 是否需要为设计师提供“零代码筛选模板”（如经济异常模板）？（Owner: `systems-designer`）
