# Windows 3D 支援者人物演出

本轮保留用户已认可的老大演出，替换其余 17 张支援者的卡面广告牌和中央几何展示。每位使用根据具体印刷卡图制作的六姿势人物图集，配合人物入场、蓄势、手势重拍、结算和退场；共新增 102 个动作画面。

## 归属和行为

- `ArenaSupporterVfx` 只负责公共身份分发、时钟、声音及清理；老大仍交给原来的 `ArenaBossOrdersVfx`。
- `ArenaSupporterCharacterCatalog` 保存各角色的节奏和视觉方向；`ArenaSupporterCharacterCutIn` 负责人物和标题层；`ArenaSupporterCharacterVfx` 负责相机及场地灯光。
- 回手和附能只使用 `ArenaSupporterCue` 已允许的公开槽位。检索和手牌变化不制造额外的宝可梦目标，也不读取隐藏手牌、牌库顺序或策略输入。
- `ArenaMotionDirector` 继续在角色手势之后释放已经提交的规则结果。正常演出约 2.94–3.30 秒；快进仍为 1.8 倍。关闭效果、缩放、换场会清理人物、相机偏移、声音和输入等待。
- 素材丢失时返回普通表现流程，避免留下半初始化的演出。
- 席蓝的人物和配色以实际 CSV9C_198 卡图的白礼帽角色为准。

## 素材和声音

`assets/arena3d/supporters/characters/provenance.json` 保存内置 imagegen 的完整提示词、具体参考印刷、原始文件名、RGBA 尺寸、透明比例及每一格的 SHA-256。17 张图集均为 1536×1024，三列两行；保留原始透明通道，运行时着色器只柔化格子边界。

`tools/arena3d/build_supporter_character_audio.py` 根据每位角色的手势和结算时点合成独立的 48 kHz 立体声音效，不使用采样人声。已认可的 `boss_command.wav` 不改动。

## 验收和录制

- 新增全员人物动作测试先红后绿，确认原卡面广告牌被替换、动作在关键时点改变、结算与退出留足时间。
- 实际 Iono、Boss、Turo、Penny、Crispin、Arven 出牌覆盖手牌队列、真实目标槽位、回手、附能、检索及取消清理。
- `ArenaSupporterCharacterReview.gd` 布置合法局面，18 张牌逐张通过 `GameStateMachine.play_trainer` 提交。录像使用 Windows OpenGL 游戏渲染器，不是将人物素材离线叠在假棋盘上。
- 合集每位六秒，包含出牌前局面、人物演出和卡效结果；它是布置局面的演示合集，不是完整竞技对局。
- 本地报告位于 `.tmp/supporter-characters-20260929/`，包括 `red`、`green`、`regression`、`windows-tests.json`、录制日志和视频完整解码检查。

已通过 10 项支援者专项、22 项相关集成回归和 8 项导出资产检查；同一支援者专项在 Windows OpenGL 渲染器上再次全部通过。全员图集检查确认 17 张有效 RGBA 图集、102 个互不相同的动作格。18 张牌的实际出牌和完整录制均无脚本错误，角色切换前的表现队列已结束。

本轮仅改变表现层，不声明新的 CABT 引擎或策略对齐水平。没有修改外部 oracle、私有云服务或设备本地策略边界。

## 回退

工作前的相关脚本保存在 `.tmp/supporter-characters-20260929/before/`。可恢复其中的 `ArenaSupporterVfx.gd`、测试和展示脚本，移除新增 Character 三个脚本及着色器引用；旧的 `tools/arena3d/build_supporter_audio.py` 能重新生成此前 2.1 秒声音。Boss 原人物脚本、图集及音效独立保留，不需要回退。回退时保留工作树其他已有改动。
