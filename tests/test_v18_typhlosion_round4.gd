class_name TestV18TyphlosionRound4
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800018880
const QUICK_SEARCH_DEBT := "quick_search_adventure_exact_ko"
const PLAY_ADVENTURE_DEBT := "play_adventure_exact_ko"


func test_quick_search_raises_only_ethans_adventure_for_the_exact_plus_sixty_knockout() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018880 should resolve to its production V18 wrapper")
	var state := _exact_ko_state(220)
	var player: PlayerState = state.players[0]
	var adventure: CardInstance = _first_exact_uid(player.deck, "CSV10C_208")
	var boss := _trainer("Boss's Orders", "CSVH1aC", "023", "Supporter")
	var counter_catcher := _trainer("Counter Catcher", "CSV6C", "114", "Item")
	var pidgeot_source := player.bench[0].get_top_card()
	var context := {
		"game_state": state,
		"player_index": 0,
		"pending_effect_card": pidgeot_source,
	}
	var step := {"id": "search_cards"}
	var adventure_score: float = strategy.call("score_interaction_target", adventure, step, context)
	var boss_score: float = strategy.call("score_interaction_target", boss, step, context)
	var counter_score: float = strategy.call("score_interaction_target", counter_catcher, step, context)
	context["pending_effect_card"] = _pokemon_instance("Rotom V", "TEST", "ROTOM", "Basic", 190, 0)
	var wrong_source_score: float = strategy.call("score_interaction_target", adventure, step, context)
	return run_checks([
		assert_true(adventure_score >= 7000.0, "Pidgeot ex Quick Search should raise Ethan's Adventure to the exact-KO tier"),
		assert_true(adventure_score >= boss_score + 5000.0, "The exact-KO route must not extend its search bonus to Boss's Orders"),
		assert_true(adventure_score >= counter_score + 5000.0, "The exact-KO route must not extend its search bonus to Counter Catcher"),
		assert_true(adventure_score >= wrong_source_score + 5000.0, "Only CSV4C_101 Pidgeot ex Quick Search may claim the exact-KO Adventure bonus"),
	])


func test_exact_ko_route_is_false_after_a_supporter_was_used() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018880 should resolve to its production V18 wrapper")
	var state := _exact_ko_state(220)
	state.supporter_used_this_turn = true
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var adventure: CardInstance = _first_exact_uid(state.players[0].deck, "CSV10C_208")
	var score: float = strategy.call("score_interaction_target", adventure, {"id": "search_cards"}, {
		"game_state": state,
		"player_index": 0,
		"pending_effect_card": state.players[0].bench[0].get_top_card(),
	})
	return run_checks([
		assert_eq(_plan_debt(plan), "", "Used Supporter must clear the Adventure exact-KO route"),
		assert_true(score < 6000.0, "Used Supporter must block the Quick Search exact-KO bonus"),
	])


func test_exact_ko_route_is_false_when_partner_blast_already_knocks_out() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018880 should resolve to its production V18 wrapper")
	var state := _exact_ko_state(160)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var adventure: CardInstance = _first_exact_uid(state.players[0].deck, "CSV10C_208")
	var score: float = strategy.call("score_interaction_target", adventure, {"id": "search_cards"}, {
		"game_state": state,
		"player_index": 0,
		"pending_effect_card": state.players[0].bench[0].get_top_card(),
	})
	return run_checks([
		assert_eq(_plan_debt(plan), "", "An already-lethal Partner Blast must not create Adventure debt"),
		assert_true(score < 6000.0, "An already-lethal Partner Blast must not spend Quick Search on Adventure"),
	])


func test_exact_ko_debt_transitions_then_clears_for_partner_blast() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018880 should resolve to its production V18 wrapper")
	var state := _exact_ko_state(220)
	var player: PlayerState = state.players[0]
	var adventure: CardInstance = _first_exact_uid(player.deck, "CSV10C_208")
	var search_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var search_continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, search_plan)

	player.deck.erase(adventure)
	player.hand.append(adventure)
	player.bench[0].effects.append({"type": "ability_search_any_used", "turn": state.turn_number})
	state.shared_turn_flags["ability_search_any_quick_search_0"] = state.turn_number
	var play_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var play_continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, play_plan)
	var premature_attack := _partner_blast_action(player.active_pokemon, 160, false)
	var adventure_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": adventure,
	}, state, 0, play_plan)
	var premature_attack_score: float = strategy.call(
		"score_action_absolute_with_plan",
		premature_attack,
		state,
		0,
		play_plan
	)

	player.hand.erase(adventure)
	player.discard_pile.append(adventure)
	state.supporter_used_this_turn = true
	var attack_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var attack_continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, attack_plan)
	var prediction: Dictionary = strategy.call("predict_attacker_damage", player.active_pokemon)
	var final_attack_score: float = strategy.call("score_action_absolute_with_plan", _partner_blast_action(
		player.active_pokemon,
		220,
		true
	), state, 0, attack_plan)
	var end_turn_score: float = strategy.call("score_action_absolute_with_plan", {"kind": "end_turn"}, state, 0, attack_plan)

	return run_checks([
		assert_eq(_plan_debt(search_plan), QUICK_SEARCH_DEBT, "Adventure in deck should create Quick Search exact-KO debt"),
		assert_eq(_continuity_debt(search_continuity), QUICK_SEARCH_DEBT, "Continuity should consume the Quick Search debt stage"),
		assert_eq(_plan_debt(play_plan), PLAY_ADVENTURE_DEBT, "Adventure in hand should transition to play debt"),
		assert_eq(_continuity_debt(play_continuity), PLAY_ADVENTURE_DEBT, "Continuity should consume the play-Adventure debt stage"),
		assert_true(adventure_score >= premature_attack_score + 3000.0, "Ethan's Adventure must outrank the premature nonlethal Partner Blast"),
		assert_eq(_plan_debt(attack_plan), "", "Adventure in discard should clear exact-KO debt"),
		assert_eq(_continuity_debt(attack_continuity), "", "Cleared exact-KO debt must disappear from continuity"),
		assert_eq(int(prediction.get("damage", 0)), 220, "The discarded Adventure should raise Partner Blast from 160 to 220"),
		assert_true(final_attack_score >= end_turn_score + 3000.0, "Lethal Partner Blast must be chosen after Adventure clears the debt"),
	])


func _wrapper_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/decks/%d.json" % DECK_ID))
	if not parsed is Dictionary:
		return null
	var deck := DeckData.from_dict(parsed)
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", deck)


func _exact_ko_state(defender_hp: int) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	player.active_pokemon = _slot(_pokemon("Ethan's Typhlosion", "CSV10C", "030", "Stage 2", 170), 0)
	player.active_pokemon.get_card_data().attacks = [
		{"name": "Partner Blast", "cost": "R", "damage": "40+"},
		{"name": "Blasting Typhoon", "cost": "RRC", "damage": "160"},
	]
	player.active_pokemon.attached_energy.append(_basic_fire())
	player.bench.assign([
		_slot(_pokemon("Pidgeot ex", "CSV4C", "101", "Stage 2", 280), 0),
		_slot(_pokemon("Ethan's Cyndaquil", "CSV10C", "028", "Basic", 70), 0),
	])
	player.discard_pile.assign([_ethans_adventure(), _ethans_adventure()])
	player.deck.append(_ethans_adventure())
	for index: int in 12:
		player.deck.append(_trainer("Deck filler %d" % index, "TEST", "D%02d" % index, "Item"))
	for index: int in 6:
		player.prizes.append(_trainer("Prize %d" % index, "TEST", "P%02d" % index, "Item"))
	opponent.active_pokemon = _slot(_pokemon("Defender", "TEST", "DEF", "Basic", defender_hp), 1)
	return state


func _plan_debt(plan: Dictionary) -> String:
	var flags: Dictionary = plan.get("flags", {})
	return str(flags.get("exact_ko_debt", ""))


func _continuity_debt(contract: Dictionary) -> String:
	var setup_debt: Dictionary = contract.get("setup_debt", {})
	var delegate: Dictionary = setup_debt.get("delegate", setup_debt)
	return str(delegate.get("exact_ko", ""))


func _partner_blast_action(source: PokemonSlot, projected_damage: int, projected_knockout: bool) -> Dictionary:
	return {
		"kind": "attack",
		"source_slot": source,
		"attack_index": 0,
		"attack_name": "Partner Blast",
		"projected_damage": projected_damage,
		"projected_knockout": projected_knockout,
	}


func _first_exact_uid(cards: Array, uid: String) -> CardInstance:
	for card: CardInstance in cards:
		if card != null and card.card_data != null and str(card.card_data.get_uid()) == uid:
			return card
	return null


func _ethans_adventure() -> CardInstance:
	return _trainer("Ethan's Adventure", "CSV10C", "208", "Supporter")


func _basic_fire() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Fire Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "R"
	card.energy_provides = "R"
	return CardInstance.create(card, 0)


func _trainer(card_name: String, set_code: String, card_index: String, card_type: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = card_type
	card.set_code = set_code
	card.card_index = card_index
	return CardInstance.create(card, 0)


func _pokemon_instance(
	card_name: String,
	set_code: String,
	card_index: String,
	stage: String,
	hp: int,
	owner_index: int
) -> CardInstance:
	return CardInstance.create(_pokemon(card_name, set_code, card_index, stage, hp), owner_index)


func _pokemon(card_name: String, set_code: String, card_index: String, stage: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.set_code = set_code
	card.card_index = card_index
	card.stage = stage
	card.hp = hp
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot
