# 武侠战棋迁移计划（tactics-tri → GDD v2.0）

- 日期：2026-10-15
- 基线工程：`tactics-tri`（Claude 等距 UI / 美术管线）
- **HUD 基线：Claude `f77192b`，不是 `d54bd9b` 双头像 HUD。** 顶部回合与时间轴、左侧纵向工具、右侧行动菜单、左下单位/地形信息与右下富文本预测；保留 GDD 的 AP / 内力 / 八向 / ZoC / 反击接线。
- 规则权威：`wuxia-tactics/02_当前设计文档/武侠战棋_GDD_v2.0.md`（【已定】必须实现；【建议】可调）
- 参考实现（仅规则/数据，不整体搬 UI）：`wuxia-tactics/archive/WuxiaTactics_Core_v2.0/`
- 旧 README / 天平之誓剧情：可忽略；投票抉择、多战程故事可后置

## 1. 保留（tactics-tri 优势）

| 模块 | 路径 | 原因 |
|------|------|------|
| 等距渲染 | `scripts/game/iso_view.gd`, `tile_node.gd`, `unit_node.gd` | 斜 45° 观感已达标，GDD 亦要求斜视 |
| 战斗场景编排 | `scripts/game/battle.gd` | HUD、输入、动画编排完整 |
| HUD / UI | `battle.gd`, `ui_kit.gd`, `tile_cursor.gd` | 按 Claude `f77192b` 布局与面板样式维护，不使用双头像 HUD |
| 特效 / 音效 | `battle_fx.gd`, `audio/` | 占位可用，后续换武学特效 |
| 美术管线 | `art/`, `assets/`, 林砚武侠试制 | 精致像素方向一致 |
| 无场景规则层 | `scripts/rules/*` | 已与表现分离，适合改规则而不推倒 UI |
| 自动化测试入口 | `tests/run_tests.gd` | 继续扩展 |

## 2. 必须改（对齐 GDD【已定】）

### 2.1 网格与移动
- **现状**：`BattleMap.DIRS` / `BattleUnit.DIRS` 仅四向；`mov` 点一次移动 + `moved/acted` 开关。
- **目标**：正方形格 + **八向**（含斜向）；普通地形横/竖/斜各 **1AP**；禁止两阻挡构成的封闭墙角斜穿。
- **改动点**：`battle_map.gd`, `battle_unit.gd`, `pathing.gd`, `iso_view` 邻接高亮。

### 2.2 行动资源
- **现状**：CTB/速度条 + 每回合 mov/act；`tp` 技能点。
- **目标**：速度排序队列；每次自身行动 **6AP【建议】** 不结转；**内力** 上限 12、行动开始 +1、调息 3AP/+4；可任意穿插移动与出招。
- **改动点**：`battle_unit.gd`（`ap`, `neili`/`qi`, `rp`）；`battle_state.gd`（扣 AP、行动开始恢复）；`turn_order.gd` 简化为速度队列轮转。

### 2.3 命中 / 伤害
- **现状**：`combat.gd` 有侧背伤害加成与高度修正；面向仅四向。
- **目标**：概率命中【已定】；【建议】`clamp(基础命中+命中-闪避+侧背+地形, 10%, 95%)`；命中后 `max(1, floor((atk+weapon)*倍率 - armor))`，护势 0.75；**初版侧背只改命中、不加伤害倍率**【建议】。高度差可降级为可选/后置（B1 地图平坦）。
- **改动点**：`combat.gd`；八向 `relative_side`。

### 2.4 控制区 / 反击 / 借机【已定机制】
- **现状**：无 ZoC、无 RP、无自动反击。
- **目标**：正侧 5 邻格控制区；每轮 1 RP；离区借机；受击自动反击（非背后）；反应不链锁。
- **改动点**：新建 `scripts/rules/control_zone.gd`；在 `battle_state.move_unit` 逐步结算借机；`use_skill` 后结算反击；UI 预览危险格。

### 2.5 武学槽
- **现状**：职业技能表 `skill_db.gd` / `unit_classes.gd`（天平之誓职业）。
- **目标**：3 主动招式 + 1 内功 + 1 轻功【已定】；B1 先用 Core 的 `b1_combat.json` 技能集（破风剑、回锋剑、燕行步、调息等）作数据源，迁到 `tactics-tri/data/` 或 `scripts/rules/wuxia_*`。
- **改动点**：`skill_db.gd` 扩展字段（ap/qi/shape）；单位创建改武侠原型角色。

### 2.6 关卡 B1《青崖渡·渡口截箱》
- **现状**：`battle_defs.gd` 的 `b1` 是青石渡石桥（10×10 高度图 + 鸦卒）。
- **目标**：接入 `青崖渡_关卡蓝图_v1.3.json` / Core `b1_map.json`（12×12、水域/箱/木箱、markers A/B/D 与 1/2）；胜负：歼灭两名劫客 / 我方关键倒地。
- **改动点**：`battle_defs.gd` 增 `wuxia_b1` 或替换首关；地图加载器读 JSON；标题入口指向新 B1。

## 3. 可后置（本 Phase 不做或仅占位）

- 客栈自由探索、谱库、成长、保存
- 完整剧情 / 投票抉择（保留代码，入口可藏）
- 内功被动细则、全兵器分支平衡
- 精致武学特效与正式像素立绘（占位圆形/剪影可继续）
- Core_v2.0 整套场景脚本（禁止 wholesale 覆盖）

## 4. Phase A 实施顺序（本轮）

1. **文档**：本迁移计划落盘。
2. **规则层最小对齐**  
   - DIRS → 8 向；facing 0..7。  
   - Unit：`ap/max_ap`, `qi/max_qi`, `rp`；行动开始恢复。  
   - Pathing：八向、1AP/格、封闭角禁斜穿；移动逐步扣 AP。  
   - Combat：GDD 命中/伤害建议公式；去掉强制侧背伤害倍率（或开关）。  
   - ControlZone + 借机/反击接入 `BattleState`。  
3. **数据**：复制/引用 B1 map+combat JSON 到 `tactics-tri/data/wuxia/`；`BattleDefs` 增加 `wuxia_b1`。  
4. **表现最小接线**：`battle.gd` 能开 `wuxia_b1`、显示 AP/内力、移动后刷新；不重做 HUD 美观。  
5. **测试**：扩展 `run_tests.gd`（八向、AP、ZoC、反击、B1 可达）；修回归。  
6. **截图**：Godot 启动 B1，截图到 `/workspace/tactics-tri-wuxia-shots/`。  
7. **Git**：中文 commit 推送；更新 `wuxia-tactics/DEV_STATUS.md` 标明基线已切到 tactics-tri。

## 5. 风险与注意事项

- 八向 + AP 穿插会破坏现有「先移动再攻击一次」的 UI 状态机，需在 `battle.gd` 把 `moved/acted` 改为「AP 余额驱动」。
- 等距渲染假设四向邻接时，斜向高亮/路径折线要验证。
- 勿从 Core 复制 `BattleUI.gd` 覆盖现有 HUD。
- 「开始游戏」保留原剧情流程，首战为 `b1` 青石渡石桥；「渡口截箱」单独进入 `wuxia_b1`。截图 `battle/battlemain/battlefx` 对应 `b1`，`wuxia/wuxia_b1` 对应武侠 B1。

## 6. 成功标准（Phase A）

- [x] 文档已提交  
- [x] headless 原有测试 + 新规则测试通过（2282 PASS）  
- [x] 能在 Godot 中打开武侠 B1 并截到等距画面  
- [x] 规则层具备 AP / 八向 / ZoC·反击 的可测实现（即使 AI/招式未全满）  
- [x] DEV_STATUS 写明基线切换  

## 7. 单元 A：B1 武学完整度（2026-10-15）

- 武学与内功参数继续由 `data/wuxia/b1_combat.json` 加载；单位分别保留 `active_skills`（3槽）、`inner`（1槽）、`lightfoot`（1槽），普攻／格挡／调息不占槽。
- 剑客：破风剑／回锋剑／守关式＋归元诀＋燕行步；枪客：穿云枪／挑枪／横江刀＋苍松功＋踏雪步；拳师：震山掌／截脉指／守关式＋归元诀＋踏雪步。原有枪系招式保留，两名劫客各配置主动招式。
- 横江刀按八向环序覆盖连续3邻格；破风剑的预览与执行均受墙和封闭斜角阻挡；震山掌八向击退1格，非法落点无撞墙或坠落追加伤害。
- 截脉指命中后令目标下一次自身行动少2AP，不叠加，受影响行动结束解除；护势单层、一击减伤25%，未触发于自身下次行动开始失效，与格挡相互替换。
- 归元诀在基础恢复外增加1内力；苍松功在结束行动且剩余至少2AP时获得护势，每行动一次。
- 燕行步按最多3步合法路径跨越木箱、矮墙、水域／沟壑，不能穿墙或封闭墙角，落点必须可通行且无人；踏雪步最多2步且不能越障。轻功支付固定成本，每行动一次；燕行步豁免借机，踏雪步逐步判定借机，存活落地后获得护势。
- 提交前统一验证装备、AP、内力、次数及合法目标，失败不改变资源或行动状态；调息每行动一次且不超过上限。回锋剑免费后撤每行动一次，按GDD 2.7正常结算离区借机。
- Claude HUD保留原布局与美术，技能列表显示消耗、不可用项置灰、轻功选合法落点；武侠行动由剩余AP驱动，可移动与出招穿插。敌方AI为出招预留AP并检查内力。
- `tests/run_tests.gd` 新增15组验收测试，覆盖GDD 6.4第2–7、14、21条及配置、八向范围、命中附效、AI与HUD回归。


## 8. 单元 B：成长与谱库／ZoC AI（2026-10-15）

- `PartyState`：独立等级 1–10、EXP 曲线、替补 0.6／追赶 ×1.5、七项训练点、共用谱库、个人学习与 3＋1＋1 装配；章节存档 version 2。
- 固有特质：游锋／守线／通脉接入命中与内力恢复。
- `party_panel.gd`：客栈谱库与 Esc 队伍成长。
- `EnemyAI`：路径借机期望伤害、致死离区回避；调息／护势／燕行步趋近。
- `BattleSim`＋`--sim`：规则层批量胜率。
- 测试约 3435 PASS；截图见 `docs/06_library.png` … `docs/11_ai_support.png`。
