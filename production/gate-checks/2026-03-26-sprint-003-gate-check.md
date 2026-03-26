# Sprint 3 Gate-Check 报告（2026-03-26）

## 基本信息
- 日期：2026-03-26
- 执行人：Copilot（自动化验证）
- 目标版本/分支：当前工作区状态
- 环境：Windows / Godot 4.6.1

## 结论
- Gate-Check 结果：有条件通过
- 总体说明：当前版本通过静态检查与引擎启动验证，无脚本/场景解析错误。由于本次执行环境无法完成 UI 人工交互，手动烟测清单中的交互项需补测后再确认“全量通过”。

## 覆盖范围
- 主流程：`BOOT -> WAVE_PREPARE -> SHOP -> DEPLOY -> BATTLE -> RESOLVE -> GAME_WIN/GAME_OVER`
- Sprint 3 关键能力：
  - S3-M1：SHOP 买入/刷新/锁定与资源扣减
  - S3-M2：DEPLOY 上阵/下阵/换位与冻结快照
  - S3-M3：BATTLE `battle_context` 输入生效
  - S3-M4：RESOLVE 同屏结果面板
  - S3-M5：手动烟测清单与报告模板
  - S3-S1：对局日志 `action_trace`
  - S3-S2：参数配置外置与校验
  - S3-N1：最近一局关键摘要回放
  - S3-N2：HUD 低信息密度与调试折叠

## 执行证据
- 清单执行记录：[production/gate-checks/2026-03-26-sprint-003-manual-smoke-checklist-run-01.md](production/gate-checks/2026-03-26-sprint-003-manual-smoke-checklist-run-01.md)
- 清单模板：[production/gate-checks/sprint-003-manual-smoke-checklist.md](production/gate-checks/sprint-003-manual-smoke-checklist.md)
- 报告模板：[production/gate-checks/sprint-003-gate-check-template.md](production/gate-checks/sprint-003-gate-check-template.md)
- 对局日志导出：`user://playtest_match_timeline.json`
- 战斗 Top3 导出：`user://playtest_battle_top3.json`
- 最近回放导出：`user://playtest_recent_match_replay.json`

## 用例结果汇总
| 类别 | 总数 | 通过 | 失败 | 待人工 | 备注 |
|---|---:|---:|---:|---:|---|
| SHOP | 4 | 0 | 0 | 4 | 需人工交互验证 |
| DEPLOY | 4 | 0 | 0 | 4 | 需人工交互验证 |
| BATTLE | 2 | 0 | 0 | 2 | 需人工推进流程 |
| RESOLVE | 2 | 0 | 0 | 2 | 需人工观察 UI |
| 导出与归档 | 2 | 1 | 0 | 1 | 启动验证通过，导出按钮需人工点击 |
| 合计 | 14 | 1 | 0 | 13 | 自动化部分通过 |

## 关键验收核对
- [ ] SHOP 操作仅在 `SHOP` 阶段生效，非法阶段拒绝（待人工补测）
- [ ] DEPLOY 上阵/下阵/换位仅在 `DEPLOY` 阶段生效（待人工补测）
- [ ] `BATTLE` 摘要可读到 `ctx(front,buy,refresh)` 变化（待人工补测）
- [ ] `RESOLVE` 面板同屏显示胜负、资源变化、复盘摘要（待人工补测）
- [ ] 日志导出成功且结构可读（待人工补测按钮触发）
- [x] 核心脚本与场景静态检查通过
- [x] Godot 启动与场景加载通过（仅音频驱动回退告警）

## 缺陷与风险
| ID | 问题描述 | 严重级别 | 影响范围 | 当前状态 | 计划 |
|---|---|---|---|---|---|
| RISK-001 | WASAPI 初始化失败，回退 dummy audio | 低 | 音频输出 | 已知环境问题 | 后续在具备可用音频设备环境复验 |
| RISK-002 | 交互用例未在自动化环境覆盖 | 中 | 验收完整性 | 待补测 | 使用清单完成人工交互补测 |

## 偏差说明
- 与 Sprint 计划不一致项：本次未完成全量“手动交互”项执行。
- 原因：当前执行链路不具备 UI 点击/按键自动化能力。
- 处理方式：已输出完整 Run 01 记录，建议按清单完成人工补测并生成 Run 02 报告。

## 发布建议
- 建议：有条件继续推进
- 条件：在本地完成 `S3-SMOKE-02`~`S3-SMOKE-14` 人工补测并更新 gate-check 结论。

## 签字（个人开发）
- 自检确认：已完成（自动化部分）
- 说明：个人开发流程下，本报告可作为阶段性留档；全量通过需补齐人工交互烟测证据。
