# 战斗流程 UI 表现设计

> 日期：2026-06-02  
> 范围：战斗流程中的敌人移动顺序、敌人攻击顺序、攻击意图预演、玩家行动预演与结算反馈。  
> 结论：采用 **棋盘编号 + 敌方行动顺序栈 + 玩家预演同步刷新** 的混合式表现方案。

## 1. 设计目标

当前战斗规则是完美信息战棋：敌人在回合开始移动，玩家回合处理敌人锁定的攻击意图，回合末敌人按既定顺序尝试攻击。问题不在规则本身，而在玩家难以稳定读懂以下信息：

1. 敌人移动和攻击的先后顺序。
2. 敌人攻击意图何时生成、何时锁定。
3. 玩家移动、推拉、挡线、击杀后，敌方攻击是否仍会命中。
4. 敌方攻击线打空时，系统为什么仍然播放该敌人的结算。

本设计的目标是让玩家在不阅读规则说明的前提下，通过 UI 直接获得这些判断。

## 2. 核心方案

采用混合式信息架构：

- 棋盘负责表达“在哪里发生”：敌人位置、移动路径、攻击格、攻击线、命中范围、伤害数字、地裂预告。
- 敌方行动顺序栈负责表达“按什么顺序发生”：敌人编号、敌人名称和轻量状态标记。
- 玩家预演负责表达“我的操作会改变什么”：棋盘临时预演结果，同时刷新攻击线、伤害数字和顺序栈状态。

不采用纯棋盘编号方案，因为敌人数量上升后编号和攻击线会挤在棋盘上。不采用纯时间轴方案，因为玩家视线会频繁离开棋盘，空间判断成本变高。

## 3. 信息架构

### 3.1 棋盘层

棋盘层显示空间信息：

- 敌人头顶显示本轮行动编号。
- 敌人移动前短暂显示移动路径。
- 敌人攻击锁定后显示攻击格或攻击线。
- 仍会出手的攻击使用红色高亮，即使当前实际攻击格为空。
- 只有敌人已死亡、坠落、被移除或攻击方向无效时，才移除该敌人的攻击线。
- 伤害数字只显示在实际会受到伤害的单位或建筑格上。
- 被悬停或在顺序栈中选中的敌人，棋盘上只强化该敌人的攻击信息，其他敌人信息降低透明度。

敌人编号来源于敌方执行顺序，不直接暴露底层 enemy id。编号在同一个敌方行动阶段内稳定。

### 3.2 敌方行动顺序栈

顺序栈是敌方意图的主解释区，建议放在棋盘右侧；若横向空间不足，可放在上方或折叠成横向队列。

每条敌人条目至少包含：

| 字段 | 表现 |
| --- | --- |
| 顺序编号 | 与棋盘敌人头顶编号一致 |
| 敌人名称 / 图标 | 例如腐食兽、瘟疫弓手、铁角兽 |
| 状态标记 | 图形标记表达命中、空击、已移除、无攻击 |

条目状态颜色：

| 状态 | 颜色 / 视觉 |
| --- | --- |
| 会出手 | 红色边框或实心状态标记 |
| 空击 | 保留红色攻击线；条目弱化，不显示伤害文字 |
| 已死亡 / 已推出棋盘 | 折叠为完成态，不再显示攻击线 |
| 当前结算中 | 条目放大或发光，棋盘同步聚焦 |

### 3.3 交互联动

棋盘与顺序栈必须双向联动：

- 鼠标悬停敌人：顺序栈对应条目高亮，棋盘只强化该敌人的路径和攻击线。
- 鼠标悬停顺序栈条目：棋盘高亮对应敌人、攻击线和目标格。
- 玩家选择行动目标时：顺序栈进入临时预演态，显示行动后敌方攻击的命中变化。
- 玩家确认行动后：临时预演态转为真实状态，等待下一次玩家操作或回合末结算。

## 4. 单回合完整表现流程

### 4.1 回合开始：地裂与敌人移动

触发条件：进入新一轮。

表现流程：

1. 顶部阶段标签显示“第 N 轮 · 敌方移动”。
2. 上回合预告的地裂先播放出怪表现。
3. 系统生成本轮敌人计划，并计算敌方执行顺序。
4. 敌人按执行顺序逐个移动。
5. 每个敌人移动前，持续 0.3-0.5 秒显示：
   - 敌人头顶编号。
   - 顺序栈对应条目高亮。
   - 起点到落点的移动路径。
