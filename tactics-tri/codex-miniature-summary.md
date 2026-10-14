# 《天平之誓》细密画与桌面操作打磨

本轮完成视觉与 PC 操作两条工作。所有修改位于 `/workspace/tactics-tri`；未推送 Git、未导出 APK。战斗规则与剧情台词沿用现有实现。

- **统一视觉**：重写 `tools/gen_art.py`、`tools/gen_battle_art.py`，新增 `tools/miniature.py`。共享青金石蓝、朱砂红、翡翠绿、羊皮纸与金线配色，使用细墨轮廓、矿物色平涂、花卉织纹、手稿式山峦和建筑。全部为确定性 Pillow 绘制，不读取参考截图或第三方美术。
- **战场与人物**：六职业及敌军改为小头、长衣、分离手脚的细密画人物，通过武器、头饰、衣纹与姿态区分；友军青色饰边、敌军朱砂饰边，枪兵另有队色旌旗。地表使用克制的草花、石板嵌饰、曲线水纹、雪地纹样；侧壁有分层石纹与刻饰，柏树以分枝尖叶绘制。旧单位与地块路径也更新为同一风格。
- **肖像与界面**：战斗和对话共用同源半身像，替换纯色对话剪影；修正右侧肖像镜像定位。羊皮纸边、墨蓝面板与金色角饰覆盖双肖像、中央预测、八手时间轴和大按钮，保留上轮布局。`scripts/game/ui_kit.gd`、`game.gd`、`silhouette.gd`、`dialogue.gd`、`unit_node.gd` 为主要接入文件。
- **尺寸与导入**：地格 TW/TH/HS 保持 **160/80/40**，仍与 `IsoView` 一致；人物贴图 96×128、显示缩放 0.82，宽约 79px。全部 **256 个 PNG** 的 `.import` 记录与资源路径已检查。
- **PC 操作**：`scripts/game/battle.gd` 新增独立悬停描边与轻量信息卡，不改动选中格、目标或伤害预测。左键与触屏点击等价；右键轻点 / Esc 取消或撤销，中键 / 右键拖动平移，滚轮缩放。空格 / Enter 待机或确认；A 攻击、S 技能；Z / Backspace 撤销；Q/E 旋转；R 重置；加减缩放；方向键 / WASD 平移。A/S 轻按松开触发行动，按住超过 180 毫秒或参与组合平移时不触发行动。鼠标模拟触摸去重，失焦清除输入状态，原有触屏拖动、双指捏合与安卓返回操作保留。完整中文绑定见 `README.md`。
- **许可**：`ART_LICENSE.md` 已补充细密画视觉来源、原创程序纹样与共享绘制库说明。

验证结果：

1. `python3 tools/gen_art.py` 完整生成；`--battle-only` 局部重建成功，Python 编译检查通过。
2. `/home/box/.local/bin/godot --headless --path . --import`：退出码 0。
3. `/home/box/.local/bin/godot --headless --path . -s tests/run_tests.gd`：**43 组测试，1950 PASS / 0 FAIL**，退出码 0。本轮没有修改规则脚本或向正式测试添加界面断言。
4. 额外交互冒烟检查：**28 PASS / 0 FAIL**，覆盖 A/S 轻按与按住、快速组合平移、旋转、重置、缩放、两种撤销、有效输入步骤、右键拖动不取消、菜单上右键取消、鼠标去重、触屏点击、失焦与悬停隔离。另用 Xvfb + xdotool 实际注入鼠标和键盘，确认单次左键与 A/S/Esc 的真实事件路径；悬停截图已保存。
5. `git diff --check` 通过。日志位于 `shots/miniature-import.log`、`shots/miniature-tests.log`、`shots/desktop_smoke.log` 与各截图同名日志。

2400×1080 截图（通过 xvfb-run 生成并检查）：

- [双肖像与伤害预测](shots/battle_miniature.png)
- [移动范围与四个行动按钮](shots/battle_main_miniature.png)
- [雪岭战场](shots/battle2a_miniature.png)
- [统一后的对话肖像与背景](shots/dialogue_miniature.png)
- [真实鼠标悬停信息](shots/battle_hover_miniature.png)

运行日志仍可出现上轮已有的 Godot 4.3 Ogg 音频退出清理提示（ObjectDB / resources still in use），以及 Xvfb 的 V-Sync 提示；测试和截图退出码均为 0，未出现 GDScript 解析或运行错误。
