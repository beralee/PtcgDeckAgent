class_name TestV18StandardGardevoirMunkidoriDebtRound10
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const ACTION_BUILDER_SCRIPT = preload("res://scripts/ai/AILegalActionBuilder.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018497.json"


func test_nonlethal_scream_tail_waits_for_safe_munkidori_transfer() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018497 should resolve through the production registry")
	var gsm := GameStateMachine.new()
	var state := _state()
	gsm.game_state = state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var scream_tail := _slot(_card("CSV6C_065"), 0)
	scream_tail.damage_counters = 40
	scream_tail.attached_energy.assign([_energy("P", 0), _energy("P", 0)])
	var gardevoir := _slot(_card("CSV2C_055"), 0)
	gardevoir.damage_counters = 30
	var munkidori := _slot(_card("CSV8C_094"), 0)
	munkidori.attached_energy.append(_energy("D", 0))
	player.active_pokemon = scream_tail
	player.bench.assign([gardevoir, munkidori])
	opponent.active_pokemon = _slot(_defender(260), 1)

	var builder: RefCounted = ACTION_BUILDER_SCRIPT.new()
	builder.call("set_deck_strategy", strategy)
	var actions := _actions(builder, gsm)
	var ability_action := _find(actions, "use_ability", func(action: Dictionary) -> bool:
		return action.get("source_slot", null) == munkidori
	)
	var attack_action := _find(actions, "attack", func(action: Dictionary) -> bool:
		return action.get("source_slot", null) == scream_tail and int(action.get("attack_index", -1)) == 1
	)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var flags: Dictionary = contract.get("flags", {}) if contract.get("flags", {}) is Dictionary else {}
	var ability_score := float(strategy.call("score_action_absolute_with_plan", ability_action, state, 0, contract))
	var attack_score := float(strategy.call("score_action_absolute_with_plan", attack_action, state, 0, contract))
	return run_checks([
		assert_false(ability_action.is_empty(), "Munkidori should be legally available with Darkness and safe movable damage"),
		assert_false(attack_action.is_empty(), "The nonlethal Scream Tail attack should remain legal"),
		assert_true(bool(flags.get("munkidori_damage_transfer_debt", false)),
			"Standard Gardevoir should expose the same safe transfer debt owned by its four-Munkidori list"),
		assert_true(ability_score > attack_score,
			"Safe Munkidori transfer must resolve before a non-final Roaring Scream"),
	])


func _strategy() -> RefCounted:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	if not raw is Dictionary:
		return null
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(raw))


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 13
	state.phase = GameState.GamePhase.MAIN
	for index: int in 12:
		player.deck.append(_filler("Player deck %d" % index, 0))
		opponent.deck.append(_filler("Opponent deck %d" % index, 1))
	for index: int in 6:
		player.prizes.append(_filler("Player prize %d" % index, 0))
		opponent.prizes.append(_filler("Opponent prize %d" % index, 1))
	return state


func _actions(builder: RefCounted, gsm: GameStateMachine) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = builder.call("build_actions", gsm, 0, false)
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				result.append(item)
	return result


func _find(actions: Array[Dictionary], kind: String, predicate: Callable) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == kind and bool(predicate.call(action)):
			return action
	return {}


func _card(ref: String) -> CardData:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % ref
	))
	return CardData.from_dict(raw) if raw is Dictionary else null


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card != null:
		slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot


func _energy(energy_type: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name_en = "Psychic Energy" if energy_type == "P" else "Darkness Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = energy_type
	return CardInstance.create(card, owner_index)


func _defender(hp: int) -> CardData:
	var card := CardData.new()
	card.name_en = "R10 Defender"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _filler(card_name: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Item"
	return CardInstance.create(card, owner_index)
