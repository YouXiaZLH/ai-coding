# Sprint 3 -- 2026-04-07 to 2026-04-11

## Sprint Goal
把 Sprint 2 的“局内可玩闭环 MVP”推进到“可连续试玩版本”：补齐可操作的 SHOP/DEPLOY 核心交互，并形成可复盘、可调参、可稳定回归的测试路径。

## Capacity
- Total days: 5
- Buffer (20%): 1 day reserved for unplanned work
- Available: 4 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S3-M1 | 实现 SHOP 最小可用交易流（买入/刷新/锁定占位 + 资源扣减） | systems-designer + gameplay-programmer | 1.0 | Sprint 2 `S2-M1,S2-M5` | SHOP 阶段可执行交易并影响 `gold`；非法阶段请求被拒绝并提示 |
| S3-M2 | 实现 DEPLOY 最小可用布阵流（上阵/下阵/换位占位） | gameplay-programmer | 1.0 | Sprint 2 `S2-M1,S2-S2` | DEPLOY 阶段可修改阵型快照；BATTLE 输入冻结前快照一致 |
| S3-M3 | 打通 BATTLE 输入上下文（读取 SHOP/DEPLOY 结果构建 battle_context） | gameplay-programmer | 0.8 | S3-M1,S3-M2,S2-M3 | 战斗摘要可反映阵型/交易变化，不再只依赖固定估算 |
| S3-M4 | 扩展 RESOLVE 结果面板（胜负 + 资源变化 + 复盘卡同屏可读） | ui-programmer | 0.6 | S2-M4,S2-N2 | 单局结束后可读展示关键结果，不阻塞继续操作 |
| S3-M5 | 建立 Sprint 3 手动烟测清单并固化 gate-check 报告模板 | qa-tester | 0.6 | S3-M1~S3-M4 | 至少覆盖 10 条关键路径；可复用到后续冲刺回归 |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S3-S1 | 对局日志追加交易与布阵事件（shop/deploy action trace） | qa-tester + gameplay-programmer | 0.4 | S3-M1,S3-M2,S2-S1 | 导出日志可还原“买了什么、如何布阵、为何输赢” |
| S3-S2 | 关键参数外置到配置（shop cost/refresh cost/hp penalty） | systems-designer | 0.4 | S3-M1,S2-S2 | 不改代码可调节核心经济与惩罚参数 |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S3-N1 | 一键回放最近一局关键摘要（phase+battle+resolve） | gameplay-programmer | 0.3 | S2-S1,S3-S1 | 调试模式可快速复看最近一局关键时间线 |
| S3-N2 | HUD 低信息密度优化（折叠次级调试字段） | ux-designer + ui-programmer | 0.3 | S3-M4 | 默认界面仅保留玩家决策相关字段，调试信息可切换 |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| Sprint 1+2 手动烟测与归档 | Sprint 2 收尾后建议项，需在 Sprint 3 初段完成 | 0.3 day |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| SHOP/DEPLOY 从占位到可写逻辑时引入状态竞态 | Medium | High | 所有写操作统一经状态机网关，维持单入口校验 |
| BATTLE 上下文接入后出现结果不稳定 | Medium | High | 固定 seed 回归样本 + 关键摘要对比脚本 |
| UI 信息继续膨胀降低可读性 | Medium | Medium | 维持“玩家视图/调试视图”分层，不混排 |
| 配置外置增加无效参数风险 | Low | Medium | 配置加载时做类型与范围校验并落日志 |

## Dependencies on External Factors
- Godot 4.6 本地环境可用
- 本机音频设备可选（当前可回退 dummy driver，不阻塞开发）
- Python 环境可用（用于日志与参数分析脚本）

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

## Progress Update

### Completed
- [x] S3-M1 实现 SHOP 最小可用交易流（买入/刷新/锁定占位 + 资源扣减）
	- 状态机新增 SHOP 操作网关：`buy / refresh / lock toggle`
	- 非 `SHOP` 阶段调用统一拒绝并返回错误码
	- 金币不足与锁定刷新场景已覆盖拒绝路径
	- UI 已接入按钮与商店状态显示（offer/lock/refresh_count/last_action）

