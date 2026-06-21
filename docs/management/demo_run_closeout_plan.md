# Demo Run 下周收尾计划

> 日期：2026-06-15  
> 状态：收尾执行清单  
> 范围：1 章 6 节点 Demo Run，从主菜单进入新 Run 到 Boss 通关或 Run 失败  
> 必读入口：[../AI_README.md](../AI_README.md)  
> 关联文档：[demo_run_project_plan.md](demo_run_project_plan.md)、[demo_run_acceptance_checklist.md](demo_run_acceptance_checklist.md)、[../demo_features.md](../demo_features.md)

## 1. 收尾目标

下周目标不是继续扩完整 3 章第一版，而是把当前 Demo Run 收到“可演示、可验收、可交接、可继续迭代”的状态。

收尾完成时应满足：

1. 主菜单到 Demo 通关或 Run 失败的完整路径已实跑验收。
2. 自动化测试和文档校验有明确记录。
3. 当前功能、已知缺口和下一阶段边界在文档中一致。
4. 玩家能理解当前威胁、自己的行动改变了什么、损耗如何带入下一场。
5. 未完成的大系统被明确冻结或进入下一阶段，不在收尾期临时扩范围。

## 2. 当前判断

| 模块 | 当前判断 | 收尾处理 |
|---|---|---|
| Demo Run 主闭环 | 主体已接近完成 | 用验收清单实跑确认，不再仅依赖文档状态 |
| A9 守卫者 3 主动技能系统 | 待开始 | 本周必须做范围裁定：落最小版或冻结到下一阶段 |
| 遗物战斗效果 | 领取和展示已接入，战斗内效果仍为 `data_only` | 明确 Demo 预期；只在时间允许时接 2-3 个高感知效果 |
| 验收清单 | 已有骨架，未记录实测结果 | 转成真实验收记录，失败项必须挂责任人和处理结论 |
| 文档状态 | 部分完成度描述陈旧 | 收尾时同步 `demo_features.md`、项目计划和缺口清单 |
| 体验意识感 | 规则和 UI 基础已具备，但后果表达仍可加强 | 优先补威胁摘要、预演后果、战后带入信息 |

## 3. 优先级轨道

### P0：验收与文档同步

| 项 | 要求 | 完成标准 |
|---|---|---|
| 自动化测试 | 运行 Godot 测试 | 测试通过；若失败，记录失败用例、责任范围和处理结论 |
| 手动验收 | 按 [demo_run_acceptance_checklist.md](demo_run_acceptance_checklist.md) 实跑 | 每个检查项有勾选或失败说明 |
| 文档一致性 | 同步功能清单和任务状态 | 文档不再互相矛盾，不把已完成系统写成缺失 |
| 工作树审查 | 区分本周收尾改动和既有改动 | 不误回滚他人改动，不混入无关重构 |

### P0：A9 范围裁定

收尾开始前先决定 A9 的处理方式，避免最后两天临时扩系统。

| 方案 | 适用条件 | 本周交付 |
|---|---|---|
| A：最小接入 | 仍有 2-3 天完整开发和回归时间 | `AbilityDef` 最小结构、`USE_ABILITY` 行动、每名守卫者 3 个主动技能、技能预演和 UI 栏真实可用 |
| B：冻结到下一阶段 | 只剩验收、修 bug 和文档时间 | 保留当前单基础技能 Demo；文档明确 3 技能是下一阶段，不在本周实现 |

裁定规则：如果 A9 无法在本周内完成“实现 + 测试 + 手动验收 + 文档同步”，选择方案 B。

### P1：遗物预期和战斗效果

遗物收尾不要追求完整池效果。优先保证玩家不会误解“选了但没生效”。

| 方案 | 适用条件 | 本周交付 |
|---|---|---|
| 展示型收口 | 时间不足 | 奖励页和文档说明 Demo 遗物当前用于构筑预览，战斗内 hook 下一阶段接入 |
| 最小效果接入 | A9 未做或已稳定 | 接入 2-3 个高感知遗物，例如链锤推力 +1、首次建筑减伤、守夜誓约守护值恢复 |

