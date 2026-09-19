extends TestBase

const OwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const PortScript = preload("res://scripts/ai/ptcgdap/host/godot/A3ExternalDecisionPort.gd")
const Competitive = preload("res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd")

class FixedCoins extends CoinFlipper:
	var results: Array[bool] = []
	var calls := 0
	func flip() -> bool:
		calls += 1
		return results.pop_front() if not results.is_empty() else false
	func flip_with_metadata(_metadata: Dictionary) -> bool:
		return flip()


func _card(index: String) -> CardData:
	return CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/30thDC_%s.json" % index)))


func _slot(index: String, seat: int = 0) -> PokemonSlot:
	var result := PokemonSlot.new()
	result.pokemon_stack.append(CardInstance.create(_card(index), seat))
	return result


func _energy(index: String = "PSY", seat: int = 0) -> CardInstance:
	return CardInstance.create(_card(index), seat)


func _battle(index: String, coin: CoinFlipper = null) -> GameStateMachine:
	var gsm := GameStateMachine.new()
	if coin != null:
		gsm.effect_processor.prepare_for_disposal()
		gsm.effect_processor = EffectProcessor.new(coin)
	gsm.effect_processor.bind_game_state_machine(gsm)
	var state := GameState.new()
	gsm.game_state = state
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	state.current_player_index = 0
	state.first_player_index = 1
	state.players = [PlayerState.new(), PlayerState.new()]
	state.shared_turn_flags["_draw_effect_processor"] = gsm.effect_processor
	for seat: int in 2:
		var player := state.players[seat]
		player.player_index = seat
		player.active_pokemon = _slot(index if seat == 0 else "024", seat)
		if seat == 1:
			player.active_pokemon.get_card_data().hp = 1000
		for _i: int in 6:
			player.prizes.append(_energy("PSY", seat))
		for _i: int in 12:
			player.deck.append(_energy("PSY", seat))
	for symbol: String in ["GRA", "FIR", "LIG", "PSY", "PSY", "DAR", "DAR", "PSY"]:
		state.players[0].active_pokemon.attached_energy.append(_energy(symbol))
	gsm.effect_processor.register_pokemon_card(state.players[0].active_pokemon.get_card_data())
	return gsm


