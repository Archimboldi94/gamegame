# 开发状态（2026-10-15）

## 基线【重要】

- **现行开发基线：`tactics-tri/`**（Claude 等距 HUD `f77192b` 布局 + GDD v2.0 规则）。
- **`archive/WuxiaTactics_Core_v2.0/` 仅作规则/数据参考**，不继续堆 UI。
- 权威设计：`02_当前设计文档/武侠战棋_GDD_v2.0.md`（【已定】必做）。
- 迁移计划：`tactics-tri/docs/WUXIA_MIGRATION.md`。
- Godot：`~/.local/bin/godot` **4.6.3**。

## 本轮已落地（origin/main）

| 内容 | 说明 |
|------|------|
| **B2《竹林遗匣》** | 12×12 地图／战斗 JSON；取匣+撤离胜负；竹林探索入口；《截脉指》+80EXP |
| **探索等距像素** | 室外／客栈改用战斗 `top_*`／`side_*` 菱形地块（草／泥／石／桥／水／林）；石板路＋渡口货箱＋建筑体块加厚 |
| B3 脚手架 | `b3_map.json`／`b3_combat.json`＋`build_wuxia_b3`；探索入口仍后续开放 |
| 精进 AI | 已精进武学评分 +1.25 |

## 验证

- Headless：`godot --headless --path tactics-tri -s tests/run_tests.gd` → **3513 PASS, 0 FAIL**。
- 截图：
  - 探索前／后：`art-slice/progress/16_explore_before.png` → `18_explore_after_iso.png`
  - 客栈前／后：`17_inn_before.png` → `19_inn_after_iso.png`
  - B2：`15_b2_bamboo.png`（亦在 `tactics-tri/docs/`）

## 可玩路径

1. 标题 →「江湖·青崖渡」→ 接任务 → **B1 渡口** → 客栈选立场 → **B2 竹林（可选，取匣撤离）** → 废祠 B3 仍提示后续开放。
2. 标题「渡口截箱」直打 B1；`--shot=wuxia_b2`／`--sim=wuxia_b2` 可用。

## 未完成 / 开放问题

- B3 完整胜负（先败首领再取渡簿）与 escort／sect 变体未接探索。
- 探索建筑仍为地块堆砌，未到正式建筑切片；河岸／渡船可读性可再加。
- B2 6 轮速通消耗品奖励未做；双方 AI 胜率未抽样。
- Steam 正式八向动画未启动。

## 下一阶段建议

1. 接线 B3 与立场变体。
2. 探索建筑／渡口专用装饰切片。
3. B2 难度与 `--sim=wuxia_b2` 平衡。
