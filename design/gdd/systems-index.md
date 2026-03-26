# Systems Index: 九宫军演：群雄策

> **Status**: Draft
> **Created**: 2026-03-25
> **Last Updated**: 2026-03-25
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

本项目是“5分钟单局”的三国单机自走棋，系统设计必须围绕四个支柱：羁绊优先、短局闭环、站位博弈、低门槛高上限。机械范围以“九宫格布阵 + 自动战斗 + 招募经济 + 羁绊判定 + 波次推进”为核心，再以局外轻解锁与基础引导补齐可玩性。由于是个人开发且首个里程碑为1天Demo，系统顺序采用“先可玩、再可测、后可扩”。

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | 对局状态机 | Core | MVP | Approved | design/gdd/对局状态机.md | — |
| 2 | 武将/羁绊数据模型 | Core | MVP | Approved | design/gdd/武将-羁绊数据模型.md | — |
| 3 | RNG与随机种子管理 (inferred) | Core | MVP | Approved | design/gdd/RNG与随机种子管理.md | — |
| 4 | 平衡参数配置表 (inferred) | Core | MVP | Approved | design/gdd/平衡参数配置表.md | — |
| 5 | 九宫格布阵规则 | Gameplay | MVP | Approved | design/gdd/九宫格布阵规则.md | 对局状态机, 武将/羁绊数据模型 |
| 6 | 自动战斗结算 | Gameplay | MVP | Approved | design/gdd/自动战斗结算.md | 对局状态机, 武将/羁绊数据模型, 九宫格布阵规则 |
| 7 | 敌方AI目标选择 | Gameplay | MVP | Approved | design/gdd/敌方AI目标选择.md | 武将/羁绊数据模型, 九宫格布阵规则, 自动战斗结算 |
| 8 | 招募商店与刷新经济 | Economy | MVP | Approved | design/gdd/招募商店与刷新经济.md | 对局状态机, 武将/羁绊数据模型, RNG与随机种子管理, 平衡参数配置表 |
| 9 | 羁绊判定与加成 | Gameplay | MVP | Approved | design/gdd/羁绊判定与加成.md | 武将/羁绊数据模型, 自动战斗结算 |
| 10 | 波次生成（普通/精英/Boss） | Gameplay | MVP | Approved | design/gdd/波次生成（普通-精英-Boss）.md | 对局状态机, 武将/羁绊数据模型, RNG与随机种子管理, 平衡参数配置表 |
| 11 | 局内资源与奖励流 (inferred) | Economy | MVP | Approved | design/gdd/局内资源与奖励流.md | 对局状态机, 自动战斗结算, 招募商店与刷新经济, 波次生成（普通/精英/Boss） |
| 12 | 存档/读档（基础） | Persistence | Vertical Slice | Approved | design/gdd/存档-读档（基础）.md | 对局状态机, 局内资源与奖励流 |
| 13 | 轻度局外解锁 | Progression | Vertical Slice | Approved | design/gdd/轻度局外解锁.md | 存档/读档（基础）, 局内资源与奖励流 |
| 14 | Playtest事件日志 (inferred) | Meta | Vertical Slice | Approved | design/gdd/Playtest事件日志.md | 对局状态机, 自动战斗结算, 招募商店与刷新经济, 波次生成（普通/精英/Boss） |
| 15 | 战斗HUD与商店UI (inferred) | UI | MVP | Approved | design/gdd/战斗HUD与商店UI.md | 九宫格布阵规则, 自动战斗结算, 招募商店与刷新经济, 羁绊判定与加成, 波次生成（普通/精英/Boss）, 局内资源与奖励流 |
| 16 | 战斗反馈系统（伤害/羁绊提示/VFX/SFX） | Audio | MVP | Approved | design/gdd/战斗反馈系统（伤害-羁绊提示-VFX-SFX）.md | 自动战斗结算, 羁绊判定与加成, 战斗HUD与商店UI |
| 17 | 新手引导与失败复盘 (inferred) | Meta | Alpha | Not Started | — | 战斗HUD与商店UI, 战斗反馈系统（伤害/羁绊提示/VFX/SFX）, Playtest事件日志 |
| 18 | 设置与可访问性增强 (inferred) | Meta | Full Vision | Not Started | — | 战斗HUD与商店UI, 战斗反馈系统（伤害/羁绊提示/VFX/SFX） |

---

## Categories

| Category | Description | Typical Systems |
|----------|-------------|-----------------|
| **Core** | 为所有玩法提供基础结构和数据约束 | 对局状态机、数据模型、随机种子、参数表 |
| **Gameplay** | 直接定义“好不好玩”的战术循环 | 布阵、自动战斗、羁绊、波次、敌方AI |
| **Progression** | 局外成长与长期目标 | 轻度局外解锁 |
| **Economy** | 资源流入流出与购买决策 | 招募商店、刷新经济、局内奖励流 |
| **Persistence** | 跨局状态保存 | 存档/读档 |
| **UI** | 玩家主要交互与信息面板 | 战斗HUD、商店UI |
| **Audio** | 战斗可感知反馈与节奏强化 | 命中、触发、波次提示音效 |
| **Meta** | 核心循环之外的支撑能力 | 引导、日志、设置与可访问性 |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | 核心循环可跑通并可验证“是否好玩” | 1天Demo + 1周打磨 | Design FIRST |
| **Vertical Slice** | 增加一轮完整体验闭环（可持续游玩） | 第2周 | Design SECOND |
| **Alpha** | 主要功能全覆盖，体验可连续使用 | 第3-4周 | Design THIRD |
| **Full Vision** | 优化、增强、边缘场景 | 发布前按需 | Design as needed |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. 对局状态机 — 全局节奏、回合阶段与状态切换的唯一真源。
2. 武将/羁绊数据模型 — 所有计算与表现读取同一数据结构。
3. RNG与随机种子管理 — 决定商店、波次、掉落随机性的可复现性。
4. 平衡参数配置表 — 将强度与概率从代码中抽离，支持快速迭代。

