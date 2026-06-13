class_name TestCSV9CUnder100RegistryEffects
extends TestBase


func test_csv9c_under100_effect_ids_register_required_hooks() -> String:
	var processor := EffectProcessor.new()
	var scripted_cards: Array[Dictionary] = [
		{"name": "蛋蛋", "effect_id": "80861b2bfa9967d1e28a97ee4d1f1316", "attacks": [_attack("早熟进化", "C", "")], "needs_attack": true},
		{"name": "铁蚁ex", "effect_id": "3a842d03df3719f7c72c2c0b48d7fd7d", "abilities": [_ability("突然切削")], "attacks": [_attack("复仇粉碎", "GCC", "120+")], "needs_effect": true, "needs_attack": true},
		{"name": "裹蜜虫", "effect_id": "7c7665c11f0e9d13ce39ee63c2f2d85c", "attacks": [_attack("涂层攻击", "G", "20")], "needs_attack": true},
		{"name": "蜜集大蛇ex", "effect_id": "e2114e7b76f6dbbe76ce0aaf2a65bc9c", "abilities": [_ability("熟成充能")], "attacks": [_attack("蜜糖风暴", "CC", "30+")], "needs_effect": true, "needs_attack": true},
		{"name": "凤王", "effect_id": "c155af5a80a873be25372736b49b5829", "attacks": [_attack("振翅", "RC", "50"), _attack("闪耀烈焰", "RRC", "100+")], "needs_attack": true},
		{"name": "比克提尼", "effect_id": "ae135beb7f4c42139fc38a4f9203db09", "abilities": [_ability("胜利声援")], "attacks": [_attack("火焰", "RC", "30")], "needs_effect": true},
		{"name": "苍炎刃鬼ex", "effect_id": "a533d02d029bd799e8c425beecd3ffaa", "attacks": [_attack("深渊炽火", "R", "30+"), _attack("紫水晶之怒", "RPM", "280")], "needs_attack": true},
		{"name": "丑丑鱼", "effect_id": "4b31ce3c692a0129980d3866878faeb5", "attacks": [_attack("抓狂", "W", "10x")], "needs_attack": true},
		{"name": "美纳斯", "effect_id": "88b2885578a73494f1eed7c2b53e67c7", "abilities": [_ability("平稳境地")], "attacks": [_attack("水炮飞溅", "WCC", "100")], "needs_effect": true},
		{"name": "古剑豹", "effect_id": "f518a7e573241c14cc225cc14d6094d3", "abilities": [_ability("埋入雪中")], "attacks": [_attack("冰柱环", "WWC", "120")], "needs_effect": true, "needs_attack": true},
		{"name": "皮卡丘ex", "effect_id": "cd845155473716c29f29efa29da0a869", "abilities": [_ability("顽强之心")], "attacks": [_attack("黄晶伏特", "GLM", "300")], "needs_effect": true, "needs_attack": true},
		{"name": "电电虫", "effect_id": "76ce94424f53e8a93cfb2c2008a84a86", "attacks": [_attack("电电充能", "C", "")], "needs_attack": true},
		{"name": "电蜘蛛ex", "effect_id": "cfe54f4650db054ec2eec6dfcaaff88a", "attacks": [_attack("冲天丝线", "LC", "110+"), _attack("雷击石", "GLF", "180")], "needs_attack": true},
		{"name": "呆呆兽", "effect_id": "ccc3bb652f886672fac7b4b0561492d9", "attacks": [_attack("垂尾", "C", ""), _attack("撞击", "PC", "30")], "needs_attack": true},
		{"name": "呆呆王", "effect_id": "79cbb7699c0e663c135524afe4e1cb14", "attacks": [_attack("灵感挑战", "PC", ""), _attack("超念力", "PPC", "120")], "needs_attack": true},
		{"name": "波克基古", "effect_id": "74fd967591e71b608b8437f28cdee910", "attacks": [_attack("吸取之吻", "CC", "30")], "needs_attack": true},
		{"name": "波克基斯", "effect_id": "019d762a760de48f1bb05528db2766f3", "abilities": [_ability("奇迹之吻")], "attacks": [_attack("高速之翼", "CCC", "140")], "needs_effect": true},
		{"name": "拉帝亚斯ex", "effect_id": "f8c2715403e3f4ea9783c46be2de832b", "abilities": [_ability("天际线")], "attacks": [_attack("无限之刃", "PPC", "200")], "needs_effect": true, "needs_attack": true},
		{"name": "仙子伊布ex", "effect_id": "317cdd81106733967d562ad538a7983a", "attacks": [_attack("魔法魅惑", "PCC", "160"), _attack("天使石", "WLP", "")], "needs_attack": true},
		{"name": "索财灵", "effect_id": "6c6c611ae3397c524ea28fec85c1f8b8", "attacks": [_attack("小使者", "C", ""), _attack("撞击", "CCC", "50")], "needs_attack": true},
		{"name": "猴怪", "effect_id": "20655f99bed441a33a259b16b9935355", "attacks": [_attack("二连劈", "C", "10x")], "needs_attack": true},
		{"name": "火暴猴", "effect_id": "5f360b6881fbb857e809ca402ffdfda4", "attacks": [_attack("扫堂腿", "F", "30"), _attack("百万吨重拳", "FC", "70")], "needs_attack": true},
		{"name": "弃世猴", "effect_id": "293b8c882a550600a395e3c82b58f833", "attacks": [_attack("暴走", "F", "130"), _attack("同命战斗", "FC", "")], "needs_attack": true},
	]
	var checks: Array[String] = []
	for spec: Dictionary in scripted_cards:
		var card := _pokemon(str(spec.get("name", "Basic")), "Basic", "", "C", 100, spec.get("attacks", []), spec.get("abilities", []), "", str(spec.get("effect_id", "")))
		processor.register_pokemon_card(card)
		if bool(spec.get("needs_effect", false)):
			checks.append(assert_true(processor.has_effect(card.effect_id), "%s should register a native Ability/effect" % card.name))
		if bool(spec.get("needs_attack", false)):
			checks.append(assert_true(processor.has_attack_effect(card.effect_id), "%s should register native attack effects" % card.name))

	var numeric_only_cards: Array[CardData] = [
		_pokemon("啃果虫", "Basic", "", "G", 40, [_attack("汁液喷吐", "G", "20")], [], "", "7cffba962d26fc020fa7a823c71157db"),
		_pokemon("炭小侍", "Basic", "", "R", 70, [_attack("磷火", "R", "20")], [], "", "975fec278b4ac548e0afd3ed538cb85d"),
		_pokemon("波克比", "Basic", "", "C", 50, [_attack("拍击", "CC", "30")], [], "", "8c8dbf6bb67e8c8d393f42ed9aead1bf"),
	]
	for card: CardData in numeric_only_cards:
		processor.register_pokemon_card(card)
		checks.append(assert_false(processor.has_effect(card.effect_id), "%s should not need a native Ability/effect" % card.name))
		checks.append(assert_false(processor.has_attack_effect(card.effect_id), "%s should not need a native attack effect" % card.name))
	return run_checks(checks)


