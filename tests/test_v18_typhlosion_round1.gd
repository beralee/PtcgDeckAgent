class_name TestV18TyphlosionRound1
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800018880


func test_partner_blast_damage_is_visible_to_wrapper_conversion_decisions() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018880 should resolve to its production V18 wrapper")

	var state := _state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var typhlosion := _typhlosion_slot()
	typhlosion.attached_energy.append(_basic_fire())
	player.active_pokemon = typhlosion
	player.bench.append(_victini_slot())
	for _index: int in 3:
		player.discard_pile.append(_ethans_adventure())

	var active_230 := _target_slot("Active 230 HP ex", 230)
	var active_240 := _target_slot("Active 240 HP ex", 240)
	var boss_target_230 := _target_slot("Bench 230 HP ex", 230)
	var boss_target_240 := _target_slot("Bench 240 HP ex", 240)
	opponent.active_pokemon = active_230
	opponent.bench.assign([boss_target_230, boss_target_240])
	strategy.call("build_turn_plan", state, 0, {"prompt_kind": "action_selection"})

	var prediction: Dictionary = strategy.call("predict_attacker_damage", typhlosion)
	var context := {"game_state": state, "player_index": 0}
	var handoff_step := {"id": "send_out"}
	var handoff_ko_score: float = strategy.call("score_handoff_target", typhlosion, handoff_step, context)
	opponent.active_pokemon = active_240
	var handoff_non_ko_score: float = strategy.call("score_handoff_target", typhlosion, handoff_step, context)

	var boss_step := {"id": "opponent_bench_target"}
	var boss_ko_score: float = strategy.call("score_handoff_target", boss_target_230, boss_step, context)
	var boss_non_ko_score: float = strategy.call("score_handoff_target", boss_target_240, boss_step, context)

	var stale_attack_projection := {
		"kind": "attack",
		"source_slot": typhlosion,
		"attack_index": 0,
		"attack_name": "Partner Blast",
		"projected_damage": 40,
		"projected_knockout": false,
	}
	opponent.active_pokemon = active_230
	var attack_ko_score: float = strategy.call("score_action_absolute", stale_attack_projection, state, 0)
	opponent.active_pokemon = active_240
	var attack_non_ko_score: float = strategy.call("score_action_absolute", stale_attack_projection, state, 0)

	return run_checks([
		assert_true(bool(prediction.get("can_attack", false)), "One Fire Energy should ready Partner Blast"),
		assert_eq(int(prediction.get("damage", 0)), 230, "Three discarded Ethan's Adventure plus Victini should predict 230 damage"),
		assert_true(int(prediction.get("damage", 0)) >= active_230.get_remaining_hp(), "The wrapper prediction should identify the 230 HP ex knockout"),
		assert_true(handoff_ko_score >= handoff_non_ko_score + 1200.0, "A lethal Partner Blast handoff should outrank the same nonlethal handoff"),
		assert_true(boss_ko_score >= boss_non_ko_score + 1200.0, "Boss should prefer the 230 HP ex that Partner Blast can knock out"),
		assert_true(attack_ko_score >= attack_non_ko_score + 1200.0, "Attack scoring should recover the lethal 230 damage even from a stale 40-damage action projection"),
	])


func _wrapper_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/decks/%d.json" % DECK_ID))
	if not parsed is Dictionary:
		return null
	var deck := DeckData.from_dict(parsed)
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", deck)


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
	return state


func _typhlosion_slot() -> PokemonSlot:
	var card := _pokemon("Ethan's Typhlosion", "CSV10C", "030", 170, "Stage 2")
	card.energy_type = "R"
	card.attacks = [
		{"name": "Partner Blast", "cost": "R", "damage": "40+"},
		{"name": "Blasting Typhoon", "cost": "RRC", "damage": "160"},
	]
	return _slot(card, 0)


func _victini_slot() -> PokemonSlot:
	return _slot(_pokemon("Victini", "CSV9C", "023", 70, "Basic"), 0)


func _target_slot(card_name: String, hp: int) -> PokemonSlot:
	var card := _pokemon(card_name, "TEST", str(hp), hp, "Basic")
	card.mechanic = "ex"
	return _slot(card, 1)


func _ethans_adventure() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Ethan's Adventure"
	card.card_type = "Supporter"
	card.set_code = "CSV10C"
	card.card_index = "208"
	return CardInstance.create(card, 0)


func _basic_fire() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Fire Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "R"
	card.energy_provides = "R"
	return CardInstance.create(card, 0)


func _pokemon(card_name: String, set_code: String, card_index: String, hp: int, stage: String) -> CardData:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.set_code = set_code
	card.card_index = card_index
	card.hp = hp
	card.stage = stage
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot
