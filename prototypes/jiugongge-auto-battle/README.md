# PROTOTYPE - NOT FOR PRODUCTION
# Question: 九宫格站位是否能显著改变自动战斗胜率与战斗时长？
# Date: 2026-03-25

## Prototype Plan
- 以最小规则实现 3x3 站位 + 自动战斗离散 Tick 模拟（无技能系统）。
- 固定同一敌方阵型，只改变我方阵型，比较胜率、平均战斗时长与剩余血量。
- 使用 500 局 Monte Carlo（轻度伤害波动）避免单次偶然结果。
- 只回答“站位是否有决策价值”这个问题，跳过完整数值与表现层。

## Files
- `simulator.py`: 原型模拟器（Python）
- `REPORT.md`: 原型结论报告

## Run
在该目录执行：

`python simulator.py`
