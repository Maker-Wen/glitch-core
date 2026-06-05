# Demo 事件池设计

> 日期：2026-06-04  
> 状态：Demo 可用内容池  
> 依赖：[run_structure_design.md](run_structure_design.md)、[reward_selection_design.md](reward_selection_design.md)、[run_relic_economy_design.md](run_relic_economy_design.md)、[relic_pool_design.md](relic_pool_design.md)

## 1. 目的

本文档补齐 Demo Run 的事件节点内容池，作为事件配置、事件 UI 和 Run 状态写回的交接依据。

事件节点的职责是制造公开的资源交换，而不是隐藏随机惩罚。第一轮 Demo 固定路线只使用 1 个事件节点，但内容池需要提供 4-6 个可替换事件，便于实现 agent 做事件抽取、调试和后续路线扩展。

## 2. 核心裁定

- 事件选项必须在确认前公开收益、代价和影响范围。
- 事件不能在下一场战斗开始后才揭示负面效果。
- 固定收益事件可以直接写回 Run 状态。
- 遗物、升级和混合选择奖励必须生成 `pending_reward`，再进入奖励选择页领取。
- 事件代价可以是余烬、守护值、守卫者 HP、腐化或下一战公开修正。
- 死亡守卫者不能成为治疗、受伤、升级或 HP 代价目标。
- 如果事件选项因为资源不足或目标不存在而不可执行，UI 必须显示禁用原因。

## 3. Demo 使用规则

第一轮 Demo 固定路线的事件节点为：

```text
普通战：断墙前哨
  -> 事件：熄灭的灯塔
  -> 普通战：裂缝庭院
```

默认使用事件：

| 路线节点 | event_id | 标题 | 目的 |
|---|---|---|---|
| 熄灭的灯塔 | `event_extinguished_beacon_01` | 熄灭的灯塔 | 在第 1 场普通战后提供守护值修复、余烬收益和下一战防守修正的取舍 |

Demo 事件池可以替换该事件，但不建议在第 1 章早期使用“守卫者 HP 代价 + 高腐化 + 下一战加压”的复合高风险选项。

## 4. 事件池总览

| event_id | 标题 | 适用章节 / 节点 | 核心取舍 | 是否可能生成 `pending_reward` |
|---|---|---|---|---|
| `event_extinguished_beacon_01` | 熄灭的灯塔 | 第 1 章；Demo 事件节点；普通战后 | 守护值修复、余烬、下一战建筑保护 | 否 |
| `event_cracked_armory_01` | 破损军械库 | 第 1 章；普通战后或精英战前 | 守卫者 HP / 余烬换升级或路障 | 是 |
| `event_refugee_caravan_01` | 难民车队 | 第 1-2 章；普通战后 | 余烬支出换建筑耐久或守护值 | 否 |
| `event_bell_nightmare_01` | 钟声梦魇 | 第 1 章后半；精英战前 | 守护值或腐化换奖励选项 / 稀有奖励 | 是 |
| `event_rift_surveyor_01` | 裂隙测绘者 | 第 1-2 章；裂隙压力路线 | 余烬或腐化换下一战裂隙修正 | 否 |
| `event_buried_oath_01` | 埋葬的誓词 | 第 1-2 章；营地前或精英后 | 守护值、余烬或无代价小收益换遗物 / 治疗 | 是 |

## 5. 事件详表

### 5.1 熄灭的灯塔

| 项 | 内容 |
|---|---|
| event_id | `event_extinguished_beacon_01` |
| 标题 | 熄灭的灯塔 |
| 适用章节 / 节点 | 第 1 章；Demo 固定事件节点；普通战后、裂隙庭院前 |
| 事件主题 | 废灯塔还能照亮裂缝庭院，但燃料和铜镜只能保留其一 |
| 推荐权重 | Demo 固定；第 1 章事件池权重 30 |

| 选项 ID | 选项 | 收益 | 代价 | pending_reward | 限制 |
|---|---|---|---|---|---|
| `beacon_rekindle` | 重燃灯塔 | 守护值 +1；下一战节点预览增加 `beacon_lit` 标记 | 余烬 -5 | 否 | 守护值已满时仍可选择，但 UI 必须提示只获得下一战标记 |
| `beacon_take_mirror` | 拆下铜镜 | 余烬 +9 | 腐化 +1 | 否 | 无 |
| `beacon_keep_ember` | 保留火种 | 下一战 1 个普通建筑开局获得 1 层屏障 | 无立即资源收益 | 否 | 如果下一战没有普通建筑则禁用 |

UI 必显信息：

