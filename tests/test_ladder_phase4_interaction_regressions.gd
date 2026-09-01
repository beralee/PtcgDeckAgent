class_name TestLadderPhase4InteractionRegressions
extends TestBase

const EffectKieranScript = preload(
	"res://scripts/effects/trainer_effects/EffectKieran.gd"
)
const EffectAccompanyingFluteScript = preload(
	"res://scripts/effects/trainer_effects/EffectAccompanyingFlute.gd"
)
const AttackOptionalDiscardStadiumScript = preload(
	"res://scripts/effects/pokemon_effects/AttackOptionalDiscardStadium.gd"
)
const AttackDrawToHandSizeScript = preload(
	"res://scripts/effects/pokemon_effects/AttackDrawToHandSize.gd"
)
const PlatformNpcRuleDecisionPortScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/PlatformNpcRuleDecisionPort.gd"
)


func test_csv8c_198_kieran_mode_compiles_as_boolean_and_preserves_followup() -> String:
	var state := _state()
	var player := state.players[0]
	player.bench.append(_slot("Bench", 0))
	var card := CardInstance.create(_card("乌栗", "Supporter"), 0)
	var effect := EffectKieranScript.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var followup: Array[Dictionary] = effect.get_followup_interaction_steps(
		card, state, {EffectKieranScript.MODE_STEP_ID: [true]}
	)
	effect.execute(card, [{EffectKieranScript.MODE_STEP_ID: [false]}], state)
	effect.execute(card, [{EffectKieranScript.MODE_STEP_ID: ["damage_boost"]}], state)
	return run_checks([
		assert_eq(effect.get_ucis_last_error(), "", "Kieran mode must compile through UCIS"),
		assert_eq(steps.size(), 1, "Kieran should expose exactly one mode window"),
		assert_eq(steps[0].get("items", []) if not steps.is_empty() else [], [true, false], "Kieran must encode switch/damage as a boolean window"),
		assert_eq(str((steps[0].get("__ucis", {}) as Dictionary).get("primitive", "")) if not steps.is_empty() else "", "ChooseBoolean", "Kieran must use the registered boolean primitive"),
		assert_eq(followup.size(), 1, "Kieran switch mode must expose a fresh bench target window"),
		assert_eq(int(state.shared_turn_flags.get("kieran_attack_bonus_turn_0", -1)), state.turn_number, "Kieran damage mode must retain its turn-scoped bonus"),
	])


func test_csv8c_175_accompanying_flute_empty_result_compiles_boolean_continue() -> String:
	var state := _state()
	state.players[1].deck.append(CardInstance.create(_card("Opponent Item", "Item"), 1))
	var card := CardInstance.create(_card("配乐之笛", "Item"), 0)
	var effect := EffectAccompanyingFluteScript.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	return run_checks([
		assert_eq(effect.get_ucis_last_error(), "", "Accompanying Flute empty reveal must compile through UCIS"),
		assert_eq(steps.size(), 1, "Accompanying Flute should expose a continue window when no Basic is revealed"),
		assert_eq(steps[0].get("items", []) if not steps.is_empty() else [], [true], "The continue window must use a typed boolean item"),
		assert_eq(str((steps[0].get("__ucis", {}) as Dictionary).get("primitive", "")) if not steps.is_empty() else "", "ChooseBoolean", "The continue window must use ChooseBoolean"),
	])


func test_csv4c_101_optional_stadium_discard_compiles_and_executes() -> String:
	var state := _state()
	var stadium := CardInstance.create(_card("Stadium", "Stadium"), 1)
	state.stadium_card = stadium
	state.stadium_owner_index = 1
	var attacker := state.players[0].active_pokemon
	var effect := AttackOptionalDiscardStadiumScript.new()
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(
		attacker.get_top_card(), {"index": 0}, state
	)
	effect.set_attack_interaction_context([
		{AttackOptionalDiscardStadiumScript.STEP_ID: [true]}
	])
	effect.execute_attack(attacker, state.players[1].active_pokemon, 0, state)
	var legacy_stadium := CardInstance.create(_card("Legacy Stadium", "Stadium"), 1)
	state.stadium_card = legacy_stadium
	state.stadium_owner_index = 1
	effect.set_attack_interaction_context([
		{AttackOptionalDiscardStadiumScript.STEP_ID: ["discard"]}
	])
	effect.execute_attack(attacker, state.players[1].active_pokemon, 0, state)
	return run_checks([
		assert_eq(effect.get_ucis_last_error(), "", "Pidgeot ex optional Stadium discard must compile through UCIS"),
		assert_eq(steps[0].get("items", []) if not steps.is_empty() else [], [false, true], "Keep/discard must use a deterministic boolean order"),
		assert_eq(state.stadium_card, null, "Selecting true must discard the Stadium"),
		assert_true(stadium in state.players[1].discard_pile, "The Stadium must move to its owner's discard pile"),
		assert_true(legacy_stadium in state.players[1].discard_pile, "Legacy string context must remain replay-compatible"),
	])


func test_csv10c_113_optional_draw_to_six_compiles_and_executes() -> String:
	var state := _state()
	var player := state.players[0]
	for index: int in 6:
		player.deck.append(CardInstance.create(_card("Deck %d" % index, "Item"), 0))
	var attacker := player.active_pokemon
	var effect := AttackDrawToHandSizeScript.new(6, 0)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(
		attacker.get_top_card(), {"index": 0}, state
	)
	effect.set_attack_interaction_context([
		{AttackDrawToHandSizeScript.STEP_ID: [true]}
	])
	effect.execute_attack(attacker, state.players[1].active_pokemon, 0, state)
	player.hand.clear()
	for index: int in 6:
		player.deck.append(CardInstance.create(_card("Legacy Deck %d" % index, "Item"), 0))
	effect.set_attack_interaction_context([
		{AttackDrawToHandSizeScript.STEP_ID: ["draw"]}
	])
	effect.execute_attack(attacker, state.players[1].active_pokemon, 0, state)
	return run_checks([
		assert_eq(effect.get_ucis_last_error(), "", "Cynthia's Garchomp ex optional draw must compile through UCIS"),
		assert_eq(steps[0].get("items", []) if not steps.is_empty() else [], [false, true], "Skip/draw must use a deterministic boolean order"),
		assert_eq(player.hand.size(), 6, "Selecting true must draw until the hand contains six cards"),
	])


func test_platform_npc_attack_score_treats_unknown_damage_as_zero() -> String:
	var port := PlatformNpcRuleDecisionPortScript.new()
	var scored: Variant = port.call("_score_option", {}, {
		"index": 0,
		"kind": "attack",
		"projected_damage": null,
		"projected_knockout": false,
	})
	return run_checks([
		assert_true(scored is Dictionary, "A public attack with unknown damage must still receive a deterministic score"),
		assert_eq(int((scored as Dictionary).get("score", -1)) if scored is Dictionary else -1, 8000, "Unknown damage must contribute zero rather than raising a script error"),
	])


func _state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _slot("Active %d" % player_index, player_index)
		state.players.append(player)
	return state


func _slot(name: String, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_pokemon(name), owner))
	return slot


func _pokemon(name: String) -> CardData:
	var card := _card(name, "Pokemon")
	card.stage = "Basic"
	card.hp = 100
	card.energy_type = "C"
	return card


func _card(name: String, card_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = card_type
	return card
