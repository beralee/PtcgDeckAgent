class_name TestV18DarkCharacterFamilyStrategy
extends TestBase


const DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18DarkCharacterFamily.gd"
const MARNIE_DECK_ID := 800018501
const NS_ZOROARK_DECK_ID := 800018502


func test_dark_character_delegate_exposes_the_v18_contract_for_both_decks() -> String:
	var script: Variant = load(DELEGATE_PATH)
	var checks: Array[String] = [
		assert_true(script is GDScript, "The dark character family delegate should compile"),
	]
	if not script is GDScript:
		return run_checks(checks)
	for deck_id: int in [MARNIE_DECK_ID, NS_ZOROARK_DECK_ID]:
		var strategy := _make_strategy(deck_id)
		checks.append(assert_not_null(strategy, "Deck %d should configure the family delegate" % deck_id))
		if strategy == null:
			continue
		for method_name: String in [
			"build_turn_plan",
			"build_turn_contract",
			"build_continuity_contract",
			"score_action_absolute",
			"score_action_absolute_with_plan",
			"pick_interaction_items",
			"score_interaction_target",
			"score_handoff_target",
		]:
			checks.append(assert_true(strategy.has_method(method_name), "The delegate should expose %s" % method_name))
		var plan: Dictionary = strategy.call("build_turn_plan", _make_state(), 0, {})
		checks.append(assert_true(str(plan.get("phase", "")) in ["setup", "launch", "convert", "rebuild", "close"], "Deck %d should emit a V18 phase" % deck_id))
		checks.append(assert_true(plan.get("owner", {}) is Dictionary, "Deck %d should declare route ownership" % deck_id))
		checks.append(assert_true(plan.get("priorities", {}) is Dictionary, "Deck %d should declare route priorities" % deck_id))
	return run_checks(checks)


