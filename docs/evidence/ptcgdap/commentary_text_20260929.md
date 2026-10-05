# 3D 文字解说验证记录

日期：2026-09-29。Godot 4.6.1，Windows，渲染使用 NVIDIA RTX 4090 / OpenGL Compatibility。

## 结果

| 验证 | 结果 |
| --- | --- |
| 新增 BattleCommentary 功能套件 | 20 / 20 通过 |
| BattleEffectsSetting | 2 / 2 通过 |
| BattleSetupAIVersions | 47 / 47 通过 |
| BattleSetupLayout | 43 / 43 通过 |
| 实际 3D 渲染与交互验收 | 26 / 26 检查通过，进程退出码 0 |
| 全量内置卡组知识检查 | 112 份卡组、49 份机制档案，覆盖与印刷锚点校验通过 |
| 付费 DeepSeek 请求 | 0 |

自动套件共 **112 项通过，0 失败，0 跳过**。汇总机器记录：[commentary_text_20260929.json](../../../evidence/ptcgdap/commentary_text_20260929.json)。

最初的 RED 用例确认缺少独立解说 Session 后失败；实现后补入真实行为与回归断言。过程中修复了 JSON 浮点证据 ID 比较导致合法响应被拒绝、720p 设置页高度溢出、触摸只发 pressed 时开关不切换等实际失败。

子 Agent 扮演 DeepSeek 提供预研与解说样本，并独立审阅代码。其发现的指示物单位、失败训练家事件、同名不同印刷、动画期间迟到响应、事件合并基线和降级战况更新问题均已修复并加入回归。

## 网络与模型替代

真实 HTTPRequest 测试仅连接 127.0.0.1，由本地 TCP 服务模拟 chat/completions 的 envelope。验证请求 JSON 模式、关闭思考、公开输入、usage 分离和响应证据解析。模型内容通过生产解析器往返 JSON，不直接假设 JSON 数字类型。

渲染验收使用真实战斗 Scene、真实交互步骤和真实引擎执行暗影子弹，确认主目标实际减少 180 HP，再经事件汇总、预研完成门控、模型响应和字幕展示走完整链路。棋盘初态由夹具构造；模型台词来自子 Agent，不能据此宣称线上 DeepSeek 已达到同样质量。

## UI

已目视检查宽屏与竖屏截图。字幕有独立布局空间，不盖手牌和场地；鼠标打开回看、无鼠标模拟时的原始触摸、键盘关闭、关闭后的场地恢复、设置保存及切回 2D 后禁用都通过。

| 截图 | 说明 |
| --- | --- |
| [宽屏](../../../evidence/ptcgdap/commentary_text_20260929/wide.png) | 真实 3D 场地、解说与手牌同屏 |
| [竖屏](../../../evidence/ptcgdap/commentary_text_20260929/portrait.png) | 独立字幕区域和完整场地目标 |
| [设置](../../../evidence/ptcgdap/commentary_text_20260929/setup.png) | 默认关闭、仅 3D、费用提示 |

渲染夹具退出时 Godot verbose 日志另有一条 RefCounted（reference count 0）的 ObjectDB 清理警告，无脚本错误、验收失败或运行中卡死。此次未将其判定为新增解说泄漏，也未宣称完成全游戏内存清理；保留该观察供后续定位。

## 文件与回退

实现说明与命令：[COMMENTARY-TEXT-IMPLEMENTATION](../../arena3d/COMMENTARY-TEXT-IMPLEMENTATION-2026-09-29.md)。

已有运行时文件只接入 BattleSetup、BattleScene 和 ArenaLayout；其余为新增独立 commentary 模块、数据和测试。无需提交或发布才能在本地工程使用；本轮没有提交、推送、改版本或重打安装包。

直接关闭设置即可停用。源码回退仅移除本次连接点与新增文件，保留工作区已有改动。功能是可选联网展示辅助，不改变设备本地策略运行边界，也不增加策略执行权限。
