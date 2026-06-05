# Run 设计完成度与缺口清单

> 日期：2026-06-04  
> 状态：持续维护清单  
> 依赖：[defense_roguelite_core_design.md](defense_roguelite_core_design.md)、[run_structure_design.md](run_structure_design.md)、[run_relic_economy_design.md](run_relic_economy_design.md)、[reward_selection_design.md](reward_selection_design.md)、[ui_screen_flow_design.md](ui_screen_flow_design.md)

## 1. 目的

本文档用于持续跟踪 Run 层设计是否足够支撑开发、UI 和内容配置。

它回答：

1. 当前 Run 设计完成到什么程度。
2. Demo 还缺什么才能开工。
3. 完整第一版 Run 还缺哪些系统。
4. 每个缺口应该由哪份文档补齐。
5. 后续查缺补漏时的优先级。

## 2. 状态定义

| 状态 | 含义 |
|---|---|
| 已定稿 | 规则、数值边界、UI 需求和配置口径已经足够进入实现 |
| Demo 可用 | 支撑第一轮固定路线 Demo，但完整第一版还需要扩展 |
| 需补细则 | 有框架和方向，但缺内容池、配置表或页面细节 |
| 缺失 | 只有口头方向或尚未形成文档 |

## 3. 总体完成度

| 范围 | 当前完成度 | 判断 |
|---|---:|---|
| 1 章 6 节点 Demo Run | 88%-92% | 主循环、奖励、遗物、事件池、地图配置和最小存档设计已可开工，仍缺正式 Boss 脚本和地图配置接入 |
| 完整 3 章第一版 Run | 62%-67% | 核心规则已定，Demo 内容池已补齐；完整事件池、地图池、节点系统和存档迁移仍需扩展 |
| 长期可重复游玩肉鸽深度 | 40%-45% | 需要更多遗物、升级、事件、地图、Boss、路线变体和调参数据 |

## 4. 已完成的 Run 基线

| 模块 | 状态 | 文档 | 说明 |
|---|---|---|---|
| 核心定位 | 已定稿 | [defense_roguelite_core_design.md](defense_roguelite_core_design.md) | 暗黑小队战术肉鸽、防守目标、公开意图 |
| 主胜负规则 | 已定稿 | [battle_objectives_and_rewards.md](battle_objectives_and_rewards.md) | 不清怪提前胜利，撑到最大回合 |
| 三层生命资源 | 已定稿 | [battle_objectives_and_rewards.md](battle_objectives_and_rewards.md) | 守护值、保护目标 HP、守卫者 HP |
| 守卫者死亡 | 已定稿 | [warden_roster_and_upgrades.md](warden_roster_and_upgrades.md) | 1 HP 濒死，0 HP 死亡，本 Run 离队 |
| Run 长度 | 已定稿 | [run_structure_design.md](run_structure_design.md) | Demo 1 章 6 节点；完整第一版 3 章 |
| Demo 固定路线 | 已定稿 | [run_structure_design.md](run_structure_design.md) | 普通战、事件、普通战、精英战、营地、Boss |
| 路线生成规则 | Demo 可用 | [run_structure_design.md](run_structure_design.md) | 完整第一版仍需配置表和生成测试 |
| 节点预览 | 已定稿 | [run_structure_design.md](run_structure_design.md) | 压力标签、裂隙强度、敌人提示、奖励 |
| 奖励选择 | 已定稿 | [reward_selection_design.md](reward_selection_design.md) | `pending_reward`、选项 +1、重抽、写回 |
| UI 页面流 | 已定稿 | [ui_screen_flow_design.md](ui_screen_flow_design.md) | 主菜单到结局完整页面链路 |
| 经济基准 | Demo 可用 | [run_relic_economy_design.md](run_relic_economy_design.md) | 余烬收入、价格和恢复边界 |
| Demo 遗物池 | 已定稿 | [relic_pool_design.md](relic_pool_design.md) | 12 个 Demo 遗物、权重和协同 |
| Demo Boss 配置 | 已定稿 | [boss_node_design.md](boss_node_design.md) | 6 回合 Boss、毁灭计数、锚石和奖励任务 |
| 敌人预算 | Demo 可用 | [enemy_map_encounter_design.md](enemy_map_encounter_design.md) | 裂隙强度、总敌人、硬威胁上限 |

## 5. Demo Run 必补项

Demo 目标是跑通 1 章 6 节点，验证路线损耗、奖励任务、遗物和营地取舍。

