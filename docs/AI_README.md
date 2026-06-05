# AI 文档入口

> 日期：2026-06-04  
> 状态：AI agent 必读入口  
> 目的：让后续 AI 在最短上下文内读到当前权威设计，避免被旧策划稿误导。

## 1. 读取规则

后续 AI agent 处理本项目时，先读本文，再按任务类型读取对应文档。

优先级规则：

1. 如果文档之间冲突，以 [design/defense_roguelite_core_design.md](design/defense_roguelite_core_design.md) 为最高玩法裁定。
2. 系统流程冲突时，以 [design/full_system_design_baseline.md](design/full_system_design_baseline.md) 和 [design/run_structure_design.md](design/run_structure_design.md) 为准。
3. 战斗胜负、守护值、守卫者死亡、奖励任务冲突时，以 [design/battle_objectives_and_rewards.md](design/battle_objectives_and_rewards.md) 为准。
4. UI 页面流冲突时，以 [design/ui_screen_flow_design.md](design/ui_screen_flow_design.md) 为准；战斗内 HUD 和意图表现再参考 [superpowers/specs/2026-06-02-battle-flow-ui-presentation-design.md](superpowers/specs/2026-06-02-battle-flow-ui-presentation-design.md)。
5. [archive/](archive/) 下的文档只做历史参考。除非用户明确要求追溯旧方案，否则不要把 archive 内容当成当前规则。

## 2. 当前不可违反设计

- 游戏定位是暗黑小队战术肉鸽。
- 战斗是 8x8 小棋盘，3 名守卫者，公开敌人意图。
- 标准战斗胜利只在 `max_rounds` 结束后检查。
- 清空敌人、封印裂隙、击破 Boss 部件都不能提前胜利。
- 保护目标被毁扣 Run 级守护值；守护值归 0 才导致 Run 失败。
- 守卫者 HP 是 Run 级资源；1 HP 是濒死但可行动，0 HP 死亡并从本 Run 移除。
- 所有守卫者死亡时，Run 立即失败。
- 战斗内不做随机命中、随机伤害、隐藏 AI 或实时倒计时。
- 裂隙是常规出怪压力模块，不是特殊关专属。
- 战斗类型不再决定胜利条件；差异来自压力标签、地图、敌群、奖励任务和 Run 构筑。

## 3. 任务型阅读路径

| 任务 | 先读 | 再读 |
|---|---|---|
| 项目管理和任务拆分 | [management/demo_run_project_plan.md](management/demo_run_project_plan.md) | [design/doc_status_inventory.md](design/doc_status_inventory.md)、[design/run_design_gap_checklist.md](design/run_design_gap_checklist.md) |
| 理解当前玩法全貌 | [design/defense_roguelite_core_design.md](design/defense_roguelite_core_design.md) | [design/full_system_design_baseline.md](design/full_system_design_baseline.md) |
| 实现战斗胜负和结算 | [design/battle_objectives_and_rewards.md](design/battle_objectives_and_rewards.md) | [design/round_flow_and_intent.md](design/round_flow_and_intent.md)、[design/combat_resolution_truth_table.md](design/combat_resolution_truth_table.md) |
| 实现敌人 AI 和出怪 | [design/ui_decision_rules.md](design/ui_decision_rules.md) | [design/enemy_map_encounter_design.md](design/enemy_map_encounter_design.md)、[design/map_pool_design.md](design/map_pool_design.md) |
| 实现 Boss 节点 | [design/boss_node_design.md](design/boss_node_design.md) | [design/battle_objectives_and_rewards.md](design/battle_objectives_and_rewards.md)、[design/enemy_map_encounter_design.md](design/enemy_map_encounter_design.md) |
| 实现 Run | [design/run_structure_design.md](design/run_structure_design.md) | [design/run_relic_economy_design.md](design/run_relic_economy_design.md)、[design/reward_selection_design.md](design/reward_selection_design.md)、[design/save_run_design.md](design/save_run_design.md) |
| 实现遗物和奖励 | [design/relic_pool_design.md](design/relic_pool_design.md) | [design/reward_selection_design.md](design/reward_selection_design.md)、[design/warden_roster_and_upgrades.md](design/warden_roster_and_upgrades.md) |
| 实现事件节点 | [design/event_pool_design.md](design/event_pool_design.md) | [design/run_structure_design.md](design/run_structure_design.md)、[design/reward_selection_design.md](design/reward_selection_design.md)、[design/save_run_design.md](design/save_run_design.md) |
| 做 UI 设计或 UI 实现 | [design/ui_screen_flow_design.md](design/ui_screen_flow_design.md) | [superpowers/specs/2026-06-02-battle-flow-ui-presentation-design.md](superpowers/specs/2026-06-02-battle-flow-ui-presentation-design.md) |
| 做内容配置 | [design/run_design_gap_checklist.md](design/run_design_gap_checklist.md) | [design/map_pool_design.md](design/map_pool_design.md)、[design/event_pool_design.md](design/event_pool_design.md)、[design/relic_pool_design.md](design/relic_pool_design.md) |
| 做美术和生成图 | [art/ai_prompts.md](art/ai_prompts.md) | [design/ui_reference/](design/ui_reference/)、[art/final_selected/](art/final_selected/) |
| 查当前切片实现状态 | [demo_features.md](demo_features.md) | [architecture/framework_design.md](architecture/framework_design.md) |