6. 敌人移动完成后，编号保留在敌人头顶，但移动路径淡出。

说明：如果多个敌人从地裂出现并立即移动，仍按顺序逐个播放。禁止多个敌人同时移动，否则顺序信息会丢失。

### 4.2 意图锁定：生成攻击队列

触发条件：敌人移动全部完成，进入玩家回合前。

表现流程：

1. 顶部阶段标签短暂显示“敌方意图锁定”。
2. 棋盘显示所有敌人的攻击格或攻击线。
3. 顺序栈生成所有本轮会尝试攻击的敌人条目。
4. 不会攻击的敌人不进入攻击队列，但头顶保留弱编号。
5. 0.5 秒后进入玩家回合，顶部阶段标签显示“玩家回合 · 敌方攻击已锁定”。

锁定后的原则：

- 敌人攻击意图不会因为玩家操作而重新规划。
- 玩家操作会改变敌人当前位置、挡线关系和实际攻击格。
- 攻击方向由 `plan.move_to → plan.attack_pos` 锁定；被推走后从敌人当前格沿原方向重新投射。
- UI 不应让玩家误解为敌人会重新选目标。

### 4.3 玩家回合：处理威胁

触发条件：玩家可以操作守卫者。

默认表现：

- 棋盘保留敌人攻击线和目标格。
- 顺序栈保留敌人攻击顺序和状态。
- 红色表示该敌人仍会按锁定方向出手。
- 棋盘伤害数字表示当前实际会受到的伤害；没有伤害数字代表该红线当前打空或只表示攻击方向。

玩家悬停一个移动或攻击目标时：

1. 系统调用与真实行动一致的预演逻辑。
2. 棋盘显示本次行动的移动、攻击、推动、坠落、撞击、伤害结果。
3. 顺序栈同步切换到临时预演态：
   - 原本命中的攻击如果被推开，棋盘攻击线平移到新的实际攻击格。
   - 新攻击格为空时，棋盘不显示伤害数字，但攻击线仍保留红色。
   - 原本命中但挡线后变为空击的条目弱化。
   - 被击杀或被推出棋盘的敌人条目变为“已移除”。
   - 仍会命中的条目保持红色。
4. 预演态必须有明显但轻量的临时标识，例如“预演后”标签或虚线边框。
5. 鼠标离开目标格或取消行动后，顺序栈恢复真实当前状态。

玩家确认行动后：

1. 播放玩家行动动画。
2. 如果行动包含敌方位移，旧攻击线先隐藏；位移动画完成后，棋盘与顺序栈更新为真实结果。
3. 如果行动导致敌方攻击状态变化，需要给顺序栈条目一个短反馈：
   - “命中 → 空击”可弱化一次状态标记，但棋盘红线仍保留。
   - “命中 → 已死亡”可划掉或折叠。
   - “空击 → 命中”必须闪红并出现伤害数字，提示玩家新风险。

### 4.4 回合末：敌人逐条攻击结算

触发条件：玩家结束回合，或所有守卫者行动结束。

表现流程：

1. 顶部阶段标签显示“敌方攻击”。
2. 顺序栈从编号 1 开始逐条结算。
3. 当前条目放大或发光，棋盘只高亮该敌人的攻击线和目标格。
4. 如果会命中：
   - 播放攻击线 / 近战打击表现。
   - 播放目标受击、伤害数字、HP 变化、建筑受损或单位死亡。
   - 条目标记为“已命中”。
5. 如果攻击线打空：
   - 播放红色攻击线扫向实际攻击格的挥空表现。
   - 目标不受伤。
   - 条目标记为空击 / 完成。
6. 如果敌人已死亡、坠落或被移除：
   - 不播放攻击线。
   - 条目直接显示“已移除”，然后折叠或淡出。
7. 所有条目结算完毕后，顺序栈清空或淡出，进入下一轮。

空击不能直接跳过。保留攻击槽能让玩家理解“敌人确实执行了自己的攻击，只是当前攻击线没有打到可伤害目标”。

## 5. 预演出现时机

预演分为两类：敌方意图预演和玩家行动预演。

