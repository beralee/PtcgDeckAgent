class_name TestLimitlessNsZoroarkEffects
extends TestBase

const NS_ZOROARK_EFFECT_ID := "cd6639f9c8249c13aa07c7df55836542"
const NS_RESHIRAM_EFFECT_ID := "c4f3e155a1461e7f5e9fbc1cebf833d1"
const NS_PP_UP_EFFECT_ID := "8a0cb1c0955bd7119e71f78b7b529954"
const AttackCopyOwnBenchNamedPokemonAttackScript := preload("res://scripts/effects/pokemon_effects/AttackCopyOwnBenchNamedPokemonAttack.gd")
const CardImplementationStatusScript := preload("res://scripts/engine/CardImplementationStatus.gd")
const DeckStrategyNsZoroarkScript := preload("res://scripts/ai/DeckStrategyNsZoroark.gd")


func test_trade_discards_one_card_and_draws_two() -> String:
	var rig := _make_ns_zoroark_rig()
	var gsm: GameStateMachine = rig["gsm"]
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	var zoroark: PokemonSlot = player.active_pokemon
	var discard_choice: CardInstance = player.hand[0]
	var initial_deck := player.deck.size()

	var can_use := gsm.effect_processor.can_use_ability(zoroark, state, 0)
	var used := gsm.use_ability(0, zoroark, 0, [{"discard_card": [discard_choice]}])
	var can_reuse := gsm.effect_processor.can_use_ability(zoroark, state, 0)

	return run_checks([
		assert_true(can_use, "Trade should be available with a card in hand"),
		assert_true(used, "Trade should execute through GameStateMachine"),
		assert_eq(player.hand.size(), 4, "Trade should discard one card and draw two from a three-card hand"),
		assert_eq(player.deck.size(), initial_deck - 2, "Trade should draw two cards"),
		assert_true(discard_choice in player.discard_pile, "Chosen card should be discarded"),
		assert_false(can_reuse, "Trade should be once per turn"),
	])


func test_night_joker_uses_benched_ns_pokemon_without_discard_fuel() -> String:
	var rig := _make_ns_zoroark_rig()
	var gsm: GameStateMachine = rig["gsm"]
	var state: GameState = gsm.game_state
	var zoroark: PokemonSlot = state.players[0].active_pokemon

	var effects := gsm.effect_processor.get_attack_effects_for_slot(zoroark, 0)
	var copy_effect: BaseEffect = effects[0] if not effects.is_empty() else null
	var steps := copy_effect.get_attack_interaction_steps(zoroark.get_top_card(), zoroark.get_attacks()[0], state)
	var options: Array = steps[0].get("items", []) if not steps.is_empty() else []

	return run_checks([
		assert_not_null(copy_effect, "Night Joker should register an attack effect"),
		assert_eq(steps.size(), 1, "Night Joker should expose Benched N's Pokemon copied-attack options even with no discard fuel"),
		assert_eq(options.size(), 2, "Night Joker should expose every non-recursive attack on Benched N's Reshiram"),
	])


func test_night_joker_matches_normal_chinese_n_benched_source_name() -> String:
	var rig := _make_ns_zoroark_rig()
	var gsm: GameStateMachine = rig["gsm"]
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	var zoroark: PokemonSlot = player.active_pokemon
	var chinese_named_reshiram := _make_ns_reshiram_card()
	chinese_named_reshiram.name = "N" + char(0x7684) + "Reshiram"
	chinese_named_reshiram.name_en = ""
	chinese_named_reshiram.name_zh = chinese_named_reshiram.name
	player.bench.clear()
	player.bench.append(_make_slot(chinese_named_reshiram, 0))

	var effects := gsm.effect_processor.get_attack_effects_for_slot(zoroark, 0)
	var copy_effect: BaseEffect = effects[0] if not effects.is_empty() else null
	var steps := copy_effect.get_attack_interaction_steps(zoroark.get_top_card(), zoroark.get_attacks()[0], state) if copy_effect != null else []
	var options: Array = steps[0].get("items", []) if not steps.is_empty() else []

	return run_checks([
		assert_not_null(copy_effect, "Night Joker should register an attack effect"),
		assert_eq(steps.size(), 1, "Night Joker should recognize a normal Chinese N-prefix Bench source"),
		assert_eq(options.size(), 2, "Night Joker should expose attacks from a normal Chinese-named N's Reshiram"),
	])


