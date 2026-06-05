# 最小 Run 存档设计

> 日期：2026-06-04  
> 状态：Demo 可用执行规格  
> 依赖：[run_structure_design.md](run_structure_design.md)、[reward_selection_design.md](reward_selection_design.md)、[full_system_design_baseline.md](full_system_design_baseline.md)

## 1. 目的

本文档补齐 Demo Run 的最小存档格式、保存时机、防重复领奖和崩溃恢复策略。

第一轮 Demo 不要求战斗内逐行动继续，但必须满足：

1. 能从主菜单继续未结束 Run。
2. 战斗、事件、奖励页和路线图重进后不重复发奖。
3. 崩溃发生在战斗中时，可以回到进入节点前快照并重新开始同一节点。
4. 存档字段有版本号，后续第一版可以迁移。

## 2. 核心裁定

- Run 存档以 Run 状态为单位，不保存全局图鉴和永久解锁。
- Demo 使用单一未结束 Run 存档槽。
- 存档写入必须按阶段进行，不能只在退出游戏时保存。
- 奖励发放必须经过 `pending_reward`，领取成功后清空。
- `node_entry_snapshot` 是 Demo 崩溃恢复的安全点，不是战斗内撤销功能。
- 战斗中崩溃不保留当前回合行动，MVP 回到进入节点前并重新开始本节点。
- 已完成节点和已领取奖励必须分别记录，避免“节点完成但奖励重复领取”。

## 3. 存档文件和版本

Demo 建议使用一个 JSON 存档文件：

```text
user://saves/current_run.json
```

如当前工程还没有存档目录，首次保存时创建 `user://saves/`。

版本字段：

| 字段 | 类型 | Demo 值 | 说明 |
|---|---|---|---|
| `save_version` | int | 1 | 存档结构版本 |
| `min_supported_version` | int | 1 | 当前版本可读取的最低版本 |
| `game_version` | string | `demo_run_2026_06_04` | 仅用于调试展示 |
| `saved_at_unix` | int | 当前时间戳 | 最近保存时间 |
| `schema_name` | string | `glitch_core_run_save` | 防止误读其他 JSON |

写入策略：

1. 先写临时文件 `current_run.json.tmp`。
2. 写入完成后刷新并关闭文件。
3. 原子替换为 `current_run.json`。
4. 可选保留 `current_run.json.bak`，只用于读档失败回退。

## 4. 顶层存档结构

```text
save:
  save_version: 1
  min_supported_version: 1
  schema_name: "glitch_core_run_save"
  game_version: "demo_run_2026_06_04"
  saved_at_unix: 0
  run:
    run_id: string
    run_seed: int
    difficulty_id: string
    run_status: active | won | failed | abandoned
    phase: prep | route | node_preview | battle | node_resolution | reward | chapter_result | run_result
    chapter_index: int
    chapter_node_index: int
    current_node_id: string
    sanctuary_integrity: int
    sanctuary_integrity_max: int
    embers: int
    corruption: int
    wardens: array
    relics: array
    route_graph: object
    visited_nodes: array
    completed_node_ids: array
    reward_claimed_node_ids: array
    pending_reward: object | null
    node_entry_snapshot: object | null
    chapter_guardian_reward_used: bool
    next_node_modifiers: array
    run_summary: object | null
```

## 5. 必要字段

### 5.1 Run 基础字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `run_id` | string | 新 Run 创建时生成，贯穿本局 |
| `run_seed` | int | 固定路线、奖励和事件使用的随机种子 |
| `difficulty_id` | string | Demo 固定为 `normal` |
| `run_status` | enum | `active`、`won`、`failed`、`abandoned` |
| `phase` | enum | 用于决定继续 Run 回到哪个页面 |
| `chapter_index` | int | Demo 固定为 1 |
| `chapter_node_index` | int | 当前章节已完成节点数 |
| `current_node_id` | string | 当前选中或正在处理的节点 |

### 5.2 资源字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `sanctuary_integrity` | int | 当前守护值 |
| `sanctuary_integrity_max` | int | Demo 默认 7 |
| `embers` | int | 当前余烬 |
| `corruption` | int | 当前腐化 |
| `chapter_guardian_reward_used` | bool | 本章奖励任务修复守护值是否已使用 |
| `next_node_modifiers` | array | 事件或遗物产生的下一战公开修正 |

### 5.3 守卫者字段

```text
warden:
  warden_id: string
  hp: int
  hp_max: int
  alive: bool
  upgrades: array
  death_node_id: string | null
  warden_upgrade_chapter_index: int | null
```