## 4. 文档分层

| 层级 | 用法 | 文档 |
|---|---|---|
| 项目管理 | 任务拆分、里程碑、agent 边界和进度同步 | [management/demo_run_project_plan.md](management/demo_run_project_plan.md) |
| 权威主纲 | 先读，决定方向 | [design/defense_roguelite_core_design.md](design/defense_roguelite_core_design.md) |
| 系统基线 | 串联主菜单、Run、节点、结算和 UI | [design/full_system_design_baseline.md](design/full_system_design_baseline.md) |
| 执行细则 | 实现和配置时查 | [design/](design/) 下的当前设计文档 |
| UI Spec | 战斗内信息表现 | [superpowers/specs/2026-06-02-battle-flow-ui-presentation-design.md](superpowers/specs/2026-06-02-battle-flow-ui-presentation-design.md) |
| 当前 Spec | 新主纲的规格摘要 | [superpowers/specs/2026-06-03-defense-roguelite-core-design.md](superpowers/specs/2026-06-03-defense-roguelite-core-design.md) |
| 实现状态 | 了解当前 demo 已做什么 | [demo_features.md](demo_features.md)、[architecture/framework_design.md](architecture/framework_design.md) |
| 历史归档 | 只追溯旧决策，不作为当前规则 | [archive/](archive/) |

## 5. 仍需补齐的文档

这些是已识别缺口，不代表当前设计冲突：

| 缺口文档 | 用途 | 优先级 |
|---|---|---:|
| `node_screen_design.md` | 营地、商店、工坊、神龛和事件节点页面细则 | P1 |
| `tutorial_design.md` | 首次 Run 教学和规则暴露顺序 | P2 |

已补齐并进入活跃阅读路径的 Demo 内容文档：

| 文档 | 用途 | 状态 |
|---|---|---|
| [design/event_pool_design.md](design/event_pool_design.md) | Demo 事件池、事件选项、代价、奖励和 `pending_reward` 规则 | Demo 可用 |
| [design/map_pool_design.md](design/map_pool_design.md) | Demo 4 场固定路线地图和 2 张候补地图的 8x8 坐标配置 | Demo 可用 |
| [design/save_run_design.md](design/save_run_design.md) | 最小 Run 存档、版本、`pending_reward` 防重复领取和崩溃恢复 | Demo 可用 |

## 6. 维护规则

新增或修改设计文档时，同时更新：

1. 本文的任务型阅读路径。
2. [design/doc_status_inventory.md](design/doc_status_inventory.md) 的状态表。
3. 相关权威文档中的引用。
4. 如果影响 Demo Run 排期或 agent 边界，同步更新 [management/demo_run_project_plan.md](management/demo_run_project_plan.md)。

不要在 archive 文档中继续扩展新设计。需要复用旧内容时，把有效部分抽到新的当前文档里，并明确旧规则已废弃。
