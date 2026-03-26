# Sprint 3 手动烟测清单（S3-M5）

## 目标
- 为 Sprint 3 提供可复用的手动回归路径，覆盖 SHOP / DEPLOY / BATTLE / RESOLVE 主流程与关键非法路径。
- 清单默认用于本地 Godot 调试运行，输出结果可直接落入 gate-check 报告。

## 环境前置
- 引擎：Godot 4.6.x
- 场景入口：`scenes/Main.tscn`
- 数据：使用当前仓库默认 `assets/data/*` 配置
- 说明：若出现 WASAPI 报错并回退 dummy audio，不阻塞本清单执行

## 执行记录
- 执行日期：____-__-__
- 执行人：____
- 版本/分支：____

## 测试用例（关键路径 ≥ 10）

| ID | 场景 | 步骤 | 预期结果 | 结果(✅/❌) | 备注 |
|---|---|---|---|---|---|
| S3-SMOKE-01 | 对局启动 | 点击“启动对局状态机” | 进入 `WAVE_PREPARE`，状态/计时/HUD 正常刷新 |  |  |
| S3-SMOKE-02 | SHOP 买入成功 | 在 `SHOP` 点击“商店写操作”或按 `1` | `gold` 扣减；`shop_buy_count` 增加；toast 成功 |  |  |
| S3-SMOKE-03 | SHOP 刷新成功 | 在 `SHOP` 点击“商店刷新”或按 `3` | `gold` 扣减；`shop_refresh_count` 增加；`offer` 变化 |  |  |
| S3-SMOKE-04 | SHOP 锁定行为 | 在 `SHOP` 切换锁定后尝试刷新 | 锁定时刷新被拒绝，解锁后可刷新 |  |  |
| S3-SMOKE-05 | SHOP 非法阶段校验 | 在 `DEPLOY/BATTLE/RESOLVE` 触发 SHOP 操作 | 请求被拒绝，显示对应错误码/提示 |  |  |
| S3-SMOKE-06 | DEPLOY 上阵 | 在 `DEPLOY` 点击“部署上阵”或按 `2` | 前排槽位填充，候补减少，操作计数增加 |  |  |
| S3-SMOKE-07 | DEPLOY 下阵 | 在 `DEPLOY` 点击“部署下阵” | 前排单位回到候补，操作计数增加 |  |  |
| S3-SMOKE-08 | DEPLOY 换位 | 在 `DEPLOY` 有至少2个前排单位时点击“部署换位”或按 `4` | 前排 0/1 位互换，toast 成功 |  |  |
| S3-SMOKE-09 | DEPLOY 非法阶段校验 | 在非 `DEPLOY` 阶段触发上阵/下阵/换位 | 请求被拒绝，错误码符合操作类型 |  |  |
| S3-SMOKE-10 | BATTLE 上下文生效 | 推进到 `BATTLE` 并观察战斗摘要 | 摘要显示 `ally_raw/mod` 与 `ctx(front,buy,refresh)` |  |  |
| S3-SMOKE-11 | BATTLE->RESOLVE 资源结算 | 进入 `RESOLVE` | `Δgold/Δhp` 与结算后值字段一致 |  |  |
| S3-SMOKE-12 | RESOLVE 同屏面板可读 | 在 `RESOLVE/GAME_WIN/GAME_OVER` 观察 `ResolvePanel` | 同屏显示胜负、资源变化、meta 变化、复盘摘要 |  |  |
| S3-SMOKE-13 | 失败复盘卡展示 | 触发 `GAME_OVER` 路径 | 复盘卡显示失败波次与 root cause |  |  |
| S3-SMOKE-14 | 日志导出 | 点击“导出对局日志”“导出战斗Top3” | 导出成功并返回 path/count |  |  |

## 回归结论
- 通过用例数：__/14
- 失败用例数：__/14
- 是否通过本轮烟测：是 / 否

## 失败项与修复跟踪
- 问题1：
  - 现象：
  - 复现步骤：
  - 影响范围：
  - 处理状态：待修复 / 已修复 / 验证通过

## 备注
- 建议每次 Sprint 内大改后至少执行 `S3-SMOKE-01`~`S3-SMOKE-12`。
- 发版前建议全量执行 14 条并附导出日志作为证据。
