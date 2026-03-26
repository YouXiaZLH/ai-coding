# Sprint 2 -- 2026-03-31 to 2026-04-04

## Sprint Goal
完成首个“局内可玩闭环”MVP：状态机驱动波次与自动战斗，产出局内奖励并回接到已完成的局外结算/解锁链路。

## Capacity
- Total days: 5
- Buffer (20%): 1 day reserved for unplanned work
- Available: 4 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S2-M1 ✅ | 实现对局状态机骨架（SHOP/DEPLOY/BATTLE/RESOLVE）与合法切换守卫 | gameplay-programmer | 1.0 | `design/gdd/对局状态机.md` | 状态可按顺序切换；非法切换被拒绝并记录日志；超时可默认前进 |
| S2-M2 ✅ | 接入波次生成最小实现（普通/精英/Boss标签 + 敌方阵容载入） | game-designer + gameplay-programmer | 0.8 | S2-M1, `design/gdd/波次生成（普通-精英-Boss）.md` | 连续3波可生成且类型正确；波次数据可被战斗结算消费 |
| S2-M3 ✅ | 实现自动战斗结算最小版（确定性种子 + 胜负/时长摘要） | gameplay-programmer | 1.2 | S2-M1, S2-M2, `design/gdd/自动战斗结算.md` | 同 seed 同输入结果一致；战斗结束产出可读摘要 |
| S2-M4 ✅ | 接入局内资源与奖励流到 RESOLVE（金币/生命变化 + 局外点数输入） | systems-designer + gameplay-programmer | 0.6 | S2-M3, `design/gdd/局内资源与奖励流.md` | 每波结算后资源变化正确；终局可生成 `meta_point_delta` 输入 |
| S2-M5 ✅ | 最小战斗HUD（wave/gold/hp/phase_timer）与阶段联动显示 | ui-programmer | 0.4 | S2-M1, `design/gdd/战斗HUD与商店UI.md` | 四阶段信息显示稳定；BATTLE/RESOLVE 禁止写操作按钮 |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S2-S1 ✅ | 扩展 playtest 日志到状态机与战斗摘要（phase 切换/战斗结果） | qa-tester + gameplay-programmer | 0.4 | S2-M1, S2-M3, `design/gdd/Playtest事件日志.md` | 导出日志可还原阶段时间线与战斗结果 |
| S2-S2 ✅ | 商店/部署占位交互（阶段可用性切换 + 非法操作提示） | ui-programmer | 0.4 | S2-M1, S2-M5 | SHOP/DEPLOY 可交互；其他阶段操作被禁用并提示 |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S2-N1 ✅ | 战斗关键事件 Top3 调试面板（命中/击杀/触发） | gameplay-programmer + qa-tester | 0.3 | S2-M3, S2-S1 | 调试模式可查看并导出关键事件摘要 |
| S2-N2 ✅ | 失败复盘原型卡片（失败波次 + 主因标签） | ux-designer | 0.4 | S2-S1, `design/gdd/Playtest事件日志.md` | 单局结束可显示1张可读复盘卡，不阻塞继续操作 |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| Sprint 1: Code reviewed and merged | 上一冲刺仅完成自动化 DoD，PR 评审与合并需人工执行 | 0.2 day |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| 状态机与子系统时序耦合导致卡局/跳阶段 | Medium | High | 先实现状态守卫与默认超时前进；所有切换走统一入口 |
| 自动战斗结果不可解释导致调参困难 | Medium | High | 先交付确定性摘要（胜负、时长、关键事件TopN） |
| HUD 信息过载影响新手理解 | Medium | Medium | MVP 只保留顶栏关键信息，次要信息延后 |
| 局内奖励与局外点数接口不一致 | Low | High | 在 RESOLVE 定义统一结算结构并做字段契约检查 |

## Dependencies on External Factors
- Godot 4.6 本地环境可用
- Python 脚本环境可用（用于 A/B 与日志后处理）
- Sprint 1 的 PR 评审与合并在 Sprint 2 前半段完成

## Definition of Done for this Sprint
- [x] All Must Have tasks completed
- [x] All tasks pass acceptance criteria
- [x] No S1 or S2 bugs in delivered features
- [x] Design documents updated for any deviations
- [x] Code reviewed and merged

> Closeout note (2026-03-25): 自动化 DoD 检查已完成，详见 `production/gate-checks/2026-03-25-sprint-002-dod-closeout.md`；个人开发流程下，`Code reviewed and merged` 以自检通过视为完成。
