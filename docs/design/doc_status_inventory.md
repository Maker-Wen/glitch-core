# 文档状态清单

> 日期：2026-06-04  
> 状态：持续维护清单  
> 入口：[../AI_README.md](../AI_README.md)

## 1. 状态定义

| 状态 | 含义 | AI 使用规则 |
|---|---|---|
| 权威 | 当前设计裁定来源 | 可以作为实现和后续设计依据 |
| 执行细则 | 某个系统的落地规格 | 与权威文档冲突时，先按权威文档修正 |
| 实现状态 | 描述当前 Demo 或架构现状 | 只能回答“现在有什么”，不能覆盖设计 |
| 美术规范 | 美术生成、评估和资产使用规则 | 只约束视觉，不改变玩法 |
| 当前 Spec | 已确认方向的规格摘要 | 可用于交接，但细则以 design 文档为准 |
| 未来预留 | 暂不进入 Demo 或第一版 | 默认不实现，除非用户重新确认 |
| 历史归档 | 旧方向、旧审查、旧方案 | 不作为当前规则 |
| 待补 | 已识别但缺文档 | 不要靠旧文档补空白，需要新开文档 |

## 2. 当前活跃文档

| 路径 | 状态 | 范围 | AI 使用说明 |
|---|---|---|---|
| [../AI_README.md](../AI_README.md) | 权威 | AI 阅读入口 | 每个新 agent 先读 |
| [../management/demo_run_project_plan.md](../management/demo_run_project_plan.md) | 执行细则 | Demo Run 任务拆分、里程碑、agent 边界和进度同步 | 项目管理和并行开发时使用 |
| [defense_roguelite_core_design.md](defense_roguelite_core_design.md) | 权威 | 核心定位、胜利条件、旧方向废弃 | 最高玩法裁定 |
| [full_system_design_baseline.md](full_system_design_baseline.md) | 权威 | 主菜单到 Run 结算的全系统边界 | 系统流和页面入口以此为准 |
| [battle_objectives_and_rewards.md](battle_objectives_and_rewards.md) | 权威 | 胜负、守护值、守卫者死亡、奖励任务 | 战斗结算最高裁定 |
| [run_structure_design.md](run_structure_design.md) | 权威 | Run 长度、章节、路线、节点和存档阶段 | Run 结构最高裁定 |
| [ui_screen_flow_design.md](ui_screen_flow_design.md) | 权威 | 主菜单、Run、战斗外页面流 | UI 页面流最高裁定 |
| [reward_selection_design.md](reward_selection_design.md) | 执行细则 | 战后结算、奖励选择、`pending_reward` | 实现奖励流时使用 |
| [save_run_design.md](save_run_design.md) | 执行细则 | 最小 Run 存档、版本、防重复领奖和崩溃恢复 | 实现继续 Run 和奖励持久化时使用 |
| [run_relic_economy_design.md](run_relic_economy_design.md) | 执行细则 | Run 资源、经济、事件和遗物框架 | 经济数值基线 |
| [relic_pool_design.md](relic_pool_design.md) | 执行细则 | 遗物池、权重、互斥、流派 | 配置遗物池时使用 |
| [event_pool_design.md](event_pool_design.md) | 执行细则 | Demo 事件池、事件选项、收益代价和 `pending_reward` 生成 | 配置事件节点和事件 UI 时使用 |
| [warden_roster_and_upgrades.md](warden_roster_and_upgrades.md) | 执行细则 | 守卫者、技能、升级 | 实现角色和升级时使用 |
| [enemy_map_encounter_design.md](enemy_map_encounter_design.md) | 执行细则 | 敌人、地图、出怪预算 | 配置敌群和地图时使用 |
| [map_pool_design.md](map_pool_design.md) | 执行细则 | Demo 战斗地图、8x8 坐标、地形、敌群和裂隙出怪表 | 配置 Demo 战斗节点时使用 |
| [boss_node_design.md](boss_node_design.md) | 执行细则 | Boss 节点、毁灭计数、锚石、奖励任务 | Demo Boss 终局节点依据 |
| [round_flow_and_intent.md](round_flow_and_intent.md) | 执行细则 | 回合顺序、意图锁定、地裂时序 | 实现回合状态机时使用 |
| [combat_resolution_truth_table.md](combat_resolution_truth_table.md) | 执行细则 | 推拉、碰撞、碎裂、边缘情况 | 实现物理结算时使用 |
| [ui_decision_rules.md](ui_decision_rules.md) | 执行细则 | 敌人 AI tie-break、出怪预算 | 实现公开 AI 时使用 |
| [run_design_gap_checklist.md](run_design_gap_checklist.md) | 待补清单 | Run 完成度和文档缺口 | 排期和查缺补漏时使用 |
| [../superpowers/specs/2026-06-03-defense-roguelite-core-design.md](../superpowers/specs/2026-06-03-defense-roguelite-core-design.md) | 当前 Spec | 新主纲交接摘要 | 快速交接用，不替代细则 |
| [../superpowers/specs/2026-06-02-battle-flow-ui-presentation-design.md](../superpowers/specs/2026-06-02-battle-flow-ui-presentation-design.md) | 当前 Spec | 战斗 UI 表现 | 战斗内 UI 实现依据 |
| [../demo_features.md](../demo_features.md) | 实现状态 | 当前战斗切片功能 | 只判断现状，不覆盖新设计 |
| [../architecture/framework_design.md](../architecture/framework_design.md) | 实现状态 | 战斗切片架构 | 修改现有代码前阅读 |
| [../art/ai_prompts.md](../art/ai_prompts.md) | 美术规范 | 美术圣经、AI 提示词模板 | 生成和评估素材时使用 |

## 3. 素材和参考目录

| 路径 | 状态 | AI 使用说明 |
|---|---|---|
| [ui_reference/](ui_reference/) | 美术规范 | 当前 UI 参考图，服务 UI 讨论 |
| [../art/final_selected/](../art/final_selected/) | 美术规范 | 已选素材和提示词资产 |
| [../art/evaluation/](../art/evaluation/) | 美术规范 | 美术评估过程材料，只作参考 |

## 4. 历史归档

| 路径 | 状态 | 归档原因 |
|---|---|---|
| [../archive/game_design_legacy.md](../archive/game_design_legacy.md) | 历史归档 | 旧主策划案体量大，含旧胜利条件和旧 Run 设定 |
| [../archive/superpowers/specs/2026-06-02-dark-squad-tactical-roguelite-design_legacy.md](../archive/superpowers/specs/2026-06-02-dark-squad-tactical-roguelite-design_legacy.md) | 历史归档 | 旧转型 Spec，包含已废弃的歼灭战和封印战胜利类型 |
| [../archive/design/boss_knell_lord_legacy.md](../archive/design/boss_knell_lord_legacy.md) | 历史归档 | 旧 Boss 击杀胜利模型与当前主纲冲突 |
| [../archive/design/oracle_review_legacy.md](../archive/design/oracle_review_legacy.md) | 历史归档 | 旧审查报告，部分问题已被新文档吸收 |
| [../archive/future/cards_1_0_preview.md](../archive/future/cards_1_0_preview.md) | 未来预留 | 卡牌系统不属于 Demo 和当前第一版实现 |

## 5. 已识别待补文档

| 文档 | 状态 | 影响 | 优先级 |
|---|---|---|---:|
| `node_screen_design.md` | 待补 | 商店、营地、工坊、神龛页面缺细则 | P1 |
| `tutorial_design.md` | 待补 | 新玩家首次 Run 引导缺失 | P2 |

## 6. 清理策略

- 活跃目录只保留当前规则和执行细则。
- 历史材料统一放入 [../archive/](../archive/)。
- 未来设想统一放入 [../archive/future/](../archive/future/) 或新建明确标注的未来文档。
- 如果某份历史文档中仍有可用规则，必须抽取到活跃文档，不要让实现 agent 直接读历史文档。
