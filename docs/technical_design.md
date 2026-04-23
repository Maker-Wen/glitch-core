# 《故障核心》(Glitch Core) 技术开发设计文档

## 1. 架构总览 (Architecture Overview)

本项目采用 **Godot Engine 4.x** 进行开发，目标平台为 WebGL/HTML5。
整体架构采用 **Manager/Autoload 模式** 结合 **节点组合 (Node Composition)** 模式。

### 1.1 全局单例 (Autoloads / Singletons)
*   **GameManager**: 负责整体游戏状态流转（MainMenu, InGame, GameOver, RunComplete）。
*   **TurnManager**: 负责战斗内的回合状态机（Deployment, PlayerTurn, EnemyTelegraph, EnemyExecute）。
*   **GridManager**: 维护 64-100 格微型战术地图的数据状态，处理逻辑坐标 (Grid X, Y) 到物理坐标 (World Position) 的转换，检查碰撞和寻路。
*   **DataManager**: 管理 Roguelike 局外/局内资源（HP，权限密钥，当前队伍模块及强化状态）。
*   **SignalBus**: 集中管理全局事件信号（如 `unit_moved`, `damage_taken`, `turn_changed`）。

### 1.2 核心场景结构 (Core Scene Structure)
```text
res://
├── Core/
│   ├── Main.tscn (入口场景，挂载 GameManager 等非全局但跨关卡的节点)
│   ├── Battle/
│   │   ├── BattleScene.tscn (单局战斗主场景)
│   │   ├── GridMap.tscn (管理异形微型地图和地形)
│   │   └── UnitSpawnPoints.tscn
├── Entities/
│   ├── BaseUnit.tscn (所有单位的基类)
│   ├── Player/
│   │   └── Modules/ (冲锤, 钩爪, 阻断 等具体预制体)
│   └── Enemies/
│       └── Viruses/ (蠕虫, 木马, 逻辑炸弹 等具体预制体)
├── Systems/
│   ├── CommandSystem/ (命令模式相关逻辑)
│   └── TelegraphSystem/ (预警表现层)
└── UI/
    ├── HUD.tscn
    ├── TelegraphOverlay.tscn
    └── TerminalTheme.tres (全息黑客终端 UI 主题)
```

## 2. 核心系统设计 (Core Systems)

### 2.1 网格与空间系统 (Grid System)
*   **数据结构**: 使用 Dictionary (键为 `Vector2i`) 存储每个格子的状态（地形类型、占用单位、Hazard），以支持不规则形状的微型战术地图（64-100格）。
*   **坐标转换**: 逻辑层全部使用二维坐标 `Vector2i`。表现层通过 `GridManager.grid_to_world(Vector2i)` 获取实际像素坐标。
*   **TileMapLayer**: 表现层使用 `TileMapLayer` 绘制基础地板和特殊地形（坏死扇区、加速带），利用 Autotile 处理不规则边缘。

### 2.2 战斗回合状态机 (Turn State Machine)
战斗遵循严格的完美信息时序：
0.  `State_Deployment`: **第 0 回合（布阵阶段）**。敌人已生成并展示第一回合攻击意图。玩家在限定的“安全部署区”内自由拖拽放置 3 个单位。
1.  `State_InitTurn`: 初始化当前回合，处理地块的环境倒计时变化。
2.  `State_EnemyTelegraph`: 遍历所有存活敌人，生成它们的下回合行动意图（Action Intent），交由 TelegraphSystem 在 UI 上渲染。
3.  `State_PlayerTurn`: 玩家操作期。玩家可以选择单位移动和施放技能。
    *   此时引入 **Command 模式** 模拟操作。玩家的悬停（Hover）会生成一份虚拟的网格状态快照，用于预览推挤结果。
4.  `State_EnemyExecute`: 敌人严格按照 Telegraph 阶段记录的 **方向、动作、相对范围** 执行。
    *   *关键逻辑*: 敌人的 Action Intent 绑定在敌人实体上。如果敌人被玩家推到了新位置，执行时原方向和动作不变，但作用的网格目标变为新位置衍生出的区域。
5.  `State_EnvironmentResolve`: 结算环境效果（如加速带强制位移、深渊秒杀判定）。
6.  `State_CheckWinLoss`: 判断核心是否毁灭，或敌人是否全灭。

### 2.3 命令与动作流 (Command & Action System)
为了支持“完美预览”和“推拉碰撞连轴”，所有改变网格状态的行为必须封装为 **Command** 或 **Action** 对象。

*   `ActionPush(target_unit, direction, distance)`:
    *   检查目标方向的下一格。
    *   如果为空地，目标单位平移 1 格。
    *   如果为深渊，目标单位平移并触发秒杀。
    *   如果是障碍物/边界，触发碰撞（双方受伤逻辑）。
*   `ActionDamage(target_unit, amount)`: 处理受击表现和血量扣除。

