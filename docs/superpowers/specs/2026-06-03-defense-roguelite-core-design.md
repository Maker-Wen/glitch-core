# 防守战术肉鸽核心设计 Spec

> 日期：2026-06-03
> 状态：已批准方向，进入实现计划前的设计基线
> 范围：稳定防守胜利条件、奖励任务、守卫者、敌人、地图、Run、遗物、经济

## 1. 设计结论

《长夜余烬》的玩法方向固定为 **暗黑小队战术肉鸽** ：3 名守卫者在 8x8 小棋盘上保护建筑和关键目标，通过公开意图、推拉位移、撞击、挡线、地裂控制和 Run 构筑撑过战斗。

标准战斗不再使用多种主胜利条件。所有标准战斗统一为：

1. 撑到最大回合结束。
2. 至少 1 名守卫者存活。

保护目标每受 1 点实际伤害都会形成 1 点守护值损失；保护目标全毁会触发本场防线溃败，但不额外追加固定扣减。守护值归 0 才导致 Run 失败。所有守卫者死亡时，队伍覆灭，Run 立即失败。

清空敌人、封印裂隙、全建筑存活、击破 Boss 部件都不触发提前胜利，只作为奖励任务、减压目标或 Boss 压制目标。

## 2. 文档拆分

本 Spec 的可执行设计已拆到以下文档：

| 文档 | 内容 |
|---|---|
| [../../design/defense_roguelite_core_design.md](../../design/defense_roguelite_core_design.md) | 新版主纲、不可违反规则、数值基准、旧方向修正 |
| [../../design/full_system_design_baseline.md](../../design/full_system_design_baseline.md) | 主菜单、Run 开始、路线、奖励、商店、营地、事件、UI 页面和 MVP 边界 |
| [../../design/ui_screen_flow_design.md](../../design/ui_screen_flow_design.md) | 主菜单、Run 准备、路线、节点、战斗、结算、奖励和结局的页面流 |
| [../../design/battle_objectives_and_rewards.md](../../design/battle_objectives_and_rewards.md) | 主胜负规则、保护目标、守护值、奖励任务、HUD 和结算 |
| [../../design/reward_selection_design.md](../../design/reward_selection_design.md) | 战后结算、奖励选择、`pending_reward`、选项权重、重抽和写回 |
| [../../design/warden_roster_and_upgrades.md](../../design/warden_roster_and_upgrades.md) | 守卫者定位、基础技能、候选角色、升级结构、HP、濒死、死亡 |
| [../../design/enemy_map_encounter_design.md](../../design/enemy_map_encounter_design.md) | 敌人职责、地形池、地图题型、出怪预算、硬威胁规则 |
| [../../design/boss_node_design.md](../../design/boss_node_design.md) | Boss 节点、毁灭计数、锚石、心脏钟和 Boss 奖励任务 |
| [../../design/run_structure_design.md](../../design/run_structure_design.md) | Run 长度、章节推进、路线生成、节点预览、存档点和 Demo 固定路线 |
| [../../design/run_relic_economy_design.md](../../design/run_relic_economy_design.md) | Run 节点、资源、经济、遗物池、事件和 Demo 范围 |
| [../../design/relic_pool_design.md](../../design/relic_pool_design.md) | 遗物池、稀有度、获得权重、互斥限制和流派协同 |
| [../../design/run_design_gap_checklist.md](../../design/run_design_gap_checklist.md) | Run 完成度、Demo 开工条件、完整第一版缺口和优先级 |

## 3. 旧文档优先级

以下旧文档已移动到 archive，只保留历史背景。如果与本 Spec 冲突，以本 Spec 和 `docs/design/defense_roguelite_core_design.md` 为准：

- [../../archive/game_design_legacy.md](../../archive/game_design_legacy.md)
- [../../archive/superpowers/specs/2026-06-02-dark-squad-tactical-roguelite-design_legacy.md](../../archive/superpowers/specs/2026-06-02-dark-squad-tactical-roguelite-design_legacy.md)

尤其废弃以下旧方向：

| 旧方向 | 新裁定 |
|---|---|
| 歼灭战清空敌人即胜利 | 改为终局清场奖励任务 |
| 封印战完成封印即胜利 | 改为裂隙压制奖励任务和减压机制 |
| Boss 击杀或部件击破即胜利 | 改为 Boss 压制目标，胜利仍看终局防守 |
| 无建筑战斗作为常规节点 | 降级为教程、事件或特殊挑战 |
| 保护目标全毁直接等于 Run 失败 | 改为防线溃败，只按本场保护目标累计受伤扣守护值后判断 Run 是否继续 |
| 守卫者 0 HP 战后归队 | 改为 1 HP 濒死、0 HP 死亡；全队死亡时 Run 失败 |

## 4. 首轮实现目标

第一轮实现应验证：

1. 战斗不会因为清空敌人提前胜利。
2. 保护目标 HP、全毁溃败、守护值扣减、终局胜利可正常结算。
3. HUD 能同时显示稳定主目标和奖励任务进度。
4. 守卫者 HP、濒死、死亡和队伍覆灭可正常结算。
5. 至少 3 个奖励任务可记录、失败、完成并结算。
6. 至少 4 类敌人和 3 类地图题型能制造不同空间压力。
7. 至少 6-8 个遗物能改变解法，而不是只改数值。

## 5. 实现边界

首轮不要求：

- 完整 3 章 Run。
- 完整商店和营地 UI。
- 大规模守卫者技能树。
- 卡牌系统。
- 随机章节大地图。
- 大量剧情事件文本。

推荐先完成 1 章 6 节点短 Run：普通战、事件、普通战、精英战、营地、Boss。