禁止在收尾期接入需要大范围重写物理、AI 或 UI 预演一致性的遗物。

### P1：意识感和可读性 polish

本轨道目标是让玩家更清楚地意识到系统在施压，自己的行动在改变局面。

| 场景 | 问题 | 建议处理 |
|---|---|---|
| 玩家回合开始 | 玩家不知道本回合最危险的点 | 增加战术摘要：受击建筑数、被锁定守卫者数、即将出怪数 |
| 悬停 / 预演后 | 玩家不知道行动解决了什么 | 在 HUD 中显示“解除 N 条攻击线 / 仍有 N 个目标会受伤” |
| Boss 回合 | Doom 增长原因不够像公开脚本 | 文案明确“因锚石未毁，下一轮 Doom +1”等条件 |
| 战斗结算 | 玩家只看到胜负，不理解带入 Run 的后果 | 显示守护值变化、守卫者 HP 带入、未领取奖励和下一节点风险 |
| 节点预览 | 玩家不知道为什么选这个节点 | 显示压力标签、预期敌人、奖励倾向和当前队伍风险 |

### P2：下一阶段 backlog

以下内容不应阻塞本周收尾，只登记到下一阶段：

| 内容 | 原因 |
|---|---|
| 完整 3 章路线 | 超出 Demo Run 收尾范围 |
| 完整 30-40 个遗物战斗效果 | 需要系统性 hook、调参和回归 |
| 商店、工坊、神龛完整规则 | 需要 `node_screen_design.md` 细化 |
| 长期 meta、图鉴、永久解锁 | 不影响 Demo 主闭环 |
| 战中卡牌系统 | 属于新动词系统，不能在收尾期临时加入 |

## 4. 一周执行计划

| 时间 | 目标 | 交付物 |
|---|---|---|
| 第 1 天 | 冻结范围和跑第一轮验收 | A9 裁定、首轮 Godot 测试结果、手动验收失败清单 |
| 第 2 天 | 修 P0 阻断问题 | 入口、节点推进、奖励领取、Run 失败 / 通关相关阻断问题关闭 |
| 第 3 天 | 处理 A9 或遗物最小项 | 按裁定完成 A9 最小版，或完成遗物预期 / 最小效果接入 |
| 第 4 天 | 意识感 polish 和二轮验收 | 威胁摘要、预演后果、Boss 脚本原因或战后带入信息中的高优先项落地 |
| 第 5 天 | 文档同步和发布候选 | 功能清单、项目计划、验收清单、缺口清单同步；形成 Demo RC |
| 缓冲 | 只修回归和验收失败 | 不接新系统，只处理 P0 / P1 验收失败 |

如果第 3 天结束时 A9 或遗物效果仍未稳定，应立即降级为文档冻结，不继续扩大改动面。

## 5. 验收门禁

### 5.1 自动化命令

