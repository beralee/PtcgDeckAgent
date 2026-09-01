# D158 作者策略玩家对局热路径证据（2026-08-28）

## 结论

本工作包在 Godot Windows 本地玩家路径完成四项合同：作者默认实时节奏、默认精简记录、动作先进入动画队列、native/author 日志按决策边界批量落盘。它不改变策略、合法窗口、公开信息防火墙、engine execution ticket 或回放 schema authority。

## 进程清理

- 已终止 4 组 `a3_godot_headless_bridge`：`42972/51552`、`57840/27312`、`56916/39564`、`43140/23124`（console wrapper/main 共 8 个进程）。
- fresh CIM 复核 `Name like Godot* && CommandLine contains a3_godot_headless_bridge` 为 0。
- PID `59868` 与 `89948` 为无该 marker 的编辑器/项目实例，未终止。

## 既有对局观测

来源：`user://match_records/match_20260827_234816_561101`，只读取本机既有诊断文件。

- `detail.jsonl`：514 行，24,104,029 bytes。
- `state_snapshot`：253 行，约 17,868,467 bytes，平均 70,624.35 字符。
- `developer_decisions.jsonl`：79 个 decision record、87 个 owner-step witness，共 166 行、1,268,343 bytes。
- policy latency：总计 2,593.971 ms，平均 32.835 ms，p50 32.837 ms，p95 43.811 ms，最大 47.729 ms；77/79 超过 16.7 ms，37/79 超过 33.3 ms。
- 旧玩家节奏另固定等待 2 秒/AI action；native detail、integrity chain、summary 与作者日志均在主线程逐条强制 flush，且作者证据/公开回放采样发生在动画捕获之前。因此推理耗时是次要因素，固定节奏与同步记录放大是主要可控因素。

## 已实现合同

- `author_realtime_v1`：0.12 秒 action pause、1.5x visual playback；只在作者模式默认启用。
- `player_compact_v1`：保留 public match evidence/community replay，关闭冗余 developer trace，public replay 由逐 action 改为逐 owner decision boundary。
- 动画优先：`_on_action_logged` 先调用 `_enqueue_battle_visual_action(action)`，再执行作者/回放/native 诊断。
- native batch：精简档按 owner step flush，8 event 或 512 KiB 强制提前 flush；detail、chain、summary 保持有序，partial integrity manifest 每批更新。
- author batch：match evidence 和完整开发 trace 均按 owner step flush；精简档 native manifest 明示 developer trace 为 `disabled_by_recording_profile`。
- 审计身份：native runtime identity 写入 `live_pacing_profile_id` 与 `author_recording_profile_id`。

## 回滚

仅影响下一局，不热切当前 episode：

```text
PTCGDAP_LIVE_PACING_PROFILE=cinematic_v1
PTCGDAP_AUTHOR_RECORDING_PROFILE=developer_full_v1
```

该组合恢复旧 2 秒/1x、逐 action public replay、完整 developer trace 与 immediate native writer。既有录像、用户策略包和历史证据不删除。

## 验证结果

- `AuthorLivePerformanceContract`：5/5。
- `BattleRecorder`：12/12。
- `AuthorMatchEvidence`：1/1。
- `AuthorLivePublicReplay`：7/7。
- `BattleVisualSequenceController`：14/14。
- `AuthorStrategyDeveloperDecisionTrace`：writer/privacy/native-manifest 3/3 通过；2 个真实作者包用例在进入本工作包路径前返回 `package_integrity_invalid`。
- 扩展 `AuthorStrategyWindowsPlayerOwner` 为 7/18；11 项均处于同一既存 exact-package/materialization 基线及其级联，不用于本门豁免。

没有运行训练、benchmark/replay Python pool，也没有修改外部只读 `D:\ai\code\ptcgabc`。

## 已知缺口与 alignment

由于作者包完整性基线未修复，本轮没有生成一盘修复后的完整可见作者对局，也没有给出新的实机 frame-time/p95 数值。当前达到 `local Godot Windows author-player hot-path contract`；Android/A5、production、official CABT/Kaggle、full-engine parity 与策略强度均未提升。
