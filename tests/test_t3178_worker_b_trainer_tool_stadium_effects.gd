class_name TestT3178WorkerBTrainerToolStadiumEffects
extends TestBase

const EffectFeatherBallScript = preload("res://scripts/effects/trainer_effects/EffectFeatherBall.gd")
const EffectArezuScript = preload("res://scripts/effects/trainer_effects/EffectArezu.gd")
const EffectAcademyAtNightScript = preload("res://scripts/effects/stadium_effects/EffectAcademyAtNight.gd")

const ANCIENT_CAPSULE_ID := "8da8631aa1827b122ec65b712939ad48"
const GLASSES_ID := "0ad0108e5ab1346d88f6ce11b75028d7"
const FEATHER_BALL_ID := "b029fdcf35f970d5d2254778009fa2fe"
const AREZU_ID := "c29db727ed3ad15978addfc5d8ed6451"
const ACADEMY_ID := "e75fad9484071647f96e9f41beeb4a99"
const POWERGLASS_ID := "1dc38c46be0951b2b135e1df2e5e7767"
const BLACK_BELT_TRAINING_ID := "a444b83881df9e2a0225aee95bbc853a"
const DEFIANCE_VEST_ID := "8661d78f9695838cee64d65fb73ddf58"
const PICNIC_BASKET_ID := "276cc8e3fd9a7b7c18f5da7715fe8460"


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	return state


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _pokemon(name: String, stage: String = "Basic", retreat_cost: int = 1, mechanic: String = "", tags: Array[String] = []) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = 100
	cd.energy_type = "C"
	cd.retreat_cost = retreat_cost
	cd.mechanic = mechanic
	var packed := PackedStringArray()
	for tag: String in tags:
		packed.append(tag)
	cd.is_tags = packed
	return cd


func _attacker(name: String, attack_type: String, damage: String = "100") -> CardData:
	var cd := _pokemon(name, "Basic", 1)
	cd.energy_type = attack_type
	cd.attacks = [{"name": "Hit", "cost": "", "damage": damage, "text": "", "is_vstar_power": false}]
	return cd