### Next
- [x] S3-M2 实现 DEPLOY 最小可用布阵流（上阵/下阵/换位占位）
	- 状态机已新增 `deploy_place / deploy_remove / deploy_swap` 三类操作
	- 非 `DEPLOY` 阶段请求统一拒绝并返回错误码
	- 进入 `BATTLE` 前冻结布阵快照，可在快照字段中核对一致性

### Next
- [x] S3-M3 打通 BATTLE 输入上下文（读取 SHOP/DEPLOY 结果构建 battle_context）
	- 状态机在进入 `BATTLE` 时构建 `battle_context`（frontline_count / deploy_action_count / shop_buy_count / refresh_count / shop_gold_spent）
	- `auto_battle_resolver` 已接入 `battle_context` 并把阵型/交易影响映射到 `ally_power_modifier`
	- 战斗摘要与 HUD 已显示关键上下文字段，支持目视核对“输入变化 -> 战斗结果变化”

### Next
- [x] S3-M4 扩展 RESOLVE 结果面板（胜负 + 资源变化 + 复盘卡同屏可读）
	- 新增 `ResolvePanelLabel`，在 `RESOLVE/GAME_WIN/GAME_OVER` 同屏展示结果汇总
	- 面板聚合字段：胜负、波次类型、`gold/hp` 变化与结算后值、`meta_point_delta`、复盘摘要
	- 非 RESOLVE 阶段显示等待状态，避免调试信息混淆

### Next
- [x] S3-M5 建立 Sprint 3 手动烟测清单并固化 gate-check 报告模板
	- 新增手动烟测清单：`production/gate-checks/sprint-003-manual-smoke-checklist.md`（14 条关键路径）
	- 新增 gate-check 报告模板：`production/gate-checks/sprint-003-gate-check-template.md`
	- 模板已对齐个人开发流程，可作为 `Code reviewed and merged` 替代证据

### Next
- [x] S3-S1 对局日志追加交易与布阵事件（shop/deploy action trace）
	- `export_playtest_match_log` 新增 `action_trace` 字段并升级 schema 为 `s3_s1_match_timeline_v2`
	- `action_trace` 同时记录 `placeholder_op_applied/rejected`，可还原 shop/deploy 决策链与失败原因
	- 导出结果新增 `action_trace_count`，主界面导出反馈可直接查看条数

### Next
- [x] S3-S2 关键参数外置到配置（shop cost/refresh cost/hp penalty）
	- 新增配置文件：`assets/data/match/match_balance_config.json`
	- 状态机新增配置加载与范围校验（类型校验 + 数值边界校验）
	- `shop_buy_cost/shop_refresh_cost/wave_hp_penalty_by_index` 已改为配置驱动

### Next
- [x] S3-N1 一键回放最近一局关键摘要（phase+battle+resolve）
	- 状态机新增 `get_recent_match_replay/export_recent_match_replay` 与最近一局时间线构建
	- 主界面新增“一键回放最近一局（S3-N1）”按钮与回放摘要面板
	- 回放导出路径：`user://playtest_recent_match_replay.json`

### Next
- [x] S3-N2 HUD 低信息密度优化（折叠次级调试字段）
	- 默认界面切换为低信息密度，仅保留玩家决策相关字段
	- 新增“显示/隐藏调试信息”按钮，支持运行时切换调试视图
	- 调试视图折叠字段：Top3、商店/布阵详情、回放摘要、导出按钮、非法跳转按钮

### Validation
- [x] Sprint 3 手动烟测 Run 01 与首份 gate-check 报告已生成
	- 执行记录：`production/gate-checks/2026-03-26-sprint-003-manual-smoke-checklist-run-01.md`
	- 首份报告：`production/gate-checks/2026-03-26-sprint-003-gate-check.md`
	- 当前结论：有条件通过（自动化验证通过，交互项待人工补测）
- [x] Sprint 3 DoD 收尾报告已生成
	- 报告：`production/gate-checks/2026-03-26-sprint-003-dod-closeout.md`
	- 当前 DoD 结论：有条件通过（待补齐交互型手动烟测）

> Solo-dev note: 个人开发流程下，`Code reviewed and merged` 以自检清单、回归记录和 closeout 报告通过视为完成。
