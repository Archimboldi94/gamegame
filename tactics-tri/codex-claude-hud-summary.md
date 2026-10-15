# Claude 战斗 HUD 恢复说明

已按 `f77192b` 恢复顶部目标、回合文字及其下方时间轴、提示条、左侧四按钮纵列、右侧行动菜单、左下图标/姓名/HP/地形信息及右下富文本预测。移除 `battle.gd` 的双头像依赖；经典关卡显示 TP，武侠关卡显示 AP/内力。恢复蓝色移动范围的显示接线。

保留现有 AP、八向、ZoC、反击和 `wuxia_b1` 数据/规则；`scripts/rules/*` 无改动。保留等距视图、键鼠/触摸、镜头旋转快捷键、光标与音效。「开始游戏」经原剧情进入青石渡石桥，「渡口截箱」仍进入武侠 B1。

改动文件：

- `scripts/game/battle.gd`：恢复 Claude 布局、天空渐变、时间轴、单位/地形信息、技能列表与预测。
- `scripts/game/game.gd`：恢复 Claude 贴图的九宫格边距；`battle/battlemain/battlefx` 截图入口改回 `b1`，保留武侠截图入口。
- `assets/ui/panel.png`、`assets/ui/btn_normal.png`、`assets/ui/btn_hover.png`、`assets/ui/btn_pressed.png`、`assets/ui/btn_disabled.png`：逐字节恢复自 `f77192b`。
- `tests/run_tests.gd`：将原双头像断言更新为 Claude HUD、富文本伤害/治疗预测、地面切换与 AP/内力断言。
- `docs/WUXIA_MIGRATION.md`：明确 HUD 基线为 Claude `f77192b`，不是 `d54bd9b` 双头像。
- `_claude_hud_ref/.gdignore`：避免参考代码中的旧 `UIKit` 被 Godot 注册并遮蔽现用类。
- `codex-claude-hud-summary.md`：本说明。

验证：

- Godot 4.6.3 headless import 完成，退出码 0；编辑器有沙箱 socket/Android 工具目录提示，无脚本编译错误。
- `tests/run_tests.gd`：**2303 PASS，0 FAIL**。使用 `--log-file /tmp/tactics-tri-claude-tests.log`，避免沙箱外默认日志目录不可写。测试退出时仍有 ObjectDB/资源未释放提示，未出现脚本运行错误。
- 2400×1080 实际控件边界检查通过：时间轴在回合文字下、提示条在其下，底部信息与右下预测未越界。记录：`/workspace/tactics-tri-claude-ui-shots/hud-layout-check.json`。
- 标题「开始游戏」→ 原剧情 → `b1` 青石渡石桥，以及「渡口截箱」→ `wuxia_b1` 的运行检查通过。
- `git diff --check` 通过。

**截图已补拍并目视核对（执行器在沙箱外用 xvfb-run）：**
- `/workspace/tactics-tri-claude-ui-shots/qingshidu_main.png` — 主菜单态，时间轴在顶部「第 1 手…」下方，左工具纵列，右「林砚 TP 3/5」菜单，左下单位/地形信息。
- `/workspace/tactics-tri-claude-ui-shots/qingshidu_attack.png` — 斩击预测，右下富文本伤害面板。
- `/workspace/tactics-tri-claude-ui-shots/title.png` — 标题入口。
- 布局边界 JSON：`/workspace/tactics-tri-claude-ui-shots/hud-layout-check.json`（CLAUDE HUD LAYOUT: PASS）。

未执行 git commit/push，未导出 APK，未改动其他工程。
