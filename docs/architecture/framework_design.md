# 《长夜余烬》框架设计 — 战斗垂直切片 Demo

> 本文档对应策划案 §15「第一阶段：战斗垂直切片」。范围限定为：
> **1 张 8×8 棋盘 + 3 守卫者 + 腐食兽 + 推/拉/接力推动 + 完美信息预演 UI + 撤销**
>
> 不在本切片范围：碎裂状态、弓手、铁角兽、建筑保护、守护值、Run 元、Boss、遗物、挑战目标、商店、营地。这些在后续阶段加入。
>
> 技术栈：Godot 4.6 + GDScript（参见 `project.godot`）。

---

## 1. 核心架构原则

完美信息棋盘游戏的核心架构特征：

| 原则 | 含义 | 实现策略 |
|---|---|---|
| **逻辑/表现严格分离** | 战斗状态机不依赖任何 Node/场景；可纯函数推演 | `scripts/battle/` 全部为 `Resource` / `RefCounted`，不继承 `Node` |
| **确定性结算** | 同样状态 + 同样操作 = 同样结果，无浮点、无随机 | 网格用整数坐标；推/拉用整数格数；A* tie-break 固定方向 |
| **状态快照可序列化** | 撤销 = 回放快照 | `BattleState` 提供 `clone()`；操作前压栈 |
| **预演 = 沙箱推演** | UI 预演就是"用真实 `BattleState.clone()` 跑一次操作"，不是另写预演逻辑 | 单一真相源：预演与执行走同一函数 |
| **事件驱动表现** | 状态机产出 `BattleEvent` 列表；视图层按事件播放动画 | `apply_action()` 返回 `Array[BattleEvent]` |

> **预演撒一次谎，设计就崩了**——策划案 §15 原话。这是本架构最重要的承诺：**预演与执行共用同一份代码路径**，杜绝 "UI 显示 vs 实际结算" 偏差。

---

## 2. 文件树

```
glitch-core/
├── project.godot
├── Scenes/
│   └── Main.tscn                       # 入口场景（已存在）
├── scripts/
│   ├── core/
│   │   └── game_manager.gd             # 游戏入口；当前阶段直接进战斗
│   │
│   ├── battle/                         # ⭐ 纯逻辑层（无 Node 依赖）
│   │   ├── battle_state.gd             # 战斗全状态快照；可 clone
│   │   ├── battle_engine.gd            # 状态机：执行 action / 推演 / 撤销
│   │   ├── unit.gd                     # 单位数据（守卫者/敌人共用）
│   │   ├── grid.gd                     # 8x8 棋盘 + 寻路 + tie-break
│   │   ├── physics_resolver.gd         # 原子结算链（推/拉/接力撞击）
│   │   ├── action.gd                   # 玩家动作（Move/Attack/EndTurn）
│   │   ├── battle_event.gd             # 结算事件（伤害/位移/死亡/...）
│   │   └── ai_decider.gd               # 敌人 AI：tie-break 决策
│   │
│   ├── data/                           # ⭐ 静态配置（Resource）
│   │   ├── unit_def.gd                 # 单位模板：HP/移动力/攻击参数
│   │   ├── map_def.gd                  # 地图骨架：尺寸/建筑/石柱/地裂位置
│   │   └── defs/                       # 具体配置文件（.tres）
│   │       ├── warden_bountyhunter.tres
│   │       ├── warden_graverobber.tres
│   │       ├── warden_mage.tres
│   │       ├── enemy_carrion_spawn.tres
│   │       └── map_tutorial_01.tres
│   │
│   ├── view/                           # ⭐ 表现层（Node 场景）
│   │   ├── battle_scene.gd             # 战斗场景根；持有 BattleEngine
│   │   ├── grid_view.gd                # 棋盘渲染（格子/地形）
│   │   ├── unit_view.gd                # 单个单位的视图（含位置插值）
│   │   ├── preview_overlay.gd          # 预演高亮：移动范围/攻击/连锁结果
│   │   ├── input_controller.gd         # 输入：点选 → 派发 Action
│   │   └── hud.gd                      # HUD：轮次/撤销按钮/结束回合
│   │
│   └── tests/                          # ⭐ 纯逻辑单测（GUT 或自写）
│       ├── test_physics_push.gd
│       ├── test_physics_relay.gd
│       ├── test_physics_pull.gd
│       └── test_ai_carrion.gd
│
└── Scenes/
    ├── Main.tscn                       # 已存在；指向 game_manager.gd
    ├── battle/
    │   ├── BattleScene.tscn
    │   ├── UnitView.tscn
    │   └── TileView.tscn
```