func test_night_joker_has_no_options_without_benched_ns_pokemon_even_with_discard_fuel() -> String:
	var rig := _make_ns_zoroark_rig()
	var gsm: GameStateMachine = rig["gsm"]
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	var zoroark: PokemonSlot = player.active_pokemon
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_card("Generic Bench", "Generic Bench", "C", 100, "", "Basic", "", []), 0))
	player.discard_pile.append(CardInstance.create(_make_ns_reshiram_card(), 0))

	var effects := gsm.effect_processor.get_attack_effects_for_slot(zoroark, 0)
	var copy_effect: BaseEffect = effects[0] if not effects.is_empty() else null
	var steps := copy_effect.get_attack_interaction_steps(zoroark.get_top_card(), zoroark.get_attacks()[0], state)

	return run_checks([
		assert_not_null(copy_effect, "Night Joker should register an attack effect"),
		assert_eq(steps.size(), 0, "Night Joker should ignore discarded N's Pokemon when there is no Benched N's Pokemon source"),
	])


func test_night_joker_copies_selected_attack_from_own_benched_ns_pokemon() -> String:
	var rig := _make_ns_zoroark_rig()
	var gsm: GameStateMachine = rig["gsm"]
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	var zoroark: PokemonSlot = player.active_pokemon
	var defender: PokemonSlot = state.players[1].active_pokemon
	zoroark.damage_counters = 30
	var benched_zoroark := _make_slot(_make_ns_zoroark_card(), 0)
	player.bench.append(benched_zoroark)
	gsm.effect_processor.register_pokemon_card(benched_zoroark.get_card_data())

	var effects := gsm.effect_processor.get_attack_effects_for_slot(zoroark, 0)
	var copy_effect: BaseEffect = effects[0] if not effects.is_empty() else null
	var steps := copy_effect.get_attack_interaction_steps(zoroark.get_top_card(), zoroark.get_attacks()[0], state)
	var options: Array = steps[0].get("items", []) if not steps.is_empty() else []
	var labels: Array = steps[0].get("labels", []) if not steps.is_empty() else []
	var action_items: Array = steps[0].get("action_items", []) if not steps.is_empty() else []
	var step_title := str(steps[0].get("title", "")) if not steps.is_empty() else ""
	var selected: Dictionary = options[0] if not options.is_empty() else {}
	var second_option: Dictionary = options[1] if options.size() > 1 and options[1] is Dictionary else {}
	var selected_attack: Dictionary = selected.get("attack", {}) if selected.get("attack", {}) is Dictionary else {}
	var second_attack: Dictionary = second_option.get("attack", {}) if second_option.get("attack", {}) is Dictionary else {}
	var selected_source_card: CardInstance = selected.get("source_card", null) as CardInstance
	var first_action_item: Dictionary = action_items[0] if not action_items.is_empty() and action_items[0] is Dictionary else {}
	var second_action_item: Dictionary = action_items[1] if action_items.size() > 1 and action_items[1] is Dictionary else {}
	var used := gsm.use_attack(0, 0, [{AttackCopyOwnBenchNamedPokemonAttackScript.STEP_ID: [selected]}])

	return run_checks([
		assert_not_null(copy_effect, "Night Joker should register an attack effect"),
		assert_eq(str(steps[0].get("presentation", "")) if not steps.is_empty() else "", "action_hud", "Night Joker should use the action HUD copied-attack UI"),
		assert_str_contains(step_title, "备战区", "Night Joker prompt should describe benched choices"),
		assert_false(step_title.contains("弃牌区"), "Night Joker prompt should not use the obsolete discard-pile wording"),
		assert_eq(options.size(), 2, "Night Joker should expose both attacks from Benched N's Reshiram and skip recursive Night Joker"),
		assert_not_null(selected_source_card, "Night Joker copied option should include the Benched source card like Apex Dragon copied options"),
		assert_eq(str(selected_source_card.card_data.effect_id) if selected_source_card != null and selected_source_card.card_data != null else "", NS_RESHIRAM_EFFECT_ID, "Night Joker source_card should point at the Benched N's Reshiram"),
		assert_eq(str(selected.get("source_effect_id", "")), NS_RESHIRAM_EFFECT_ID, "Night Joker should copy the Benched N's Reshiram"),
		assert_eq(str(selected.get("source_zone", "")), "bench", "Night Joker copied source should be tagged as bench"),
		assert_eq(int(selected.get("attack_index", -1)), 0, "The selected option should preserve the copied attack index"),
		assert_eq(str(selected_attack.get("name", "")), "Powerful Rage", "Night Joker should allow selecting Powerful Rage"),
		assert_eq(int(second_option.get("attack_index", -1)), 1, "Night Joker should allow selecting later attacks, not only the first attack"),
		assert_eq(str(second_attack.get("name", "")), "Virtuous Flame", "Night Joker should expose N's Reshiram's second attack"),
		assert_eq(str(labels[0]) if not labels.is_empty() else "", "N的莱希拉姆 - 强力愤怒", "Night Joker label should use translated source and attack names"),
		assert_eq(str(first_action_item.get("title", "")), "强力愤怒", "Night Joker action HUD title should use the translated copied attack"),
		assert_false(str(first_action_item.get("meta", "")).contains("第1个招式"), "Night Joker action HUD meta should match Apex Dragon source/damage style, not the old first-attack wording"),
		assert_false(str(first_action_item.get("body", "")).contains("弃牌区"), "Night Joker action HUD body should not use the obsolete discard-pile wording"),
		assert_false(str(first_action_item.get("meta", "")).contains("伤害"), "Night Joker action HUD meta should match Apex Dragon source/damage style"),
		assert_str_contains(str(first_action_item.get("body", "")), "伤害指示物", "Night Joker action HUD body should use translated copied attack text"),
		assert_eq(str(first_action_item.get("cost", "")), "RL", "Night Joker action HUD should show Powerful Rage's printed source cost instead of Zoroark's DD cost"),
		assert_eq(str(second_action_item.get("cost", "")), "RRLC", "Night Joker action HUD should show Virtuous Flame's printed source cost"),
		assert_eq(str(second_action_item.get("body", "")), "无额外效果。", "A copied attack without rules text should not repeat Night Joker's own copy description"),
		assert_true(used, "Night Joker should be usable with DD attached"),
		assert_eq(defender.damage_counters, 60, "Copied Powerful Rage should use Zoroark's own 3 damage counters for 60 damage"),
	])


func test_real_csv10c_145_night_joker_hud_uses_benched_source_attack_details() -> String:
	var zoroark_card: CardData = CardDatabase.get_card("CSV10C", "145")
	var reshiram_card: CardData = CardDatabase.get_card("CSV10C", "166")
	if zoroark_card == null or reshiram_card == null:
		return "CSV10C_145 or CSV10C_166 fixture missing"
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 2
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	var zoroark := _make_slot(zoroark_card, 0)
	var reshiram := _make_slot(reshiram_card, 0)
	state.players[0].active_pokemon = zoroark
	state.players[0].bench.append(reshiram)
	gsm.game_state = state
	gsm.effect_processor.register_pokemon_card(zoroark_card)
	gsm.effect_processor.register_pokemon_card(reshiram_card)
	var effects := gsm.effect_processor.get_attack_effects_for_slot(zoroark, 0)
	var copy_effect: BaseEffect = effects[0] if not effects.is_empty() else null
	var steps: Array[Dictionary] = copy_effect.get_attack_interaction_steps(
		zoroark.get_top_card(),
		zoroark.get_attacks()[0],
		state
	) if copy_effect != null else []
	var action_items: Array = steps[0].get("action_items", []) if not steps.is_empty() else []
	var powerful_rage: Dictionary = action_items[0] if not action_items.is_empty() and action_items[0] is Dictionary else {}
	var virtuous_flame: Dictionary = action_items[1] if action_items.size() > 1 and action_items[1] is Dictionary else {}

	return run_checks([
		assert_not_null(copy_effect, "Real CSV10C_145 should register Night Joker's Bench copy effect"),
		assert_eq(action_items.size(), 2, "Real CSV10C_166 should contribute both printed attacks to Night Joker's HUD"),
		assert_eq(str(powerful_rage.get("title", "")), "力量愤怒", "HUD should show the Benched source attack name"),
		assert_eq(str(powerful_rage.get("cost", "")), "RL", "HUD should show Powerful Rage's printed cost instead of Night Joker's DD"),
		assert_eq(str(powerful_rage.get("meta", "")), "N的莱希拉姆  20×", "HUD should show the source Pokemon and printed damage"),
		assert_str_contains(str(powerful_rage.get("body", "")), "伤害指示物", "HUD should show Powerful Rage's detailed effect text"),
		assert_eq(str(virtuous_flame.get("title", "")), "纯真火焰", "HUD should show the second Benched source attack name"),
		assert_eq(str(virtuous_flame.get("cost", "")), "RRLC", "HUD should show Pure Flame's printed source cost"),
		assert_eq(str(virtuous_flame.get("body", "")), "无额外效果。", "A source attack without rules text should show an explicit empty detail"),
	])


