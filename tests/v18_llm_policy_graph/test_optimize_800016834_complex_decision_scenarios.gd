extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const EnergyBurstScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGEnergyBurst.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800016834
const DECK_SEED_PATH := "res://data/bundled_user/decks/800016834.json"
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800016834.json"
const ROUND00_PATH := "res://tmp/v18cpg/optimization21/800016834/round00.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800016834/complex_decision_scenarios.json"

const GHOLDENGO_EX_UID := "CSV4C_089"
const GHOLDENGO_UID := "CSV9C_142"
const GIMMIGHOUL_UID := "CSV9C_096"
const FEZANDIPITI_UID := "CSV8C_135"
const CIPHER_UID := "CSV7C_191"
const SUPERIOR_RETRIEVAL_UID := "CSV3C_115"
const ENERGY_SEARCH_PRO_UID := "CSV9C_176"
const IONO_UID := "CSV3C_123"
const METAL_UID := "CSVE1C_MET"
const DARK_UID := "CSVE1C_DAR"
const LIGHTNING_UID := "CSVE1C_LIG"
const GRASS_UID := "CSVE1C_GRA"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _deck_seed: Dictionary = {}
var _current_fingerprint := ""
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []
var _energy_burst = EnergyBurstScript.new()


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_deck_seed = _load_json(DECK_SEED_PATH)
	var deck := DeckData.from_dict(_deck_seed)
	_current_fingerprint = SemanticCompilerScript.deck_content_fingerprint(deck)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production pure Gholdengo profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "pure Gholdengo semantic manifest must load")
	_check(_profile.get("modules", []) == ["energy_burst", "cycle_pivot"], \
		"scenarios must use the production energy-burst/cycle-pivot composition")
	_check(int(deck.id) == DECK_ID and int(deck.total_cards) == 60, \
		"current bundled AI seed must be the exact 60-card deck")
	_check(_current_fingerprint != "" \
		and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", "")), \
		"semantic manifest fingerprint must match the current bundled AI deck")

	_scenario_a_make_it_rain_minimum_payment()
	_scenario_b_cipher_before_coin_bonus()
	_scenario_c_unique_energy_search_and_four_energy_recovery()
	_scenario_d_evolve_then_complete_metal_cost()
	_scenario_e_exact_final_prize_closeout()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800016834 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800016834 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_make_it_rain_minimum_payment() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var gholdengo := _real_slot(_real_card_data(GHOLDENGO_EX_UID), 0)
	gholdengo.attached_energy = [_real_instance(METAL_UID, 0)]
	var target := _real_target("Public 200 HP target", 200, 2)
	state.players[0].active_pokemon = gholdengo
	state.players[1].active_pokemon = target
	processor.register_pokemon_card(gholdengo.get_card_data())

	var basics: Array[CardInstance] = []
	for uid: String in [METAL_UID, DARK_UID, LIGHTNING_UID, GRASS_UID, METAL_UID]:
		basics.append(_real_instance(uid, 0))
	var special := _special_energy_instance("Public Special Energy", "M", 0)
	var protected_card := _filler_instance("Protected recovery card", 0)
	state.players[0].hand.assign(basics)
	state.players[0].hand.append(special)
	state.players[0].hand.append(protected_card)

	var effects := processor.get_attack_effects_for_slot(gholdengo, 0)
	var discard_step: Dictionary = {}
	for effect: BaseEffect in effects:
		var steps: Array = effect.get_attack_interaction_steps(
			gholdengo.get_top_card(), gholdengo.get_card_data().attacks[0], state)
		var candidate_step := _step(steps, "discard_basic_energy")
		if not candidate_step.is_empty():
			discard_step = candidate_step
			break
	var legal_items: Array = discard_step.get("items", []) if discard_step.get("items", []) is Array else []
	var minimum_selection := [basics[0], basics[1], basics[2], basics[3]]
	var three_selection := [basics[0], basics[1], basics[2]]
	var all_selection: Array = basics.duplicate()
	var exact_damage := _make_it_rain_damage(processor, gholdengo, target, state, minimum_selection)
	var short_damage := _make_it_rain_damage(processor, gholdengo, target, state, three_selection)
	var overpay_damage := _make_it_rain_damage(processor, gholdengo, target, state, all_selection)

	var observation := _observation(
		[_attack("attack:make-it-rain-200", 200, true)],
		_slot("slot:active", GHOLDENGO_EX_UID, [_energy_card(METAL_UID)]), [], 18)
	observation["own"]["hand"] = [
		_energy_card(METAL_UID), _energy_card(DARK_UID), _energy_card(LIGHTNING_UID),
		_energy_card(GRASS_UID), _energy_card(METAL_UID),
		{"uid": "PUBLIC_SPECIAL", "type": "Special Energy", "energy_type": "M"},
		{"uid": "PUBLIC_PROTECTED_CARD", "type": "Item"},
	]
	observation["opponent"]["active"] = _public_target("PUBLIC_200_HP_TARGET", 200, 2)
	var resource := _energy_burst.damage_resource_snapshot(observation, _profile, {}, 200)
	var minimum_certificate := _energy_burst.verified_minimum_discard_choice(5, 200, 5, 0, 50)

	var executed := processor.execute_attack_effect(
		gholdengo, 0, target, state, [{"discard_basic_energy": minimum_selection}])
	var remaining_basic_count := 0
	for card: CardInstance in state.players[0].hand:
		if card.card_data.card_type == "Basic Energy":
			remaining_basic_count += 1
	var real_contract_ok := legal_items.size() == 5 and special not in legal_items \
		and protected_card not in legal_items \
		and int(discard_step.get("min_select", -1)) == 0 \
		and int(discard_step.get("max_select", -1)) == 5 \
		and exact_damage == 200 and short_damage == 150 and overpay_damage == 250 \
		and executed and state.players[0].discard_pile.size() == 4 \
		and remaining_basic_count == 1 and special in state.players[0].hand \
		and protected_card in state.players[0].hand
	var architecture_ok := str(resource.get("mode", "")) == "hand_discard" \
		and str(resource.get("resource_zone", "")) == "own_hand_basic_energy" \
		and int(resource.get("raw_units", -1)) == 5 \
		and int(resource.get("required_units", -1)) == 4 \
		and int(resource.get("projected_public_damage", -1)) == 250 \
		and bool(minimum_certificate.get("verified", false)) \
		and int(minimum_certificate.get("selected_choice", -1)) == 4 \
		and int(minimum_certificate.get("preserved_basic_energy", -1)) == 1
	var passed: bool = real_contract_ok and architecture_ok
	_check(passed, "scenario A must pay exactly four hand Basic Energy for 200 and preserve the fifth")
	_rows.append(_row(
		"make_it_rain_minimum_payment",
		"淘金潮最小支付",
		"对200HP公开目标只弃4张手牌基础能量，造成200伤害；保留第5张基础能量、特殊能量和非能量资源。",
		"discard exactly 4 Basic Energy from hand; preserve the fifth",
		[
			"只弃3张时仅150伤害，不能宣称击倒",
			"弃5张虽有250伤害但浪费1张同奖效能量",
			"场上贴能、特殊能量与非能量手牌都不是淘金潮可弃伤害单位",
		],
		passed
	))


func _scenario_b_cipher_before_coin_bonus() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var gholdengo := _real_slot(_real_card_data(GHOLDENGO_EX_UID), 0)
	state.players[0].active_pokemon = gholdengo
	state.players[1].active_pokemon = _real_target("Public information target", 200, 2)
	processor.register_pokemon_card(gholdengo.get_card_data())
	var cipher := _real_instance(CIPHER_UID, 0)
	var metal := _real_instance(METAL_UID, 0)
	var superior := _real_instance(SUPERIOR_RETRIEVAL_UID, 0)
	var filler_a := _filler_instance("Unknown filler A", 0)
	var filler_b := _filler_instance("Unknown filler B", 0)
	state.players[0].hand = [cipher]
	state.players[0].deck = [filler_a, filler_b, metal, superior]
	var cipher_effect := processor.get_effect(cipher.card_data.effect_id)
	var cipher_steps: Array = cipher_effect.get_interaction_steps(cipher, state) if cipher_effect != null else []
	var top_step := _step(cipher_steps, "top_cards")
	var cipher_executed := processor.execute_card_effect(
		cipher, [{"top_cards": [metal, superior]}], state)
	var exact_stack := state.players[0].deck.size() == 4 \
		and state.players[0].deck[0] == metal and state.players[0].deck[1] == superior
	var ability_ready := processor.can_use_ability(gholdengo, state, 0)
	var ability_executed := processor.execute_ability_effect(gholdengo, 0, [], state)
	var exact_draw := metal in state.players[0].hand and superior in state.players[0].hand \
		and state.players[0].deck.size() == 2
	var once_only := not processor.can_use_ability(gholdengo, state, 0)

	var before := _observation(
		[
			_play_trainer("supporter:cipher-before-bonus", CIPHER_UID, true),
			_ability("ability:coin-bonus-before-cipher", GHOLDENGO_EX_UID),
		],
		_slot("slot:active", GHOLDENGO_EX_UID, [_energy_card(METAL_UID)]), [], 4)
	before["observation_version"] = 1
	before["observation_hash"] = "pure-gholdengo-before-codebreaking"
	var facts_before := _facts(true, false, false, 1, false, false, 0)
	var frontier := _frontier(before, {
		"supporter:cipher-before-bonus": 520.0,
		"ability:coin-bonus-before-cipher": 500.0,
	}, facts_before, "supporter:cipher-before-bonus")
	var cipher_candidate := _candidate(frontier, "supporter:cipher-before-bonus")
	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "pure-gholdengo-after-codebreaking-bonus"
	after["own"]["hand"] = [_card(CIPHER_UID), _energy_card(METAL_UID), _card(SUPERIOR_RETRIEVAL_UID)]
	after["own"]["deck_count"] = 2
	after["legal_actions"] = [_attack("attack:after-codebreaking", 200, true)]
	var facts_after := _facts(true, true, false, 3, false, false, 200)
	var epoch_reopens := _epoch_reopens(before, after, facts_before, facts_after, cipher_candidate, frontier)

	var wrong := _game_state()
	var wrong_gholdengo := _real_slot(_real_card_data(GHOLDENGO_EX_UID), 0)
	wrong.players[0].active_pokemon = wrong_gholdengo
	wrong.players[1].active_pokemon = _real_target("Public wrong-order target", 200, 2)
	processor.register_pokemon_card(wrong_gholdengo.get_card_data())
	var wrong_cipher := _real_instance(CIPHER_UID, 0)
	var wrong_metal := _real_instance(METAL_UID, 0)
	var wrong_superior := _real_instance(SUPERIOR_RETRIEVAL_UID, 0)
	wrong.players[0].hand = [wrong_cipher]
	wrong.players[0].deck = [
		_filler_instance("Wrong-order filler A", 0),
		_filler_instance("Wrong-order filler B", 0),
		wrong_metal,
		wrong_superior,
	]
	var wrong_draw := processor.execute_ability_effect(wrong_gholdengo, 0, [], wrong)
	var wrong_cipher_play := processor.execute_card_effect(
		wrong_cipher, [{"top_cards": [wrong_metal, wrong_superior]}], wrong)
	var wrong_order_blocked := wrong_draw and wrong_cipher_play \
		and wrong_metal not in wrong.players[0].hand and wrong_superior not in wrong.players[0].hand \
		and not processor.can_use_ability(wrong_gholdengo, wrong, 0)

	var bench_state := _game_state()
	var active_root := _real_slot(_real_card_data(GIMMIGHOUL_UID), 0)
	var bench_gholdengo := _real_slot(_real_card_data(GHOLDENGO_EX_UID), 0)
	bench_state.players[0].active_pokemon = active_root
	bench_state.players[0].bench = [bench_gholdengo]
	bench_state.players[1].active_pokemon = _real_target("Public bench-draw target", 100, 1)
	bench_state.players[0].deck = [
		_filler_instance("Bench draw one", 0),
		_filler_instance("Bench must leave one", 0),
	]
	processor.register_pokemon_card(bench_gholdengo.get_card_data())
	var bench_draw := processor.execute_ability_effect(bench_gholdengo, 0, [], bench_state) \
		and bench_state.players[0].hand.size() == 1 and bench_state.players[0].deck.size() == 1
	var empty_state := _game_state()
	var empty_gholdengo := _real_slot(_real_card_data(GHOLDENGO_EX_UID), 0)
	empty_state.players[0].active_pokemon = empty_gholdengo
	empty_state.players[1].active_pokemon = _real_target("Public empty-deck target", 100, 1)
	processor.register_pokemon_card(empty_gholdengo.get_card_data())
	var empty_blocked := not processor.can_use_ability(empty_gholdengo, empty_state, 0)

	var passed: bool = cipher_effect != null and cipher_steps.size() == 1 \
		and str(top_step.get("visible_scope", "")) == "own_full_deck" \
		and int(top_step.get("min_select", 0)) == 2 and int(top_step.get("max_select", 0)) == 2 \
		and cipher_executed and exact_stack and ability_ready and ability_executed \
		and exact_draw and once_only and epoch_reopens and wrong_order_blocked \
		and bench_draw and empty_blocked
	_check(passed, "scenario B must stack exact public cards before active Gholdengo draws two")
	_rows.append(_row(
		"cipher_before_coin_bonus",
		"赛富豪特性与支援者顺序",
		"先用密码解读把钢能与超级能量回收依次置顶，再由前台赛富豪ex特性抽2，信息结果触发紧凑重规划。",
		"Ciphermaniac(Metal, Superior Retrieval) -> active Coin Bonus draw 2",
		[
			"先发动特性会抽走未知顶牌，之后置顶的两张本回合无法再由同一特性抽取",
			"后备赛富豪ex只抽1张，不能按前台抽2估值",
			"空牌库与同回合第二次发动均必须被拒绝",
		],
		passed
	))


func _scenario_c_unique_energy_search_and_four_energy_recovery() -> void:
	var processor := EffectProcessor.new()
	var search_state := _game_state()
	search_state.players[0].active_pokemon = _real_slot(_real_card_data(GIMMIGHOUL_UID), 0)
	search_state.players[1].active_pokemon = _real_target("Public search target", 100, 1)
	var energy_search := _real_instance(ENERGY_SEARCH_PRO_UID, 0)
	var metal_a := _real_instance(METAL_UID, 0)
	var metal_b := _real_instance(METAL_UID, 0)
	var dark := _real_instance(DARK_UID, 0)
	var lightning := _real_instance(LIGHTNING_UID, 0)
	var deck_filler := _filler_instance("Non-energy deck card", 0)
	search_state.players[0].hand = [energy_search]
	search_state.players[0].deck = [metal_a, metal_b, dark, lightning, deck_filler]
	var search_effect := processor.get_effect(energy_search.card_data.effect_id)
	var search_steps: Array = search_effect.get_interaction_steps(energy_search, search_state) \
		if search_effect != null else []
	var search_step := _step(search_steps, "csv9c176_energy")
	var unique_items: Array = search_step.get("items", []) \
		if search_step.get("items", []) is Array else []
	var search_executed := processor.execute_card_effect(
		energy_search, [{"csv9c176_energy": [metal_a, dark, lightning]}], search_state)
	var unique_search_ok := search_executed \
		and metal_a in search_state.players[0].hand \
		and dark in search_state.players[0].hand \
		and lightning in search_state.players[0].hand \
		and metal_b in search_state.players[0].deck \
		and deck_filler in search_state.players[0].deck

	var duplicate_state := _game_state()
	duplicate_state.players[0].active_pokemon = _real_slot(_real_card_data(GIMMIGHOUL_UID), 0)
	duplicate_state.players[1].active_pokemon = _real_target("Public duplicate target", 100, 1)
	var duplicate_search := _real_instance(ENERGY_SEARCH_PRO_UID, 0)
	var duplicate_metal_a := _real_instance(METAL_UID, 0)
	var duplicate_metal_b := _real_instance(METAL_UID, 0)
	duplicate_state.players[0].hand = [duplicate_search]
	duplicate_state.players[0].deck = [duplicate_metal_a, duplicate_metal_b]
	var duplicate_effect := processor.get_effect(duplicate_search.card_data.effect_id)
	duplicate_effect.execute(
		duplicate_search,
		[{"csv9c176_energy": [duplicate_metal_a, duplicate_metal_b]}],
		duplicate_state
	)
	var duplicate_type_deduped := duplicate_state.players[0].hand.size() == 2 \
		and (duplicate_metal_a in duplicate_state.players[0].hand) != \
		(duplicate_metal_b in duplicate_state.players[0].hand)

	var recovery_state := _game_state()
	recovery_state.players[0].active_pokemon = _real_slot(_real_card_data(GHOLDENGO_EX_UID), 0)
	recovery_state.players[1].active_pokemon = _real_target("Public recovery target", 200, 2)
	var superior := _real_instance(SUPERIOR_RETRIEVAL_UID, 0)
	var cost_a := _filler_instance("Public expendable cost A", 0)
	var cost_b := _filler_instance("Public expendable cost B", 0)
	var recovered: Array[CardInstance] = [
		_real_instance(METAL_UID, 0), _real_instance(DARK_UID, 0),
		_real_instance(LIGHTNING_UID, 0), _real_instance(GRASS_UID, 0),
	]
	recovery_state.players[0].hand = [superior, cost_a, cost_b]
	recovery_state.players[0].discard_pile.assign(recovered)
	var recovery_effect := processor.get_effect(superior.card_data.effect_id)
	var recovery_steps: Array = recovery_effect.get_interaction_steps(superior, recovery_state) \
		if recovery_effect != null else []
	var discard_cost_step := _step(recovery_steps, "discard_cards")
	var recover_step := _step(recovery_steps, "recover_energy")
	var recovery_executed := processor.execute_card_effect(
		superior,
		[{"discard_cards": [cost_a, cost_b], "recover_energy": recovered}],
		recovery_state
	)
	var recovery_ok := recovery_executed \
		and cost_a in recovery_state.players[0].discard_pile \
		and cost_b in recovery_state.players[0].discard_pile
	for energy: CardInstance in recovered:
		recovery_ok = recovery_ok and energy in recovery_state.players[0].hand \
			and energy not in recovery_state.players[0].discard_pile

	var cost_energy_state := _game_state()
	cost_energy_state.players[0].active_pokemon = _real_slot(_real_card_data(GHOLDENGO_EX_UID), 0)
	cost_energy_state.players[1].active_pokemon = _real_target("Public cost exclusion target", 100, 1)
	var cost_superior := _real_instance(SUPERIOR_RETRIEVAL_UID, 0)
	var energy_paid_as_cost := _real_instance(METAL_UID, 0)
	var other_cost := _filler_instance("Other public cost", 0)
	var old_discard_energy := _real_instance(DARK_UID, 0)
	cost_energy_state.players[0].hand = [cost_superior, energy_paid_as_cost, other_cost]
	cost_energy_state.players[0].discard_pile = [old_discard_energy]
	recovery_effect.execute(cost_superior, [{
		"discard_cards": [energy_paid_as_cost, other_cost],
		"recover_energy": [energy_paid_as_cost, old_discard_energy],
	}], cost_energy_state)
	var paid_energy_not_recovered := energy_paid_as_cost in cost_energy_state.players[0].discard_pile \
		and energy_paid_as_cost not in cost_energy_state.players[0].hand \
		and old_discard_energy in cost_energy_state.players[0].hand

	var insufficient_state := _game_state()
	insufficient_state.players[0].active_pokemon = _real_slot(_real_card_data(GHOLDENGO_EX_UID), 0)
	insufficient_state.players[1].active_pokemon = _real_target("Public insufficient-cost target", 100, 1)
	var insufficient_superior := _real_instance(SUPERIOR_RETRIEVAL_UID, 0)
	insufficient_state.players[0].hand = [insufficient_superior, _filler_instance("Only one other card", 0)]
	insufficient_state.players[0].discard_pile = [_real_instance(METAL_UID, 0)]
	var insufficient_blocked := not recovery_effect.can_execute(insufficient_superior, insufficient_state)

	var passed: bool = search_effect != null and recovery_effect != null \
		and str(search_step.get("visible_scope", "")) == "own_full_deck" \
		and unique_items.size() == 3 and metal_a in unique_items and metal_b not in unique_items \
		and unique_search_ok and duplicate_type_deduped \
		and int(discard_cost_step.get("min_select", 0)) == 2 \
		and int(discard_cost_step.get("max_select", 0)) == 2 \
		and int(recover_step.get("min_select", -1)) == 0 \
		and int(recover_step.get("max_select", -1)) == 4 \
		and recovery_ok and paid_energy_not_recovered and insufficient_blocked
	_check(passed, "scenario C must search unique Energy types and recover exactly four pre-existing Basic Energy")
	_rows.append(_row(
		"unique_energy_search_and_four_energy_recovery",
		"能量检索与回收",
		"能量输送PRO只取不同属性的基础能量；超级能量回收支付2张非关键手牌后，把弃牌区既有4张基础能量取回，形成淘金潮续航。",
		"Energy Search Pro(M/D/L unique) -> Superior Retrieval(discard 2, recover 4)",
		[
			"同属性的第二张钢能不能被能量输送PRO重复取回",
			"作为超级能量回收支付成本而刚进入弃牌区的能量不能同时回收",
			"不足2张其他手牌时超级能量回收不可发动",
		],
		passed
	))


func _scenario_d_evolve_then_complete_metal_cost() -> void:
	var processor := EffectProcessor.new()
	var validator := RuleValidator.new()
	var state := _game_state()
	var gimmighoul := _real_slot(_real_card_data(GIMMIGHOUL_UID), 0)
	gimmighoul.turn_played = 1
	var gholdengo_card := _real_instance(GHOLDENGO_EX_UID, 0)
	state.players[0].active_pokemon = gimmighoul
	state.players[0].hand = [gholdengo_card]
	state.players[1].active_pokemon = _real_target("Public evolution target", 200, 2)
	var legal_evolution := validator.can_evolve(state, 0, gimmighoul, gholdengo_card, processor)
	if legal_evolution:
		state.players[0].hand.erase(gholdengo_card)
		gimmighoul.pokemon_stack.append(gholdengo_card)
		gimmighoul.turn_evolved = state.turn_number
	processor.register_pokemon_card(gimmighoul.get_card_data())
	var blocked_before_attach := not validator.can_use_attack(state, 0, 0, processor)
	var metal := _real_instance(METAL_UID, 0)
	gimmighoul.attached_energy.append(metal)
	var ready_after_attach := validator.can_use_attack(state, 0, 0, processor)

	var fresh_state := _game_state()
	var fresh_root := _real_slot(_real_card_data(GIMMIGHOUL_UID), 0)
	fresh_root.turn_played = fresh_state.turn_number
	fresh_state.players[0].active_pokemon = fresh_root
	fresh_state.players[1].active_pokemon = _real_target("Public fresh-root target", 100, 1)
	var fresh_evolution_blocked := not validator.can_evolve(
		fresh_state, 0, fresh_root, _real_instance(GHOLDENGO_EX_UID, 0), processor)
	var wrong_state := _game_state()
	var wrong_gholdengo := _real_slot(_real_card_data(GHOLDENGO_EX_UID), 0)
	wrong_gholdengo.attached_energy = [_real_instance(DARK_UID, 0)]
	wrong_state.players[0].active_pokemon = wrong_gholdengo
	wrong_state.players[1].active_pokemon = _real_target("Public off-color target", 100, 1)
	processor.register_pokemon_card(wrong_gholdengo.get_card_data())
	var off_color_blocked := not validator.can_use_attack(wrong_state, 0, 0, processor)

	var observation := _observation(
		[
			_play_basic("bench:optional-fezandipiti", FEZANDIPITI_UID),
			_attach_energy("attach:metal-completes-cost", METAL_UID, "slot:active"),
			_attach_energy("attach:dark-does-not-complete", DARK_UID, "slot:active"),
		],
		_slot("slot:active", GHOLDENGO_EX_UID, []), [], 18)
	var facts := _facts(false, false, true, 3, false, false, 0)
	var frontier := _frontier(observation, {
		"bench:optional-fezandipiti": 700.0,
		"attach:metal-completes-cost": 690.0,
		"attach:dark-does-not-complete": 680.0,
	}, facts, "bench:optional-fezandipiti")
	var metal_candidate := _candidate(frontier, "attach:metal-completes-cost")
	var dark_candidate := _candidate(frontier, "attach:dark-does-not-complete")
	var fez_candidate := _candidate(frontier, "bench:optional-fezandipiti")
	var metal_annotation := _module(metal_candidate, "energy_burst")
	var dark_annotation := _module(dark_candidate, "energy_burst")
	var fez_annotation := _module(fez_candidate, "cycle_pivot")
	var metal_attachment: Dictionary = metal_annotation.get("attachment", {}) \
		if metal_annotation.get("attachment", {}) is Dictionary else {}
	var dark_attachment: Dictionary = dark_annotation.get("attachment", {}) \
		if dark_annotation.get("attachment", {}) is Dictionary else {}
	var certificate := CapabilityRegistryScript.new().verify_route_advantage(
		metal_candidate, frontier[0], facts, _profile)
	var safety := _route_safety(metal_candidate, frontier, facts)

	var passed: bool = legal_evolution and gimmighoul.get_card_data().get_uid() == GHOLDENGO_EX_UID \
		and blocked_before_attach and ready_after_attach \
		and fresh_evolution_blocked and off_color_blocked \
		and bool(metal_attachment.get("target_is_primary_attacker", false)) \
		and bool(metal_attachment.get("completes_required_types", false)) \
		and metal_attachment.get("missing_required_types_before", []) == ["M"] \
		and not bool(dark_attachment.get("completes_required_types", false)) \
		and bool(fez_annotation.get("optional_draw_engine", false)) \
		and bool(certificate.get("verified", false)) \
		and str(certificate.get("certificate_kind", "")) == "public_typed_attack_cost_completion" \
		and bool(safety.get("valid", false))
	_check(passed, "scenario D must evolve the real Gimmighoul and certify exact Metal cost completion")
	_rows.append(_row(
		"evolve_then_complete_metal_cost",
		"进化与填能",
		"已留场的索财灵先进化为赛富豪ex，再贴钢能补齐淘金潮费用；该确定性费用完成优先于占后备位的可选吉雉鸡ex。",
		"evolve Gimmighoul -> Gholdengo ex -> attach Metal -> Make It Rain ready",
		[
			"本回合刚下场的索财灵不能普通进化",
			"恶能等非钢能不能补齐钢费用",
			"没有钢能时不能把淘金潮标为可用",
		],
		passed
	))


func _scenario_e_exact_final_prize_closeout() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var gholdengo := _real_slot(_real_card_data(GHOLDENGO_EX_UID), 0)
	gholdengo.attached_energy = [_real_instance(METAL_UID, 0)]
	var target := _real_target("Public final two-Prize ex", 280, 2)
	state.players[0].active_pokemon = gholdengo
	state.players[1].active_pokemon = target
	processor.register_pokemon_card(gholdengo.get_card_data())
	var basics: Array[CardInstance] = []
	for uid: String in [METAL_UID, DARK_UID, LIGHTNING_UID, GRASS_UID, METAL_UID, DARK_UID, LIGHTNING_UID]:
		basics.append(_real_instance(uid, 0))
	state.players[0].hand.assign(basics)
	var exact_selection := [basics[0], basics[1], basics[2], basics[3], basics[4], basics[5]]
	var short_selection := [basics[0], basics[1], basics[2], basics[3], basics[4]]
	var exact_damage := _make_it_rain_damage(processor, gholdengo, target, state, exact_selection)
	var short_damage := _make_it_rain_damage(processor, gholdengo, target, state, short_selection)
	var overpay_damage := _make_it_rain_damage(processor, gholdengo, target, state, basics)
	var executed := processor.execute_attack_effect(
		gholdengo, 0, target, state, [{"discard_basic_energy": exact_selection}])
	DamageCalculator.new().apply_damage_to_slot(target, exact_damage)
	var real_knockout := target.is_knocked_out()
	var remaining_exactly_one := state.players[0].hand.size() == 1 \
		and state.players[0].hand[0] == basics[6]

	var observation := _observation(
		[
			_play_trainer("supporter:iono-too-late", IONO_UID, false),
			_attack("attack:make-it-rain-final", 300, true),
		],
		_slot("slot:active", GHOLDENGO_EX_UID, [_energy_card(METAL_UID)]), [], 9)
	observation["own"]["hand"] = [
		_energy_card(METAL_UID), _energy_card(DARK_UID), _energy_card(LIGHTNING_UID),
		_energy_card(GRASS_UID), _energy_card(METAL_UID), _energy_card(DARK_UID),
		_energy_card(LIGHTNING_UID),
	]
	observation["own"]["prizes_remaining"] = 2
	observation["opponent"]["active"] = _public_target("PUBLIC_FINAL_TWO_PRIZE_EX", 280, 2)
	var facts := _facts(true, true, false, 7, false, false, 300)
	facts["resources"]["prizes_remaining"] = 2
	facts["prize"] = {"current_swing": 2, "win_now": true}
	var frontier := _frontier(observation, {
		"supporter:iono-too-late": 700.0,
		"attack:make-it-rain-final": 10.0,
	}, facts, "supporter:iono-too-late")
	var attack_candidate := _candidate(frontier, "attack:make-it-rain-final")
	var burst := _module(attack_candidate, "energy_burst")
	var safety := _route_safety(attack_candidate, frontier, facts)
	var outcome: Dictionary = attack_candidate.get("outcome", {}) \
		if attack_candidate.get("outcome", {}) is Dictionary else {}
	var plan := _energy_burst.discard_plan(280, 7, 0, 50)
	var impossible_plan := _energy_burst.discard_plan(351, 7, 0, 50)
	var unknown_plan := _energy_burst.discard_plan(0, 7, 0, 50)

	var passed: bool = exact_damage == 300 and short_damage == 250 and overpay_damage == 350 \
		and executed and real_knockout and remaining_exactly_one \
		and int(burst.get("damage_raw_units", -1)) == 7 \
		and int(burst.get("minimum_discards_for_active_ko", -1)) == 6 \
		and int(burst.get("projected_public_damage", -1)) == 350 \
		and bool(burst.get("ko_payable_with_reserve", false)) \
		and int(plan.get("discard_count", -1)) == 6 \
		and int(plan.get("remaining_energy", -1)) == 1 \
		and bool(outcome.get("win_now", false)) and int(outcome.get("prizes_now", 0)) == 2 \
		and bool(safety.get("valid", false)) \
		and str(safety.get("reason", "")) == "deterministic_win_now" \
		and not bool(impossible_plan.get("payable", true)) \
		and not bool(unknown_plan.get("payable", true))
	_check(passed, "scenario E must take the final two prizes with exactly six hand Energy before Iono")
	_rows.append(_row(
		"exact_final_prize_closeout",
		"关键奖终局",
		"己方剩2奖、对手前台280HP双奖ex时，淘金潮精确弃6张造成300并立即结束比赛，保留第7张；任何抽换手牌动作都不得抢在终局攻击前。",
		"Make It Rain(discard exactly 6 for 300) before Iono",
		[
			"只弃5张仅250伤害，不能宣称终局",
			"弃7张虽击倒但浪费末张能量，不是最小支付",
			"351HP或未知HP不能生成可支付的确定性终局证书",
		],
		passed
	))


func _frontier(
	observation: Dictionary,
	scores: Dictionary,
	facts: Dictionary,
	rule_action_id: String
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = RouteSearchScript.new().build_candidate_pool(
		observation, scores, _manifest, facts)
	var rule_index := -1
	for index: int in pool.size():
		pool[index]["engine_rule_floor_exact"] = false
		if str(pool[index].get("safe_prefix_action_id", "")) == rule_action_id:
			rule_index = index
	if rule_index >= 0:
		var rule_floor: Dictionary = pool[rule_index]
		rule_floor["engine_rule_floor_exact"] = true
		pool.remove_at(rule_index)
		pool.insert(0, rule_floor)
	var annotated: Array[Dictionary] = CapabilityRegistryScript.new().annotate_frontier(
		pool, observation, facts, _profile, _manifest)
	_check(not annotated.is_empty() \
		and str(annotated[0].get("safe_prefix_action_id", "")) == rule_action_id, \
		"fixture Rule floor %s must remain exact and first" % rule_action_id)
	_check(not JSON.stringify(annotated).contains("FORBIDDEN_SECRET"), \
		"public scenario frontier must exclude hidden sentinels")
	return annotated


func _route_safety(selected: Dictionary, frontier: Array[Dictionary], facts: Dictionary) -> Dictionary:
	if selected.is_empty():
		return {"valid": false, "reason": "missing_selected_candidate"}
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	return strategy.call("_validate_model_route_safety", \
		str(selected.get("route_id", "")), frontier, facts, str(selected.get("candidate_id", "")))


func _epoch_reopens(
	before: Dictionary,
	after: Dictionary,
	facts_before: Dictionary,
	facts_after: Dictionary,
	candidate: Dictionary,
	frontier: Array[Dictionary]
) -> bool:
	var delta := MaterialDeltaScript.new().compare(before, after, facts_before, facts_after)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.configure_verified_local_only_for_benchmark()
	return bool(strategy.call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": true,
			"route_id": str(candidate.get("route_id", "")),
			"candidate_id": str(candidate.get("candidate_id", "")),
		}, delta, frontier))