> **目录命名约定**：Godot 通常用小写 `scripts/`；场景文件用 `PascalCase.tscn`。和现有 `Scenes/Main.tscn` 风格保持一致。

---

## 3. 核心数据结构

### 3.1 `Grid`（棋盘）

```gdscript
class_name Grid extends RefCounted

const SIZE := 8

# tile_type 用整数枚举存储，节省内存且确定
enum TileType { EMPTY, PILLAR, BUILDING, RIFT, RUIN }

var tiles: Array[int] = []              # 长度 64；TileType
var tile_hp: Dictionary = {}            # {Vector2i: int} 仅石柱/建筑用

func in_bounds(p: Vector2i) -> bool
func get_tile(p: Vector2i) -> int
func blocks_movement(p: Vector2i) -> bool  # 建筑/石柱阻挡
func blocks_push(p: Vector2i) -> bool      # 含外缘 = 坠渊判断不在此

# 寻路 — 4 方向 BFS / A*
# tie-break 顺序：北 → 东 → 南 → 西（与 design/ui_decision_rules §1.1 一致）
func find_path(from: Vector2i, to: Vector2i, blocked: Array[Vector2i]) -> Array[Vector2i]
func reachable_cells(from: Vector2i, max_steps: int, blocked: Array[Vector2i]) -> Array[Vector2i]
```

### 3.2 `Unit`（单位）

```gdscript
class_name Unit extends Resource

enum Faction { WARDEN, ENEMY }
enum AttackKind { MELEE_PUSH, RANGED_PULL, RANGED_PUSH, MELEE_BUMP }

@export var id: int                 # 唯一 ID（用于 tie-break、序列化）
@export var def_id: StringName      # 引用 UnitDef
@export var faction: int            # Faction
@export var hp: int
@export var max_hp: int
@export var move: int
@export var attack_kind: int        # AttackKind
@export var attack_range: int       # 1=近战；3=远程3格
@export var attack_damage: int
@export var attack_push: int        # 推/拉格数（负数代表拉？或单独字段，见下）
@export var attack_pull: int        # 拉力格数；与 push 互斥
@export var position: Vector2i

# 运行时（不保存到 def）
var has_acted: bool                 # 本回合是否已行动
var alive: bool = true              # Tend 前可能为 false 但仍占格
var cracked: bool = false           # 切片不用，预留

func clone() -> Unit                # 深拷贝；BattleState.clone 调用
```

> **设计权衡**：用整数枚举而非字符串/类继承。优势：(1) 易序列化 / 比较 (2) 配置驱动 — 通过 `.tres` 文件加敌人，无需新建类。劣势：扩展行为时要写 `match` 分支。切片阶段动词只有 4 种，可控。

### 3.3 `BattleState`（战斗全状态）

```gdscript
class_name BattleState extends RefCounted

var grid: Grid
var units: Array[Unit]              # 所有存活/濒死单位（含 alive=false 但未清算的）
var current_round: int = 1
var max_rounds: int = 5
var phase: int                      # Phase 枚举
var current_actor_faction: int      # 当前是玩家还是敌方回合
var pending_warning: Dictionary     # {unit_id: PlannedAction} 敌人预警动作

enum Phase {
    GARRISON,        # 布防（切片简化为：直接 3 守卫者预放置）
    ENEMY_WARNING,   # 揭晓敌人下回合意图
    PLAYER_ACTION,   # 玩家操作
    ENEMY_EXECUTE,   # 敌人执行
    BUILDING_RESOLVE,# 建筑结算（切片不用）
    RIFT_SPAWN,      # 地裂出怪（切片不用 / 简化）
    BATTLE_END
}

func clone() -> BattleState         # 深拷贝；撤销 + 预演用
func find_unit(uid: int) -> Unit
func get_unit_at(p: Vector2i) -> Unit  # 返回 alive 或 alive=false 但未清算的
func is_warden_turn() -> bool
```

### 3.4 `BattleEvent`（结算事件）

视图层按事件播放动画。事件是**只读快照**，不可变。

```gdscript
class_name BattleEvent extends RefCounted

enum Type {
    UNIT_MOVED,           # 单位走到 to
    UNIT_PUSHED,          # 单位被推到 to（与 MOVED 区分用于动画）
    UNIT_DAMAGED,         # 单位扣 HP
    UNIT_DIED,            # 标记 alive=false（仍占格）
    UNIT_REMOVED,         # 链结束统一清算
    UNIT_FELL,            # 坠渊
    UNIT_CRACKED,         # 预留
    TILE_DAMAGED,         # 石柱/建筑扣 HP（预留）
    TILE_DESTROYED,       # 石柱/建筑被毁（预留）
    BUMP_WALL,            # 撞墙伤
    BUMP_UNIT,            # 接力撞击点
    PHASE_CHANGED,        # 阶段切换
    ROUND_STARTED,
    ROUND_ENDED,
    BATTLE_ENDED
}

var type: int
var unit_id: int = -1
var from_pos: Vector2i = Vector2i.ZERO
var to_pos: Vector2i = Vector2i.ZERO
var amount: int = 0          # 伤害量等
var extra: Dictionary = {}   # 弹性字段
```

### 3.5 `Action`（玩家动作）

```gdscript
class_name Action extends RefCounted

enum Kind { MOVE, ATTACK, END_TURN, SELECT_UNIT, UNDO }

var kind: int
var actor_id: int = -1       # 操作的守卫者
var target_pos: Vector2i = Vector2i.ZERO    # 移动目的 / 攻击目标格
```

---

## 4. 核心模块详细

### 4.1 `BattleEngine`（状态机入口）

**唯一的状态修改入口**。视图层只能通过它改状态。

```gdscript
class_name BattleEngine extends RefCounted

signal events_produced(events: Array)    # 一次 action 产生的事件流
signal state_changed()

var state: BattleState
var _history: Array[BattleState] = []    # 撤销栈

func start_battle(map_def: MapDef, warden_defs: Array[UnitDef]) -> void

# 核心方法：应用玩家/系统动作
# 步骤：
# 1. _history.push(state.clone())
# 2. 验证合法性（return [] 表示非法）
# 3. 修改 state，收集 events
# 4. emit events_produced(events)
# 5. 自动推进阶段（如所有守卫者行动完毕 → ENEMY_EXECUTE）
func apply_action(action: Action) -> Array[BattleEvent]

# 预演：在 state.clone() 上跑同样逻辑，不发信号，仅返回事件
func preview_action(action: Action) -> Array[BattleEvent]

# 撤销到上一个玩家动作前
func undo() -> Array[BattleEvent]

# 合法动作枚举（供 UI 高亮）
func get_legal_moves(unit_id: int) -> Array[Vector2i]
func get_legal_attack_targets(unit_id: int) -> Array[Vector2i]
```

> **预演 = 真实结算**：`preview_action` 内部就是 `var s2 = state.clone(); _apply_on(s2, action); return events`。这保证 UI 预演 100% 等于实际执行。

### 4.2 `PhysicsResolver`（原子结算链）

**这是整个游戏最严苛的模块**。必须严格按真值表 (`docs/design/combat_resolution_truth_table.md`) 实现。

```gdscript
class_name PhysicsResolver extends RefCounted

# 主入口：对目标 unit 施加 N 点推力（拉就是反方向推）
# 修改 state，返回 events
static func resolve_attack(
    state: BattleState,
    attacker: Unit,
    target: Unit,
    direction: Vector2i,    # 北/东/南/西单位向量
    push_force: int,
    damage: int
) -> Array[BattleEvent]

# 关键：按 T0..Tend 时间点结算
# T0  攻击声明
# T1  伤害快照（Cracksbane 检查点；切片不用）
# T2  伤害施加（target.hp -= damage）
# T3  逐格推动开始
# T4..Tn  每格碰撞
#   空格 → 滑入，剩余推力 -1
#   棋盘外缘 → 坠渊（events += UNIT_FELL）
#   建筑/石柱 → 撞墙 1 伤 + 推力作废（切片不用，但预留）
#   其他单位 U → U -1 伤 + 推力传递（剩余 N-1）给 U
# Tend
#   统一清除 alive=false 单位
#   触发 UNIT_REMOVED 事件
```

**关键不变量**：
- `target.alive=false` 后**仍占格**直到 Tend
- 同一链可推动多个单位（接力 A→B→C）
- 推力为 0 即停止推进
- 推动方向永远是 4 方向单位向量

### 4.3 `AIDecider`（敌人 AI）

**完美信息核心**：决策必须 100% 可重复，无随机。

```gdscript
class_name AIDecider extends RefCounted

# 为每个敌人决定下回合行为
# 输出：{unit_id: PlannedAction}
static func plan_enemy_turn(state: BattleState) -> Dictionary

# 单个敌人决策（按 §4.5 三铁律 + tie-break）
# 1. 计算"最近能攻击的建筑"（切片简化：朝最近守卫者，等建筑加入后改）
# 2. 路径上有守卫者挡路（绕路成本 >2）→ 攻击守卫者
# 3. 已在攻击位置 → 攻击（近战/远程/冲撞按 attack_kind）
# 4. tie-break：北→东→南→西
static func plan_unit(state: BattleState, unit: Unit) -> PlannedAction
```

> **切片简化**：当前没有建筑，腐食兽的目标改为"最近的守卫者"。后续加建筑时只改这一处。**架构稳定**。

### 4.4 `BattleScene`（视图根）

```gdscript
class_name BattleScene extends Node2D

@onready var grid_view: GridView = $GridView
@onready var preview: PreviewOverlay = $PreviewOverlay
@onready var input_ctl: InputController = $InputController
@onready var hud: HUD = $HUD

var engine: BattleEngine
var unit_views: Dictionary = {}    # unit_id → UnitView

func _ready():
    engine = BattleEngine.new()
    engine.events_produced.connect(_on_events)
    # 加载地图 + 初始化战斗
    var map_def = preload("res://scripts/data/defs/map_tutorial_01.tres")
    var wardens = [
        preload("res://scripts/data/defs/warden_bountyhunter.tres"),
        preload("res://scripts/data/defs/warden_graverobber.tres"),
        preload("res://scripts/data/defs/warden_mage.tres"),
    ]
    engine.start_battle(map_def, wardens)

func _on_events(events: Array):
    # 按顺序播放（带短暂动画），完成后 UI 解锁
    for e in events:
        await _play_event(e)
```

### 4.5 `PreviewOverlay`（预演 UI）

**预演只显示"最终结果"**（策划案 §11.1 精简原则）。

```gdscript
class_name PreviewOverlay extends Node2D

# 鼠标悬停目标格时调用
func show_action_preview(action: Action) -> void:
    var events = engine.preview_action(action)
    # 解析事件流，高亮：
    # - 所有受影响单位的最终位置（半透虚影）
    # - 所有伤害数字
    # - 坠渊提示（红色 X）
    # - 撞墙位置（暗红格高亮）

func clear() -> void
```

---

## 5. 关键流程图

### 5.1 玩家移动

```
鼠标悬停目标格
  ↓
PreviewOverlay.show_action_preview(MOVE)
  ↓
BattleEngine.preview_action()
  ↓ (内部 state.clone() + 模拟移动)
返回 [UNIT_MOVED 事件]
  ↓
PreviewOverlay 高亮目标格 + 路径
  ↓
玩家点击确认
  ↓
InputController 派发 Action.MOVE
  ↓
BattleEngine.apply_action() 实际修改 state
  ↓
events_produced 信号 → BattleScene 播放动画
```

### 5.2 玩家攻击（核心：接力推动）

例：守卫者 A 用近战推 1 攻击腐食兽 B，B 后面紧贴另一只腐食兽 C，C 后面是空格然后棋盘外。

```
apply_action(ATTACK, actor=A, target=B位置)
  ↓
PhysicsResolver.resolve_attack(B, dir=east, push=1, damage=1)
  ↓ T1: 伤害快照
  ↓ T2: B.hp = 0, alive=false（仍占格）
  ↓ T3: B 朝东推 1
  ↓ T4: 东边一格 = C → 触发接力
  ↓     C.hp -= 1, push_force=0 传给 C（已用完 1 点）
  ↓     B 停在 C 原位置 (但 B 已 alive=false)
  ↓ Tend: 清算 B → UNIT_REMOVED
  ↓
events = [UNIT_DAMAGED(B,1), UNIT_DIED(B), UNIT_PUSHED(B,east), 
          BUMP_UNIT(B→C), UNIT_DAMAGED(C,1), UNIT_REMOVED(B)]
```

### 5.3 撤销

```
玩家点撤销按钮
  ↓
InputController.action_undo()
  ↓
BattleEngine.undo()
  ↓ state = _history.pop()
  ↓
emit state_changed()
  ↓
BattleScene 整体重建视图（不播动画，瞬间恢复）
```

**重要**：撤销范围 = "上一个玩家 Action 之前"。敌人执行阶段不能撤销中途。

---

## 6. 切片实现 Roadmap（细化）

按这个顺序串起来，每一步可单独验证。

### 阶段 0：基础设施（半天）
1. 删除 `Main.tscn` 引用的失效脚本，新建 `scripts/core/game_manager.gd`
2. 创建空目录结构
3. 写一个最小 `BattleScene.tscn` 显示 8×8 网格

**验证**：跑起来能看到棋盘格子。

### 阶段 1：纯逻辑层（1-2 天）
4. 实现 `Grid`（含 BFS + tie-break）
5. 实现 `Unit` + `UnitDef`
6. 实现 `BattleState` + `clone()`
7. 写 `tests/test_grid_pathfinding.gd` 验证 tie-break

**验证**：测试通过，方向优先级 N→E→S→W 正确。

### 阶段 2：物理引擎（核心，1-2 天）
8. 实现 `PhysicsResolver.resolve_attack`
9. 写测试：
   - `test_physics_push`：推 1 到空格
   - `test_physics_push_wall`：推到外缘 → 坠渊
   - `test_physics_relay`：推 1 撞另一只敌人 → 接力
   - `test_physics_chain_kill`：3 只腐食兽一线，推 1 链杀末尾
   - `test_physics_pull`：拉 1
   - `test_physics_dead_unit_occupies`：0 HP 单位 Tend 前仍占格

**验证**：所有测试用例与真值表 §1-3 一致。

### 阶段 3：玩家操作 + 视图（2-3 天）
10. `BattleEngine.apply_action(MOVE)` + 视图层动画
11. `BattleEngine.apply_action(ATTACK)` + 事件播放
12. `PreviewOverlay`：悬停高亮 + 预演最终位置
13. 撤销系统：`_history` 栈 + 重建视图
14. HUD：当前轮次、撤销按钮、结束回合按钮

**验证**：玩家可移动 3 守卫者 + 看到攻击预演 + 撤销可工作。

### 阶段 4：敌人 AI（1-2 天）
15. `AIDecider.plan_enemy_turn` — 朝最近守卫者移动 + 相邻则攻击
16. `ENEMY_WARNING` 阶段：所有敌人显示意图（移动落点 + 攻击格）
17. `ENEMY_EXECUTE`：按预警执行（被推走 = 落空）
18. 写测试：`test_ai_carrion_picks_nearest`

**验证**：1 守卫者 vs 3 腐食兽，敌人朝守卫者推进，玩家能用推/拉/接力反制。

### 阶段 5：完整循环（1 天）
19. 5 轮限制 + 回合切换
20. 战斗结束条件：所有守卫者死亡 / 所有敌人死亡
21. 简单的胜利/失败结算屏

**验证**：能完整跑完一场战斗。

**预计总时长**：1-2 周（独立开发）。

---

## 7. 关键技术决策（待用户确认）

| # | 决策点 | 推荐 | 备选 |
|---|---|---|---|
| 1 | 测试框架 | **GUT (Godot Unit Test)** — 社区标准，CI 友好 | 自写脚本 |
| 2 | 单位数据 | **`.tres` Resource 文件** — 编辑器可视化编辑 | JSON / GDScript 常量 |
| 3 | 棋盘渲染 | **`TileMap` 节点** — Godot 原生，性能好 | 自绘 Polygon2D 网格 |
| 4 | 单位动画 | **Tween 移动 + 占位色块** — 切片无美术资产 | 等待立绘资产 |
| 5 | 撤销粒度 | **每个玩家 Action 一个快照** | 每个事件一个快照（更细，但内存大） |
| 6 | 状态克隆 | **手动写 `clone()` 方法** — 类型安全 | `inst_to_dict` + `dict_to_inst`（慢） |
| 7 | 输入坐标 | **格坐标 `Vector2i`** + 视图层转屏幕 | 纯像素 |

---

## 8. 风险与减缓

| 风险 | 影响 | 减缓 |
|---|---|---|
| 物理结算 bug 难调（接力链复杂） | 整个游戏的核心崩塌 | **严格按 `combat_resolution_truth_table.md` 写单测**，每个边缘情况一个测试 |
| 预演与执行偏差 | 完美信息承诺破灭 | 物理上**让预演调用同一份代码**，根本不存在偏差可能性 |
| 撤销与动画冲突（动画中撤销）| 视觉错乱 | 动画期间禁用所有输入（hud 锁屏） |
| Godot 4.6 API 变动 | 部分代码失效 | 用稳定 API；不依赖实验性功能 |

---

## 9. 后续阶段扩展点（不在切片内，但架构需预留）

为避免后续推倒重来，本次设计预留以下接口：

| 扩展 | 预留接口 |
|---|---|
| 碎裂状态 | `Unit.cracked` 字段已有；`Cracksbane` 在 T1 检查 |
| 建筑 | `Grid.TileType.BUILDING` 已有；`BattleEvent.TILE_DAMAGED` 已有 |
| 弓手射线 | `AttackKind.RANGED_PULL/PUSH` 已支持远程；射线扫描复用相同模块 |
| 铁角兽冲刺 | 单独的 `AttackKind.CHARGE`；复用 `PhysicsResolver` |
| 遗物 | `BattleState` 加 `relics: Array[RelicDef]`；在 T1 钩子 |
| Run 元 | `RunState` 独立于 `BattleState`；战斗结束传值 |

---

## 10. 验收标准（切片完成时）

- [ ] 8×8 棋盘可视，深渊在外缘
- [ ] 3 守卫者初始放置在棋盘边缘 2 格内
- [ ] 3 只腐食兽从指定位置生成
- [ ] 玩家点选守卫者 → 高亮可达格
- [ ] 鼠标悬停目标格 → 显示移动/攻击的最终结果预演
- [ ] 玩家可移动 + 近战推 + 远程推 + 远程拉
- [ ] 接力推动正确：A 撞 B 撞 C 撞外缘 = 多杀
- [ ] 撤销键 Ctrl/Cmd+Z 工作
- [ ] 空格键结束回合
- [ ] 敌人按 N→E→S→W tie-break 移动，行为完全可预演
- [ ] 物理引擎单测全部通过
- [ ] 无 GDScript 报错 / 警告

---

## 附录：与策划案的对应索引

| 策划案章节 | 对应模块 |
|---|---|
| §3.1 完美信息回合制 | `BattleEngine.Phase` 状态机 |
| §3.2 物理规则（推/拉/接力） | `PhysicsResolver` |
| §3.5 原子结算顺序 | `PhysicsResolver` T0..Tend 时间点 |
| §4.5 敌人 AI 三铁律 | `AIDecider` |
| §7 3 守卫者 | `data/defs/warden_*.tres` |
| §8.3 腐食兽 | `data/defs/enemy_carrion_spawn.tres` |
| §11.1 精确预演 UI | `PreviewOverlay` |
| §11.2 移动范围可视化 | `Grid.reachable_cells` + `PreviewOverlay` |
| `combat_resolution_truth_table.md` | `PhysicsResolver` + 测试 |
| `ui_decision_rules.md` §1 tie-break | `Grid.find_path` + `AIDecider` |
