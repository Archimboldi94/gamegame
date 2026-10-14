# 《天平之誓》战斗界面调整

- **地格与点选**：TW/TH/HS 从 128/64/32 调整为 **160/80/40**；单位贴图缩放为 **0.82**，宽约 79px（格宽的 49%）。地形、光标、地格特效、遮挡判断与拾取共用 `IsoView` 尺寸。同格点选仍可切换单位／地面，预测时再次点选目标仍可确认行动。
- **场景风格**：原创程序绘制的苔绿草地、暖灰石板、层叠石壁、橄榄色灌木与青蓝河流；每种地表有四种纹理变体。深水保留暗色水流，浅滩保留踏石。范围线变细、填充减淡；预测中的出手方和目标保持清晰，查看地面时继续淡化遮挡单位。
- **HUD**：底部左右双肖像，显示生命／技力条与数值；中央突出伤害、命中率、预计剩余生命及夹击等说明。顶部为紧凑行动计数与技能标签，底边为八手小人时间轴；右侧攻击／技能／撤销移动／待机按钮高 104px。界面文字使用简体中文，保留原有角色、姓名、剧情与规则。
- **主要文件**：`iso_view.gd`、`tile_node.gd`、`unit_node.gd`、`tile_cursor.gd`、`battle_fx.gd`；`ui_kit.gd`、`battle.gd`、新增 `battle_unit_panel.gd`；新增 `tools/gen_battle_art.py` 和 `assets/battle_portraits/`，更新 `gen_art.py`、`ART_LICENSE.md`、`README.md`。仅重建战斗美术：`python3 tools/gen_art.py --battle-only`。
- **验证**：Godot 4.3 无窗口导入完成；`tests/run_tests.gd` 为 **1950 PASS / 0 FAIL**。新增地面空隙拾取、四向旋转、双肖像预测、治疗上限、自身技能、同格切换、遮挡淡化和失效目标确认检查。`git diff --check` 通过。
- **截图**：[战斗预测](shots/battle_ui.png)、[普通行动](shots/battle_main_ui.png)、[夹击特效](shots/battlefx_ui.png) 为 2400×1080；[雪岭](shots/battle2a_ui.png) 与 [城寨](shots/battle2b_ui.png) 为 1920×1080，已检查排版。

测试和截图退出码均为 0；Godot 退出时仍有 Ogg 音频资源清理提示，未出现 GDScript 解析或运行错误。
