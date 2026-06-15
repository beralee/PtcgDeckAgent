class_name TestCsv9cTrainerStadiumEnergyEffects
extends TestBase

const Effect176 = preload("res://scripts/effects/trainer_effects/CSV9C176EnergySearchPro.gd")
const Effect178 = preload("res://scripts/effects/trainer_effects/CSV9C178GlassTrumpet.gd")
const Effect180 = preload("res://scripts/effects/trainer_effects/CSV9C180ScrambleSwitch.gd")
const Effect181 = preload("res://scripts/effects/trainer_effects/CSV9C181TeraOrb.gd")
const Effect183 = preload("res://scripts/effects/trainer_effects/CSV9C183PerfectMixer.gd")
const Effect186 = preload("res://scripts/effects/trainer_effects/CSV9C186PreciousTrolley.gd")
const Effect196 = preload("res://scripts/effects/trainer_effects/CSV9C196Crispin.gd")
const Effect198 = preload("res://scripts/effects/trainer_effects/CSV9C198Cilan.gd")
const Effect202 = preload("res://scripts/effects/trainer_effects/CSV9C202Briar.gd")
const Effect204 = preload("res://scripts/effects/trainer_effects/CSV9C204LuciansAppeal.gd")
const Effect190 = preload("res://scripts/effects/tool_effects/CSV9C190CounterGain.gd")
const Effect205 = preload("res://scripts/effects/stadium_effects/CSV9C205GrandTree.gd")
const Effect206 = preload("res://scripts/effects/stadium_effects/CSV9C206VibrantPalace.gd")
const Effect207 = preload("res://scripts/effects/stadium_effects/CSV9C207AreaZeroUnderdepths.gd")
const Effect208 = preload("res://scripts/effects/energy_effects/CSV9C208RichEnergy.gd")
const EffectPenny = preload("res://scripts/effects/trainer_effects/EffectPenny.gd")
const AttackOptionalDiscardStadiumScript = preload("res://scripts/effects/pokemon_effects/AttackOptionalDiscardStadium.gd")
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const CSV9CHelpers = preload("res://scripts/effects/CSV9CHelpers.gd")


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _slot(_pokemon("Active %d" % pi, "C"), pi)
		state.players.append(player)
	return state


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _pokemon(
	name: String,
	energy_type: String = "C",
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	effect_id: String = "",
	evolves_from: String = "",
	ancient_trait: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.mechanic = mechanic
	cd.effect_id = effect_id
	cd.evolves_from = evolves_from
	cd.ancient_trait = ancient_trait
	return cd


func _energy(name: String, energy_type: String, card_type: String = "Basic Energy", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	cd.effect_id = effect_id
	return cd


func _trainer(name: String, card_type: String, effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _read_card_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _slot(cd: CardData, owner_index: int, turn_played: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(cd, owner_index))
	slot.turn_played = turn_played
	return slot


func _prizes(player: PlayerState, count: int) -> void:
	player.prizes.clear()
	for i: int in count:
		player.prizes.append(CardInstance.create(_trainer("Prize %d" % i, "Item"), player.player_index))


func test_csv9c_remote_trainer_stadium_energy_effect_ids_register() -> String:
	var processor := EffectProcessor.new()
	var remote_fixed_ids := [
		"bccf47163b5058460ec0a00ddb08d0bb",
		"3f27c81408709eb3ad93c81b1fbb516f",
		"1da701b43813d6ddb1238e54bce95811",
		"93e504a96d675da78630b8a27ee6199b",
		"e6d017f040bcadf0006755aa929897b7",
		"a36548792cb4ff401f9b56e3ade897f6",
		"41925a41899add8220e9815466adc265",
		"fa8d8691876be30f245bc878d0a29745",
		"e0ed0e3e0a6b9e63a201fa79e390a054",
		"a7a9d14928bdbaf4ec973a65ac878999",
		"49665630511298f462fb938a0e1b3096",
		"4e63e9081027157f00910ffd8c55c02e",
		"4622932a419f939cc537e765a5bbe543",
		"cf3124da3d7bf217f7969b6ae4e60e38",
		"257e65746310895c10fff95ce172415d",
	]
	var checks: Array[String] = []
	for effect_id: String in remote_fixed_ids:
		checks.append(assert_true(processor.has_effect(effect_id), "%s should register as a CSV9C fixed effect alias" % effect_id))
	return run_checks(checks)


func test_csv9c_metadata_matches_tcg_missing_fields() -> String:
	var card112 := _read_card_json("res://data/bundled_user/cards/CSV9C_112.json")
	var card190 := _read_card_json("res://data/bundled_user/cards/CSV9C_190.json")
	return run_checks([
		assert_eq(str(card112.get("label", "")), "Ancient", "CSV9C_112 should carry the Ancient label"),
		assert_eq(str(card190.get("set_code_en", "")), "LOT", "CSV9C_190 should carry the English set code"),
		assert_eq(str(card190.get("card_index_en", "")), "170", "CSV9C_190 should carry the English card index"),
		assert_eq(str(card190.get("name_en", "")), "Counter Gain", "CSV9C_190 should carry the English card name"),
	])


func test_csv9c_180_scramble_switch_followup_targets_selected_new_active() -> String:
	var state := _make_state()
	var player := state.players[0]
	var old_active := player.active_pokemon
	old_active.attached_energy = [
		CardInstance.create(_energy("Fire Energy", "R"), 0),
		CardInstance.create(_energy("Double Turbo Energy", "C", "Special Energy"), 0),
	]
	var new_active := _slot(_pokemon("New Active", "C"), 0)
	var other_bench := _slot(_pokemon("Other Bench", "C"), 0)
	player.bench = [new_active, other_bench]
	var effect := Effect180.new()
	var card := CardInstance.create(_trainer("Scramble Switch", "Item"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var followup: Array[Dictionary] = effect.get_followup_interaction_steps(card, state, {
		Effect180.SWITCH_STEP_ID: [new_active],
	})

	return run_checks([
		assert_true(effect.can_execute(card, state), "Scramble Switch should be usable with an active and at least one benched Pokemon"),
		assert_eq(steps.size(), 1, "Initial interaction should only ask which benched Pokemon becomes Active"),
		assert_eq(str(steps[0].get("id", "")), Effect180.SWITCH_STEP_ID, "Initial step id should identify the switch target"),
		assert_true(bool(steps[0].get("requires_followup_interaction", false)), "Switch choice should inject the follow-up Energy transfer step"),
		assert_eq(followup.size(), 1, "Selected switch target should create one optional Energy transfer follow-up"),
		assert_eq(str(followup[0].get("id", "")), Effect180.ENERGY_STEP_ID, "Follow-up step should identify the Energy transfer"),
		assert_eq(followup[0].get("source_items", []), old_active.attached_energy, "Only Energy on the old Active should be offered as sources"),
		assert_eq(followup[0].get("target_items", []), [new_active], "Follow-up should only target the selected new Active Pokemon"),
		assert_eq(int(followup[0].get("min_select", -1)), 0, "Energy transfer should allow choosing zero Energy"),
		assert_eq(int(followup[0].get("max_select", -1)), 2, "Energy transfer should allow moving any number of attached Energy"),
	])


func test_csv9c_180_scramble_switch_switches_and_moves_only_selected_energy() -> String:
	var state := _make_state()
	var player := state.players[0]
	var old_active := player.active_pokemon
	var fire := CardInstance.create(_energy("Fire Energy", "R"), 0)
	var special := CardInstance.create(_energy("Double Turbo Energy", "C", "Special Energy"), 0)
	old_active.attached_energy = [fire, special]
	var new_active := _slot(_pokemon("New Active", "C"), 0)
	var other_bench := _slot(_pokemon("Other Bench", "C"), 0)
	player.bench = [new_active, other_bench]
	var effect := Effect180.new()
	var card := CardInstance.create(_trainer("Scramble Switch", "Item"), 0)

	effect.execute(card, [{
		Effect180.SWITCH_STEP_ID: [new_active],
		Effect180.ENERGY_STEP_ID: [
			{"source": fire, "target": new_active},
		],
	}], state)

	return run_checks([
		assert_eq(player.active_pokemon, new_active, "Selected bench Pokemon should become the new Active"),
		assert_true(old_active in player.bench, "Old Active should move to the bench"),
		assert_true(fire in new_active.attached_energy, "Selected Energy should move to the new Active"),
		assert_false(fire in old_active.attached_energy, "Moved Energy should leave the old Active"),
		assert_true(special in old_active.attached_energy, "Unselected Energy should stay on the old Active"),
		assert_false(special in new_active.attached_energy, "Unselected Energy should not move"),
	])


func test_csv9c_180_scramble_switch_allows_zero_energy_transfer() -> String:
	var state := _make_state()
	var player := state.players[0]
	var old_active := player.active_pokemon
	var fire := CardInstance.create(_energy("Fire Energy", "R"), 0)
	old_active.attached_energy = [fire]
	var new_active := _slot(_pokemon("New Active", "C"), 0)
	player.bench = [new_active]
	var effect := Effect180.new()
	var card := CardInstance.create(_trainer("Scramble Switch", "Item"), 0)

	effect.execute(card, [{
		Effect180.SWITCH_STEP_ID: [new_active],
		Effect180.ENERGY_STEP_ID: [],
	}], state)

	return run_checks([
		assert_eq(player.active_pokemon, new_active, "Scramble Switch should still switch when zero Energy is chosen"),
		assert_true(old_active in player.bench, "Old Active should move to the bench when zero Energy is chosen"),
		assert_true(fire in old_active.attached_energy, "Explicit zero transfer should keep attached Energy on the old Active"),
		assert_false(fire in new_active.attached_energy, "Explicit zero transfer should not move Energy"),
	])


func test_csv9c_180_scramble_switch_works_without_attached_energy() -> String:
	var state := _make_state()
	var player := state.players[0]
	var new_active := _slot(_pokemon("New Active", "C"), 0)
	player.bench = [new_active]
	player.active_pokemon.attached_energy.clear()
	var effect := Effect180.new()
	var card := CardInstance.create(_trainer("Scramble Switch", "Item"), 0)
	var steps := effect.get_interaction_steps(card, state)
	var followup := effect.get_followup_interaction_steps(card, state, {
		Effect180.SWITCH_STEP_ID: [new_active],
	})

	effect.execute(card, [{Effect180.SWITCH_STEP_ID: [new_active]}], state)

	return run_checks([
		assert_true(effect.can_execute(card, state), "Scramble Switch should not require attached Energy"),
		assert_eq(steps.size(), 1, "No attached Energy should produce only the switch step"),
		assert_eq(followup.size(), 0, "No attached Energy should not inject an Energy transfer follow-up"),
		assert_eq(player.active_pokemon, new_active, "Scramble Switch should still switch without attached Energy"),
	])


func test_csv9c_176_energy_search_pro_shows_full_deck_and_enforces_unique_types() -> String:
	var state := _make_state()
	var player := state.players[0]
	player.deck.clear()
	var fire_a := CardInstance.create(_energy("Fire A", "R"), 0)
	var fire_b := CardInstance.create(_energy("Fire B", "R"), 0)
	var water := CardInstance.create(_energy("Water", "W"), 0)
	var filler := CardInstance.create(_pokemon("Deck Pokemon"), 0)
	player.deck = [fire_a, fire_b, water, filler]
	var effect := Effect176.new()
	var card := CardInstance.create(_trainer("能量输送PRO", "Item"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)

	effect.execute(card, [{Effect176.STEP_ID: [fire_a, fire_b, water]}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "Energy Search PRO should ask for a full-library search"),
		assert_eq(steps[0].get("card_items", []), [fire_a, fire_b, water, filler], "Full deck should be visible"),
		assert_eq(steps[0].get("card_indices", []), [0, -1, 1, -1], "Duplicate Energy type and non-Energy cards should be visible but disabled"),
		assert_true(fire_a in player.hand, "Selected Fire Energy should move to hand"),
		assert_true(water in player.hand, "Selected Water Energy should move to hand"),
		assert_true(fire_b in player.deck, "Second Fire Energy should be rejected by unique-type rule"),
	])


func test_csv9c_176_headless_fallback_uses_unique_energy_without_type_error() -> String:
	var state := _make_state()
	var player := state.players[0]
	player.deck.clear()
	var fire_a := CardInstance.create(_energy("Fire A", "R"), 0)
	var fire_b := CardInstance.create(_energy("Fire B", "R"), 0)
	var water := CardInstance.create(_energy("Water", "W"), 0)
	player.deck = [fire_a, fire_b, water]
	var effect := Effect176.new()
	var card := CardInstance.create(_trainer("Energy Search PRO", "Item"), 0)

	effect.execute(card, [], state)

	return run_checks([
		assert_true(fire_a in player.hand, "Fallback should move the first Fire Energy to hand"),
		assert_true(water in player.hand, "Fallback should move a different-type Energy to hand"),
		assert_true(fire_b in player.deck, "Fallback should keep duplicate Energy types in deck"),
	])


func test_csv9c_178_glass_trumpet_requires_tera_and_attaches_to_colorless_bench() -> String:
	var state := _make_state()
	var player := state.players[0]
	var effect := Effect178.new()
	var card := CardInstance.create(_trainer("玻璃喇叭", "Item"), 0)
	var colorless_a := _slot(_pokemon("Colorless A", "C"), 0)
	var colorless_b := _slot(_pokemon("Colorless B", "C"), 0)
	var water_bench := _slot(_pokemon("Water Bench", "W"), 0)
	player.bench = [colorless_a, colorless_b, water_bench]
	var energy_a := CardInstance.create(_energy("Fire", "R"), 0)
	var energy_b := CardInstance.create(_energy("Water", "W"), 0)
	player.discard_pile = [energy_a, energy_b]
	var can_without_tera := effect.can_execute(card, state)
	player.active_pokemon = _slot(_pokemon("Tera Active", "C", 120, "Basic", "", "", "", "Tera"), 0)
	var can_with_tera := effect.can_execute(card, state)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)

	effect.execute(card, [{
		Effect178.ASSIGNMENT_ID: [
			{"source": energy_a, "target": colorless_a},
			{"source": energy_b, "target": colorless_b},
		],
	}], state)

	return run_checks([
		assert_false(can_without_tera, "Glass Trumpet should be unusable without own Tera Pokemon"),
		assert_true(can_with_tera, "Glass Trumpet should be usable with own Tera Pokemon, discard Energy, and Colorless bench targets"),
		assert_eq(steps[0].get("target_items", []), [colorless_a, colorless_b], "Only Benched Colorless Pokemon should be legal targets"),
		assert_true(energy_a in colorless_a.attached_energy, "First Basic Energy should attach to first selected target"),
		assert_true(energy_b in colorless_b.attached_energy, "Second Basic Energy should attach to second selected target"),
		assert_false(energy_a in player.discard_pile, "Attached Energy should leave discard"),
	])


func test_csv9c_178_explicit_empty_assignment_does_not_fallback() -> String:
	var state := _make_state()
	var player := state.players[0]
	var tera := _slot(_pokemon("Tera", "C", 120, "Basic", "Tera", "", "", ""), 0)
	player.bench.append(tera)
	var colorless := _slot(_pokemon("Colorless Bench", "C"), 0)
	player.bench.append(colorless)
	var grass := CardInstance.create(_energy("Grass", "G"), 0)
	player.discard_pile.append(grass)
	var effect := Effect178.new()
	var card := CardInstance.create(_trainer("玻璃喇叭", "Item"), 0)
	effect.execute(card, [{Effect178.ASSIGNMENT_ID: []}], state)

	return run_checks([
		assert_true(grass in player.discard_pile, "Explicitly declining Glass Trumpet should not fall back to auto attachment"),
		assert_false(grass in colorless.attached_energy, "Explicit empty Glass Trumpet context should attach no Energy"),
	])


func test_csv9c_181_tera_orb_shows_full_deck_and_searches_tera_pokemon() -> String:
	var state := _make_state()
	var player := state.players[0]
	var tera := CardInstance.create(_pokemon("Tera Pokemon", "R", 180, "Basic", "", "", "", "Tera"), 0)
	var normal := CardInstance.create(_pokemon("Normal Pokemon", "R"), 0)
	player.deck = [normal, tera]
	var effect := Effect181.new()
	var card := CardInstance.create(_trainer("太晶珠", "Item"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)

	effect.execute(card, [{Effect181.STEP_ID: [tera]}], state)

	return run_checks([
		assert_eq(steps[0].get("card_items", []), [normal, tera], "Tera Orb should show the complete searched deck"),
		assert_eq(steps[0].get("card_indices", []), [-1, 0], "Only Tera Pokemon should be selectable"),
		assert_true(tera in player.hand, "Selected Tera Pokemon should move to hand"),
		assert_true(normal in player.deck, "Non-Tera Pokemon should remain in deck"),
	])


func test_csv9c_183_perfect_mixer_discards_up_to_five_selected_deck_cards() -> String:
	var state := _make_state()
	var player := state.players[0]
	player.deck.clear()
	for i: int in 6:
		player.deck.append(CardInstance.create(_trainer("Deck Card %d" % i, "Item"), 0))
	var selected := player.deck.duplicate()
	var keep_card: CardInstance = player.deck[5]
	var effect := Effect183.new()
	var card := CardInstance.create(_trainer("完美搅拌器", "Item"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)

	effect.execute(card, [{Effect183.STEP_ID: selected}], state)

	return run_checks([
		assert_eq(steps[0].get("card_items", []), selected, "Perfect Mixer should expose every deck card"),
		assert_eq(player.discard_pile.size(), 5, "Perfect Mixer should discard no more than five selected cards"),
		assert_true(keep_card in player.deck, "Sixth selected card should remain in deck"),
	])


func test_csv9c_186_precious_trolley_respects_bench_space_and_full_deck_visibility() -> String:
	var state := _make_state()
	var player := state.players[0]
	player.bench.clear()
	for i: int in 4:
		player.bench.append(_slot(_pokemon("Existing %d" % i), 0))
	var basic_a := CardInstance.create(_pokemon("Basic A"), 0)
	var basic_b := CardInstance.create(_pokemon("Basic B"), 0)
	var stage_one := CardInstance.create(_pokemon("Stage One", "C", 90, "Stage 1", "", "", "Basic A"), 0)
	player.deck = [basic_a, stage_one, basic_b]
	var effect := Effect186.new()
	var card := CardInstance.create(_trainer("贵重推车", "Item"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)

	effect.execute(card, [{Effect186.STEP_ID: [basic_a, basic_b]}], state)

	return run_checks([
		assert_eq(int(steps[0].get("max_select", -1)), 1, "Precious Trolley should cap selection by remaining Bench space"),
		assert_eq(steps[0].get("card_indices", []), [0, -1, 1], "Only Basic Pokemon should be selectable while the full deck is visible"),
		assert_eq(player.bench.size(), 5, "Bench should fill only to its legal limit"),
		assert_true(basic_a not in player.deck or basic_b not in player.deck, "One selected Basic Pokemon should be benched"),
		assert_true(stage_one in player.deck, "Evolution Pokemon should stay in deck"),
	])


func test_csv9c_190_counter_gain_reduces_colorless_cost_only_when_behind() -> String:
	var gsm := _make_gsm()
	var attacker := gsm.game_state.players[0].active_pokemon
	var tool_cd := _trainer("反击增幅器", "Tool", "csv9c190")
	attacker.attached_tool = CardInstance.create(tool_cd, 0)
	gsm.effect_processor.register_effect("csv9c190", Effect190.new())
	_prizes(gsm.game_state.players[0], 4)
	_prizes(gsm.game_state.players[1], 3)
	var behind_modifier := gsm.effect_processor.get_attack_colorless_cost_modifier(attacker, {"cost": "CC"}, gsm.game_state)
	_prizes(gsm.game_state.players[0], 3)
	var tied_modifier := gsm.effect_processor.get_attack_colorless_cost_modifier(attacker, {"cost": "CC"}, gsm.game_state)

	return run_checks([
		assert_eq(behind_modifier, -1, "Counter Gain should reduce one Colorless cost when its owner has more Prize cards remaining"),
		assert_eq(tied_modifier, 0, "Counter Gain should not apply when Prize counts are tied"),
	])


func test_csv9c_196_crispin_moves_one_energy_to_hand_and_attaches_a_different_type() -> String:
	var state := _make_state()
	var player := state.players[0]
	var fire := CardInstance.create(_energy("Fire", "R"), 0)
	var fire_duplicate := CardInstance.create(_energy("Fire Duplicate", "R"), 0)
	var water := CardInstance.create(_energy("Water", "W"), 0)
	var filler := CardInstance.create(_trainer("Filler", "Item"), 0)
	player.deck = [fire, fire_duplicate, water, filler]
	var effect := Effect196.new()
	var card := CardInstance.create(_trainer("赤松", "Supporter"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var followup: Array[Dictionary] = effect.get_followup_interaction_steps(card, state, {
		Effect196.HAND_STEP_ID: [fire],
	})
	var followup_step: Dictionary = followup[0] if not followup.is_empty() else {}

	effect.execute(card, [{
		Effect196.HAND_STEP_ID: [fire],
		Effect196.ATTACH_STEP_ID: [{"source": water, "target": player.active_pokemon}],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "Crispin should ask for hand Energy first, then build attachment from that choice"),
		assert_true(bool(steps[0].get("requires_followup_interaction", false)), "Crispin hand Energy step should declare the attachment follow-up"),
		assert_eq(steps[0].get("card_indices", []), [0, -1, 1, -1], "Crispin hand step should show full deck and disable duplicate Energy types"),
		assert_eq(followup.size(), 1, "Crispin should offer an attachment follow-up after a hand Energy is selected"),
		assert_eq(followup_step.get("source_items", []), [water], "Crispin follow-up should only allow a different Energy type from the hand choice"),
		assert_eq(followup_step.get("source_card_indices", []), [-1, -1, 0, -1], "Crispin attachment follow-up should show full deck and only enable different-type Energy"),
		assert_true(fire in player.hand, "Chosen first Energy should move to hand"),
		assert_true(water in player.active_pokemon.attached_energy, "Different-type remaining Energy should attach to own Pokemon"),
		assert_true(fire_duplicate in player.deck, "Duplicate type should remain in deck"),
	])


func test_csv9c_196_does_not_attach_without_hand_energy_choice() -> String:
	var state := _make_state()
	var player := state.players[0]
	player.deck.clear()
	var fire := CardInstance.create(_energy("Fire", "R"), 0)
	var water := CardInstance.create(_energy("Water", "W"), 0)
	player.deck.append_array([fire, water])
	var effect := Effect196.new()
	var card := CardInstance.create(_trainer("赤松", "Supporter"), 0)
	effect.execute(card, [{
		Effect196.ATTACH_STEP_ID: [{"source": water, "target": player.active_pokemon}],
	}], state)

	return run_checks([
		assert_true(water in player.deck, "Crispin should not attach an Energy when no Energy was chosen for hand"),
		assert_false(water in player.active_pokemon.attached_energy, "Crispin attachment is illegal without the required hand Energy"),
	])


func test_csv9c_196_crispin_no_attachment_followup_without_hand_energy_choice() -> String:
	var state := _make_state()
	var player := state.players[0]
	var fire := CardInstance.create(_energy("Fire", "R"), 0)
	var water := CardInstance.create(_energy("Water", "W"), 0)
	player.deck = [fire, water]
	var effect := Effect196.new()
	var card := CardInstance.create(_trainer("赤松", "Supporter"), 0)
	var followup: Array[Dictionary] = effect.get_followup_interaction_steps(card, state, {
		Effect196.HAND_STEP_ID: [],
	})

	return run_checks([
		assert_eq(followup.size(), 0, "Crispin should not show an attachment step when the player takes no Energy into hand"),
	])


func test_csv9c_196_ai_keeps_crispin_interactive_for_followup_attachment() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player := state.players[0]
	var fire := CardInstance.create(_energy("Fire", "R"), 0)
	var water := CardInstance.create(_energy("Water", "W"), 0)
	player.deck = [fire, water]
	var crispin := CardInstance.create(_trainer("赤松", "Supporter", "136fdb6578daa3b81aef369495de4c3d"), 0)
	player.hand = [crispin]
	gsm.effect_processor.register_effect("136fdb6578daa3b81aef369495de4c3d", Effect196.new())
	var builder = AILegalActionBuilderScript.new()
	var actions: Array[Dictionary] = builder.build_actions(gsm, 0)
	var crispin_action: Dictionary = {}
	for action: Dictionary in actions:
		if action.get("kind", "") == "play_trainer" and action.get("card") == crispin:
			crispin_action = action
			break

	return run_checks([
		assert_false(crispin_action.is_empty(), "AI should enumerate Crispin when the deck has searchable Basic Energy"),
		assert_true(bool(crispin_action.get("requires_interaction", false)), "AI should keep Crispin interactive because the attachment step depends on the hand Energy choice"),
		assert_eq(crispin_action.get("targets", []), [], "AI should not fall back to blind automatic Crispin targets before the follow-up is resolved"),
	])


func test_csv9c_198_cilan_searches_only_pokemon_ex_with_full_deck_visible() -> String:
	var state := _make_state()
	var player := state.players[0]
	var ex_card := CardInstance.create(_pokemon("Pokemon ex", "L", 220, "Basic", "ex"), 0)
	var v_card := CardInstance.create(_pokemon("Pokemon V", "L", 220, "Basic", "V"), 0)
	var normal := CardInstance.create(_pokemon("Normal", "L"), 0)
	player.deck = [normal, ex_card, v_card]
	var effect := Effect198.new()
	var card := CardInstance.create(_trainer("席蓝", "Supporter"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)

	effect.execute(card, [{Effect198.STEP_ID: [v_card, ex_card]}], state)

	return run_checks([
		assert_eq(steps[0].get("card_indices", []), [-1, 0, -1], "Only Pokemon ex should be selectable"),
		assert_true(ex_card in player.hand, "Selected Pokemon ex should move to hand"),
		assert_true(v_card in player.deck, "Pokemon V should not be accepted as Pokemon ex"),
	])


func test_csv9c_202_briar_sets_turn_flag_and_helper_requires_tera_attacker() -> String:
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	_prizes(player, 4)
	_prizes(opponent, 3)
	var effect := Effect202.new()
	var card := CardInstance.create(_trainer("白蕾雅", "Supporter"), 0)
	var can_with_three_prizes := effect.can_execute(card, state)
	_prizes(opponent, 2)
	player.active_pokemon = _slot(_pokemon("Tera Attacker", "R", 180, "Basic", "", "", "", "Tera"), 0)
	effect.execute(card, [], state)
	var applies_with_tera := Effect202.should_apply_extra_prize(state, player.active_pokemon, opponent.active_pokemon)
	player.active_pokemon = _slot(_pokemon("Normal Attacker", "R"), 0)
	var applies_without_tera := Effect202.should_apply_extra_prize(state, player.active_pokemon, opponent.active_pokemon)

	return run_checks([
		assert_false(can_with_three_prizes, "Briar should only be playable when opponent has exactly two Prize cards remaining"),
		assert_true(Effect202.is_active_for_player(state, 0), "Briar should mark this player for the current turn"),
		assert_true(applies_with_tera, "Briar helper should identify a Tera attacker hitting opponent Active"),
		assert_false(applies_without_tera, "Briar helper should reject non-Tera attackers"),
	])


func test_csv9c_204_lucians_appeal_switches_basic_bench_and_confuses_new_active() -> String:
	var state := _make_state()
	var opponent := state.players[1]
	var old_active := opponent.active_pokemon
	var basic := _slot(_pokemon("Basic Bench", "G"), 1)
	var stage_one := _slot(_pokemon("Stage One Bench", "G", 90, "Stage 1", "", "", "Basic Bench"), 1)
	opponent.bench = [stage_one, basic]
	var effect := Effect204.new()
	var card := CardInstance.create(_trainer("琉琪亚的展现", "Supporter"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)

	effect.execute(card, [{Effect204.STEP_ID: [basic]}], state)

	return run_checks([
		assert_eq(steps[0].get("items", []), [basic], "Lucian's Appeal should target only Benched Basic Pokemon"),
		assert_eq(opponent.active_pokemon, basic, "Selected Basic Bench Pokemon should become Active"),
		assert_true(opponent.active_pokemon.status_conditions.get("confused", false), "New Active Pokemon should be Confused"),
		assert_true(opponent.active_pokemon.entered_active_from_bench_this_turn(state.turn_number), "Lucian's Appeal should mark the new Active as entered from Bench"),
		assert_true(old_active in opponent.bench, "Previous Active Pokemon should move to Bench"),
	])


func test_csv9c_205_grand_tree_evolves_stage1_then_optional_stage2_from_full_deck() -> String:
	var state := _make_state()
	state.turn_number = 3
	var player := state.players[0]
	player.active_pokemon = _slot(_pokemon("Seed", "G"), 0, 0)
	var stage1 := CardInstance.create(_pokemon("Tree Stage1", "G", 100, "Stage 1", "", "", "Seed"), 0)
	var stage2 := CardInstance.create(_pokemon("Tree Stage2", "G", 160, "Stage 2", "", "", "Tree Stage1"), 0)
	var unrelated := CardInstance.create(_pokemon("Other Stage1", "G", 100, "Stage 1", "", "", "Other"), 0)
	player.deck = [unrelated, stage1, stage2]
	var effect := Effect205.new()
	var stadium := CardInstance.create(_trainer("伟大巨树", "Stadium"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(stadium, state)
	var followup: Array[Dictionary] = effect.get_followup_interaction_steps(stadium, state, {
		Effect205.STAGE1_STEP_ID: [{"source": stage1, "target": player.active_pokemon}],
	})

	effect.execute(stadium, [{
		Effect205.STAGE1_STEP_ID: [{"source": stage1, "target": player.active_pokemon}],
		Effect205.STAGE2_STEP_ID: [{"source": stage2, "target": player.active_pokemon}],
	}], state)

	state.turn_number = 2
	state.first_player_index = 1
	var first_turn_blocked := effect.can_execute(stadium, state)

	return run_checks([
		assert_eq(steps[0].get("source_card_indices", []), [-1, 0, -1], "Grand Tree Stage 1 step should expose full deck and only enable matching Stage 1 cards"),
		assert_eq(followup.size(), 1, "Grand Tree should offer an optional Stage 2 follow-up after a Stage 1 choice"),
		assert_true(bool(steps[0].get("requires_followup_interaction", false)), "Grand Tree Stage 1 choice should declare that a follow-up may be needed"),
		assert_eq(followup[0].get("source_card_indices", []), [-1, -1, 0], "Stage 2 follow-up should expose full deck and only enable matching Stage 2 cards"),
		assert_eq(player.active_pokemon.pokemon_stack.size(), 3, "Grand Tree should evolve through Stage 1 and Stage 2"),
		assert_eq(player.active_pokemon.get_pokemon_name(), "Tree Stage2", "Top Pokemon should be the selected Stage 2"),
		assert_eq(player.active_pokemon.turn_evolved, 3, "Grand Tree should mark the evolution turn"),
		assert_false(first_turn_blocked, "Grand Tree should not be usable on that player's first turn"),
	])


func test_csv9c_205_no_default_stage2_and_ai_keeps_followup_interaction() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	state.turn_number = 3
	var player := state.players[0]
	player.active_pokemon = _slot(_pokemon("Seed", "G"), 0, 0)
	var stage1 := CardInstance.create(_pokemon("Tree Stage1", "G", 100, "Stage 1", "", "", "Seed"), 0)
	var stage2 := CardInstance.create(_pokemon("Tree Stage2", "G", 160, "Stage 2", "", "", "Tree Stage1"), 0)
	player.deck = [stage1, stage2]
	var stadium_cd := _trainer("伟大巨树", "Stadium", "csv9c205")
	var stadium := CardInstance.create(stadium_cd, 0)
	state.stadium_card = stadium
	state.stadium_owner_index = 0
	gsm.effect_processor.register_effect("csv9c205", Effect205.new())
	var builder = AILegalActionBuilderScript.new()
	var actions: Array[Dictionary] = builder.build_actions(gsm, 0, true)
	var stadium_action: Dictionary = {}
	for action: Dictionary in actions:
		if action.get("kind", "") == "use_stadium_effect":
			stadium_action = action
			break

	var effect := Effect205.new()
	effect.execute(stadium, [{
		Effect205.STAGE1_STEP_ID: [{"source": stage1, "target": player.active_pokemon}],
	}], state)

	return run_checks([
		assert_true(bool(stadium_action.get("requires_interaction", false)), "AI should keep Grand Tree as interactive because Stage 2 follow-up cannot be preview-resolved"),
		assert_eq(player.active_pokemon.pokemon_stack.size(), 2, "Grand Tree should not auto-pick a Stage 2 when no Stage 2 context is supplied"),
		assert_true(stage2 in player.deck, "Unchosen Stage 2 should remain in deck"),
	])


func test_csv9c_039_return_to_hand_block_respects_ability_disabled() -> String:
	var state := _make_state()
	var player := state.players[0]
	player.bench.append(_slot(_pokemon("Bench", "C"), 0))
	var milotic_cd := _pokemon("Milotic", "W", 120, "Stage 1", "", "88b2885578a73494f1eed7c2b53e67c7", "Feebas")
	var milotic := _slot(milotic_cd, 1)
	state.players[1].bench.append(milotic)
	var penny := EffectPenny.new()
	var card := CardInstance.create(_trainer("牡丹", "Supporter"), 0)
	var blocked := penny.can_execute(card, state)
	milotic.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	var enabled_after_disable := penny.can_execute(card, state)

	return run_checks([
		assert_false(blocked, "Milotic should block opponent return-to-hand effects while its Ability is active"),
		assert_true(enabled_after_disable, "Return-to-hand effects should become legal when Milotic's Ability is disabled"),
	])


func test_csv9c_039_remote_milotic_return_to_hand_block() -> String:
	var state := _make_state()
	state.players[0].bench.append(_slot(_pokemon("Bench", "C"), 0))
	var remote_milotic_cd := _pokemon("Remote Milotic", "W", 120, "Stage 1", "", "57aa4d41e927a2f1cdf846f73509b907", "Feebas")
	state.players[1].bench.append(_slot(remote_milotic_cd, 1))
	var penny := EffectPenny.new()
	var card := CardInstance.create(_trainer("Penny", "Supporter"), 0)

	return run_checks([
		assert_false(penny.can_execute(card, state), "Remote Milotic effectId should block opponent return-to-hand effects"),
	])


func test_csv9c_206_vibrant_palace_adds_hp_only_to_basic_pokemon() -> String:
	var gsm := _make_gsm()
	var basic := gsm.game_state.players[0].active_pokemon
	var stage_one := _slot(_pokemon("Stage One", "C", 100, "Stage 1", "", "", "Active 0"), 0)
	gsm.game_state.players[0].bench.append(stage_one)
	var stadium_cd := _trainer("振奋竞技场", "Stadium", "csv9c206")
	gsm.game_state.stadium_card = CardInstance.create(stadium_cd, 0)
	gsm.effect_processor.register_effect("csv9c206", Effect206.new())

	return run_checks([
		assert_eq(gsm.effect_processor.get_effective_max_hp(basic, gsm.game_state), 130, "Vibrant Palace should add 30 HP to Basic Pokemon"),
		assert_eq(gsm.effect_processor.get_effective_max_hp(stage_one, gsm.game_state), 100, "Vibrant Palace should not add HP to Evolution Pokemon"),
	])


func test_csv9c_206_remote_vibrant_palace_effect_id_modifies_hp() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var basic := state.players[0].active_pokemon
	state.stadium_card = CardInstance.create(_trainer("Remote Vibrant Palace", "Stadium", "4622932a419f939cc537e765a5bbe543"), 0)
	state.stadium_owner_index = 0

	return run_checks([
		assert_true(gsm.effect_processor.has_effect("4622932a419f939cc537e765a5bbe543"), "Remote Vibrant Palace effectId should register"),
		assert_eq(gsm.effect_processor.get_effective_max_hp(basic, state), 130, "Remote Vibrant Palace should add 30 HP to Basic Pokemon"),
		assert_true(CSV9CHelpers.slot_label(basic, state).contains("130"), "Remote Vibrant Palace should be reflected in slot labels"),
	])


func test_csv9c_207_area_zero_underdepths_expands_only_tera_player_bench_limit() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player := state.players[0]
	var opponent := state.players[1]
	player.active_pokemon = _slot(_pokemon("太晶宝可梦", "L", 200, "Basic", "ex", "cd845155473716c29f29efa29da0a869", "", "Tera"), 0)
	for i: int in 5:
		player.bench.append(_slot(_pokemon("Own Bench %d" % i), 0))
		opponent.bench.append(_slot(_pokemon("Opp Bench %d" % i), 1))
	var stadium_cd := _trainer("零之大空洞", "Stadium", Effect207.EFFECT_ID)
	var stadium := CardInstance.create(stadium_cd, 0)
	player.hand.append(stadium)

	var registered := gsm.effect_processor.has_effect(Effect207.EFFECT_ID)
	var played := gsm.play_stadium(0, stadium)

	return run_checks([
		assert_true(registered, "Area Zero Underdepths should be registered by effect_id"),
		assert_true(played, "Area Zero Underdepths should be playable through the normal Stadium flow"),
		assert_eq(BenchLimitHelper.get_bench_limit(state, player), 8, "Area Zero should expand the bench limit for a player with Tera in play"),
		assert_eq(BenchLimitHelper.get_bench_limit(state, opponent), 5, "Area Zero should keep the normal bench limit for a player without Tera"),
		assert_false(BenchLimitHelper.is_bench_full(state, player), "A Tera player with five Benched Pokemon should still have room"),
		assert_true(BenchLimitHelper.is_bench_full(state, opponent), "A non-Tera player with five Benched Pokemon should be full"),
	])


func test_csv9c_207_remote_area_zero_effect_id_expands_bench_limit() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player := state.players[0]
	var opponent := state.players[1]
	player.active_pokemon = _slot(_pokemon("Tera Active", "L", 200, "Basic", "ex", "", "", "Tera"), 0)
	for i: int in 5:
		player.bench.append(_slot(_pokemon("Own Bench %d" % i), 0))
		opponent.bench.append(_slot(_pokemon("Opp Bench %d" % i), 1))
	var stadium_cd := _trainer("Remote Area Zero", "Stadium", Effect207.REMOTE_EFFECT_ID)
	var stadium := CardInstance.create(stadium_cd, 0)
	player.hand.append(stadium)

	var registered := gsm.effect_processor.has_effect(Effect207.REMOTE_EFFECT_ID)
	var played := gsm.play_stadium(0, stadium)

	return run_checks([
		assert_true(registered, "Remote Area Zero effectId should be registered"),
		assert_true(played, "Remote Area Zero should be playable through the normal Stadium flow"),
		assert_true(Effect207.is_area_zero_active(state), "Remote Area Zero should count as active Area Zero"),
		assert_eq(BenchLimitHelper.get_bench_limit(state, player), 8, "Remote Area Zero should expand the bench limit for a player with Tera in play"),
		assert_eq(BenchLimitHelper.get_bench_limit(state, opponent), 5, "Remote Area Zero should keep the normal bench limit for a player without Tera"),
	])


func test_csv9c_remote_pokemon_attack_usage_gates_match_local_effect_ids() -> String:
	var state := _make_state()
	var validator := RuleValidator.new()
	var sylveon_cd := _pokemon("Remote Sylveon", "P", 270, "Stage 1", "ex", "61fb0755be18f5fcdc6a30781d5fc05e", "Eevee", "Tera")
	sylveon_cd.attacks = [
		{"name": "Magical Charm", "cost": "PCC", "damage": "160", "text": "", "is_vstar_power": false},
		{"name": "Angelite", "cost": "WLP", "damage": "", "text": "", "is_vstar_power": false},
	]
	var sylveon := _slot(sylveon_cd, 0)
	state.players[0].active_pokemon = sylveon
	state.turn_number = 4
	state.shared_turn_flags["csv9c_angelite_used_p0"] = 2
	var sylveon_gate := str(validator.call("_fails_special_attack_usage_gate", state, 0, sylveon, 1))

	var terapagos_cd := _pokemon("Remote Terapagos", "C", 230, "Basic", "ex", "5de19cbd4b2d1ff80ba14d6d89246ae9", "", "Tera")
	terapagos_cd.attacks = [
		{"name": "Unified Beat", "cost": "C", "damage": "30x", "text": "", "is_vstar_power": false},
	]
	var terapagos := _slot(terapagos_cd, 1)
	state.players[1].active_pokemon = terapagos
	state.turn_number = 2
	state.current_player_index = 1
	state.first_player_index = 0
	var terapagos_gate := str(validator.call("_fails_special_attack_usage_gate", state, 1, terapagos, 0))

	return run_checks([
		assert_true(sylveon_gate != "", "Remote Sylveon effectId should keep Angelite's next-turn lock"),
		assert_true(terapagos_gate != "", "Remote Terapagos effectId should keep the second-player first-turn attack gate"),
	])


func test_csv9c_207_area_zero_underdepths_trims_when_stadium_leaves() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player := state.players[0]
	player.active_pokemon = _slot(_pokemon("Tera Active", "L", 200, "Basic", "ex", Effect207.EFFECT_ID, "", "Tera"), 0)
	for i: int in 8:
		player.bench.append(_slot(_pokemon("Bench %d" % i), 0))
	var zero_cd := _trainer("零之大空洞", "Stadium", Effect207.EFFECT_ID)
	var zero := CardInstance.create(zero_cd, 0)
	state.stadium_card = zero
	state.stadium_owner_index = 0
	var other_stadium := CardInstance.create(_trainer("Other Stadium", "Stadium", "other_stadium"), 0)
	player.hand.append(other_stadium)

	var before_limit := BenchLimitHelper.get_bench_limit(state, player)
	var played_replacement := gsm.play_stadium(0, other_stadium)

	return run_checks([
		assert_eq(before_limit, 8, "Area Zero should allow eight Bench Pokemon while Tera is in play"),
		assert_true(played_replacement, "Replacing Area Zero should be legal"),
		assert_eq(player.bench.size(), 5, "Replacing Area Zero should trim the player back to five Bench Pokemon"),
		assert_eq(player.discard_pile.size(), 4, "Old Stadium plus three excess Bench Pokemon should be in discard"),
		assert_eq(player.discard_pile[1].card_data.name, "Bench 7", "Default cleanup should discard from the rightmost Bench slots first"),
	])


func test_csv9c_207_area_zero_underdepths_prompts_connected_ui_before_cleanup() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player := state.players[0]
	player.active_pokemon = _slot(_pokemon("Tera Active", "L", 200, "Basic", "ex", Effect207.EFFECT_ID, "", "Tera"), 0)
	for i: int in 8:
		player.bench.append(_slot(_pokemon("Bench %d" % i), 0))
	var zero := CardInstance.create(_trainer("Area Zero Underdepths", "Stadium", Effect207.EFFECT_ID), 0)
	state.stadium_card = zero
	state.stadium_owner_index = 0
	var other_stadium := CardInstance.create(_trainer("Other Stadium", "Stadium", "other_stadium"), 0)
	player.hand.append(other_stadium)
	var prompt: Dictionary = {}
	gsm.player_choice_required.connect(func(choice_type: String, data: Dictionary) -> void:
		prompt["type"] = choice_type
		prompt["data"] = data
	)

	var played_replacement := gsm.play_stadium(0, other_stadium)
	var prompt_data: Dictionary = prompt.get("data", {})
	var steps: Array = prompt_data.get("steps", [])
	var first_step: Dictionary = steps[0] if not steps.is_empty() and steps[0] is Dictionary else {}
	var bench_size_before_choice := player.bench.size()
	var selected_slots: Array[PokemonSlot] = [player.bench[0], player.bench[2], player.bench[4]]
	var context := {
		str(first_step.get("id", "")): selected_slots,
	}
	var cleaned := gsm.enforce_current_bench_limits("test_prompt_resolution", 0, "", -1, [context])

	return run_checks([
		assert_true(played_replacement, "Replacing Area Zero should still complete before the mandatory cleanup choice"),
		assert_eq(str(prompt.get("type", "")), "bench_limit_cleanup", "Connected UI should receive a cleanup prompt instead of automatic discard"),
		assert_eq(bench_size_before_choice, 8, "The cleanup prompt should not discard Bench Pokemon before the player chooses"),
		assert_eq(steps.size(), 1, "Only the overflowing player should be prompted"),
		assert_false(bool(first_step.get("allow_cancel", true)), "Area Zero cleanup should be mandatory"),
		assert_true(bool(first_step.get("force_dialog", false)), "Area Zero cleanup should use the popup dialog path"),
		assert_eq(player.bench.size(), 5, "Selected cleanup should trim the bench after the prompt is resolved"),
		assert_true(cleaned, "Resolving the cleanup prompt should discard the selected Bench Pokemon"),
		assert_eq(player.discard_pile.size(), 4, "Old Stadium plus three selected Bench Pokemon should be in discard"),
		assert_eq(player.discard_pile[1].card_data.name, "Bench 0", "Prompt resolution should respect the first selected Bench slot"),
	])


func test_csv9c_207_area_zero_underdepths_trims_when_player_loses_tera() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player := state.players[0]
	player.active_pokemon = _slot(_pokemon("Tera Active", "L", 200, "Basic", "ex", Effect207.EFFECT_ID, "", "Tera"), 0)
	for i: int in 8:
		player.bench.append(_slot(_pokemon("Bench %d" % i), 0))
	state.stadium_card = CardInstance.create(_trainer("零之大空洞", "Stadium", Effect207.EFFECT_ID), 0)
	state.stadium_owner_index = 0

	player.active_pokemon = _slot(_pokemon("Plain Active", "C"), 0)
	var cleaned := gsm.enforce_current_bench_limits("test_loses_tera", 0)

	return run_checks([
		assert_true(cleaned, "Losing the only Tera Pokemon should trigger Area Zero cleanup"),
		assert_eq(BenchLimitHelper.get_bench_limit(state, player), 5, "Without Tera in play, the player's Area Zero limit should return to five"),
		assert_eq(player.bench.size(), 5, "Area Zero cleanup should trim excess Bench Pokemon"),
		assert_eq(player.discard_pile.size(), 3, "Three excess Bench Pokemon should be discarded"),
	])


func test_csv9c_207_area_zero_active_tera_knockout_cleans_before_replacement() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	state.current_player_index = 1
	state.turn_number = 5
	state.phase = GameState.GamePhase.POKEMON_CHECK
	var player := state.players[0]
	var opponent := state.players[1]
	var terapagos := _slot(_pokemon("Terapagos ex", "C", 230, "Basic", "ex", "", "", "Tera"), 0)
	terapagos.damage_counters = 230
	player.active_pokemon = terapagos
	player.bench.clear()
	for bench_name: String in [
		"Blastoise ex",
		"Pidgeot ex",
		"Noctowl",
		"Hoothoot",
		"Fan Rotom",
		"Bidoof",
		"Bibarel",
		"Lapras ex",
	]:
		player.bench.append(_slot(_pokemon(bench_name, "W", 120, "Basic", "ex" if bench_name.ends_with("ex") else ""), 0))
	player.deck.clear()
	for i: int in 3:
		player.deck.append(CardInstance.create(_trainer("Player0 Deck %d" % i, "Item"), 0))
	_prizes(player, 6)
	_prizes(opponent, 6)
	state.stadium_card = CardInstance.create(_trainer("Area Zero Underdepths", "Stadium", Effect207.EFFECT_ID), 0)
	state.stadium_owner_index = 0
	var choice_events: Array[Dictionary] = []
	gsm.player_choice_required.connect(func(choice_type: String, data: Dictionary) -> void:
		choice_events.append({"type": choice_type, "data": data.duplicate(true)})
	)

	var limit_before_knockout := BenchLimitHelper.get_bench_limit(state, player)
	gsm._check_all_knockouts()
	var bench_after_knockout_before_cleanup := player.bench.size()
	var active_removed_before_replacement := player.active_pokemon == null
	var limit_after_knockout := BenchLimitHelper.get_bench_limit(state, player)
	var first_prompt_type := str(choice_events[0].get("type", "")) if not choice_events.is_empty() else ""
	var cleanup_prompt: Dictionary = choice_events[0].get("data", {}) if not choice_events.is_empty() else {}
	var cleanup_steps: Array = cleanup_prompt.get("steps", [])
	var cleanup_step: Dictionary = cleanup_steps[0] if not cleanup_steps.is_empty() and cleanup_steps[0] is Dictionary else {}
	var cleanup_context := {
		str(cleanup_step.get("id", "")): [
			player.bench[player.bench.size() - 3],
			player.bench[player.bench.size() - 2],
			player.bench[player.bench.size() - 1],
		],
	}
	var cleaned := gsm.enforce_current_bench_limits("bench_limit_cleanup", 0, "", -1, [cleanup_context])
	var bench_after_cleanup_before_prizes := player.bench.size()
	var take_prize_prompt_index := -1
	for i: int in choice_events.size():
		if str(choice_events[i].get("type", "")) == "take_prize":
			take_prize_prompt_index = i
			break
	var prize_one_resolved := gsm.resolve_take_prize(1, 0)
	var prize_two_resolved := gsm.resolve_take_prize(1, 1)
	var send_out_prompt_index := -1
	var event_types: Array[String] = []
	for i: int in choice_events.size():
		event_types.append(str(choice_events[i].get("type", "")))
		if str(choice_events[i].get("type", "")) == "send_out_pokemon":
			send_out_prompt_index = i
	var bench_before_send_out := player.bench.size()
	var replacement := player.bench[0]
	var sent_out := gsm.send_out_pokemon(0, replacement)
	var total_pokemon_after_send_out := player.bench.size()
	if player.active_pokemon != null:
		total_pokemon_after_send_out += 1

	return run_checks([
		assert_eq(limit_before_knockout, 8, "Area Zero should start with an eight-card Bench for the 17.0 Terapagos setup"),
		assert_eq(first_prompt_type, "bench_limit_cleanup", "Knocking out the only Tera Pokemon should clean Area Zero excess before prizes or replacement"),
		assert_eq(bench_after_knockout_before_cleanup, 8, "The Bench should still be full while the mandatory cleanup prompt is waiting"),
		assert_true(active_removed_before_replacement, "The knocked-out Terapagos ex should leave Active before replacement"),
		assert_eq(limit_after_knockout, 5, "Losing the only Tera Pokemon should collapse the live Bench limit to five"),
		assert_eq(int(cleanup_step.get("min_select", -1)), 3, "Cleanup before send-out should discard three excess Benched Pokemon"),
		assert_eq(int(cleanup_step.get("max_select", -1)), 3, "Cleanup before send-out should not wait until a replacement reduces the excess"),
		assert_true(cleaned, "Resolving the cleanup prompt should resume the knockout flow"),
		assert_eq(bench_after_cleanup_before_prizes, 5, "After pre-replacement cleanup, five Pokemon should remain on the Bench"),
		assert_true(take_prize_prompt_index > 0, "Prize taking should be prompted only after Area Zero cleanup"),
		assert_true(prize_one_resolved, "The first prize should resolve before replacement"),
		assert_true(prize_two_resolved, "The second ex prize should resolve before replacement"),
		assert_true(send_out_prompt_index > take_prize_prompt_index, "The knockout flow should ask for replacement after cleanup and prizes (events=%s phase=%s)" % [str(event_types), str(state.phase)]),
		assert_eq(bench_before_send_out, 5, "Bench cleanup should finish before the replacement choice"),
		assert_true(sent_out, "A Bench Pokemon should be sent out after Area Zero cleanup"),
		assert_eq(player.active_pokemon, replacement, "The selected replacement should become Active"),
		assert_eq(player.bench.size(), 4, "Sending out after cleanup should leave four Benched Pokemon"),
		assert_eq(total_pokemon_after_send_out, 5, "Cleanup-before-replacement should leave one Active plus four Benched Pokemon"),
	])


func test_csv9c_207_area_zero_bench_tera_knockout_cleans_before_prizes() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.POKEMON_CHECK
	var attacker := state.players[0]
	var defender := state.players[1]
	attacker.active_pokemon = _slot(_pokemon("Attacker", "C", 120), 0)
	defender.active_pokemon = _slot(_pokemon("Plain Active", "C", 120), 1)
	var tera_bench := _slot(_pokemon("Bench Terapagos ex", "C", 230, "Basic", "ex", "", "", "Tera"), 1)
	tera_bench.damage_counters = 230
	defender.bench.append(tera_bench)
	for i: int in 7:
		defender.bench.append(_slot(_pokemon("Support Bench %d" % i, "C", 70), 1))
	_prizes(attacker, 6)
	_prizes(defender, 6)
	state.stadium_card = CardInstance.create(_trainer("Area Zero Underdepths", "Stadium", Effect207.EFFECT_ID), 1)
	state.stadium_owner_index = 1
	var choice_events: Array[Dictionary] = []
	gsm.player_choice_required.connect(func(choice_type: String, data: Dictionary) -> void:
		choice_events.append({"type": choice_type, "data": data.duplicate(true)})
	)

	var limit_before_knockout := BenchLimitHelper.get_bench_limit(state, defender)
	gsm._check_all_knockouts()
	var first_prompt_type := str(choice_events[0].get("type", "")) if not choice_events.is_empty() else ""
	var cleanup_prompt: Dictionary = choice_events[0].get("data", {}) if not choice_events.is_empty() else {}
	var cleanup_steps: Array = cleanup_prompt.get("steps", [])
	var cleanup_step: Dictionary = cleanup_steps[0] if not cleanup_steps.is_empty() and cleanup_steps[0] is Dictionary else {}
	var bench_after_knockout_before_cleanup := defender.bench.size()
	var take_prize_prompt_index_before_cleanup := -1
	for i: int in choice_events.size():
		if str(choice_events[i].get("type", "")) == "take_prize":
			take_prize_prompt_index_before_cleanup = i
			break
	var cleanup_context := {
		str(cleanup_step.get("id", "")): [
			defender.bench[defender.bench.size() - 2],
			defender.bench[defender.bench.size() - 1],
		],
	}
	var cleaned := gsm.enforce_current_bench_limits("bench_limit_cleanup", 1, "", -1, [cleanup_context])
	var take_prize_prompt_index_after_cleanup := -1
	for i: int in choice_events.size():
		if str(choice_events[i].get("type", "")) == "take_prize":
			take_prize_prompt_index_after_cleanup = i
			break

	return run_checks([
		assert_eq(limit_before_knockout, 8, "Area Zero should start with an expanded Bench while the only Tera is in play"),
		assert_eq(first_prompt_type, "bench_limit_cleanup", "A Benched only-Tera knockout should clean Area Zero excess before prize prompts"),
		assert_eq(bench_after_knockout_before_cleanup, 7, "The knocked-out Tera should leave the Bench while cleanup is pending"),
		assert_eq(int(cleanup_step.get("min_select", -1)), 2, "After the Benched Tera leaves, exactly two excess Bench Pokemon must be discarded"),
		assert_eq(take_prize_prompt_index_before_cleanup, -1, "Prize taking must not be prompted before the mandatory Area Zero cleanup"),
		assert_true(cleaned, "Resolving the cleanup prompt should resume the bench knockout flow"),
		assert_eq(defender.bench.size(), 5, "Area Zero cleanup should trim the AI Bench to five before prizes"),
		assert_true(take_prize_prompt_index_after_cleanup > 0, "Prize prompt should appear after cleanup resolves"),
	])


func test_csv9c_207_lugia_discards_area_zero_then_ko_waits_for_cleanup_before_prizes() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	var attacker := state.players[0]
	var defender := state.players[1]
	var lugia_cd := _pokemon("Lugia V", "C", 220, "Basic", "V", "test_lugia_optional_discard_stadium")
	lugia_cd.attacks = [{"name": "Aero Dive", "cost": "C", "damage": "130", "text": "You may discard a Stadium in play.", "is_vstar_power": false}]
	var lugia := _slot(lugia_cd, 0)
	lugia.attached_energy.append(CardInstance.create(_energy("Colorless Energy", "C"), 0))
	attacker.active_pokemon = lugia
	defender.active_pokemon = _slot(_pokemon("Budew", "G", 30), 1)
	defender.bench.clear()
	defender.bench.append(_slot(_pokemon("Terapagos ex", "C", 230, "Basic", "ex", "", "", "Tera"), 1))
	for i: int in 7:
		defender.bench.append(_slot(_pokemon("Turtle Bench %d" % i, "C", 90), 1))
	_prizes(attacker, 6)
	_prizes(defender, 6)
	state.stadium_card = CardInstance.create(_trainer("Area Zero Underdepths", "Stadium", Effect207.EFFECT_ID), 1)
	state.stadium_owner_index = 1
	gsm.effect_processor.register_effect("test_lugia_optional_discard_stadium", AttackOptionalDiscardStadiumScript.new())
	var choice_events: Array[Dictionary] = []
	gsm.player_choice_required.connect(func(choice_type: String, data: Dictionary) -> void:
		choice_events.append({"type": choice_type, "data": data.duplicate(true)})
	)

	var attacked := gsm.use_attack(0, 0, [{"discard_stadium": ["discard"]}])
	var event_types_after_attack: Array[String] = []
	for event: Dictionary in choice_events:
		event_types_after_attack.append(str(event.get("type", "")))
	var cleanup_prompt: Dictionary = choice_events[0].get("data", {}) if not choice_events.is_empty() else {}
	var cleanup_steps: Array = cleanup_prompt.get("steps", [])
	var cleanup_step: Dictionary = cleanup_steps[0] if not cleanup_steps.is_empty() and cleanup_steps[0] is Dictionary else {}
	var bench_before_cleanup := defender.bench.size()
	var cleanup_context := {
		str(cleanup_step.get("id", "")): [
			defender.bench[defender.bench.size() - 3],
			defender.bench[defender.bench.size() - 2],
			defender.bench[defender.bench.size() - 1],
		],
	}
	var cleaned := gsm.enforce_current_bench_limits("bench_limit_cleanup", 1, "", -1, [cleanup_context])
	var event_types_after_cleanup: Array[String] = []
	for event: Dictionary in choice_events:
		event_types_after_cleanup.append(str(event.get("type", "")))
	var take_prize_prompt_index := -1
	for i: int in choice_events.size():
		if str(choice_events[i].get("type", "")) == "take_prize":
			take_prize_prompt_index = i
			break
	var prize_resolved := gsm.resolve_take_prize(0, 0)

	return run_checks([
		assert_true(attacked, "Lugia V should be able to use Aero Dive and choose to discard Area Zero"),
		assert_eq(state.stadium_card, null, "Aero Dive should discard Area Zero before cleanup is resolved"),
		assert_eq(event_types_after_attack, ["bench_limit_cleanup"], "Aero Dive should pause on Area Zero cleanup and not emit prizes before cleanup (events=%s)" % str(event_types_after_attack)),
		assert_eq(defender.active_pokemon, null, "Budew should leave Active during the attack knockout flow"),
		assert_eq(bench_before_cleanup, 8, "The opponent Bench should remain full while cleanup is pending"),
		assert_eq(int(cleanup_step.get("chooser_player_index", -1)), 1, "The opponent should choose which excess Bench Pokemon to discard"),
		assert_eq(int(cleanup_step.get("min_select", -1)), 3, "Removing Area Zero should force the opponent to discard three excess Bench Pokemon"),
		assert_true(cleaned, "Resolving the Area Zero cleanup should resume the paused attack knockout flow"),
		assert_eq(defender.bench.size(), 5, "Cleanup should trim the opponent Bench to five before prizes"),
		assert_true(take_prize_prompt_index > 0, "Prize taking should be prompted after cleanup resolves (events=%s)" % str(event_types_after_cleanup)),
		assert_true(prize_resolved, "The attacking player should be able to take the Budew prize after cleanup"),
		assert_eq(attacker.prizes.size(), 5, "The attacking player should take exactly one prize"),
	])


func test_csv9c_207_headless_bench_tera_knockout_cleanup_does_not_stall() -> String:
	var gsm := _make_gsm()
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	var state := gsm.game_state
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.POKEMON_CHECK
	var attacker := state.players[0]
	var defender := state.players[1]
	attacker.active_pokemon = _slot(_pokemon("Attacker", "C", 120), 0)
	defender.active_pokemon = _slot(_pokemon("Plain Active", "C", 120), 1)
	var tera_bench := _slot(_pokemon("Bench Terapagos ex", "C", 230, "Basic", "ex", "", "", "Tera"), 1)
	tera_bench.damage_counters = 230
	defender.bench.append(tera_bench)
	for i: int in 7:
		defender.bench.append(_slot(_pokemon("Support Bench %d" % i, "C", 70), 1))
	_prizes(attacker, 6)
	_prizes(defender, 6)
	state.stadium_card = CardInstance.create(_trainer("Area Zero Underdepths", "Stadium", Effect207.EFFECT_ID), 1)
	state.stadium_owner_index = 1

	gsm._check_all_knockouts()
	var pending_after_cleanup := bridge.get_pending_prompt_type()
	var bench_after_cleanup := defender.bench.size()
	var resolved_prize_count := 0
	while bridge.get_pending_prompt_type() == "take_prize":
		if not bridge.resolve_pending_prompt():
			break
		resolved_prize_count += 1
	var pending_after_prize := bridge.get_pending_prompt_type()
	bridge.free()

	return run_checks([
		assert_eq(bench_after_cleanup, 5, "Headless Area Zero cleanup should auto-trim the AI Bench to five immediately"),
		assert_eq(pending_after_cleanup, "take_prize", "Headless cleanup should continue into the normal prize prompt instead of stalling"),
		assert_eq(resolved_prize_count, 2, "Headless bridge should resolve both prizes for the knocked-out Tera ex"),
		assert_eq(pending_after_prize, "", "After prize resolution, the headless bridge should not leave an unsupported cleanup prompt pending"),
		assert_eq(attacker.prizes.size(), 4, "The attacking player should take two prizes after cleanup"),
	])


func test_csv9c_207_area_zero_underdepths_cleanup_respects_start_player_and_choices() -> String:
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	for i: int in 8:
		player.bench.append(_slot(_pokemon("P0 Bench %d" % i), 0))
		opponent.bench.append(_slot(_pokemon("P1 Bench %d" % i), 1))
	var p0_selected: Array[PokemonSlot] = [player.bench[1], player.bench[3], player.bench[5]]
	var p1_selected: Array[PokemonSlot] = [opponent.bench[0], opponent.bench[2], opponent.bench[4]]
	var context := {
		"csv9c207_zero_area_discard_p0": p0_selected,
		"csv9c207_zero_area_discard_p1": p1_selected,
	}

	var cleanup_groups: Array[Dictionary] = Effect207.enforce_bench_limits(state, [context], 1)

	return run_checks([
		assert_eq(cleanup_groups.size(), 2, "Both players should clean up when both benches exceed the default limit"),
		assert_eq(int(cleanup_groups[0].get("player_index", -1)), 1, "Area Zero holder should start simultaneous cleanup"),
		assert_eq(int(cleanup_groups[1].get("player_index", -1)), 0, "The other player should clean up second"),
		assert_eq(player.bench.size(), 5, "Player 0 should be trimmed to five Bench Pokemon"),
		assert_eq(opponent.bench.size(), 5, "Player 1 should be trimmed to five Bench Pokemon"),
		assert_true(p0_selected[0].get_top_card() in player.discard_pile, "Selected Player 0 bench card should be discarded"),
		assert_true(p1_selected[0].get_top_card() in opponent.discard_pile, "Selected Player 1 bench card should be discarded"),
		assert_eq(str(cleanup_groups[0].get("discarded_names", [])[0]), "P1 Bench 0", "Cleanup should preserve selected discard order"),
	])


func test_csv9c_208_rich_energy_provides_colorless_and_draws_four_from_hand_attachment() -> String:
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var rich_cd := _energy("富裕能量", "", "Special Energy", "csv9c208")
	var rich := CardInstance.create(rich_cd, 0)
	player.hand.append(rich)
	player.deck.clear()
	for i: int in 5:
		player.deck.append(CardInstance.create(_trainer("Draw %d" % i, "Item"), 0))
	gsm.effect_processor.register_effect("csv9c208", Effect208.new())

	var attached := gsm.attach_energy(0, rich, player.active_pokemon)

	return run_checks([
		assert_true(attached, "Rich Energy should attach through the normal hand attachment flow"),
		assert_eq(gsm.effect_processor.get_energy_type(rich, gsm.game_state), "C", "Rich Energy should provide Colorless Energy"),
		assert_eq(gsm.effect_processor.get_energy_colorless_count(rich, gsm.game_state), 1, "Rich Energy should provide one Energy unit"),
		assert_eq(player.hand.size(), 4, "Rich Energy should draw four cards after attachment"),
		assert_eq(player.deck.size(), 1, "Rich Energy draw should remove four cards from deck"),
	])