func test_csv9c_remote_pokemon_effect_id_aliases_register_required_hooks() -> String:
	var processor := EffectProcessor.new()
	var scripted_cards: Array[Dictionary] = [
		{"remote": "6b6641a24bd64c822e7ca22834562305", "needs_attack": true},
		{"remote": "6c353de6662e532e4c46e3cfae7dfa2f", "needs_effect": true, "needs_attack": true},
		{"remote": "408e35f7f658381ad43783473e50049e", "needs_attack": true},
		{"remote": "30c0f190345a6b72ddf9df7726842de2", "needs_effect": true, "needs_attack": true},
		{"remote": "178c0eaa413487309e4bb17d0a495039", "needs_attack": true},
		{"remote": "6c64991ff0cfcc9656603347504deab7", "needs_effect": true},
		{"remote": "92770a887520f6c4528cf57ae82392b3", "needs_attack": true},
		{"remote": "5185ad3335c161ab7b0714d053721e9d", "needs_attack": true},
		{"remote": "57aa4d41e927a2f1cdf846f73509b907", "needs_effect": true},
		{"remote": "398c5e37a64e8f0184c7634bb63a511c", "needs_effect": true, "needs_attack": true},
		{"remote": "689549e631f4f93ecf618a215c628bd1", "needs_effect": true, "needs_attack": true},
		{"remote": "36d024ba3147200b7a179519b1eb4992", "needs_attack": true},
		{"remote": "27d1eb5f7abc237f462328c2ff00fdf3", "needs_attack": true},
		{"remote": "b081eea7ec634b2aad300056bd7b3fe6", "needs_attack": true},
		{"remote": "59d3af627f14b4a65ab4d589f6cb52db", "needs_attack": true},
		{"remote": "a8d69abb427e7a074497b66db3f524fb", "needs_attack": true},
		{"remote": "0730af1743d1604c0fdd734359ec239b", "needs_effect": true},
		{"remote": "a92ab1fcfe663d2a56b267a34307fad4", "needs_effect": true, "needs_attack": true},
		{"remote": "61fb0755be18f5fcdc6a30781d5fc05e", "needs_attack": true},
		{"remote": "7f156dbd62a95fd428ab7a9ea4b8b89d", "needs_attack": true},
		{"remote": "c4ced8d2c2f4129b58fd469712e4d838", "needs_attack": true},
		{"remote": "db85afb351bf456c9f6c1ed236ca5457", "needs_attack": true},
		{"remote": "293b8c882a550600a395e3c82b58f833", "needs_attack": true},
		{"remote": "2a4c4317b6951f2ee8d0bf52c89614a3", "needs_attack": true},
		{"remote": "66377923675b93ec93a30c3411292d47", "needs_attack": true},
		{"remote": "9012c0df72a664cd90358d69ec41df45", "needs_attack": true},
		{"remote": "d193ab1a44b659f4dfbef13a3a6440f9", "needs_attack": true},
		{"remote": "62619a01b9dd1e1dec71d6f6557c9cb8", "needs_attack": true},
		{"remote": "5a1d0fbbb9c71b9ec99b31734560d4d1", "needs_effect": true, "needs_attack": true},
		{"remote": "cd6b5456da3f4e586959e20ca1b413a0", "needs_effect": true},
		{"remote": "e274ef5f7e7bb3915d46ace2f2a50dde", "needs_attack": true},
		{"remote": "cd4296af21eb61bd3078372aef79c6f8", "needs_effect": true, "needs_attack": true},
		{"remote": "03abed2436ae00ff738a55bc9758c63c", "needs_attack": true},
		{"remote": "c09bd406f26faeab1683244e53bab0b4", "needs_attack": true},
		{"remote": "35449fa64a627725e9f3129b6596b2a7", "needs_effect": true, "needs_attack": true},
		{"remote": "28b17de5f7b3d15229205c65f1173fb7", "needs_attack": true},
		{"remote": "ec0fdcc9700f2362e584d98dd2a88f88", "needs_effect": true, "needs_attack": true},
		{"remote": "3050727a9de336da69b1b7865ad2cf2d", "needs_attack": true},
		{"remote": "842bef708173f5e6e1186bfb25e35e38", "needs_effect": true},
		{"remote": "fff777c54e423cea55d217f6954f635c", "needs_effect": true, "needs_attack": true},
		{"remote": "80825120ec77d6da5fa04c2e5d73f115", "needs_effect": true, "needs_attack": true},
		{"remote": "5de19cbd4b2d1ff80ba14d6d89246ae9", "needs_attack": true},
	]
	var checks: Array[String] = []
	for spec: Dictionary in scripted_cards:
		var card := _pokemon("Remote CSV9C", "Basic", "", "C", 100, [_attack("Alias Attack", "C", "")], [_ability("Alias Ability")], "", str(spec["remote"]))
		processor.register_pokemon_card(card)
		if bool(spec.get("needs_effect", false)):
			checks.append(assert_true(processor.has_effect(card.effect_id), "%s should register a native Ability/effect alias" % card.effect_id))
		if bool(spec.get("needs_attack", false)):
			checks.append(assert_true(processor.has_attack_effect(card.effect_id), "%s should register native attack effect aliases" % card.effect_id))

	var numeric_only_cards: Array[CardData] = [
		_pokemon("Remote Applin", "Basic", "", "G", 40, [_attack("Acid Spray", "G", "20")], [], "", "ea16fe3d0ca185db9e37c8e3a2d88efc"),
		_pokemon("Remote Charcadet", "Basic", "", "R", 70, [_attack("Ember", "R", "20")], [], "", "990ee62469ff9c158e669543e6d93e00"),
		_pokemon("Remote Togepi", "Basic", "", "C", 50, [_attack("Pound", "CC", "30")], [], "", "1ff33aa784d1181c5e87ca96bab80ab3"),
	]
	for card: CardData in numeric_only_cards:
		processor.register_pokemon_card(card)
		checks.append(assert_false(processor.has_effect(card.effect_id), "%s should not need a native Ability/effect alias" % card.name))
		checks.append(assert_false(processor.has_attack_effect(card.effect_id), "%s should not need a native attack effect alias" % card.name))
	return run_checks(checks)


func test_csv9c_023_victini_registered_boost_only_applies_to_own_fire_evolution() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var victini_cd := _pokemon("比克提尼", "Basic", "", "R", 70, [_attack("火焰", "RC", "30")], [_ability("胜利声援")], "", "ae135beb7f4c42139fc38a4f9203db09")
	processor.register_pokemon_card(victini_cd)
	var victini := _slot(victini_cd, 0)
	state.players[0].bench.append(victini)
	var fire_evo := _slot(_pokemon("火进化", "Stage 1", "基础", "R", 120), 0)
	var fire_basic := _slot(_pokemon("火基础", "Basic", "", "R", 80), 0)
	var water_evo := _slot(_pokemon("水进化", "Stage 1", "基础", "W", 120), 0)

	state.players[0].active_pokemon = fire_evo
	var fire_evo_bonus := processor.get_attacker_modifier(fire_evo, state, state.players[1].active_pokemon)
	state.players[0].active_pokemon = fire_basic
	var fire_basic_bonus := processor.get_attacker_modifier(fire_basic, state, state.players[1].active_pokemon)
	state.players[0].active_pokemon = water_evo
	var water_evo_bonus := processor.get_attacker_modifier(water_evo, state, state.players[1].active_pokemon)
	state.players[0].active_pokemon = fire_evo
	victini.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	var disabled_bonus := processor.get_attacker_modifier(fire_evo, state, state.players[1].active_pokemon)

	return run_checks([
		assert_eq(fire_evo_bonus, 10, "Victini should add 10 only to own Fire Evolution Pokemon attacks"),
		assert_eq(fire_basic_bonus, 0, "Victini should not boost own Basic Fire Pokemon"),
		assert_eq(water_evo_bonus, 0, "Victini should not boost non-Fire Evolution Pokemon"),
		assert_eq(disabled_bonus, 0, "Victini boost should stop while its Ability is disabled"),
	])


