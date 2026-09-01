# PTCG 18.0 五套作者策略包交付

日期：2026-08-23

## 结论

以下五套牌已按 PTCG Strategy Forge 的 data-only 合同生成真实 `.ptcgai`，并复制到本地游戏内置作者包目录。每个包都绑定精确 60 卡 Windows-local 牌表、逐 printing 来源哈希、受限 Base Graph IR、牌组专用 adapter、完整策略蓝图和标准十场景证明矩阵。

| 牌组 | package_id | deck ID | 规则 | SHA-256 |
|---|---|---:|---:|---|
| 玛俐长毛巨魔 | `dev.beralee.v18.marnie-grimmsnarl` | 800018501 | 12 | `60D0DBFED01230D524A3FFB173C152B0A1F4FDF2E6926614DBABB9ED57ED6316` |
| 无碟沙奈朵 | `dev.beralee.v18.no-balloon-gardevoir` | 800017097 | 12 | `FC2245D12044CE0ED92E877ACDA006A2DBD6F406FAE2573363D1C2EB7A69FB90` |
| 多龙巴鲁托 | `dev.beralee.v18.pure-dragapult` | 800018499 | 11 | `8CCA6A11C6F04D3267187112112244057ABCCB3073898BBE7027B264AE68D0D9` |
| 猛雷鼓厄诡椪 | `dev.beralee.v18.raging-bolt-ogerpon` | 800018509 | 89 + 10 count | `59FB9D35BAB8987B1156714E64FB488A90432A491D42FBF8F3076E4E823ABD76` |
| N 的索罗亚克 | `dev.beralee.v18.ns-zoroark` | 800018502 | 12 | `5ADE7B78A3F43E2537CE8E35FE73E1C63927C1EA0D15963EA5D98EC53664FBD0` |

游戏内置位置：`data/ptcgdap/author_strategy_packages/reviewed-*-1.0.0.ptcgai`。

Forge 开发工作区位于相邻 `ptcg-strategy-forge/work/` 下；每套包含 `STRATEGY-BLUEPRINT.md`、包源码、十个场景、验收报告和最终 archive。

## RED→GREEN 和 Forge 验收

- 首个非玛俐牌组在 `new --deck-id` 尚不存在时按预期 RED。
- 每套执行两次构建并比较 exact bytes/SHA-256。
- 五套均通过严格 Host 编译和精确 deck gate。
- 50/50 场景通过，覆盖主 macro、缺关键卡、错误目标、option 重排、mandatory、terminal、hard tier、veto、未知 UID 和隐藏字段拒绝。
- N 的索罗亚克首次负例命中了另一条合法莱希拉姆规则；将错误目标修正为同牌组、但不匹配任何 macro 的 UID 后 10/10 GREEN。该过程证明测试按语义检查而非只看固定 index。

## Godot 本地加载与执行证据

`tests/ptcgdap/godot/test_reviewed_author_strategy_packages.gd` 4/4 通过：

1. 本地 catalog 找到五个 exact package ID/version/archive SHA，开发门只放行内置来源。
2. 五个包分别编译 sealed policy documents，并在公开当前窗口命中各自主 macro。
3. 五套精确游戏牌组都能绑定 `ReviewedAuthorStrategyDevelopmentBattleOwner`；经典 raw-state fallback 未参与。
4. BattleSetup 逐包显示“已加载 · 可开战”，开始时仍重新验证 archive、deck 和 handle。

既有 `test_author_strategy_battle_setup.gd` 10/10、`test_author_strategy_windows_player_owner.gd` 14/14 通过，原玛俐和 Cynthia 封存路径未被替换。

## 运行边界

这些包已达到 Windows 本地 Godot development execution：设备本地、无系统 Python、无网络、policy 只接收公开 primitive frame 并只返回当前窗口 indexes。Base 继续拥有 legality、mandatory/terminal、hard tier、veto、fallback 和最终裁决。

玛俐、沙奈朵、多龙和 N 的索罗亚克仍是原 restricted IR v1 交付；猛雷鼓已升级为 Competitive Policy IR v2 Round 3。v2 保持 `agent(raw_observation) -> list[int]` 不变，并已在真实 Godot Host 执行精确子集、逐次目标分配、公开目标能量/ready/debt、奖赏时钟和投影伤害；完整架构与证据见 `docs/ptcgdap/30-competitive-author-policy-v2.md`。

猛雷鼓最终同种子 100 局对经典 GDScript 为 37–63（Round 0 为 8–92，提升 29pp），5784/5784 policy success、4085 engine commits、0 error/invalid/rejection/fallback。该结果达到架构有效性门，但尚未证明与经典策略非劣；当前 development audit runtime 平均每次决策约 0.82 秒，性能也未达到内置 GDScript 水平。

这仍不是 production approval、Android/A5 或官方 CABT engine parity。任意跨窗口条件图和未知公开派生继续 fail closed，未被蓝图文字伪装成运行行为。

## 回滚

- 当前比赛不热换 owner 或 archive。
- 新比赛可通过关闭作者策略 feature gate 或删除这五条 exact development candidate 禁止启动。
- 回滚不删除开发者包和工作区；production gate 保持关闭。
