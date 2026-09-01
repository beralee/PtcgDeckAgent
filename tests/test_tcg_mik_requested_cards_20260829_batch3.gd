class_name TestTcgMikRequestedCards20260829Batch3
extends TestBase

const TREASURE_TRACKER_EFFECT_ID := "c0ea20d42e8e30a99c2a2430843a7b26"
const CRABOMINABLE_EFFECT_ID := "13f57c90c23bf4118291353727093eff"
const VELUZA_EFFECT_ID := "5a7b30386f52c19ae6ceb2c9ae905f84"
const AILegalActionBuilderScript := preload("res://scripts/ai/AILegalActionBuilder.gd")


func test_csv95c166_treasure_tracker_full_library_visibility_and_tool_filter_are_exact() -> String:
	var card_data := _load_card("CSV9.5C", "166")
	if card_data == null:
		return assert_not_null(card_data, "CSV9.5C_166 should load")
	var processor := EffectProcessor.new()
	var state := _state()
	var tracker := CardInstance.create(card_data, 0)
	var tools: Array[CardInstance] = []
	for index: int in 6:
		tools.append(_trainer("Tool %d" % index, "Tool", 0))
	var item := _trainer("Visible Item", "Item", 0)
	var pokemon := CardInstance.create(_pokemon("Visible Pokemon", 80), 0)
	state.players[0].deck.assign(tools + [item, pokemon])
	state.players[0].hand = [tracker]
	var effect := processor.get_effect(TREASURE_TRACKER_EFFECT_ID)
	var steps: Array = effect.get_interaction_steps(tracker, state) if effect != null else []
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var trainer_action := _find_trainer_action(AILegalActionBuilderScript.new().build_actions(gsm, 0), tracker)
	state.players[0].hand.clear()
	if effect != null:
		processor.execute_card_effect(tracker, [{"search_cards": tools.slice(0, 5)}], state)
	var decline_state := _state()
	var decline_tracker := CardInstance.create(card_data, 0)
	decline_state.players[0].deck.assign([_trainer("Decline Tool", "Tool", 0), _trainer("Decline Item", "Item", 0)])
	var decline_effect := EffectProcessor.new()
	decline_effect.execute_card_effect(decline_tracker, [{"search_cards": []}], decline_state)
	return run_checks([
		assert_not_null(effect, "Treasure Tracker should register by its API effect id"),
		assert_eq(str(step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Treasure Tracker should show the complete own deck"),
		assert_eq((step.get("card_items", []) as Array).size(), 8, "All legal and illegal deck cards should remain visible"),
		assert_eq(step.get("items", []), tools, "Only Pokemon Tool cards should be selectable"),
		assert_eq(int(step.get("min_select", -1)), 0, "Treasure Tracker should allow selecting fewer than five Tools"),
		assert_eq(int(step.get("max_select", -1)), 5, "Treasure Tracker should select at most five Tools"),
		assert_false(trainer_action.is_empty(), "The AI/headless legal-action builder should expose Treasure Tracker from hand"),
		assert_false(bool(trainer_action.get("requires_interaction", true)), "The AI/headless path should auto-resolve Treasure Tracker's Tool selection"),
		assert_eq(_selected_count(trainer_action, "search_cards"), 5, "The AI/headless path should select no more than five legal Tools"),
		assert_eq(state.players[0].hand.size(), 5, "Treasure Tracker should move exactly the selected five Tools to hand"),
		assert_true(item in state.players[0].deck and pokemon in state.players[0].deck, "Illegal visible cards must remain in the deck"),
		assert_true(decline_state.players[0].hand.is_empty() and decline_state.players[0].deck.size() == 2, "Declining Treasure Tracker should leave hand and deck counts unchanged"),
	])


func test_csv8c059_crabominable_prep_work_and_haymaker_lock_match_kofu_count() -> String:
	var card := _load_card("CSV8C", "059")
	if card == null:
		return assert_not_null(card, "CSV8C_059 should load")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _state()
	var attacker := _slot(card, 0)
	state.players[0].active_pokemon = attacker
	state.players[0].discard_pile = [_named_card("海岱", "Kofu", 0), _named_card("海岱", "Kofu", 0), _named_card("博士的研究", "Professor's Research", 0)]
	var modifier := processor.get_attack_colorless_cost_modifier(attacker, card.attacks[0], state)
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state)
	return run_checks([
		assert_not_null(processor.get_effect(CRABOMINABLE_EFFECT_ID), "Crabominable's Prep Work Ability should register"),
		assert_eq(modifier, -2, "Only the two Kofu in the discard pile should reduce Haymaker's Colorless cost"),
		assert_true(attacker.effects.any(func(entry: Dictionary) -> bool: return str(entry.get("type", "")) == "attack_lock" and int(entry.get("attack_index", -1)) == 0), "Haymaker should lock only itself during Crabominable's next turn"),
	])


func test_csv9c051_veluza_prep_work_caps_reduction_and_sonic_edge_ignores_effects() -> String:
	var card := _load_card("CSV9C", "051")
	if card == null:
		return assert_not_null(card, "CSV9C_051 should load")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _state()
	var attacker := _slot(card, 0)
	state.players[0].active_pokemon = attacker
	var no_kofu_modifier := processor.get_attack_colorless_cost_modifier(attacker, card.attacks[0], state)
	for _index: int in 5:
		state.players[0].discard_pile.append(_named_card("海岱", "Kofu", 0))
	var modifier := processor.get_attack_colorless_cost_modifier(attacker, card.attacks[0], state)
	var ignores := processor.attack_effect_id_ignores_defender_effects(VELUZA_EFFECT_ID, 0, attacker, state)
	return run_checks([
		assert_not_null(processor.get_effect(VELUZA_EFFECT_ID), "Veluza's Prep Work Ability should register"),
		assert_eq(no_kofu_modifier, 0, "Prep Work should not reduce Sonic Edge when no Kofu is in the discard pile"),
		assert_eq(modifier, -4, "Prep Work should cap at Sonic Edge's four printed Colorless Energy"),
		assert_true(ignores, "Sonic Edge should ignore effects on the opponent's Active Pokemon"),
		assert_false(CardImplementationStatus.is_unimplemented(card), "CSV9C_051 should be marked implemented"),
	])


func test_batch3_numeric_crabrawler_and_existing_kofu_representative_remain_healthy() -> String:
	var crabrawler := _load_card("CSV8C", "115")
	var kofu := _load_card("CSV8C", "200")
	return run_checks([
		assert_not_null(crabrawler, "CSV8C_115 should load"),
		assert_eq(crabrawler.attacks.size() if crabrawler != null else 0, 2, "Crabrawler should retain both numeric-only attacks"),
		assert_eq(crabrawler.attacks[0].get("cost", "") if crabrawler != null else "", "CC", "Crabrawler's first attack should cost two Colorless Energy"),
		assert_eq(crabrawler.attacks[0].get("damage", "") if crabrawler != null else "", "20", "Crabrawler's first attack should deal 20"),
		assert_eq(crabrawler.attacks[1].get("cost", "") if crabrawler != null else "", "CCC", "Crabrawler's second attack should cost three Colorless Energy"),
		assert_eq(crabrawler.attacks[1].get("damage", "") if crabrawler != null else "", "50", "Crabrawler's second attack should deal 50"),
		assert_false(CardImplementationStatus.is_unimplemented(crabrawler), "Numeric-only Crabrawler should be runnable through base damage rules"),
		assert_not_null(kofu, "CSV8C_200 should load as the shared Prep Work representative card"),
		assert_false(CardImplementationStatus.is_unimplemented(kofu), "The existing Kofu implementation should remain registered"),
	])


func _load_card(set_code: String, card_index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s_%s.json" % [set_code, card_index]))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot(_pokemon("Active %d" % owner, 300), owner)
		state.players.append(player)
	return state


func _pokemon(name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = hp
	card.attacks = [{"name": "Tackle", "cost": "", "damage": "10", "text": "", "is_vstar_power": false}]
	return card


func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	slot.turn_played = 0
	return slot


func _trainer(name: String, card_type: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = card_type
	return CardInstance.create(card, owner)


func _named_card(name: String, name_en: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.card_type = "Supporter"
	return CardInstance.create(card, owner)


func _find_trainer_action(actions: Array[Dictionary], card: CardInstance) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == "play_trainer" and action.get("card", null) == card:
			return action
	return {}


func _selected_count(action: Dictionary, step_id: String) -> int:
	var targets: Array = action.get("targets", [])
	if targets.is_empty() or not (targets[0] is Dictionary):
		return 0
	var selected: Variant = (targets[0] as Dictionary).get(step_id, [])
	return (selected as Array).size() if selected is Array else 0