func test_csv9c_064_galvantula_registered_attacks_apply_bonus_discard_and_item_lock() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var galv_cd := _pokemon("电蜘蛛ex", "Stage 1", "电电虫", "L", 260, [_attack("冲天丝线", "LC", "110+"), _attack("雷击石", "GLF", "180")], [], "ex", "cfe54f4650db054ec2eec6dfcaaff88a")
	processor.register_pokemon_card(galv_cd)
	var galv := _slot(galv_cd, 0)
	state.players[0].active_pokemon = galv
	state.players[1].active_pokemon.get_card_data().mechanic = "ex"
	var grass := CardInstance.create(_energy("草能量", "G"), 0)
	var lightning := CardInstance.create(_energy("雷能量", "L"), 0)
	galv.attached_energy.append_array([grass, lightning])

	var bonus := processor.get_attack_damage_modifier(galv, state.players[1].active_pokemon, galv_cd.attacks[0], state)
	processor.execute_attack_effect(galv, 1, state.players[1].active_pokemon, state)

	return run_checks([
		assert_eq(bonus, 110, "Galvantula ex first attack should add 110 against Pokemon ex/V"),
		assert_eq(galv.attached_energy.size(), 0, "Galvantula ex second attack should discard all attached Energy"),
		assert_true(grass in state.players[0].discard_pile, "Discarded Grass Energy should enter discard"),
		assert_true(lightning in state.players[0].discard_pile, "Discarded Lightning Energy should enter discard"),
		assert_eq(int(state.shared_turn_flags.get("item_lock_1", -1)), state.turn_number + 1, "Galvantula ex should item-lock the opponent next turn"),
	])


func test_csv9c_072_slowking_registered_inspiration_copies_top_deck_attack() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var slowking_cd := _pokemon("呆呆王", "Stage 1", "呆呆兽", "P", 120, [_attack("灵感挑战", "PC", ""), _attack("超念力", "PPC", "120")], [], "", "79cbb7699c0e663c135524afe4e1cb14")
	processor.register_pokemon_card(slowking_cd)
	var slowking := _slot(slowking_cd, 0)
	state.players[0].active_pokemon = slowking
	var copied_cd := _pokemon("复制目标", "Basic", "", "C", 80, [_attack("复制伤害", "C", "50")], [], "", "copy_target")
	var top_card := CardInstance.create(copied_cd, 0)
	state.players[0].deck.append(top_card)

	processor.execute_attack_effect(slowking, 0, state.players[1].active_pokemon, state)

	return run_checks([
		assert_true(top_card in state.players[0].discard_pile, "Slowking should discard the top deck Pokemon before copying"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 50, "Slowking should copy and deal the top Pokemon attack damage"),
	])