### 5.1 敌方意图预演

出现时机：

- 敌人完成回合开始移动后。
- 玩家回合开始前。
- 玩家回合中常驻显示。

隐藏时机：

- 进入敌方攻击结算时，改为逐条聚焦显示。
- 该轮敌方攻击全部结算后清空。
- 战斗结束时清空。

### 5.2 玩家行动预演

出现时机：

- 玩家选中守卫者后，显示可移动格和可攻击格。
- 玩家悬停具体行动目标时，显示该行动的完整结果。

隐藏时机：

- 鼠标离开目标格。
- 玩家取消选择。
- 玩家确认行动并播放实际动画。
- 战斗进入敌方攻击结算。

玩家行动预演必须与实际结算共用逻辑，避免 UI 预演和真实结果不一致。

## 6. 边界情况规则

### 6.1 敌人本轮只移动不攻击

表现：

- 回合开始移动时显示编号和路径。
- 玩家回合中不进入攻击顺序栈。
- 头顶编号降低透明度保留，用于说明它参与了本轮移动顺序。

### 6.2 敌人攻击线打空但攻击槽仍存在

表现：

- 顺序栈条目保留。
- 图形状态标记弱化。
- 棋盘保留红色攻击线，表示敌人仍会按锁定方向出手。
- 棋盘不显示伤害数字。
- 回合末播放挥空表现。

### 6.3 敌人被击杀或推出棋盘

表现：

- 顺序栈条目从攻击态转为完成态。
- 状态显示“已死亡”或“已坠落”。
- 棋盘移除对应攻击线。
- 回合末轮到该编号时，条目快速确认后跳过攻击动画。

### 6.4 远程敌人被挡线

表现：

- 攻击方向仍按原方向锁定。
- 如果新的挡线会导致命中其他单位，应在棋盘上把伤害数字显示到新目标格。
- 如果射线当前没有可伤害目标，保留红色攻击线，但不显示伤害数字。
- 顺序栈不写长文目标摘要，空间结果由棋盘表达。

### 6.5 近战敌人被推离

表现：

- 攻击方向仍按原方向锁定。
- 攻击格从敌人当前实际位置沿原方向平移 1 格。
- 若新攻击格为空，保留红色攻击线但不显示伤害数字。
- 若新攻击格有守卫者或建筑，则显示该格伤害数字并按新目标结算。
- 玩家确认行动后，旧攻击线先隐藏，等敌人推移动画完成后再刷新新攻击线。

### 6.6 地裂出怪被占位延迟

表现：

- 地裂保留下回合出怪预告。
- 如果单位站在地裂上导致延迟，地裂图标显示“延迟”状态。
- 顺序栈不提前显示未来敌人，避免玩家误以为它本轮会行动。

## 7. 视觉语言建议

| 信息 | 建议表现 |
| --- | --- |
| 行动编号 | 敌人头顶圆形小牌，琥珀色或白底深字 |
| 当前出手 | 红色攻击格 / 攻击线，顺序栈红色状态 |
| 当前空击 | 红色攻击线保留，不显示伤害数字，顺序栈状态标记弱化 |
| 玩家预演 | 虚线、半透明或“预演后”标签 |
| 当前结算条目 | 顺序栈条目放大 / 发光，棋盘其他攻击线降透明 |
| 地裂预告 | 金色脉冲，不显示敌人种类 |

棋盘上不堆长文字。复杂解释放到顺序栈、悬浮详情或教程中。

## 8. 动画表现规范

动画目标不是“炫”，而是把战斗时序讲清楚。所有动效都应服务三个判断：谁先行动、攻击是否锁定、实际伤害落在哪里。

### 8.1 动效总原则

1. 棋盘信息优先，UI 面板动画不能遮挡棋盘关键格。
2. 普通状态变化使用短动画，避免拖慢战斗节奏。
3. 同一类状态使用同一套动效语言，不能每个敌人各做一套特效。
4. 玩家悬停预演必须即时，目标是 0.1 秒内给反馈。
5. 敌方结算可以稍慢，因为这是战斗结果确认阶段。
6. 普通攻击不移动镜头；只有建筑被毁、守卫者死亡、战斗结束可使用轻微镜头震动。

### 8.2 回合开始：地裂出怪与敌人移动

