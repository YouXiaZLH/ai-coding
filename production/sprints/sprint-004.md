# Sprint 4 -- 2026-04-14 to 2026-04-18

## Sprint Goal
在 Sprint 3 可玩闭环基础上，完成“可持续游玩”的 Vertical Slice 关键能力：存档恢复、局外解锁闭环、战斗反馈可解释性。

## Capacity
- Total days: 5
- Buffer (20%): 1 day reserved for unplanned work
- Available: 4 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S4-M2 | ~~实现存档/读档（基础）安全点快照（WAVE_PREPARE/SHOP_END/RESOLVE）~~ **[DONE]** | gameplay-programmer | 1.2 | design/gdd/存档-读档（基础）.md（Approved） | 可写入并恢复关键快照；恢复后 state/wave/resource 一致；失败可安全回退 |
| S4-M3 | ~~打通轻度局外解锁与终局结算闭环（前置校验->扣点->写状态）~~ **[DONE]** | systems-designer + gameplay-programmer | 0.9 | S4-M2, design/gdd/轻度局外解锁.md（Approved） | 解锁流程原子化；失败回滚；局外页显示解锁状态与花费 |
| S4-M4 | ~~落地战斗反馈最小闭环（命中/技能/击杀/羁绊）~~ **[DONE]** | technical-artist + gameplay-programmer | 0.9 | design/gdd/战斗反馈系统（伤害-羁绊提示-VFX-SFX）.md（Approved）, S3-M3 | BATTLE 阶段可见关键反馈；关键事件不丢失；低性能下可降级 |
| S4-M5 | 建立存档恢复与反馈系统回归清单 + gate-check 模板扩展 | qa-tester | 0.5 | S4-M2~S4-M4 | 新增至少 10 条回归路径（含恢复/反馈）；可复用于后续 Sprint |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S4-S1 | Playtest 日志扩展：追加 save/load、feedback dispatch、recover result 事件 | qa-tester + gameplay-programmer | 0.4 | S4-M2,S4-M4,S3-S1 | 导出日志可还原“何时存档、是否恢复成功、关键反馈是否派发” |
| S4-S2 | 参数配置二期：反馈强度与冷却参数外置并校验 | systems-designer | 0.4 | S4-M4, design/gdd/平衡参数配置表.md（Approved） | 不改代码可调节反馈强度/频次；加载失败回退默认并落日志 |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S4-N1 | 新手引导与失败复盘入口占位（首局提示 + 失败建议） | ux-designer + game-designer | 0.3 | S4-M3,S4-M4 | 首局提供最小引导；失败页给出 1-2 条可执行建议 |
| S4-N2 | 调试性能观测面板（关键系统耗时与事件量） | gameplay-programmer | 0.3 | S4-M4,S4-S1 | 调试模式可查看 battle/feedback/save_load 的基础统计 |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| 无 | — | — |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| 存档恢复导致状态不一致（phase/wave/resource 漂移） | Medium | High | 严格安全点写入 + 幂等恢复校验 + 失败回退到最近有效快照 |
| 战斗反馈事件过载造成可读性下降或性能抖动 | Medium | Medium | 关键优先 + 普通合并 + 冷却阈值 + 低性能降级开关 |
| 局外解锁事务中断导致“扣点成功但状态未写” | Low | High | 原子事务流程（校验->扣点->写状态）+ 回滚与错误日志 |

## Dependencies on External Factors
- `production/milestones/` 当前缺失，目标按 `design/gdd/systems-index.md` 的 Vertical Slice 优先级推进
- `production/risk-register/` 当前缺失，风险项以 `systems-index.md` High-Risk Systems 与 Run 01 gate-check 风险为准
- Godot 4.6 本地环境可用（音频设备异常时允许 dummy driver 回退）
- 本地文件系统可写（用于 `user://` 存档/回放/日志导出）

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

> Solo-dev note: 个人开发流程下，`Code reviewed and merged` 以自检清单、回归记录和 closeout 报告通过视为完成。
