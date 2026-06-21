# Demo Run 集成验收清单

> 日期：2026-06-15  
> 状态：P0 自动化验收记录中  
> 范围：1 章 6 节点 Demo Run，从主菜单进入新 Run 到 Boss 通关或 Run 失败。  
> 关联管理计划：[demo_run_project_plan.md](demo_run_project_plan.md)

## 1. 验收前置

- [ ] 已阅读 [../AI_README.md](../AI_README.md)，确认当前不可违反设计没有被实现改动破坏。
- [ ] Godot 版本与项目兼容，能以 headless 模式运行测试。
- [ ] 当前工作树中各 worker 的改动来源可区分，验收只记录失败，不回滚非 A8 改动。
- [ ] `docs/demo_features.md` 与本轮真实可跑功能没有明显冲突。

## 2. 入口与新 Run

- [ ] 从主菜单可以点击开始新 Run。
- [ ] 新 Run 使用固定 3 名守卫者：赏金猎人、盗墓人、大魔法师。
- [ ] 初始守护值为 12 / 12。
- [ ] 新 Run 后进入路线或节点预览，而不是直接跳过 Run 外壳进入单场战斗。
- [ ] 放弃、失败或通关后可以回到主菜单或 Run 结果页，状态不会残留到下一次新 Run。

## 3. 固定路线

- [ ] 路线按固定顺序展示 6 个节点：普通战、事件、普通战、精英战、营地、Boss。
- [ ] 当前可用代码若仍是临时战斗路线，应在验收记录中标明与目标路线的差异。
- [ ] 只能进入当前未访问节点，已访问节点不可重复领取奖励或重复触发效果。
- [ ] `mark_current_node_visited` 后路线推进到下一个未访问节点。
- [ ] 最后一个 Boss 节点访问后进入 Demo 通关结算。

## 4. 事件节点

- [ ] 事件节点不进入战斗场景。
- [ ] 事件页展示标题、叙事、选项、收益与代价。
- [ ] 选择后写回 Run 状态，例如守护值、余烬、遗物、守卫者 HP 或腐化。
- [ ] 事件选择确认后节点标记为已访问，回到路线。
- [ ] 事件不可重复选择，也不会生成战斗奖励。

## 5. 营地节点

- [ ] 营地节点不进入战斗场景。
- [ ] 营地至少提供治疗小队和修复防线两个 Demo 选项。
- [ ] 治疗不会超过守卫者 `hp_max`，死亡守卫者不会被营地治疗错误复活。
- [ ] 修复防线不会超过守护值上限。
- [ ] 选择确认后节点标记为已访问，回到路线。

## 6. 战斗节点

- [ ] 普通战、精英战和 Boss 前普通战读取节点自身的地图、敌群、回合数和奖励任务配置。
- [ ] 战斗开始时读取 Run 级守卫者 HP，而不是重置为满血。
- [ ] 敌人全灭不会提前胜利，胜利只在最大回合结束后结算。
- [ ] 保护目标受伤会在战斗结算中生成 `protected_damage_taken`，保护目标全毁会生成 `line_breached` 信息。
- [ ] 战斗结束后按保护目标总受伤点数写回守护值损失，并写回守卫者 HP、奖励任务完成数和节点结算字段。

## 7. 奖励与 `pending_reward`

- [ ] 战斗结算后先生成 `pending_reward`，不直接绕过奖励页写回所有奖励。
- [ ] `pending_reward` 包含 `reward_id`、`source_node_id`、`fixed_rewards`、`choice_groups` 和 `claim_state`。
- [ ] 固定奖励和可选奖励在领取后写回 Run 状态。
- [ ] 领取后 `pending_reward` 清空。
- [ ] 已领取奖励的节点不可通过返回路线重复领奖。
- [ ] 跳过奖励时发放配置的跳过补偿。

## 8. Boss 终局

- [ ] Boss 节点使用 6 回合防守胜利，不以击杀 Boss 或清怪提前胜利。
- [ ] Boss 压力脚本、毁灭计数、锚石或等价占位在节点预览与战斗内表现一致。
- [ ] Boss 战奖励任务在战斗结束时结算。
- [ ] Boss 胜利后领取章节奖励，并进入 Demo 通关结算。
- [ ] Boss 失败时按 Run 失败或可继续规则进入正确页面。

## 9. 失败与通关

- [ ] 防线溃败不额外追加固定守护值损失；只按保护目标累计受伤扣减，若守护值仍大于 0，Run 可继续。
- [ ] 非溃败保护目标损失按受伤点数扣守护值，且单场不封顶。
- [ ] 守护值归 0 时进入 Run 失败。
- [ ] 所有守卫者死亡时进入 Run 失败。
- [ ] Run 失败清空未领取的 `pending_reward`，避免失败后领奖。
- [ ] 完成 Boss 后进入 Demo 通关结果，并保留本 Run 的关键统计。

## 10. 文档同步

- [ ] 如果真实功能状态变化，同步 [../demo_features.md](../demo_features.md)。
- [ ] 如果新增或废弃设计文档，同步 [../design/doc_status_inventory.md](../design/doc_status_inventory.md)。
- [ ] 如果改变 agent 必读入口，同步 [../AI_README.md](../AI_README.md)。
- [ ] 如果工作包状态变化，同步 [demo_run_project_plan.md](demo_run_project_plan.md)。

## 11. 自动化回归

- [x] 运行 Godot 测试：

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s scripts/tests/test_runner.gd
```

- [ ] 如果上方 Godot 路径不可用，运行：

```bash
godot --headless --path . -s scripts/tests/test_runner.gd
```

- [x] 运行 Markdown 校验：

```bash
python3 /Users/happyelements/.config/opencode/skills/markdown/scripts/verify_markdown.py docs/management/demo_run_acceptance_checklist.md docs/management/demo_run_project_plan.md
```

- [ ] 若测试失败，先确认是否由本轮 A8 测试或清单引入；非 A8 范围失败只记录，不修改其他 worker 的实现。

### 11.1 2026-06-15 自动化验收记录

| 项 | 记录 |
|---|---|
| 工作树基线 | 验收前工作树已有大量未提交改动，本轮只记录结果，不回滚非收尾改动 |
| Godot 测试命令 | `/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s scripts/tests/test_runner.gd` |
| Godot 测试结果 | PASS，`Passes: 859   Failures: 0` |
| Godot 观察项 | 退出时出现 CanvasItem RID、ObjectDB 和 resource still in use 泄漏警告；本次归类为非阻断观察项，后续如做发布包需单独排查 |
| Markdown 全量命令 | `python3 /Users/happyelements/.config/opencode/skills/markdown/scripts/verify_markdown.py docs/management/demo_run_closeout_plan.md docs/management/demo_run_acceptance_checklist.md docs/management/demo_run_project_plan.md` |
| Markdown 全量结果 | FAIL，`docs/management/demo_run_project_plan.md` 第 205 行 Mermaid verification timed out |
| Markdown 收尾子集命令 | `python3 /Users/happyelements/.config/opencode/skills/markdown/scripts/verify_markdown.py docs/management/demo_run_closeout_plan.md docs/management/demo_run_acceptance_checklist.md` |
| Markdown 收尾子集结果 | PASS，2 个文件 CJK emphasis issues 0、Mermaid errors 0 |
| 范围分类 | Godot 回归通过；Markdown 全量失败来自既有项目计划 Mermaid 校验超时，不阻断本收尾记录，但需要后续单独处理或在发布前复验 |