规则：

- `alive = false` 的守卫者不进入后续战斗、治疗和升级目标。
- `hp` 不自动恢复。
- `warden_upgrade_chapter_index` 用于限制每名守卫者每章最多升级 1 次。

### 5.4 路线字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `route_graph` | object | 当前章节路线图，Demo 为固定 6 节点 |
| `visited_nodes` | array | 已进入并完成流程的节点 |
| `completed_node_ids` | array | 已完成节点 ID |
| `reward_claimed_node_ids` | array | 已成功领取奖励的节点 ID |

`visited_nodes` 和 `reward_claimed_node_ids` 不合并。事件可能无奖励，战斗可能已结算但奖励未领取，二者需要分别判断。

## 6. 保存时机

| 时机 | phase | 必须保存内容 | 目的 |
|---|---|---|---|
| 创建新 Run 后 | `route` | 初始资源、固定守卫者、固定路线、种子 | 主菜单能继续 Run |
| 生成或载入章节路线后 | `route` | `route_graph`、当前可达节点 | 路线不重复随机 |
| 确认进入节点前 | `node_preview` 或 `battle` | `node_entry_snapshot`、`current_node_id`、节点配置 ID | 战斗中崩溃可回到安全点 |
| 战斗结束后 | `node_resolution` | 战斗结果、HP、守护值变化、奖励任务结果、`pending_reward` | 结算页重进不重复计算 |
| 事件选项确认后 | `reward` 或 `route` | 事件代价、固定收益、`pending_reward` 或节点完成 | 事件不重复执行 |
| 奖励生成后 | `reward` | 完整 `pending_reward`、奖励种子和候选项 | 奖励页重进不重新抽 |
| 奖励领取成功后 | `route` 或 `chapter_result` | 写回资源、遗物、升级；清空 `pending_reward`；更新领取列表 | 防止重复领奖 |
| 完成节点后 | `route` | `completed_node_ids`、`visited_nodes`、后续可达节点 | 路线推进 |
| Boss 失败可重试 | `node_preview` | 损耗保留，节点不完成，奖励为空 | 回同一 Boss 节点 |
| Run 结束后 | `run_result` | `run_status`、失败 / 通关摘要 | 主菜单展示结果 |

## 7. `pending_reward` 防重复领取

### 7.1 必要字段

```text
pending_reward:
  reward_id: string
  source_node_id: string
  source_type: battle | event | shrine | chapter | start
  reward_phase: fixed | choice | chapter_choice
  generated_seed: int
  fixed_rewards: array
  choice_groups: array
  modifiers: array
  reroll:
    allowed: bool
    cost_embers: int
    used_count: int
    max_count: int
  claim_state:
    generated: bool
    fixed_claimed: bool
    choice_claimed: bool
    selected_option_ids: array
    claimed_at_unix: int | null
```

Demo 可以不做重抽，但仍保留 `reroll` 字段，默认：

```text
reroll:
  allowed: false
  cost_embers: 3
  used_count: 0
  max_count: 0
```

### 7.2 防重复规则

领取奖励时必须按顺序校验：

1. `pending_reward != null`。
2. `pending_reward.source_node_id == current_node_id`。
3. `pending_reward.claim_state.choice_claimed == false`。
4. `current_node_id` 不在 `reward_claimed_node_ids`。
5. 选项 ID 存在于 `pending_reward.choice_groups`。
6. 目标仍合法，例如守卫者存活、守护值未满、余烬足够。

写回成功后一次性执行：

```text
apply fixed_rewards
apply selected options
append current_node_id to reward_claimed_node_ids
append current_node_id to completed_node_ids
clear pending_reward
phase = route or chapter_result or run_result
save
```

如果任一步失败，不能部分写入。实现上应把奖励领取视为一个事务。

### 7.3 奖励重进规则

| 情况 | 处理 |
|---|---|
| 奖励页崩溃，未确认 | 读取同一个 `pending_reward`，选项不重新随机 |
| 固定奖励已生成但未领取 | 固定奖励仍在 `pending_reward.fixed_rewards` 中等待领取 |
| 领取成功后崩溃 | `pending_reward` 已清空，`reward_claimed_node_ids` 已记录，不重复发放 |
| 存档中同时存在 `pending_reward` 和已领取节点 | 以 `reward_claimed_node_ids` 为准，清空异常 `pending_reward` 并记录恢复日志 |

## 8. `node_entry_snapshot`

`node_entry_snapshot` 是进入节点前的最小安全快照。Demo 用它处理战斗中崩溃和 Boss 重试。

### 8.1 必要字段

```text
node_entry_snapshot:
  snapshot_id: string
  source_node_id: string
  node_type: battle | boss | event | camp
  chapter_index: int
  chapter_node_index: int
  phase_before_entry: route | node_preview
  run_seed: int
  node_attempt_index: int
  encounter_config_id: string | null
  map_id: string | null
  event_config_id: string | null
  reward_table_id: string | null
  battle_seed: int | null
  sanctuary_integrity: int
  embers: int
  corruption: int
  wardens: array
  relics: array
  completed_node_ids: array
  reward_claimed_node_ids: array
  next_node_modifiers: array
```

### 8.2 创建时机

玩家在节点预览点击“进入”时创建快照，随后保存。

战斗节点：

```text
phase = battle
current_node_id = selected node
node_entry_snapshot = current run state before battle
save
load battle scene
```

事件和营地节点可以也创建快照，但 Demo 的关键需求是战斗和 Boss。

### 8.3 使用规则

| 恢复原因 | 使用方式 |
|---|---|
| `phase = battle` 读档 | 恢复 `node_entry_snapshot`，回到同一节点预览或直接重新开始战斗 |
| Boss 溃败但守护值大于 0 | 不回滚到快照；保留战斗损耗，回同一 Boss 节点预览，`node_attempt_index +1` |
| 战斗已结束并保存 `node_resolution` | 不使用快照回滚，读取结算结果 |
| 奖励页崩溃 | 不使用快照，读取 `pending_reward` |

快照不是给玩家撤销失败使用的功能。只有崩溃恢复和 MVP 战斗中断使用它。

## 9. 崩溃恢复策略

继续 Run 时按 `phase` 恢复：

| phase | 恢复位置 | 处理 |
|---|---|---|
| `route` | 章节路线图 | 显示当前可达节点 |
| `node_preview` | 章节路线图或节点预览 | 取消未确认选择，允许重新确认 |
| `battle` | 同一节点预览 | 从 `node_entry_snapshot` 恢复，重新开始该节点 |
| `node_resolution` | 战后结算页 | 显示已保存战斗结果，不重新结算 |
| `reward` | 奖励选择页 | 读取同一个 `pending_reward` |
| `chapter_result` | 章节结算页 | Demo Boss 胜利后可直接进入通关结算 |
| `run_result` | Run 失败 / 通关页 | 展示最终摘要 |

异常恢复：

| 异常 | 处理 |
|---|---|
| 存档 JSON 解析失败 | 尝试读取 `.bak`；仍失败则主菜单禁用继续 Run |
| `save_version` 高于当前支持 | 主菜单禁用继续 Run，提示版本不兼容 |
| `pending_reward` 缺少源节点 | 清空 `pending_reward`，回路线图并记录恢复日志 |
| `current_node_id` 已完成但 phase 仍是 `battle` | 以 `completed_node_ids` 为准，回路线图 |
| 全员死亡但 `run_status = active` | 修正为 `failed`，进入失败结算 |
| 守护值小于等于 0 但 `run_status = active` | 修正为 `failed`，进入失败结算 |

## 10. Demo 固定路线存档示例

Demo 新 Run 创建后的关键字段：

```text
run:
  run_id: "run_20260604_001"
  run_seed: 10001
  difficulty_id: "normal"
  run_status: "active"
  phase: "route"
  chapter_index: 1
  chapter_node_index: 0
  current_node_id: ""
  sanctuary_integrity: 7
  sanctuary_integrity_max: 7
  embers: 0
  corruption: 0
  wardens:
    - warden_id: "bounty_hunter"
      hp: 2
      hp_max: 2
      alive: true
      upgrades: []
      death_node_id: null
    - warden_id: "grave_robber"
      hp: 2
      hp_max: 2
      alive: true
      upgrades: []
      death_node_id: null
    - warden_id: "grand_mage"
      hp: 2
      hp_max: 2
      alive: true
      upgrades: []
      death_node_id: null
  relics: []
  completed_node_ids: []
  reward_claimed_node_ids: []
  pending_reward: null
```

Demo 路线节点应保存在 `route_graph.nodes`：