func test_plain_attacks_keep_printed_damage_and_no_extra_effects() -> String:
	var checks: Array[String] = []
	for spec: Array in [["005", 0, 60], ["008", 0, 10], ["009", 0, 80], ["012", 0, 30], ["019", 0, 40], ["021", 0, 10], ["021", 1, 20], ["022", 0, 20], ["022", 1, 50]]:
		var gsm := _battle(spec[0])
		var defender := gsm.game_state.players[1].active_pokemon
		checks.append(assert_true(gsm.use_attack(0, spec[1]), "%s attack %d" % [spec[0], spec[1]]))
		checks.append(assert_eq(defender.damage_counters, spec[2], "Printed damage"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_conditional_damage_uses_exact_counts_and_attack_index() -> String:
	var checks: Array[String] = []
	for spec: Array in [["001", 0, 120], ["001", 1, 90], ["014", 0, 90], ["017", 0, 240], ["024", 0, 70], ["024", 1, 100]]:
		var gsm := _battle(spec[0])
		var state := gsm.game_state
		var attacker := state.players[0].active_pokemon
		var defender := state.players[1].active_pokemon
		state.players[0].bench.assign([_slot("005"), _slot("012")])
		state.shared_turn_flags["attack_damage_knockout_names:0:3"] = ["previous ally"]
		attacker.damage_counters = 50
		defender.damage_counters = 10
		checks.append(assert_true(gsm.use_attack(0, spec[1]), "Conditional attack accepted"))
		checks.append(assert_eq(defender.damage_counters - 10, spec[2], "%s conditional damage" % spec[0]))
		gsm.prepare_for_disposal()
	for index: String in ["001", "017"]:
		var gsm := _battle(index)
		var defender := gsm.game_state.players[1].active_pokemon
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(defender.damage_counters, 30 if index == "001" else 100, "No qualifying condition gives printed damage"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_eevee_coin_bonus_is_added_before_weakness_without_preview_rng() -> String:
	var checks: Array[String] = []
	for heads: bool in [true, false]:
		var coins := FixedCoins.new()
		coins.results.assign([heads])
		var gsm := _battle("025", coins)
		var defender := gsm.game_state.players[1].active_pokemon
		defender.get_card_data().weakness_energy = "C"
		defender.get_card_data().weakness_value = "×2"
		AILegalActionBuilder.new().build_actions(gsm, 0)
		checks.append(assert_eq(coins.calls, 0, "Damage preview must not consume the coin"))
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(defender.damage_counters, 80 if heads else 40, "Bonus participates in weakness"))
		checks.append(assert_eq(coins.calls, 1, "Exactly one coin"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_vulpix_fail_azumarill_paralysis_and_murkrow_coin_retreat_lock() -> String:
	var checks: Array[String] = []
	for index: String in ["004", "013", "018"]:
		for heads: bool in [true, false]:
			var coins := FixedCoins.new()
			coins.results.assign([heads])
			var gsm := _battle(index, coins)
			var defender := gsm.game_state.players[1].active_pokemon
			checks.append(assert_true(gsm.use_attack(0, 0)))
			if index == "004":
				checks.append(assert_eq(defender.damage_counters, 30 if heads else 0, "Tails fails attack"))
			elif index == "013":
				checks.append(assert_eq(defender.damage_counters, 90))
				checks.append(assert_eq(defender.status_conditions.paralyzed, heads))
			else:
				checks.append(assert_eq(defender.damage_counters, 20))
				checks.append(assert_eq(defender.effects.any(func(e: Dictionary) -> bool: return e.get("type") == "retreat_lock"), heads))
			checks.append(assert_eq(coins.calls, 1))
			gsm.prepare_for_disposal()
	return run_checks(checks)


func test_cherrim_and_victini_search_counts_and_optional_zero() -> String:
	var checks: Array[String] = []
	for index: String in ["003", "006"]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var player := state.players[0]
		player.bench.append(_slot("005"))
		player.deck.assign([_energy("GRA"), _energy("DAR"), CardInstance.create(_card("002"), 0), CardInstance.create(_card("004"), 0), CardInstance.create(_card("014"), 0)])
		var effects := gsm.effect_processor.get_attack_effects_for_slot(player.active_pokemon, 0)
		if effects.is_empty():
			gsm.prepare_for_disposal()
			return "Missing search effect for %s" % index
		var effect := effects[0]
		var step: Dictionary = effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), player.active_pokemon.get_card_data().attacks[0], state)[0]
		checks.append(assert_eq(step.max_select, 2, "Up to two"))
		checks.append(assert_eq(step.min_select, 0))
		if index == "003":
			checks.append(assert_eq(step.source_items.size(), 2, "Only basic Energy"))
			checks.append(assert_eq(step.source_card_items.size(), 5, "Full deck visible to search UI"))
			var chosen: Array = [{"source": player.deck[0], "target": player.bench[0]}, {"source": player.deck[1], "target": player.bench[0]}]
			checks.append(assert_true(gsm.use_attack(0, 0, [{"energy_assignments": chosen}]), "Can attach both to one Bench target"))
			checks.append(assert_eq(player.bench[0].attached_energy.size(), 2))
		else:
			checks.append(assert_eq(step.items.size(), 2, "Evolution excluded"))
			checks.append(assert_true(gsm.use_attack(0, 0, [{"search_basic_pokemon": []}]), "May choose zero"))
			checks.append(assert_eq(player.bench.size(), 1, "No automatic search fallback after explicit zero"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_comfey_heals_only_chosen_bench_and_potion_can_heal_bench() -> String:
	var gsm := _battle("016")
	var state := gsm.game_state
	var player := state.players[0]
	var first := _slot("005")
	var chosen := _slot("009")
	first.damage_counters = 60
	chosen.damage_counters = 100
	player.active_pokemon.damage_counters = 40
	player.bench.assign([first, chosen])
	var effects := gsm.effect_processor.get_attack_effects_for_slot(player.active_pokemon, 0)
	if effects.is_empty():
		gsm.prepare_for_disposal()
		return "Comfey effect missing"
	var step: Dictionary = effects[0].get_attack_interaction_steps(player.active_pokemon.get_top_card(), player.active_pokemon.get_card_data().attacks[0], state)[0]
	var checks: Array[String] = [assert_eq(step.items, [first, chosen], "Active excluded")]
	checks.append(assert_true(gsm.use_attack(0, 0, [{str(step.id): [chosen]}])))
	checks.append(assert_eq(chosen.damage_counters, 20))
	checks.append(assert_eq(first.damage_counters, 60))
	checks.append(assert_eq(player.active_pokemon.damage_counters, 40))
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	var potion := CardInstance.create(_card("028"), 0)
	player.hand.append(potion)
	var heal := gsm.effect_processor.get_effect(potion.card_data.effect_id)
	if heal == null:
		gsm.prepare_for_disposal()
		return "Potion effect missing"
	var heal_step: Dictionary = heal.get_interaction_steps(potion, state)[0]
	checks.append(assert_true(gsm.play_trainer(0, potion, [{str(heal_step.id): [first]}])))
	checks.append(assert_eq(first.damage_counters, 30, "Potion heals chosen Bench Pokemon"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_zoroark_retreat_aura_requires_bench_stacks_and_obeys_suppression() -> String:
	var gsm := _battle("024")
	var state := gsm.game_state
	var source := _slot("020")
	var second := _slot("020")
	var active := state.players[0].active_pokemon
	active.get_card_data().retreat_cost = 5
	gsm.effect_processor.register_pokemon_card(source.get_card_data())
	state.players[0].bench.assign([source, second])
	var checks: Array[String] = [assert_eq(gsm.effect_processor.get_effective_retreat_cost(active, state), 1, "Two Benched Zoroark reduce cost by four")]
	checks.append(assert_eq(gsm.effect_processor.get_effective_retreat_cost(state.players[1].active_pokemon, state), 2, "Opponent unaffected"))
	source.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	checks.append(assert_eq(gsm.effect_processor.get_effective_retreat_cost(active, state), 3, "Suppressed aura stops contributing"))
	source.effects.clear()
	state.players[0].bench.assign([second, active])
	state.players[0].active_pokemon = source
	checks.append(assert_eq(gsm.effect_processor.get_effective_retreat_cost(active, state), 5, "Only own Active is helped"))
	state.players[0].bench.clear()
	checks.append(assert_eq(gsm.effect_processor.get_effective_retreat_cost(source, state), 1, "Active Zoroark has no own aura"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_hydreigon_flips_once_then_discards_energy_units_in_fresh_windows() -> String:
	var coins := FixedCoins.new()
	coins.results.assign([true, true, false])
	var gsm := _battle("023", coins)
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	var defender := state.players[1].active_pokemon
	var double_data := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSNC_024.json")))
	var double_energy := CardInstance.create(double_data, 1)
	var single := _energy("DAR", 1)
	defender.attached_energy.assign([single, double_energy])
	var effect := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)[0]
	var checks: Array[String] = []
	AILegalActionBuilder.new().build_actions(gsm, 0)
	checks.append(assert_eq(coins.calls, 0, "Preview does not roll"))
	var attack := attacker.get_card_data().attacks[0]
	var steps := effect.get_attack_interaction_steps(attacker.get_top_card(), attack, state)
	effect.get_attack_interaction_steps(attacker.get_top_card(), attack, state)
	checks.append(assert_eq(coins.calls, 3, "Reopening selection cannot reroll three coins"))
	checks.append(assert_eq(steps[0].max_select, 1, "Energy payment proceeds by physical card, reobserving after each"))
	var context := {str(steps[0].id): [double_energy]}
	var finish := effect.get_followup_attack_interaction_steps(attacker.get_top_card(), attack, state, context)
	checks.append(assert_eq(finish.size(), 1, "One Double Turbo can finish, or continue using one unit from each card"))
	if finish.size() == 1:
		context[str(finish[0].id)] = [false]
	checks.append(assert_true(effect.get_followup_attack_interaction_steps(attacker.get_top_card(), attack, state, context).is_empty(), "Explicitly finish with one Double Turbo"))
	checks.append(assert_true(gsm.use_attack(0, 0, [context])))
	checks.append(assert_true(double_energy in state.players[1].discard_pile))
	checks.append(assert_true(single in defender.attached_energy, "Do not discard an extra physical card"))
	checks.append(assert_eq(coins.calls, 3))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_waitress_rejects_seventh_card_without_consuming_supporter() -> String:
	var gsm := _battle("005")
	var state := gsm.game_state
	var player := state.players[0]
	var trainer := CardInstance.create(_card("035"), 0)
	player.hand.append(trainer)
	player.deck.clear()
	for _i: int in 6:
		player.deck.append(CardInstance.create(_card("002"), 0))
	var seventh := _energy("DAR")
	player.deck.append(seventh)
	var before := player.deck.duplicate()
	var checks: Array[String] = [assert_false(gsm.play_trainer(0, trainer, [{"waitress_energy_assignment": [{"source": seventh, "target": player.active_pokemon}]}]), "Top-seven injection must be rejected")]
	checks.append(assert_true(trainer in player.hand, "Invalid selection keeps the trainer"))
	checks.append(assert_eq(player.deck, before, "Invalid selection does not shuffle"))
	checks.append(assert_false(state.supporter_used_this_turn, "Invalid selection does not consume Supporter"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_new_targeted_effects_reject_wrong_owner_before_attack_or_item_consumption() -> String:
	var gsm := _battle("016")
	var state := gsm.game_state
	var player := state.players[0]
	player.active_pokemon.damage_counters = 30
	var bench := _slot("009")
	bench.damage_counters = 80
	player.bench.append(bench)
	var checks: Array[String] = [assert_false(gsm.use_attack(0, 0, [{"csv9c_heal_own_pokemon": [player.active_pokemon]}]), "Comfey cannot select Active")]
	checks.append(assert_eq(state.current_player_index, 0, "Rejected attack keeps turn"))
	var potion := CardInstance.create(_card("028"), 0)
	player.hand.append(potion)
	state.players[1].active_pokemon.damage_counters = 40
	checks.append(assert_false(gsm.play_trainer(0, potion, [{"heal_target": [state.players[1].active_pokemon]}]), "Potion cannot select opponent"))
	checks.append(assert_true(potion in player.hand))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_all_45_source_printings_register_every_rule() -> String:
	var processor := EffectProcessor.new()
	var checks: Array[String] = []
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/30thdc_source.json"))
	checks.append(assert_eq(source.cards.size(), 45, "Complete deluxe set including five basic Energy printings"))
	for raw: Dictionary in source.cards:
		var card := CardData.from_api_json(raw)
		processor.register_pokemon_card(card)
		checks.append(assert_false(CardImplementationStatus.is_unimplemented(card), "%s %s rules registered" % [card.card_index, card.name]))
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(CardInstance.create(card, 0))
		for index: int in card.attacks.size():
			var effects := processor.get_attack_effects_for_slot(slot, index)
			if str(card.attacks[index].get("text", "")) != "":
				checks.append(assert_false(effects.is_empty(), "%s attack %d has its own effect" % [card.card_index, index]))
			else:
				checks.append(assert_true(effects.is_empty(), "%s vanilla attack %d has no unrelated effect" % [card.card_index, index]))
	processor.prepare_for_disposal()
	return run_checks(checks)


func _host(gsm: GameStateMachine, seat: int) -> Dictionary:
	for player: PlayerState in gsm.game_state.players:
		var count := player.deck.size() + player.hand.size() + player.discard_pile.size() + player.prizes.size() + player.lost_zone.size()
		for slot: PokemonSlot in player.get_all_pokemon():
			count += slot.collect_all_cards().size()
		while count < 60:
			player.deck.append(_energy("PSY", player.player_index))
			count += 1
	var port := PortScript.new()
	var created := OwnerScript.create_external(gsm, seat, "30thdc-interactions-%d" % seat, port)
	created["port"] = port
	return created


func _check_frame(checkpoint: Dictionary, checks: Array[String], handles: Array) -> void:
	checks.append(assert_true(bool(checkpoint.get("ok", false)), "Host must publish a current window: %s" % checkpoint.get("code", "")))
	if not bool(checkpoint.get("ok", false)):
		return
	var handle := str(checkpoint.get("window_handle", ""))
	checks.append(assert_false(handle in handles, "Each accepted selection gets a new window"))
	handles.append(handle)
	var frame: Dictionary = checkpoint.get("frame", {}).duplicate(true)
	for option: Dictionary in frame.get("options", []):
		option.erase("option_area_raw")
		option.erase("option_area_index")
	frame["select_semantics"].erase("remain_damage_counter")
	frame["select_semantics"].erase("remain_energy_cost")
	checks.append(assert_eq(Competitive._frame_error(frame), "", "Full public schema accepts the compiled window"))


func _pick(host: Dictionary, step: Dictionary, items: Array, selected: Array, context: Dictionary, checks: Array[String], handles: Array) -> Array:
	var owner: Variant = host.owner
	var port: Variant = host.port
	owner.call("_pick_interaction_items", items, step, context)
	var checkpoint: Dictionary = port.pending_checkpoint()
	_check_frame(checkpoint, checks, handles)
	if not bool(checkpoint.get("ok", false)):
		return []
	var submitted: Dictionary = port.submit(str(checkpoint.window_handle), selected)
	checks.append(assert_true(bool(submitted.get("ok", false)), "Chosen current indexes accepted"))
	var result: Array = owner.call("_pick_interaction_items", items, step, context)
	checks.append(assert_false(bool(port.submit(str(checkpoint.window_handle), selected).get("ok", false)), "Consumed window cannot be replayed"))
	return result


func _assign(host: Dictionary, step: Dictionary, source_index: int, target_index: int, context: Dictionary, checks: Array[String], handles: Array) -> Dictionary:
	var sources: Array = step.source_items
	var selected := _pick(host, step, sources, [source_index], context, checks, handles)
	if selected.size() != 1:
		return {}
	var target_context := context.duplicate()
	target_context["source_card"] = selected[0]
	var targets: Array = step.target_items
	host.owner.call("_pick_interaction_target_index", targets, [], step, target_context)
	var checkpoint: Dictionary = host.port.pending_checkpoint()
	_check_frame(checkpoint, checks, handles)
	if not bool(checkpoint.get("ok", false)):
		return {}
	checks.append(assert_true(bool(host.port.submit(str(checkpoint.window_handle), [target_index]).get("ok", false))))
	var index: int = host.owner.call("_pick_interaction_target_index", targets, [], step, target_context)
	checks.append(assert_eq(index, target_index, "Target bound from the fresh window"))
	return {"source": selected[0], "target": targets[index]} if index >= 0 else {}


func _close_host(host: Dictionary, gsm: GameStateMachine, expected: int, checks: Array[String]) -> void:
	var audit: Dictionary = host.owner.audit_snapshot()
	checks.append(assert_eq(audit.get("policy_successes"), expected, "All expected windows were accepted"))
	for counter: String in ["policy_errors", "same_window_fallbacks", "invalid_outputs", "engine_rejections"]:
		checks.append(assert_eq(audit.get(counter), 0, counter))
	host.owner.close_match()
	gsm.prepare_for_disposal()


func test_waitress_real_host_two_windows_both_seats_and_top_six_visibility() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		var gsm := _battle("005")
		var state := gsm.game_state
		state.current_player_index = seat
		var player := state.players[seat]
		var trainer := CardInstance.create(_card("035"), seat)
		player.hand.append(trainer)
		var chosen := _energy("DAR", seat)
		var seventh := _energy("LIG", seat)
		player.deck.assign([CardInstance.create(_card("002"), seat), chosen, CardInstance.create(_card("014"), seat), CardInstance.create(_card("028"), seat), CardInstance.create(_card("019"), seat), CardInstance.create(_card("005"), seat), seventh])
		player.bench.append(_slot("009", seat))
		var host := _host(gsm, seat)
		if not bool(host.get("ok", false)):
			gsm.prepare_for_disposal()
			return "Waitress Host creation failed: %s" % host
		var effect := gsm.effect_processor.get_effect(trainer.card_data.effect_id)
		var steps := effect.get_interaction_steps(trainer, state)
		checks.append(assert_eq(effect.get_ucis_last_error(), ""))
		checks.append(assert_eq(steps[0].source_card_items.size(), 6, "Only top six visible"))
		checks.append(assert_eq(steps[0].source_items, [chosen], "Seventh card cannot enter current candidates"))
		var handles: Array = []
		var assignment := _assign(host, steps[0], 0, 1, {"pending_effect_card": trainer}, checks, handles)
		checks.append(assert_true(gsm.play_trainer(seat, trainer, [{str(steps[0].id): [assignment]}]), "Real trainer entry executes the accepted assignment"))
		checks.append(assert_true(chosen in player.bench[0].attached_energy))
		checks.append(assert_true(seventh in player.deck))
		checks.append(assert_true(trainer in player.discard_pile))
		_close_host(host, gsm, 2, checks)
	return run_checks(checks)


func test_hydreigon_host_reobserves_between_two_energy_choices() -> String:
	var coins := FixedCoins.new()
	coins.results.assign([true, false, true])
	var gsm := _battle("023", coins)
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	var defender := state.players[1].active_pokemon
	var keep := _energy("GRA", 1)
	var first := _energy("DAR", 1)
	var second := _energy("PSY", 1)
	defender.attached_energy.assign([keep, first, second])
	var host := _host(gsm, 0)
	if not bool(host.get("ok", false)):
		gsm.prepare_for_disposal()
		return "Hydreigon Host creation failed: %s" % host
	var checks: Array[String] = []
	var handles: Array = []
	var effect := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)[0]
	var attack := attacker.get_card_data().attacks[0]
	var step: Dictionary = effect.get_attack_interaction_steps(attacker.get_top_card(), attack, state)[0]
	var pick := _pick(host, step, step.items, [1], {"pending_effect_card": attacker.get_top_card()}, checks, handles)
	var resolved := {str(step.id): pick}
	var followup := effect.get_followup_attack_interaction_steps(attacker.get_top_card(), attack, state, resolved)
	checks.append(assert_eq(followup.size(), 1))
	if followup.size() == 1:
		checks.append(assert_false(first in followup[0].items, "Already selected Energy excluded from next window"))
		resolved[str(followup[0].id)] = _pick(host, followup[0], followup[0].items, [1], {"pending_effect_card": attacker.get_top_card()}, checks, handles)
		checks.append(assert_true(gsm.use_attack(0, 0, [resolved])))
		checks.append(assert_eq(defender.attached_energy, [keep]))
		checks.append(assert_true(first in state.players[1].discard_pile and second in state.players[1].discard_pile))
	checks.append(assert_eq(coins.calls, 3))
	_close_host(host, gsm, 2, checks)
	return run_checks(checks)


func test_search_heal_switch_discard_and_attack_target_host_matrix() -> String:
	var checks: Array[String] = []
	for index: String in ["003", "006", "007", "010", "016", "027", "028", "029", "030", "031", "032", "033", "034", "038", "039"]:
		var coins := FixedCoins.new()
		coins.results.assign([true])
		var is_attack := int(index) <= 27
		var gsm := _battle(index if is_attack else "005", coins)
		var state := gsm.game_state
		var player := state.players[0]
		var opponent := state.players[1]
		var attacker := player.active_pokemon
		player.bench.assign([_slot("005"), _slot("009")])
		player.bench[0].damage_counters = 40
		player.bench[1].damage_counters = 100
		opponent.bench.assign([_slot("005", 1), _slot("009", 1)])
		for slot: PokemonSlot in opponent.bench:
			slot.get_card_data().hp = 1000
		opponent.active_pokemon.attached_energy.append(_energy("GRA", 1))
		var hammer_target := _energy("DAR", 1)
		opponent.bench[1].attached_energy.append(hammer_target)
		player.discard_pile.assign([_energy("GRA"), _energy("DAR")])
		player.deck.assign([CardInstance.create(_card("002"), 0), CardInstance.create(_card("004"), 0), CardInstance.create(_card("014"), 0), _energy("GRA"), _energy("DAR")])
		var source := attacker.get_top_card() if is_attack else CardInstance.create(_card(index), 0)
		if not is_attack:
			player.hand.assign([source, _energy("LIG"), _energy("DAR"), _energy("GRA")])
		var attack_index := 1 if index == "007" else 0
		var effect: BaseEffect = gsm.effect_processor.get_attack_effects_for_slot(attacker, attack_index)[0] if is_attack else gsm.effect_processor.get_effect(source.card_data.effect_id)
		var host := _host(gsm, 0)
		if not bool(host.get("ok", false)):
			gsm.prepare_for_disposal()
			return "%s Host creation failed: %s" % [index, host]
		var steps := effect.get_attack_interaction_steps(source, source.card_data.attacks[attack_index], state) if is_attack else effect.get_interaction_steps(source, state)
		checks.append(assert_eq(effect.get_ucis_last_error(), "", "%s UCIS compiler" % index))
		checks.append(assert_false(steps.is_empty(), "%s must expose actual choices" % index))
		var handles: Array = []
		var resolved: Dictionary = {}
		var context := {"pending_effect_card": source}
		for step: Dictionary in steps:
			if step.get("ui_mode") == "card_assignment":
				resolved[str(step.id)] = [_assign(host, step, 0, step.target_items.size() - 1, context, checks, handles)]
			else:
				var items: Array = step.get("items", []).duplicate()
				if index == "031":
					items.reverse()
				var count := maxi(1, int(step.get("min_select", 0)))
				if index in ["006", "010"]:
					count = int(step.max_select)
				var selected: Array = []
				for offset: int in mini(count, items.size()):
					selected.append(items.size() - 1 - offset)
				if index == "038":
					selected = [items.find(true)]
				resolved[str(step.id)] = _pick(host, step, items, selected, context, checks, handles)
		if not is_attack:
			var followup := effect.get_followup_interaction_steps(source, state, resolved)
			for step: Dictionary in followup:
				var items: Array = step.items
				var selected: Array = []
				for choice: int in int(step.max_select):
					selected.append(choice)
				resolved[str(step.id)] = _pick(host, step, items, selected, context, checks, handles)
		var own_bench_before := player.bench.duplicate()
		var opponent_bench_before := opponent.bench.duplicate()
		checks.append(assert_true(gsm.use_attack(0, attack_index, [resolved]) if is_attack else gsm.play_trainer(0, source, [resolved]), "%s engine accepts resolved Host choices" % index))
		match index:
			"003":
				var assignment: Dictionary = resolved.energy_assignments[0]
				checks.append(assert_true(assignment.source in assignment.target.attached_energy))
			"006":
				checks.append(assert_eq(player.bench.size(), 4, "Victini benches two, not generic one"))
			"007":
				checks.append(assert_eq(opponent.active_pokemon.damage_counters, 50))
				checks.append(assert_eq(opponent.bench[1].damage_counters, 20))
			"010":
				checks.append(assert_eq(player.bench[1].attached_energy.size(), 2, "Both Energy go to the one selected target"))
			"016":
				checks.append(assert_eq(player.bench[1].damage_counters, 20))
			"027":
				checks.append(assert_eq(opponent.bench[1].damage_counters, 120))
				checks.append(assert_true(attacker.attached_energy.is_empty(), "Meteor Shot discards all Energy"))
			"028":
				checks.append(assert_eq(player.bench[1].damage_counters, 70))
			"029":
				checks.append(assert_true(hammer_target in opponent.discard_pile))
			"030", "031":
				checks.append(assert_true(resolved.search_pokemon[0] in player.hand))
				if index == "030":
					for cost: CardInstance in resolved.discard_cards:
						checks.append(assert_true(cost in player.discard_pile))
				else:
					checks.append(assert_false(resolved.search_pokemon[0].card_data.is_rule_box_pokemon()))
			"032":
				checks.append(assert_eq(player.active_pokemon, own_bench_before[1]))
			"033", "039":
				checks.append(assert_eq(opponent.active_pokemon, opponent_bench_before[1]))
			"034":
				checks.append(assert_true(resolved.discard_cards[0] in player.discard_pile))
				checks.append(assert_eq(player.hand.size(), 6))
			"038":
				checks.append(assert_eq(resolved.brocks_scouting_basic.size(), 2))
				for searched: CardInstance in resolved.brocks_scouting_basic:
					checks.append(assert_true(searched in player.hand))
		print("30thDC %s Host accepted windows=%d" % [index, handles.size()])
		_close_host(host, gsm, handles.size(), checks)
	return run_checks(checks)


func test_remaining_attack_and_supporter_semantics() -> String:
	var checks: Array[String] = []
	var gsm := _battle("007")
	var player := gsm.game_state.players[0]
	checks.append(assert_true(gsm.use_attack(0, 0)))
	checks.append(assert_eq(player.hand.size(), 1, "Quick Draw draws exactly one"))
	gsm.prepare_for_disposal()
	for attack_index: int in 2:
		gsm = _battle("015")
		var attacker := gsm.game_state.players[0].active_pokemon
		attacker.damage_counters = 50
		checks.append(assert_true(gsm.use_attack(0, attack_index)))
		checks.append(assert_eq(attacker.damage_counters, 20 if attack_index == 0 else 50, "Only Aurora Gain heals"))
		gsm.prepare_for_disposal()
	gsm = _battle("010")
	var attacker := gsm.game_state.players[0].active_pokemon
	var discard := attacker.attached_energy[0]
	checks.append(assert_true(gsm.use_attack(0, 1, [{"discard_attached_energy_from_self": [discard]}])))
	checks.append(assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, 120))
	checks.append(assert_true(discard in gsm.game_state.players[0].discard_pile))
	gsm.prepare_for_disposal()
	gsm = _battle("011")
	var defender := gsm.game_state.players[1].active_pokemon
	var double_data := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSNC_024.json")))
	defender.attached_energy.assign([CardInstance.create(double_data, 1), _energy("DAR", 1)])
	checks.append(assert_true(gsm.use_attack(0, 0)))
	checks.append(assert_eq(defender.damage_counters, 130, "Mew counts three Energy units"))
	gsm.prepare_for_disposal()
	for spec: Array in [["036", 6, 5], ["037", 6, 4], ["040", 6, 8], ["040", 5, 6]]:
		gsm = _battle("005")
		player = gsm.game_state.players[0]
		player.prizes.resize(spec[1])
		var trainer := CardInstance.create(_card(spec[0]), 0)
		player.hand.assign([trainer, _energy("LIG"), _energy("DAR")])
		gsm.game_state.players[1].hand.assign([_energy("GRA", 1)])
		checks.append(assert_true(gsm.play_trainer(0, trainer, [])))
		checks.append(assert_eq(player.hand.size(), spec[2], "%s exact draw count" % spec[0]))
		if spec[0] == "037":
			checks.append(assert_eq(gsm.game_state.players[1].hand.size(), 4))
		checks.append(assert_true(trainer in player.discard_pile))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_all_45_bundled_printings_match_frozen_source_and_have_images() -> String:
	var checks: Array[String] = []
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/30thdc_source.json"))
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt").split("\n")
	for raw: Dictionary in source.cards:
		var index := str(raw.cardIndex)
		var path := "res://data/bundled_user/cards/30thDC_%s.json" % index
		checks.append(assert_true(FileAccess.file_exists(path), "Bundled %s" % index))
		if not FileAccess.file_exists(path):
			continue
		var bundled := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string(path)))
		var expected := CardData.from_api_json(raw)
		expected.source_provider = "tcg_mik"
		expected.source_url = "https://tcg.mik.moe/cards/30thDC/%s" % index
		expected.source_set_code = "30thDC"
		expected.source_card_index = index
		expected.source_language = "zh-CN"
		expected.source_parser_version = 1
		checks.append(assert_eq(bundled.to_dict(), expected.to_dict(), "Exact source fields %s" % index))
		checks.append(assert_true(path in manifest, "Card in seed manifest"))
		var image_path := "res://data/bundled_user/cards/images/30thDC/%s.png.bin" % index
		checks.append(assert_true(FileAccess.file_exists(image_path), "Image %s" % index))
		checks.append(assert_true(image_path in manifest, "Image in seed manifest"))
	return run_checks(checks)


func test_cherrubi_protection_blocks_damage_and_status_only_next_opponent_turn() -> String:
	var checks: Array[String] = []
	for heads: bool in [true, false]:
		var coins := FixedCoins.new()
		coins.results.assign([heads, true])
		var gsm := _battle("002", coins)
		var state := gsm.game_state
		var protected := state.players[0].active_pokemon
		protected.get_card_data().hp = 1000
		checks.append(assert_true(gsm.use_attack(0, 0)))
		state.current_player_index = 1
		state.turn_number = 5
		state.phase = GameState.GamePhase.MAIN
		state.players[1].active_pokemon = _slot("013", 1)
		state.players[1].active_pokemon.attached_energy.assign([_energy("PSY", 1), _energy("PSY", 1), _energy("PSY", 1)])
		gsm.effect_processor.register_pokemon_card(state.players[1].active_pokemon.get_card_data())
		checks.append(assert_true(gsm.use_attack(1, 0)))
		checks.append(assert_eq(protected.damage_counters, 0 if heads else 90))
		checks.append(assert_eq(protected.status_conditions.paralyzed, not heads, "Hide also prevents attack effects"))
		state.turn_number = 6
		checks.append(assert_false(AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(protected, state), "Protection expires"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_meteor_shot_respects_active_weakness_bench_protection_and_energy_modifier() -> String:
	var checks: Array[String] = []
	for spec: Array in [[false, false, false, 240], [true, false, false, 120], [false, false, true, 200], [true, true, true, 0]]:
		var gsm := _battle("027")
		var state := gsm.game_state
		var attacker := state.players[0].active_pokemon
		var target := state.players[1].active_pokemon
		if spec[0]:
			target = _slot("009", 1)
			state.players[1].bench.append(target)
		target.get_card_data().hp = 1000
		target.get_card_data().weakness_energy = "C"
		target.get_card_data().weakness_value = "×2"
		if spec[1]:
			target.effects.append({"type": "prevent_attack_damage_and_effects", "turn": state.turn_number - 1})
		if spec[2]:
			var data := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSNC_024.json")))
			attacker.attached_energy.append(CardInstance.create(data, 0))
		var count := attacker.attached_energy.size()
		checks.append(assert_true(gsm.use_attack(0, 0, [{"any_target": [target]}])))
		checks.append(assert_eq(target.damage_counters, spec[3], "Correct targeting, weakness and Double Turbo modifier"))
		checks.append(assert_true(attacker.attached_energy.is_empty(), "Energy discarded even when damage is prevented"))
		checks.append(assert_eq(state.players[0].discard_pile.size(), count))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_meteor_shot_rejects_own_target_without_discarding_energy_or_ending_turn() -> String:
	var gsm := _battle("027")
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	var attached := attacker.attached_energy.duplicate()
	var checks: Array[String] = [assert_false(gsm.use_attack(0, 0, [{"any_target": [attacker]}]), "Own target must be rejected")]
	checks.append(assert_eq(attacker.attached_energy, attached))
	checks.append(assert_eq(state.current_player_index, 0))
	checks.append(assert_eq(state.phase, GameState.GamePhase.MAIN))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_hydreigon_zero_heads_short_energy_and_duplicate_selection() -> String:
	var checks: Array[String] = []
	for mode: int in 3:
		var coins := FixedCoins.new()
		coins.results.assign([mode > 0, mode > 0, mode > 0])
		var gsm := _battle("023", coins)
		var state := gsm.game_state
		var attacker := state.players[0].active_pokemon
		var defender := state.players[1].active_pokemon
		var energy := _energy("PSY", 1)
		defender.attached_energy.assign([energy])
		var effect := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)[0]
		var steps := effect.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_card_data().attacks[0], state)
		checks.append(assert_eq(steps.size(), 0 if mode == 0 else 1))
		var selected: Array = [] if mode == 0 else ([energy] if mode == 1 else [energy, energy])
		var result := gsm.use_attack(0, 0, [{"discard_opponent_active_energy": selected}])
		checks.append(assert_eq(result, mode != 2))
		checks.append(assert_eq(defender.attached_energy.size(), 0 if mode == 1 else 1))
		checks.append(assert_eq(coins.calls, 3, "No repeated flips during validation/execution"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_waitress_no_energy_short_deck_and_empty_deck() -> String:
	var checks: Array[String] = []
	for count: int in [0, 2, 7]:
		var gsm := _battle("005")
		var state := gsm.game_state
		var player := state.players[0]
		player.deck.clear()
		for i: int in count:
			player.deck.append(_energy("DAR") if i == 6 else CardInstance.create(_card("004"), 0))
		var energy_before := player.active_pokemon.attached_energy.size()
		var trainer := CardInstance.create(_card("035"), 0)
		player.hand.assign([trainer])
		checks.append(assert_eq(gsm.play_trainer(0, trainer, []), count > 0))
		checks.append(assert_eq(player.deck.size(), count, "No Energy in visible prefix: no attachment"))
		checks.append(assert_eq(player.active_pokemon.attached_energy.size(), energy_before))
		checks.append(assert_eq(trainer in player.discard_pile, count > 0))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_additional_vanilla_attacks_and_all_basic_energy_types() -> String:
	var checks: Array[String] = []
	for spec: Array in [["002", 1, 10], ["003", 1, 50], ["006", 1, 50], ["016", 1, 30], ["020", 0, 90], ["023", 1, 140], ["026", 0, 20]]:
		var gsm := _battle(spec[0], FixedCoins.new())
		checks.append(assert_true(gsm.use_attack(0, spec[1])))
		checks.append(assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, spec[2]))
		gsm.prepare_for_disposal()
	for spec: Array in [["GRA", "G"], ["FIR", "R"], ["LIG", "L"], ["PSY", "P"], ["DAR", "D"]]:
		var gsm := _battle("005")
		var state := gsm.game_state
		var energy := _energy(spec[0])
		var player := state.players[0]
		player.hand.assign([energy])
		checks.append(assert_true(gsm.attach_energy(0, energy, player.active_pokemon)))
		checks.append(assert_true(energy in player.active_pokemon.attached_energy))
		checks.append(assert_eq(gsm.effect_processor.get_energy_colorless_count(energy, state), 1))
		checks.append(assert_eq(energy.card_data.energy_provides, spec[1]))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_all_45_printings_load_in_actual_database_and_decode_images() -> String:
	var checks: Array[String] = []
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/30thdc_source.json"))
	var all_uids: Dictionary = {}
	for card: CardData in CardDatabase.get_all_cards():
		all_uids[card.get_uid()] = true
	for raw: Dictionary in source.cards:
		var index := str(raw.cardIndex)
		var actual: CardData = CardDatabase.get_card("30thDC", index)
		checks.append(assert_not_null(actual, "Actual database %s" % index))
		checks.append(assert_true(all_uids.has("30thDC_%s" % index), "Deck editor pool"))
		if actual != null:
			checks.append(assert_eq(actual.to_dict(), _card(index).to_dict(), "Runtime cache matches bundled printing"))
		checks.append(assert_true(CardData.is_valid_card_image_file("res://data/bundled_user/cards/images/30thDC/%s.png.bin" % index), "Bundled image decodes"))
	print("30thDC actual Godot user directory: %s" % OS.get_user_data_dir())
	return run_checks(checks)


func test_mewtwo_discard_and_brock_evolution_branch_use_current_host_windows() -> String:
	var checks: Array[String] = []
	for index: String in ["010", "038"]:
		var gsm := _battle("010" if index == "010" else "005")
		var state := gsm.game_state
		var player := state.players[0]
		var attacker := player.active_pokemon
		var source := attacker.get_top_card() if index == "010" else CardInstance.create(_card(index), 0)
		player.deck.assign([CardInstance.create(_card("002"), 0), CardInstance.create(_card("014"), 0)])
		if index == "038":
			player.hand.assign([source])
		var host := _host(gsm, 0)
		if not bool(host.get("ok", false)):
			gsm.prepare_for_disposal()
			return "Additional Host creation failed"
		var effect: BaseEffect = gsm.effect_processor.get_attack_effects_for_slot(attacker, 1)[0] if index == "010" else gsm.effect_processor.get_effect(source.card_data.effect_id)
		var steps := effect.get_attack_interaction_steps(source, source.card_data.attacks[1], state) if index == "010" else effect.get_interaction_steps(source, state)
		var resolved: Dictionary = {}
		var handles: Array = []
		var context := {"pending_effect_card": source}
		for step: Dictionary in steps:
			var chosen: int = step.items.size() - 1 if index == "010" else step.items.find(false)
			resolved[str(step.id)] = _pick(host, step, step.items, [chosen], context, checks, handles)
		if index == "010":
			checks.append(assert_true(gsm.use_attack(0, 1, [resolved])))
			checks.append(assert_true(resolved.discard_attached_energy_from_self[0] in player.discard_pile))
			checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 120))
		else:
			var followup := effect.get_followup_interaction_steps(source, state, resolved)
			checks.append(assert_eq(followup.size(), 1))
			for step: Dictionary in followup:
				checks.append(assert_eq(step.max_select, 1))
				checks.append(assert_eq(step.items.size(), 1, "Only Evolution Pokemon"))
				resolved[str(step.id)] = _pick(host, step, step.items, [0], context, checks, handles)
			checks.append(assert_true(gsm.play_trainer(0, source, [resolved])))
			checks.append(assert_eq(player.hand.size(), 1))
			checks.append(assert_eq(player.hand[0].card_data.card_index, "014"))
		_close_host(host, gsm, 1 if index == "010" else 2, checks)
	return run_checks(checks)

