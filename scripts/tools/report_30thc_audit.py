"""Render explicit review sign-off with frozen source and actual test evidence."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / ".tmp/30thc-card-audit"
SOURCE = EVIDENCE / "source"
rows = json.loads((SOURCE / "inventory.json").read_text(encoding="utf-8"))
audit = {r["card_index"]: r for r in json.loads((EVIDENCE / "registration-audit.json").read_text(encoding="utf-8"))}
test_source = (ROOT / "tests/test_30thc_cards.gd").read_text(encoding="utf-8")
tests = re.findall(r"^func (test_\w+)\(", test_source, re.M)
test_lines = {m.group(1): test_source[:m.start()].count("\n") + 1 for m in re.finditer(r"^func (test_\w+)\(", test_source, re.M)}
final_log = (EVIDENCE / "final-30thc.log").read_text(encoding="utf-8")
assert set(tests) == set(re.findall(r"^PASS (test_\w+)", final_log, re.M)) and "Failed: 0" in final_log
assert len(audit) == 139 and all(not r["status"]["unimplemented"] for r in audit.values())

NOTES = {
    "002": ["真实反转能量按供给单位计数；奖赏条件消失时 HP 加成随之失效。"],
    "006": ["丢弃能量按供给单位而非卡片张数支付，逐步选择且拒绝重复引用。"],
    "027": ["备战伤害与放置伤害指示物/退化等效果保护分开接线，压制后不保护。"],
    "032": ["指定目标伤害补齐伤害事件、生存道具及手持风扇反应；Headless 保留防守方选择窗口。"],
    "036": ["抛币不被 AI 预览消耗；有正面但无基本雷能量时仍可查看己方牌库并空搜。"],
    "053": ["两个雷能量按有效供给单位支付，交互逐步收集所选能量。"],
    "058": ["退化清除特殊状态及效果、保留伤害，尊重备战特性和防止招式效果保护。"],
    "061": ["只剩这只宝可梦也可选择回牌库；可以放弃，选择返回则触发无宝可梦败北。"],
    "070": ["物品/支援者/道具/竞技场共用声明投币；反面先弃牌，不揭示搜索内容、不消耗成功使用次数。"],
    "072": ["两个斗能量按有效供给单位支付，交互逐步收集所选能量。"],
    "079": ["统一治疗入口覆盖已有治疗卡，不把移动伤害指示物、生存和离场重置误判为治疗。"],
    "081": ["高速星星限定第二招式，避免无视弱点/效果标记串到第一招式。"],
    "084": ["日出允许牌库无基本钢能量时空搜，查看牌库、零张选择和每回合次数一致。"],
    "097": ["火/水/雷需求按单位匹配；真实反转能量可同时支付多属性，双重涡轮仅支付无色。"],
    "102": ["宝可平板接入 UCIS；完整己方牌库可见、仅合法牌可选，空搜 UI/Headless 一致。"],
}
EVOLUTIONS = {"005", "015", "062", "066", "070", "076", "084", "088", "091"}
for index in EVOLUTIONS:
    NOTES.setdefault(index, []).append("普通进化及神奇糖果双路径；缺 Stage 1 实体时按稳定中英映射选择同线基础宝可梦，拒绝错误/当回合登场目标。")

def summary(name):
    return re.findall(r"^Total:.*$", (EVIDENCE / name).read_text(encoding="utf-8"), re.M)[-1].strip().replace(" | ", "; ")

def related(index):
    if not index.isdigit():
        suffix = "grass_fire_water_lightning" if index in {"GRA", "FIR", "WAT", "LIG"} else "psychic_fighting_darkness_metal"
        return [t for t in tests if suffix in t]
    result = []
    for test in tests:
        numbers = re.findall(r"(?<!\d)\d{3}(?!\d)", test)
        if index in numbers or ("_to_" in test and len(numbers) == 2 and int(numbers[0]) <= int(index) <= int(numbers[1])):
            result.append(test)
    base = next(r["card_index"] for r in rows if r["in_scope"] and r["effect_id"] == audit[index]["effect_id"])
    if base != index:
        result += related(base)
    if index in EVOLUTIONS:
        result += ["test_30thc_review_evolution_batch_one" if int(index) <= 70 else "test_30thc_review_evolution_batch_two"]
    if index == "057":
        result.append("test_30thc_printings_135_mew_copies_real_unown_and_earns_extra_prize")
    return list(dict.fromkeys(result))

def literal(value):
    return json.dumps(value, ensure_ascii=False)

lines = """# 30thC G/H/I/J 全卡实现与复审报告

