# Sprint 3 Gate-Check 报告模板

> 使用方式：复制本文件并重命名为 `YYYY-MM-DD-sprint-003-gate-check.md` 后填写。

## 基本信息
- 日期：____-__-__
- 执行人：____
- 目标版本/分支：____
- 环境：Windows / Godot 4.6.x

## 结论
- Gate-Check 结果：通过 / 有条件通过 / 不通过
- 总体说明（1-3 句）：

## 覆盖范围
- 主流程：`BOOT -> WAVE_PREPARE -> SHOP -> DEPLOY -> BATTLE -> RESOLVE -> GAME_WIN/GAME_OVER`
- Sprint 3 关键能力：
  - S3-M1：SHOP 买入/刷新/锁定与资源扣减
  - S3-M2：DEPLOY 上阵/下阵/换位与冻结快照
  - S3-M3：BATTLE `battle_context` 输入生效
  - S3-M4：RESOLVE 同屏结果面板
  - S3-M5：手动烟测清单与报告模板

## 执行证据
- 清单文件：`production/gate-checks/sprint-003-manual-smoke-checklist.md`
- 对局日志导出：`user://playtest_match_timeline.json`
- 战斗 Top3 导出：`user://playtest_battle_top3.json`
- 相关实现：
  - `src/core/match_state_machine.gd`
  - `src/core/auto_battle_resolver.gd`
  - `src/core/app_root.gd`
  - `scenes/Main.tscn`

## 用例结果汇总
| 类别 | 总数 | 通过 | 失败 | 备注 |
|---|---:|---:|---:|---|
| SHOP | 4 |  |  |  |
| DEPLOY | 4 |  |  |  |
| BATTLE | 2 |  |  |  |
| RESOLVE | 2 |  |  |  |
| 导出与归档 | 2 |  |  |  |
| 合计 | 14 |  |  |  |

## 关键验收核对
- [ ] SHOP 操作仅在 `SHOP` 阶段生效，非法阶段拒绝
- [ ] DEPLOY 上阵/下阵/换位仅在 `DEPLOY` 阶段生效
- [ ] `BATTLE` 摘要可读到 `ctx(front,buy,refresh)` 变化
- [ ] `RESOLVE` 面板同屏显示胜负、资源变化、复盘摘要
- [ ] 日志导出成功且结构可读

## 缺陷与风险
| ID | 问题描述 | 严重级别 | 影响范围 | 当前状态 | 计划 |
|---|---|---|---|---|---|
| BUG-001 |  | 低/中/高 |  | 打开/修复中/已验证 |  |

## 偏差说明（如有）
- 与 Sprint 计划不一致项：
- 原因：
- 处理方式：

## 发布建议
- 建议：继续推进下一任务 / 先修复问题后再推进
- 条件（如有）：

## 签字（个人开发）
- 自检确认：已完成 / 未完成
- 说明：个人开发流程下，以本 gate-check 报告 + 清单记录作为 `Code reviewed and merged` 的替代证据。