| node_id | node_type | config |
|---|---|---|
| `node_demo_01_broken_wall_outpost` | `battle` | `map_demo_broken_wall_outpost` |
| `node_demo_02_extinguished_beacon` | `event` | `event_extinguished_beacon_01` |
| `node_demo_03_rift_courtyard` | `battle` | `map_demo_rift_courtyard` |
| `node_demo_04_ironhorn_gate` | `elite_battle` | `map_demo_ironhorn_gate` |
| `node_demo_05_cinder_camp` | `camp` | Demo 营地 2 选 1 |
| `node_demo_06_outer_bell_ring` | `boss` | `map_demo_outer_bell_ring`、`knell_lord_demo_01` |

## 11. Demo 与完整第一版差异

| 范围 | Demo | 完整第一版 |
|---|---|---|
| 存档槽 | 1 个当前 Run | 多槽或最近 Run + 历史摘要 |
| 路线 | 固定 1 章 6 节点 | 3 章生成路线 |
| 版本迁移 | 只校验 `save_version = 1` | 提供版本迁移函数 |
| 战斗中继续 | 不保存行动日志，回节点前快照 | 可选保存确定性行动日志 |
| 奖励重抽 | 字段保留，按钮可不做 | 支持重抽次数和消耗 |
| 图鉴 / 永久解锁 | 不保存 | 单独全局存档 |
| Boss 重试 | 保留损耗，回同一 Boss 节点 | 同规则，但支持多章节 Boss |
| 事件池 | 固定或少量事件 | 18-24 个事件和权重过滤 |
| 存档兼容 | 读失败则禁用继续 Run | 尽量迁移旧版本 |

完整第一版新增字段建议：

- `profile_id`：玩家档案。
- `meta_progression`：永久解锁，建议放全局存档，不和 Run 存档混写。
- `rng_cursors`：路线、奖励、事件分别记录随机游标。
- `battle_action_log`：战斗内确定性行动日志。
- `content_seen_ids`：图鉴和新内容提示。
- `save_migration_history`：迁移版本记录。

## 12. 配置和实现交接

### 12.1 `run_save_header`

| 字段 | 说明 |
|---|---|
| `save_version` | 存档结构版本 |
| `min_supported_version` | 当前读取器支持的最低版本 |
| `schema_name` | 固定字符串，用于防误读 |
| `game_version` | 构建或 Demo 标识 |
| `saved_at_unix` | 最近保存时间 |

### 12.2 `run_save_state`

| 字段 | 说明 |
|---|---|
| `run_id` | Run 唯一 ID |
| `run_seed` | Run 随机种子 |
| `run_status` | 当前 Run 状态 |
| `phase` | 当前阶段 |
| `resources` | 守护值、余烬、腐化 |
| `wardens` | 守卫者状态 |
| `relics` | 已获得遗物 |
| `route_graph` | 路线图 |
| `progress_flags` | 节点完成、奖励领取、章节限制 |
| `pending_reward` | 待领奖励 |
| `node_entry_snapshot` | 节点入口快照 |

### 12.3 存档服务接口建议

| 接口 | 说明 |
|---|---|
| `has_active_run()` | 主菜单判断是否显示继续 Run |
| `create_new_run(seed)` | 创建 Demo 固定 Run 并保存 |
| `load_current_run()` | 读取并校验当前 Run |
| `save_run(run_state)` | 原子保存 |
| `save_node_entry_snapshot(run_state, node_config)` | 进入节点前保存快照 |
| `save_pending_reward(run_state, reward)` | 生成奖励后保存 |
| `claim_pending_reward(run_state, selected_options)` | 事务式领取奖励 |
| `mark_node_completed(run_state, node_id)` | 标记节点完成 |
| `finish_run(run_state, result)` | 保存失败或通关摘要 |

## 13. 验收用例

| 用例 | 预期 |
|---|---|
| 新 Run 后退出 | 主菜单显示继续 Run，读档回路线图 |
| 战斗中崩溃 | 读档回同一节点预览或重新开始同一战斗 |
| 战斗结算页崩溃 | 读档回结算页，不重新生成战斗结果 |
| 奖励页崩溃 | 读取同一个 `pending_reward`，奖励选项不变化 |
| 奖励领取后崩溃 | 不重复获得余烬、遗物或升级 |
| 事件生成遗物奖励 | 先保存 `pending_reward`，领取后清空 |
| Boss 溃败但守护值大于 0 | 保留损耗，回同一 Boss 节点，不发奖励 |
| 守护值归 0 | 保存 `run_status = failed`，继续 Run 进入失败结算 |
| 全队死亡 | 保存 `run_status = failed`，死亡列表可展示 |
| 存档版本不兼容 | 禁用继续 Run，不尝试错误读取 |