**预览逻辑 (Preview Logic)**:
深拷贝一份当前的 Grid 逻辑数据，将玩家欲执行的 Action 投入这个虚拟 Grid 中运算，将运算后的结果（位移、伤害、碰撞）返回给 UI 层渲染出虚线和高亮。

### 2.4 实体组件 (Entity Components)
采用 Godot 的节点组合方式搭建单位：
*   `BaseUnit` (CharacterBody2D 或 Area2D)
    *   `HealthComponent`: 处理血量和死亡。
    *   `GridMovementComponent`: 处理在网格上的平滑移动插值 (Tween)。
    *   `ActionComponent`: 定义该单位能执行的具体技能（如 冲锤、拉扯、自爆）。
    *   `TelegraphComponent`: 负责向系统注册自己的攻击意图。

## 3. UI/UX 与表现层 (Visuals & Telegraphing)

### 3.1 预警系统 (Telegraph System)
这是本游戏最重要的表现反馈层。
*   **数据模型**: `Intent { source: Unit, type: MOVE/ATTACK/EXPLODE, target_grids: Array[Vector2i], damage: int }`
*   **视觉呈现**:
    *   **攻击线**: 使用 `Line2D` 配合发光 Shader 绘制从敌人指向目标格的虚线。
    *   **危险区域**: 在对应的 Tile 上叠加一个红色的高亮 Sprite，带有呼吸和扫描线 Shader（Holographic Terminal Style）。

### 3.2 碰撞与受击表现 (Juice & Game Feel)
*   **Hit Stop (顿帧)**: 当发生碰撞或击杀时，通过 `Engine.time_scale` 短暂降速（如降至 0.05 持续 0.1s），增强打击感。
*   **Camera Shake (屏幕震动)**: 根据伤害量和碰撞级别，调用相机的震动脚本。
*   **Glitch Effect (故障特效)**: 敌人受击或死亡时，不使用传统的流血，而是材质上的 Chromatic Aberration（色差）和像素撕裂 Shader 效果。

## 4. 数据与养成体系 (Data & Progression)

### 4.1 局外养成 (Meta-Progression)
*   建立全局持久化系统，记录玩家游戏进度。
*   玩家通过战斗获得“元数据（Meta-Points）”，在局外的【机库】界面中解锁新的机甲（新的 `UnitData.tres`）、新的骇客协议（卡牌种类）及初始遗物。

### 4.2 局内卡组与抽牌系统 (Deck & Hand System)
*   **DeckManager**: 负责洗牌、抽牌、弃牌逻辑。
*   **骇客协议卡牌 (Hack Cards)**: 基于 Godot `Resource`，每张卡包含指向目标环境的 Action 函数引用（如生成障碍物、强制滑动等）。
*   在 `State_PlayerTurn` 中，不仅能发送单位移动/攻击指令，也能使用手牌打出指令。

### 4.3 三位一体局内升级 (In-Run Upgrades)
战斗结束后，弹出三选一奖励池，分别挂载在不同层级：
1.  **机甲固件 (Firmware)**: 直接修改目标单位的 `HealthComponent` 或 `ActionComponent` 属性。
2.  **卡牌软件 (Software)**: 将新的 Card Resource 塞入 `DeckManager` 的抽牌堆。
3.  **全局遗物 (Artifacts)**: 挂载在 `DataManager` 上的被动 Listener，监听 `SignalBus` 的事件（如触发连环碰撞时，拦截并翻倍伤害）。

### 4.4 局内机甲劫持机制 (Hijacking)
*   实现判定逻辑：当标识为“可劫持”的敌方单位进入指定的“净化区 (Tile)”并且回合结束时，不执行击杀，而是触发捕获逻辑。
*   在关卡结算时，通过 UI 提供交换界面，更新玩家的小队数据列阵。

## 5. 开发里程碑划分 (Milestones)

*   **Phase 1: 白盒原型 (Greybox Prototype)**
    *   实现不规则微型网格生成、基于第0回合的布阵系统、点击移动。
    *   实现基础的推 (Push) 和 墙壁碰撞逻辑。
    *   实现回合时序：部署 -> 玩家操作 -> 敌人意图生成 -> 敌人执行。
*   **Phase 2: 核心解谜闭环与波次 (Core Puzzle & Waves)**
    *   加入拉扯 (Pull) 技能和环境秒杀坑洞 (Void)。
    *   完善 UI 预览，做到“鼠标悬停即见结局”。
    *   实装基础敌人，引入波次生成器 (Wave Spawner) 逻辑。
*   **Phase 3: 肉鸽与卡组系统 (Roguelike & Decks)**
    *   实现 DeckManager（卡牌抽滤系统）与骇客协议使用。
    *   实现三位一体（固件、软件、遗物）的局内强化。
    *   实现劫持机制 (Hijacking)。
*   **Phase 4: 表现力打磨 (Polish)**
    *   替换美术素材为赛博朋克高精度资产。
    *   完善 Shader、顿帧、音效。