func _candidate(frontier: Array[Dictionary], action_id: String) -> Dictionary:
	for candidate: Dictionary in frontier:
		if str(candidate.get("safe_prefix_action_id", "")) == action_id:
			return candidate
	_check(false, "candidate for %s must exist" % action_id)
	return {}


func _module(candidate: Dictionary, module_id: String) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(module_id, {}) if annotations.get(module_id, {}) is Dictionary else {}


func _observation(actions: Array, active: Dictionary, bench: Array, deck_count: int) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "pure-gholdengo-complex-scenario",
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": active,
			"bench": bench,
			"hand": [{"uid": "VISIBLE_OWN_HAND_CARD"}],
			"discard": [],
			"deck_count": deck_count,
			"prizes_remaining": 6,
		},
		"opponent": {
			"active": _public_target("PUBLIC_OPPONENT_ACTIVE", 230, 2),
			"bench": [],
			"hand": [{"uid": "FORBIDDEN_SECRET_HAND_CARD"}],
			"deck_order": ["FORBIDDEN_SECRET_TOP_CARD"],
		},
		"stadium": {},
		"legal_actions": actions,
	}


func _facts(
	attack_ready: bool,
	ko_available: bool,
	energy_available: bool,
	hand_size: int,
	deck_low: bool,
	deck_critical: bool,
	max_damage: int
) -> Dictionary:
	return {
		"attack": {"ready": attack_ready, "ko_available": ko_available, "max_damage": max_damage},
		"turn": {"energy_available": energy_available, "supporter_available": true},
		"resources": {
			"deck_low": deck_low,
			"deck_critical": deck_critical,
			"hand_size": hand_size,
			"bench_slots_free": 5,
			"prizes_remaining": 6,
			"energy_on_board": 0,
		},
		"board": {"bench_full": false, "has_tera": false},
		"information": {"material_action_available": true},
		"prize": {"current_swing": 0, "win_now": false},
		"route": {"current_valid": true},
	}


