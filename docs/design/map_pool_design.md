# Demo 地图池设计

> 日期：2026-06-04  
> 状态：Demo 可用内容池  
> 依赖：[enemy_map_encounter_design.md](enemy_map_encounter_design.md)、[run_structure_design.md](run_structure_design.md)、[battle_objectives_and_rewards.md](battle_objectives_and_rewards.md)、[boss_node_design.md](boss_node_design.md)

## 1. 目的

本文档补齐 Demo Run 战斗节点的地图池，提供可直接转成配置的 8x8 坐标、保护目标、地形、敌群、裂隙出怪和奖励任务建议。

第一轮 Demo 固定路线需要 4 场战斗：

```text
断墙前哨 -> 裂缝庭院 -> 铁角闸门 -> 钟楼外环
```

本文档提供 6 张地图，其中前 4 张对应固定路线，后 2 张作为 Demo 调试和后续路线候补。

## 2. 坐标和对象约定

棋盘为 8x8，坐标使用 `(x,y)`：

- `x = 0` 为左侧，`x = 7` 为右侧。
- `y = 0` 为上侧，`y = 7` 为下侧。
- 玩家守卫者默认从下半区进入。
- 深渊边缘用 `abyss_edges` 表示“从该格向指定方向出界会坠落”。
- 地裂出怪坐标本身可通行；守卫者占住地裂时按地裂规则延迟出怪。

对象 ID 建议：

| 前缀 | 含义 |
|---|---|
| `b_` | 普通建筑，默认 HP 2 |
| `k_` | 关键建筑，默认 HP 3 |
| `s_` | 石柱 |
| `r_` | 地裂 |
| `a_` | Boss 锚石 |
| `h_` | Boss 心脏钟 |
| `e_` | 敌人初始或脚本出生点 |

敌人 ID 建议：

| enemy_id | 敌人 |
|---|---|
| `rot_beast` | 腐食兽 |
| `plague_archer` | 瘟疫弓手 |
| `ironhorn` | 铁角兽 |
| `rift_priest` | 裂隙司祭 |
| `blast_sac` | 腐爆囊 |
| `shell_beetle` | 护壳虫 |
| `bone_grub` | 蚀骨蛆群 |
| `bell_thrall` | 钟奴 |

## 3. 地图总览

| map_id | 显示名 | 适用节点 | 回合 | 裂隙强度 | 压力标签 | 用途 |
|---|---|---|---:|---:|---|---|
| `map_demo_broken_wall_outpost` | 断墙前哨 | 第 1 节点普通战 | 5 | 0 | 基础防守、远程线压 | Demo 首战 |
| `map_demo_rift_courtyard` | 裂缝庭院 | 第 2 层普通战 | 5 | 1 | 基础防守、裂隙压力、远程线压 | Demo 分支普通战 |
| `map_demo_pillar_graveyard` | 石柱墓园 | 第 3 层普通战 | 5 | 1 | 堵路拥挤、裂隙压力、推撞连锁 | Demo 高收益普通战 |
| `map_demo_ironhorn_gate` | 铁角闸门 | 第 4 层精英战 | 5 | 1 | 精英冲撞、堵路拥挤、裂隙压力 | Demo 精英战 |
| `map_demo_outer_bell_ring` | 钟楼外环 | 第 6 层 Boss | 6 | 2 | Boss 脚本、裂隙压力 | Demo Boss |
| `map_demo_broken_bridge_edge` | 断桥边缘 | 候补普通 / 精英战 | 5 | 1 | 深渊边缘、精英冲撞 | 调试坠渊和边缘推位 |

## 4. 固定路线地图

### 4.1 断墙前哨

| 项 | 配置 |
|---|---|
| map_id | `map_demo_broken_wall_outpost` |
| 适用节点 | `node_demo_01_broken_wall_outpost`；普通战：断墙前哨 |
| max_rounds | 5 |
| rift_strength | 0 |
| 保护目标 | 3 个普通建筑 |
| 地图题型 | 中央村落 + 远程线压 |

8x8 坐标配置：

