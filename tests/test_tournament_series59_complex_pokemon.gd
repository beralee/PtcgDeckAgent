extends TestBase

const Cards = preload("res://tests/test_tournament_series59_pokemon.gd")
const Fixtures = preload("res://tests/test_30thdc_cards.gd")
const UIDS := ["CSV1C_044", "CSV1C_071", "CSV3C_005", "CSV5C_021"]
const ASSIGN := "forretress_exploding_energy"
var cards := Cards.new()
var f := Fixtures.new()

func _energy(symbol: String, seat: int = 0) -> CardInstance:
	var card := cards._energy(seat)
	card.card_data.energy_provides = symbol
	card.card_data.energy_type = symbol
	return card

func test_complex_printings_match_exact_api_sources() -> String:
	var checks: Array[String] = []
	for uid: String in UIDS:
		var parts := uid.split("_")
		var db := CardDatabase.get_card(parts[0], parts[1])
		checks.append(assert_not_null(db))
		if db != null:
			checks.append(assert_eq(db.attacks, cards._source_card(uid).attacks))
			checks.append(assert_eq(db.abilities, cards._source_card(uid).abilities))
	return run_checks(checks)

func test_magnezone_counts_all_opponent_energy_units_and_binds_recoil_only_to_second_attack() -> String:
	var checks: Array[String] = []
	for index: int in 2:
		for count: int in [0, 1, 3]:
			var gsm := cards._battle("CSV1C_044")
			var state := gsm.game_state
			var attacker := state.players[0].active_pokemon
			var defender := state.players[1].active_pokemon
			attacker.attached_energy.assign([_energy("L"), _energy("L")])
			if count > 0:
				defender.attached_energy.append(_energy("P", 1))
			if count == 3:
				var bench := f._slot("024", 1)
				bench.attached_energy.append(cards._energy(1, true))
				state.players[1].bench.append(bench)
			checks.append(assert_true(gsm.use_attack(0, index)))
			checks.append(assert_eq(defender.damage_counters, count * 50 if index == 0 else 220))
			checks.append(assert_eq(attacker.damage_counters, 0 if index == 0 else 30))
			gsm.prepare_for_disposal()
	return run_checks(checks)

func test_annihilape_uses_opponents_taken_prizes_and_recoil_is_separate() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		for taken: int in [0, 1, 5]:
			for index: int in 2:
				var gsm := cards._battle("CSV1C_071", seat)
				var state := gsm.game_state
				var attacker := state.players[seat].active_pokemon
				attacker.attached_energy.assign([_energy("F", seat), _energy("F", seat)])
				for _i: int in taken:
					state.players[1-seat].prizes.pop_back()
				checks.append(assert_true(gsm.use_attack(seat, index)))
				checks.append(assert_eq(state.players[1-seat].active_pokemon.damage_counters, taken * 70 if index == 0 else 170))
				checks.append(assert_eq(attacker.damage_counters, 0 if index == 0 else 50))
				gsm.prepare_for_disposal()
	return run_checks(checks)

func test_armarouge_armor_requires_full_hp_and_self_unsuppressed() -> String:
	var checks: Array[String] = []
	for initial: int in [0, 10]:
		for suppressed: bool in [false, true]:
			var gsm := cards._battle("CSV5C_021", 1)
			var state := gsm.game_state
			state.current_player_index = 0
			var defender := state.players[1].active_pokemon
			defender.damage_counters = initial
			if suppressed:
				defender.effects.append({"type": "ability_disabled", "turn": state.turn_number})
			var attacker := state.players[0].active_pokemon
			attacker.get_card_data().attacks = [{"name": "Armor probe", "cost": "C", "damage": "100", "text": ""}]
			attacker.attached_energy.append(_energy("P"))
			checks.append(assert_true(gsm.use_attack(0, 0)))
			checks.append(assert_eq(defender.damage_counters - initial, 20 if initial == 0 and not suppressed else 100))
			gsm.prepare_for_disposal()
	return run_checks(checks)