func _slot(slot_id: String, uid: String, energy: Array) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid),
		"energy": energy,
		"energy_count": energy.size(),
		"remaining_hp": 260 if uid == GHOLDENGO_EX_UID else 70,
		"max_hp": 260 if uid == GHOLDENGO_EX_UID else 70,
		"prize_count": 2 if uid == GHOLDENGO_EX_UID else 1,
	}


func _public_target(uid: String, remaining_hp: int, prize_count: int) -> Dictionary:
	return {
		"slot_id": "slot:%s" % uid.to_lower(),
		"pokemon": {"uid": uid},
		"remaining_hp": remaining_hp,
		"prize_count": prize_count,
	}


func _play_trainer(action_id: String, uid: String, interaction: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "play_trainer",
		"card": _card(uid),
		"requires_interaction": interaction,
	}


func _play_basic(action_id: String, uid: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "play_basic_to_bench",
		"card": _card(uid),
		"requires_interaction": false,
	}


func _attach_energy(action_id: String, uid: String, target: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attach_energy",
		"card": _energy_card(uid),
		"target": target,
	}


func _ability(action_id: String, uid: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "use_ability",
		"source": "slot:active",
		"source_card": _card(uid),
		"ability_index": 0,
		"requires_interaction": false,
	}


func _attack(action_id: String, damage: int, knockout: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attack",
		"source": "slot:active",
		"source_card": _card(GHOLDENGO_EX_UID),
		"attack_index": 0,
		"projected_damage": damage,
		"projected_knockout": knockout,
		"requires_interaction": true,
	}