| 缺口 | 状态 | 影响 | 建议文档 | 优先级 |
|---|---|---|---|---:|
| Demo 遗物池 8-12 个 | 已定稿 | 第一轮构筑差异可配置 | [relic_pool_design.md](relic_pool_design.md) | P0 |
| Demo 事件 4-6 个 | Demo 可用 | Demo 事件池、选项收益代价和 UI 必显信息已补齐 | [event_pool_design.md](event_pool_design.md) | P0 |
| Demo 地图配置 4-6 张 | Demo 可用 | 4 张固定路线地图和 2 张候补地图已补齐，可转配置 | [map_pool_design.md](map_pool_design.md) | P0 |
| Boss 节点具体配置 | 已定稿 | Demo 终局可配置 | [boss_node_design.md](boss_node_design.md) | P0 |
| 营地页面和规则细节 | Demo 可用 | 目前有 2 选 1 规则，缺最终 UI / 配置口径 | `node_screen_design.md` | P1 |
| 固定路线配置表 | Demo 可用 | 当前 `RunState` 已有固定路线；后续应数据化为配置表 | 扩展 [run_structure_design.md](run_structure_design.md) | P1 |
| 奖励任务 Demo 池 | Demo 可用 | 已有任务池，但要标出 Demo 使用哪 8 个 | 扩展 [battle_objectives_and_rewards.md](battle_objectives_and_rewards.md) | P1 |
| 存档最小格式 | Demo 可用 | 最小字段、防重复领奖、入口快照和崩溃恢复已补齐 | [save_run_design.md](save_run_design.md) | P1 |

## 6. 完整第一版 Run 必补项

完整第一版目标是 3 章 Run，有稳定路线差异、长期损耗和多局构筑变化。

| 缺口 | 状态 | 影响 | 建议文档 | 优先级 |
|---|---|---|---|---:|
| 完整遗物池 30-40 个 | 已定稿 | 第一版 40 个遗物池已给出，后续需调参 | [relic_pool_design.md](relic_pool_design.md) | P0 |
| 遗物权重、互斥和协同 | 已定稿 | 可进入实现，后续靠测试调权重 | [relic_pool_design.md](relic_pool_design.md) | P0 |
| 事件池 18-24 个 | 缺失 | 路线风险和资源交换不足 | `event_pool_design.md` | P0 |
| 地图池 13-17 张 | 缺失 | 三章节点无法支撑变化 | `map_pool_design.md` | P0 |
| 商店完整规则 | 需补细则 | 经济消耗少，余烬价值不足 | `node_screen_design.md` | P1 |
| 工坊完整规则 | 需补细则 | 升级定向成长不足 | `node_screen_design.md` | P1 |
| 神龛完整规则 | 需补细则 | 腐化没有足够入口和高风险路线 | `node_screen_design.md` | P1 |
| 守卫者完整升级池 | 需补细则 | 成长深度不足 | 扩展 [warden_roster_and_upgrades.md](warden_roster_and_upgrades.md) | P1 |
| 章节 Boss 设计 3 个 | 需补细则 | 三章缺终局压力 | `boss_chapter_design.md` | P1 |
| 存档版本和迁移 | 缺失 | 后续开发容易破坏存档 | `save_run_design.md` | P1 |
| 教程和首次 Run 引导 | 缺失 | 新玩家理解成本高 | `tutorial_design.md` | P2 |
| 永久解锁和图鉴 | 缺失 | 不影响第一版核心闭环，可后置 | `meta_progression_design.md` | P3 |

## 7. 当前建议顺序

### 7.1 先补内容深度

1. [relic_pool_design.md](relic_pool_design.md)
2. [event_pool_design.md](event_pool_design.md)
3. [map_pool_design.md](map_pool_design.md)

状态：Demo 范围已补齐。下一步是把地图池正式接入战斗配置，并把事件占位替换为事件池配置。

### 7.2 再补节点经济

1. `node_screen_design.md`
2. 扩展 [warden_roster_and_upgrades.md](warden_roster_and_upgrades.md)
3. [save_run_design.md](save_run_design.md)

理由：商店、工坊、营地完整页和存档迁移会影响第一版结构；Demo 已有最小营地和最小存档设计。

### 7.3 最后补引导和长期目标

1. `tutorial_design.md`
2. `meta_progression_design.md`
3. 图鉴和统计页

理由：这些能提升完整产品体验，但不是验证 Run 核心循环的前置条件。

## 8. Demo 可开工条件

以下全部满足后，Demo Run 可以交给实现 agent：

| 条件 | 当前状态 |
|---|---|
| 固定 1 章 6 节点路线 | 已定稿 |
| 守护值和守卫者 HP 规则 | 已定稿 |
| 战斗胜负和结算 | 已定稿 |
| 奖励选择和 `pending_reward` | 已定稿 |
| UI 页面流 | 已定稿 |
| Demo 遗物池 | 已定稿 |
| Demo 事件池 | Demo 可用 |
| Demo 地图配置 | Demo 可用 |
| Demo Boss 配置 | 已定稿 |
| 最小存档格式 | Demo 可用 |

结论：当前可以开始地图配置接入、Boss 终局脚本、战斗 UI 完成度和最小存档实现。完整第一版仍需扩展事件池、地图池、节点页面和存档迁移。