Godot 测试：

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s scripts/tests/test_runner.gd
```

备用命令：

```bash
godot --headless --path . -s scripts/tests/test_runner.gd
```

Markdown 校验：

```bash
python3 /Users/happyelements/.config/opencode/skills/markdown/scripts/verify_markdown.py docs/management/demo_run_closeout_plan.md docs/management/demo_run_acceptance_checklist.md docs/management/demo_run_project_plan.md
```

### 5.2 手动验收

按 [demo_run_acceptance_checklist.md](demo_run_acceptance_checklist.md) 实跑，至少覆盖：

1. 新 Run 入口和状态清空。
2. 固定路线 6 节点推进。
3. 事件和营地不会进入战斗，且选择后写回 Run 状态。
4. 普通战、精英战和 Boss 读取各自配置。
5. 清怪不会提前胜利，最大回合才结算。
6. 保护目标损失、守护值扣减和守卫者 HP 正确带入下一场。
7. `pending_reward` 防重复领取。
8. Boss Doom、锚石、心脏钟和章节奖励链可理解且可结算。
9. Run 失败和 Demo 通关页面正确进入。

### 5.3 文档验收

| 文档 | 收尾要求 |
|---|---|
| [../demo_features.md](../demo_features.md) | 真实功能、已知未实装项和测试数量一致 |
| [demo_run_project_plan.md](demo_run_project_plan.md) | 任务状态反映本周最终裁定 |
| [demo_run_acceptance_checklist.md](demo_run_acceptance_checklist.md) | 不再只是模板，包含实测结论 |
| [../design/run_design_gap_checklist.md](../design/run_design_gap_checklist.md) | Demo 完成度和缺口描述不陈旧 |
| [../design/doc_status_inventory.md](../design/doc_status_inventory.md) | 如新增当前文档或改变阅读路径，需要同步登记 |

## 6. 禁止扩范围

收尾期禁止以下行为，除非主线程重新确认：

1. 把 Demo Run 扩成完整 3 章 Run。
2. 同时接 A9、完整遗物 hook、商店、工坊和神龛。
3. 改变“撑到最大回合才胜利”的核心规则。
4. 把 Boss 做成击杀或清怪提前胜利。
5. 绕过 `pending_reward` 直接发放战斗奖励。
6. 为了通过测试删除或削弱失败测试。
7. 在验收期做无关 UI 重设计或大规模重构。

## 7. 收尾检查清单

### 范围冻结

- [ ] 已决定 A9 本周是最小接入还是冻结。
- [ ] 已决定遗物本周是展示型收口还是最小效果接入。
- [ ] 已列出本周不做的系统，并同步给实现人员。

### 自动化回归

- [x] Godot 测试已运行。
- [x] Godot 测试结果已记录。
- [x] Markdown 校验已运行。
- [x] Markdown 校验结果已记录。

2026-06-15 P0 自动化记录：

| 项 | 结果 |
|---|---|
| Godot 回归 | PASS，`Passes: 859   Failures: 0` |
| Godot 观察项 | 退出时有资源泄漏警告，作为非阻断观察项记录 |
| Markdown 全量校验 | FAIL，`demo_run_project_plan.md` 第 205 行 Mermaid verification timed out |
| Markdown 收尾子集校验 | PASS，`demo_run_closeout_plan.md` 和 `demo_run_acceptance_checklist.md` 均通过 |

### 手动验收

- [ ] 主菜单到新 Run 可进入。
- [ ] 6 节点路线可推进。
- [ ] 事件节点写回 Run 状态。
- [ ] 营地节点写回 Run 状态。
- [ ] 战斗节点读取配置和 Run 级 HP。
- [ ] 战斗结算写回守护值、守卫者 HP 和奖励任务。
- [ ] `pending_reward` 可领取且不能重复领取。
- [ ] Boss 胜负、Doom 和心脏钟奖励链可结算。
- [ ] Run 失败和 Demo 通关页面可达。

### 意识感验收

- [ ] 玩家能在回合开始知道主要威胁。
- [ ] 玩家能在预演后知道行动改变了什么。
- [ ] 玩家能理解 Boss Doom 增减原因。
- [ ] 玩家能在战后看到下一场会继承的损耗和收益。
- [ ] 玩家能在节点预览理解风险和奖励倾向。

### 文档同步

- [ ] `demo_features.md` 已反映最终功能状态。
- [ ] `demo_run_project_plan.md` 已反映最终任务状态。
- [ ] `demo_run_acceptance_checklist.md` 已记录实测结果。
- [ ] `run_design_gap_checklist.md` 已清理陈旧完成度描述。
- [ ] 如需要，`doc_status_inventory.md` 已登记本收尾计划。

## 8. 最终交付口径

收尾完成后，对外只承诺以下内容：

> 当前版本是 1 章 6 节点 Demo Run，用于验证防守型战术肉鸽的主闭环、公开意图、Run 级损耗、奖励选择、事件 / 营地和 Boss 终局。它不是完整 3 章第一版，也不承诺所有遗物、商店、工坊、神龛和长期 meta 已完成。

如果本周选择冻结 A9 或遗物战斗效果，必须在最终说明中明确写出：这是 Demo 范围裁定，不是遗漏。
