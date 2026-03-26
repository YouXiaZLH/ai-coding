Vibe Coding × MCP × Skill

从‘能用 AI 写代码’到‘系统化产出’

分享人：赵龙辉  |  日期：2026-03-24

目录

1. 什么是 Vibe Coding

2. 为什么现在必须掌握 MCP

3. Skill 能力模型与成长路径

4. 一套可落地的项目实践

5. 风险、治理与行动计划

6. 以godot进行游戏开发的项目实践

核心定义

Vibe Coding：LLM 驱动的快速编码 + 迭代 + 验证循环

MCP：模型通过标准协议调用工具与上下文服务

Skill：团队将 AI 产出转化为工程资产的能力集合

结论：三者组合才形成稳定生产力

什么是 Vibe Coding

定义：用自然语言驱动 AI 快速完成编码、调试与迭代

核心价值：更快试错、更低门槛、更强反馈闭环

不是替代工程能力，而是放大工程能力

结果导向：从‘写代码’转向‘交付价值’

Vibe Coding 的边界

适合：原型、脚手架、重复性逻辑、文档与测试补全

谨慎：高风险交易、核心安全模块、强合规场景

原则：AI 负责速度，人类负责正确性与责任

关键动作：明确约束、缩小任务、快速验证

MCP 是什么

MCP（Model Context Protocol）：是一种开放协议，通过标准化的服务器实现，使 AI 模型能够安全地与本地和远程资源进行交互。如通过文件访问、数据库连接、API 集成和其他上下文服务来扩展 AI 功能。

本质：给 AI 增加‘手和眼’，而不只是‘大脑’

统一接口：文件系统、数据库、API、Issue/PR 平台

价值：减少上下文丢失，提升自动化与可审计性

为什么 MCP 很关键

从单轮问答升级为多步骤执行

从‘建议代码’升级为‘直接完成任务’

把分散工具串成可复用工作流

让个人效率提升扩展到团队效率提升

Skill：教 AI 按固定流程做事的操作说明书

一套落地流程

Step 1：定义目标与验收（Definition of Done）

Step 2：让 AI 产出方案 + 风险清单

Step 3：小步实现 + 自动化验证

Step 4：Code Review + 文档沉淀

Step 5：复盘并更新团队 Skill 模板

风险与治理

风险：幻觉、过度自动化、隐私与合规

治理：最小权限、日志留痕、关键路径人工审批

质量线：测试覆盖、静态检查、发布闸门

建议：建立‘AI 产出可追溯’机制

godot进行游戏开发的项目实践

AI 组件版图

Agent 层（角色专家）：位于 `.copilot/agents/`，覆盖设计、程序、QA、发布等

Skills 层（可复用流程）：位于 `.github/skills/`，以命令驱动标准工作法

Guide 层（全局方法）：`docs/WORKFLOW-GUIDE.md`明确了 “48-agent system + 37 slash commands + hooks”

Project Config 层：`COPILOT.md` + engine reference + production 文档

Tier 1 — Directors (Opus)

creative-director    technical-director    producer

Tier 2 — Department Leads (Sonnet)

game-designer        lead-programmer       art-director

audio-director       narrative-director    qa-lead

release-manager      localization-lead

Tier 3 — Specialists (Sonnet/Haiku)

gameplay-programmer  engine-programmer     ai-programmer

network-programmer   tools-programmer      ui-programmer

systems-designer     level-designer        economy-designer

technical-artist     sound-designer        writer

world-builder        ux-designer           prototyper

performance-analyst  devops-engineer       analytics-engineer

security-engineer    qa-tester             accessibility-specialist

live-ops-designer    community-manager

agents

Reviews & Analysis /design-review /code-review /balance-check /asset-audit /scope-check /perf-profile /tech-debt

Production /sprint-plan /milestone-review /estimate /retrospective /bug-report

Project Management /start /project-stage-detect /reverse-document /gate-check /map-systems /design-system

Release /release-checklist /launch-checklist /changelog /patch-notes /hotfix

Creative /brainstorm /playtest-report /prototype /onboard /localize

Team Orchestration (coordinate multiple agents on a single feature) /team-combat /team-narrative /team-ui /team-release /team-polish /team-audio /team-level

skills

开发时间线

- `/start`：判定为“全新模板状态”，明确路径与下一步

- `/brainstorm 三国 自走棋 单机`：产出并落地 `design/gdd/game-concept.md`

- `/setup-engine godot 4.6`：补齐 `COPILOT.md`、技术偏好与版本参考

- `/map-systems`：生成 `design/gdd/systems-index.md` 与会话状态

- 后续进入 sprint/gate-check，形成“设计-实现-验证”闭环

Vibe Coding 的正确姿势（不是无序 Coding）

- 先保留 vibe：快速提炼核心爽点与反体验（例如“羁绊成型反杀”）

- 再结构化 vibe：用系统分解与依赖排序约束实现顺序

- 最后量化 vibe：把体验目标映射到参数、验收、日志与回放证据

- 原则：创意可发散，交付必须收敛

Workflow 设计：三层闭环

- 设计闭环：Concept → Systems Index → GDD

- 开发闭环：Sprint Plan → Must/Should/Nice → 实现与配置外置

- 质量闭环：Smoke Checklist → Gate Check → DoD Closeout

- 每层都产出文档证据，避免“口头完成”

一些好用的工具

https://github.com/jnMetaCode/agency-agents-zh/tree/main

https://github.com/msitarzewski/agency-agents

https://glama.ai/mcp/servers

https://github.com/anthropics/skills

总结

Vibe Coding 提升‘速度’，MCP 提升‘执行力’，Skill 决定‘上限’

Q&A
