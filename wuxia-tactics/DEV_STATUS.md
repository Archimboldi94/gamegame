# 开发状态（2026-10-15）

## 基线切换【重要】

- **现行开发基线：`tactics-tri/`**（Claude 等距渲染、战斗 HUD、美术管线）。
- **`01_Godot工程/WuxiaTactics_Core_v2.0/` 降级为规则/数据参考**，不再作为主工程继续堆 UI。
- 权威设计：`02_当前设计文档/武侠战棋_GDD_v2.0.md`（【已定】必做，【建议】可调）。
- 迁移计划：`tactics-tri/docs/WUXIA_MIGRATION.md`。

## Phase A（本轮）结论

1. 已在 `tactics-tri` 落地八向格、AP/内力/RP、控制区与反击/借机（`use_gdd_rules` 路径），并接入 B1《青崖渡·渡口截箱》JSON。
2. Godot 4.6.3 headless 测试：`godot --headless --path tactics-tri --script res://tests/run_tests.gd` → **2282 PASS, 0 FAIL**。
3. 图形截图：`/workspace/tactics-tri-wuxia-shots/`（标题 + 武侠 B1 开局）；仓库内 `tactics-tri/shots/wuxia/`。
4. 标题「渡口截箱」直接进入 `wuxia_b1`。

## 未完成

- 完整 AP 情境 HUD（大量菜单仍写「技力」）。
- 武学细节（燕行步路径、回锋安全后撤、枪距等）与 ZoC 感知 AI。
- 客栈探索闭环、谱库、成长。
- 正式武侠像素替换占位。

## 下一阶段建议

1. 把 `battle.gd` 主菜单/预览全面改为 AP·内力·借机风险展示（对照 `03_美术与HUD规范`）。
2. 补强 B1 招式与自动试玩胜负统计。
3. 再开客栈最小循环。