func _trainer(name: String, card_type: String, effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _basic_energy(name: String = "Basic Energy", energy_type: String = "C", owner: int = 0) -> CardInstance:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_type
	return CardInstance.create(cd, owner)


func _slot(card_data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	return slot


func _prepare_safe_turn_end(gsm: GameStateMachine) -> void:
	for pi: int in 2:
		var prize := _basic_energy("Prize %d" % pi, "C", pi)
		gsm.game_state.players[pi].set_prizes([prize])
		gsm.game_state.players[pi].deck.append(_basic_energy("Draw %d" % pi, "C", pi))


func _full_deck_step_checks(step: Dictionary, visible_cards: Array, legal_cards: Array, indices: Array, step_id: String) -> Array[String]:
	return [
		assert_eq(str(step.get("id", "")), step_id, "step id should remain stable"),
		assert_eq(step.get("card_items", []), visible_cards, "full deck search must expose every own deck card to UI"),
		assert_eq(step.get("items", []), legal_cards, "items must contain only selectable legal cards"),
		assert_eq(step.get("card_indices", []), indices, "card_indices must map visible cards to selectable indices"),
		assert_eq(str(step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "own deck searches must declare full-deck scope"),
		assert_eq(int(step.get("visible_count", 0)), visible_cards.size(), "visible_count should include non-candidates"),
		assert_eq(int(step.get("selectable_count", 0)), legal_cards.size(), "selectable_count should only include candidates"),
	]


func _find_action(actions: Array[Dictionary], kind: String, card: CardInstance = null) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) != kind:
			continue
		if card != null and action.get("card", null) != card:
			continue
		return action
	return {}


func test_csv6c_118_ancient_booster_capsule_hp_and_status_boundaries() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var ancient := _slot(_pokemon("Ancient Holder", "Basic", 2, "", [CardData.ANCIENT_TAG]), 0)
	var normal := _slot(_pokemon("Normal Holder", "Basic", 2), 0)
	state.players[0].active_pokemon = ancient
	state.players[0].bench.append(normal)
	ancient.attached_tool = CardInstance.create(_trainer("Ancient Booster Energy Capsule", "Tool", ANCIENT_CAPSULE_ID), 0)
	normal.attached_tool = CardInstance.create(_trainer("Ancient Booster Energy Capsule", "Tool", ANCIENT_CAPSULE_ID), 0)
	ancient.set_status("burned", true)
	normal.set_status("burned", true)

	processor.execute_card_effect(ancient.attached_tool, [ancient], state)
	EffectApplyStatus.new("poisoned").execute_attack(null, ancient, 0, state)
	EffectApplyStatus.new("poisoned").execute_attack(null, normal, 0, state)
	var unsuppressed_hp_bonus := processor.get_hp_modifier(ancient, state)

	state.stadium_card = CardInstance.create(_trainer("Jamming Tower", "Stadium", "4e16157bfa88a41e823d058a732df8e0"), 0)
	EffectApplyStatus.new("asleep").execute_attack(null, ancient, 0, state)

	return run_checks([
		assert_not_null(processor.get_effect(ANCIENT_CAPSULE_ID), "Ancient Booster Energy Capsule should be registered"),
		assert_eq(unsuppressed_hp_bonus, 60, "Ancient holder should get +60 HP without tool suppression"),
		assert_eq(processor.get_hp_modifier(normal, state), 0, "Non-Ancient holder should not get HP"),
		assert_false(ancient.status_conditions.get("burned", false), "Ancient holder should clear existing Special Conditions"),
		assert_false(ancient.status_conditions.get("poisoned", false), "Ancient holder should prevent new Special Conditions"),
		assert_true(normal.status_conditions.get("burned", false), "Non-Ancient holder should keep existing status"),
		assert_true(normal.status_conditions.get("poisoned", false), "Non-Ancient holder should not be protected"),
		assert_eq(processor.get_hp_modifier(ancient, state), 0, "Jamming Tower should suppress Ancient Booster HP bonus"),
		assert_true(ancient.status_conditions.get("asleep", false), "Jamming Tower should suppress Ancient Booster status prevention"),
	])


func test_cs5ac_118_supereffective_glasses_weakness_x3_and_suppression() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var attacker := _slot(_attacker("Fighting Attacker", "F", "100"), 0)
	var defender_data := _pokemon("Weak Defender", "Basic", 1)
	defender_data.weakness_energy = "F"
	defender_data.weakness_value = "x2"
	player.active_pokemon = attacker
	opponent.active_pokemon = _slot(defender_data, 1)
	attacker.attached_tool = CardInstance.create(_trainer("Supereffective Glasses", "Tool", GLASSES_ID), 0)
	var boosted_damage := gsm.get_attack_preview_damage(0, 0)

	gsm.game_state.stadium_card = CardInstance.create(_trainer("Jamming Tower", "Stadium", "4e16157bfa88a41e823d058a732df8e0"), 0)
	var suppressed_damage := gsm.get_attack_preview_damage(0, 0)

	return run_checks([
		assert_not_null(gsm.effect_processor.get_effect(GLASSES_ID), "Supereffective Glasses should be registered"),
		assert_eq(boosted_damage, 300, "Weakness should be calculated as x3"),
		assert_eq(suppressed_damage, 200, "Tool suppression should restore normal x2 Weakness"),
	])


func test_csv8c_188_powerglass_attaches_basic_energy_at_own_turn_end() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var active := _slot(_pokemon("Active Holder"), 0)
	var discard_energy := _basic_energy("Discard Lightning", "L", 0)
	player.active_pokemon = active
	opponent.active_pokemon = _slot(_pokemon("Opponent Active"), 1)
	active.attached_tool = CardInstance.create(_trainer("Powerglass", "Tool", POWERGLASS_ID), 0)
	player.discard_pile.append(discard_energy)
	_prepare_safe_turn_end(gsm)

	gsm.end_turn(0)

	var checks: Array[String] = [
		assert_not_null(gsm.effect_processor.get_effect(POWERGLASS_ID), "Powerglass effect should be registered"),
		assert_true(discard_energy in active.attached_energy, "Powerglass should attach one Basic Energy from discard to the Active holder at own turn end"),
		assert_false(discard_energy in player.discard_pile, "Powerglass should remove the attached Energy from discard"),
		assert_not_null(active.attached_tool, "Powerglass should remain attached after resolving its end-turn effect"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_csv8c_188_powerglass_prompts_and_uses_selected_basic_energy_at_own_turn_end() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var active := _slot(_pokemon("Active Holder"), 0)
	var first_energy := _basic_energy("Discard Lightning", "L", 0)
	var selected_energy := _basic_energy("Discard Water", "W", 0)
	var special_energy := _basic_energy("Discard Special", "C", 0)
	special_energy.card_data.card_type = "Special Energy"
	player.active_pokemon = active
	opponent.active_pokemon = _slot(_pokemon("Opponent Active"), 1)
	active.attached_tool = CardInstance.create(_trainer("Powerglass", "Tool", POWERGLASS_ID), 0)
	player.discard_pile.append_array([first_energy, special_energy, selected_energy])
	_prepare_safe_turn_end(gsm)
	var prompts: Array[Dictionary] = []
	gsm.player_choice_required.connect(func(choice_type: String, data: Dictionary) -> void:
		prompts.append({"type": choice_type, "data": data.duplicate(true)})
	)

	gsm.end_turn(0)
	var prompt: Dictionary = prompts[0] if not prompts.is_empty() else {}
	var prompt_data: Dictionary = prompt.get("data", {})
	var steps: Array = prompt_data.get("steps", [])
	var first_step: Dictionary = steps[0] if not steps.is_empty() else {}
	var resolved: bool = gsm.resolve_powerglass_end_turn_choice(0, [{"powerglass_energy": [selected_energy]}])

	var checks: Array[String] = [
		assert_eq(str(prompt.get("type", "")), "powerglass_end_turn", "Powerglass should request an optional end-turn energy choice when a UI listener is present"),
		assert_eq(prompt_data.get("card", null), active.attached_tool, "Powerglass prompt should expose the attached Tool card"),
		assert_eq(prompt_data.get("slot", null), active, "Powerglass prompt should identify the Active holder"),
		assert_eq(str(first_step.get("id", "")), "powerglass_energy", "Powerglass choice step should have a stable id"),
		assert_eq(first_step.get("items", []), [first_energy, selected_energy], "Powerglass should expose only Basic Energy from discard in original order"),
		assert_eq(int(first_step.get("min_select", -1)), 0, "Powerglass is optional, so zero selections must be legal"),
		assert_eq(int(first_step.get("max_select", -1)), 1, "Powerglass may attach only one Basic Energy"),
		assert_true(bool(first_step.get("allow_cancel", false)), "Powerglass should expose a cancel button because the attachment is optional"),
		assert_true(bool(first_step.get("cancel_resolves_empty", false)), "Powerglass cancel should resolve as choosing no Energy"),
		assert_true(bool(first_step.get("force_confirm", false)), "Powerglass should require explicit confirm so the player can skip with zero selections"),
		assert_true(resolved, "Resolving the selected Powerglass energy should succeed"),
		assert_true(selected_energy in active.attached_energy, "Powerglass should attach the selected Basic Energy, not the first discard Basic Energy"),
		assert_true(first_energy in player.discard_pile, "Unselected Basic Energy should remain in discard"),
		assert_true(special_energy in player.discard_pile, "Special Energy should remain in discard and should not be selectable"),
		assert_false(selected_energy in player.discard_pile, "Selected Basic Energy should leave discard"),
		assert_eq(gsm.game_state.current_player_index, 1, "Resolving Powerglass should resume normal turn advancement"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_csv8c_188_powerglass_can_be_skipped_at_own_turn_end() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var active := _slot(_pokemon("Active Holder"), 0)
	var discard_energy := _basic_energy("Discard Lightning", "L", 0)
	player.active_pokemon = active
	opponent.active_pokemon = _slot(_pokemon("Opponent Active"), 1)
	active.attached_tool = CardInstance.create(_trainer("Powerglass", "Tool", POWERGLASS_ID), 0)
	player.discard_pile.append(discard_energy)
	_prepare_safe_turn_end(gsm)
	gsm.player_choice_required.connect(func(_choice_type: String, _data: Dictionary) -> void:
		pass
	)

	gsm.end_turn(0)
	var resolved: bool = gsm.resolve_powerglass_end_turn_choice(0, [{"powerglass_energy": []}])

	var checks: Array[String] = [
		assert_true(resolved, "Powerglass should allow resolving with no selected Energy"),
		assert_false(discard_energy in active.attached_energy, "Skipping Powerglass should not attach Energy"),
		assert_true(discard_energy in player.discard_pile, "Skipping Powerglass should leave discard untouched"),
		assert_eq(gsm.game_state.current_player_index, 1, "Skipping Powerglass should still resume normal turn advancement"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_csv8c_188_powerglass_prompts_again_on_later_own_turn() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var active := _slot(_pokemon("Active Holder"), 0)
	var first_energy := _basic_energy("First Discard Energy", "L", 0)
	var second_energy := _basic_energy("Second Discard Energy", "W", 0)
	player.active_pokemon = active
	opponent.active_pokemon = _slot(_pokemon("Opponent Active"), 1)
	active.attached_tool = CardInstance.create(_trainer("Powerglass", "Tool", POWERGLASS_ID), 0)
	player.discard_pile.append_array([first_energy, second_energy])
	player.set_prizes([_basic_energy("Player Prize", "C", 0)])
	opponent.set_prizes([_basic_energy("Opponent Prize", "C", 1)])
	player.deck.append_array([
		_basic_energy("Player Draw 1", "C", 0),
		_basic_energy("Player Draw 2", "C", 0),
	])
	opponent.deck.append_array([
		_basic_energy("Opponent Draw 1", "C", 1),
		_basic_energy("Opponent Draw 2", "C", 1),
	])
	var prompts: Array[Dictionary] = []
	gsm.player_choice_required.connect(func(choice_type: String, data: Dictionary) -> void:
		prompts.append({"type": choice_type, "data": data.duplicate(true)})
	)

	gsm.end_turn(0)
	var first_prompt_count := prompts.size()
	var first_resolved: bool = gsm.resolve_powerglass_end_turn_choice(0, [{"powerglass_energy": [first_energy]}])
	gsm.end_turn(1)
	prompts.clear()
	gsm.end_turn(0)
	var second_prompt_count := prompts.size()
	var second_resolved: bool = gsm.resolve_powerglass_end_turn_choice(0, [{"powerglass_energy": [second_energy]}])

	var checks: Array[String] = [
		assert_eq(first_prompt_count, 1, "Powerglass should prompt at the first own turn end"),
		assert_true(first_resolved, "The first Powerglass choice should resolve"),
		assert_true(first_energy in active.attached_energy, "The first selected Basic Energy should attach"),
		assert_eq(second_prompt_count, 1, "Powerglass should prompt again on a later own turn"),
		assert_true(second_resolved, "The later Powerglass choice should resolve"),
		assert_true(second_energy in active.attached_energy, "The later selected Basic Energy should attach"),
		assert_false(second_energy in player.discard_pile, "The later selected Basic Energy should leave discard"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_csv8c_188_powerglass_does_not_trigger_from_bench_or_opponents_turn() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var active := _slot(_pokemon("Active"), 0)
	var benched := _slot(_pokemon("Benched Holder"), 0)
	var discard_energy := _basic_energy("Discard Psychic", "P", 0)
	player.active_pokemon = active
	player.bench.append(benched)
	opponent.active_pokemon = _slot(_pokemon("Opponent Active"), 1)
	benched.attached_tool = CardInstance.create(_trainer("Powerglass", "Tool", POWERGLASS_ID), 0)
	player.discard_pile.append(discard_energy)
	_prepare_safe_turn_end(gsm)

	gsm.end_turn(0)
	var bench_turn_attached := discard_energy in benched.attached_energy

	gsm.game_state.current_player_index = 1
	gsm.game_state.phase = GameState.GamePhase.MAIN
	player.active_pokemon.attached_tool = CardInstance.create(_trainer("Powerglass", "Tool", POWERGLASS_ID), 0)
	gsm.end_turn(1)

	var checks: Array[String] = [
		assert_false(bench_turn_attached, "Powerglass should not trigger when attached Pokemon is on the Bench"),
		assert_false(discard_energy in player.active_pokemon.attached_energy, "Powerglass should not trigger on the opponent's turn"),
		assert_true(discard_energy in player.discard_pile, "Powerglass should leave discard untouched when its conditions are not met"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_csv3c_117_picnic_basket_heals_every_pokemon_on_both_sides() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = _slot(_pokemon("Own Active"), 0)
	player.active_pokemon.damage_counters = 50
	var own_bench_a := _slot(_pokemon("Own Bench A"), 0)
	own_bench_a.damage_counters = 20
	var own_bench_b := _slot(_pokemon("Own Bench B"), 0)
	own_bench_b.damage_counters = 0
	player.bench.append_array([own_bench_a, own_bench_b])
	opponent.active_pokemon = _slot(_pokemon("Opponent Active"), 1)
	opponent.active_pokemon.damage_counters = 80
	var opp_bench := _slot(_pokemon("Opponent Bench"), 1)
	opp_bench.damage_counters = 30
	opponent.bench.append(opp_bench)
	var picnic := CardInstance.create(_trainer("Picnic Basket", "Item", PICNIC_BASKET_ID), 0)
	var effect := gsm.effect_processor.get_effect(PICNIC_BASKET_ID)
	if effect == null:
		gsm.prepare_for_disposal()
		return run_checks([
			assert_not_null(effect, "Picnic Basket should be registered by effect_id"),
		])

	var executed := gsm.effect_processor.execute_card_effect(picnic, [], gsm.game_state)
	var checks: Array[String] = [
		assert_true(executed, "Picnic Basket should execute as a registered Item"),
		assert_eq(player.active_pokemon.damage_counters, 20, "Picnic Basket should heal own Active by 30"),
		assert_eq(own_bench_a.damage_counters, 0, "Picnic Basket should heal own Bench by 30 without going below zero"),
		assert_eq(own_bench_b.damage_counters, 0, "Picnic Basket should leave undamaged own Bench at zero"),
		assert_eq(opponent.active_pokemon.damage_counters, 50, "Picnic Basket should heal opponent Active by 30"),
		assert_eq(opp_bench.damage_counters, 0, "Picnic Basket should heal opponent Bench by 30"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_csv8c_188_powerglass_respects_jamming_tower_suppression() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var active := _slot(_pokemon("Active Holder"), 0)
	var discard_energy := _basic_energy("Discard Fighting", "F", 0)
	player.active_pokemon = active
	opponent.active_pokemon = _slot(_pokemon("Opponent Active"), 1)
	active.attached_tool = CardInstance.create(_trainer("Powerglass", "Tool", POWERGLASS_ID), 0)
	player.discard_pile.append(discard_energy)
	gsm.game_state.stadium_card = CardInstance.create(_trainer("Jamming Tower", "Stadium", "4e16157bfa88a41e823d058a732df8e0"), 0)
	_prepare_safe_turn_end(gsm)

	gsm.end_turn(0)

	var checks: Array[String] = [
		assert_false(discard_energy in active.attached_energy, "Jamming Tower should suppress Powerglass attachment"),
		assert_true(discard_energy in player.discard_pile, "Suppressed Powerglass should not remove Energy from discard"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_csv4c_118_defiance_vest_reduces_damage_when_owner_is_behind_on_prizes() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var attacker := _slot(_attacker("Attacker", "C", "100"), 0)
	var defender := _slot(_pokemon("Defiance Vest Holder"), 1)
	player.active_pokemon = attacker
	opponent.active_pokemon = defender
	defender.attached_tool = CardInstance.create(_trainer("Defiance Vest", "Tool", DEFIANCE_VEST_ID), 1)
	player.set_prizes([
		_basic_energy("Player Prize 1", "C", 0),
		_basic_energy("Player Prize 2", "C", 0),
		_basic_energy("Player Prize 3", "C", 0),
	])
	opponent.set_prizes([
		_basic_energy("Opponent Prize 1", "C", 1),
		_basic_energy("Opponent Prize 2", "C", 1),
		_basic_energy("Opponent Prize 3", "C", 1),
		_basic_energy("Opponent Prize 4", "C", 1),
		_basic_energy("Opponent Prize 5", "C", 1),
	])

	var reduced_damage := gsm.get_attack_preview_damage(0, 0)
	var active_modifier := gsm.effect_processor.get_defender_modifier(defender, state, attacker)
	state.stadium_card = CardInstance.create(_trainer("Jamming Tower", "Stadium", "4e16157bfa88a41e823d058a732df8e0"), 0)
	var suppressed_damage := gsm.get_attack_preview_damage(0, 0)
	state.stadium_card = null
	opponent.set_prizes([
		_basic_energy("Opponent Prize A", "C", 1),
		_basic_energy("Opponent Prize B", "C", 1),
	])
	var inactive_damage := gsm.get_attack_preview_damage(0, 0)

	var checks: Array[String] = [
		assert_not_null(gsm.effect_processor.get_effect(DEFIANCE_VEST_ID), "Defiance Vest effect should be registered"),
		assert_eq(active_modifier, -40, "Defiance Vest should reduce damage by 40 while its owner has more remaining Prize cards"),
		assert_eq(reduced_damage, 60, "Defiance Vest should reduce 100 damage to 60 when active"),
		assert_eq(suppressed_damage, 100, "Jamming Tower should suppress Defiance Vest damage reduction"),
		assert_eq(inactive_damage, 100, "Defiance Vest should not reduce damage when its owner does not have more remaining Prize cards"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_csv4c_118_defiance_vest_does_not_reduce_same_owner_attack_damage() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var same_owner_attacker := _slot(_attacker("Same Owner Attacker", "C", "100"), 1)
	var defender := _slot(_pokemon("Defiance Vest Holder"), 1)
	opponent.active_pokemon = defender
	opponent.bench.append(same_owner_attacker)
	defender.attached_tool = CardInstance.create(_trainer("Defiance Vest", "Tool", DEFIANCE_VEST_ID), 1)
	player.set_prizes([
		_basic_energy("Player Prize 1", "C", 0),
		_basic_energy("Player Prize 2", "C", 0),
	])
	opponent.set_prizes([
		_basic_energy("Opponent Prize 1", "C", 1),
		_basic_energy("Opponent Prize 2", "C", 1),
		_basic_energy("Opponent Prize 3", "C", 1),
		_basic_energy("Opponent Prize 4", "C", 1),
		_basic_energy("Opponent Prize 5", "C", 1),
	])

	var modifier := gsm.effect_processor.get_defender_modifier(defender, state, same_owner_attacker)
	var damage := gsm.damage_calculator.calculate_damage(
		same_owner_attacker,
		defender,
		same_owner_attacker.get_card_data().attacks[0],
		state,
		0,
		0,
		modifier
	)

	var checks: Array[String] = [
		assert_eq(modifier, 0, "Defiance Vest should only reduce damage from opponent Pokemon attacks"),
		assert_eq(damage, 100, "Defiance Vest should not reduce same-owner attack damage"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_csv95c_188_black_belts_training_boosts_only_opponent_active_ex_this_turn() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var attacker := _slot(_attacker("Training Attacker", "C", "100"), 0)
	var opponent_ex := _slot(_pokemon("Opponent ex", "Basic", 1, "ex"), 1)
	var opponent_v := _slot(_pokemon("Opponent V", "Basic", 1, "V"), 1)
	var opponent_bench_ex := _slot(_pokemon("Benched ex", "Basic", 1, "ex"), 1)
	var supporter := CardInstance.create(_trainer("Black Belt's Training", "Supporter", BLACK_BELT_TRAINING_ID), 0)
	player.active_pokemon = attacker
	opponent.active_pokemon = opponent_ex
	opponent.bench.append(opponent_bench_ex)

	gsm.effect_processor.execute_card_effect(supporter, [], state)
	var boosted_damage := gsm.get_attack_preview_damage(0, 0)
	var bench_bonus := gsm.effect_processor.get_attack_damage_modifier(
		attacker,
		opponent_bench_ex,
		attacker.get_card_data().attacks[0],
		state
	)

	opponent.active_pokemon = opponent_v
	var non_ex_damage := gsm.get_attack_preview_damage(0, 0)

	opponent.active_pokemon = opponent_ex
	state.turn_number += 1
	var next_turn_damage := gsm.get_attack_preview_damage(0, 0)

	var checks: Array[String] = [
		assert_not_null(gsm.effect_processor.get_effect(BLACK_BELT_TRAINING_ID), "Black Belt's Training effect should be registered"),
		assert_eq(boosted_damage, 140, "Black Belt's Training should add 40 damage against the opponent Active Pokemon ex"),
		assert_eq(non_ex_damage, 100, "Black Belt's Training should not boost damage against Pokemon V"),
		assert_eq(bench_bonus, 0, "Black Belt's Training should not boost damage to Benched Pokemon ex"),
		assert_eq(next_turn_damage, 100, "Black Belt's Training damage boost should expire after the current turn"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_csv95c_188_black_belts_training_play_trainer_entry_sets_turn_damage_bonus() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var attacker := _slot(_attacker("Training Attacker", "C", "100"), 0)
	var opponent_ex := _slot(_pokemon("Opponent ex", "Basic", 1, "ex"), 1)
	var supporter := CardInstance.create(_trainer("Black Belt's Training", "Supporter", BLACK_BELT_TRAINING_ID), 0)
	player.active_pokemon = attacker
	opponent.active_pokemon = opponent_ex
	player.hand.append(supporter)

	var actions := AILegalActionBuilder.new().build_actions(gsm, 0)
	var action := _find_action(actions, "play_trainer", supporter)
	var played := gsm.play_trainer(0, supporter, [])
	var boosted_damage := gsm.get_attack_preview_damage(0, 0)

	var checks: Array[String] = [
		assert_false(action.is_empty(), "AI legal action builder should expose Black Belt's Training as a legal Supporter"),
		assert_true(played, "GameStateMachine.play_trainer should play Black Belt's Training from hand"),
		assert_false(supporter in player.hand, "Black Belt's Training should leave hand after play_trainer"),
		assert_true(supporter in player.discard_pile, "Black Belt's Training should be discarded after resolving"),
		assert_true(state.supporter_used_this_turn, "Black Belt's Training should consume the Supporter for the turn"),
		assert_eq(boosted_damage, 140, "Black Belt's Training played through GameStateMachine should boost later attack damage"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_csv95c_188_black_belts_training_does_not_create_damage_for_non_damage_attack() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var attacker := _slot(_attacker("Status Attacker", "C", ""), 0)
	var opponent_ex := _slot(_pokemon("Opponent ex", "Basic", 1, "ex"), 1)
	var supporter := CardInstance.create(_trainer("Black Belt's Training", "Supporter", BLACK_BELT_TRAINING_ID), 0)
	player.active_pokemon = attacker
	opponent.active_pokemon = opponent_ex

	gsm.effect_processor.execute_card_effect(supporter, [], state)
	var preview_damage := gsm.get_attack_preview_damage(0, 0)
	var modifier := gsm.effect_processor.get_attack_damage_modifier(
		attacker,
		opponent_ex,
		attacker.get_card_data().attacks[0],
		state
	)

	var checks: Array[String] = [
		assert_eq(modifier, 0, "Black Belt's Training should not add damage to an attack that does not deal damage"),
		assert_eq(preview_damage, 0, "Black Belt's Training should not turn a non-damage attack into 40 damage"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_cs5ac_116_feather_ball_full_library_search_and_execution() -> String:
	var gsm := _make_gsm()
	gsm.effect_processor.register_effect(FEATHER_BALL_ID, EffectFeatherBallScript.new())
	var player: PlayerState = gsm.game_state.players[0]
	var free_a := CardInstance.create(_pokemon("Free Retreat A", "Basic", 0), 0)
	var paid := CardInstance.create(_pokemon("Paid Retreat", "Basic", 1), 0)
	var item := CardInstance.create(_trainer("Deck Item", "Item"), 0)
	var free_b := CardInstance.create(_pokemon("Free Retreat B", "Stage 1", 0), 0)
	player.deck.append_array([free_a, paid, item, free_b])
	var card := CardInstance.create(_trainer("Feather Ball", "Item", FEATHER_BALL_ID), 0)
	player.hand.append(card)
	var effect: BaseEffect = gsm.effect_processor.get_effect(FEATHER_BALL_ID)
	var steps := effect.get_interaction_steps(card, gsm.game_state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var visible_deck := player.deck.duplicate()

	var actions := AILegalActionBuilder.new().build_actions(gsm, 0)
	var action := _find_action(actions, "play_trainer", card)
	var played := gsm.play_trainer(0, card, [{"search_pokemon": [paid, free_b]}])

	var checks := _full_deck_step_checks(step, visible_deck, [free_a, free_b], [0, -1, -1, 1], "search_pokemon")
	checks.append(assert_eq(int(step.get("min_select", -1)), 0, "Feather Ball searches a hidden deck and must allow whiffing"))
	checks.append(assert_true(bool(step.get("force_confirm", false)), "Feather Ball should expose a confirm path for selecting no card"))
	checks.append(assert_false(action.is_empty(), "AI/headless should enumerate Feather Ball"))
	checks.append(assert_false(bool(action.get("requires_interaction", true)), "AI/headless should auto-resolve Feather Ball from legal candidates"))
	checks.append(assert_true(played, "Feather Ball should play through GameStateMachine"))
	checks.append(assert_true(free_b in player.hand, "Selected legal no-retreat Pokemon should move to hand"))
	checks.append(assert_false(paid in player.hand, "Pokemon with Retreat Cost must not move to hand"))
	checks.append(assert_true(paid in player.deck, "Invalid selected Pokemon must remain in deck"))
	return run_checks(checks)


func test_cs5ac_116_feather_ball_can_whiff_hidden_deck_search() -> String:
	var gsm := _make_gsm()
	gsm.effect_processor.register_effect(FEATHER_BALL_ID, EffectFeatherBallScript.new())
	var player: PlayerState = gsm.game_state.players[0]
	var free_target := CardInstance.create(_pokemon("Free Retreat", "Basic", 0), 0)
	var paid := CardInstance.create(_pokemon("Paid Retreat", "Basic", 1), 0)
	player.deck.append_array([free_target, paid])
	var card := CardInstance.create(_trainer("Feather Ball", "Item", FEATHER_BALL_ID), 0)
	player.hand.append(card)

	var played := gsm.play_trainer(0, card, [{"search_pokemon": []}])

	return run_checks([
		assert_true(played, "Feather Ball should be playable with an explicit whiff"),
		assert_false(free_target in player.hand, "Whiffing should not move a legal target to hand"),
		assert_true(free_target in player.deck, "Legal target should remain in deck after whiff"),
		assert_true(card in player.discard_pile, "Feather Ball should still be consumed after whiff"),
	])


func test_cs5dc_147_arezu_searches_non_rule_box_evolutions_only() -> String:
	var gsm := _make_gsm()
	gsm.effect_processor.register_effect(AREZU_ID, EffectArezuScript.new())
	var player: PlayerState = gsm.game_state.players[0]
	var stage_one := CardInstance.create(_pokemon("Stage One", "Stage 1", 1), 0)
	var basic := CardInstance.create(_pokemon("Basic Pokemon", "Basic", 1), 0)
	var stage_two_ex := CardInstance.create(_pokemon("Stage Two ex", "Stage 2", 2, "ex"), 0)
	var vmax := CardInstance.create(_pokemon("VMAX Pokemon", "VMAX", 3, "VMAX"), 0)
	var stage_two := CardInstance.create(_pokemon("Stage Two", "Stage 2", 2), 0)
	var stage_one_b := CardInstance.create(_pokemon("Stage One B", "Stage 1", 1), 0)
	var stage_two_b := CardInstance.create(_pokemon("Stage Two B", "Stage 2", 2), 0)
	player.deck.append_array([stage_one, basic, stage_two_ex, vmax, stage_two, stage_one_b, stage_two_b])
	var card := CardInstance.create(_trainer("Arezu", "Supporter", AREZU_ID), 0)
	player.hand.append(card)
	var effect: BaseEffect = gsm.effect_processor.get_effect(AREZU_ID)
	var steps := effect.get_interaction_steps(card, gsm.game_state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var visible_deck := player.deck.duplicate()

	var actions := AILegalActionBuilder.new().build_actions(gsm, 0)
	var action := _find_action(actions, "play_trainer", card)
	var played := gsm.play_trainer(0, card, [{"search_pokemon": [stage_two_ex, stage_one, vmax, stage_two, stage_one_b, stage_two_b]}])

	var checks := _full_deck_step_checks(step, visible_deck, [stage_one, stage_two, stage_one_b, stage_two_b], [0, -1, -1, -1, 1, 2, 3], "search_pokemon")
	checks.append(assert_eq(int(step.get("min_select", -1)), 0, "Arezu is an up-to-3 search and should allow selecting none"))
	checks.append(assert_eq(int(step.get("max_select", -1)), 3, "Arezu should cap selection at 3 even when more legal evolutions exist"))
	checks.append(assert_true(bool(step.get("force_confirm", false)), "Arezu should expose a confirm path for selecting no card"))
	checks.append(assert_false(action.is_empty(), "AI/headless should enumerate Arezu"))
	checks.append(assert_false(bool(action.get("requires_interaction", true)), "AI/headless should auto-resolve Arezu from legal candidates"))
	checks.append(assert_true(played, "Arezu should play through GameStateMachine"))
	checks.append(assert_true(stage_one in player.hand and stage_two in player.hand and stage_one_b in player.hand, "Selected legal evolutions should move to hand up to the cap"))
	checks.append(assert_false(stage_two_ex in player.hand, "Rule Box evolution Pokemon must not move to hand"))
	checks.append(assert_false(vmax in player.hand, "VMAX Rule Box Pokemon must not move to hand"))
	checks.append(assert_true(stage_two_ex in player.deck and vmax in player.deck, "Rule Box selections should remain in deck"))
	checks.append(assert_true(stage_two_b in player.deck, "Fourth legal evolution should remain in deck because Arezu selects at most 3"))
	return run_checks(checks)


func test_csv8c_205_academy_at_night_stadium_action_once_per_turn() -> String:
	var gsm := _make_gsm()
	gsm.effect_processor.register_effect(ACADEMY_ID, EffectAcademyAtNightScript.new())
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var stadium := CardInstance.create(_trainer("Academy at Night", "Stadium", ACADEMY_ID), 0)
	var keep := CardInstance.create(_trainer("Keep", "Item"), 0)
	var top_choice := CardInstance.create(_trainer("Top Choice", "Item"), 0)
	var invalid_opponent_card := CardInstance.create(_trainer("Opponent Card", "Item"), 1)
	var old_top := CardInstance.create(_trainer("Old Top", "Item"), 0)
	player.hand.append_array([keep, top_choice])
	player.deck.append(old_top)
	opponent.hand.append(invalid_opponent_card)
	gsm.game_state.stadium_card = stadium
	gsm.game_state.stadium_owner_index = 1
	var effect: BaseEffect = gsm.effect_processor.get_effect(ACADEMY_ID)
	var steps := effect.get_interaction_steps(stadium, gsm.game_state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	var actions := AILegalActionBuilder.new().build_actions(gsm, 0)
	var action := _find_action(actions, "use_stadium_effect", stadium)
	var first_use := gsm.use_stadium_effect(0, [{"academy_at_night_card": [invalid_opponent_card, top_choice]}])
	var second_use := gsm.use_stadium_effect(0, [{"academy_at_night_card": [keep]}])
	var opponent_kept_after_player_use := invalid_opponent_card in opponent.hand
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 3
	var opponent_use := gsm.use_stadium_effect(1, [{"academy_at_night_card": [invalid_opponent_card]}])

	return run_checks([
		assert_eq(str(step.get("id", "")), "academy_at_night_card", "Academy at Night should expose a hand-card choice"),
		assert_eq(step.get("items", []), [keep, top_choice], "Only current player's hand should be selectable"),
		assert_false(action.is_empty(), "AI/headless should enumerate Academy at Night stadium action"),
		assert_false(bool(action.get("requires_interaction", true)), "AI/headless should auto-resolve Academy at Night"),
		assert_true(first_use, "First stadium use this turn should succeed"),
		assert_false(second_use, "Same player should not reuse the same Stadium effect this turn"),
		assert_eq(player.deck[0], top_choice, "Selected hand card should be placed on top of deck"),
		assert_false(top_choice in player.hand, "Selected hand card should leave hand"),
		assert_true(opponent_kept_after_player_use, "Opponent hand card must not be selectable or moved by player 0"),
		assert_true(opponent_use, "Opponent should be able to use Academy at Night on their own turn"),
		assert_eq(opponent.deck[0], invalid_opponent_card, "Opponent's own hand card should go to the top of their deck"),
	])
