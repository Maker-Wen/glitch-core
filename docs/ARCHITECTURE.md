# 故障核心 (Glitch Core) — 架构说明

## 技术栈

- Godot 4.6 + GDScript
- 目标平台：WebGL/HTML5

## 目录结构

```
scripts/
├── core/               # 核心系统
│   ├── enums.gd        # 全局枚举与工具函数 (Enums)
│   ├── board.gd        # 棋盘网格 (Board)
│   ├── displacement.gd # 位移解算器 (Displacement)
│   └── game_manager.gd # 游戏主控 (GameManager)
├── units/              # 玩家单位
│   ├── unit.gd         # 单位基类 (Unit)
│   ├── kinetic_ram.gd  # 动能冲锤
│   ├── magnetic_grapple.gd  # 磁性钩爪
│   └── protocol_jammer.gd  # 协议阻断
├── enemies/            # 敌方单位
│   ├── enemy_unit.gd   # 敌人基类 (EnemyUnit)
│   ├── worm.gd         # 蠕虫
│   ├── trojan.gd       # 木马
│   └── logic_bomb.gd   # 逻辑炸弹
├── input/
│   └── input_controller.gd  # 输入控制器
└── ui/
    ├── hud.gd          # 顶栏/底栏/横幅 HUD
    ├── intent_display.gd    # 敌方攻击预警线绘制
    └── unit_tooltip.gd      # 悬浮信息面板

Assets/Sprites/         # AI 生成的 64x64 赛博朋克精灵图 (11 张)
Scenes/Main.tscn        # 主场景入口
```

## 类职责

### 核心层

| 类 | 职责 | 行数 |
|---|---|---|
| `Enums` | 枚举定义 (Cell/Phase/Dir) + 静态工具函数 (dir_vector, manhattan, cell_name) | ~42 |
| `Board` | 8x8 网格数据模型、Sprite2D 渲染、BFS 可达性计算、高亮/hover/debug overlay | ~200 |
| `Displacement` | 推/拉/碰撞位移解算（纯逻辑，不依赖场景树）、爆炸桶连锁、单位查找工具 | ~100 |
| `GameManager` | 回合状态机、关卡初始化、信号连接中枢、玩家输入路由、敌人 AI 执行 | ~300 |

### 单位层

| 类 | 继承 | 特殊 |
|---|---|---|
| `Unit` | Node2D | 基类：HP/移动/网格定位/Sprite2D 渲染 |
| `KineticRam` | Unit | 1伤害 + 推1格 |
| `MagneticGrapple` | Unit | 0伤害 + 拉至面前 |
| `ProtocolJammer` | Unit | 沉默敌人 / 部署屏障 |
| `EnemyUnit` | Unit | 意图系统 (intent_dir/damage/range)、沉默状态 |
| `Worm` | EnemyUnit | 近战，攻击正前方 |
| `Trojan` | EnemyUnit | 直线无限射程 |
| `LogicBomb` | EnemyUnit | 3x3 自爆 |

### UI 层

| 类 | 职责 |
|---|---|
| `HUD` | 回合/阶段/能量/模式标签、底部提示、横幅、tooltip 转发 |
| `IntentDisplay` | 绘制敌人攻击预警线（方向线 + 炸弹范围） |
| `UnitTooltip` | 鼠标跟随的单位信息面板 |

## 数据流

```
InputController (信号)
    ↓
GameManager (信号路由)
    ├── Board (网格数据 + 渲染)
    ├── Displacement (纯逻辑计算)
    ├── Unit / EnemyUnit (状态变更)
    ├── IntentDisplay (预警线绘制)
    └── HUD (UI 更新)
```

## 回合流程

```
_next_turn()
    → _enemy_warning()     # 敌人声明攻击意图
        → _set_phase(PLAYER_ACTION)
            → 玩家操作 (点选/移动/攻击)
                → _on_end_turn()
                    → _enemy_execute()     # 敌人移动 + 执行攻击
                        → _cleanup()       # 核心损伤检查
                            → _check_end() # 胜负判定
                                → _next_turn() (循环)
```

## 坐标系

- 网格坐标: `Vector2i(x, y)`，x 右增，y 下增
- 世界坐标: `Board.to_world(grid_pos)` 返回格子中心像素位置
- 鼠标 → 网格: `Board.get_local_mouse_position()` → `Board.to_grid()`
- 格子像素大小: 64px，间隔 2px，步长 66px

## Debug 模式

按 **F3** 切换，每个格子显示坐标和地块类型中文名。
