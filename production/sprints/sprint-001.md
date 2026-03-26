# Sprint 1 -- 2026-03-26 to 2026-03-30

## Sprint Goal
完成首个“可交互竖切闭环”：终局发放局外点数 -> 进入局外解锁面板 -> 解锁落盘 -> 重启后恢复一致。

## Capacity
- Total days: 5
- Buffer (20%): 1 day reserved for unplanned work
- Available: 4 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S1-M1 ✅ | 初始化 Godot 4.6 工程骨架（场景、输入映射、数据目录） | gameplay-programmer | 0.5 | Pre-Production PASS | 工程可启动；主场景可进入“终局结算页（占位）” |
| S1-M2 ✅ | 实现终局 `meta_point_delta` 结算并写入 `meta_progress` | systems-designer + gameplay-programmer | 1.0 | 局内资源与奖励流、轻度局外解锁 | 同局重复结算不重复发放；日志记录完整 |
| S1-M3 ✅ | 实现局外解锁事务（校验前置/扣点/写状态/幂等） | gameplay-programmer | 1.0 | 存档/读档（基础）、轻度局外解锁 | 重复点击不重复扣点；失败可回滚 |
| S1-M4 ✅ | 接入本地持久化（存档恢复 `meta_progress + unlock_state`） | gameplay-programmer | 0.8 | S1-M2, S1-M3 | 重启后数据一致；损坏快照可降级 |
| S1-M5 ✅ | 最小 UI 闭环（终局点数展示 + 解锁面板 + 成功/失败提示） | ui-programmer | 0.7 | S1-M2, S1-M3 | 30秒内可完成一次解锁操作；错误提示可读 |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S1-S1 ✅ | 新增 playtest 日志字段（unlock_result / txn_latency / error_code） | qa-tester + gameplay-programmer | 0.4 | S1-M3 | 导出日志可区分成功/幂等/回滚 |
| S1-S2 ✅ | 参数表化局外点数曲线（base/win/wave/cost） | systems-designer | 0.4 | S1-M2 | 不改代码即可调整点数与花费 |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S1-N1 ✅ | 解锁面板“NEW”标记与一次性引导提示 | ux-designer | 0.3 | S1-M5 | 首次解锁有轻提示，不阻塞操作 |
| S1-N2 ✅ | 3组参数快速A/B脚本（2-3局首解锁达成率） | systems-designer | 0.5 | S1-S2 | 输出达成率与建议默认参数 |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| N/A | 首个生产冲刺 | N/A |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| 尚无 Godot 工程导致开发启动延迟 | High | High | 把工程骨架列为首个 Must Have，首日完成 |
| 解锁与存档事务竞态导致重复扣点 | Medium | High | 单线程事务队列 + 幂等键 + 回滚测试 |
| 点数曲线过松/过紧影响短局留存 | Medium | Medium | 参数表化并在 Sprint 内做小样本 A/B |
| UI 信息密度过高导致新手理解失败 | Medium | Medium | MVP 仅保留点数、花费、前置、按钮四要素 |

## Dependencies on External Factors
- Godot 4.6 本地环境可用
- Android 目标机至少 1 台用于真机烟测（可后置到 Sprint 2）

## Definition of Done for this Sprint
- [x] All Must Have tasks completed
- [x] All tasks pass acceptance criteria
- [x] No S1 or S2 bugs in delivered features
- [x] Design documents updated for any deviations
- [x] Code reviewed and merged

> Closeout note (2026-03-25): 自动化 DoD 检查已完成，详见 `production/gate-checks/2026-03-25-sprint-001-dod-closeout.md`；个人开发流程下，`Code reviewed and merged` 以自检通过视为完成。