- 当前守护值、余烬和腐化。
- `重燃灯塔` 的守护值变化，包含上限提示。
- `拆下铜镜` 后腐化变化和是否跨过 3 / 5 / 7 阈值。
- `保留火种` 作用到下一战，且不是立即恢复。
- 下一战为 `裂缝庭院` 时，预览中显示“灯塔修正：建筑屏障”或“灯塔熄灭：无修正”。

配置建议：

```text
event_id: "event_extinguished_beacon_01"
event_type: "resource_trade"
chapter_filter: [1]
node_filter: ["event_demo_beacon"]
preview_tags: ["embers", "sanctuary_integrity", "corruption", "next_battle_modifier"]
options: ["beacon_rekindle", "beacon_take_mirror", "beacon_keep_ember"]
```

### 5.2 破损军械库

| 项 | 内容 |
|---|---|
| event_id | `event_cracked_armory_01` |
| 标题 | 破损军械库 |
| 适用章节 / 节点 | 第 1 章；普通战后、精英战前 |
| 事件主题 | 旧军械还能修出一件装备，但需要有人冒险清理倒塌铁架 |
| 推荐权重 | 第 1 章事件池权重 18；守卫者全员 2 HP 以上时权重 +8 |

| 选项 ID | 选项 | 收益 | 代价 | pending_reward | 限制 |
|---|---|---|---|---|---|
| `armory_take_upgrade` | 清理军械 | 生成守卫者升级 2 选 1 | 选择 1 名存活且 HP >1 的守卫者 HP -1 | 是 | 没有 HP >1 的存活守卫者时禁用 |
| `armory_sell_scrap` | 出售废铁 | 余烬 +6 | 无 | 否 | 无 |
| `armory_build_barricade` | 拼装路障 | 下一场战斗开局可放置 1 个 HP=1 临时路障 | 余烬 -4 | 否 | 余烬不足时禁用 |

`armory_take_upgrade` 生成的 `pending_reward`：

```text
source_type: event
reward_phase: choice
fixed_rewards:
  - reward_type: warden_hp
    amount: -1
    target_rule: selected_alive_warden_hp_above_1
choice_groups:
  - group_type: upgrade
    choose_count: 1
    display_count: 2
    pool_id: "pool_event_chapter1_common_upgrade"
```

UI 必显信息：

- 可承受 HP 代价的守卫者列表和选择后 HP。
- HP 代价不会杀死守卫者；若会降到 0，则该目标不可选。
- 升级奖励需要进入奖励选择页确认，不能直接写回。
- 临时路障只影响下一场战斗，战后不保留。

### 5.3 难民车队

| 项 | 内容 |
|---|---|
| event_id | `event_refugee_caravan_01` |
| 标题 | 难民车队 |
| 适用章节 / 节点 | 第 1-2 章；普通战后、营地前 |
| 事件主题 | 车队愿意帮忙加固防线，但需要余烬补给 |
| 推荐权重 | 第 1 章事件池权重 16；守护值 4 以下时权重 +8 |

| 选项 ID | 选项 | 收益 | 代价 | pending_reward | 限制 |
|---|---|---|---|---|---|
| `caravan_repair_line` | 补给车队 | 守护值 +1 | 余烬 -5 | 否 | 守护值已满或余烬不足时禁用 |
| `caravan_reinforce_building` | 借用木梁 | 下一战 2 个普通建筑最大 HP +1 | 余烬 -3 | 否 | 下一战普通建筑少于 2 个时只作用合法数量 |
| `caravan_turn_away` | 拒绝停留 | 余烬 +2 | 腐化 +1 | 否 | 无 |

UI 必显信息：

- 当前守护值是否已满。
- `借用木梁` 的目标数量和下一战名称。
- `拒绝停留` 的腐化阈值变化。
- 所有选项都是立即确定效果，不进入奖励页。

### 5.4 钟声梦魇

| 项 | 内容 |
|---|---|
| event_id | `event_bell_nightmare_01` |
| 标题 | 钟声梦魇 |
| 适用章节 / 节点 | 第 1 章后半；精英战前；第 2 章裂隙路线 |
| 事件主题 | 守卫者梦见钟声中的未来，可以提前换取奖励或避开压力 |
| 推荐权重 | 第 1 章事件池权重 12；腐化 4 以上时权重 -6 |

| 选项 ID | 选项 | 收益 | 代价 | pending_reward | 限制 |
|---|---|---|---|---|---|
| `nightmare_accept_echo` | 接受回声 | 生成普通 / 稀有遗物 2 选 1 | 腐化 +1 | 是 | 腐化 7 以上时禁用 Demo 池 |
| `nightmare_mute_bell` | 熄灭钟声 | 下一场战斗第 1 个硬威胁降级为软威胁 | 守护值 -1 | 否 | 守护值 1 时禁用 |
| `nightmare_pay_embers` | 用余烬压住梦魇 | 腐化 -1，最低到 0 | 余烬 -6 | 否 | 腐化为 0 或余烬不足时禁用 |