func test_real_len_jtg_98_registers_effect_id_override_for_bench_copy_ui() -> String:
	var card: CardData = CardDatabase.get_card("LEN_JTG", "98")
	var reshiram: CardData = CardDatabase.get_card("LEN_JTG", "116")
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	gsm.game_state = state

	var zoroark := _make_slot(card, 0) if card != null else null
	var bench_reshiram := _make_slot(reshiram, 0) if reshiram != null else null
	if zoroark != null:
		state.players[0].active_pokemon = zoroark
	if bench_reshiram != null:
		state.players[0].bench.append(bench_reshiram)
	if card != null:
		gsm.effect_processor.register_pokemon_card(card)
	if reshiram != null:
		gsm.effect_processor.register_pokemon_card(reshiram)

	var effects := gsm.effect_processor.get_attack_effects_for_slot(zoroark, 0) if zoroark != null else []
	var copy_effect: BaseEffect = effects[0] if not effects.is_empty() else null
	var steps := copy_effect.get_attack_interaction_steps(zoroark.get_top_card(), zoroark.get_attacks()[0], state) if copy_effect != null else []
	var options: Array = steps[0].get("items", []) if not steps.is_empty() else []
	var selected: Dictionary = options[0] if not options.is_empty() and options[0] is Dictionary else {}
	var source_card: CardInstance = selected.get("source_card", null) as CardInstance

	return run_checks([
		assert_not_null(card, "Real LEN_JTG_98 should load through CardDatabase"),
		assert_not_null(reshiram, "Real LEN_JTG_116 should load through CardDatabase"),
		assert_eq(copy_effect.get_script() if copy_effect != null else null, AttackCopyOwnBenchNamedPokemonAttackScript, "Real LEN_JTG_98 should register the Benched N's Pokemon copy effect by effect_id"),
		assert_eq(steps.size(), 1, "Real LEN_JTG_98 should expose Benched N's Pokemon copied-attack options"),
		assert_eq(str(selected.get("source_zone", "")), "bench", "Real Night Joker options should be sourced from Bench"),
		assert_eq(str(source_card.card_data.effect_id) if source_card != null and source_card.card_data != null else "", NS_RESHIRAM_EFFECT_ID, "Real Night Joker option should include the Benched source card"),
		assert_false(str(selected.get("source_zone", "")) == "discard", "Real Night Joker should not use the old discard-source option"),
	])


func test_real_len_jtg_116_powerful_rage_20x_has_no_printed_base_damage() -> String:
	var reshiram: CardData = CardDatabase.get_card("LEN_JTG", "116")
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	gsm.game_state = state

	var attacker := _make_slot(reshiram, 0) if reshiram != null else null
	if attacker != null:
		attacker.attached_energy.append(CardInstance.create(_make_energy_card("Fire Energy", "R"), 0))
		attacker.attached_energy.append(CardInstance.create(_make_energy_card("Lightning Energy", "L"), 0))
		state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target", "Target", "C", 300, "", "Basic", "", []), 1)
	if reshiram != null:
		gsm.effect_processor.register_pokemon_card(reshiram)

	var attack: Dictionary = reshiram.attacks[0] if reshiram != null and not reshiram.attacks.is_empty() and reshiram.attacks[0] is Dictionary else {}
	var zero_counter_preview := gsm.get_attack_preview_damage(0, 0)
	if attacker != null:
		attacker.damage_counters = 30
	var three_counter_preview := gsm.get_attack_preview_damage(0, 0)
	var used := gsm.use_attack(0, 0)
	var defender_damage := state.players[1].active_pokemon.damage_counters if state.players[1].active_pokemon != null else -1

	return run_checks([
		assert_not_null(reshiram, "Real LEN_JTG_116 should load through CardDatabase"),
		assert_eq(str(attack.get("name", "")), "Powerful Rage", "Real LEN_JTG_116 first attack should be Powerful Rage"),
		assert_eq(str(attack.get("damage", "")), "20x", "Real Powerful Rage should keep its printed 20x damage text"),
		assert_str_contains(str(attack.get("text", "")), "20 damage for each damage counter", "Real Powerful Rage text should describe per-counter damage"),
		assert_eq(zero_counter_preview, 0, "Powerful Rage should deal 0 damage with no damage counters"),
		assert_eq(three_counter_preview, 60, "Powerful Rage should deal 60 damage with 3 damage counters"),
		assert_true(used, "Real Powerful Rage should execute with Fire and Lightning Energy attached"),
		assert_eq(defender_damage, 60, "Real Powerful Rage live damage should be 60 with 3 damage counters"),
	])


