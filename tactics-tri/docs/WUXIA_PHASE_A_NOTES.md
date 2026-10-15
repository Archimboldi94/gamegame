# Phase A 实施笔记（2026-10-15）

## 做了什么
- 开发基线确认：`tactics-tri`（等距 UI / HUD），Core_v2.0 仅作规则/数据参考。
- 规则：八向移动、封闭角禁斜穿、AP/内力/RP、GDD 命中伤害（`use_gdd_rules`）、五格控制区、借机/反击。
- 数据：`data/wuxia/b1_map.json` + `b1_combat.json`；`BattleDefs.build_wuxia_b1()`。
- 入口：标题「渡口截箱」直进 `wuxia_b1`；`--shot=wuxia_b1` 可截图。
- 测试：`tests/run_tests.gd` 新增四项武侠测试；全量 **2282 PASS / 0 FAIL**。

## 截图
- `/workspace/tactics-tri-wuxia-shots/00_title.png`
- `/workspace/tactics-tri-wuxia-shots/01_wuxia_b1_open.png`
- 仓库副本：`tactics-tri/shots/wuxia/`

## 已知缺口（下一阶段）
- 战斗 UI 仍大量沿用「移动一次 + 行动一次」文案/菜单；GDD 下 AP 穿插可玩但未完全情境化。
- 燕行步/回锋/击退/截脉为简化实现；敌方 AI 未按 ZoC 估价。
- 泥地/木箱用草地等美术回退；正式像素未接。
- 客栈探索 → 战斗 → 谱库闭环未做。
- 旧叙事关卡仍可运行，但主入口已切武侠 B1。
