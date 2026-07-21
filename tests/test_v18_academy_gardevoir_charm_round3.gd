class_name TestV18AcademyGardevoirCharmRound3
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const DECK_ID := 800018498
const RULES_PATH := "res://scripts/ai/DeckStrategyV18Rules.gd"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18PidgeotAcademy.gd"


func test_pre_shell_charm_targets_yield_to_end_turn() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018498 should resolve through the production registry")
	var delegate: RefCounted = strategy.get("_delegate")
	var state := _state()
	var player: PlayerState = state.players[0]
	var ralts := _slot(_real_card("CSV2C_053"), 0)
	var munkidori := _slot(_real_card("CSV8C_094"), 0)
	var scream_tail := _slot(_real_card("CSV6C_065"), 0)
	player.active_pokemon = ralts
	player.bench.assign([munkidori, scream_tail])
	state.players[1].active_pokemon = _slot(_pokemon("Opponent Active", 130), 1)
	var charm := _instance(_real_card("CSV1C_118"))
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var end_score := _score(strategy, state, plan, {"kind": "end_turn"})
	var ralts_score := _charm_score(strategy, state, plan, charm, ralts)
	var munkidori_score := _charm_score(strategy, state, plan, charm, munkidori)
	var scream_tail_score := _charm_score(strategy, state, plan, charm, scream_tail)
	return run_checks([
		assert_eq(strategy.get_script().resource_path, RULES_PATH, "The registry must return the production V18 rules wrapper"),
		assert_not_null(delegate, "The production wrapper must expose the Academy delegate"),
		assert_eq(delegate.get_script().resource_path if delegate != null else "", DELEGATE_PATH, "Deck 800018498 must use its owned delegate"),
		assert_eq(_psychic_count(player.discard_pile), 0, "The pre-shell fixture must not have Psychic Embrace fuel"),
		assert_true(ralts_score <= -4000.0, "Bravery Charm on pre-shell Ralts must be hard-rejected (Ralts=%f end=%f)" % [ralts_score, end_score]),
		assert_true(munkidori_score <= -4000.0, "Bravery Charm on pre-shell Munkidori must be hard-rejected (Munkidori=%f end=%f)" % [munkidori_score, end_score]),
		assert_true(scream_tail_score < end_score, "Pre-shell Scream Tail must wait for the Charm commit window (Scream Tail=%f end=%f)" % [scream_tail_score, end_score]),
	])


func test_online_scalers_commit_charm_when_embrace_crosses_visible_prize_threshold() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018498 should resolve through the production registry")
	var charm := _instance(_real_card("CSV1C_118"))

	var drifloon_state := _online_state()
	var drifloon_player: PlayerState = drifloon_state.players[0]
	var drifloon := _slot(_real_card("CSV2C_060"), 0)
	drifloon.attached_energy.assign([_psychic(), _psychic()])
	drifloon_player.active_pokemon = drifloon
	drifloon_state.players[1].active_pokemon = _slot(_pokemon("Visible 60 HP Prize", 60), 1)
	var drifloon_plan: Dictionary = strategy.call("build_turn_plan", drifloon_state, 0, {})
	var drifloon_end := _score(strategy, drifloon_state, drifloon_plan, {"kind": "end_turn"})
	var drifloon_score := _charm_score(strategy, drifloon_state, drifloon_plan, charm, drifloon)
	var drifloon_support := _best_support_score(strategy, drifloon_state, drifloon_plan, charm)
	var drifloon_now: Dictionary = strategy.call("predict_attacker_damage", drifloon, 0)
	var drifloon_after: Dictionary = strategy.call("predict_attacker_damage", drifloon, 1)

	var scream_state := _online_state()
	var scream_player: PlayerState = scream_state.players[0]
	var scream_tail := _slot(_real_card("CSV6C_065"), 0)
	scream_tail.attached_energy.assign([_psychic(), _psychic()])
	scream_tail.damage_counters = 20
	scream_player.active_pokemon = scream_tail
	scream_state.players[1].active_pokemon = _slot(_pokemon("Protected Active", 250), 1)
	scream_state.players[1].bench.append(_slot(_pokemon("Visible 80 HP Prize", 80), 1))
	var scream_plan: Dictionary = strategy.call("build_turn_plan", scream_state, 0, {})
	var scream_end := _score(strategy, scream_state, scream_plan, {"kind": "end_turn"})
	var scream_score := _charm_score(strategy, scream_state, scream_plan, charm, scream_tail)
	var scream_support := _best_support_score(strategy, scream_state, scream_plan, charm)
	var scream_now: Dictionary = strategy.call("predict_attacker_damage", scream_tail, 0)
	var scream_after: Dictionary = strategy.call("predict_attacker_damage", scream_tail, 1)

	return run_checks([
		assert_eq(_psychic_count(drifloon_player.discard_pile), 1, "The Drifloon fixture must expose one Psychic Embrace payment"),
		assert_eq(int(drifloon_now.get("damage", -1)), 0, "Drifloon should start below the visible Prize threshold"),
		assert_eq(int(drifloon_after.get("damage", -1)), 60, "One Embrace should cross the 60 HP visible Prize threshold"),
		assert_true(drifloon_score > drifloon_end, "Threshold-crossing Drifloon should commit Bravery Charm (Drifloon=%f end=%f)" % [drifloon_score, drifloon_end]),
		assert_true(drifloon_score > drifloon_support, "Threshold-crossing Drifloon must outrank support attachments (Drifloon=%f support=%f)" % [drifloon_score, drifloon_support]),
		assert_eq(_psychic_count(scream_player.discard_pile), 1, "The Scream Tail fixture must expose one Psychic Embrace payment"),
		assert_eq(int(scream_now.get("damage", -1)), 40, "Scream Tail should start below the visible Prize threshold"),
		assert_eq(int(scream_after.get("damage", -1)), 80, "One Embrace should cross the 80 HP visible Prize threshold"),
		assert_true(scream_score > scream_end, "Threshold-crossing Scream Tail should commit Bravery Charm (Scream Tail=%f end=%f)" % [scream_score, scream_end]),
		assert_true(scream_score > scream_support, "Threshold-crossing Scream Tail must outrank support attachments (Scream Tail=%f support=%f)" % [scream_score, scream_support]),
	])


func test_online_scalers_wait_when_embrace_does_not_cross_visible_prize_threshold() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018498 should resolve through the production registry")
	var charm := _instance(_real_card("CSV1C_118"))
	var state := _online_state()
	var player: PlayerState = state.players[0]
	var drifloon := _slot(_real_card("CSV2C_060"), 0)
	drifloon.attached_energy.assign([_psychic(), _psychic()])
	var scream_tail := _slot(_real_card("CSV6C_065"), 0)
	scream_tail.attached_energy.assign([_psychic(), _psychic()])
	scream_tail.damage_counters = 20
	player.active_pokemon = drifloon
	player.bench.append(scream_tail)
	state.players[1].active_pokemon = _slot(_pokemon("Out-of-range Active", 330), 1)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var end_score := _score(strategy, state, plan, {"kind": "end_turn"})
	var drifloon_score := _charm_score(strategy, state, plan, charm, drifloon)
	var scream_score := _charm_score(strategy, state, plan, charm, scream_tail)
	return run_checks([
		assert_true(drifloon_score < end_score, "Drifloon must wait when the next Embrace cannot take a visible Prize (Drifloon=%f end=%f)" % [drifloon_score, end_score]),
		assert_true(scream_score < end_score, "Scream Tail must wait when the next Embrace cannot take a visible Prize (Scream Tail=%f end=%f)" % [scream_score, end_score]),
	])


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
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	for index: int in 12:
		player.deck.append(_instance(_trainer("Own deck filler %d" % index)))
	for index: int in 6:
		player.prizes.append(_instance(_trainer("Own Prize %d" % index)))
		opponent.prizes.append(_instance(_trainer("Opponent Prize %d" % index), 1))
	return state


func _online_state() -> GameState:
	var state := _state()
	var player: PlayerState = state.players[0]
	player.bench.assign([
		_slot(_real_card("CSV2C_055"), 0),
		_slot(_real_card("CSV2C_053"), 0),
		_slot(_real_card("CSV8C_094"), 0),
	])
	player.discard_pile.append(_psychic())
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


func _best_support_score(
	strategy: RefCounted,
	state: GameState,
	plan: Dictionary,
	charm: CardInstance
) -> float:
	var player: PlayerState = state.players[0]
	var best := -INF
	for slot: PokemonSlot in player.bench:
		if slot.get_card_data() != null and str(slot.get_card_data().name_en) in ["Ralts", "Munkidori"]:
			best = maxf(best, _charm_score(strategy, state, plan, charm, slot))
	return best


func _psychic() -> CardInstance:
	return _instance(_real_card("CSVE1C_PSY"))


func _psychic_count(cards: Array[CardInstance]) -> int:
	var count := 0
	for card: CardInstance in cards:
		if card != null and card.card_data != null and str(card.card_data.energy_provides) == "P":
			count += 1
	return count


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
