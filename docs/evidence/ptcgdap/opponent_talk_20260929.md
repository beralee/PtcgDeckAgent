# 对手人格互动验证记录

日期：2026-09-29。实现说明：[文字首版](../../arena3d/OPPONENT-TALK-2026-09-29.md)。Windows，Godot 4.6.1，OpenGL Compatibility / RTX 4090。

## 结果

| 验证 | 结果 |
| --- | --- |
| OpponentTalk | 9 / 9 |
| 原 BattleCommentary（含公共投影、知识覆盖、回环 HTTP） | 20 / 20 |
| BattleSetupLayout | 43 / 43 |
| DeepseekSettingsUI | 1 / 1 |
| 实际 3D 场景与输入 | 26 / 26 |
| 上一轮真实 18.5 多龙局公开录像 | 81 个局面，9 个发言触发，0 个核对错误 |
| 付费 API | 0 次 |

自动套件共 73 项，0 失败、0 跳过。机器报告与截图在 [证据目录](../../../evidence/ptcgdap/opponent_talk_20260929)。所有模型回复均为离线子 Agent 编写的夹具，未验证真实 DeepSeek 的生成质量或线上延迟。

## 验证的实际行为

最初的失败用例确认尚无独立对手 Director。补入实现后，检查自己的动作与玩家动作分离、开局不误报卡死、展开回合不自称受阻、真实奖赏计数变化后才庆祝、胜负优先且只报一次。三种本地人格使用同一事实槽位，不推进游戏全局 RNG。模型回复仅准备模板、迟到回复不恢复静音会话、预算/失败熔断和无 Key 本地模式均已验证。

子 Agent 模拟 DeepSeek 提供 12 个角色样本（9 正例、3 负例）和完整九类双句模板库。额外人工审阅修掉开场“我的回合”及丢奖即声称“受到攻击”的错误假设。静态校验只证明所检查的格式和内容约束，不能证明所有自然语言事实。

真实渲染验收用已构造的合法初态，由生产交互执行暗影子弹，确认对手发动招式时气泡已经有第一人称喊招，同时引擎确实扣除 180 HP，不等待模型。鼠标回看、关闭鼠标模拟后的原始触摸回看、键盘静音、静音取消请求和归还场地、设置开关持久化，以及 2D 不创建 Agent 都通过。

检查启动流程还发现作者策略的异步校验可能晚于场景创建：新增用例先安装 Controller、后提供真实 GSM，旧代码确实失败（0 请求、整局不说话）。修为等待并绑定实际 GSM 后，完整 26 项渲染验收通过。若 GSM 被替换，旧会话关闭，避免串局。

## 真实多龙录像核对

只读取前一轮模拟保存的公共投影，没有读取或上传私有引擎录像。按事件顺序驱动 Director，使用虚拟时钟验证发言逻辑；这不是新录制的视频，也不是新一轮策略胜率测试。

| 步骤 | 实际触发 |
| --- | --- |
| 4 | 开场 |
| 13 / 23 | 小哀怨 / 龙之头击喊招 |
| 34 | 多龙巴鲁托 ex 实际进化登场 |
| 71 / 97 / 114 | 幻影潜袭喊招 |
| 74 | 已完成的两张奖赏转移后得意 |
| 117 | 确认胜利，只说一次，不再追加两奖庆祝 |

无喷火龙台词，无“我的长毛巨魔”串阵营错误。第 45 步虽未攻击，但本回合有公开发展动作，因此没有强行说“卡死”。模拟模板准备 3 次，付费请求 0 次。

## 视觉证据与范围

- [宽屏气泡](../../../evidence/ptcgdap/opponent_talk_20260929/wide.png)
- [竖屏气泡](../../../evidence/ptcgdap/opponent_talk_20260929/portrait.png)
- [设置入口](../../../evidence/ptcgdap/opponent_talk_20260929/setup.png)

已目视检查截图并验证气泡不覆盖牌场、手牌及 44 px 按钮点击目标。原始触摸是 Windows 上的输入事件测试，不代表已完成 Android/iOS 实机验收；当前 3D 平台门控不变。渲染夹具退出仍有此前已观察到的 ObjectDB 清理警告，无脚本错误，不宣称本轮修复全游戏资源泄漏。

本轮仅落地代码与本地验证，未提交、推送、改版本或打包发布。无需回退规则/策略代码，直接关闭设置即可停用；精确源码回退见实现说明。

## 复现

```powershell
.\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_opponent_talk.gd -UserDataRoot .godot_test_user/commentary -ReportDirectory C:/Users/24726/.codex/tmp/opponent_talk_check_new
$env:APPDATA = 'D:\ai\code\PtcgDAP\.godot_test_user\commentary'
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/commentary/OpponentTalkArenaAcceptanceRunner.gd
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path . --script res://tests/commentary/OpponentTalkReplayAcceptanceRunner.gd -- --public-replay=res://.tmp/commentary_match_20260929/public_match.json
```

报告目录须为新的空目录。录像检查需要指定上一轮生成的公共投影文件；没有文件时明确失败，不伪造轨迹。
