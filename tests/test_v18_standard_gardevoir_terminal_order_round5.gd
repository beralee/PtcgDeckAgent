class_name TestV18StandardGardevoirTerminalOrderRound5
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const ACTION_BUILDER_SCRIPT = preload("res://scripts/ai/AILegalActionBuilder.gd")
const AI_OPPONENT_SCRIPT = preload("res://scripts/ai/AIOpponent.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018497.json"


func test_non_ko_roaring_scream_waits_for_live_refinement() -> String:
	CardInstance.reset_id_counter()
	var strategy := _strategy()
	var gsm := GameStateMachine.new()
	var state := _state()
	gsm.game_state = state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var scream_tail := _slot(_card("CSV6C_065"), 0)
	var gardevoir := _slot(_card("CSV2C_055"), 0)
	var kirlia := _slot(_card("CS6.5C_030"), 0)
	var second_kirlia := _slot(_card("CS6.5C_030"), 0)
	var munkidori := _slot(_card("CSV8C_094"), 0)
	var fezandipiti := _slot(_card("CSV8C_135"), 0)
	var psychic := _card("CSVE1C_PSY")
	scream_tail.damage_counters = 40
	scream_tail.attached_energy.assign([
		CardInstance.create(psychic, 0),
		CardInstance.create(psychic, 0),
		CardInstance.create(psychic, 0),
	])
	player.active_pokemon = scream_tail
	player.bench.assign([gardevoir, kirlia, second_kirlia, munkidori, fezandipiti])
	player.hand.assign([
		_item("Discard fuel", 0),
		_item("Spare card", 0),
		_item("Third card", 0),
	])
	opponent.active_pokemon = _slot(_defender(220), 1)

	var builder := ACTION_BUILDER_SCRIPT.new()
	builder.set_deck_strategy(strategy)
	var actions: Array = builder.build_actions(gsm, 0, false)
	var attack := _find(actions, "attack", func(action: Dictionary) -> bool:
		return int(action.get("attack_index", -1)) == 1
	)
	var refinement := _find(actions, "use_ability", func(action: Dictionary) -> bool:
		return action.get("source_slot", null) == kirlia
	)
	var ai := AI_OPPONENT_SCRIPT.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_only"
	ai.set_deck_strategy(strategy)
	var contract: Dictionary = ai._build_turn_contract(gsm, {"prompt_kind": "action_selection"})
	var best: Dictionary = ai._pick_best_absolute(actions, gsm, contract)
	var chosen: Dictionary = best.get("action", {}) if best.get("action", {}) is Dictionary else {}

	opponent.active_pokemon = _slot(_defender(80), 1)
	var ko_choice: Dictionary = _pick_best(ai, gsm, builder)

	opponent.active_pokemon = _slot(_defender(220), 1)
	for refinement_slot: PokemonSlot in [kirlia, second_kirlia]:
		refinement_slot.effects.append({
			"type": "ability_discard_draw_any_used",
			"turn": state.turn_number,
		})
	var used_choice: Dictionary = _pick_best(ai, gsm, builder)

	for refinement_slot: PokemonSlot in [kirlia, second_kirlia]:
		refinement_slot.effects.clear()
	player.deck.resize(8)
	var secret_box := _item("Secret Box", 0)
	var secret_box_action := {
		"kind": "play_trainer",
		"card": secret_box,
	}
	var attack_score: float = float(strategy.score_action_absolute(attack, state, 0))
	var secret_box_score: float = float(strategy.score_action_absolute(secret_box_action, state, 0))
	var deck_pressure_choice: Dictionary = _pick_best(ai, gsm, builder)
	return run_checks([
		assert_false(attack.is_empty(), "The real Scream Tail scaling attack should be legal"),
		assert_eq(int(attack.get("projected_damage", -1)), 80, "The scenario should use the fixed dynamic damage preview"),
		assert_false(bool(attack.get("projected_knockout", true)), "The 220 HP Active should keep this a non-KO attack"),
		assert_false(refinement.is_empty(), "The real Kirlia Refinement should be legal before the terminal attack"),
		assert_true(attack_score > secret_box_score, "Secret Box must trail a legal attack under low-deck pressure"),
		assert_eq(str(chosen.get("kind", "")), "use_ability", "The production selector should use safe Refinement before a non-KO terminal attack"),
		assert_eq(chosen.get("source_slot", null), kirlia, "The production selector should choose the live Kirlia Refinement"),
		assert_eq(str(ko_choice.get("kind", "")), "attack", "An immediate Scream Tail prize must not wait for Refinement"),
		assert_eq(str(used_choice.get("kind", "")), "attack", "Scream Tail should attack after all Refinements were used"),
		assert_eq(str(deck_pressure_choice.get("kind", "")), "attack", "Scream Tail should not churn the deck under deck-out pressure"),
	])


func test_night_stretcher_closed_loop_recovers_english_scream_tail_before_energy() -> String:
	CardInstance.reset_id_counter()
	var strategy := _strategy()
	var state := _state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_card("CSV2C_055"), 0)
	player.bench.append(_slot(_card("CS6.5C_030"), 0))
	var scream_tail_data := _card("CSV6C_065")
	scream_tail_data.name = "Untranslated runtime name"
	scream_tail_data.name_en = "Scream Tail"
	var scream_tail := CardInstance.create(scream_tail_data, 0)
	var psychic := CardInstance.create(_card("CSVE1C_PSY"), 0)
	player.discard_pile.assign([scream_tail, psychic])
	var context := {
		"game_state": state,
		"player_index": 0,
	}
	var scream_tail_score: float = strategy.score_interaction_target(
		scream_tail,
		{"id": "night_stretcher_choice"},
		context
	)
	var psychic_score: float = strategy.score_interaction_target(
		psychic,
		{"id": "night_stretcher_choice"},
		context
	)
	return assert_true(
		scream_tail_score > psychic_score,
		"Closed-loop Night Stretcher should recover an English-identified Scream Tail before Psychic Energy (scream=%f energy=%f)" % [scream_tail_score, psychic_score]
	)


func test_mid_low_deck_prefers_iono_over_professors_research() -> String:
	var strategy := _strategy()
	var state := _state()
	var player: PlayerState = state.players[0]
	player.deck.resize(22)
	var iono := _supporter("Iono", 0)
	var research := _supporter("Professor's Research", 0)
	player.hand.assign([iono, research])
	var iono_score: float = float(strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": iono,
	}, state, 0))
	var research_score: float = float(strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": research,
	}, state, 0))
	return assert_true(
		iono_score > research_score,
		"With both draw supporters available in a 22-card deck, Iono should preserve more deck than Professor's Research (iono=%f research=%f)" % [iono_score, research_score]
	)
func _pick_best(ai: RefCounted, gsm: GameStateMachine, builder: RefCounted) -> Dictionary:
	var actions: Array = builder.build_actions(gsm, 0, false)
	var contract: Dictionary = ai._build_turn_contract(gsm, {"prompt_kind": "action_selection"})
	var best: Dictionary = ai._pick_best_absolute(actions, gsm, contract)
	return best.get("action", {}) if best.get("action", {}) is Dictionary else {}


func _strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(DeckData.from_dict(parsed as Dictionary))


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 12
	state.phase = GameState.GamePhase.MAIN
	for index: int in 30:
		player.deck.append(_item("Player deck %d" % index, 0))
		opponent.deck.append(_item("Opponent deck %d" % index, 1))
	for index: int in 6:
		player.prizes.append(_item("Player prize %d" % index, 0))
		opponent.prizes.append(_item("Opponent prize %d" % index, 1))
	return state


func _card(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % ref
	))
	return CardData.from_dict(parsed as Dictionary)


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot


func _defender(hp: int) -> CardData:
	var card := CardData.new()
	card.name = "Non-KO target"
	card.name_en = card.name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _item(name: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Item"
	return CardInstance.create(card, owner_index)


func _supporter(name: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Supporter"
	return CardInstance.create(card, owner_index)


func _find(actions: Array, kind: String, predicate: Callable) -> Dictionary:
	for item: Variant in actions:
		if not item is Dictionary:
			continue
		var action := item as Dictionary
		if str(action.get("kind", "")) == kind and bool(predicate.call(action)):
			return action
	return {}
