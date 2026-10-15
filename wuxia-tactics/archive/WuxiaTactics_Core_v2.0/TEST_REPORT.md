# B1工程与战斗测试报告

测试日期：2026-10-15。工程：`WuxiaTactics_Core_v2.0`。引擎实测版本：`4.6.3.stable.official.7d41c59c4`。

## 结论与验证边界

**静态检查、真实Godot脚本执行、真实主场景键鼠/HUD集成和headless主入口均通过。** 战斗88项、UI24项，合计112项行为检查无失败。3局固定种子B1对局已从原始部署推进至胜利，另以濒死队伍夹具验证真实AI攻击至败北。

**未完成三局图形试玩。** 本报告不把自动对局写作人工试玩，不把静态通过写作“已验证可玩”。GUI启动及Xvfb均实试失败，原因如下。

## 环境与可重复命令

直接运行默认用户环境的Godot测试/主场景曾因`user://logs`不可写而signal 11退出（exit 134）。编辑器默认配置目录也不可写。采用下述进程环境后不再崩溃，不改动全局HOME或工程运行配置：

```bash
mkdir -p /tmp/wuxia-core-validation/data /tmp/wuxia-core-validation/config /tmp/wuxia-core-validation/cache
export XDG_DATA_HOME=/tmp/wuxia-core-validation/data
export XDG_CONFIG_HOME=/tmp/wuxia-core-validation/config
export XDG_CACHE_HOME=/tmp/wuxia-core-validation/cache

python3 tests/static_validation.py
/home/box/.local/bin/godot --headless --path . --editor --quit-after 2
/home/box/.local/bin/godot --headless --path . --import
/home/box/.local/bin/godot --headless --path . --script res://tests/CombatTests.gd
/home/box/.local/bin/godot --headless --path . --script res://tests/UITests.gd
/home/box/.local/bin/godot --headless --path . --quit-after 120
```

或直接运行`python3 tests/run_checks.py`，该入口自动设置子进程环境、限制单步60秒并保存日志；Godot二进制可用`GODOT_BIN`指定。

## 最终复验结果

| 检查 | 退出码 / 摘要 | 原始输出 |
|---|---|---|
| 静态 | 0；资源引用、地图、部署、战斗JSON契约通过 | [final_static.log](artifacts/final_static.log) |
| 编辑器快速启动 | 0；无解析错误；沙箱TCP监听失败；2帧退出会中止扫描线程 | [final_editor.log](artifacts/final_editor.log) |
| 完整导入 | 0；脚本注册与编辑器布局加载完成；沙箱TCP监听失败 | [final_import.log](artifacts/final_import.log) |
| CombatTests | `TEST RESULT: 88 checks, 0 failures` | [final_combat.log](artifacts/final_combat.log) |
| UITests | `UI TEST RESULT: 24 checks, 0 failures` | [final_ui.log](artifacts/final_ui.log) |
| 主入口120帧 | 0；无解析/运行错误 | [final_main.log](artifacts/final_main.log) |
| 汇总入口 | 0 | [final_summary.log](artifacts/final_summary.log) |
| 差异检查 | `git diff --check -- .`通过 | 无空白错误 |

编辑器的`_inet_open` / `TCPServer.listen`错误来自禁止创建监听套接字的沙箱。验证入口只允许编辑器这两个确定来源的错误成对出现，明确标记环境限制；不会忽略其他解析/脚本错误。CombatTests、UITests及主场景最终日志无ERROR、泄漏或失败项。

## 自动化覆盖

- 12×12地图/marker部署、普通与泥地AP、八向最短路径、占格、封闭角、直线遮挡、非轴向轻功经过格、越界、高墙与低障碍。
- 移动路径整体校验；逐步扣AP；借机致死停止在原格并仅扣尝试步；AP/内力不足不支付资源。
- 速度交错、死亡跳过、同速稳定ID、速度变更下轮重排、RP统一轮次刷新、自然恢复、调息限次、状态失效、防御互斥、轻功限次。
- 八种朝向严格五格ZOC；多敌同一步仅一人反应；后续步可触发他人；RP共享；反应不递归；背袭与落空反击；反应不扣AP/内力。
- 命中/未命中固定种子、未命中仍扣费用且不消耗目标防御、破甲、最低伤害、护势floor取整、枪法恰好2格与单位/地形挡线、AOE独立掷骰及主目标反击、击退被阻挡、截脉指、回锋安全后撤限次。
- 只读预览不改变状态或随机数；命中与落空分别模拟击退/后撤/反击分支；实际命中率、命中伤害、落点与预览相同。
- 敌方主动接敌/攻击、无路可走有限返回；真实B1完整对局；资源/占格不变量；胜负后锁定与重开复位。
- UITests加载真实Main.tscn，经Viewport注入键鼠；检查命令栏边界、等距选格、选招/取消、点击移动/攻击、空格推进、敌方空槽HUD、延迟AI、危险模态取消/确认、途中阵亡、旧确认/旧AI回调失效、胜败弹窗与重开。

## 三局自动对局记录（非图形试玩）

使用原B1地图、属性和真实EnemyAI；仅随机种子及我方测试策略不同。每次角色行动后检查存活占格合法、无重叠、AP不为负、内力0—12、RP为0或1。

| 局 | 种子 | 我方测试策略 | 结果 | 结束轮次 / 单位行动次数 |
|---|---|---|---|---|
| 1 | 1234 | 近身普攻与接敌移动 | 胜利 | 2 / 7 |
| 2 | 1235 | 全程结束行动，保留自动反击 | 胜利 | 7 / 24 |
| 3 | 1236 | 可用固定招式，按命中伤害/AP选择 | 胜利 | 2 / 7 |

第二局说明当前建议参数偏简单，不能据此推算胜率，也未擅改【已定】规则。额外败北夹具：只把我方初始HP改为1，使用真实敌方AI与正常轮次，得到`defeat`，第2轮、6次单位行动；该夹具不是默认B1难度测试。

## 图形试玩未完成的实证

- `DISPLAY=:16 /home/box/.local/bin/godot --path . --quit-after 2` → exit 1，`X11 Display is not available`，Wayland亦无法连接。见 [graphical_attempt.log](artifacts/graphical_attempt.log)。
- `Xvfb :99 -screen 0 1280x720x24 -nolisten tcp` → exit 1，`Cannot establish any listening sockets`。见 [xvfb_attempt.log](artifacts/xvfb_attempt.log)。
- 因而无法检查像素画面、中文字形、实际鼠标悬停手感、截图和三局图形实玩。主场景输入集成的通过只说明引擎节点与交互链路工作，不能替代这部分验收。

## 初检与修复后差异

原静态测试通过；在可写XDG环境中，原18项CombatTests与短时主场景启动均通过，未发现脚本解析错误。原测试没有覆盖敌方回合HUD、模态输入、重开竞争及大部分规则边界。本轮针对这些遗漏修复后，已运行上述完整复验。初始环境崩溃日志及中间检查保留在`artifacts/initial_*`、`baseline_*`等文件中。

最终复核新增“取消确认后按钮立即恢复”的回归项，先在修复前得到`24 checks, 1 failures`（见 [cancel_regression_before_fix.log](artifacts/cancel_regression_before_fix.log)），再修复取消回调的HUD刷新，并重跑全套得到24项UI检查通过。

已知剩余项：B1强度与AI策略平衡、图形三局验收；内功/自选构筑、正式美术与演出、探索/共享谱库/成长/保存未实现，详见NEXT_STEPS。
