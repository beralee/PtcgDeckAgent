class_name TestV18AcademyGardevoirRound1
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const DECK_ID := 800018498
const RULES_PATH := "res://scripts/ai/DeckStrategyV18Rules.gd"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18PidgeotAcademy.gd"


func test_active_drifloon_zero_to_sixty_pays_embrace_debt_before_attacking() -> String:
	var strategy := _academy_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018498 should resolve through the production registry")
	var delegate: RefCounted = strategy.get("_delegate")
	var state := _academy_state(100)
	var player: PlayerState = state.players[0]
	var drifloon := player.active_pokemon
	var gardevoir := player.bench[0]
	var before: Dictionary = strategy.call("predict_attacker_damage", drifloon, 0)
	var after: Dictionary = strategy.call("predict_attacker_damage", drifloon, 1)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var embrace_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "use_ability",
		"source_slot": gardevoir,
		"ability_name": "Psychic Embrace",
	}, state, 0, plan)
	var attack_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": drifloon,
		"attack_index": 1,
		"projected_damage": 0,
		"projected_knockout": false,
	}, state, 0, plan)
	var picked: Array = strategy.call("pick_interaction_items", [gardevoir, drifloon], {
		"id": "embrace_target",
		"min_select": 1,
		"max_select": 1,
	}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_eq(strategy.get_script().resource_path, RULES_PATH, "The registry must return the production V18 rules wrapper"),
		assert_not_null(delegate, "The production wrapper must expose the Academy delegate"),
		assert_eq(delegate.get_script().resource_path if delegate != null else "", DELEGATE_PATH, "Deck 800018498 must use its owned delegate"),
		assert_true(bool(before.get("can_attack", false)), "Two Psychic Energy should already pay Drifloon's scaler attack cost"),
		assert_eq(int(before.get("damage", -1)), 0, "An undamaged Drifloon should currently project zero scaler damage"),
		assert_eq(int(after.get("damage", -1)), 60, "One safe Psychic Embrace should raise Drifloon from 0 to 60 damage"),
		assert_true(delegate != null and bool(delegate.call("_academy_active_scaler_needs_embrace", state, player, 0)), "The nonlethal 0-to-60 route should expose Academy Embrace debt"),
		assert_true(embrace_score >= 5600.0, "Gardevoir ex should receive the Academy Embrace debt floor (score=%f)" % embrace_score),
		assert_true(embrace_score > attack_score, "Psychic Embrace should precede the zero-damage attack (embrace=%f attack=%f)" % [embrace_score, attack_score]),
		assert_eq(picked, [drifloon], "Psychic Embrace debt should deterministically target the Active Drifloon"),
	])


func test_active_drifloon_lethal_keeps_attack_ahead_of_embrace() -> String:
	var strategy := _academy_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018498 should resolve through the production registry")
	var delegate: RefCounted = strategy.get("_delegate")
	var state := _academy_state(60)
	var player: PlayerState = state.players[0]
	var drifloon := player.active_pokemon
	var gardevoir := player.bench[0]
	drifloon.damage_counters = 20
	var current: Dictionary = strategy.call("predict_attacker_damage", drifloon, 0)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var embrace_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "use_ability",
		"source_slot": gardevoir,
		"ability_name": "Psychic Embrace",
	}, state, 0, plan)
	var attack_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": drifloon,
		"attack_index": 1,
		"projected_damage": 60,
		"projected_knockout": true,
	}, state, 0, plan)
	return run_checks([
		assert_eq(int(current.get("damage", -1)), 60, "The damaged Drifloon should already have a 60-damage attack"),
		assert_false(delegate != null and bool(delegate.call("_academy_active_scaler_needs_embrace", state, player, 0)), "An existing Prize-taking attack must retire Academy Embrace debt"),
		assert_true(attack_score > embrace_score, "A lethal Drifloon attack must stay ahead of overcharging (attack=%f embrace=%f)" % [attack_score, embrace_score]),
	])


func _academy_strategy() -> RefCounted:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/decks/%d.json" % DECK_ID
	))
	if not payload is Dictionary:
		return null
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(payload))


func _academy_state(opponent_hp: int) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN

	var drifloon := _slot(_real_card_data("CSV2C_060"), 0)
	drifloon.attached_energy.assign([_psychic(0), _psychic(0)])
	player.active_pokemon = drifloon
	player.bench.append(_slot(_real_card_data("CSV2C_055"), 0))
	player.discard_pile.append(_psychic(0))
	opponent.active_pokemon = _slot(_pokemon("Opponent Active", opponent_hp), 1)
	for index: int in 12:
		player.deck.append(CardInstance.create(_trainer("Own deck filler %d" % index), 0))
	for index: int in 6:
		player.prizes.append(CardInstance.create(_trainer("Own Prize %d" % index), 0))
		opponent.prizes.append(CardInstance.create(_trainer("Opponent Prize %d" % index), 1))
	return state


func _psychic(owner_index: int) -> CardInstance:
	return CardInstance.create(_real_card_data("CSVE1C_PSY"), owner_index)


func _real_card_data(ref: String) -> CardData:
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
	card.card_type = "Item"
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot
