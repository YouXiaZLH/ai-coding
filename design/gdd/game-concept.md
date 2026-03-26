# Game Concept: 九宫军演：群雄策

*Created: 2026-03-25*
*Status: Draft*

---

## Elevator Pitch

> 这是一款三国题材单机自走棋，你在5分钟内通过九宫格布阵与羁绊取舍完成一场“普通-精英-Boss”波次军演。每局节奏紧凑、可快速重开，重点验证“短局也能打出深策略与逆风翻盘”。

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 策略自走棋（单机、快节奏、移动端） |
| **Platform** | Android（TapTap首发） |
| **Target Audience** | 偏探索与构筑乐趣的中轻度策略玩家 |
| **Player Count** | Single-player |
| **Session Length** | 5 分钟 |
| **Monetization** | 暂不定义（Demo阶段以玩法验证为主） |
| **Estimated Scope** | Small（1个月内） |
| **Comparable Titles** | 《金铲铲之战》（羁绊构筑）、《炉石酒馆战棋》（回合运营）、《杀戮尖塔》（单机重开与构筑反馈） |

---

## Core Fantasy

玩家扮演乱世军师，在极短时间内完成“武将选择-羁绊成型-站位博弈-波次应对”的连续决策，以有限资源打出高质量组合。核心情绪是“我靠脑子和取舍赢下这局”，尤其是在资源紧张或局势不顺时，通过站位调整与羁绊激活完成反打。

---

## Unique Hook

“像三国自走棋，AND ALSO 一局仅5分钟的九宫格军演。”

差异点在于：
- 小棋盘（九宫格）强迫高价值站位决策
- 波次制（普通/精英/Boss）让节奏天然前中后分层
- 快速重开降低试错成本，鼓励玩家主动探索羁绊组合

---

## Player Experience Analysis (MDA Framework)

The MDA (Mechanics-Dynamics-Aesthetics) framework ensures we design from the
player's emotional experience backward to the systems that create it.

### Target Aesthetics (What the player FEELS)
Rank the following aesthetic goals for this game (1 = primary, mark N/A if not
relevant). These come from the MDA framework's 8 aesthetic categories:

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 6 | 像素风命中特效、羁绊激活动画、简洁音效反馈 |
| **Fantasy** (make-believe, role-playing) | 2 | 三国武将身份与阵营羁绊映射“军师统军”幻想 |
| **Narrative** (drama, story arc) | N/A | Demo阶段不做重剧情，仅做战斗背景文本 |
| **Challenge** (obstacle course, mastery) | 1 | 5分钟高密度决策、波次压力、Boss检定 |
| **Fellowship** (social connection) | N/A | 单机定位，不做社交依赖 |
| **Discovery** (exploration, secrets) | 3 | 羁绊组合试验、站位与装备交互探索 |
| **Expression** (self-expression, creativity) | 4 | 多流派构筑与局内临时转型 |
| **Submission** (relaxation, comfort zone) | 5 | 快速重开、低失败惩罚，形成“再来一把” |

### Key Dynamics (Emergent player behaviors)
- 玩家会在前两波主动试探羁绊方向，并在精英波前完成一次关键转型
- 玩家会围绕Boss机制做站位微调（集火、保护后排、诱导仇恨）
- 玩家会在“保连胜”与“攒资源冲高费”之间做风险决策

### Core Mechanics (Systems we build)
1. 九宫格布阵系统（前后排、邻接关系、攻击目标规则）
2. 三国武将招募与升星系统（共享卡池简化版）
3. 阵营/职业羁绊系统（阈值激活、分层加成）
4. 波次战斗系统（普通/精英/Boss）
5. 轻度局外解锁（新武将或新羁绊逐步开放）

---

## Player Motivation Profile

Understanding WHY players play helps us make every design decision. Based on
Self-Determination Theory (SDT) and the Player Experience of Need Satisfaction
(PENS) model.

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | 每回合在招募、上阵、换位、资源分配间做取舍 | Core |
| **Competence** (mastery, skill growth) | 通过波次稳定通关、识别强势转型时机体现成长 | Core |
| **Relatedness** (connection, belonging) | 通过三国阵营认同与武将主题形成轻度情感连接 | Supporting |

### Player Type Appeal (Bartle Taxonomy)

