---
marp: true
title: 从 Agent 到交付：Vibe Coding 与 Workflow 设计实践
paginate: true
---

# 从 Agent 到交付
## Vibe Coding 与 Workflow 设计实践分享

- 项目：九宫军演：群雄策（Godot 4.6）
- 时间：2026-03-26
- 主题：如何用 Agent + Skills 把“灵感”稳定变成“可交付”

---

# 01 为什么要做这套流程

- 单人/小团队开发，最大风险不是“不会做”，而是“做不完、做不稳”
- 传统“想到就写”在 1 天 Demo + 1 个月周期下，极易失控
- 目标：让创意速度（vibe）与工程节奏（workflow）同时成立

---

# 02 我们的 AI 组件版图

- Agent 层（角色专家）：位于 `.copilot/agents/`，覆盖设计、程序、QA、发布等
- Skills 层（可复用流程）：位于 `.github/skills/`，以命令驱动标准工作法
- Guide 层（全局方法）：`docs/WORKFLOW-GUIDE.md`
  - 明确了 “48-agent system + 37 slash commands + hooks”
- Project Config 层：`COPILOT.md` + engine reference + production 文档

---

# 03 关键 Skills（本项目高频）

- 启动与定位：`/start`、`/setup-engine`
- 设计链路：`/brainstorm` → `/map-systems` → `/design-system` → `/design-review`
- 交付链路：`/prototype`、`/sprint-plan`、`/gate-check`、`/playtest-report`
- 治理链路：`/scope-check`、`/retrospective`、`/architecture-decision`

---

# 04 团队型 Skills：把“单人开发”变成“虚拟团队协作”

- `team-combat`：战斗设计 + 实现 + QA
- `team-ui`：交互方案到 UI 落地
- `team-polish`：性能/表现/稳定性收敛
- `team-release`：候选版本到发布节奏
- 价值：把“我该先做什么”变成“按角色并行推进什么”

---

# 05 基于 chat 的实战时间线（真实）

- `/start`：判定为“全新模板状态”，明确路径与下一步
- `/brainstorm 三国 自走棋 单机`：产出并落地 `design/gdd/game-concept.md`
- `/setup-engine godot 4.6`：补齐 `COPILOT.md`、技术偏好与版本参考
- `/map-systems`：生成 `design/gdd/systems-index.md` 与会话状态
- 后续进入 sprint/gate-check，形成“设计-实现-验证”闭环

---

# 06 Vibe Coding 的正确姿势（不是无序 Coding）

- 先保留 vibe：快速提炼核心爽点与反体验（例如“羁绊成型反杀”）
- 再结构化 vibe：用系统分解与依赖排序约束实现顺序
- 最后量化 vibe：把体验目标映射到参数、验收、日志与回放证据
- 原则：创意可发散，交付必须收敛

---

# 07 Workflow 设计：三层闭环

- 设计闭环：Concept → Systems Index → GDD
- 开发闭环：Sprint Plan → Must/Should/Nice → 实现与配置外置
- 质量闭环：Smoke Checklist → Gate Check → DoD Closeout
- 每层都产出文档证据，避免“口头完成”

---

# 08 Sprint 3 样例：从可玩到可连续试玩

- Sprint Goal：补齐 SHOP/DEPLOY 核心交互，建立可回归路径
- Must Have：S3-M1~M5（交易流、布阵流、battle_context、结果面板、烟测模板）
- Should/Nice：日志 action_trace、参数外置、最近一局回放、HUD 信息降噪
- 结果：任务实现完成，具备可复盘、可调参、可持续迭代基础

---

# 09 验证结果与“有条件通过”机制

- Gate-Check 结论：有条件通过（自动化验证通过，交互项待人工补测）
- 优点：不过度乐观，不把“未验证”包装成“已完成”
- 风险显式化：如 UI 交互覆盖缺口、环境音频回退
- DoD 同步标注条件项，避免里程碑质量漂移

---

# 10 AI 组件对效率的直接增益

- 降低切换成本：命令即流程，减少“我现在该干嘛”空转
- 降低遗漏概率：模板化产物 + 清单化验收
- 提升复盘质量：日志、报告、会话状态持续沉淀
- 让个人开发拥有“团队级过程控制”

---

# 11 可复制实践（给团队的最小落地包）

- 约定 1：所有关键阶段必须有产物文件（design/production/docs）
- 约定 2：先跑 `/start` 与 `/setup-engine`，再允许进入实现
- 约定 3：每个 Sprint 必须有 gate-check 与 DoD closeout
- 约定 4：对“待人工补测”设置显式关闭条件

---

# 12 常见误区与纠偏

- 误区：把 Agent 当“写代码机器人”
  - 纠偏：把 Agent 当“流程执行器 + 质量守门员”
- 误区：只追求速度，不留证据
  - 纠偏：强制保留计划、验收、回归、结论文档
- 误区：一次把系统做满
  - 纠偏：MVP 优先，按 Must/Should/Nice 分层推进

---

# 13 下一步升级方向

- 增加交互自动化测试，减少“待人工”比例
- 把关键 KPI（迭代周期、回归通过率、缺陷逃逸率）持续看板化
- 将 team-* skills 固化为固定节奏（设计周 / 实现周 / 收敛周）
- 把高价值决策沉淀为 ADR，减少后续反复

---

# 14 Q&A

## 一句话总结

把 vibe coding 变成稳定交付，不靠压制创意，靠的是：
**Agent 分工 + Skills 流程 + 证据化工作流**。

---

# 附录：可直接复用的一页流程图（讲解版）

1. `/start` 确定阶段与路径  
2. `/brainstorm` 定义核心体验与边界  
3. `/setup-engine` 锁定技术栈与版本认知  
4. `/map-systems` 建立系统依赖与优先级  
5. `/design-system` + `/design-review` 出可实现设计  
6. `/prototype` + `/sprint-plan` 推进迭代  
7. `/gate-check` + DoD 形成发布前质量闭环