`nightmare_accept_echo` 生成的 `pending_reward`：

```text
source_type: event
reward_phase: choice
fixed_rewards:
  - reward_type: corruption
    amount: 1
choice_groups:
  - group_type: relic
    choose_count: 1
    display_count: 2
    pool_id: "pool_event_echo_relic_chapter1"
```

UI 必显信息：

- 腐化变化和阈值说明。
- 守护值 -1 是否会导致 Run 失败；会失败时禁用。
- 遗物选择是奖励页领取，不在事件页直接获得。
- 下一场硬威胁降级必须显示作用范围：只影响下一场第 1 个硬威胁。

### 5.5 裂隙测绘者

| 项 | 内容 |
|---|---|
| event_id | `event_rift_surveyor_01` |
| 标题 | 裂隙测绘者 |
| 适用章节 / 节点 | 第 1-2 章；裂隙压力路线；普通战或精英战前 |
| 事件主题 | 测绘者能标出裂隙脉动，但可靠情报需要花费余烬 |
| 推荐权重 | 下一战 `rift_strength` 大于 0 时权重 22，否则不出现 |

| 选项 ID | 选项 | 收益 | 代价 | pending_reward | 限制 |
|---|---|---|---|---|---|
| `surveyor_buy_map` | 购买裂隙图 | 下一战第 1 次地裂出怪延迟 1 回合 | 余烬 -4 | 否 | 下一战无地裂时禁用 |
| `surveyor_sell_note` | 出售旧笔记 | 余烬 +5 | 下一战 `rift_warning_quality` 降为低，只显示回合不显示敌种 | 否 | Demo 默认不推荐使用 |
| `surveyor_overcharge` | 过载探针 | 下一战奖励任务完成数结算时额外 +1 余烬 | 腐化 +1；下一战裂隙强度 +1，但不超过 2 | 否 | 第 1 章 Boss 前禁用 |

UI 必显信息：

- 下一战裂隙强度和被修正后的裂隙强度。
- `出售旧笔记` 会降低预告质量，必须在事件页和节点预览中标红。
- `过载探针` 的奖励只是额外余烬，不增加任务完成数量。
- 所有下一战修正都写入 `next_node_modifiers`，完成下一战后清除。

### 5.6 埋葬的誓词

| 项 | 内容 |
|---|---|
| event_id | `event_buried_oath_01` |
| 标题 | 埋葬的誓词 |
| 适用章节 / 节点 | 第 1-2 章；营地前、精英战后 |
| 事件主题 | 旧防线的誓词还在地下发光，可以换来遗物或恢复 |
| 推荐权重 | 精英战后权重 16；守护值 3 以下时权重 -6 |

| 选项 ID | 选项 | 收益 | 代价 | pending_reward | 限制 |
|---|---|---|---|---|---|
| `oath_take_relic` | 取出誓物 | 生成普通遗物 2 选 1 | 守护值 -1 | 是 | 守护值 1 时禁用 |
| `oath_tend_wounds` | 按誓词整队 | 所有存活且未满 HP 的守卫者 +1 HP | 余烬 -6 | 否 | 无受伤守卫者或余烬不足时禁用 |
| `oath_leave_marker` | 留下标记 | 余烬 +3 | 无 | 否 | 无 |

`oath_take_relic` 生成的 `pending_reward`：

```text
source_type: event
reward_phase: choice
fixed_rewards:
  - reward_type: sanctuary_integrity
    amount: -1
choice_groups:
  - group_type: relic
    choose_count: 1
    display_count: 2
    pool_id: "pool_event_oath_common_relic"
```

UI 必显信息：

- 守护值 -1 的战前 / 战后对比。
- `取出誓物` 不允许把守护值扣到 0。
- 治疗只作用于存活守卫者，死亡守卫者不显示为目标。
- 遗物池使用 Demo 遗物池，禁用诅咒遗物。

## 6. 事件生成和过滤

Demo 固定路线可以直接指定 `event_extinguished_beacon_01`。完整第一版使用事件池时，按以下规则过滤：

| 条件 | 规则 |
|---|---|
| 章节过滤 | 第 1 章不出现神龛式诅咒事件 |
| 节点位置 | Boss 前 1 层不出现会提高 Boss 压力的事件 |
| 资源不足 | 资源不足的选项可以灰态，但事件不能只剩 1 个不可选选项 |
| 残编状态 | 存活守卫者少于 3 时，HP 代价事件权重 -10 |
| 低守护值 | 守护值 2 以下时，守护值代价选项默认禁用 |
| 高腐化 | 腐化 7 以上时，腐化代价事件权重 -15 |