func test_armarouge_attack_counts_fire_only_with_attached_special_energy() -> String:
	var checks: Array[String] = []
	for fire_count: int in [0, 1, 3]:
		var gsm := cards._battle("CSV5C_021")
		var attacker := gsm.game_state.players[0].active_pokemon
		attacker.attached_energy.assign([_energy("P"), _energy("P")])
		for _i: int in fire_count:
			attacker.attached_energy.append(_energy("R"))
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, 40 + fire_count * 40))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_forretress_assigns_up_to_five_grass_then_self_knockout_awards_two_prizes() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		for amount: int in [0, 2, 5]:
			var gsm := cards._battle("CSV3C_005", seat)
			var state := gsm.game_state
			var player := state.players[seat]
			var forretress := player.active_pokemon
			var top := forretress.get_top_card()
			player.active_pokemon = f._slot("024", seat)
			var target := player.active_pokemon
			player.bench.append(forretress)
			var assignments: Array = []
			for _i: int in 6:
				var energy := _energy("G", seat)
				player.deck.append(energy)
				if assignments.size() < amount:
					assignments.append({"source": energy, "target": target})
			checks.append(assert_true(gsm.use_ability(seat, forretress, 0, [{ASSIGN: assignments}])))
			checks.append(assert_eq(target.attached_energy.size(), amount))
			checks.append(assert_true(top in player.discard_pile, "Ability really Knocks Out its source"))
			checks.append(assert_false(forretress in player.bench))
			var pending := gsm.get_pending_decision_snapshot()
			checks.append(assert_eq(pending.get("owner_player_index"), 1-seat))
			checks.append(assert_eq(pending.get("count"), 2, "Pokemon ex awards two prizes even on own turn"))
			gsm.prepare_for_disposal()
	return run_checks(checks)

func test_forretress_rejects_foreign_duplicate_wrong_type_and_too_many_assignments_without_mutation() -> String:
	var checks: Array[String] = []
	for invalid: String in ["opponent", "self", "wrong_type", "duplicate", "too_many", "stale"]:
		var gsm := cards._battle("CSV3C_005")
		var state := gsm.game_state
		var player := state.players[0]
		var source := player.active_pokemon
		var target := f._slot("024")
		player.bench.append(target)
		var assignments: Array = []
		for _i: int in 6:
			var energy := _energy("G")
			player.deck.append(energy)
			assignments.append({"source": energy, "target": target})
		if invalid != "too_many":
			assignments.resize(1)
		match invalid:
			"opponent": assignments[0].target = state.players[1].active_pokemon
			"self": assignments[0].target = source
			"wrong_type": assignments[0].source.card_data.energy_provides = "P"
			"duplicate": assignments.append(assignments[0])
			"stale": player.deck.erase(assignments[0].source)
		var size_before := player.deck.size()
		checks.append(assert_false(gsm.use_ability(0, source, 0, [{ASSIGN: assignments}]), invalid))
		checks.append(assert_eq(source.damage_counters, 0))
		checks.append(assert_eq(player.deck.size(), size_before))
		checks.append(assert_eq(target.attached_energy.size(), 0))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_forretress_guard_applies_next_opponent_turn_only() -> String:
	var gsm := cards._battle("CSV3C_005")
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.assign([_energy("G"), _energy("G")])
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0))]
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 120))
	var opponent := state.players[1].active_pokemon
	checks.append(assert_eq(gsm.effect_processor.get_defender_modifier(source, state, opponent), -30))
	state.turn_number += 1
	checks.append(assert_eq(gsm.effect_processor.get_defender_modifier(source, state, opponent), 0, "Guard expires after opponent's next turn"))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_forretress_suppression_and_dry_deck_still_resolve_self_knockout() -> String:
	var checks: Array[String] = []
	var gsm := cards._battle("CSV3C_005")
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	var top := source.get_top_card()
	state.players[0].active_pokemon = f._slot("024")
	state.players[0].bench.append(source)
	source.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	checks.append(assert_false(gsm.use_ability(0, source)))
	checks.append(assert_eq(source.damage_counters, 0))
	source.effects.clear()
	checks.append(assert_true(gsm.use_ability(0, source), "Self knockout works even with no Basic Grass in deck"))
	checks.append(assert_true(top in state.players[0].discard_pile))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_all_four_attacks_execute_through_real_host_current_windows() -> String:
	var checks: Array[String] = []
	for uid: String in UIDS:
		var gsm := cards._battle(uid)
		var state := gsm.game_state
		var attacker := state.players[0].active_pokemon
		attacker.attached_energy.assign([f._energy("GRA"), f._energy("GRA"), f._energy("LIG"), f._energy("LIG"), f._energy("FIR")])
		# Annihilape needs real Fighting cards, all other fixtures above are real printings.
		if uid == "CSV1C_071":
			attacker.attached_energy.assign([CardInstance.create(CardDatabase.get_card("CSVE1C", "FIG"), 0)])
		state.players[1].active_pokemon.attached_energy.assign([f._energy("PSY", 1)])
		state.players[1].prizes.pop_back()
		var host: Dictionary = f._host(gsm, 0)
		if not host.get("ok", false):
			gsm.prepare_for_disposal()
			return "Host creation failed " + uid
		var bridge := HeadlessMatchBridge.new()
		bridge.bind(gsm)
		host.owner.run_single_step(bridge, gsm)
		var checkpoint: Dictionary = host.port.pending_checkpoint()
		var handles: Array = []
		f._check_frame(checkpoint, checks, handles)
		var pick := -1
		for option: Dictionary in checkpoint.get("frame", {}).get("options", []):
			if option.get("kind") == "attack" and int(option.get("attack_index", -1)) == 0:
				pick = int(option.index)
		checks.append(assert_true(pick >= 0, uid + " exposes printed first attack"))
		if pick >= 0:
			checks.append(assert_true(host.port.submit(str(checkpoint.window_handle), [pick]).get("ok", false)))
			checks.append(assert_true(host.owner.run_single_step(bridge, gsm)))
			checks.append(assert_false(host.port.submit(str(checkpoint.window_handle), [pick]).get("ok", false)))
			var expected := {"CSV1C_044": 50, "CSV1C_071": 70, "CSV3C_005": 120, "CSV5C_021": 80}
			checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, expected[uid]))
		bridge.bind(null)
		bridge.free()
		f._close_host(host, gsm, 1, checks)
	return run_checks(checks)