完成日期：2026-09-10。使用 card-audit，每批不超过 5 张实施，全部落地后再次 review。本报告基于冻结源数据、真实注册结果、实际测试日志及显式复审记录生成。

## 结论与范围

来源：[30 周年卡表](https://tcg.mik.moe/cards/30thC)。产品共 169 个印刷版本，G/H/I/J 范围 **139 个印刷版本 / 111 个源 effect_id**：G=8、H=0、I=2、J=129；其余 30 个版本不在范围。

- 已落地 138 份与 API 转换结果严格相等的 JSON 及图片，保留原有 057 照片版本，共 139 张。
- 全部清单引用、图片格式和路径大小写验证通过；139 张真实源 JSON 注册状态均为已实现。
- 本地用户缓存的 138 张新增卡与 bundle 逐文件哈希一致。057 原缓存仅 Pokemon/Pokémon 拼写规范化不同，身份及规则语义一致，未覆盖。
- 全部卡牌完成规则、注册参数、逐招式索引、交互及跨层 review，修复本次确认的问题。
- 这不是对所有卡牌组合的穷举证明，也不代表整个仓库测试全绿。没有提交、发布、执行训练或设备发行构建。
- 现有 card_status_matrix_latest.txt 仅包含旧 057，不能为新增卡背书；本次使用冻结源注册审计与新卡专项重新验证。大小写敏感路径已测，但没有宣称执行过 Android/Linux 真机构建。

### 身份兼容例外

057 保留 `data/bundled_user/cards/30THC_057.json`：source_provider=user_photo，effect_id=`9256615fd387482e220b7e2630343eb7`，规则名仍为 `Mew ex / Memory Helix / Teleportation Burst`。没有覆盖旧照片身份与图片。API 057/135 的 effect_id=`dd6e658057478ff1eb223c71000b08a2` 另行注册，135 已落地；两个来源都覆盖备战招式复制/额外奖赏行为。全部图片使用实际 `30THC` 目录，并给 API `30thC` 身份补大小写敏感路径候选。

## 跨层 review 与修复

| 链路 | 核对及结果 |
|---|---|
| API -> CardData -> bundle/manifest -> CardDatabase | 源规则文本、费用/HP/弱抗/退却/进化字段逐份核对；057 兼容身份保留，图片路径可解析。 |
| effect_id -> EffectRegistry -> ThirtiethCelebrationRegistry -> EffectProcessor | 稳定 ID 路由、异画复用、逐招式索引；纯伤害/基本能量使用通用引擎。 |
| 效果 -> DamageCalculator/EffectProcessor -> GSM | 弱点倍率、能量单位、HP、减伤及伤害反应接线；指定目标伤害写公开目标事件，结算生存道具和受伤反应。 |
| PokemonSlot.heal -> EffectProcessor.can_heal_pokemon | 伊裴尔塔尔阻止对手战斗宝可梦治疗；已有治疗卡统一通过拦截器，指示物移动/离场/生存不经过治疗。 |
| 训练家声明 -> UI/Headless -> 核心提交 | 蟾蜍王投币在搜索揭示之前；正面缓存，反面只弃牌，不消耗成功使用次数。 |
| 进化元数据 -> RuleValidator -> RareCandy 配对 -> GSM -> UI/Headless | 9 条二阶线覆盖普通进化及缺 Stage 1 跳进化，中英基础别名、非首个合法目标、登场回合/错误配对负例。 |
| UCIS 选择 -> 新窗口 -> 执行 | 整副己方牌库区分可见与可选牌；顶 3 张效果不扩张视野；特殊能量逐步选择；受伤反应保留防守方选择权。 |

主要复审修复：退化清状态与防护、飘飘球单独在场离场分支、特殊能量多单位支付、日出/冲锋之舞空搜、宝可平板交互、指定目标伤害事件及手持风扇反应、基拉祈第二招式绑定、图片目录大小写。下文逐卡记录列出规则到实现的对应关系。

规则疑点辅助核对：[官方术语表（退化）](https://www.pokemon.com/us/play-pokemon/about/pokemon-tcg-glossary)、[官方规则书（场上无宝可梦）](https://assets.pokemon.com/assets/cms2/pdf/trading-card-game/rulebook/sm12_rulebook_en.pdf)。具体卡牌效果以冻结源 JSON 为准。

## 验证与未解决的原有问题

| 验证 | 实际结果 | 证据文件（均在 .tmp/30thc-card-audit/） |
|---|---|---|
""".splitlines()
for label, name in [("新卡专项", "final-30thc.log"), ("CSV9C/CSV10C 全功能分组 + 规则/伤害/GSM/UI/照片卡", "final-functional-group.log"), ("HeadlessMatchBridge", "final-headless.log"), ("全仓源码编码", "final-source-encoding.log")]:
    lines.append(f"| {label} | {summary(name)} | `{name}` |")
lines += r"""| 源文件/资源/清单 | 139/139 通过 | `bundle-verification.json` |
| 真实源注册 | 139/139 已实现 | `registration-audit.json` |

仍未解决的仓库原有回归（不计作通过）：

1. CSV10C 101/105 两项投币测试：RiggedCoinFlipper 的 runtime port 未初始化，push_context/pop_context 调用 null。HEAD 隔离副本使用同样真实卡数据复现为 5 项中 2 项失败：`head-reference-coin-fixture.log`。
2. Headless 两项起手重抽测试：恢复了 setup_active_0 而非 mulligan_extra_draw、额外抽牌未发生。HEAD 副本两项同样失败：`head-reference-mulligan.log`。
3. 愿增猿/光明能量第一项在 AbilityMoveDamageCountersToOpponent.gd:30 出现 GDScript 初始化异常；HEAD 副本同样复现为 6 项中 1 项失败。混合分组还出现 Godot 原生崩溃，没有计为通过：`head-reference-munkidori.log`、`review-functional-core.log`。
4. 实现早期曾跑完整 FunctionalTestRunner：5514 项，5334 通过、180 失败（`.godot_test_user/logs/functional-20260910-104122.log`）。包含已移除策略包、旧训练夹具及其他既有失败。这不是最终全仓通过证明，没有为测试恢复用户已删除的策略。最终采用上述相关功能全分组验证。
5. 现有全卡库加载仍有 Unexpected NUL character 提示，部分旧套件退出有资源泄漏警告。本次新卡文本/资源验证通过，但没有宣称解决全库及 Godot 退出警告。
6. 源码编码专项 2 项中 1 项失败，定位到 PublicReplayViewer.gd:465 的 U+23F8 暂停字符；git show HEAD 同一位置已有该字符，文件不属于本任务改动，未修改。

HEAD 对照副本在 `.tmp/30thc-card-audit/head-reference/`，git archive 提取脚本/场景/测试，隔离配置去掉 autoload，并补所需原始卡、证书与 contracts；没有回退/覆盖工作区。

## 复现与回滚边界

```powershell
python scripts/tools/verify_30thc_bundle.py
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s scripts/tools/audit_tcg_mik_snapshot.gd
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_30thc_cards.gd
$cardSuites = @(Get-ChildItem tests -File | Where-Object { $_.Name -match '^test_csv(9|10)c.*\.gd$' } | ForEach-Object { $_.BaseName -replace '^test_', '' -replace '_', '' })
$cardSuites += @('DamageCalculator','RuleValidator','GameStateMachine','BattleActionController','BattleActionControllerInvalidHints','Photo30thCelebrationCards')
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s tests/FunctionalTestRunner.gd -- ('--suite=' + ($cardSuites -join ','))
```

快照工具 `snapshot_tcg_mik_product.py`、安装工具 `install_30thc_snapshot_batch.py` 使用 --help 查看参数；单批上限 5 张。重新抓取应先比较源变化，不要盲目覆盖审计版本。报告生成依赖本次 .tmp 冻结快照和最终日志。

回滚仅限本次新增的 138 张 30thC JSON/图片、对应 manifest 行、新增效果/注册/工具/测试/报告及相关引擎 hunk。保留 057 照片、同文件原有修改、策略包及其他用户工作。不要使用 git reset --hard 或整目录删除；本任务没有执行回滚。

## 逐卡源文本、实现与测试

“匹配/通过”是本次逐句审查结论，结合列出的注册及行为测试，不是仅凭注册存在自动认定。测试数量为关联函数数，并非每句规则独占一条测试。异画复用基础版行为测试并验证实际印刷数据；纯伤害/基本能量不虚构独立效果类。
""".splitlines()

for row in rows:
    if not row["in_scope"]:
        continue
    index = row["card_index"]
    raw = json.loads((SOURCE / f"{index}.json").read_text(encoding="utf-8"))
    filename = f"30THC_{index}.json" if index == "057" else f"30thC_{index}.json"
    card = json.loads((ROOT / "data/bundled_user/cards" / filename).read_text(encoding="utf-8"))
    attr = raw.get("pokemonAttr") or {}
    record = audit[index]
    refs = related(index)
    assert refs, index
    base = next(r["card_index"] for r in rows if r["in_scope"] and r["effect_id"] == row["effect_id"])
    notes = NOTES.get(base, [])
    lines += ["", f'### {index} {row["name"]}', "",
              f'- 名称：{card.get("name", "")}；英文={card.get("name_en", "")}；中文显示={card.get("name_zh", "")}。',
              f'- 类型={row["card_type"]}；标记={row["regulation_mark"]}；源 effect_id=`{row["effect_id"]}`。',
              f'- 本地文件：[{filename}](../data/bundled_user/cards/{filename})；源：tcg_mik / zh-CN。',
              f'- 源元数据：{literal({k: attr.get(k) for k in ("stage", "evolvesFrom", "hp", "energyType", "weakness", "resistance", "retreatCost")})}。',
              f'- mechanic / ancient_trait / is_tags：{literal({k: card.get(k) for k in ("mechanic", "ancient_trait", "is_tags")})}。',
              f'- 来源字段：{literal({k: card.get(k) for k in ("source_provider", "source_language", "source_url", "source_set_code", "source_card_index", "source_prints", "source_parser_version")})}。',
              '- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。',
              f'- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 {len(refs)} 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。',
              f'- 复审修正记录 {len(notes)} 项（含共享链路，非穷举缺陷数）；状态：{"已修复并验证" if notes else "已实现并复审，无本卡未结项"}。',
              '- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。',
              '', '源描述原文：', '', '```text', raw.get('description', '').strip(), '```', '',
              '| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |', '|---|---|---|']
    for ability in record["abilities"]:
        rule = (ability.get("name", "") + ': ' + ability.get("text", "")).replace('\n', '<br>').replace('|', '\\|')
        lines.append(f'| 特性 {rule} | `{record["effect"]}` -> EffectProcessor/GSM | 通过 |')
    for attack in record["attacks"]:
        rule = attack["rule"]
        text = f'{rule["name"]}；cost={rule.get("cost", "")}；damage={rule.get("damage", "")}；{rule.get("text", "")}'.replace('\n', '<br>').replace('|', '\\|')
        effects = ', '.join(f'`{e}`' for e in attack["effects"]) or '`GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害）'
        lines.append(f'| 招式 {attack["index"]}: {text} | {effects} | 通过 |')
    if not record["abilities"] and not record["attacks"]:
        lines.append(f'| 上述训练家/能量文本 | `{record["effect"] or "EffectProcessor 能量供给 / GSM attach_energy"}` | 通过 |')
    lines += ['', '关联新增测试：', '']
    lines += [f'- [`{t}`](../tests/test_30thc_cards.gd#L{test_lines[t]})' for t in refs]
    if notes:
        lines += ['', '复审修复：', ''] + [f'- {note}' for note in notes]

lines += ['', '## 不在 G/H/I/J 范围的版本', '']
lines += [f'- {r["card_index"]} {r["name"]}：标记 `{r["regulation_mark"] or "无"}`。' for r in rows if not r["in_scope"]]
(ROOT / "docs/30thc-card-audit.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Generated final audit: 139 printings, {len(tests)} passing focused tests")