## 7. `pending_reward` 规则

事件只有在产生选择型奖励时生成 `pending_reward`。

| 奖励类型 | 是否生成 `pending_reward` | 示例 |
|---|---|---|
| 固定余烬 | 否 | `beacon_take_mirror` |
| 固定守护值变化 | 否 | `caravan_repair_line` |
| 下一战修正 | 否 | `surveyor_buy_map` |
| 遗物 2 选 1 | 是 | `oath_take_relic` |
| 升级 2 选 1 | 是 | `armory_take_upgrade` |
| 混合奖励选择 | 是 | 后续神龛或章节事件 |

生成 `pending_reward` 的事件写回顺序：

1. 事件页确认选项。
2. 生成 `pending_reward`，包含固定代价和选择组。
3. 保存 `phase = reward`。
4. 进入奖励选择页。
5. 玩家确认奖励后一次性写回固定代价和选择奖励。
6. 清空 `pending_reward`，标记事件节点完成。

这样可以避免玩家在事件页付出代价后崩溃，再重进时重复获得遗物或升级。

## 8. UI 必显信息

事件页必须固定显示：

| 区域 | 内容 |
|---|---|
| 顶部 | 事件标题、事件类型标签、当前章节节点 |
| 当前资源 | 守护值、余烬、腐化、守卫者 HP |
| 选项卡 | 选项标题、收益、代价、是否影响下一战、是否进入奖励页 |
| 变化预览 | 选择后资源变化，例如 `守护值 4 -> 5` |
| 风险提示 | 腐化跨阈值、守护值接近 0、守卫者濒死 |
| 按钮 | 确认、返回路线图；固定 Demo 可以不允许离开事件 |

事件文案不能把关键规则藏在长段剧情里。剧情句可以有，但收益和代价必须用稳定图标和数字显示。

## 9. 配置字段建议

### 9.1 `event_config`

| 字段 | 说明 |
|---|---|
| `event_id` | 事件唯一 ID |
| `display_title` | 事件标题 |
| `event_type` | `resource_trade`、`risk_reward`、`next_battle_modifier`、`choice_reward` |
| `chapter_filter` | 可出现章节 |
| `node_filter` | 可出现节点或固定节点 ID |
| `weight` | 基础权重 |
| `preview_tags` | 路线预览显示资源类型 |
| `options` | 事件选项 ID 列表 |
| `disable_rules` | 事件整体不可出现规则 |
| `ui_flags` | 高风险、腐化、HP 代价、奖励页等标记 |

### 9.2 `event_option_config`

| 字段 | 说明 |
|---|---|
| `option_id` | 选项唯一 ID |
| `event_id` | 所属事件 |
| `display_title` | 选项标题 |
| `benefit_ops` | 收益写回操作 |
| `cost_ops` | 代价写回操作 |
| `next_node_modifiers` | 下一战公开修正 |
| `creates_pending_reward` | 是否生成 `pending_reward` |
| `reward_table_id` | 生成奖励时使用的奖励表 |
| `target_rule` | 选择守卫者、建筑或下一战对象的规则 |
| `disable_rule` | 选项禁用条件 |
| `preview_text` | UI 短说明 |

### 9.3 `next_node_modifier`

| 字段 | 说明 |
|---|---|
| `modifier_id` | 修正 ID |
| `source_event_id` | 来源事件 |
| `target_node_id` | 作用节点，Demo 通常是下一节点 |
| `duration` | `next_node_only` 或章节持续 |
| `effect_ops` | 进入战斗前应用的配置修正 |
| `preview_text` | 节点预览必须显示的文案 |
| `expires_on` | 完成节点、放弃节点或 Run 结束时清除 |

## 10. Demo 验收口径

| 场景 | 预期 |
|---|---|
| 进入熄灭的灯塔 | 显示 3 个选项和当前资源 |
| 选择重燃灯塔 | 扣 5 余烬，守护值 +1，不超过上限 |
| 选择拆下铜镜 | 增加 9 余烬，腐化 +1，显示阈值变化 |
| 选择保留火种 | 下一场普通战 1 个建筑获得屏障，并在节点预览显示 |
| 选择会生成遗物的事件 | 保存 `pending_reward`，进入奖励页，领取后清空 |
| 资源不足 | 对应选项灰态，不允许确认 |
| 事件页崩溃重进 | 读取保存状态，不重复执行选项 |