| 节点 | 时长 | 动画表现 | 目的 |
| --- | --- | --- | --- |
| 阶段标签切换 | 0.25 秒 | 顶部文字淡入，“敌方移动”短暂亮起 | 告诉玩家进入敌方流程 |
| 地裂预告激活 | 0.35 秒 | 地裂金色脉冲加快，中心亮起 | 说明上一轮预告兑现 |
| 敌人从地裂出现 | 0.45 秒 | 敌人从格子中心缩放出现，轻微上浮，阴影落定 | 明确新敌人来源 |
| 当前敌人行动聚焦 | 0.2 秒 | 敌人头顶编号放大 110%，顺序栈同编号条目亮起 | 告诉玩家轮到谁 |
| 移动路径显示 | 0.15 秒 | 路径格按起点到终点依次点亮 | 说明移动路线 |
| 敌人移动 | 每格 0.12-0.16 秒 | 沿路径平滑移动，到终点轻微停顿 | 保持顺序可读 |
| 路径淡出 | 0.2 秒 | 移动路径透明度降低到 0 | 避免残留信息干扰 |

移动阶段禁止多个敌人同时移动。若敌人数量很多，可以略微缩短单格移动时间，但不能并行播放。

### 8.3 意图锁定：攻击线与顺序栈出现

| 节点 | 时长 | 动画表现 | 目的 |
| --- | --- | --- | --- |
| 阶段标签 | 0.25 秒 | 顶部显示“敌方意图锁定” | 建立锁定时点 |
| 攻击格出现 | 0.18 秒 | 攻击目标格由中心向外扩散一圈红色边框 | 告诉玩家哪里会被打 |
| 远程攻击线出现 | 0.22 秒 | 攻击线从敌人位置扫向目标格 | 表达射线方向 |
| 顺序栈生成 | 0.04 秒 / 条 | 条目按编号逐条滑入或淡入 | 表达结算顺序 |
| 常驻状态稳定 | 0.5 秒后 | 红色攻击线保持低强度呼吸 | 表示当前仍会命中 |

攻击线出现时不要一次性全屏爆亮。应按敌方攻击顺序依次出现，让玩家把棋盘上的线和顺序栈编号对应起来。

### 8.4 玩家回合：悬停预演与状态刷新

| 节点 | 时长 | 动画表现 | 目的 |
| --- | --- | --- | --- |
| 选中守卫者 | 0.12 秒 | 守卫者底盘亮起，可移动格淡入 | 进入可操作状态 |
| 悬停移动格 | 0.08-0.12 秒 | 移动路径虚线出现，落点出现半透明幻影 | 说明移动结果 |
| 悬停攻击目标 | 0.08-0.12 秒 | 攻击方向、推动方向、伤害标记同步出现 | 说明行动结果 |
| 敌方状态预演刷新 | 0.12 秒 | 攻击线平移、伤害数字出现 / 消失，或条目变为“已移除” | 说明威胁变化 |
| 取消悬停 | 0.08 秒 | 预演层快速淡出，顺序栈恢复真实态 | 防止玩家误读为已执行 |
| 确认行动 | 按事件播放 | 预演态转真实态，变化条目闪一次 | 强化行动已生效 |

预演态必须和真实态有区别。建议使用虚线、半透明、浅色标签“预演后”，避免玩家误以为悬停已经提交操作。

### 8.5 回合末：敌人攻击逐条结算

| 节点 | 时长 | 动画表现 | 目的 |
| --- | --- | --- | --- |
| 进入敌方攻击 | 0.25 秒 | 顶部阶段标签切换，顺序栈整体亮起 | 告诉玩家开始结算 |
| 当前条目聚焦 | 0.15 秒 | 条目放大 104%，编号发光，其他条目降透明 | 表达当前结算对象 |
| 攻击线聚焦 | 0.12 秒 | 棋盘只保留当前敌人的攻击线，其他线降到 30% 透明度 | 降低视觉噪音 |
| 命中攻击 | 0.16-0.25 秒 | 红色攻击线快速扫向目标，目标受击闪白 / 红 | 确认伤害发生 |
| 空击攻击 | 0.18 秒 | 红色攻击线扫向实际攻击格后消散，无受击闪光 | 表达尝试攻击但未命中 |
| 已移除敌人 | 0.12 秒 | 条目显示“已移除”并折叠 | 不浪费攻击动画时间 |
| 条目完成 | 0.1 秒 | 条目右侧出现完成标记，进入下一条 | 表达结算进度 |