Which player types does this game primarily serve?

- [x] **Achievers** (goal completion, collection, progression) — How: 追求稳定通关、解锁全羁绊
- [x] **Explorers** (discovery, understanding systems, finding secrets) — How: 尝试不同羁绊与站位组合
- [ ] **Socializers** (relationships, cooperation, community) — How: 单机定位，暂不覆盖
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — How: 暂不做PVP/排行

### Flow State Design

Flow occurs when challenge matches skill. How does this game maintain flow?

- **Onboarding curve**: 前2局用固定初始阵容+引导提示，10分钟内掌握“招募-上阵-羁绊-站位”
- **Difficulty scaling**: 波次敌人强度与机制递进，Boss作为阶段性检定
- **Feedback clarity**: 羁绊激活、伤害来源、承伤热点与失败原因可视化
- **Recovery from failure**: 失败后3秒内可重开，几乎无惩罚

---

## Core Loop

### Moment-to-Moment (30 seconds)
在一个回合内快速完成“看商店-买卖武将-调整九宫格站位-确认开战”，核心乐趣来自即时取舍与布阵反馈。

### Short-Term (5-15 minutes)
一局约5分钟，经历普通波→精英波→Boss波。玩家在每波间优化阵容，追求羁绊成型与关键站位，形成“再打一波就能过”的心理。

### Session-Level (30-120 minutes)
玩家在碎片时间内连续进行多局，目标是测试不同流派、完成解锁任务、提升通关稳定率。

### Long-Term Progression
通过轻度局外解锁扩展可用武将池和羁绊组合；长期目标是实现多流派可通关并提高高难度Boss胜率。

### Retention Hooks
[What specifically brings the player back for their next session?]
- **Curiosity**: 新羁绊阈值效果与隐藏组合尚未验证
- **Investment**: 已解锁武将与流派理解持续累积
- **Social**: 暂不依赖社交驱动（单机）
- **Mastery**: 站位细节、资源节奏、波次应对可持续精进

---

## Game Pillars

Design pillars are non-negotiable principles that guide EVERY decision. When
two design choices conflict, pillars break the tie. Keep to 3-5 pillars.

Real AAA examples:
- God of War: "Intense combat", "Father-son story", "World exploration"
- Hades: "Fast fluid combat", "Narrative depth through repeated runs"
- The Last of Us: "Story as essential", "AI partners build relationships", "Stealth encouraged"

### Pillar 1: 羁绊优先
组对羁绊比单纯堆叠高数值更重要，玩家应因“构筑正确”而获胜。

*Design test*: 如果在“提高单卡面板”与“强化羁绊协同”之间选择，优先强化羁绊协同。

### Pillar 2: 5分钟一局
任何系统都要服务于短局闭环，保证移动端碎片时间可完成完整体验。

*Design test*: 若某功能让平均局时明显超过目标，则拆分、简化或延期。

### Pillar 3: 站位博弈
九宫格位置变化必须显著影响结果，让“换一格”成为真实策略。

*Design test*: 若站位调整对胜率影响不明显，必须重做目标选择或技能作用域规则。

### Pillar 4: 低门槛高上限
新手快速上手，高手通过资源运营与转型时机建立优势。

*Design test*: 新手三局内应理解核心规则；高手应能通过决策质量拉开胜率差。

### Anti-Pillars (What This Game Is NOT)

Anti-pillars are equally important — they prevent scope creep and keep the
vision focused. Every "no" protects the "yes."

- **NOT 重剧情主线**: 剧情产能会挤压玩法验证，且不服务于5分钟短局核心
- **NOT 重度付费养成**: Demo与首月目标是玩法口碑，不是数值付费驱动
- **NOT 联网PVP与赛季系统**: 单人开发周期内网络与运营成本不可控
- **NOT 超长单局（>15分钟）**: 违背移动端碎片化定位与快速重开节奏

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| 金铲铲之战 | 羁绊构筑与站位权重 | 单机、超短局、九宫格极简化 | 验证羁绊驱动策略有广泛受众 |
| 炉石酒馆战棋 | 回合运营与“再来一局”循环 | 三国题材与波次Boss检定 | 验证短循环策略体验可持续 |
| 杀戮尖塔 | 单机重开友好与失败学习 | 自走棋阵容+站位双决策 | 验证单机可形成高复玩与学习乐趣 |