func _energy_card(uid: String) -> Dictionary:
	var card := _card(uid)
	var symbol := "M"
	match uid:
		DARK_UID:
			symbol = "D"
		LIGHTNING_UID:
			symbol = "L"
		GRASS_UID:
			symbol = "G"
	card["energy_type"] = symbol
	card["energy_provides"] = symbol
	return card


func _card(uid: String) -> Dictionary:
	for raw_card: Variant in _manifest.get("cards", []):
		if not (raw_card is Dictionary) or str((raw_card as Dictionary).get("uid", "")) != uid:
			continue
		var source: Dictionary = raw_card
		return {
			"uid": uid,
			"effect_id": str(source.get("effect_id", "")),
			"name": str(source.get("name", "")),
			"type": str(source.get("type", "")),
			"semantic_roles": (source.get("roles", []) as Array).duplicate() \
				if source.get("roles", []) is Array else [],
		}
	_check(false, "manifest card %s must exist" % uid)
	return {"uid": uid}


func _make_it_rain_damage(
	processor: EffectProcessor,
	attacker: PokemonSlot,
	defender: PokemonSlot,
	state: GameState,
	selected: Array
) -> int:
	var attack: Dictionary = attacker.get_card_data().attacks[0]
	var modifier := processor.get_attack_damage_modifier(
		attacker, defender, attack, state, [{"discard_basic_energy": selected}], 0)
	return DamageCalculator.new().calculate_damage(
		attacker, defender, attack, state, modifier, 0, 0)


