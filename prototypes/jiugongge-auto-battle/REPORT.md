# PROTOTYPE - NOT FOR PRODUCTION
# Question: 九宫格站位是否能显著改变自动战斗胜率与战斗时长？
# Date: 2026-03-25

## Prototype Report: 九宫格布阵+自动战斗

### Hypothesis
九宫格站位会显著影响自动战斗结果（至少体现在胜率或平均战斗时长之一），因此“站位博弈”可作为核心可玩性的有效来源。

### Approach
基于 Python 快速搭建 3x3 布阵 + 自动战斗 Tick 模拟器，保持敌方阵型不变，仅切换我方两种站位：`balanced_frontline` 与 `clumped_backline`。运行 500 局 Monte Carlo（轻度伤害波动），输出胜率、平均时长、P95 时长与平均剩余血量。为提速采用硬编码单位与简化伤害模型，跳过技能系统、羁绊系统与表现层。

### Result
站位对战斗结果影响极大：`balanced_frontline` 500 局胜率为 0%，`clumped_backline` 胜率为 100%。两者平均战斗时长接近（7.09s vs 7.30s），但生存血量差异显著（129.3 vs 246.0）。这说明当前简化规则下，“是否后排抱团”几乎决定胜负，站位决策价值成立，但强度曲线明显失衡。

### Metrics
- Frame time: 不适用（本次为离线模拟，不含渲染帧测量）
- Feel assessment: 结果可解释但过于极端，站位收益过大，存在单一最优风险
- Player action counts: 2 种阵型 × 500 局 = 1000 场
- Iteration count: 2（首轮发现同 tick 全灭边界崩溃，修复后复测）

### Recommendation: PROCEED
建议继续推进到引擎内原型验证。证据表明“站位影响自动战斗”这一核心假设成立，符合项目“站位博弈”支柱；但当前规则导致胜负倾斜过大，必须在进入生产实现前补充目标选择与前后排修正的平衡约束，避免形成单一最优阵型。

### If Proceeding
- Architecture requirements
  - 在 Godot 原型中落实“相位门控输入 + 状态机驱动战斗开始/结束”。
  - 战斗目标选择策略应可参数化（最近优先、威胁优先、后排保护权重）。
- Performance targets
  - 战斗逻辑计算保持在非渲染线程可接受范围；目标机保持 60 FPS（低端 30 FPS 回退）。
- Scope adjustments from the original design
  - 先关闭技能与复杂羁绊，仅验证“布阵 + 普攻自动战斗 + 结算”。
  - 增加一组对照敌方阵型，避免单敌方样本偏差。
- Estimated production effort
  - 1~2 天：Godot 内可交互原型（布阵拖拽 + 自动战斗 + 简报）

### If Pivoting
可将“后排聚团优势”转为显式机制（如阵型协同加成），并引入 AoE 或穿透惩罚抑制单一最优。

### If Killing
不适用（核心假设已被支持）。

### Lessons Learned
- 站位机制在极简战斗模型中已经能产生可观差异，适合作为核心表达。
- 目标选择与前后排修正是平衡杠杆，若缺乏约束会快速形成唯一最优。
- 原型测试应优先覆盖“边界同 tick 全灭”等收束场景，避免结论受崩溃影响。