**Non-game inspirations**: 三国演义人物关系与阵营对抗、古战场阵图思路、移动端碎片娱乐习惯。

---

## Target Player Profile

[Be specific. "Gamers" is not a target audience.]

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 16-35 |
| **Gaming experience** | 轻中度策略玩家（对自走棋有基础认知） |
| **Time availability** | 工作日5-20分钟碎片时间，周末可连续多局 |
| **Platform preference** | Android 手机 |
| **Current games they play** | 金铲铲之战、酒馆战棋、三国题材策略手游 |
| **What they're looking for** | 不依赖社交、可离线、短局但有策略深度 |
| **What would turn them away** | 数值失衡、强制长局、复杂养成、重氪驱动 |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot（你已熟悉；2D与UI效率高；1天Demo产出速度快） |
| **Key Technical Challenges** | 羁绊平衡、敌方AI目标选择、移动端性能与触控操作反馈 |
| **Art Style** | 像素2D |
| **Art Pipeline Complexity** | Low-Medium（先用占位资源+最小可读性） |
| **Audio Needs** | Minimal-Moderate（命中、羁绊触发、波次提示） |
| **Networking** | None |
| **Content Volume** | Demo：12-18名武将、6-8条羁绊、1张九宫格战场、3类波次 |
| **Procedural Systems** | 轻量随机商店与敌方波次变体 |

---

## Risks and Open Questions

### Design Risks
[Things that could make the game unfun or uncompelling]
- 强势羁绊过于集中，导致“唯一正确答案”
- 5分钟内信息密度过高，新手理解压力大

### Technical Risks
[Things that could be hard or impossible to build]
- 武将技能与目标选择规则耦合导致调试复杂
- 安卓低端机上粒子/动画叠加造成帧率波动

### Market Risks
[Things that could prevent commercial success]
- 三国+自走棋赛道存在成熟竞品，差异点需更明确
- 单机定位可能降低长线传播，需要强口碑与迭代节奏

### Scope Risks
[Things that could blow the timeline]
- 美术与武将数量扩张过快
- 过早引入局外系统导致开发分散

### Open Questions
[Things that need prototyping or research before we can answer]
- 5分钟局时下，玩家是否仍能感到“构筑成型”的满足？（通过1天Demo留存与复玩次数验证）
- 哪些羁绊阈值最易失衡？（通过自动对局与手动对局样本统计验证）

---

## MVP Definition

[The absolute minimum version that validates the core hypothesis. The MVP
answers ONE question: "Is the core loop fun?"]

**Core hypothesis**: 玩家会因为“短局内羁绊构筑+站位博弈”而连续重开，并在单局失败后愿意立即再来一局。

**Required for MVP**:
1. 九宫格布阵 + 自动战斗 + 普通/精英/Boss三波结构
2. 12+武将、6+羁绊、基础商店刷新与经济规则
3. 清晰战斗反馈（羁绊激活提示、伤害与失败原因）

**Explicitly NOT in MVP** (defer to later):
- 联网PVP、排行榜、赛季
- 完整剧情战役与复杂局外养成树

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1个战场、12-18武将、6-8羁绊 | 核心对局闭环 | 1天Demo + 1周打磨 |
| **Vertical Slice** | 增至20-24武将、10羁绊 | 轻度局外解锁、更多Boss机制 | 2周 |
| **Alpha** | 30+武将、2套地图主题 | 完整主要流派可玩 | 3-4周 |
| **Full Vision** | 多章节主题与稳定平衡版本 | 优化、美术升级、长线内容 | 1个月+ |

---

## Next Steps

- [ ] Get concept approval from creative-director
- [ ] Fill in COPILOT.md technology stack based on engine choice (`/setup-engine`)
- [ ] Create game pillars document (`/design-review` to validate)
- [ ] Decompose concept into systems (`/map-systems` — maps dependencies, assigns priorities, guides per-system GDD writing)
- [ ] Create first architecture decision record (`/architecture-decision`)
- [ ] Prototype core loop (`/prototype [core-mechanic]`)
- [ ] Validate core loop with playtest (`/playtest-report`)
- [ ] Plan first milestone (`/sprint-plan new`)