### Core Layer (depends on foundation)

1. 九宫格布阵规则 — depends on: 对局状态机, 武将/羁绊数据模型
2. 自动战斗结算 — depends on: 对局状态机, 武将/羁绊数据模型, 九宫格布阵规则
3. 敌方AI目标选择 — depends on: 武将/羁绊数据模型, 九宫格布阵规则, 自动战斗结算
4. 招募商店与刷新经济 — depends on: 对局状态机, 武将/羁绊数据模型, RNG与随机种子管理, 平衡参数配置表
5. 羁绊判定与加成 — depends on: 武将/羁绊数据模型, 自动战斗结算
6. 波次生成（普通/精英/Boss） — depends on: 对局状态机, 武将/羁绊数据模型, RNG与随机种子管理, 平衡参数配置表
7. 局内资源与奖励流 — depends on: 对局状态机, 自动战斗结算, 招募商店与刷新经济, 波次生成（普通/精英/Boss）

### Feature Layer (depends on core)

1. 存档/读档（基础） — depends on: 对局状态机, 局内资源与奖励流
2. 轻度局外解锁 — depends on: 存档/读档（基础）, 局内资源与奖励流
3. Playtest事件日志 — depends on: 对局状态机, 自动战斗结算, 招募商店与刷新经济, 波次生成（普通/精英/Boss）

### Presentation Layer (depends on features)

1. 战斗HUD与商店UI — depends on: 九宫格布阵规则, 自动战斗结算, 招募商店与刷新经济, 羁绊判定与加成, 波次生成（普通/精英/Boss）, 局内资源与奖励流
2. 战斗反馈系统（伤害/羁绊提示/VFX/SFX） — depends on: 自动战斗结算, 羁绊判定与加成, 战斗HUD与商店UI

### Polish Layer (depends on everything)

1. 新手引导与失败复盘 — depends on: 战斗HUD与商店UI, 战斗反馈系统（伤害/羁绊提示/VFX/SFX）, Playtest事件日志
2. 设置与可访问性增强 — depends on: 战斗HUD与商店UI, 战斗反馈系统（伤害/羁绊提示/VFX/SFX）

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | 对局状态机 | MVP | Foundation | game-designer, gameplay-programmer | S |
| 2 | 武将/羁绊数据模型 | MVP | Foundation | game-designer, systems-designer | S |
| 3 | 九宫格布阵规则 | MVP | Core | game-designer | M |
| 4 | 自动战斗结算 | MVP | Core | game-designer, gameplay-programmer | M |
| 5 | 羁绊判定与加成 | MVP | Core | systems-designer | M |
| 6 | 招募商店与刷新经济 | MVP | Core | systems-designer | M |
| 7 | 波次生成（普通/精英/Boss） | MVP | Core | game-designer | S |
| 8 | 敌方AI目标选择 | MVP | Core | ai-programmer, game-designer | M |
| 9 | 局内资源与奖励流 | MVP | Core | systems-designer | S |
| 10 | 战斗HUD与商店UI | MVP | Presentation | ux-designer, ui-programmer | M |
| 11 | 战斗反馈系统（伤害/羁绊提示/VFX/SFX） | MVP | Presentation | technical-artist, sound-designer | M |
| 12 | 存档/读档（基础） | Vertical Slice | Feature | gameplay-programmer | S |
| 13 | 轻度局外解锁 | Vertical Slice | Feature | systems-designer | M |
| 14 | Playtest事件日志 | Vertical Slice | Feature | qa-tester, gameplay-programmer | S |
| 15 | 新手引导与失败复盘 | Alpha | Polish | ux-designer, game-designer | M |
| 16 | 设置与可访问性增强 | Full Vision | Polish | ui-programmer | S |

---

## Circular Dependencies

- None found.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| 自动战斗结算 | Design | 结算规则若不透明会让玩家觉得“输得不明不白” | 先做可视化战报与关键事件回放；每次战斗记录伤害来源 |
| 羁绊判定与加成 | Scope | 阈值与加成曲线容易出现唯一最优解 | 建立参数表+批量模拟对局，周更平衡审查 |
| 招募商店与刷新经济 | Design | 经济节奏过紧/过松都会破坏5分钟短局体验 | 定义3套基线经济模板并A/B测试平均局时 |
| 波次生成（普通/精英/Boss） | Technical | 波次机制若与构筑成长脱节，会导致体验断裂 | 固定Boss能力池，确保与主流羁绊至少有2种可解法 |
| 战斗HUD与商店UI | Scope | 信息过载会提高新手理解门槛 | MVP仅保留关键数值与提示，复杂信息折叠到详情层 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 18 |
| Design docs started | 16 |
| Design docs reviewed | 16 |
| Design docs approved | 16 |
| MVP systems designed | 11/11 |
| Vertical Slice systems designed | 3/3 |

---

## Next Steps

- [x] Review and approve this systems enumeration
- [ ] Design MVP-tier systems first (use `/design-system [system-name]`)
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Prototype the highest-risk system early (`/prototype 自动战斗结算`)
