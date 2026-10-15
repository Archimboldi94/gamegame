# 武侠战棋 · 交接文档（2026-10-15）

## 先看这些
- 权威设计：`wuxia-tactics/02_当前设计文档/武侠战棋_GDD_v2.0.md`（【已定】必做，【建议】可调）
- 大地图：`wuxia-tactics/02_当前设计文档/武侠战棋_大地图设计_v1.0.md`
- 主线剧情与文案：`wuxia-tactics/02_当前设计文档/武侠战棋_主线剧情与文案_v1.0.md`
- 当前进度与开放问题：`wuxia-tactics/DEV_STATUS.md`
- 迁移计划：`tactics-tri/docs/WUXIA_MIGRATION.md`
- 运行/测试/导出：`tactics-tri/README.md`

## 工程
- 主工程：`tactics-tri/`（Godot 4.6.x）。战斗 HUD 布局以 Claude 版 `f77192b` 为准：顶部时间轴、第N手、右侧菜单、左下地块信息。
- `wuxia-tactics/archive/` 只放旧工程和历史资料，不在里面开发。
- 测试：`godot --headless --path tactics-tri --script res://tests/run_tests.gd`，目前 3721 PASS、0 FAIL。
- 自动试玩胜率：`godot --headless --path tactics-tri -- --sim=wuxia_b1 --seeds=24`（B1 约 62%）。
- 截图：`-- --shot=battle`、`--shot=wuxia_b2` 等。

## 可玩内容
标题 →「江湖·青崖渡」→ 探索室外和客栈 → B1 渡口截箱 → 选立场 → B2 竹林遗匣（可选）→ B3 废祠夺簿（两种立场、首领后取簿、章节结算）。
已有系统：AP/内力/RP、八向格、控制区与反击/借机、六种主动武学和内功/步法、队伍成长、谱库、武学精进、Lv4 专精、存档 v2、能感知控制区的 AI。

## 美术方向（已定）
- 像素画，人物比例参考《侠客风云传》Q版（约 2.5 头身）；探索地图和战斗地图用同一套像素地块。
- 只用免费工具（Pixelorama、LibreSprite、Pillow/numpy、ImageMagick），不用 Aseprite、PixelLab。
- 流程：先用生图做出四向设定稿（正面、斜侧、侧面、背面），再用 `tactics-tri/tools/art_pipeline/build_v4.py` 处理：抠透明、去地面阴影、统一脚底锚点、扩到八方向、生成敌方换色。设定稿在 `tools/art_pipeline/src/`。
- 单位帧 160×200，脚底在 (80,196)，人物约 140px 高，首领约 170px；地块 160×80。
- 素材来源有 AI 生成，上架 Steam 时要在商店页申报。

## 下一步建议
1. 真人试玩 B3 两路，检查陷阱／借机预览与操作节奏；24种子AI抽样护镖83.3%、核验暗记70.8%，不是承诺真人胜率。
2. 八方向行走和攻击动画，并手工重画东北、西北两个朝向。
3. B2 的6轮速通消耗品奖励仍可后置。

B3 可用 `--sim=wuxia_b3 --stance=escort|sect --sim-party=after_b1 --seeds=24` 复现主线最低整备基准；统计 `turns` 是单位行动次数，`rounds` 是战斗轮次。清场后不会再持续守关而不取簿。普通移动、轻功、回锋后撤及击退入陷阱统一结算；危险移动先确认，已触发陷阱灰显。截图见 `/workspace/art-slice/progress/27_b3_escort_balanced.png` … `30_b3_trap_spent.png`。

## 约束
- 不改 storyteller / warchess-pixel / frost。
- 不提交 `builds/` 下的 apk。
- 提交信息用中文，每完成一个可验证单元就测试、提交。