func test_csv9c_078_latias_registered_skyline_and_self_lock() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var latias_cd := _pokemon("拉帝亚斯ex", "Basic", "", "P", 210, [_attack("无限之刃", "PPC", "200")], [_ability("天际线")], "ex", "f8c2715403e3f4ea9783c46be2de832b")
	processor.register_pokemon_card(latias_cd)
	var latias := _slot(latias_cd, 0)
	state.players[0].bench.append(latias)
	var basic_active := state.players[0].active_pokemon
	basic_active.get_card_data().retreat_cost = 3
	var stage1_active := _slot(_pokemon("一阶宝可梦", "Stage 1", "基础", "C", 100, [], [], "", "stage1"), 0)
	stage1_active.get_card_data().retreat_cost = 2

	var basic_retreat := processor.get_effective_retreat_cost(basic_active, state)
	var stage1_retreat := processor.get_effective_retreat_cost(stage1_active, state)
	state.players[0].active_pokemon = latias
	state.players[0].bench.erase(latias)
	processor.execute_attack_effect(latias, 0, state.players[1].active_pokemon, state)

	return run_checks([
		assert_eq(basic_retreat, 0, "Latias ex should make own Basic Pokemon retreat for free"),
		assert_eq(stage1_retreat, 2, "Latias ex should not modify Evolution Pokemon retreat cost"),
		assert_true(latias.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == "attack_lock" and int(e.get("attack_index", -1)) == 0), "Latias ex attack should lock itself next own turn"),
	])


func test_csv9c_090_sylveon_registered_effects_reduce_damage_and_lock_angelite() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var sylveon_cd := _pokemon("仙子伊布ex", "Stage 1", "伊布", "P", 270, [_attack("魔法魅惑", "PCC", "160"), _attack("天使石", "WLP", "")], [], "ex", "317cdd81106733967d562ad538a7983a")
	processor.register_pokemon_card(sylveon_cd)
	var sylveon := _slot(sylveon_cd, 0)
	state.players[0].active_pokemon = sylveon
	var opponent := state.players[1]
	var bench_a := _slot(_pokemon("对手备战A", "Basic", "", "L", 80), 1)
	var bench_b := _slot(_pokemon("对手备战B", "Basic", "", "R", 80), 1)
	opponent.bench.append_array([bench_a, bench_b])

	processor.execute_attack_effect(sylveon, 0, opponent.active_pokemon, state)
	state.turn_number = 3
	state.current_player_index = 1
	var outgoing_modifier := processor.get_attacker_modifier(opponent.active_pokemon, state, sylveon)
	state.turn_number = 2
	state.current_player_index = 0
	processor.execute_attack_effect(sylveon, 1, opponent.active_pokemon, state, [{"csv9c_return_bench_to_deck": [bench_a, bench_b]}])
	state.turn_number = 4
	var locked := not RuleValidator.new().can_use_attack(state, 0, 1, processor)

	return run_checks([
		assert_eq(outgoing_modifier, -100, "Sylveon ex Magical Charm should reduce defender's next outgoing damage by 100"),
		assert_false(bench_a in opponent.bench, "Sylveon ex Angelite should remove the first selected Bench Pokemon"),
		assert_false(bench_b in opponent.bench, "Sylveon ex Angelite should remove the second selected Bench Pokemon"),
		assert_true(bench_a.get_top_card() in opponent.deck, "Sylveon ex Angelite should return selected cards to deck"),
		assert_true(locked, "Sylveon ex Angelite should be unusable on the next own turn after use"),
	])