func test_forretress_full_host_assignment_windows_and_explicit_decline() -> String:
	var checks: Array[String] = []
	for decline: bool in [false, true]:
		var gsm := cards._battle("CSV3C_005")
		var state := gsm.game_state
		var player := state.players[0]
		var source := player.active_pokemon
		var top := source.get_top_card()
		player.active_pokemon = f._slot("024")
		player.bench.append(source)
		for _i: int in 6:
			player.deck.append(f._energy("GRA"))
		var host: Dictionary = f._host(gsm, 0)
		if not host.get("ok", false):
			gsm.prepare_for_disposal()
			return "Forretress Host creation failed"
		var bridge := HeadlessMatchBridge.new()
		bridge.bind(gsm)
		var handles: Array = []
		var begun := false
		for _tick: int in 80:
			host.owner.run_single_step(bridge, gsm)
			if top in player.discard_pile:
				break
			var checkpoint: Dictionary = host.port.pending_checkpoint()
			if not checkpoint.get("ok", false):
				continue
			f._check_frame(checkpoint, checks, handles)
			var frame: Dictionary = checkpoint.frame
			var choices: Array = []
			if not begun:
				for option: Dictionary in frame.options:
					if option.get("kind") == "use_ability":
						choices = [option.index]
				checks.append(assert_false(choices.is_empty(), "Main exposes Exploding Energy"))
				if choices.is_empty():
					break
				begun = true
			elif not (decline and int(frame.select_semantics.min_count) == 0):
				choices = [frame.options[0].index]
				if int(frame.select_semantics.max_count) >= 5:
					for extra: int in range(1, 5):
						choices.append(frame.options[extra].index)
			checks.append(assert_true(host.port.submit(str(checkpoint.window_handle), choices).get("ok", false)))
		checks.append(assert_true(top in player.discard_pile, "Host actually resolves the ability and self knockout"))
		checks.append(assert_eq(player.active_pokemon.attached_energy.size(), 0 if decline else 5, "Reobserved assignment windows bind five distinct energies or explicit zero"))
		var pending := gsm.get_pending_decision_snapshot()
		checks.append(assert_eq(pending.get("owner_player_index"), 1))
		checks.append(assert_eq(pending.get("count"), 2))
		bridge.bind(null)
		bridge.free()
		f._close_host(host, gsm, handles.size(), checks)
	return run_checks(checks)
