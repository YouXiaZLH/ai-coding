# ADR-0001: Core Runtime Baseline for Pre-Production (Rendering / Input / State Management)

## Status
Accepted

## Date
2026-03-25

## Context

### Problem Statement
项目已完成 MVP 与多数 Vertical Slice 设计文档，但 `/gate-check pre-production` 显示缺少 ADR，导致无法确认核心技术路线。当前需要在进入预制作前，明确三项基础决策：渲染路径、输入架构、对局状态管理边界，避免后续实现阶段出现系统耦合、性能失控与行为不一致。

### Constraints
- 技术约束：Godot 4.6、主语言 GDScript、Android 为主平台，需支持低端机回退策略。
- 时间约束：当前为 Pre-Production 入口，需尽快形成可执行架构基线。
- 资源约束：个人开发为主，架构必须可维护、低复杂度、可快速落地。
- 兼容约束：必须与已批准 GDD（状态机、战斗、商店、存档、日志）保持契约一致。

### Requirements
- 必须支持 5 分钟单局的稳定相位流转（`WAVE_PREPARE -> SHOP -> DEPLOY -> BATTLE -> RESOLVE`）。
- 必须在 Android 目标机保持可控性能（默认 60 FPS 目标，可低端降级）。
- 必须与 `对局状态机`、`战斗HUD与商店UI`、`存档/读档（基础）`、`Playtest事件日志` 对接。
- 必须允许渲染、输入、状态管理各自独立演进，避免互相反向控制。

## Decision
采用**分层事件驱动基线架构**：
1. **Rendering**：默认使用 Godot Forward+；根据设备能力切换到 Mobile renderer（低端机回退）。
2. **Input**：统一 Input Action Map + 相位门控命令分发器（Phase-Gated Command Dispatcher）；所有输入先映射为命令，再由状态机判断是否可执行。
3. **State Management**：`对局状态机` 作为唯一流程真源（SSOT），其他系统仅通过事件总线请求，不可直接改写全局状态。

该决策确保：表现层可降级、输入层可控、流程层可证明，满足短局快节奏与可复现要求。

### Architecture Diagram
```text
+-------------------+        +------------------------+
| Input Devices     |        | Rendering Profile      |
| (touch/mouse/kb)  |        | (Forward+/Mobile)      |
+---------+---------+        +-----------+------------+
          |                              |
          v                              v
+---------------------------+   +----------------------+
| Input Action Map          |   | Presentation Layer   |
| -> Command Dispatcher     |   | (HUD/VFX/SFX)        |
+-------------+-------------+   +----------+-----------+
              |                            ^
              v                            |
      +------------------- Event Bus -------------------+
      |                                                 |
      v                                                 |
+---------------------------+        +------------------+----------------+
| Match State Machine (SSOT)|------->| Gameplay Systems                   |
| phase, wave, timers       |        | shop/battle/reward/save/log        |
+---------------------------+        +------------------------------------+
```

### Key Interfaces
- `state_changed(prev_state, next_state, wave, timer_ms)`
  - 发布方：State Machine
  - 订阅方：HUD、输入门控、日志
- `request_command(command_type, payload, phase, revision)`
  - 发布方：输入分发器
  - 消费方：对应子系统（商店/布阵等）
  - 约束：`phase` 不匹配时拒绝执行
- `publish_game_event(event_type, match_id, wave, payload)`
  - 发布方：各 gameplay 子系统
  - 消费方：日志系统、反馈系统
- `snapshot_request(reason, phase, wave, revisions)`
  - 发布方：State Machine
  - 消费方：Save/Load 系统

## Alternatives Considered

### Alternative 1: Monolithic Scene Script（单体脚本主控）
- **Description**: 将渲染、输入、状态切换、业务逻辑集中在少数场景脚本中。
- **Pros**: 上手快、初期实现成本低。
- **Cons**: 耦合高、回归风险大、难以做性能降级与行为追踪。
- **Rejection Reason**: 与多系统并行演进目标冲突，后期维护成本过高。

### Alternative 2: Full ECS-First from Day 1（首日全面 ECS）
- **Description**: 在预制作阶段即全面采用 ECS 架构重构全部系统。
- **Pros**: 理论上数据导向、可扩展性高。
- **Cons**: 学习与迁移成本高，当前阶段收益不成比例，增加实现风险。
- **Rejection Reason**: 不符合当前时间与人力约束，超出预制作必要复杂度。

## Consequences

### Positive
- 架构边界明确，减少系统间互相穿透调用。
- 输入合法性可统一由状态机相位控制，降低越权操作问题。
- 渲染可按设备能力降级，利于 Android 目标机稳定运行。
- 为存档、日志、复盘提供统一事件主线。

### Negative
- 需要维护事件契约与版本，初期有一定规范成本。
- 调试需要跨层追踪（输入->状态->系统->表现），工具要求更高。

### Risks
- 事件命名失控导致契约漂移。
  - Mitigation: 建立事件命名规范与 schema version 检查。
- 相位门控规则遗漏导致输入误执行。
  - Mitigation: 为关键命令添加 phase 白名单测试。
- 设备能力判定不准确导致错误渲染档位。
  - Mitigation: 启动时能力探测 + 手动覆盖开关（调试）。

## Performance Implications
- **CPU**: 事件分发与门控增加轻量开销，但可通过批处理与节流控制在可接受范围。
- **Memory**: 事件缓冲与快照元数据会增加少量内存占用。
- **Load Time**: 启动时渲染档位探测与配置加载有轻微开销。
- **Network**: 单机项目无必需网络开销（此决策不引入新增网络成本）。

## Migration Plan
1. 在 `src/` 实现最小状态机骨架与事件总线。
2. 将 HUD、商店、布阵输入接入统一命令分发器。
3. 接入渲染档位选择（Forward+ 默认，低端 Mobile 回退）。
4. 为关键事件补日志采集与存档触发点。
5. 在 prototype 阶段以“九宫格布阵+自动战斗”验证端到端流程。

## Validation Criteria
- 关键流程事件链可追踪：输入->状态->系统->反馈->日志。
- 非法相位输入 100% 被拒绝（带明确拒绝原因）。
- 低端档位切换后对局核心信息可读性不下降。
- 恢复后状态与事件序列一致，无重复结算。
- 通过后续 `/gate-check pre-production` 的 ADR 项检查。

## Related Decisions
- 相关设计文档：
  - `design/gdd/对局状态机.md`
  - `design/gdd/战斗HUD与商店UI.md`
  - `design/gdd/存档-读档（基础）.md`
  - `design/gdd/Playtest事件日志.md`
- 相关 ADR：
  - None (first ADR)