| 对象 | 坐标 |
|---|---|
| 守卫者出生 | `(2,5)`、`(3,5)`、`(4,5)` |
| 普通建筑 | `b_well (3,3) HP 2`、`b_store (4,3) HP 2`、`b_shrine (3,4) HP 2` |
| 关键建筑 | 无 |
| 石柱 | `s_nw (2,2)`、`s_ne (5,2)`、`s_sw (2,6)`、`s_se (5,6)` |
| 地裂 | 无 |
| 深渊边缘 | 无 |

推荐敌群：

| 来源 | 回合 | 敌人和坐标 |
|---|---:|---|
| 初始 | 1 | `rot_beast (1,1)`、`rot_beast (6,1)`、`rot_beast (1,6)`、`plague_archer (4,0)` |
| 脚本出怪 | 2 | `rot_beast (7,3)` |
| 脚本出怪 | 3 | `plague_archer (0,4)` |
| 脚本出怪 | 4 | `rot_beast (6,6)` |

`rift_schedule`：

| 回合 | 配置 |
|---:|---|
| 1-5 | 无地裂出怪 |

奖励任务建议：

1. 完美防守。
2. 推离威胁。
3. 守卫者全员存活。

实现备注：

- 首战不放地裂，让玩家先读建筑 HP、弓手直线和保护目标。
- 第 3 回合弓手从左侧出现，给玩家一次明确挡线题。
- 总敌人 7 个，符合普通战预算。

### 4.2 裂缝庭院

| 项 | 配置 |
|---|---|
| map_id | `map_demo_rift_courtyard` |
| 适用节点 | `node_demo_03_rift_courtyard`；普通战：裂缝庭院 |
| max_rounds | 5 |
| rift_strength | 1 |
| 保护目标 | 4 个普通建筑 |
| 地图题型 | 裂隙庭院 + 远程线压 |

8x8 坐标配置：

| 对象 | 坐标 |
|---|---|
| 守卫者出生 | `(2,6)`、`(3,6)`、`(4,6)` |
| 普通建筑 | `b_nw (3,3) HP 2`、`b_ne (4,3) HP 2`、`b_sw (3,4) HP 2`、`b_se (4,4) HP 2` |
| 关键建筑 | 无 |
| 石柱 | `s_left (1,3)`、`s_right (6,4)` |
| 地裂 | `r_nw (2,2)`、`r_se (5,5)` |
| 深渊边缘 | 无 |

推荐敌群：

| 来源 | 回合 | 敌人和坐标 |
|---|---:|---|
| 初始 | 1 | `rot_beast (1,1)`、`plague_archer (6,1)`、`bone_grub (6,6)` |
| 脚本出怪 | 3 | `plague_archer (7,2)` |
| 脚本出怪 | 4 | `rot_beast (0,5)` |

`rift_schedule`：

| 回合 | 地裂 | 敌人 |
|---:|---|---|
| 2 | `r_nw (2,2)` | `rot_beast` |
| 3 | `r_se (5,5)` | `bone_grub` |
| 4 | `r_nw (2,2)` | `rot_beast`，若地裂被占住则延迟到回合 5 |

奖励任务建议：

1. 裂隙压制。
2. 低损防线。
3. 终局清场。

实现备注：

- 如果事件 `beacon_keep_ember` 生效，推荐给 `b_ne (4,3)` 添加 1 层屏障。
- 如果事件 `surveyor_buy_map` 生效，优先延迟第 2 回合 `r_nw` 出怪。
- 总敌人 8 个，裂隙出怪 3 个，符合普通战裂隙强度 1。

### 4.3 铁角闸门

| 项 | 配置 |
|---|---|
| map_id | `map_demo_ironhorn_gate` |
| 适用节点 | `node_demo_04_ironhorn_gate`；精英战：铁角闸门 |
| max_rounds | 5 |
| rift_strength | 1 |
| 保护目标 | 2 个普通建筑，1 个关键建筑 |
| 地图题型 | 石柱闸门 + 精英冲撞 + 堵路拥挤 |

8x8 坐标配置：

| 对象 | 坐标 |
|---|---|
| 守卫者出生 | `(2,6)`、`(3,6)`、`(4,6)` |
| 普通建筑 | `b_left (3,3) HP 2`、`b_right (4,3) HP 2` |
| 关键建筑 | `k_gate (3,4) HP 3` |
| 石柱 | `s_top_l (3,1)`、`s_top_r (4,1)`、`s_mid_l (2,2)`、`s_mid_r (5,2)`、`s_gate_l (2,4)`、`s_gate_r (5,4)` |
| 地裂 | `r_left (1,5)`、`r_right (6,5)` |
| 深渊边缘 | 无 |

推荐敌群：

| 来源 | 回合 | 敌人和坐标 |
|---|---:|---|
| 初始 | 1 | `ironhorn (3,0)`、`rot_beast (1,1)`、`rot_beast (6,1)`、`plague_archer (6,3)` |
| 脚本出怪 | 2 | `plague_archer (0,2)` |
| 脚本出怪 | 3 | `shell_beetle (7,4)` |
| 脚本出怪 | 4 | `ironhorn (4,0)` |
| 脚本出怪 | 5 | `rot_beast (0,6)` |

`rift_schedule`：

| 回合 | 地裂 | 敌人 |
|---:|---|---|
| 2 | `r_left (1,5)` | `rot_beast` |
| 3 | `r_right (6,5)` | `rot_beast` |
| 4 | `r_left (1,5)` | `bone_grub` |

奖励任务建议：

1. 精英猎杀：第 5 回合结束前击杀 1 只 `ironhorn`。
2. 指定目标无伤：`k_gate` 不受伤。
3. 守卫者全员存活。

实现备注：

- `ironhorn (3,0)` 面向中线，首轮应给玩家读到冲撞车道。
- `shell_beetle` 只做堵路，不应在同回合和 2 个铁角兽共同形成 3 个以上硬威胁。
- 总敌人 12 个，符合精英战预算。

### 4.4 钟楼外环

| 项 | 配置 |
|---|---|
| map_id | `map_demo_outer_bell_ring` |
| 适用节点 | `node_demo_06_outer_bell_ring`；Boss：钟楼外环 |
| boss_config_id | `knell_lord_demo_01` |
| max_rounds | 6 |
| rift_strength | 2 |
| 保护目标 | 3 个普通建筑，1 个关键建筑 |
| 地图题型 | Boss 锚石 + 裂隙压力 |

8x8 坐标配置：

| 对象 | 坐标 |
|---|---|
| 守卫者出生 | `(2,6)`、`(3,6)`、`(4,6)` |
| 普通建筑 | `b_left (2,3) HP 2`、`b_right (5,3) HP 2`、`b_back (3,5) HP 2` |
| 关键建筑 | `k_bell_gate (4,4) HP 3` |
| Boss 锚石 | `a_left (1,2) HP 2`、`a_right (6,2) HP 2` |
| 心脏钟 | `h_heart_bell (4,2)`，默认封闭，不阻挡移动；暴露后可被攻击 |
| 石柱 | `s_lantern_l (2,1)`、`s_lantern_r (5,1)`、`s_back_l (1,5)`、`s_back_r (6,5)` |
| 地裂 | `r_left (0,3)`、`r_right (7,3)`、`r_top (3,0)` |
| 深渊边缘 | 无 |

推荐敌群：

| 来源 | 回合 | 敌人和坐标 |
|---|---:|---|
| 初始 | 1 | `rot_beast (2,0)`、`rot_beast (5,0)`、`plague_archer (7,5)`、`rot_beast (0,5)` |
| Boss 召唤 | 3 | `rot_beast (3,1)`、`rot_beast (4,1)` |
| Boss 召唤 | 5 | `bell_thrall (0,4)`、`bell_thrall (7,4)` |
| Boss 召唤 | 6 | `rot_beast (3,0)` |

`rift_schedule`：

| 回合 | 地裂 | 敌人 |
|---:|---|---|
| 2 | `r_left (0,3)` | `bone_grub` |
| 3 | `r_top (3,0)` | `rot_beast` |
| 4 | `r_right (7,3)` | `plague_archer` |
| 5 | `r_left (0,3)` | `rot_beast`，如果 Boss 第 3 回合召唤潮未反制，可提前到回合 4 |

奖励任务建议：

1. 锚石破坏：第 5 回合结束前摧毁全部锚石。
2. 完美守夜：没有保护目标被毁。
3. 全员存活：3 名守卫者都存活。

实现备注：

- Boss 脚本以 [boss_node_design.md](boss_node_design.md) 为准，本表只给盘内对象和敌群。
- Boss 召唤杂兵不提供击杀余烬。
- 如果心脏钟暴露，`h_heart_bell` 可被合法攻击或被推撞命中，但不能触发提前胜利。
- 总敌人 13 个，符合 Boss 战预算。

## 5. 扩展地图

### 5.1 石柱墓园

| 项 | 配置 |
|---|---|
| map_id | `map_demo_pillar_graveyard` |
| 适用节点 | `pillar_graveyard_03`；第 1 章第 3 层普通战 |
| max_rounds | 5 |
| rift_strength | 1 |
| 保护目标 | 3 个普通建筑 |
| 地图题型 | 石柱墓园 + 推撞连锁 |

8x8 坐标配置：

| 对象 | 坐标 |
|---|---|
| 守卫者出生 | `(1,6)`、`(3,6)`、`(5,6)` |
| 普通建筑 | `b_center_l (3,3) HP 2`、`b_center_r (4,3) HP 2`、`b_lower (2,4) HP 2` |
| 关键建筑 | 无 |
| 石柱 | `s_nw (1,2)`、`s_n (2,2)`、`s_ne (5,2)`、`s_e (6,2)`、`s_sw (1,5)`、`s_se (6,5)`、`s_lower (4,5)` |
| 地裂 | `r_left (0,4)`、`r_right (7,4)` |
| 深渊边缘 | 无 |

推荐敌群：

| 来源 | 回合 | 敌人和坐标 |
|---|---:|---|
| 初始 | 1 | `rot_beast (2,0)`、`rot_beast (5,0)`、`plague_archer (7,2)` |
| 脚本出怪 | 2 | `blast_sac (0,2)` |
| 脚本出怪 | 3 | 普通战用 `rot_beast (6,6)`；精英战改为 `ironhorn (4,0)` |
| 脚本出怪 | 4 | `shell_beetle (1,4)` |

`rift_schedule`：

| 回合 | 地裂 | 敌人 |
|---:|---|---|
| 2 | `r_left (0,4)` | `rot_beast` |
| 3 | `r_right (7,4)` | `bone_grub` |
| 4 | 精英战追加 `r_left (0,4)` | `rot_beast` |

奖励任务建议：

1. 连锁大师。
2. 物理处决。
3. 低损防线。

实现备注：

- 石柱多，适合验证撞击、碎裂和连锁预演。
- 腐爆囊必须显示死亡爆裂范围，不与低 HP 建筑贴脸出生。

### 5.2 断桥边缘

| 项 | 配置 |
|---|---|
| map_id | `map_demo_broken_bridge_edge` |
| 适用节点 | 候补普通战、候补精英战 |
| max_rounds | 5 |
| rift_strength | 1 |
| 保护目标 | 3 个普通建筑 |
| 地图题型 | 断桥边缘 + 坠渊解法 |

8x8 坐标配置：

| 对象 | 坐标 |
|---|---|
| 守卫者出生 | `(2,6)`、`(3,6)`、`(4,6)` |
| 普通建筑 | `b_left (2,3) HP 2`、`b_right (5,3) HP 2`、`b_lower (2,4) HP 2` |
| 关键建筑 | 无 |
| 石柱 | `s_nw (1,2)`、`s_ne (6,2)`、`s_sw (1,5)`、`s_se (6,5)` |
| 地裂 | `r_top_l (3,1)`、`r_bottom_r (4,6)` |
| 深渊空洞 | `void_1 (3,3)`、`void_2 (4,3)`、`void_3 (3,4)`、`void_4 (4,4)` |
| 深渊边缘 | `x=0` 全列向 `W` 出界坠落；`x=7` 全列向 `E` 出界坠落；与 `void_*` 相邻格向空洞方向坠落 |

推荐敌群：

| 来源 | 回合 | 敌人和坐标 |
|---|---:|---|
| 初始 | 1 | `rot_beast (1,1)`、`plague_archer (6,1)`、`rot_beast (6,6)` |
| 脚本出怪 | 2 | `ironhorn (3,0)` |
| 脚本出怪 | 4 | `blast_sac (7,5)` |

`rift_schedule`：

| 回合 | 地裂 | 敌人 |
|---:|---|---|
| 2 | `r_top_l (3,1)` | `rot_beast` |
| 3 | `r_bottom_r (4,6)` | `bone_grub` |
| 4 | `r_top_l (3,1)` | `rot_beast` |

奖励任务建议：

1. 物理处决。
2. 无坠落事故。
3. 完美防守。

实现备注：

- 该地图必须在节点预览中显示“深渊边缘”标签。
- 守卫者被推出棋盘或推入 `void_*` 直接死亡，预演必须明确显示。
- 普通战版本建议移除第 2 回合 `ironhorn`，改为 `rot_beast`，避免第一章早期过压。

## 6. 奖励任务映射建议

| map_id | 推荐任务 1 | 推荐任务 2 | 推荐任务 3 | 不推荐任务 |
|---|---|---|---|---|
| `map_demo_broken_wall_outpost` | 完美防守 | 推离威胁 | 守卫者全员存活 | 裂隙压制 |
| `map_demo_rift_courtyard` | 裂隙压制 | 低损防线 | 终局清场 | 无坠落事故 |
| `map_demo_ironhorn_gate` | 精英猎杀 | 指定目标无伤 | 守卫者全员存活 | 节省行动 |
| `map_demo_outer_bell_ring` | 锚石破坏 | 完美守夜 | 全员存活 | 物理处决 |
| `map_demo_pillar_graveyard` | 连锁大师 | 物理处决 | 低损防线 | 指定目标无伤 |
| `map_demo_broken_bridge_edge` | 物理处决 | 无坠落事故 | 完美防守 | 裂隙压制 |

## 7. 配置字段建议

### 7.1 `map_config`

| 字段 | 说明 |
|---|---|
| `map_id` | 地图唯一 ID |
| `display_name` | 显示名 |
| `board_size` | 固定 `[8, 8]` |
| `chapter_filter` | 可出现章节 |
| `node_type_filter` | 普通战、精英战、Boss |
| `pressure_tags` | 压力标签 |
| `risk_level` | 节点风险等级建议 |
| `max_rounds` | 推荐回合数 |
| `warden_spawns` | 守卫者出生坐标 |
| `protected_targets` | 建筑和关键建筑数组 |
| `terrain_objects` | 石柱、地裂、深渊、临时路障等 |
| `initial_enemies` | 初始敌人 |
| `script_spawns` | 非地裂脚本出怪 |
| `rift_schedule` | 地裂出怪表 |
| `reward_task_pool` | 推荐奖励任务 |
| `preview_flags` | 节点预览必须显示的地图风险 |

### 7.2 `protected_target_config`

| 字段 | 说明 |
|---|---|
| `target_id` | 建筑 ID |
| `target_type` | `normal_building`、`key_building`、`temporary_target` |
| `coord` | 坐标 |
| `hp` | 初始 HP |
| `sanctuary_loss_per_damage` | 每 1 点实际受伤扣多少守护值，默认 1 |
| `preview_priority` | UI 排序 |

### 7.3 `rift_spawn_config`

| 字段 | 说明 |
|---|---|
| `round` | 预告或出怪回合 |
| `rift_id` | 地裂 ID |
| `enemy_id` | 出怪敌人 |
| `delay_if_occupied` | 被守卫者占住时是否延迟 |
| `fallback_round` | 延迟后的回合 |
| `counts_to_enemy_budget` | 必须为 `true` |
| `preview_quality` | 显示敌种、只显示回合或显示完整意图 |

## 8. Demo 验收口径

| 场景 | 预期 |
|---|---|
| 断墙前哨 | 无地裂，7 个敌人，玩家能读到远程线压 |
| 裂缝庭院 | 2 个地裂，地裂出怪计入总敌人预算 |
| 铁角闸门 | 至少 1 只铁角兽，关键建筑明确显示，硬威胁不超过 3 |
| 钟楼外环 | 2 个锚石、1 个心脏钟、3 个地裂，Boss 脚本不以击杀胜利 |
| 深渊候补图 | 所有坠落方向可预演，奖励任务包含无坠落事故 |
| 节点预览 | 显示地图提示、保护目标数量、裂隙强度、深渊或 Boss 警告 |
