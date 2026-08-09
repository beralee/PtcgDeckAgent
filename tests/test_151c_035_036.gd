class_name Test151C035036
extends TestBase

const CLEFAIRY_EFFECT_ID := "03b4239cd2061eb23b13824b7b6cc7b8"
const CLEFABLE_EFFECT_ID := "cae24aba46134427b6c27356344dab57"
const SEARCH_STEP_ID := "bombirdier_fast_carrier"
const SWITCH_STEP_ID := "opponent_switch_target"


func test_cards_preserve_tcg_mik_identity_text_and_evolution_metadata() -> String:
	var clefairy: CardData = CardDatabase.get_card("151C", "035")
	var clefable: CardData = CardDatabase.get_card("151C", "036")
	if clefairy == null or clefable == null:
		return run_checks([
			assert_not_null(clefairy, "151C_035 Clefairy should be bundled"),
			assert_not_null(clefable, "151C_036 Clefable should be bundled"),
		])
	return run_checks([
		assert_eq(clefairy.name, "皮皮", "151C_035 should preserve the Chinese card name"),
		assert_eq(clefairy.name_en, "Clefairy", "151C_035 should preserve the English card name"),
		assert_eq(clefairy.stage, "Basic", "151C_035 should remain a Basic Pokemon"),
		assert_eq(clefairy.effect_id, CLEFAIRY_EFFECT_ID, "151C_035 should preserve the source effect id"),
		assert_eq(str(clefairy.attacks[0].get("name", "")), "赏月邀请", "151C_035 first attack should be Moon-Watching Invitation"),
		assert_eq(str(clefairy.attacks[1].get("damage", "")), "20", "151C_035 Palm Slap should deal 20 damage"),
		assert_eq(clefable.name, "皮可西", "151C_036 should preserve the Chinese card name"),
		assert_eq(clefable.name_en, "Clefable", "151C_036 should preserve the English card name"),
		assert_eq(clefable.stage, "Stage 1", "151C_036 should remain a Stage 1 Pokemon"),
		assert_eq(clefable.evolves_from, "皮皮", "151C_036 should evolve from Clefairy"),
		assert_eq(clefable.effect_id, CLEFABLE_EFFECT_ID, "151C_036 should preserve the source effect id"),
		assert_eq(str(clefable.attacks[0].get("name", "")), "看我嘛", "151C_036 first attack should be Look at Me"),
		assert_eq(str(clefable.attacks[1].get("damage", "")), "50", "151C_036 Additional Moon should deal 50 damage"),
	])


func test_clefairy_search_shows_full_deck_and_benches_only_selected_clefairy() -> String:
	var clefairy: CardData = CardDatabase.get_card("151C", "035")
	if clefairy == null:
		return assert_not_null(clefairy, "151C_035 Clefairy should be bundled")
	var state := _state()
	var player: PlayerState = state.players[0]
	var attacker := _slot(clefairy, 0)
	player.active_pokemon = attacker
	var selected := CardInstance.create(clefairy, 0)
	var unselected := CardInstance.create(clefairy, 0)
	var third_clefairy := CardInstance.create(clefairy, 0)
	var illegal_basic := CardInstance.create(_pokemon("皮卡丘", "Pikachu"), 0)
	var illegal_item := CardInstance.create(_trainer("高级球"), 0)
	player.deck = [illegal_item, selected, illegal_basic, unselected, third_clefairy]

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(clefairy)
	var first_effects := processor.get_attack_effects_for_slot(attacker, 0)
	var second_effects := processor.get_attack_effects_for_slot(attacker, 1)
	var steps: Array[Dictionary] = []
	for effect: BaseEffect in first_effects:
		steps.append_array(effect.get_attack_interaction_steps(attacker.get_top_card(), clefairy.attacks[0], state))
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [{SEARCH_STEP_ID: [selected]}])

	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var benched_top: CardInstance = player.bench[0].get_top_card() if not player.bench.is_empty() else null
	return run_checks([
		assert_eq(first_effects.size(), 1, "Clefairy's first attack should register one named search effect"),
		assert_eq(second_effects.size(), 0, "Clefairy's vanilla second attack should not inherit the search effect"),
		assert_eq(steps.size(), 1, "Clefairy's search attack should expose one interaction step"),
		assert_eq(str(step.get("id", "")), SEARCH_STEP_ID, "Clefairy's search should use the shared full-library step"),
		assert_true(str(step.get("title", "")).contains("皮皮"), "Clefairy's search title should state its name restriction"),
		assert_eq(str(step.get("visible_scope", "")), "own_full_deck", "Clefairy's search should reveal the full own deck to its owner"),
		assert_eq((step.get("card_items", []) as Array).size(), 5, "The search UI should show legal and illegal deck cards"),
		assert_eq((step.get("items", []) as Array).size(), 3, "Only cards named Clefairy should be selectable"),
		assert_eq(int(step.get("max_select", -1)), 3, "Clefairy should allow up to three selections when Bench space permits"),
		assert_eq(player.bench.size(), 1, "The selected Clefairy should be put onto the Bench"),
		assert_eq(benched_top, selected, "The explicitly selected Clefairy should be Benched"),
		assert_contains(player.deck, unselected, "An unselected Clefairy should stay in the deck"),
		assert_contains(player.deck, third_clefairy, "Other unselected Clefairy cards should stay in the deck"),
		assert_contains(player.deck, illegal_basic, "A differently named Basic Pokemon should stay in the deck"),
		assert_contains(player.deck, illegal_item, "A Trainer card should stay in the deck"),
	])


func test_clefairy_search_respects_explicit_whiff_and_full_bench() -> String:
	var clefairy: CardData = CardDatabase.get_card("151C", "035")
	if clefairy == null:
		return assert_not_null(clefairy, "151C_035 Clefairy should be bundled")
	var state := _state()
	var player: PlayerState = state.players[0]
	var attacker := _slot(clefairy, 0)
	player.active_pokemon = attacker
	var candidate := CardInstance.create(clefairy, 0)
	player.deck = [candidate]
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(clefairy)
	var effects := processor.get_attack_effects_for_slot(attacker, 0)
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [{SEARCH_STEP_ID: []}])
	var bench_after_whiff := player.bench.size()
	for i: int in 5:
		player.bench.append(_slot(_pokemon("Bench %d" % i), 0))
	var steps: Array[Dictionary] = []
	for effect: BaseEffect in effects:
		steps.append_array(effect.get_attack_interaction_steps(attacker.get_top_card(), clefairy.attacks[0], state))
	return run_checks([
		assert_eq(effects.size(), 1, "Clefairy's first attack should register its named search effect"),
		assert_eq(bench_after_whiff, 0, "An explicit hidden-search whiff should Bench no Pokemon"),
		assert_contains(player.deck, candidate, "An explicit whiff should leave Clefairy in the deck"),
		assert_eq(steps.size(), 0, "A full Bench should suppress Clefairy's search interaction"),
	])


func test_clefable_first_attack_is_attacker_chosen_gust_and_second_attack_marks_extra_prize() -> String:
	var clefable: CardData = CardDatabase.get_card("151C", "036")
	if clefable == null:
		return assert_not_null(clefable, "151C_036 Clefable should be bundled")
	var state := _state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var attacker := _slot(clefable, 0)
	player.active_pokemon = attacker
	var old_active := opponent.active_pokemon
	var unselected := _slot(_pokemon("Opponent Bench A"), 1)
	var selected := _slot(_pokemon("Opponent Bench B"), 1)
	opponent.bench = [unselected, selected]

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(clefable)
	var first_effects := processor.get_attack_effects_for_slot(attacker, 0)
	var second_effects := processor.get_attack_effects_for_slot(attacker, 1)
	var steps: Array[Dictionary] = []
	for effect: BaseEffect in first_effects:
		steps.append_array(effect.get_attack_interaction_steps(attacker.get_top_card(), clefable.attacks[0], state))
	processor.execute_attack_effect(attacker, 0, old_active, state, [{SWITCH_STEP_ID: [selected]}])
	var prize_target := _slot(_pokemon("Prize Target"), 1)
	processor.execute_attack_effect(attacker, 1, prize_target, state)
	var extra_prize_markers := prize_target.effects.filter(
		func(effect: Dictionary) -> bool: return str(effect.get("type", "")) == "extra_prize"
	)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	return run_checks([
		assert_eq(first_effects.size(), 1, "Clefable's first attack should register one switch effect"),
		assert_eq(second_effects.size(), 1, "Clefable's second attack should register one extra-prize effect"),
		assert_eq(steps.size(), 1, "Clefable's first attack should expose one Bench target choice"),
		assert_eq(str(step.get("id", "")), SWITCH_STEP_ID, "Clefable should use the shared opponent Bench target step"),
		assert_false(bool(step.get("opponent_chooses", true)), "Clefable's attacker should choose the opposing Benched Pokemon"),
		assert_eq(opponent.active_pokemon, selected, "The selected opposing Benched Pokemon should become Active"),
		assert_contains(opponent.bench, old_active, "The old opposing Active Pokemon should move to the Bench"),
		assert_contains(opponent.bench, unselected, "The unselected opposing Benched Pokemon should remain Benched"),
		assert_eq(extra_prize_markers.size(), 1, "Clefable's second attack should mark its defender for one extra Prize on KO"),
		assert_eq(int(extra_prize_markers[0].get("count", 0)) if not extra_prize_markers.is_empty() else 0, 1, "Additional Moon should grant exactly one extra Prize"),
	])


func _state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _slot(_pokemon("Active %d" % player_index), player_index)
		state.players.append(player)
	return state


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _pokemon(name: String, name_en: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 100
	card.energy_type = "P"
	return card


func _trainer(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return card
