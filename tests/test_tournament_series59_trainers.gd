class_name TestTournamentSeries59Trainers
extends TestBase

const Database := preload("res://scripts/autoload/CardDatabase.gd")
const Restriction := preload("res://scripts/effects/DiscardPileRestrictionHelper.gd")

func _card(uid: String) -> CardData:
	return CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % uid))) if FileAccess.file_exists("res://data/bundled_user/cards/%s.json" % uid) else null

func _slot(owner: int, stage: String = "Basic", damage: int = 80) -> PokemonSlot:
	var data := CardData.new()
	data.name = "Target"
	data.card_type = "Pokemon"
	data.stage = stage
	data.hp = 200
	data.retreat_cost = 2
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	slot.damage_counters = damage
	return slot

func _state() -> GameState:
	var state := GameState.new()
	state.players.append(PlayerState.new())
	state.players.append(PlayerState.new())
	state.players[0].active_pokemon = _slot(0)
	state.players[1].active_pokemon = _slot(1)
	state.players[0].bench.append(_slot(0, "Stage 1", 160))
	state.turn_number = 4
	state.current_player_index = 0
	return state

func test_healing_cards_require_current_own_targets_and_preserve_others() -> String:
	var processor := EffectProcessor.new()
	var checks: Array[String] = []
	for uid: String in ["CSV2C_122", "CSV7C_198", "CSV8C_180", "SVP_341"]:
		var data := _card(uid)
		if data == null:
			checks.append(uid + " source is missing")
			continue
		var card := CardInstance.create(data, 0)
		var effect := processor.get_effect(data.effect_id)
		if effect == null:
			checks.append(uid + " real effect registration is missing")
			continue
		var state := _state()
		var active := state.players[0].active_pokemon
		var bench := state.players[0].bench[0]
		bench.damage_counters = 180 if uid == "CSV7C_198" else 160
		bench.set_status("confused", true)
		var steps := effect.get_interaction_steps(card, state)
		checks.append(assert_false(steps.is_empty(), uid + " actual UCIS target window"))
		if steps.is_empty():
			continue
		var key := str(steps[0].id)
		checks.append(assert_false(processor.execute_card_effect(card, [{key: [state.players[1].active_pokemon]}], state), uid + " rejects opponent target"))
		checks.append(assert_false(processor.execute_card_effect(card, [{key: [bench, bench]}], state), uid + " rejects duplicate target"))
		checks.append(assert_true(processor.execute_card_effect(card, [{key: [bench]}], state), uid + " accepts own bench"))
		var expected := {"CSV2C_122": 110, "CSV7C_198": 0, "CSV8C_180": 10, "SVP_341": 100}
		checks.append(assert_eq(bench.damage_counters, expected[uid], uid + " printed healing amount"))
		checks.append(assert_eq(active.damage_counters, 80, uid + " unselected Active unchanged"))
		checks.append(assert_eq(bench.status_conditions.confused, uid != "SVP_341", uid + " exact status recovery"))
	processor.prepare_for_disposal()
	return run_checks(checks)

func test_poke_vital_cannot_leave_discard_but_ordinary_cards_can() -> String:
	var data := _card("CSV8C_180")
	if data == null: return "Poke Vital A source missing"
	return run_checks([
		assert_false(Restriction.can_move_to_hand_or_deck(CardInstance.create(data, 0))),
		assert_true(Restriction.can_move_to_hand_or_deck(CardInstance.create(_card("CSV2C_122"), 0))),
	])

func test_beach_and_practice_studio_have_exact_stage_scope() -> String:
	var processor := EffectProcessor.new()
	var beach := processor.get_effect(_card("CSV4C_127").effect_id)
	var practice := processor.get_effect(_card("CSV4C_128").effect_id)
	if beach == null or practice == null:
		processor.prepare_for_disposal()
		return "Both real Stadium effects must register"
	var checks: Array[String] = []
	for owner in [0, 1]:
		for stage: String in ["Basic", "Stage 1", "Stage 2"]:
			var slot := _slot(owner, stage)
			checks.append(assert_eq(beach.matches_pokemon(slot), stage == "Basic", "Beach exact Basic scope"))
			checks.append(assert_eq(practice.matches_pokemon(slot), stage == "Stage 1", "Practice exact Stage 1 scope"))
	checks.append(assert_eq(beach.retreat_modifier, -1))
	checks.append(assert_eq(practice.modifier_amount, 10))
	processor.prepare_for_disposal()
	return run_checks(checks)

func test_dangerous_laser_burns_and_confuses_the_opponent_active() -> String:
	var processor := EffectProcessor.new()
	var card := CardInstance.create(_card("CSV8C_178"), 0)
	if processor.get_effect(card.card_data.effect_id) == null:
		processor.prepare_for_disposal()
		return "Dangerous Laser is not registered"
	var state := _state()
	var accepted := processor.execute_card_effect(card, [], state)
	var checks: Array[String] = [assert_true(accepted), assert_true(state.players[1].active_pokemon.status_conditions.burned), assert_true(state.players[1].active_pokemon.status_conditions.confused), assert_false(state.players[0].active_pokemon.has_any_status())]
	processor.prepare_for_disposal()
	return run_checks(checks)
