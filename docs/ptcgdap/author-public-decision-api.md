# Author public decision API v1

2026-09-30 本地补丁，基于 53cc7f86cb2048827ae29dc510494ded92ceb48c；不代表生产部署。

`PtcgDAPAuthorDevelopmentBattleOwner` 在 Competitive public_state 增加可选闭合 `decision` v1。包含 current/first player、双方首回合/VSTAR/上一对手回合被击倒/放逐区/后排容量、竞技场与回合预算、显式 interaction 预算与限制，以及按 entity_serial 关联的状态、登场/进化、撤退、工具/能力关闭、通用能力使用记录、逐张能量实际类型/单位及逐印刷招式费用。

HP 字段统一采用 EffectProcessor effective remaining HP。原 slot.damage_counters 单位是 HP 点数；option.target_pending_damage_counters 单位是 10 HP 指示物，不改变实际 HP。新逐招式 energy_ready 是当前真实附着费用满足，不是当前合法出招或未来换位后的保证。授予招式仍通过当前 option 的既有来源身份查询。

`scripts/ai/ptcgdap/public_decision_facts.py` 定义公共 schema、160 个 fact 的类型、校验和 Python 求值；`public/PublicDecisionFacts.gd` 镜像相同闭合格式，CompetitivePolicyV2 普通和缓存路径均接入。未知字段/枚举/错误实体连接拒绝，旧 frame 缺少扩展则新事实为 null。selection 限制只投影引擎明确提供的值；不会添加猜测默认。

合同通过 `tools/ptcgdap/build_competitive_policy_v2_contract.py` 生成并更新固定加载器摘要；Forge 复制同字节的事实模块和 contract extension，保留各自解释器版本，重新生成各自合同。Forge 根 SDK 的 PublicDecisionView 提供不可变查询与当前选项语义重绑定。只返回当前 options 索引的动作边界不变。

没有开放隐藏手牌/牌库序/奖赏身份/私有 RNG/原始 effects/引擎对象。没有宣称任意未来局面或任意目标完整伤害/奖赏模拟。当前合法性仍以合法窗口为准，Base 保留必选、终结、硬优先级和否决。

测试：`tests/ptcgdap/godot/test_author_public_decision_api.gd`、`test_competitive_policy_v2.gd`、`tests/test_author_public_counter_state.gd`。证据、完整能力审计和回滚清单在 Forge `work/public-decision-api-20260930` 及 `docs/38-PUBLIC-DECISION-API-AUDIT.md`。未提交、未推送、未部署、未上传天梯。

后续多龙 0.12.0 本地迭代新增派生整数事实 `decision.option.counter_prize_plan`（共 161 facts）。它以公开 counter 字段与对手场上身份/HP/奖赏的严格连接为输入，不要求 decision 块；支持 13/14、1—6 个预算、至多 9 个不同目标，无显式每目标限额。枚举击倒子集，按当前奖赏算术、击倒数、节省预算择优，余量集中到未足量分配的低 HP 目标。每窗重算，缺失/不匹配/超范围返回 null，不推断免疫或未来伤害。Python 与 Godot 共享 7 个新增向量，真实幻影潜袭原生回归见证 2+2+2 的结算；这不等同整局胜率或生产资格。Forge 候选及 Bench 状态见 `work/dragapult-api-20260930`。
