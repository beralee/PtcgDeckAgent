# 老大的指令：人物驱动的 3D 演出重制

本次只重做老大的指令。其余 17 张仍是上一版，没有宣称整套已达到本次的人物演出标准。

原版 2D 的有效设计是独立人物、明确手势和人物自身的气场。上一版 3D 的整卡展示加线条装饰没有延续这个重点。

新路径使用与 2D 六帧动作对应的高清板木立绘：出场、紫色气场、抬掌、指向、目标锁定、气场退去。人物在独立展示层压过场地标签；右侧保留真实目标，镜头轻移让人物与目标分开。立绘是 2D cut-in，场内束带、卡牌运动和灯光在 3D 中；不是绑定骨骼的 3D 板木模型。

正常总长 3.05 秒。1.02 秒指向冲击，1.78 秒释放已经提交的公开结果，再由现有 MotionDirector 播放真实换位；输入到 3.05 秒恢复。快进统一除以 1.8。取消、缩放和关闭动态效果会清理外部展示层、音效、几何和镜头偏移。未改变任何卡牌规则和策略边界。

资源：

- 高清六帧素材：[boss-command-hd.png](../../assets/arena3d/supporters/boss-command-hd.png)。使用内置 image_gen 编辑；原 2D 贴图保留。
- 完整生成提示词与来源：[boss-command-hd.provenance.json](../../assets/arena3d/supporters/boss-command-hd.provenance.json)。
- 音效由 `tools/arena3d/build_boss_command_audio.py` 原创合成，无外部录音或对白。

录像使用 `ArenaBossOrdersReview.gd` 布置公开场面，通过真实 `GameStateMachine.play_trainer` 打出老大，并断言选中的备战目标确实成为战斗宝可梦。不是完整比赛回放。可用 `--reference --battle-2d` 运行未改动的 2D 效果作参考。交付片包括正常速度和明确标注的 0.625 倍回看。

检查证据位于 `.tmp/boss-director-20260929/`：`red-character` 证明旧整卡方案缺少人物导演；`green-hd` 检查新手势、提交前展示保持、快进、真实换位、外部 cut-in 清理以及原集合路径；`windows-final.json` 是实际 Windows 渲染器检查；`regression-all` 覆盖相关展示、平台、手牌事件、招式和 2D 老大。另运行 2D 资源隔离检查。最终精确结果见该目录的 `acceptance.json`。

回滚只撤销本次 owner 改动：`ArenaSupporterVfx` 的 boss 分流、`ArenaMotionDirector` 的每效果时长查询、`ArenaWorld` 的镜头偏移/展示层引用、`ArenaBattlePresenter` 的展示层绑定。删除新增的两个 BossOrders 渲染脚本及其新素材。先与 `.tmp/boss-director-20260929/before/` 对比，保留后续及其他任务的改动，不用整文件覆盖。无需回滚规则、牌库、云端或 2D VFX。