func test_csv9c_099_annihilape_registered_attacks_confuse_self_and_knock_out_both_active() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var annihilape_cd := _pokemon("弃世猴", "Stage 2", "火暴猴", "F", 140, [_attack("暴走", "F", "130"), _attack("同命战斗", "FC", "")], [], "", "293b8c882a550600a395e3c82b58f833")
	processor.register_pokemon_card(annihilape_cd)
	var annihilape := _slot(annihilape_cd, 0)
	state.players[0].active_pokemon = annihilape
	var attack0_effects := processor.get_attack_effects_for_slot(annihilape, 0)
	var attack1_effects := processor.get_attack_effects_for_slot(annihilape, 1)

	processor.execute_attack_effect(annihilape, 0, state.players[1].active_pokemon, state)
	var confused := bool(annihilape.status_conditions.get("confused", false))
	annihilape.clear_all_status()
	processor.execute_attack_effect(annihilape, 1, state.players[1].active_pokemon, state)

	return run_checks([
		assert_eq(attack0_effects.size(), 1, "Annihilape first attack should resolve exactly one native attack effect"),
		assert_eq(attack1_effects.size(), 1, "Annihilape second attack should resolve exactly one native attack effect"),
		assert_true(confused, "Annihilape first attack should Confuse itself"),
		assert_true(annihilape.is_knocked_out(), "Annihilape second attack should Knock Out itself"),
		assert_true(state.players[1].active_pokemon.is_knocked_out(), "Annihilape second attack should Knock Out the opponent Active"),
	])


func test_csv95c_031_slowpoke_real_attack_flow_has_no_native_effects_and_deals_printed_damage() -> String:
	var slowpoke_cd := _load_bundled_card("res://data/bundled_user/cards/CSV9.5C_031.json")
	if slowpoke_cd == null:
		return "CSV9.5C_031 bundled card should load"

	var water_gun_gsm := _make_gsm()
	var water_gun_attacker := _slot(slowpoke_cd, 0)
	var water_gun_defender := _slot(_pokemon("High HP Defender A", "Basic", "", "C", 220, [_attack("Tackle", "C", "30")], [], "", "defender_a"), 1)
	water_gun_gsm.game_state.players[0].active_pokemon = water_gun_attacker
	water_gun_gsm.game_state.players[1].active_pokemon = water_gun_defender
	_attach_energy(water_gun_attacker, 0, "W", 1)
	water_gun_gsm.effect_processor.register_pokemon_card(slowpoke_cd)
	var water_gun_used := water_gun_gsm.use_attack(0, 0)

	var tail_slap_gsm := _make_gsm()
	var tail_slap_attacker := _slot(slowpoke_cd, 0)
	var tail_slap_defender := _slot(_pokemon("High HP Defender B", "Basic", "", "C", 220, [_attack("Tackle", "C", "30")], [], "", "defender_b"), 1)
	tail_slap_gsm.game_state.players[0].active_pokemon = tail_slap_attacker
	tail_slap_gsm.game_state.players[1].active_pokemon = tail_slap_defender
	_attach_energy(tail_slap_attacker, 0, "W", 2)
	tail_slap_gsm.effect_processor.register_pokemon_card(slowpoke_cd)
	var tail_slap_used := tail_slap_gsm.use_attack(0, 1)

	return run_checks([
		assert_eq(str(slowpoke_cd.effect_id), "26d4511ab7a84d662387e992b44f130a", "CSV9.5C_031 should keep the API effect id"),
		assert_false(water_gun_gsm.effect_processor.has_attack_effect(slowpoke_cd.effect_id), "Slowpoke should not register native attack effects"),
		assert_true(water_gun_used, "Slowpoke should use Water Gun through GameStateMachine"),
		assert_eq(water_gun_defender.damage_counters, 10, "Water Gun should deal printed 10 damage"),
		assert_true(tail_slap_used, "Slowpoke should use Tail Slap through GameStateMachine"),
		assert_eq(tail_slap_defender.damage_counters, 30, "Tail Slap should deal printed 30 damage"),
	])


func test_csv9c_099_annihilape_real_attack_flow_uses_remote_effect_id() -> String:
	var annihilape_cd := _load_bundled_card("res://data/bundled_user/cards/CSV9C_099.json")
	if annihilape_cd == null:
		return "CSV9C_099 bundled card should load"

	var rage_gsm := _make_gsm()
	var rage_attacker := _slot(annihilape_cd, 0)
	var rage_defender := _slot(_pokemon("High HP Defender A", "Basic", "", "C", 220, [_attack("Tackle", "C", "30")], [], "", "annihilape_defender_a"), 1)
	rage_gsm.game_state.players[0].active_pokemon = rage_attacker
	rage_gsm.game_state.players[1].active_pokemon = rage_defender
	_attach_energy(rage_attacker, 0, "F", 1)
	rage_gsm.effect_processor.register_pokemon_card(annihilape_cd)
	var rage_effects := rage_gsm.effect_processor.get_attack_effects_for_slot(rage_attacker, 0)
	var rage_used := rage_gsm.use_attack(0, 0)

	var destined_gsm := _make_gsm()
	var destined_attacker := _slot(annihilape_cd, 0)
	var destined_defender := _slot(_pokemon("High HP Defender B", "Basic", "", "C", 220, [_attack("Tackle", "C", "30")], [], "", "annihilape_defender_b"), 1)
	destined_gsm.game_state.players[0].active_pokemon = destined_attacker
	destined_gsm.game_state.players[1].active_pokemon = destined_defender
	_attach_energy(destined_attacker, 0, "F", 2)
	destined_gsm.effect_processor.register_pokemon_card(annihilape_cd)
	var destined_effects := destined_gsm.effect_processor.get_attack_effects_for_slot(destined_attacker, 1)
	var destined_used := destined_gsm.use_attack(0, 1)

	return run_checks([
		assert_eq(str(annihilape_cd.effect_id), "293b8c882a550600a395e3c82b58f833", "CSV9C_099 should keep the remote imported effect id"),
		assert_true(rage_gsm.effect_processor.has_attack_effect(annihilape_cd.effect_id), "Remote effect id should register attack effects"),
		assert_eq(rage_effects.size(), 1, "Rage should resolve exactly one attack effect through the remote effect id"),
		assert_eq(destined_effects.size(), 1, "Destined Fight should resolve exactly one attack effect through the remote effect id"),
		assert_true(rage_used, "Annihilape should use Rage through GameStateMachine"),
		assert_eq(rage_defender.damage_counters, 130, "Rage should apply its printed 130 damage"),
		assert_true(bool(rage_attacker.status_conditions.get("confused", false)), "Rage should Confuse the attacker after damage"),
		assert_true(destined_used, "Annihilape should use Destined Fight through GameStateMachine"),
		assert_true(destined_attacker.damage_counters >= destined_attacker.get_max_hp(), "Destined Fight should Knock Out Annihilape"),
		assert_true(destined_defender.damage_counters >= destined_defender.get_max_hp(), "Destined Fight should Knock Out the opponent Active"),
		assert_true(destined_attacker.get_top_card() in destined_gsm.game_state.players[0].discard_pile, "Knocked Out Annihilape should move to discard"),
		assert_true(destined_defender.get_top_card() in destined_gsm.game_state.players[1].discard_pile, "Knocked Out opponent Active should move to discard"),
	])


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _slot(_pokemon("战斗宝可梦%d" % pi, "Basic", "", "C", 120, [_attack("撞击", "C", "30")], [], "", "active_%d" % pi), pi)
		state.players.append(player)
	return state


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _load_bundled_card(path: String) -> CardData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK or not (json.data is Dictionary):
		return null
	return CardData.from_dict(json.data)


func _pokemon(
	name: String,
	stage: String = "Basic",
	evolves_from: String = "",
	energy_type: String = "C",
	hp: int = 100,
	attacks: Array = [],
	abilities: Array = [],
	mechanic: String = "",
	effect_id: String = ""
) -> CardData:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = stage
	data.evolves_from = evolves_from
	data.energy_type = energy_type
	data.hp = hp
	var typed_attacks: Array[Dictionary] = []
	for attack: Variant in attacks:
		if attack is Dictionary:
			typed_attacks.append(attack)
	var typed_abilities: Array[Dictionary] = []
	for ability: Variant in abilities:
		if ability is Dictionary:
			typed_abilities.append(ability)
	data.attacks = typed_attacks
	data.abilities = typed_abilities
	data.mechanic = mechanic
	data.effect_id = effect_id
	return data


func _energy(name: String, energy_type: String, card_type: String = "Basic Energy") -> CardData:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = card_type
	data.energy_type = energy_type
	data.energy_provides = energy_type
	return data


func _attack(name: String, cost: String = "", damage: String = "", text: String = "") -> Dictionary:
	return {"name": name, "cost": cost, "damage": damage, "text": text, "is_vstar_power": false}


func _ability(name: String, text: String = "") -> Dictionary:
	return {"name": name, "text": text}


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> void:
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index))
