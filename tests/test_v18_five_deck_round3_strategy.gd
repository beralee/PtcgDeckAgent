class_name TestV18FiveDeckRound3Strategy
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_marnie_does_not_retreat_the_only_ready_grimmsnarl() -> String:
	var strategy := _delegate_for_deck(800018501)
	if strategy == null:
		return assert_true(false, "Marnie's Grimmsnarl delegate should resolve")
	var state := _state(26)
	var player: PlayerState = state.players[0]
	var grimmsnarl := _slot(_real_card("CSV10C_148", 0))
	_attach_basic_energy(grimmsnarl, "D")
	_attach_basic_energy(grimmsnarl, "D")
	var munkidori := _slot(_real_card("CSV8C_094", 0))
	player.active_pokemon = grimmsnarl
	player.bench = [munkidori]
	var blocked_score := float(strategy.call("score_action_absolute", {
		"kind": "retreat", "bench_target": munkidori,
	}, state, 0))
	var backup := _slot(_real_card("CSV10C_148", 0))
	_attach_basic_energy(backup, "D")
	_attach_basic_energy(backup, "D")
	player.bench.append(backup)
	var released_score := float(strategy.call("score_action_absolute", {
		"kind": "retreat", "bench_target": backup,
	}, state, 0))
	return run_checks([
		assert_true(blocked_score <= -4200.0, "The only ready Grimmsnarl must keep the current attack window"),
		assert_true(released_score > blocked_score + 2000.0, "The retreat guard must release when a second ready Grimmsnarl can take over"),
	])


func test_no_balloon_gardevoir_reserves_bravery_charm_for_damage_attackers() -> String:
	var strategy := _delegate_for_deck(800017097)
	if strategy == null:
		return assert_true(false, "No-balloon Gardevoir delegate should resolve")
	var state := _state(13)
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_real_card("CSV2C_055", 0))
	var munkidori := _slot(_real_card("CSV8C_094", 0))
	var drifloon := _slot(_real_card("CSV2C_060", 0))
	player.bench = [munkidori, drifloon]
	var charm := _real_card("CSV1C_118", 0)
	var support_score := float(strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": charm, "target_slot": munkidori,
	}, state, 0))
	var attacker_score := float(strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": charm, "target_slot": drifloon,
	}, state, 0))
	return run_checks([
		assert_true(support_score <= -4600.0, "Bravery Charm must not be consumed by Munkidori"),
		assert_true(attacker_score >= support_score + 3000.0, "Bravery Charm should remain available for Drifloon or Scream Tail"),
	])


func test_pure_dragapult_preserves_counter_catcher_without_an_attack_window() -> String:
	var strategy := _delegate_for_deck(800018499)
	if strategy == null:
		return assert_true(false, "Pure Dragapult delegate should resolve")
	var state := _state(8)
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_real_card("CSV8C_158", 0))
	var counter := _real_card("CSV6C_114", 0)
	var blocked_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": counter,
	}, state, 0))
	var ready := _slot(_real_card("CSV8C_159", 0))
	_attach_basic_energy(ready, "R")
	_attach_basic_energy(ready, "P")
	player.active_pokemon = ready
	var ready_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": counter,
	}, state, 0))
	return run_checks([
		assert_true(blocked_score <= -2800.0, "Counter Catcher must be held when no Dragapult attack can follow"),
		assert_true(ready_score > -2800.0, "Counter Catcher protection must release for a ready Phantom Dive"),
	])


func test_raging_bolt_funds_the_primary_core_before_bloodmoon() -> String:
	var strategy := _delegate_for_deck(800018509)
	if strategy == null:
		return assert_true(false, "Raging Bolt delegate should resolve")
	var state := _state(13)
	var player: PlayerState = state.players[0]
	var bloodmoon := _slot(_real_card("CSV8C_172", 0))
	var bolt := _slot(_real_card("CSV7C_154", 0))
	_attach_basic_energy(bolt, "L")
	player.active_pokemon = bloodmoon
	player.bench = [bolt]
	var fighting := _basic_energy("F", 0)
	var finisher_score := float(strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": fighting, "target_slot": bloodmoon,
	}, state, 0))
	var core_score := float(strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": fighting, "target_slot": bolt,
	}, state, 0))
	_attach_basic_energy(bolt, "F")
	var released_score := float(strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": fighting, "target_slot": bloodmoon,
	}, state, 0))
	return run_checks([
		assert_true(finisher_score <= -3000.0, "Bloodmoon must not consume the Fighting Energy needed by the primary Raging Bolt"),
		assert_true(core_score >= finisher_score + 4000.0, "The missing Raging Bolt core type must win the current attachment"),
		assert_true(released_score > finisher_score + 2000.0, "Bloodmoon attachment protection must release after a Bolt core is ready"),
	])


func test_ns_zoroark_gust_requires_a_real_copy_attack() -> String:
	var strategy := _delegate_for_deck(800018502)
	if strategy == null:
		return assert_true(false, "N's Zoroark delegate should resolve")
	var state := _state(33)
	var player: PlayerState = state.players[0]
	var zoroark := _slot(_real_card("CSV10C_145", 0))
	_attach_basic_energy(zoroark, "D")
	_attach_basic_energy(zoroark, "D")
	player.active_pokemon = zoroark
	var boss := _real_card("CSVH1aC_023", 0)
	var empty_copy_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": boss,
	}, state, 0))
	zoroark.damage_counters = 30
	player.bench = [_slot(_real_card("CSV10C_166", 0))]
	var real_copy_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": boss,
	}, state, 0))
	return run_checks([
		assert_true(empty_copy_score <= -2800.0, "Paid Night Joker energy is not an attack window without a benched N attack to copy"),
		assert_true(real_copy_score > empty_copy_score + 2000.0, "Gust protection must release once Night Joker has a positive-damage copy"),
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


func _filler_card(card_name: String, owner_index: int) -> CardInstance:
	var data := CardData.new()
	data.name = card_name
	data.name_en = card_name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 120
	data.attacks = [{"name": "Test attack", "cost": "C", "damage": "10"}]
	return CardInstance.create(data, owner_index)


func _basic_energy(energy_type: String, owner_index: int) -> CardInstance:
	var data := CardData.new()
	data.name = "%s Energy" % energy_type
	data.name_en = "%s Energy" % energy_type
	data.card_type = "Basic Energy"
	data.energy_provides = energy_type
	return CardInstance.create(data, owner_index)


func _slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card != null:
		slot.pokemon_stack.append(card)
	return slot


func _attach_basic_energy(slot: PokemonSlot, energy_type: String) -> void:
	slot.attached_energy.append(_basic_energy(energy_type, 0))