空击攻击必须有表现，不能静默跳过。玩家需要看到“这个敌人确实结算了，只是当前攻击线打空”。

### 8.6 状态变化动效

| 状态变化 | 动画表现 |
| --- | --- |
| 命中 → 空击 | 攻击线平移到新格并保留红色，目标伤害数字消失 |
| 命中 → 已死亡 | 条目短暂闪红后折叠，棋盘攻击线快速收回 |
| 空击 → 命中 | 攻击线保留红色，新目标格出现伤害数字并闪一次 |
| 目标建筑受损 | 建筑格闪红，HP 条扣减，轻微碎片粒子 |
| 建筑被毁 | 棋盘轻微震动 0.12 秒，建筑变废墟，顺序栈保留造成破坏的敌人条目 |
| 守卫者死亡 | 单位头像和棋盘模型同步暗下，顶部可短暂提示 |
| 地裂延迟 | 地裂脉冲降速，显示小型“延迟”状态 |

### 8.7 缓动与节奏

推荐统一使用以下节奏：

- 淡入 / 淡出：ease-out，0.12-0.22 秒。
- 条目滑入：ease-out-cubic，0.18 秒。
- 敌人出现：back-out，0.35-0.45 秒。
- 受击闪烁：linear 或 ease-out，0.08-0.14 秒。
- 聚焦放大：scale 1.00 → 1.04 或 1.10，不超过 1.10。

避免使用高弹性、大幅弹跳、长时间旋转和全屏闪白。这些效果会破坏战术阅读。

## 9. AI 概念图生成提示词

本节用于生成 UI 概念图 / 效果图。目标是让图像 AI 生成“接近最终战斗界面”的视觉参考，而不是生成精确可用的 UI 素材。生成后仍需由 UI / 美术二次整理。

### 9.1 主界面概念图提示词

```text
Use case: ui-mockup
Asset type: 16:9 game combat UI concept image
Primary request: Create a polished tactical roguelite battle UI mockup showing a dark gothic 2.5D grid battlefield with enemy action order clarity.
Scene/backdrop: An 8x8 orthographic stone dungeon battlefield, ruined sanctuary architecture, muted dark fantasy atmosphere, readable tactical board, no decorative background clutter.
Main UI layout: The board occupies the left 70% of the screen. A vertical enemy action order stack occupies the right 25% of the screen. A compact top bar shows round and phase. A bottom ability bar shows the selected hero actions.
Board details: Three enemy tokens on the board, each with a small circular amber action number badge above it: 1, 2, 3. Red attack warning tiles and red attack lines show attacks that will hit. One gray dashed attack line shows an attack that has been neutralized but will still resolve. One friendly hero token and one protected building tile are visible.
Right panel details: Enemy Action Order panel with three stacked rows. Row 1 says hit state in red, Row 2 says hit state in red, Row 3 says miss or neutralized state in gray. Each row has the same number as the enemy badge on the board.
Visual style: Premium dark fantasy tactical game UI, clean readable panels, restrained red and amber highlights, subtle glow, crisp silhouettes, compact information density, professional game production mockup.
Composition: Clear hierarchy, board readable at a glance, enemy order panel easy to scan, no marketing hero layout, no oversized decorative cards.
Text handling: Use simple short UI labels only. Text may be stylized but should not be tiny or cluttered.
Avoid: purple gradient UI, sci-fi holograms, cute cartoon style, mobile gacha clutter, huge cinematic characters covering the board, illegible tiny text, excessive particle effects, photorealistic humans, brand logos, watermarks.
```

### 9.2 玩家预演态概念图提示词

