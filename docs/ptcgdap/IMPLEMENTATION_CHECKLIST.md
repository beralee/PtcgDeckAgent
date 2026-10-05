# PtcgDAP public implementation checklist

2026-10-04 大钢蛇空过复发：[x] 0.29 完整场景复现一报错一空过；[x] 两种预测模式共用缺目录可用性规则；[x] 双方前后场/未知 UID/重排/Base/隐私/旧计划清理回归；[x] 原包二维/三维八场景真实出牌→攻击→奖赏/玩家输入流程；[ ] 导出客户端、整局对战胜率（未声明）。见 [复发修复](../evidence/ptcgdap/developer_ai_damage_catalog_gap_20260928.md)。

2026-10-04 多龙漏攻击：[x] 验证原盘 453 条录像见证链并定位两次超时；[x] 后台调度/回收共享选择状态摘要；[x] 六次计数、重排和真实过期 RED→GREEN；[x] 原盘第 6/8 回合完整场景的实际后台策略 200+60 结算；[ ] 整局重赛与导出客户端发行（本次不声明）。见 [指示物状态](author-public-counter-state.md)。

2026-10-03 开战补充：[x] 多龙 0.29/0.23 精确开发包 Windows 登记；[x] 异步准备不将 metadata 冒充市场 ready；[x] 拒绝原因在列表/详情/导入结果可见；[x] 0.29 原包实际安装→异步准备→真实引擎绑定；[ ] 导出客户端发行与整局胜率复验（本次不声明）。见 [运行兼容性](strategy-runtime-compatibility.md)。

2026-10-03：策略运行时兼容性修复与 Windows 0.6.3 / build 63 版本边界，见 [兼容性与验收](strategy-runtime-compatibility.md)。

2026-10-03 expert feedback 0.1.1：[x] 目标/顺序/取舍/条件提示与不覆盖模板；[x] 自动暂存及同 attempt 恢复；[x] 固定保存区与键盘高度回归；[x] 输入法收尾及重复提交门；[ ] ARM 真机软键盘完整验收。设备证据随独立更新包记录。

0.1.1 交付追加：[x] 全局触摸兜底让出专家弹窗；[x] 恢复 JSON 整数类型并拒绝小数；[x] 13 + 37 项回归；[x] 最终 Android APK 与导出回读；[x] 两条旧标注载荷摘要不变；[x] Google CLI 上传及云端 MD5/大小核验。最终摘要 `ae753882119b862fb6eecdd07de80a8a49f46a9e5fb104b7e2c3babac03ab57d`，Forge `work/dragapult-expert-save-20261003/RESULTS.md` 记录已知边界。

2026-10-03 专家共创：[x] 675701 精确牌源与 36 局面；[x] 公开记录与隐私边界；[x] 本地草稿/提交与系统文件导出；[x] 新模式及旧训练回归；[ ] 统一人类当前窗口/Host 训练资格；[ ] 专家样本复核、学习和独立胜率验收。Android 与 Drive 回执见 Forge `work/dragapult-expert-play-20261003/`。

2026-09-30 卡牌内容更新（active / local）：[x] 协议/签名/增量构建；[x] 启动挂载与回退；[x] 卡牌目录与图片缓存优先级；[x] 玩家更新面板；[x] 维护者上传/发布/回退 CLI；[x] 冻结 Windows EXE 和 Android 模拟器 APK 验证；[ ] 生产发布及 ARM 真机/Web 验收。见 [证据与操作](card-content-updates.md)。

2026-09-25: Applied the user-reviewed author public attack-cost repair and added
a discovered seven-test / 45-situation regression suite. Applied-source probe
passes 45/45 and the cost / competitive / privacy suites pass 7/7, 19/19, 5/5;
44 local developer-only match executions also pass cleanly, with 4,881/4,881
successful policy calls; strength promotion remains unproven.
[Scope and rollback](author-public-attack-cost.md).

2026-09-20: Corrected 675700's three Snorunt to CSV9.5C/043, including exact
legacy seed migration and generated seed revision. The 101 discovered catalog,
seed and printing tests pass; newer player choices remain protected. See
[printing correction](marnie185-snorunt-printing-correction.md).

2026-09-20: Local-author Munkidori source/count/target routing is covered by
RED→GREEN engine tests and 68 passing related regressions. The resolver uses
the existing sequential-window capability; this does not grant production,
device, CABT parity, or ladder-strength acceptance. See
[local counter-window validation](local-author-counter-windows.md).

2026-09-19: Complete 1,011-card developer catalog refresh and source-delivery checks; see [71](71-developer-card-catalog-refresh.md). Server deployment remains a separate acceptance claim.

## Contract boundary

- [x] Policy accepts only raw/public observation data.
- [x] Policy returns indexes into the current immutable select window.
- [x] Accepted selections invalidate stale bindings.
- [x] Hidden information is excluded by allow-list projection.
- [x] Deterministic legal fallback remains local.

## Host and packaging

- [x] Python is retained for development/reference work.
- [x] GDScript is the portable player-runtime baseline.
- [x] Author `.ptcgai` packages have explicit identity and signature contracts.
- [x] PC/Android execution has no hosted inference prerequisite.
- [x] Windows battle setup presents classic AI and author packages through one
  scrollable AI-opponent picker without collapsing their runtime owners.
- [x] Large author-package catalogs cannot displace built-in 18.0 opponents
  from the bounded, searchable picker.

## Validation

- [x] Public damage registry matches the full bundled catalog and generated
  source; anniversary-card acceptance and unknown/hidden-input rejection are
  covered by focused Python regressions (2026-09-20).

- [x] Interface and cross-runtime conformance are reported separately.
- [x] Engine parity claims are scoped and evidence-backed.
- [x] Rollback paths remain explicit.
- [x] Native Android x86_64 emulator and Windows exports pass twelve paired
  full matches with exact package/public-window/model-adjudication comparison.
- [x] Local regression tooling preserves failure evidence and searchable
  decision review, checks native ABI/dependencies, and detects shutdown crashes.
- [ ] Complete the remaining product-approved Android device acceptance gate.

## Confidential infrastructure split

- [x] Control, Battle Bot and database implementations moved out of the public
  worktree.
- [x] Cloud deployment tools, operational documents and release artifacts moved
  with their owner.
- [x] Public/private dependency direction is one-way: private may consume the
  public runtime; public may not import private implementation.
- [x] Automated boundary checks prevent accidental reintroduction.