func test_marnie_route_prioritizes_grimmsnarl_evolution_and_candy_bridge() -> String:
	var strategy := _make_strategy(MARNIE_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var impidimp := _make_slot(_make_pokemon("玛俐的捣蛋小妖", "Basic", "", [
		{"name": "骗取", "cost": "C", "damage": "", "text": "Draw a card."},
		{"name": "推打", "cost": "D", "damage": "10", "text": ""},
	]))
	player.active_pokemon = impidimp
	var rare_candy := CardInstance.create(_make_trainer("神奇糖果", "Item"), 0)
	var grimmsnarl := CardInstance.create(_make_pokemon("玛俐的长毛巨魔ex", "Stage 2", "玛俐的诈唬魔", [
		{"name": "暗影子弹", "cost": "DD", "damage": "180", "text": ""},
	]), 0)
	player.hand.assign([rare_candy, grimmsnarl])
	for index: int in 5:
		player.deck.append(CardInstance.create(_make_energy("基本恶能量 %d" % index, "D"), 0))
	var unrelated := CardInstance.create(_make_pokemon("无关二阶", "Stage 2", "无关一阶", [
		{"name": "错误招式", "cost": "DD", "damage": "200", "text": ""},
	]), 0)
	var grimmsnarl_score: float = strategy.call("score_action_absolute", {
		"kind": "evolve", "card": grimmsnarl, "target_slot": impidimp,
	}, state, 0)
	var unrelated_score: float = strategy.call("score_action_absolute", {
		"kind": "evolve", "card": unrelated, "target_slot": impidimp,
	}, state, 0)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return run_checks([
		assert_true(grimmsnarl_score >= unrelated_score + 1500.0, "The Punk Up Stage-2 conversion should outrank an unrelated evolution"),
		assert_eq(str((plan.get("owner", {}) as Dictionary).get("bridge_target_name", "")), "玛俐的长毛巨魔ex", "Rare Candy in hand should make Grimmsnarl the immediate bridge"),
		assert_eq(str(plan.get("intent", "")), "complete_marnie_evolution", "The plan should keep ownership on the Marnie evolution route"),
	])


func test_marnie_punk_up_funds_the_attacker_then_the_backup_line() -> String:
	var strategy := _make_strategy(MARNIE_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var grimmsnarl := _make_slot(_make_pokemon("玛俐的长毛巨魔ex", "Stage 2", "玛俐的诈唬魔", [
		{"name": "暗影子弹", "cost": "DD", "damage": "180", "text": ""},
	]))
	var impidimp := _make_slot(_make_pokemon("玛俐的捣蛋小妖", "Basic", "", [
		{"name": "推打", "cost": "D", "damage": "10", "text": ""},
	]))
	player.active_pokemon = grimmsnarl
	player.bench.append(impidimp)
	var energies: Array = []
	for index: int in 5:
		energies.append(CardInstance.create(_make_energy("基本恶能量 %d" % index, "D"), 0))
	var picked: Array = strategy.call("pick_interaction_items", energies, {
		"id": "marnies_punk_up_assignments",
		"max_select": 5,
	}, {"game_state": state, "player_index": 0})
	var initial_grimmsnarl_score: float = strategy.call("score_interaction_target", grimmsnarl, {
		"id": "marnies_punk_up_assignments",
	}, {"game_state": state, "player_index": 0})
	var initial_impidimp_score: float = strategy.call("score_interaction_target", impidimp, {
		"id": "marnies_punk_up_assignments",
	}, {"game_state": state, "player_index": 0})
	var pending := {}
	pending[grimmsnarl.get_instance_id()] = 2
	var funded_grimmsnarl_score: float = strategy.call("score_interaction_target", grimmsnarl, {
		"id": "marnies_punk_up_assignments",
	}, {"game_state": state, "player_index": 0, "pending_assignment_counts": pending})
	var backup_score: float = strategy.call("score_interaction_target", impidimp, {
		"id": "marnies_punk_up_assignments",
	}, {"game_state": state, "player_index": 0, "pending_assignment_counts": pending})
	return run_checks([
		assert_eq(picked.size(), 4, "Punk Up should take exactly the four Energy needed to fund two DD routes"),
		assert_true(initial_grimmsnarl_score > initial_impidimp_score, "The current Grimmsnarl attacker should receive the first Energy"),
		assert_true(backup_score > funded_grimmsnarl_score, "After Grimmsnarl reaches DD, assignments should move to the backup Marnie line"),
	])


func test_spikemuth_search_completes_the_live_marnie_evolution_route() -> String:
	var strategy := _make_strategy(MARNIE_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(_make_pokemon("玛俐的捣蛋小妖", "Basic", "", [
		{"name": "推打", "cost": "D", "damage": "10", "text": ""},
	]))
	player.hand.append(CardInstance.create(_make_trainer("神奇糖果", "Item"), 0))
	var impidimp := CardInstance.create(_make_pokemon("玛俐的捣蛋小妖", "Basic", "", []), 0)
	var morgrem := CardInstance.create(_make_pokemon("玛俐的诈唬魔", "Stage 1", "玛俐的捣蛋小妖", []), 0)
	var grimmsnarl := CardInstance.create(_make_pokemon("玛俐的长毛巨魔ex", "Stage 2", "玛俐的诈唬魔", []), 0)
	var picked: Array = strategy.call("pick_interaction_items", [impidimp, morgrem, grimmsnarl], {
		"id": "spikemuth_gym_marnies_pokemon",
		"max_select": 1,
	}, {"game_state": state, "player_index": 0})
	return assert_true(
		picked.size() == 1 and picked[0] == grimmsnarl,
		"Spikemuth Gym should search Grimmsnarl when Rare Candy and an Impidimp are already live"
	)


func test_ns_trade_discards_recoverable_energy_but_preserves_the_only_manual_attachment() -> String:
	var strategy := _make_strategy(NS_ZOROARK_DECK_ID)
	var ready_state := _make_ns_state(2, true)
	var ready_player: PlayerState = ready_state.players[0]
	var recoverable_energy := CardInstance.create(_make_energy("基本恶能量", "D"), 0)
	var pp_up := CardInstance.create(_make_trainer("N的PP提升剂", "Item"), 0)
	var iono := CardInstance.create(_make_trainer("奇树", "Supporter"), 0)
	ready_player.hand.assign([recoverable_energy, pp_up, iono])
	var ready_pick: Array = strategy.call("pick_interaction_items", ready_player.hand, {
		"id": "discard_card", "max_select": 1,
	}, {"game_state": ready_state, "player_index": 0})

	var launch_state := _make_ns_state(1, true)
	var launch_player: PlayerState = launch_state.players[0]
	var required_energy := CardInstance.create(_make_energy("基本恶能量", "D"), 0)
	var spare_supporter := CardInstance.create(_make_trainer("席蓝", "Supporter"), 0)
	launch_player.hand.assign([required_energy, spare_supporter])
	var launch_pick: Array = strategy.call("pick_interaction_items", launch_player.hand, {
		"id": "discard_card", "max_select": 1,
	}, {"game_state": launch_state, "player_index": 0})
	return run_checks([
		assert_true(ready_pick.size() == 1 and ready_pick[0] == recoverable_energy, "Trade should seed Darkness Energy for N's PP Up after the Active attacker is funded"),
		assert_true(launch_pick.size() == 1 and launch_pick[0] == spare_supporter, "Trade should preserve the only Darkness Energy that completes the Active DD cost"),
	])


func test_ns_trade_preserves_the_only_real_reversal_energy_id() -> String:
	var strategy := _make_strategy(NS_ZOROARK_DECK_ID)
	var state := _make_ns_state(2, true)
	var player: PlayerState = state.players[0]
	var reversal_data := _load_card("CSV2C_128")
	var reversal := CardInstance.create(reversal_data, 0)
	var spare_supporter := CardInstance.create(_make_trainer("席蓝", "Supporter"), 0)
	player.hand.assign([reversal, spare_supporter])
	var picked: Array = strategy.call("pick_interaction_items", player.hand, {
		"id": "discard_card", "max_select": 1,
	}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_eq(str(reversal_data.effect_id), "cbadb3473273c14cf667d495d44d111b", "The real CSV2C_128 ID should anchor Reversal Energy recognition"),
		assert_true(picked.size() == 1 and picked[0] == spare_supporter, "Trade should preserve the deck's only Reversal Energy"),
		assert_true(
			int(strategy.call("get_discard_priority_contextual", reversal, state, 0)) < int(strategy.call("get_discard_priority_contextual", spare_supporter, state, 0)),
			"The unique Reversal Energy should remain below ordinary Trade discard fuel"
		),
	])


func test_ns_pp_up_and_night_joker_choose_real_attack_routes() -> String:
	var strategy := _make_strategy(NS_ZOROARK_DECK_ID)
	var state := _make_ns_state(2, true)
	var player: PlayerState = state.players[0]
	var zorua: PokemonSlot = player.bench[0]
	var reshiram: PokemonSlot = player.bench[1]
	var darkness := CardInstance.create(_make_energy("基本恶能量", "D"), 0)
	var fighting := CardInstance.create(_make_energy("基本斗能量", "F"), 0)
	var energy_pick: Array = strategy.call("pick_interaction_items", [fighting, darkness], {
		"id": "ns_pp_up_assignment", "max_select": 1,
	}, {"game_state": state, "player_index": 0})
	var zorua_score: float = strategy.call("score_interaction_target", zorua, {
		"id": "ns_pp_up_assignment",
	}, {"game_state": state, "player_index": 0, "assignment_source": darkness})
	var reshiram_score: float = strategy.call("score_interaction_target", reshiram, {
		"id": "ns_pp_up_assignment",
	}, {"game_state": state, "player_index": 0, "assignment_source": darkness})
	var powerful_rage := {
		"source_slot": reshiram,
		"attack": {"name": "力量愤怒", "damage": "20×", "text": ""},
	}
	var virtuous_flame := {
		"source_slot": reshiram,
		"attack": {"name": "纯真火焰", "damage": "170", "text": ""},
	}
	var copied_pick: Array = strategy.call("pick_interaction_items", [powerful_rage, virtuous_flame], {
		"id": "copied_attack", "max_select": 1,
	}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_true(energy_pick.size() == 1 and energy_pick[0] == darkness, "N's PP Up should prefer Darkness Energy that advances a Zoroark route"),
		assert_true(zorua_score > reshiram_score + 1500.0, "N's PP Up should fund the future Zoroark, not its attack-copy source"),
		assert_true(copied_pick.size() == 1 and copied_pick[0] == virtuous_flame, "An undamaged Zoroark should copy the stable 170-damage attack instead of defaulting to Powerful Rage"),
	])


func test_real_ns_card_ids_predict_night_jokers_live_copied_damage() -> String:
	var strategy := _make_strategy(NS_ZOROARK_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var zoroark_data := _load_card("CSV10C_145")
	var reshiram_data := _load_card("CSV10C_166")
	var zoroark := _make_slot(zoroark_data)
	zoroark.attached_energy.assign([
		CardInstance.create(_make_energy("基本恶能量", "D"), 0),
		CardInstance.create(_make_energy("基本恶能量", "D"), 0),
	])
	zoroark.damage_counters = 120
	player.active_pokemon = zoroark
	player.bench.append(_make_slot(reshiram_data))
	strategy.call("build_turn_plan", state, 0, {})
	var rage_prediction: Dictionary = strategy.call("predict_attacker_damage", zoroark)
	zoroark.damage_counters = 20
	strategy.call("build_turn_plan", state, 0, {})
	var flame_prediction: Dictionary = strategy.call("predict_attacker_damage", zoroark)
	player.bench.clear()
	strategy.call("build_turn_plan", state, 0, {})
	var no_source_prediction: Dictionary = strategy.call("predict_attacker_damage", zoroark)
	return run_checks([
		assert_eq(str(zoroark_data.effect_id), "a1742becbf9fdc6a66ddfb1b306c4bc0", "The real CSV10C_145 ID should identify N's Zoroark ex"),
		assert_eq(str(reshiram_data.effect_id), "7ee514e3fb601f1f743a3d329b98daab", "The real CSV10C_166 ID should identify N's Reshiram as a copy source"),
		assert_eq(int(rage_prediction.get("damage", 0)), 240, "Night Joker should predict Powerful Rage from Zoroark's live 120 damage"),
		assert_true(bool(rage_prediction.get("can_attack", false)), "Two Darkness Energy and a real Bench source should make Night Joker live"),
		assert_true(str(rage_prediction.get("description", "")).contains("力量愤怒"), "The prediction should report the copied attack that supplies its damage"),
		assert_eq(int(flame_prediction.get("damage", 0)), 170, "At low damage Night Joker should predict Reshiram's stable Virtuous Flame"),
		assert_false(bool(no_source_prediction.get("can_attack", true)), "Night Joker should not predict a legal attack after its real Bench source leaves play"),
		assert_eq(int(no_source_prediction.get("damage", -1)), 0, "Night Joker without a Bench source should predict zero damage"),
	])


func test_night_joker_is_rejected_without_a_benched_n_attack_source() -> String:
	var strategy := _make_strategy(NS_ZOROARK_DECK_ID)
	var state := _make_ns_state(2, false)
	var player: PlayerState = state.players[0]
	var action := {
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 0,
		"attack_name": "暗夜王牌",
		"projected_damage": 0,
		"projected_knockout": false,
	}
	var blocked_score: float = strategy.call("score_action_absolute", action, state, 0)
	player.bench.append(_make_slot(_make_pokemon("N的莱希拉姆", "Basic", "", [
		{"name": "纯真火焰", "cost": "RRLC", "damage": "170", "text": ""},
	])))
	var live_score: float = strategy.call("score_action_absolute", action, state, 0)
	return run_checks([
		assert_true(blocked_score <= -2000.0, "Night Joker should not be treated as a valid default attack without a copy source"),
		assert_true(live_score >= blocked_score + 4000.0, "A real benched N attack source should reopen the Night Joker route"),
	])


func test_impidimp_draw_attack_outranks_nonlethal_default_chip() -> String:
	var strategy := _make_strategy(MARNIE_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var impidimp := _make_slot(_make_pokemon("玛俐的捣蛋小妖", "Basic", "", [
		{"name": "骗取", "cost": "C", "damage": "", "text": "Draw a card."},
		{"name": "推打", "cost": "D", "damage": "10", "text": ""},
	]))
	player.active_pokemon = impidimp
	for index: int in 10:
		player.deck.append(CardInstance.create(_make_trainer("牌库卡 %d" % index), 0))
	var draw_score: float = strategy.call("score_action_absolute", {
		"kind": "attack", "source_slot": impidimp, "attack_index": 0,
		"attack_name": "骗取", "projected_damage": 0, "projected_knockout": false,
	}, state, 0)
	var chip_score: float = strategy.call("score_action_absolute", {
		"kind": "attack", "source_slot": impidimp, "attack_index": 1,
		"attack_name": "推打", "projected_damage": 10, "projected_knockout": false,
	}, state, 0)
	return assert_true(draw_score >= chip_score + 500.0, "Impidimp setup should draw a card instead of defaulting to nonlethal 10 damage")


func _make_strategy(deck_id: int) -> RefCounted:
	var script: Variant = load(DELEGATE_PATH)
	if not script is GDScript:
		return null
	var strategy: RefCounted = (script as GDScript).new()
	var deck := DeckData.new()
	deck.id = deck_id
	strategy.call("configure_from_deck", deck)
	return strategy


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_ns_state(active_energy_count: int, include_copy_source: bool) -> GameState:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var zoroark := _make_slot(_make_pokemon("N的索罗亚克ex", "Stage 1", "N的索罗亚", [
		{"name": "暗夜王牌", "cost": "DD", "damage": "", "text": "Copy an attack."},
	], [{"name": "交易", "text": "Discard 1 card and draw 2."}]))
	for index: int in active_energy_count:
		zoroark.attached_energy.append(CardInstance.create(_make_energy("基本恶能量 %d" % index, "D"), 0))
	player.active_pokemon = zoroark
	player.bench.append(_make_slot(_make_pokemon("N的索罗亚", "Basic", "", [
		{"name": "抓", "cost": "D", "damage": "20", "text": ""},
	])))
	if include_copy_source:
		player.bench.append(_make_slot(_make_pokemon("N的莱希拉姆", "Basic", "", [
			{"name": "力量愤怒", "cost": "RL", "damage": "20×", "text": ""},
			{"name": "纯真火焰", "cost": "RRLC", "damage": "170", "text": ""},
		])))
	return state


func _make_slot(card_data: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, 0))
	return slot


func _make_pokemon(
	name: String,
	stage: String,
	evolves_from: String,
	attacks: Array[Dictionary],
	abilities: Array[Dictionary] = []
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.name_zh = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.energy_type = "D"
	card.hp = 280 if stage != "Basic" else 70
	card.attacks = attacks
	card.abilities = abilities
	return card


func _make_energy(name: String, provides: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_type = provides
	card.energy_provides = provides
	return card


func _make_trainer(name: String, card_type: String = "Supporter") -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.name_zh = name
	card.card_type = card_type
	return card


func _load_card(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(parsed) if parsed is Dictionary else null