```text
Use case: ui-mockup
Asset type: 16:9 game combat UI concept image
Primary request: Create a tactical battle UI mockup focused on player action preview and threat resolution feedback.
Scene/backdrop: Same dark gothic 8x8 orthographic board, clear tactical readability.
Interaction state: A player hero is selected. A hovered attack target shows a translucent preview path, push direction arrow, damage marker, and ghosted final enemy position.
Enemy intent feedback: The right enemy action order stack updates into preview mode. One enemy row changes from red "will hit" to gray "will miss / neutralized". Another enemy row is marked removed or defeated. Remaining threats stay red.
Board feedback: Red attack lines show threats that still hit. Gray dashed lines show neutralized enemy attacks. Preview elements use translucent amber and pale blue ghost overlays, distinct from committed results.
UI details: Add a small "Preview after action" label near the enemy order panel. Keep the board uncluttered. Use numbered badges that match the enemy rows.
Visual style: Polished dark fantasy tactics UI, high readability, disciplined colors, restrained animation still frame, no clutter.
Avoid: ambiguous labels, overwhelming red overlays, full-screen effects, decorative fantasy illustration taking over the UI, unreadable micro text, brand logos, watermarks.
```

### 9.3 敌方结算态概念图提示词

```text
Use case: ui-mockup
Asset type: 16:9 game combat UI concept image
Primary request: Create a tactical battle UI mockup showing enemy attack resolution order.
Scene/backdrop: Dark gothic 8x8 orthographic dungeon board with a visible protected building and player hero.
Resolution state: The enemy action order stack is resolving row 2. Row 2 is enlarged and glowing amber-red. Rows 1 and 3 are dimmed. On the board, only enemy 2's attack line is strongly highlighted, while other enemy warnings are faded.
Hit and miss language: One completed row shows a hit checkmark. One later row shows gray "miss / neutralized". The active attack line is red if it will hit, or gray if it will miss.
Motion cue in still image: Add a directional streak along the active attack line, subtle impact glow on the target tile, and a small completion marker in the order stack.
Visual style: Premium dark fantasy tactical UI, readable combat feedback, compact panels, no cinematic cut-in, no excessive screen shake.
Avoid: explosions covering board cells, anime special attack cut-ins, complex unreadable text, sci-fi UI, bright neon palette, watermarks.
```

### 9.4 移动端 / 窄屏构图提示词

```text
Use case: ui-mockup
Asset type: portrait mobile tactical battle UI concept
Primary request: Create a mobile portrait version of the same tactical roguelite battle UI.
Layout: The 8x8 board fills the upper 65% of the screen. The enemy action order stack becomes a horizontal numbered strip below the board. The selected hero ability bar sits at the bottom.
Key readability: Enemy numbered badges on the board match the horizontal enemy order strip. Red means will hit. Gray means neutralized. Keep labels short and large enough for mobile.
Visual style: Dark gothic tactical game, compact but readable, restrained highlights, no excessive card stacking.
Avoid: tiny text, overlapping bottom controls, decorative panels covering board, one-color purple or blue palette, watermarks.
```

### 9.5 负面提示词通用清单

```text
Avoid unreadable small text, excessive particle effects, cinematic character portraits covering the board, marketing landing page composition, sci-fi hologram UI, cute cartoon chibi style, noisy gacha UI, purple gradient domination, bright neon cyberpunk palette, illegible icons, overlapping UI panels, watermarks, logos, fake app store badges.
```

## 10. AI 动效分镜生成提示词

如果使用 AI 生成动效参考图或序列帧，建议按关键帧生成，不要求 AI 一次生成完整视频。每个关键帧都应保持同一棋盘构图和同一 UI 布局。

### 10.1 四帧流程分镜提示词

```text
Create a four-panel storyboard for a dark fantasy tactical roguelite combat UI. Keep the same 8x8 orthographic board and the same right-side enemy action order stack in every panel.

Panel 1: Enemy movement phase. Enemy number 1 is highlighted with an amber badge, its movement path is lit tile by tile, and the matching row in the order stack glows.
Panel 2: Enemy intent locked. Red attack warning tiles and red attack lines appear on the board. The enemy action order stack shows rows 1, 2, 3 with hit states.
Panel 3: Player preview. A selected hero previews an attack or push. One enemy attack line changes from red to gray dashed, and the matching order row changes to neutralized preview state.
Panel 4: Enemy attack resolution. Row 2 in the order stack is active and enlarged. Only enemy 2's attack line is strongly highlighted on the board. Other warnings are dimmed.

Style: polished game UI storyboard, clean readable tactical information, restrained dark gothic palette, amber order numbers, red danger, gray neutralized state, no clutter, no brand logos, no watermark.
```

