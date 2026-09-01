class_name TestV18FiveDeckRound2Strategy
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_marnie_preserves_gust_cards_without_a_current_attack_window() -> String:
	var strategy := _delegate_for_deck(800018501)
	if strategy == null:
		return assert_true(false, "Marnie's Grimmsnarl delegate should resolve")
	var state := _state(18)
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_real_card("CSV10C_147", 0))
	var boss := _real_card("CSVH1aC_023", 0)
	var counter := _real_card("CSV6C_114", 0)
	var boss_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": boss,
	}, state, 0))
	var counter_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": counter,
	}, state, 0))
	var ready_grimmsnarl := _slot(_real_card("CSV10C_148", 0))
	_attach_basic_energy(ready_grimmsnarl, "D")
	_attach_basic_energy(ready_grimmsnarl, "D")
	player.active_pokemon = ready_grimmsnarl
	var ready_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": boss,
	}, state, 0))
	return run_checks([
		assert_true(boss_score <= -2800.0, "Boss must be held when Marnie cannot attack after the gust"),
		assert_true(counter_score <= -2800.0, "Counter Catcher must be held when Marnie cannot attack after the gust"),
		assert_true(ready_score > -2800.0, "The gust hold must release once active Grimmsnarl has a current attack window"),
	])


func test_no_balloon_gardevoir_preserves_the_last_live_rare_candy_bridge() -> String:
	var strategy := _delegate_for_deck(800017097)
	if strategy == null:
		return assert_true(false, "No-balloon Gardevoir delegate should resolve")
	var state := _state(5)
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_real_card("CSV2C_060", 0))
	player.bench = [_slot(_real_card("CSV2C_053", 0))]
	var candy := _real_card("CSVH1C_045", 0)
	var filler := _typed_card("Expendable Item", "Item", 0)
	player.hand = [candy, filler]
	player.deck = [_real_card("CSV2C_055", 0)]
	var protected_score := int(strategy.call("get_discard_priority_contextual", candy, state, 0))
	var filler_score := int(strategy.call("get_discard_priority_contextual", filler, state, 0))
	player.bench.clear()
	var off_route_score := int(strategy.call("get_discard_priority_contextual", candy, state, 0))
	return run_checks([
		assert_true(protected_score < filler_score, "The only Rare Candy must survive while a Ralts-to-Gardevoir bridge is live"),
		assert_true(off_route_score > protected_score, "Rare Candy protection must disappear when no Ralts bridge exists"),
	])


func test_pure_dragapult_preserves_boss_without_a_current_attack_window() -> String:
	var strategy := _delegate_for_deck(800018499)
	if strategy == null:
		return assert_true(false, "Pure Dragapult delegate should resolve")
	var state := _state(19)
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_real_card("CSV8C_158", 0))
	var boss := _real_card("CSVH1aC_023", 0)
	var blocked_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": boss,
	}, state, 0))
	var ready_dragapult := _slot(_real_card("CSV8C_159", 0))
	_attach_basic_energy(ready_dragapult, "R")
	_attach_basic_energy(ready_dragapult, "P")
	player.active_pokemon = ready_dragapult
	var ready_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": boss,
	}, state, 0))
	return run_checks([
		assert_true(blocked_score <= -2800.0, "Pure Dragapult should hold Boss when no attack can follow it"),
		assert_true(ready_score > -2800.0, "Boss protection must release for a ready active Phantom Dive"),
	])


func test_raging_bolt_discards_exact_lethal_energy_even_early() -> String:
	var strategy := _delegate_for_deck(800018509)
	if strategy == null:
		return assert_true(false, "Raging Bolt delegate should resolve")
	var state := _state(2)
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_real_card("CSV7C_154", 0))
	_attach_basic_energy(player.active_pokemon, "L")
	_attach_basic_energy(player.active_pokemon, "F")
	var ogerpon := _slot(_real_card("CSV8C_028", 0))
	_attach_basic_energy(ogerpon, "G")
	player.bench = [ogerpon]
	var cheap_ko := int(strategy.call("_desired_bellowing_thunder_discard_count", player, 70, 3, 2))
	var full_ko := int(strategy.call("_desired_bellowing_thunder_discard_count", player, 210, 3, 2))
	return run_checks([
		assert_eq(cheap_ko, 1, "Bellowing Thunder should spend one Energy for a 70 HP knockout on turn two"),
		assert_eq(full_ko, 3, "The same early board should still spend all three Energy when 210 damage is required"),
	])


func test_ns_zoroark_trade_preserves_the_only_darmanitan_bridge() -> String:
	var strategy := _delegate_for_deck(800018502)
	if strategy == null:
		return assert_true(false, "N's Zoroark delegate should resolve")
	var state := _state(7)
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_real_card("CSV10C_145", 0))
	player.bench = [_slot(_real_card("CSV10C_040", 0))]
	var darmanitan := _real_card("CSV10C_041", 0)
	var iono := _real_card("CSV3C_123", 0)
	player.hand = [darmanitan, iono]
	var protected_score := int(strategy.call("get_discard_priority_contextual", darmanitan, state, 0))
	var filler_score := int(strategy.call("get_discard_priority_contextual", iono, state, 0))
	player.bench.clear()
	var off_route_score := int(strategy.call("get_discard_priority_contextual", darmanitan, state, 0))
	return run_checks([
		assert_true(protected_score < filler_score, "Trade must preserve the sole Darmanitan while Darumaka is live"),
		assert_true(off_route_score > protected_score, "Darmanitan protection must release when no Darumaka bridge exists"),
	])


func _delegate_for_deck(deck_id: int) -> RefCounted:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/decks/%d.json" % deck_id
	))
	if not payload is Dictionary:
		return null
	var wrapper: RefCounted = REGISTRY_SCRIPT.new().resolve_strategy_for_deck(DeckData.from_dict(payload))
	if wrapper == null:
		return null
	var delegate: Variant = wrapper.get("_delegate")
	return delegate as RefCounted if delegate is RefCounted else wrapper


func _state(turn_number: int) -> GameState:
	var state := GameState.new()
	state.turn_number = turn_number
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[1].active_pokemon = _slot(_filler_card("Opponent Active", 1))
	return state


func _real_card(uid: String, owner_index: int) -> CardInstance:
	var parts := uid.rsplit("_", true, 1)
	var data: CardData = CardDatabase.get_card(parts[0], parts[1]) if parts.size() == 2 else null
	return CardInstance.create(data, owner_index) if data != null else null


func _typed_card(card_name: String, card_type: String, owner_index: int) -> CardInstance:
	var data := CardData.new()
	data.name = card_name
	data.name_en = card_name
	data.card_type = card_type
	return CardInstance.create(data, owner_index)


func _filler_card(card_name: String, owner_index: int) -> CardInstance:
	var data := CardData.new()
	data.name = card_name
	data.name_en = card_name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 120
	data.attacks = [{"name": "Test attack", "cost": "C", "damage": "10"}]
	return CardInstance.create(data, owner_index)


func _slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card != null:
		slot.pokemon_stack.append(card)
	return slot


func _attach_basic_energy(slot: PokemonSlot, energy_type: String) -> void:
	var data := CardData.new()
	data.name = "%s Energy" % energy_type
	data.name_en = "%s Energy" % energy_type
	data.card_type = "Basic Energy"
	data.energy_provides = energy_type
	slot.attached_energy.append(CardInstance.create(data, 0))
