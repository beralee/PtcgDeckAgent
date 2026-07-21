class_name TestV18RabscaArtazonRound1
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018105.json"


func test_artazon_searches_rellor_when_bench_damage_creates_guard_debt() -> String:
	var strategy := _load_strategy()
	var ralts_data: CardData = CardDatabase.get_card("CSV2C", "053")
	var rellor_data: CardData = CardDatabase.get_card("CSV7C", "030")
	var checks: Array[String] = [
		assert_not_null(strategy, "Rabsca Gardevoir should resolve its production strategy"),
		assert_not_null(ralts_data, "Ralts should load"),
		assert_not_null(rellor_data, "Rellor should load"),
	]
	if strategy == null or ralts_data == null or rellor_data == null:
		return run_checks(checks)
	var state := _state_with_bench_pressure()
	var ralts := CardInstance.create(ralts_data, 0)
	var rellor := CardInstance.create(rellor_data, 0)
	var picked: Array = strategy.call(
		"pick_interaction_items",
		[ralts, rellor],
		{"id": "artazon_pokemon", "min_select": 1, "max_select": 1},
		{"game_state": state, "player_index": 0}
	)
	checks.append(assert_true(picked.size() == 1 and picked[0] == rellor, "Artazon should establish the Rabsca guard before taking another Ralts"))
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", deck) if deck != null else null


func _state_with_bench_pressure() -> GameState:
	var state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.current_player_index = 0
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	state.players[0].active_pokemon = _slot(_pokemon("Pivot", []), 0)
	state.players[1].active_pokemon = _slot(_pokemon("Bench Sniper", [
		{"name": "Bench Shot", "cost": "L", "damage": "", "text": "Do 30 damage to 1 of your opponent's Benched Pokemon."},
	]), 1)
	return state


func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _pokemon(card_name: String, attacks: Array) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 100
	var typed_attacks: Array[Dictionary] = []
	for attack: Variant in attacks:
		if attack is Dictionary:
			typed_attacks.append((attack as Dictionary).duplicate(true))
	card.attacks = typed_attacks
	return card