func test_real_len_jtg_98_night_joker_copies_real_powerful_rage_20x_without_base_damage() -> String:
	var zoroark_card: CardData = CardDatabase.get_card("LEN_JTG", "98")
	var reshiram: CardData = CardDatabase.get_card("LEN_JTG", "116")
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	gsm.game_state = state

	var zoroark := _make_slot(zoroark_card, 0) if zoroark_card != null else null
	var bench_reshiram := _make_slot(reshiram, 0) if reshiram != null else null
	if zoroark != null:
		zoroark.attached_energy.append(CardInstance.create(_make_energy_card("Darkness Energy", "D"), 0))
		zoroark.attached_energy.append(CardInstance.create(_make_energy_card("Darkness Energy", "D"), 0))
		zoroark.damage_counters = 30
		state.players[0].active_pokemon = zoroark
	if bench_reshiram != null:
		state.players[0].bench.append(bench_reshiram)
	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target", "Target", "C", 300, "", "Basic", "", []), 1)
	if zoroark_card != null:
		gsm.effect_processor.register_pokemon_card(zoroark_card)
	if reshiram != null:
		gsm.effect_processor.register_pokemon_card(reshiram)

	var effects := gsm.effect_processor.get_attack_effects_for_slot(zoroark, 0) if zoroark != null else []
	var copy_effect: BaseEffect = effects[0] if not effects.is_empty() else null
	var steps := copy_effect.get_attack_interaction_steps(zoroark.get_top_card(), zoroark.get_attacks()[0], state) if copy_effect != null else []
	var options: Array = steps[0].get("items", []) if not steps.is_empty() else []
	var selected: Dictionary = {}
	for option_raw: Variant in options:
		if not (option_raw is Dictionary):
			continue
		var option := option_raw as Dictionary
		var option_attack: Dictionary = option.get("attack", {}) if option.get("attack", {}) is Dictionary else {}
		if str(option_attack.get("name", "")) == "Powerful Rage":
			selected = option
			break
	var used := gsm.use_attack(0, 0, [{AttackCopyOwnBenchNamedPokemonAttackScript.STEP_ID: [selected]}])
	var defender_damage := state.players[1].active_pokemon.damage_counters if state.players[1].active_pokemon != null else -1

	return run_checks([
		assert_not_null(zoroark_card, "Real LEN_JTG_98 should load through CardDatabase"),
		assert_not_null(reshiram, "Real LEN_JTG_116 should load through CardDatabase"),
		assert_false(selected.is_empty(), "Night Joker should expose real Powerful Rage as a selectable copied attack"),
		assert_true(used, "Night Joker should execute after selecting real Powerful Rage"),
		assert_eq(defender_damage, 60, "Night Joker copying real Powerful Rage should use Zoroark's 3 damage counters for 60 damage"),
	])


func test_ns_pp_up_attaches_basic_energy_to_benched_ns_pokemon_only() -> String:
	var rig := _make_ns_zoroark_rig()
	var gsm: GameStateMachine = rig["gsm"]
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	var pp_up := CardInstance.create(_make_ns_pp_up_card(), 0)
	var energy := CardInstance.create(_make_energy_card("Darkness Energy", "D"), 0)
	player.discard_pile.append(energy)
	var target: PokemonSlot = player.bench[0]
	var non_ns_before := player.bench[1].attached_energy.size()

	var effect: BaseEffect = gsm.effect_processor.get_effect(NS_PP_UP_EFFECT_ID)
	var can_execute := effect.can_execute(pp_up, state)
	effect.execute(pp_up, [{
		"ns_pp_up_assignment": [{
			"source": energy,
			"target": target,
		}],
	}], state)

	return run_checks([
		assert_true(can_execute, "N's PP Up should be playable with Basic Energy in discard and an N's bench target"),
		assert_false(energy in player.discard_pile, "Selected energy should leave discard"),
		assert_true(energy in target.attached_energy, "Selected energy should attach to the selected N's Pokemon"),
		assert_eq(player.bench[1].attached_energy.size(), non_ns_before, "Non-N's bench Pokemon should not receive fallback energy"),
	])


func test_ns_pp_up_cannot_execute_without_benched_ns_target() -> String:
	var rig := _make_ns_zoroark_rig()
	var gsm: GameStateMachine = rig["gsm"]
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_card("Generic Bench", "Generic Bench", "C", 100, "", "Basic", "", []), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_card("Darkness Energy", "D"), 0))
	var pp_up := CardInstance.create(_make_ns_pp_up_card(), 0)
	var effect: BaseEffect = gsm.effect_processor.get_effect(NS_PP_UP_EFFECT_ID)

	return assert_false(effect.can_execute(pp_up, state), "N's PP Up should fail closed when there is no Benched N's Pokemon target")


func test_ns_zoroark_key_cards_are_implemented() -> String:
	CardImplementationStatusScript.clear_cache()
	var zoroark := _make_ns_zoroark_card()
	var reshiram := _make_ns_reshiram_card()
	var pp_up := _make_ns_pp_up_card()
	return run_checks([
		assert_false(CardImplementationStatusScript.is_unimplemented(zoroark), "N's Zoroark ex should register Trade and Night Joker"),
		assert_false(CardImplementationStatusScript.is_unimplemented(reshiram), "N's Reshiram should register Powerful Rage"),
		assert_false(CardImplementationStatusScript.is_unimplemented(pp_up), "N's PP Up should register its Item effect"),
	])


func test_ns_zoroark_strategy_preserves_reshiram_as_benched_night_joker_source() -> String:
	var rig := _make_ns_zoroark_rig()
	var gsm: GameStateMachine = rig["gsm"]
	var state: GameState = gsm.game_state
	var strategy := DeckStrategyNsZoroarkScript.new()
	var reshiram := CardInstance.create(_make_ns_reshiram_card(), 0)
	var darkness := CardInstance.create(_make_energy_card("Darkness Energy", "D"), 0)
	var generic := CardInstance.create(_make_pokemon_card("Generic", "Generic", "C", 60, "", "Basic", "", []), 0)
	var reshiram_priority: int = strategy.get_discard_priority_contextual(reshiram, state, 0)
	var darkness_priority: int = strategy.get_discard_priority_contextual(darkness, state, 0)
	var generic_priority: int = strategy.get_discard_priority_contextual(generic, state, 0)

	return run_checks([
		assert_gt(darkness_priority, reshiram_priority, "Darkness Energy should be discarded before N's Reshiram because Night Joker copies Benched N's Pokemon"),
		assert_gt(generic_priority, reshiram_priority, "Generic filler should be discarded before N's Reshiram so Reshiram can stay benched as Night Joker source"),
	])


func test_ns_zoroark_strategy_preserves_real_reversal_energy_by_effect_id() -> String:
	var rig := _make_ns_zoroark_rig()
	var state: GameState = (rig["gsm"] as GameStateMachine).game_state
	var player: PlayerState = state.players[0]
	var strategy := DeckStrategyNsZoroarkScript.new()
	var reversal_data: CardData = CardDatabase.get_card("CSV2C", "128")
	if reversal_data == null:
		return "CSV2C_128 fixture missing"
	var id_only_data := reversal_data.duplicate(true) as CardData
	id_only_data.name = "ID-only special Energy"
	id_only_data.name_en = ""
	id_only_data.name_zh = ""
	var reversal := CardInstance.create(id_only_data, 0)
	var filler := CardInstance.create(_make_pokemon_card("Trade Fuel", "Trade Fuel", "C", 60, "", "Basic", "", []), 0)
	player.hand.assign([reversal, filler])
	var reversal_priority: int = strategy.get_discard_priority_contextual(reversal, state, 0)
	var filler_priority: int = strategy.get_discard_priority_contextual(filler, state, 0)

	return run_checks([
		assert_eq(str(reversal_data.effect_id), "cbadb3473273c14cf667d495d44d111b", "The real CSV2C_128 effect ID should anchor Reversal Energy recognition"),
		assert_true(reversal_priority < filler_priority, "Trade should preserve the only Reversal Energy even when only its real effect ID identifies it"),
	])


func test_ns_zoroark_strategy_trade_protects_the_only_manual_darkness_energy() -> String:
	var rig := _make_ns_zoroark_rig()
	var state: GameState = (rig["gsm"] as GameStateMachine).game_state
	var player: PlayerState = state.players[0]
	var strategy := DeckStrategyNsZoroarkScript.new()
	player.bench.append(_make_slot(_make_ns_zorua_card(), 0))
	var recoverable_energy := CardInstance.create(_make_energy_card("基本恶能量", "D"), 0)
	var ready_filler := CardInstance.create(_make_pokemon_card("Ready Fuel", "Ready Fuel", "C", 60, "", "Basic", "", []), 0)
	player.hand.assign([recoverable_energy, ready_filler])
	var recoverable_priority: int = strategy.get_discard_priority_contextual(recoverable_energy, state, 0)
	var ready_filler_priority: int = strategy.get_discard_priority_contextual(ready_filler, state, 0)

	player.active_pokemon.attached_energy.resize(1)
	var required_energy := CardInstance.create(_make_energy_card("基本恶能量", "D"), 0)
	var launch_filler := CardInstance.create(_make_pokemon_card("Launch Fuel", "Launch Fuel", "C", 60, "", "Basic", "", []), 0)
	player.hand.assign([required_energy, launch_filler])
	var required_priority: int = strategy.get_discard_priority_contextual(required_energy, state, 0)
	var launch_filler_priority: int = strategy.get_discard_priority_contextual(launch_filler, state, 0)

	return run_checks([
		assert_gt(recoverable_priority, ready_filler_priority, "Trade should seed a recoverable Darkness Energy after the Active Zoroark is funded"),
		assert_true(required_priority < launch_filler_priority, "Trade should preserve the only Darkness Energy that completes the Active Zoroark's DD cost"),
	])


func test_ns_zoroark_strategy_predicts_and_selects_real_benched_n_attacks() -> String:
	var rig := _make_ns_zoroark_rig()
	var state: GameState = (rig["gsm"] as GameStateMachine).game_state
	var player: PlayerState = state.players[0]
	var strategy := DeckStrategyNsZoroarkScript.new()
	var zoroark_data: CardData = CardDatabase.get_card("CSV10C", "145")
	var reshiram_data: CardData = CardDatabase.get_card("CSV10C", "166")
	if zoroark_data == null or reshiram_data == null:
		return "CSV10C_145 or CSV10C_166 fixture missing"
	var zoroark := _make_slot(zoroark_data, 0)
	zoroark.attached_energy.assign([
		CardInstance.create(_make_energy_card("基本恶能量", "D"), 0),
		CardInstance.create(_make_energy_card("基本恶能量", "D"), 0),
	])
	var reshiram := _make_slot(reshiram_data, 0)
	player.active_pokemon = zoroark
	player.bench.assign([reshiram])
	zoroark.damage_counters = 120
	strategy.build_turn_plan(state, 0, {})
	var rage_prediction: Dictionary = strategy.predict_attacker_damage(zoroark)
	var rage_option := {"source_slot": reshiram, "attack": reshiram.get_attacks()[0]}
	var flame_option := {"source_slot": reshiram, "attack": reshiram.get_attacks()[1]}
	var rage_score: float = strategy.score_interaction_target(rage_option, {"id": "copied_attack"}, {"game_state": state, "player_index": 0})
	var flame_score_at_high_damage: float = strategy.score_interaction_target(flame_option, {"id": "copied_attack"}, {"game_state": state, "player_index": 0})

	zoroark.damage_counters = 20
	strategy.build_turn_plan(state, 0, {})
	var flame_prediction: Dictionary = strategy.predict_attacker_damage(zoroark)
	var rage_score_at_low_damage: float = strategy.score_interaction_target(rage_option, {"id": "copied_attack"}, {"game_state": state, "player_index": 0})
	var flame_score: float = strategy.score_interaction_target(flame_option, {"id": "copied_attack"}, {"game_state": state, "player_index": 0})
	player.bench.clear()
	strategy.build_turn_plan(state, 0, {})
	var no_source_prediction: Dictionary = strategy.predict_attacker_damage(zoroark)

	return run_checks([
		assert_eq(int(rage_prediction.get("damage", 0)), 240, "Night Joker should predict Powerful Rage from Zoroark's live 120 damage"),
		assert_true(bool(rage_prediction.get("can_attack", false)), "Two Darkness Energy plus a real Benched N attack source should make Night Joker live"),
		assert_str_contains(str(rage_prediction.get("description", "")), str(reshiram.get_attacks()[0].get("name", "")), "The prediction should identify the copied attack"),
		assert_gt(rage_score, flame_score_at_high_damage, "At 120 damage, Night Joker AI should choose the stronger live Powerful Rage copy"),
		assert_eq(int(flame_prediction.get("damage", 0)), 170, "At low damage, Night Joker should predict the stable real Reshiram attack"),
		assert_gt(flame_score, rage_score_at_low_damage, "At low damage, Night Joker AI should choose the stable 170-damage copy"),
		assert_false(bool(no_source_prediction.get("can_attack", true)), "Night Joker should not predict a legal attack after its real Bench source leaves play"),
		assert_eq(int(no_source_prediction.get("damage", -1)), 0, "Night Joker without a Benched N attack source should predict zero damage"),
	])


func _make_ns_zoroark_rig() -> Dictionary:
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()

	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)

	var player0: PlayerState = state.players[0]
	var player1: PlayerState = state.players[1]
	var zoroark := _make_slot(_make_ns_zoroark_card(), 0)
	zoroark.attached_energy.append(CardInstance.create(_make_energy_card("Darkness Energy", "D"), 0))
	zoroark.attached_energy.append(CardInstance.create(_make_energy_card("Darkness Energy", "D"), 0))
	player0.active_pokemon = zoroark
	player0.bench.append(_make_slot(_make_ns_reshiram_card(), 0))
	player0.bench.append(_make_slot(_make_pokemon_card("Generic Bench", "Generic Bench", "C", 100, "", "Basic", "", []), 0))
	for i: int in 3:
		player0.hand.append(CardInstance.create(_make_pokemon_card("Hand %d" % i, "Hand %d" % i, "C", 60, "", "Basic", "", []), 0))
	for i: int in 5:
		player0.deck.append(CardInstance.create(_make_pokemon_card("Deck %d" % i, "Deck %d" % i, "C", 60, "", "Basic", "", []), 0))

	player1.active_pokemon = _make_slot(_make_pokemon_card("Target", "Target", "C", 300, "", "Basic", "", []), 1)

	gsm.game_state = state
	gsm.effect_processor.register_pokemon_card(zoroark.get_card_data())
	gsm.effect_processor.register_pokemon_card(player0.bench[0].get_card_data())
	return {
		"gsm": gsm,
	}


func _make_ns_zoroark_card() -> CardData:
	var cd := _make_pokemon_card(
		"N's Zoroark ex",
		"N's Zoroark ex",
		"D",
		280,
		NS_ZOROARK_EFFECT_ID,
		"Stage 1",
		"ex",
		[{"name": "Trade", "text": "You must discard a card from your hand in order to use this Ability. Once during your turn, you may draw 2 cards."}]
	, [
		{"name": "Night Joker", "name_zh": "暗夜小丑", "cost": "DD", "damage": "0", "text": "Choose 1 of your Benched N's Pokemon's attacks and use it as this attack.", "text_zh": "选择自己备战区的1只N的宝可梦拥有的1个招式，作为这个招式使用。", "is_vstar_power": false},
	])
	cd.name_zh = "N的索罗亚克ex"
	return cd


func _make_ns_zorua_card() -> CardData:
	var cd := _make_pokemon_card(
		"N's Zorua",
		"N's Zorua",
		"D",
		70,
		"",
		"Basic",
		"",
		[],
		[{"name": "Scratch", "name_zh": "抓", "cost": "D", "damage": "20", "text": "", "is_vstar_power": false}]
	)
	cd.name_zh = "N的索罗亚"
	return cd


func _make_ns_reshiram_card() -> CardData:
	var cd := _make_pokemon_card(
		"N's Reshiram",
		"N's Reshiram",
		"N",
		130,
		NS_RESHIRAM_EFFECT_ID,
		"Basic",
		"",
		[],
		[
			{"name": "Powerful Rage", "name_zh": "强力愤怒", "cost": "RL", "damage": "20x", "text": "This attack does 20 damage for each damage counter on this Pokemon.", "text_zh": "造成这只宝可梦身上放置的伤害指示物的数量x20点伤害。", "is_vstar_power": false},
			{"name": "Virtuous Flame", "name_zh": "高洁火焰", "cost": "RRLC", "damage": "170", "text": "", "is_vstar_power": false},
		]
	)
	cd.name_zh = "N的莱希拉姆"
	return cd


func _make_ns_pp_up_card() -> CardData:
	var cd := CardData.new()
	cd.name = "N's PP Up"
	cd.name_en = "N's PP Up"
	cd.card_type = "Item"
	cd.effect_id = NS_PP_UP_EFFECT_ID
	cd.description = "Attach a Basic Energy card from your discard pile to 1 of your Benched N's Pokemon."
	return cd


func _make_pokemon_card(
	name: String,
	name_en: String,
	energy_type: String,
	hp: int,
	effect_id: String = "",
	stage: String = "Basic",
	mechanic: String = "",
	abilities: Array = [],
	attacks: Array = []
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name_en
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.mechanic = mechanic
	cd.effect_id = effect_id
	cd.abilities.clear()
	for ability: Variant in abilities:
		if ability is Dictionary:
			cd.abilities.append((ability as Dictionary).duplicate(true))
	cd.attacks.clear()
	for attack: Variant in attacks:
		if attack is Dictionary:
			cd.attacks.append((attack as Dictionary).duplicate(true))
	return cd


func _make_energy_card(name: String, energy: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot
