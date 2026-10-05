class_name TestAuthorPublicAttackCost
extends TestBase

const OriginalOwner = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const FLARE := "CSV9.5C_023"
const TERA := "CSV9C_175"
const BEAR := "CSV8C_172"
const CRYSTAL := "CSV8C_186"
const FIRE := "CSVE1C_FIR"
const WATER := "CSVE1C_WAT"
const JET := "CSV4C_129"
var _rows: Array[Dictionary] = []
var _owner_script: Script = OriginalOwner


class SuppressTools extends BaseEffect:
	func suppresses_tool_effects() -> bool:
		return true


class RaiseColorless extends BaseEffect:
	func get_attack_colorless_cost_modifier(_slot: PokemonSlot, _attack: Dictionary, _state: GameState) -> int:
		return 1


func test_crystal_palette_and_printed_cost_negatives() -> String:
	for energy: String in [FIRE, WATER, JET]:
		_case("crystal-flare-" + energy, FLARE, [energy], 6, true, 1, 0, true)
		_case("crystal-tera-" + energy, TERA, [energy], 6, true, 1, 0, true)
	_case("empty-crystal-flare", FLARE, [], 6, true, 1, 1, false)
	_case("wrong-color-no-crystal", FLARE, [WATER], 6, false, 2, 1, false)
	_case("printed-fire-colorless", FLARE, [FIRE, JET], 6, false, 2, 0, true)
	_case("non-tera-no-discount", "CSV4C_101", [JET], 6, true, 2, 1, false)
	return _finish_cases()


func test_bloodmoon_prize_discount_both_seats() -> String:
	for seat: int in [0, 1]:
		for prizes: int in range(1, 7):
			var energy: Array = []
			for _i: int in prizes - 1:
				energy.append(WATER)
			_case("bear-exact-%d-%d" % [seat, prizes], BEAR, energy, prizes, false, prizes - 1, 0, true, {"seat": seat})
			if not energy.is_empty():
				energy.pop_back()
				_case("bear-short-%d-%d" % [seat, prizes], BEAR, energy, prizes, false, prizes - 1, 1, false, {"seat": seat})
	return _finish_cases()


func test_suppression_and_cost_increase() -> String:
	_case("bear-ability-disabled", BEAR, [WATER], 2, false, 5, 4, false, {"disabled": true})
	_case("crystal-tool-suppressed", FLARE, [FIRE], 6, true, 2, 1, false, {"suppress_tool": true})
	_case("increased-cost", FLARE, [FIRE, WATER], 6, false, 3, 1, false, {"increase": true})
	return _finish_cases()


func test_pending_assignment_target_identity() -> String:
	_case("pending-bear-same-target", BEAR, [], 2, false, 1, 0, true, {"pending": WATER})
	_case("pending-bear-other-target", BEAR, [], 2, false, 1, 1, false, {"pending": WATER, "wrong_pending": true})
	_case("pending-disabled-bear", BEAR, [], 2, false, 5, 4, false, {"pending": WATER, "disabled": true})
	_case("pending-crystal-water", FLARE, [], 6, true, 1, 0, true, {"pending": WATER})
	_case("pending-crystal-wrong-target", FLARE, [], 6, true, 1, 1, false, {"pending": WATER, "wrong_pending": true})
	return _finish_cases()


func test_bench_payment_and_current_attack_legality() -> String:
	_case("bench-bear", BEAR, [WATER], 2, false, 1, 0, true, {"bench": true})
	_case("bench-crystal", FLARE, [JET], 6, true, 1, 0, true, {"bench": true})
	_case("paid-first-turn-still-not-legal", FLARE, [FIRE, JET], 6, false, 2, 0, true, {"first_turn": true})
	return _finish_cases()


func test_fresh_prize_counts_recompute_without_cached_readiness() -> String:
	_test_fresh_prize_counts()
	return _finish_cases()


func test_hidden_identities_do_not_change_public_cost() -> String:
	_test_hidden_identity_invariance()
	return _finish_cases()


func _finish_cases() -> String:
	var failures: Array[String] = []
	for row: Dictionary in _rows:
		if not row.get("passed", false):
			failures.append(JSON.stringify(row))
	_rows.clear()
	EffectProcessor.cleanup_live_instances_for_tests()
	return "\n".join(failures)


func _card(uid: String) -> CardData:
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/" + uid + ".json"))
	assert(doc is Dictionary, "card_missing: " + uid)
	return CardData.from_dict(doc)


func _filler(owner: int) -> CardInstance:
	var card := CardData.new()
	card.set_code = "COSTTEST"
	card.card_index = "001"
	card.card_type = "Item"
	return CardInstance.create(card, owner)


func _state(uid: String, energies: Array, prizes: int, crystal: bool, seat: int) -> GameState:
	var state := GameState.new()
	state.players = [PlayerState.new(), PlayerState.new()]
	state.current_player_index = seat
	state.first_player_index = 1 - seat
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	for player: int in [0, 1]:
		state.players[player].player_index = player
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(CardInstance.create(_card(uid if player == seat else TERA), player))
		state.players[player].active_pokemon = slot
		state.players[player].deck = [_filler(player)]
		for _i: int in (3 if player == seat else prizes):
			state.players[player].prizes.append(_filler(player))
	var active := state.players[seat].active_pokemon
	for energy: String in energies:
		active.attached_energy.append(CardInstance.create(_card(energy), seat))
	if crystal:
		active.attached_tool = CardInstance.create(_card(CRYSTAL), seat)
	return state


func _case(label: String, uid: String, energies: Array, prizes: int, crystal: bool, cost: int, debt: int, ready: bool, flags: Dictionary = {}) -> void:
	var seat := int(flags.get("seat", 0))
	var state := _state(uid, energies, prizes, crystal, seat)
	var slot := state.players[seat].active_pokemon
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	gsm.effect_processor.register_pokemon_card(slot.get_card_data())
	if flags.get("disabled", false):
		slot.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	if flags.get("suppress_tool", false) or flags.get("increase", false):
		var stadium := _filler(seat)
		stadium.card_data.card_type = "Stadium"
		stadium.card_data.effect_id = "cost_probe_stadium"
		state.stadium_card = stadium
		gsm.effect_processor.register_effect("cost_probe_stadium", SuppressTools.new() if flags.get("suppress_tool", false) else RaiseColorless.new())
	var context := {}
	var extra: CardInstance = null
	if flags.has("pending"):
		extra = CardInstance.create(_card(flags["pending"]), seat)
		context["pending_assignments"] = [{"source": extra, "target": state.players[1 - seat].active_pokemon if flags.get("wrong_pending", false) else slot}]
	var bridge: PokemonSlot = null
	if flags.get("bench", false):
		bridge = PokemonSlot.new()
		bridge.pokemon_stack.append(CardInstance.create(_card(TERA), seat))
		state.players[seat].active_pokemon = bridge
		state.players[seat].bench = [slot]
	if flags.get("first_turn", false):
		state.turn_number = 1
		state.first_player_index = seat
	var owner: RefCounted = _owner_script.new()
	owner.set("_gsm", gsm)
	var actual: Dictionary = owner.call("_slot_attack_profile", slot, context)
	var snapshot_energy := slot.attached_energy.size()
	# Engine legality is tested on the real slot; pending input is temporary test setup.
	if extra != null and not flags.get("wrong_pending", false):
		slot.attached_energy.append(extra)
	if bridge != null:
		state.players[seat].bench.clear()
		state.players[seat].active_pokemon = slot
	var engine_can_attack := false
	for attack: int in slot.get_card_data().attacks.size():
		engine_can_attack = engine_can_attack or gsm.rule_validator.can_use_attack(state, seat, attack, gsm.effect_processor)
	if extra != null and not flags.get("wrong_pending", false):
		slot.attached_energy.pop_back()
	var expected_legal: bool = ready and not flags.get("first_turn", false)
	var expected_count := energies.size() + (1 if extra != null and not flags.get("wrong_pending", false) else 0)
	var passed: bool = actual.get("minimum_attack_energy_count") == cost and actual.get("energy_debt") == debt and actual.get("attack_ready") == ready \
		and actual.get("attached_energy_count") == expected_count and engine_can_attack == expected_legal and snapshot_energy == energies.size()
	_rows.append({"id": label, "passed": passed, "expected": {"cost": cost, "debt": debt, "ready": ready}, "actual": actual, "engine_can_attack": engine_can_attack})


func _test_fresh_prize_counts() -> void:
	var state := _state(BEAR, [WATER, WATER], 4, false, 0)
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var slot := state.players[0].active_pokemon
	gsm.effect_processor.register_pokemon_card(slot.get_card_data())
	var owner: RefCounted = _owner_script.new()
	owner.set("_gsm", gsm)
	var before: Dictionary = owner.call("_slot_attack_profile", slot, {})
	state.players[1].prizes.pop_back()
	var after: Dictionary = owner.call("_slot_attack_profile", slot, {})
	_rows.append({"id": "fresh-prize-count-no-cache", "passed": before.get("energy_debt") == 1 and before.get("attack_ready") == false \
		and after.get("energy_debt") == 0 and after.get("attack_ready") == true, "before": before, "after": after})


func _test_hidden_identity_invariance() -> void:
	var state := _state(BEAR, [WATER], 2, false, 0)
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var slot := state.players[0].active_pokemon
	gsm.effect_processor.register_pokemon_card(slot.get_card_data())
	var owner: RefCounted = _owner_script.new()
	owner.set("_gsm", gsm)
	state.players[1].hand = [_filler(1)]
	var before: Dictionary = owner.call("_slot_attack_profile", slot, {})
	# Replace all hidden identities, retaining every public count.
	for player: int in [0, 1]:
		for zone: Array in [state.players[player].hand, state.players[player].deck, state.players[player].prizes]:
			for index: int in zone.size():
				zone[index] = CardInstance.create(_card(FIRE), player)
	var after: Dictionary = owner.call("_slot_attack_profile", slot, {})
	_rows.append({"id": "hidden-identities-do-not-enter-profile", "passed": before == after, "before": before, "after": after})
