class_name TestV18StandardGardevoirCharmReserveRound3
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const DECK_ID := 800018497
const RULES_PATH := "res://scripts/ai/DeckStrategyV18Rules.gd"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyGardevoir.gd"


func test_seed6200_reserves_charm_for_recovered_scream_tail_240_route() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018497 should resolve through the production registry")
	var delegate: RefCounted = strategy.get("_delegate")
	if delegate == null:
		return assert_true(false, "Deck 800018497 should expose the mature Gardevoir delegate")

	CardInstance.reset_id_counter()
	var state := _state()
	var player: PlayerState = state.players[0]
	var gardevoir := _slot(_real_card("CSV2C_055"), 0)
	var ralts := _slot(_real_card("CSV2C_053"), 0)
	var munkidori := _slot(_real_card("CSV8C_094"), 0)
	var scream_card := _instance(_real_card("CSV6C_065"))
	var charm := _instance(_real_card("CSV1C_118"))
	player.active_pokemon = gardevoir
	player.bench.assign([ralts, munkidori])
	player.hand.append(charm)
	player.discard_pile.assign([
		scream_card,
		_psychic(),
		_psychic(),
	])
	state.players[1].active_pokemon = _slot(_pokemon("Seed 6200 opponent Active", 280), 1)

	var reserve_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var reserve_end := _score(strategy, state, reserve_plan, {"kind": "end_turn"})
	var support_scores := {
		"Gardevoir ex": _charm_score(strategy, state, reserve_plan, charm, gardevoir),
		"Ralts": _charm_score(strategy, state, reserve_plan, charm, ralts),
		"Munkidori": _charm_score(strategy, state, reserve_plan, charm, munkidori),
	}
	var checks: Array[String] = [
		assert_eq(str(strategy.get_script().resource_path), RULES_PATH, "The fixture must use the production V18 rules wrapper"),
		assert_eq(str(delegate.get_script().resource_path), DELEGATE_PATH, "Deck 800018497 must use the mature Gardevoir delegate"),
		assert_eq(int(delegate.get("_configured_deck_id")), DECK_ID, "The delegate must retain exact production deck identity"),
		assert_eq(_field_count(player, "Scream Tail"), 0, "The reserve half of the seed 6200 fixture must have no fielded Scream Tail"),
	]
	for target_name: String in support_scores:
		var target_score: float = float(support_scores[target_name])
		checks.append(assert_true(
			target_score <= -4000.0,
			"Bravery Charm on %s must hard-reject while Scream Tail is recoverable (target=%f end=%f)" % [target_name, target_score, reserve_end]
		))
		checks.append(assert_true(
			target_score < reserve_end,
			"Bravery Charm on %s must stay below end turn while Scream Tail is absent (target=%f end=%f)" % [target_name, target_score, reserve_end]
		))

	player.discard_pile.erase(scream_card)
	var scream_tail := PokemonSlot.new()
	scream_tail.pokemon_stack.append(scream_card)
	scream_tail.attached_energy.assign([_psychic(), _psychic()])
	scream_tail.damage_counters = 80
	player.bench.append(scream_tail)
	var commit_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var commit_end := _score(strategy, state, commit_plan, {"kind": "end_turn"})
	var scream_score := _charm_score(strategy, state, commit_plan, charm, scream_tail)
	var best_support_score := -INF
	for support_slot: PokemonSlot in [gardevoir, ralts, munkidori]:
		best_support_score = maxf(
			best_support_score,
			_charm_score(strategy, state, commit_plan, charm, support_slot)
		)
	checks.append(assert_true(
		scream_score > maxf(commit_end, best_support_score),
		"Recovered Scream Tail must own the Charm route (Scream=%f support=%f end=%f)" % [scream_score, best_support_score, commit_end]
	))

	scream_tail.attached_tool = charm
	player.hand.erase(charm)
	var prediction: Dictionary = strategy.call("predict_attacker_damage", scream_tail, 2)
	checks.append(assert_true(bool(prediction.get("can_attack", false)), "Two more Psychic Embraces must leave Scream Tail attack-ready"))
	checks.append(assert_eq(int(prediction.get("damage", -1)), 240, "The held Charm route must preserve the predicted 240-damage attack"))
	checks.append(assert_true(
		bool(delegate.call("_drifloon_survives_extra_embrace_count", scream_tail, 2, false, state)),
		"Charmed Scream Tail at 80 damage must survive two more Psychic Embraces"
	))
	checks.append(assert_false(
		bool(delegate.call("_drifloon_survives_extra_embrace_count", scream_tail, 3, false, state)),
		"The fixture must retain the self-KO boundary after the two-Embrace route"
	))
	return run_checks(checks)


func _strategy() -> RefCounted:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/decks/%d.json" % DECK_ID
	))
	if not payload is Dictionary:
		return null
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(payload))


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 7
	state.phase = GameState.GamePhase.MAIN
	for index: int in 12:
		player.deck.append(_instance(_trainer("Own deck filler %d" % index)))
	for index: int in 2:
		player.prizes.append(_instance(_trainer("Own Prize %d" % index)))
		opponent.prizes.append(_instance(_trainer("Opponent Prize %d" % index), 1))
	return state


func _score(strategy: RefCounted, state: GameState, plan: Dictionary, action: Dictionary) -> float:
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _charm_score(
	strategy: RefCounted,
	state: GameState,
	plan: Dictionary,
	charm: CardInstance,
	target: PokemonSlot
) -> float:
	return _score(strategy, state, plan, {
		"kind": "attach_tool",
		"card": charm,
		"target_slot": target,
	})


func _field_count(player: PlayerState, name_en: String) -> int:
	var count := 0
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	slots.append_array(player.bench)
	for slot: PokemonSlot in slots:
		if slot.get_card_data() != null and str(slot.get_card_data().name_en) == name_en:
			count += 1
	return count


func _psychic() -> CardInstance:
	return _instance(_real_card("CSVE1C_PSY"))


func _real_card(ref: String) -> CardData:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % ref
	))
	return CardData.from_dict(payload) if payload is Dictionary else null


func _pokemon(card_name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.name_zh = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.attacks = [{"name": "Test Attack", "cost": "C", "damage": "10", "text": ""}]
	return card


func _trainer(card_name: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.name_zh = card_name
	card.card_type = "Item"
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_instance(card, owner_index))
	return slot


func _instance(card: CardData, owner_index: int = 0) -> CardInstance:
	return CardInstance.create(card, owner_index)
