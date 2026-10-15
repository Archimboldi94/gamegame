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

## 目录
- `scripts/rules/` 规则与数据；`scripts/game/` 场景与表现；`scenes/` 场景
- `data/wuxia/` B1 地图与战斗数据；`assets/` 运行时贴图；`audio/`、`fonts/`
- `art/wuxia/` 武侠美术试制（参考稿，不参与导入）；`tools/` 程序美术/音效生成脚本
