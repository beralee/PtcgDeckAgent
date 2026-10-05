# AI 对手心态表情验收记录

2026-09-29。实现与研究依据见[设计文档](../../arena3d/OPPONENT-EMOTIONS-2026-09-29.md)。本次是可选显示功能，不改变出牌策略或 CABT 对齐等级，未打包发布。

## 范围

新增 `OpponentMood.gd` 和十二张原创表情图集。Director 从公开事件判定心态；Session、Voice、Bubble 与回看共用规范心态 ID。十五种合法事件/心态组合覆盖十二种表情。既有性格控制措辞；本地句库完整兜底，网络不阻塞游戏。默认关闭、只在既有 3D 模式门控内启用。

## 验证

先运行缺少心态模块的失败用例，再补齐实现。最终结果：

| 检查 | 结果 | 本机证据 |
| --- | --- | --- |
| 心态、头像、句库、历史与复位 | 7/7 | `C:/Users/24726/.codex/tmp/opponent_emotion_final_20260929/report.json` |
| 原有对手互动回归 | 9/9 | `C:/Users/24726/.codex/tmp/opponent_emotion_talk_regression_20260929/report.json` |
| 实际渲染、布局、开关、鼠标/原始触摸/键盘 | 29/29 | `.tmp/opponent_emotions_20260929/arena_acceptance.log` |
| 完整比赛与回放状态核对 | 91/91 | `output/opponent-emotions-20260929/video-evidence.json` |
| 视频完整解码 | 通过 | 同上，`file.full_decode_ok` |

渲染用例进程正常退出；测试场景仍有原有 ObjectDB 退出警告，本轮没有将其宣称修复。触摸检查为 Windows 的输入事件测试，未完成移动平台实机验收。当前 3D 平台门控未扩展。

可复现入口：`tests/test_opponent_emotions.gd`、`tests/test_opponent_talk.gd`、`tests/commentary/OpponentTalkArenaAcceptanceRunner.gd`。对局脚本为 `CommentaryMatchSimulationRunner.gd`，参数 `--match-seed=20260930 --output-root=res://.tmp/opponent_emotions_20260929/match`；录像入口为 `OpponentEmotionMatchVideoRunner.gd`，编码与成片工具位于 `tools/arena3d/encode_commentary_stream.py` 和 `finish_opponent_emotion_video.py`。

## 新对局与录像

18.5 玛俐长毛巨魔（675700，本地规则）对 18.5 开发者多龙（675701，`dev.dragapult-dusknoir` 0.9.1）。种子 20260930；132 个决策步骤，13 回合，玛俐拿完奖赏卡获胜。开发者策略 79 次成功调用，0 错误、0 引擎拒绝、0 同窗回退。

按原始行动顺序录制完整对局回放；压缩等待并保留台词阅读时间。模拟模型经真实响应解析链路调用两次，零付费请求。实际十次发言、六种心态；没有为展示全部表情伪造场面。片头片尾另有十二表情一览。私有引擎快照仅用于本机恢复画面，未上传。

视频：121.233 秒，1600×900，30 fps，H.264/AAC，49,512,208 字节。

本地 SHA-256：`0c0c05a9188950cd9488d92c71c3412366a9cee9357bc9d13e93b7f66a1e8bff`。

本地 MD5：`98f5891cbe4006c18b4bc8f7e7807e14`。

[网盘视频](https://drive.google.com/file/d/1ENKYeGlDwhaCzBjkJ_Hk5FSyGWGnBCYz/view?usp=drivesdk)与[表情 ZIP](https://drive.google.com/file/d/1NbvZDbyFG3W18iDREPJ__9AizRLIxDTf/view?usp=drivesdk)均已上传后回读文件名、类型、大小及 URL；连接器未返回远端哈希，因此不声称完成远端哈希校验。沿用现有网盘权限。

## 回退

玩家关闭“AI 对手互动”即可停用。源码回退仅撤销本轮心态模块、资源与对应对话/UI/测试改动，保留此前对手互动及其他工作区修改。本次未提交、推送、修改版本号或发布安装包。

## 2026-09-30：右侧独立布局

按用户反馈取消顶部横条，改为右侧 236–292 逻辑像素的独立栏。`ArenaLayout` 在主区域右侧预留宽度，`OpponentTalkController` 布置不拦截输入的深色背景和气泡，`OpponentTalkBubble` 改为纵向表情、心态、台词、按钮。气泡不再缩减场地高度；静音同时移除背景并释放侧栏宽度。策略和网络逻辑未改动，对齐等级不变。

先增加“气泡必须位于战斗区右侧、战斗区保留高度”的渲染断言，旧实现失败（`.tmp/opponent_emotions_20260929/sidebar-red.log`）；修改后使用真实 3D 场景通过 85 项检查，包括四种窗口尺寸、长句完整显示、卡牌/手牌/按钮不重叠、鼠标和原始触摸回看、键盘静音与释放侧栏。心态逻辑回归 7/7 通过。使用既有隔离测试用户目录，零付费请求。原有测试场景 ObjectDB 退出警告仍在。

证据位于 `output/opponent-emotions-20260930-layout/`：`report.json`、`emotion-tests.json`、`landscape.png`、`portrait.png`。未重新录制旧视频或发布安装包。停用仍使用对战设置开关；源码回退限定本次三个布局文件及对应测试增量。

## 2026-09-30：最终改为临时浮动气泡

用户进一步要求缩小、悬浮在对手牌堆到战斗宝可梦上方的空白处，不覆盖备战卡。已取消上述侧栏与宽度预留；MainArea 恢复原来的完整宽高。气泡仅在发言时显示，八秒后隐藏，终局也不再常驻。头像从 112 缩至 60 逻辑像素，常规截图中的气泡为 280×107；根据可用空间和长句在 280–360 宽度之间选择。

新增 `OpponentTalkPlacement.gd`，从实际投影矩形寻找对手右上方的安全空隙；上方不够时使用战斗宝可梦与牌堆之间的空隙。避开全部可见卡位（包括空备战槽）、牌堆、奖赏与操作控件。没有安全位置时临时隐藏，不缩放或挤压场地。隐藏 Container 尚未排版时，先按真实文本宽度测量换行高度，避免误判为无法放置。

气泡的两个按钮注册到 presenter 的既有触摸目标列表，复用 ArenaTouchInput 的取消、拖动与兼容鼠标处理；静音时注销，避免留下失效按钮引用。气泡正文保持鼠标穿透。没有修改策略、网络请求或隐私边界。

先补充默认隐藏、八秒消失及终局消失用例，旧实现按预期失败。最终心态与空间避让回归 9/9 通过；四种窗口尺寸、长句、逐卡不覆盖、全宽全高、牌堆与按钮不重叠、鼠标回看、原始触摸回看、键盘静音、触摸目标注销等渲染检查 155/155 通过。所有台词来自离线模拟，付费请求为零。Windows 输入事件验证不代表移动设备实机验收；已有 ObjectDB 测试退出警告未在本次修复。

最终证据位于 `output/opponent-emotions-20260930-floating/`；执行日志为 `.tmp/opponent_emotions_20260929/floating-render-upper-final.log` 和 `floating-tests-final.log`。网盘视频仍是原录制版，本轮没有重新录制或打包。回退只撤销本次浮动定位、临时显示、触摸注册及对应测试修改；关闭对战设置开关可直接停用。
