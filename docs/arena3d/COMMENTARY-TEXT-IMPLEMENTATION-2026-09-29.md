# 3D 比赛文字解说：实现与验证

日期：2026-09-29。承接 [分析设计](COMMENTARY-AGENT-DESIGN-2026-09-29.md)。

后续方向调整：实时对战入口现已改为[有性格的对手互动](OPPONENT-TALK-2026-09-29.md)。本文保留旁观解说原型的历史实现与视频复现说明，其中「AI 文字解说」入口和 24 次预算不再描述当前实时对战功能。

## 已实现的体验

在对战设置选择 3D 场地后，可开启「AI 文字解说」。默认关闭，与对手是否使用大模型无关。2D、录像回看与无画面的测试运行不创建解说 Agent。当前游戏的 3D 场地仍只向 Windows 开放，本次没有改变平台范围。

开启后先加载卡组知识，再根据双方公开开局分析打法；这一步成功后才生成策略解说。每个已记录行动都会使旧响应立即失效，等引擎选择和场景动画完成后，汇总公开事件与前后局面。模型在后台工作，对战不等待网络。

字幕区域在场地上方独立占位，横屏、竖屏均不覆盖场地目标和手牌。支持鼠标、键盘与原始触摸事件；回看采用游戏内弹层。关闭立即取消本实例的请求并归还场地空间，不影响对手 AI。

API 使用设置中的 DeepSeek 账户与模型，保持独立请求实例。开发验证全部使用子 Agent 编写的模拟响应和本机回环 HTTP 服务，付费请求数为 **0**。玩家主动开启且已配置 Key 后才会使用真实服务。

## 卡组预先理解

[知识库](../../data/commentary/deck_knowledge.json)覆盖当前全部 **112** 份内置卡组，显式映射 **49** 份机制/打法档案。组合牌组可以对应多个档案，不是给每个名字套一段通用描述。

每份档案包含：

| 字段 | 解说关注点 |
| --- | --- |
| opening | 启动与铺场依赖 |
| engine | 抽滤、检索、附能、攻击等核心循环 |
| prizes | 单双奖交换、补刀与多目标取奖路线 |
| sustain | 下一只攻击手、能量、回收和换位 |
| risks | 关键干扰、资源空档、机制易错点 |
| printings | 在明确映射的内置牌组中核对过的本地印刷 UID |

例如多龙强调正面伤害与备战指示物的跨回合收割；玛俐强调进化附能与前后排攻击，明确暗影子弹的备战部分是招式伤害；呆呆王强调顶牌控制，同时禁止读取或确定宣称隐藏顶牌。

旧 DeckData.strategy 中存在把雷吉铎拉戈复制招式说成特性等错误，本实现不把这些文本作为权威。运行时提供公开卡牌的具体规则文本，优先级高于通用档案。同名不同机制的密勒顿 ex、卡比兽等不能直接继承档案。

对局中不会用选中的完整牌表或卡组 ID 暗中确认对方体系。档案由已公开的场上、弃牌区、放逐区印刷触发，始终标成候选组件；模型不能把常见搭配说成对方当前手牌。自定义或未知印刷先依据已公开卡文分析，明确未识别的部分；后续出现新体系证据时重新分析，不冒充已经掌握未公开的整副牌。

维护方式：

1. 在 [生成器](../../tools/build_commentary_knowledge.py) 的 ROWS 中编辑机制档案。
2. 在 GROUPS 中明确映射新增卡组；不自动根据名称补齐缺口。
3. 执行 python tools/build_commentary_knowledge.py。
4. 执行 BattleCommentary 套件。它独立扫描实际卡组文件，检查每副牌的覆盖、字段完整性和印刷证据，不依赖种子 manifest 或 AI 支持名单。

本次没有修改内置牌组、manifest、种子版本或 AI 支持范围。

## 代码边界

| 文件 | 职责 |
| --- | --- |
| [CommentaryPublicProjector](../../scripts/commentary/CommentaryPublicProjector.gd) | 公共信息白名单；隐藏区只取数量，双方准备阶段都遮盖 |
| [CommentaryKnowledge](../../scripts/commentary/CommentaryKnowledge.gd) | 开局前加载档案，公开印刷匹配与已见组件记忆 |
| [CommentaryPrompt](../../scripts/commentary/CommentaryPrompt.gd) | 专业语气、分析/解说协议、规则文本预算与响应格式验证 |
| [BattleCommentarySession](../../scripts/commentary/BattleCommentarySession.gd) | 单请求、节流、费用预算、取消、过期校验和最近 40 条记录 |
| [CommentaryDeepSeekClient](../../scripts/commentary/CommentaryDeepSeekClient.gd) | 现有 DeepSeek 传输的独立实例，JSON 模式、关闭思考、保留供应商 usage |
| [BattleCommentaryController](../../scripts/commentary/BattleCommentaryController.gd) | 订阅公开事件，等待稳定局面，将响应送入 UI |
| [CommentaryPanel](../../scripts/commentary/CommentaryPanel.gd) | 独立字幕区域、回看、关闭 |
| [CommentarySetupOption](../../scripts/commentary/CommentarySetupOption.gd) | 设置开关与 720p 紧凑布局 |
| [CommentaryPreferences](../../scripts/commentary/CommentaryPreferences.gd) | 独立 user://battle_commentary.cfg 偏好与运行门控 |

已有文件仅增加三个连接点：BattleSetup 放置开关；BattleScene 在实际 3D 中安装；ArenaLayout 为字幕预留高度。不修改引擎的动作选择、策略边界或规则结果。

## 费用和故障处理

- 每局最多 24 次请求，含前置打法分析；最短间隔 9 秒。
- 总预算 120,000 tokens。发送前用 UTF-8 字节数保守预留，供应商返回可信 usage 后调整；缺失 usage、超时或取消不会被当成免费。
- 分析输出最多 800 tokens，解说最多 300 tokens；单条字幕长度与证据 ID 受本地约束。
- 每次只允许一个请求；排队信息合并成最新局面，保留最早 before 基线与最多 64 条事件。
- 连续失败三次、额度不足或上下文过大时停止模型请求，继续本地公开战况。
- 使用验证 TLS，不走旧客户端的不安全 TLS 或 Python 回退，不写临时 Key，不消耗游戏随机数。
- 不把供应商 envelope 与模型 JSON 混在一起。模型伪造 tokens 字段不能改变费用记录。

## 实际验证

[功能用例](../../tests/test_battle_commentary.gd)包含隐藏信息哨兵、双方准备阶段遮盖、抽牌/奖赏净化、全部内置卡组覆盖、不同印刷隔离、先分析后解说、单请求、迟到响应、预算熔断、随机数不变及本机 HTTP 请求。HTTP 用例真正经过 HTTPRequest、请求构造、响应解析和证据验证，只连接 127.0.0.1。

[模拟响应集](../../tests/fixtures/commentary_model_simulation.json)由子 Agent 担任专业解说编写，18 例含 11 个正例、3 个机械拒绝例、4 个人工语义反例。自动化使用正例与机械反例；不把 JSON 校验包装成全自动的幻觉检测。专业规则审阅见 [模拟与审阅记录](../evidence/ptcgdap/commentary_model_simulation_20260929.md)。

[渲染验收](../../tests/commentary/CommentaryArenaAcceptance.gd)在真实 3D 战斗场景调用真实交互和规则引擎，完成玛俐攻击、状态汇总、模拟分析与解说、实际字幕、回看和关闭。还验证横屏/竖屏几何、原始触摸、设置偏好，以及已开启偏好时 2D 仍不创建 Agent。初始棋盘由夹具布置，网络模型响应由子 Agent 编写；这不是完整自然对局或线上 DeepSeek 质量评测。

复现：

```powershell
python tools/build_commentary_knowledge.py
.\scripts\tools\run_godot_tests.ps1 -Runner functional -Suite BattleCommentary
.\scripts\tools\run_godot_tests.ps1 -Runner ui -Suite 'BattleEffectsSetting,BattleSetupAIVersions,BattleSetupLayout'
# 渲染验收须使用隔离的 APPDATA；夹具会切换其解说偏好。
$env:APPDATA = 'D:\ai\code\PtcgDAP\.godot_test_user\commentary'
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/commentary/CommentaryArenaAcceptanceRunner.gd
```

本机磁盘接近测试框架的 2 GiB 保护线，最终套件报告写入 C 盘的任务临时目录并复用隔离用户目录，没有降低保护门槛。最终汇总见 [验证证据](../evidence/ptcgdap/commentary_text_20260929.md)。

## 明确的能力边界

首版不是读全牌表的教练。公开展示事件中的卡牌身份暂不外传，临时效果尚未全面结构化，所以这些信息不足时应保守表达。过期、取消、格式和证据引用可以机械验证；自然语言中的所有规则推理、胜负表述仍需语义评审。终局的本地事实由引擎 winner 决定。

真实 DeepSeek 的质量、延迟与账单没有在本轮测试中验证。没有增加语音功能，没有改版本号、打安装包或发布。

回退时关闭设置开关即可停止新对局的模型请求。若回退代码，应仅移除本次三个连接点和新增 commentary 文件；不要整体恢复已有脏文件。任务开始时的连接点文件快照位于 .tmp/commentary_20260929/before。