### 10.2 单段动效生成提示词：敌方攻击结算

```text
Generate a short UI animation reference for a tactical roguelite battle screen, 3 seconds, 16:9.
The right-side enemy action order stack resolves one row at a time. The active row gently scales up and glows. The matching enemy numbered badge on the board glows. The active attack line sweeps from enemy to target. If it hits, the target tile flashes red and the row receives a hit check. If it misses, the gray dashed line breaks apart and the row receives a miss label. Other rows and attack lines are dimmed.
Camera remains fixed in orthographic view. No cinematic cuts. No large explosions. Keep all board cells readable.
```

### 10.3 单段动效生成提示词：玩家预演刷新

```text
Generate a short UI animation reference for a tactical roguelite battle screen, 2 seconds, 16:9.
A player hovers an attack target. A translucent amber preview arrow appears. A ghosted enemy final position appears. The enemy action order stack switches into preview mode: one red attack row weakens into an "empty shot" icon, while another row remains red. The board's corresponding red attack line slides from the enemy's new position along the original locked direction, and the damage number disappears from the previous target cell. When the hover is canceled, the preview elements fade out and the UI returns to the original state.
Camera remains fixed. The animation is quick, readable, and tactical. No excessive particles or camera shake.
```

## 11. 教程与首次引导

首次出现敌方意图锁定时，显示一次短引导：

```text
敌人已锁定攻击方向。编号表示敌人攻击顺序，红线表示仍会出手，格子上的伤害数字表示实际会受伤的位置。
```

首次玩家把敌人攻击线推到空格时，显示一次短反馈：

```text
攻击线已移开。该敌人仍会按顺序出手，但当前不会造成伤害。
```

引导必须短，不阻断玩家多次操作。后续可通过悬浮详情复看。

## 12. 数据与实现需求

UI 至少需要以下数据：

| 数据 | 用途 |
| --- | --- |
| 敌方执行顺序 | 生成编号和顺序栈 |
| 敌人当前格 | 绘制棋盘编号和攻击线起点 |
| 敌人计划落点 | 回合开始移动路径和说明 |
| 锁定攻击方向 / 射程 | 绘制攻击线 |
| 当前实际攻击格 | 绘制攻击线终点 |
| 当前实际伤害 | 在棋盘目标格显示伤害数字 |
| 玩家行动预演事件 | 预演伤害、位移、死亡、坠落和状态变化 |

当前工程已有可复用基础：

- `BattleEngine.enemy_execution_order()` 可作为编号来源。
- `BattleEngine.preview_action()` 可作为玩家行动预演来源。
- `PreviewOverlay.set_enemy_intents()` 已可显示敌方攻击意图。
- `BattleEvent.Type.ENEMY_ATTACK_STARTED` 和 `ENEMY_ATTACK_MISSED` 可用于攻击槽开始与空击结算表现。

后续实现重点不是改变战斗规则，而是补齐顺序栈 UI、预演态刷新和棋盘 / 顺序栈联动。

## 13. 验收标准

完成后应满足以下标准：

1. 玩家进入回合后，能直接看出敌人攻击顺序。
2. 玩家能区分“会命中”“仍会出手但当前打空”“已死亡 / 已移除”三种状态。
3. 玩家悬停行动目标时，能看到该行动对敌方攻击队列的影响。
4. 回合末敌人按顺序结算时，当前结算敌人、攻击线和顺序栈条目同步高亮。
5. 敌人空击不会被静默跳过，而是有结算表现。
6. 棋盘文字信息不过载，敌人多时仍能读懂主威胁。
7. 玩家预演结果与真实执行结果一致。
8. 动画不会拖慢普通回合操作，玩家悬停预演反馈应接近即时。
9. AI 概念图提示词能够生成含棋盘编号、顺序栈、红色攻击线、棋盘伤害数字四个核心元素的效果图。

## 14. 暂不纳入本次范围

以下内容不在本次设计范围内：

- 新增敌人 AI 行为或改变敌人攻击规则。
- 改变地裂出怪规则。
- 新增战斗胜负条件。
- 设计完整美术风格稿。
- 制作教程关卡的完整脚本。
- 直接产出最终游戏内 UI 贴图或动画资产。

本次只定义战斗流程 UI 表现和信息结构，为后续实现与美术稿提供依据。