func _game_state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 8
	state.phase = GameState.GamePhase.MAIN
	for index: int in 2:
		var player := PlayerState.new()
		player.player_index = index
		state.players.append(player)
	return state


func _real_card_data(uid: String) -> CardData:
	var path := "res://data/bundled_user/cards/%s.json" % uid
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "real card %s must load" % uid)
	return CardData.from_dict(parsed as Dictionary) if parsed is Dictionary else CardData.new()


func _real_instance(uid: String, owner: int) -> CardInstance:
	return CardInstance.create(_real_card_data(uid), owner)


func _real_slot(data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot


func _real_target(name: String, hp: int, prize_count: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = hp
	data.mechanic = "ex" if prize_count == 2 else ""
	return _real_slot(data, 1)


func _special_energy_instance(name: String, symbol: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Special Energy"
	data.energy_provides = symbol
	return CardInstance.create(data, owner)


func _filler_instance(name: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Item"
	return CardInstance.create(data, owner)


func _step(steps: Array, id: String) -> Dictionary:
	for raw_step: Variant in steps:
		if raw_step is Dictionary and str((raw_step as Dictionary).get("id", "")) == id:
			return raw_step as Dictionary
	return {}


func _row(
	id: String,
	category: String,
	description: String,
	expected_choice: String,
	negative_boundaries: Array,
	passed: bool
) -> Dictionary:
	return {
		"id": id,
		"category": category,
		"description": description,
		"expected_choice": expected_choice,
		"negative_boundaries": negative_boundaries.duplicate(),
		"passed": passed,
	}


func _round00_summary() -> Dictionary:
	if not FileAccess.file_exists(ROUND00_PATH):
		return {"artifact_exists": false, "status": "missing"}
	var round00 := _load_json(ROUND00_PATH)
	var reports: Array = round00.get("reports", []) if round00.get("reports", []) is Array else []
	if reports.is_empty() or not (reports[0] is Dictionary):
		return {"artifact_exists": true, "status": "unreadable_report"}
	var report: Dictionary = reports[0]
	var provenance_valid := str(report.get("deck_source", "")) == "bundled_ai" \
		and str(report.get("deck_content_fingerprint", "")) == _current_fingerprint
	return {
		"artifact_exists": true,
		"artifact": ROUND00_PATH,
		"status": "current_bundled_ai_round00" if provenance_valid \
			else "rejected_missing_or_mismatched_bundled_ai_provenance",
		"accepted_for_round_accounting": provenance_valid,
		"required_deck_content_fingerprint": _current_fingerprint,
		"observed_deck_source": str(report.get("deck_source", "")),
		"observed_deck_content_fingerprint": str(report.get("deck_content_fingerprint", "")),
		"games": int(report.get("games", 0)),
		"rule_win_rate": float(report.get("rule_win_rate", 0.0)),
		"v18cpg_win_rate": float(report.get("v18cpg_win_rate", 0.0)),
		"paired_improvement": float(report.get("paired_improvement", 0.0)),
		"model_calls": int(report.get("model_calls", 0)),
		"model_accepted": int(report.get("model_accepted", 0)),
		"model_acceptance_rate": float(report.get("model_acceptance_rate", 0.0)),
		"turn_visible_wait_p95_ms": float(report.get("turn_visible_wait_p95_ms", 0.0)),
		"uncovered_events": int(report.get("uncovered_events", 0)),
	}


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"semantic_schema": "v18cpg-2",
		"transport_contract_version": 3,
		"deck_id": DECK_ID,
		"deck_name": "18.0 纯赛富豪",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"deck_source": {
			"source_kind": "bundled_ai",
			"bundled_seed_path": DECK_SEED_PATH,
			"source_provider": str(_deck_seed.get("source_provider", "")),
			"source_url": str(_deck_seed.get("source_url", "")),
			"total_cards": int(_deck_seed.get("total_cards", 0)),
			"deck_content_fingerprint": _current_fingerprint,
			"semantic_manifest_fingerprint": str(_manifest.get("deck_content_fingerprint", "")),
			"fingerprint_verified": _current_fingerprint != "" \
				and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", "")),
		},
		"baseline": _round00_summary(),
		"scope": "focused scenario proof only; no formal or real-model run was started",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_not_promoted",
		"scenarios": _rows,
		"known_production_gaps": [
			"The existing five-game round00 tied Rule at 80% but lacks bundled_ai fingerprint provenance, so it is rejected for round accounting.",
			"The existing model acceptance was 1/37; these focused scenarios do not claim transport, acceptance, or latency improvement.",
			"The profile models Make It Rain as hand-discard damage and exposes exact public KO units, while production interaction ownership remains client-side.",
			"No deck-local profile, shared runtime, Rule strategy, legacy LLM strategy, Agent strategy, registry, or formal manifest was modified.",
		],
		"isolation": {
			"focused_test_added": true,
			"tmp_report_generated": true,
			"profile_modified": false,
			"shared_runtime_modified": false,
			"rule_modified": false,
			"legacy_modified": false,
			"agent_modified": false,
			"formal_run_started": false,
		},
		"test_only": true,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	_check(file != null, "complex scenario report must be writable")
	if file != null:
		file.store_string(JSON.stringify(report, "  "))


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "%s must contain a JSON object" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
