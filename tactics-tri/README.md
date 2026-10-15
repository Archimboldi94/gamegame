# 武侠战棋（tactics-tri 基线）

Godot 4.6 等距战棋工程，当前按《武侠战棋 GDD v2.0》开发（AP/内力、八向移动、控制区、反击/借机，B1 青石渡战斗）。

## 文档
- 权威设计：[`../wuxia-tactics/02_当前设计文档/武侠战棋_GDD_v2.0.md`](../wuxia-tactics/02_当前设计文档/武侠战棋_GDD_v2.0.md)
- 美术 / HUD 规范：`../wuxia-tactics/03_美术与HUD规范/`；地图蓝图：`../wuxia-tactics/04_地图蓝图与数据/`
- 迁移计划：[`docs/WUXIA_MIGRATION.md`](docs/WUXIA_MIGRATION.md)；清理记录：[`docs/CLEANUP.md`](docs/CLEANUP.md)
- 开发状态：[`../wuxia-tactics/DEV_STATUS.md`](../wuxia-tactics/DEV_STATUS.md)

## 运行与测试
```bash
cd tactics-tri
godot --headless --path . --import             # 首次导入资源
godot --path .                                 # 运行游戏
godot --headless --path . -s tests/run_tests.gd # 规则测试，输出 PASS/FAIL
godot --headless --path . --export-debug Android build/tactics-tri.apk  # 导出 APK
```

## 队伍成长与谱库

探索中按 Esc 查看个人等级、EXP、七项属性与训练点；客栈 P 打开队伍谱库，按招式／内功／轻功分类，选择角色后可免费学习、装配和卸下。客栈 G 仍提供一次性心得，也可进入成长界面。每项训练最多4点，可免费重置；心得仅保存数量，暂不开放精进。

探索进入 B1 使用个人成长与装配，标题「渡口截箱」保留 JSON 默认配置。探索初始配置留空尚未取得的回锋剑和兵器不兼容槽位；B1 首胜后队伍收录《回锋剑谱》，每名出战成员各得100 EXP，倒地仍结算。旧章节存档会迁移，截图模式不会写入玩家存档。

```bash
godot --path . --resolution 1600x900 -- --shot=library --out=/workspace/art-slice/progress/library.png --frames=40
godot --path . --resolution 1600x900 -- --shot=party --out=/workspace/art-slice/progress/party.png --frames=40
```

## 目录
- `scripts/rules/` 规则与数据；`scripts/game/` 场景与表现；`scenes/` 场景
- `data/wuxia/` B1 地图与战斗数据；`assets/` 运行时贴图；`audio/`、`fonts/`
- `art/wuxia/` 武侠美术试制（参考稿，不参与导入）；`tools/` 程序美术/音效生成脚本
