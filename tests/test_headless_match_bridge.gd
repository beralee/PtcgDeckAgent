class_name TestHeadlessMatchBridge
extends TestBase

const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AIStepResolverScript = preload("res://scripts/ai/AIStepResolver.gd")
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const AbilityMoveDamageCountersToOpponentScript = preload("res://scripts/effects/pokemon_effects/AbilityMoveDamageCountersToOpponent.gd")
const AbilityFirstTurnDrawScript = preload("res://scripts/effects/pokemon_effects/AbilityFirstTurnDraw.gd")
const AttackMoveOwnDamageCountersToOpponentScript = preload("res://scripts/effects/pokemon_effects/AttackMoveOwnDamageCountersToOpponent.gd")
const EffectGrandTreeScript = preload("res://scripts/effects/stadium_effects/CSV9C205GrandTree.gd")

const SCREAM_TAIL_EFFECT_ID := "12c9416c64d1a8cfbbf0a3000a9f3d50"
const CRESSELIA_HEADLESS_EFFECT_ID := "cresselia_headless_test"
const POWERGLASS_ID := "1dc38c46be0951b2b135e1df2e5e7767"


class SetupCompletionSpyGameStateMachine extends GameStateMachine:
	var setup_complete_calls: Array[int] = []

	func setup_complete(player_index: int) -> bool:
		setup_complete_calls.append(player_index)
		return true


class FakeSendOutStrategy extends RefCounted:
	var preferred_name: String = ""

	func _init(next_preferred_name: String = "") -> void:
		preferred_name = next_preferred_name

	func score_interaction_target(item: Variant, step: Dictionary, _context: Dictionary = {}) -> float:
		if str(step.get("id", "")) != "send_out" or not item is PokemonSlot:
			return 0.0
		return 500.0 if (item as PokemonSlot).get_pokemon_name() == preferred_name else 0.0


class FakeHandoffStrategy extends RefCounted:
	var step_id: String = ""
	var preferred_name: String = ""

	func _init(next_step_id: String = "", next_preferred_name: String = "") -> void:
		step_id = next_step_id
		preferred_name = next_preferred_name

	func score_handoff_target(item: Variant, step: Dictionary, _context: Dictionary = {}) -> float:
		if str(step.get("id", "")) != step_id or not item is PokemonSlot:
			return 0.0
		return 500.0 if (item as PokemonSlot).get_pokemon_name() == preferred_name else 0.0


class FakeBenchCleanupStrategy extends RefCounted:
	var preferred_name: String = ""

	func _init(next_preferred_name: String = "") -> void:
		preferred_name = next_preferred_name

	func pick_interaction_items(items: Array, step: Dictionary, _context: Dictionary = {}) -> Array:
		if not str(step.get("id", "")).contains("zero_area_discard"):
			return []
		for item: Variant in items:
			if item is PokemonSlot and (item as PokemonSlot).get_pokemon_name() == preferred_name:
				return [item]
		return []


class FakeInteractionTargetStrategy extends RefCounted:
	var step_id: String = ""
	var preferred_name: String = ""

	func _init(next_step_id: String = "", next_preferred_name: String = "") -> void:
		step_id = next_step_id
		preferred_name = next_preferred_name

	func score_interaction_target(item: Variant, step: Dictionary, _context: Dictionary = {}) -> float:
		if str(step.get("id", "")) != step_id or not item is PokemonSlot:
			return 0.0
		return 900.0 if (item as PokemonSlot).get_pokemon_name() == preferred_name else 10.0


class HeavyBatonResolveSpyGameStateMachine extends GameStateMachine:
	var resolve_heavy_baton_choice_calls: int = 0
	var resolved_heavy_baton_player_index: int = -1
	var resolved_heavy_baton_target: PokemonSlot = null

	func resolve_heavy_baton_choice(player_index: int, bench_slot: PokemonSlot) -> bool:
		resolve_heavy_baton_choice_calls += 1
		resolved_heavy_baton_player_index = player_index
		resolved_heavy_baton_target = bench_slot
		return true


class FakeSendOutInteractionScorer extends RefCounted:
	func score_delta(_state_features: Array, interaction_vector: Array) -> float:
		if interaction_vector.size() <= 25:
			return 0.0
		var attached_energy_hint: float = float(interaction_vector[25])
		return 260.0 if attached_energy_hint < 0.01 else 0.0


func _make_basic_card(name: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 60
	return CardInstance.create(card, 0)


func _make_evolution_card(name: String, stage: String, evolves_from: String, owner: int = 0) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.hp = 120
	return CardInstance.create(card, owner)


func _make_basic_card_with_ability(name: String, ability_name: String, effect_id: String, owner: int = 0) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 110
	card.energy_type = "P"
	card.effect_id = effect_id
	card.abilities = [{"name": ability_name, "text": ""}]
	return CardInstance.create(card, owner)


func _make_filler_card(name: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, 0)


func _make_tool_card(name: String, effect_id: String, owner: int = 0) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Tool"
	card.effect_id = effect_id
	return CardInstance.create(card, owner)


func _make_energy_card(name: String, provides: String, owner: int = 0, card_type: String = "Basic Energy") -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.energy_provides = provides
	return CardInstance.create(card, owner)


func _make_slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _make_scream_tail_card(owner: int = 0) -> CardInstance:
	var card := CardData.new()
	card.name = "吼叫尾"
	card.name_en = "Scream Tail"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 90
	card.energy_type = "P"
	card.effect_id = SCREAM_TAIL_EFFECT_ID
	card.attacks = [
		{"name": "巴掌", "cost": "P", "damage": "30", "is_vstar_power": false},
		{"name": "凶暴吼叫", "cost": "PC", "damage": "", "is_vstar_power": false},
	]
	return CardInstance.create(card, owner)


func _make_cresselia_card(owner: int = 0) -> CardInstance:
	var card := CardData.new()
	card.name = "Cresselia"
	card.name_en = "Cresselia"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 120
	card.energy_type = "P"
	card.effect_id = CRESSELIA_HEADLESS_EFFECT_ID
	card.attacks = [
		{"name": "Moonglow Reverse", "cost": "P", "damage": "", "is_vstar_power": false},
	]
	return CardInstance.create(card, owner)


func _make_gsm() -> GameStateMachine:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	return gsm


func test_bridge_script_exposes_bootstrap_pending_setup() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	return run_checks([
		assert_true(bridge.has_method("bootstrap_pending_setup"), "The extracted bridge script should expose bootstrap_pending_setup"),
	])


func test_bridge_declares_bridge_owned_prompt_handling_contract() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	return run_checks([
		assert_true(bridge.has_method("handles_bridge_owned_prompts"), "The extracted bridge script should expose the bridge-owned prompt contract"),
		assert_true(bridge.handles_bridge_owned_prompts(), "The extracted bridge should opt into bridge-owned prompt handling"),
	])


func test_bridge_declares_effect_interaction_execution_supported() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	return run_checks([
		assert_true(bridge.has_method("supports_effect_interaction_execution"), "The extracted bridge should expose the effect-interaction execution capability contract"),
		assert_true(bridge.supports_effect_interaction_execution(), "HeadlessMatchBridge should support effect interaction execution"),
	])


func test_bridge_injects_ability_followup_counter_distribution_steps() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	var effect := AbilityMoveDamageCountersToOpponentScript.new(3)
	gsm.effect_processor.register_effect("munkidori_headless_followup_test", effect)

	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var munkidori := _make_slot(_make_basic_card_with_ability("Munkidori", "Adrena-Brain", "munkidori_headless_followup_test", 0))
	munkidori.attached_energy.append(_make_energy_card("Darkness Energy", "D", 0))
	var source := _make_slot(_make_basic_card("Drifloon"))
	source.damage_counters = 30
	player.active_pokemon = munkidori
	player.bench = [source]
	var opponent_active_data := CardData.new()
	opponent_active_data.name = "Iron Hands ex"
	opponent_active_data.card_type = "Pokemon"
	opponent_active_data.stage = "Basic"
	opponent_active_data.hp = 230
	opponent.active_pokemon = _make_slot(CardInstance.create(opponent_active_data, 1))
	opponent.bench.clear()
	bridge.bind(gsm)

	var steps := effect.get_interaction_steps(munkidori.get_top_card(), gsm.game_state)
	bridge._start_effect_interaction("ability", 0, steps, munkidori.get_top_card(), munkidori, 0)
	bridge._handle_effect_interaction_choice(PackedInt32Array([0]))
	var injected_step_ids: Array[String] = []
	for step: Dictionary in bridge.get("_pending_effect_steps"):
		injected_step_ids.append(str(step.get("id", "")))
	bridge._on_counter_distribution_amount_chosen(3)
	bridge._handle_counter_distribution_target(0)

	return run_checks([
		assert_true(injected_step_ids.has("target_damage_counters"), "Headless ability interaction should inject Munkidori's damage-counter follow-up step"),
		assert_eq(source.damage_counters, 0, "Headless follow-up should remove selected counters from the damaged own Pokemon"),
		assert_eq(opponent.active_pokemon.damage_counters, 30, "Headless follow-up should place selected counters onto the opponent target"),
		assert_eq(str(bridge.get("_pending_choice")), "", "Resolved follow-up should clear the effect interaction prompt"),
	])


func test_bridge_resolves_scream_tail_attack_target_and_damage() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var resolver := AIStepResolverScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var scream_tail := _make_slot(_make_scream_tail_card(0))
	scream_tail.damage_counters = 60
	scream_tail.attached_energy = [
		_make_energy_card("Psychic Energy", "P", 0),
		_make_energy_card("Psychic Energy", "P", 0),
	]
	player.active_pokemon = scream_tail
	gsm.effect_processor.register_pokemon_card(scream_tail.get_card_data())
	var target_data := CardData.new()
	target_data.name = "Miraidon ex"
	target_data.card_type = "Pokemon"
	target_data.stage = "Basic"
	target_data.hp = 220
	opponent.active_pokemon = _make_slot(CardInstance.create(target_data, 1))
	bridge.bind(gsm)

	var started := bridge._try_use_attack_with_interaction(0, scream_tail, 1)
	var resolved := resolver.resolve_pending_step(bridge, gsm, 0)

	return run_checks([
		assert_true(started, "Headless bridge should start Scream Tail's target_pokemon attack interaction"),
		assert_true(resolved, "AIStepResolver should resolve Scream Tail's attack target prompt"),
		assert_eq(opponent.active_pokemon.damage_counters, 120, "Resolved Roaring Scream should deal self-damage-counter based damage to the selected target"),
		assert_eq(str(bridge.get("_pending_choice")), "", "Resolved Scream Tail attack should clear the effect interaction prompt"),
	])


func test_bridge_resolves_cresselia_attack_target_and_moves_damage() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var resolver := AIStepResolverScript.new()
	resolver.set_deck_strategy(FakeInteractionTargetStrategy.new("cresselia_damage_target", "Prize Target"))
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.effect_processor.replace_attack_effects(
		CRESSELIA_HEADLESS_EFFECT_ID,
		[AttackMoveOwnDamageCountersToOpponentScript.new(20, 0)]
	)
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var cresselia := _make_slot(_make_cresselia_card(0))
	cresselia.damage_counters = 20
	cresselia.attached_energy = [_make_energy_card("Psychic Energy", "P", 0)]
	var damaged_bench := _make_slot(_make_basic_card("Damaged Ralts"))
	damaged_bench.damage_counters = 20
	player.active_pokemon = cresselia
	player.bench = [damaged_bench]
	var bulky_active := _make_slot(_make_basic_card("Bulky Active"))
	bulky_active.pokemon_stack[0].card_data.hp = 220
	opponent.active_pokemon = bulky_active
	var prize_target := _make_slot(_make_basic_card("Prize Target"))
	prize_target.pokemon_stack[0].card_data.hp = 60
	prize_target.damage_counters = 20
	opponent.bench = [prize_target]
	bridge.bind(gsm)

	var started := bridge._try_use_attack_with_interaction(0, cresselia, 0)
	var source_step: Dictionary = (bridge.get("_pending_effect_steps") as Array)[0] if not (bridge.get("_pending_effect_steps") as Array).is_empty() else {}
	var resolved_source := resolver.resolve_pending_step(bridge, gsm, 0)
	var target_step: Dictionary = (bridge.get("_pending_effect_steps") as Array)[int(bridge.get("_pending_effect_step_index"))] if int(bridge.get("_pending_effect_step_index")) >= 0 and int(bridge.get("_pending_effect_step_index")) < (bridge.get("_pending_effect_steps") as Array).size() else {}
	var resolved_target := resolver.resolve_pending_step(bridge, gsm, 0)

	return run_checks([
		assert_true(started, "Headless bridge should start Cresselia's own damage-counter source prompt"),
		assert_eq(str(source_step.get("id", "")), "cresselia_damage_sources", "Cresselia should resolve own sources before choosing the opponent target"),
		assert_true(resolved_source, "AIStepResolver should resolve Cresselia's cresselia_damage_sources prompt"),
		assert_eq(str(target_step.get("id", "")), "cresselia_damage_target", "Cresselia should inject the opponent target prompt after source selection"),
		assert_true(resolved_target, "AIStepResolver should resolve Cresselia's cresselia_damage_target prompt"),
		assert_eq(cresselia.damage_counters, 0, "Cresselia should move up to 20 damage counters from itself"),
		assert_eq(damaged_bench.damage_counters, 0, "Cresselia should move up to 20 damage counters from each own Pokemon"),
		assert_eq(prize_target.damage_counters, 60, "Resolved Moonglow Reverse should move the full damage pool to the strategy-selected target"),
		assert_eq(bulky_active.damage_counters, 0, "Cresselia should not fall back to the opponent active when strategy prefers a bench prize target"),
		assert_eq(str(bridge.get("_pending_choice")), "", "Resolved Cresselia attack should clear the effect interaction prompt"),
	])


func test_bridge_resolves_powerglass_end_turn_energy_choice() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var resolver := AIStepResolverScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var active := _make_slot(_make_basic_card("Powerglass Holder"))
	active.attached_tool = _make_tool_card("Powerglass", POWERGLASS_ID, 0)
	var lightning := _make_energy_card("Lightning Energy", "L", 0)
	var water := _make_energy_card("Water Energy", "W", 0)
	player.active_pokemon = active
	player.discard_pile.append_array([lightning, water])
	player.set_prizes([_make_energy_card("Player Prize", "C", 0)])
	player.deck.append(_make_energy_card("Player Draw", "C", 0))
	opponent.active_pokemon = _make_slot(CardInstance.create((_make_basic_card("Opponent Active")).card_data, 1))
	opponent.set_prizes([_make_energy_card("Opponent Prize", "C", 1)])
	opponent.deck.append(_make_energy_card("Opponent Draw", "C", 1))
	bridge.bind(gsm)

	gsm.end_turn(0)
	var pending_after_end := str(bridge.get_pending_prompt_type())
	var steps: Array = bridge.get("_pending_effect_steps")
	var first_step: Dictionary = steps[0] if not steps.is_empty() else {}
	var resolved := resolver.resolve_pending_step(bridge, gsm, 0, [])

	return run_checks([
		assert_eq(pending_after_end, "effect_interaction", "Headless Powerglass should enter the shared effect_interaction prompt"),
		assert_eq(str(first_step.get("id", "")), "powerglass_energy", "Headless Powerglass should expose the energy choice step"),
		assert_true(resolved, "AIStepResolver should resolve Powerglass's optional end-turn choice"),
		assert_true(lightning in active.attached_energy, "Headless resolver should attach one legal Basic Energy from discard"),
		assert_true(water in player.discard_pile, "Headless resolver should leave unselected Basic Energy in discard"),
		assert_eq(gsm.game_state.current_player_index, 1, "Resolved headless Powerglass should resume normal turn advancement"),
		assert_eq(str(bridge.get_pending_prompt_type()), "", "Resolved Powerglass prompt should clear pending choice"),
	])


func test_bridge_finalizes_munkidori_partial_counter_distribution_after_one_assignment() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	var effect := AbilityMoveDamageCountersToOpponentScript.new(3)
	gsm.effect_processor.register_effect("munkidori_partial_followup_test", effect)

	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var munkidori := _make_slot(_make_basic_card_with_ability("Munkidori", "Adrena-Brain", "munkidori_partial_followup_test", 0))
	munkidori.attached_energy.append(_make_energy_card("Darkness Energy", "D", 0))
	var source := _make_slot(_make_basic_card("Drifloon"))
	source.damage_counters = 30
	player.active_pokemon = munkidori
	player.bench = [source]
	opponent.active_pokemon = _make_slot(_make_basic_card("Damaged Target"))
	opponent.bench.clear()
	bridge.bind(gsm)

	var steps := effect.get_interaction_steps(munkidori.get_top_card(), gsm.game_state)
	bridge._start_effect_interaction("ability", 0, steps, munkidori.get_top_card(), munkidori, 0)
	bridge._handle_effect_interaction_choice(PackedInt32Array([0]))
	bridge._on_counter_distribution_amount_chosen(1)
	bridge._handle_counter_distribution_target(0)

	return run_checks([
		assert_eq(source.damage_counters, 20, "Munkidori should allow moving only one damage counter from the source"),
		assert_eq(opponent.active_pokemon.damage_counters, 10, "The partial counter assignment should still resolve onto the opponent target"),
		assert_eq(str(bridge.get("_pending_choice")), "", "A partial one-target Munkidori assignment should complete the prompt instead of leaving AI stuck"),
	])


func test_step_resolver_executes_headless_ability_followup_counter_distribution() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var resolver := AIStepResolverScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	var effect := AbilityMoveDamageCountersToOpponentScript.new(3)
	gsm.effect_processor.register_effect("munkidori_step_resolver_followup_test", effect)

	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var munkidori := _make_slot(_make_basic_card_with_ability("Munkidori", "Adrena-Brain", "munkidori_step_resolver_followup_test", 0))
	munkidori.attached_energy.append(_make_energy_card("Darkness Energy", "D", 0))
	var source := _make_slot(_make_basic_card("Drifloon"))
	source.damage_counters = 30
	player.active_pokemon = munkidori
	player.bench = [source]
	var opponent_active_data := CardData.new()
	opponent_active_data.name = "Iron Hands ex"
	opponent_active_data.card_type = "Pokemon"
	opponent_active_data.stage = "Basic"
	opponent_active_data.hp = 230
	opponent.active_pokemon = _make_slot(CardInstance.create(opponent_active_data, 1))
	opponent.bench.clear()
	bridge.bind(gsm)

	var steps := effect.get_interaction_steps(munkidori.get_top_card(), gsm.game_state)
	bridge._start_effect_interaction("ability", 0, steps, munkidori.get_top_card(), munkidori, 0)
	var resolved_source := resolver.resolve_pending_step(bridge, gsm, 0, [])
	var pending_after_source := str(bridge.get("_pending_choice"))
	var mode_after_source := str(bridge.get("_field_interaction_mode"))
	var resolved_target := resolver.resolve_pending_step(bridge, gsm, 0, [])

	return run_checks([
		assert_true(resolved_source, "AIStepResolver should resolve Munkidori's source selection"),
		assert_eq(pending_after_source, "effect_interaction", "Source selection should leave the injected target step pending"),
		assert_eq(mode_after_source, "counter_distribution", "Injected follow-up should become a counter-distribution prompt"),
		assert_true(resolved_target, "AIStepResolver should resolve Munkidori's counter-distribution target"),
		assert_eq(source.damage_counters, 0, "Resolver follow-up should remove counters from the selected source"),
		assert_eq(opponent.active_pokemon.damage_counters, 30, "Resolver follow-up should place counters onto the selected opponent target"),
		assert_eq(str(bridge.get("_pending_choice")), "", "Resolver follow-up should complete the ability interaction"),
	])


func test_step_resolver_executes_headless_grand_tree_stage2_followup() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var resolver := AIStepResolverScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 3
	var player: PlayerState = gsm.game_state.players[0]
	var active := _make_slot(_make_basic_card("Seed"))
	active.turn_played = 0
	player.active_pokemon = active
	var stage1 := _make_evolution_card("Tree Stage1", "Stage 1", "Seed", 0)
	var stage2 := _make_evolution_card("Tree Stage2", "Stage 2", "Tree Stage1", 0)
	player.deck = [stage1, stage2]
	var stadium_data := CardData.new()
	stadium_data.name = "Great Tree"
	stadium_data.card_type = "Stadium"
	stadium_data.effect_id = "grand_tree_headless_test"
	var stadium := CardInstance.create(stadium_data, 0)
	gsm.game_state.stadium_card = stadium
	gsm.game_state.stadium_owner_index = 0
	gsm.effect_processor.register_effect("grand_tree_headless_test", EffectGrandTreeScript.new())
	bridge.bind(gsm)

	var started := bridge._try_use_stadium_with_interaction(0)
	var stage1_step: Dictionary = (bridge.get("_pending_effect_steps") as Array)[0] if not (bridge.get("_pending_effect_steps") as Array).is_empty() else {}
	var resolved_stage1 := resolver.resolve_pending_step(bridge, gsm, 0, [])
	var pending_after_stage1 := str(bridge.get("_pending_choice"))
	var mode_after_stage1 := str(bridge.get("_field_interaction_mode"))
	var step_index_after_stage1 := int(bridge.get("_pending_effect_step_index"))
	var pending_steps: Array = bridge.get("_pending_effect_steps")
	var stage2_step: Dictionary = pending_steps[step_index_after_stage1] if step_index_after_stage1 >= 0 and step_index_after_stage1 < pending_steps.size() else {}
	var resolved_stage2 := resolver.resolve_pending_step(bridge, gsm, 0, [])

	return run_checks([
		assert_true(started, "Headless bridge should start Grand Tree's Stadium interaction"),
		assert_eq(str(stage1_step.get("id", "")), EffectGrandTreeScript.STAGE1_STEP_ID, "Grand Tree should first ask for a Stage 1 evolution assignment"),
		assert_true(resolved_stage1, "AIStepResolver should resolve Grand Tree's Stage 1 assignment"),
		assert_eq(pending_after_stage1, "effect_interaction", "Stage 1 assignment should leave the optional Stage 2 follow-up pending"),
		assert_eq(mode_after_stage1, "assignment", "Grand Tree's follow-up should remain a field assignment prompt"),
		assert_eq(str(stage2_step.get("id", "")), EffectGrandTreeScript.STAGE2_STEP_ID, "Grand Tree should inject the Stage 2 follow-up step"),
		assert_true(resolved_stage2, "AIStepResolver should resolve Grand Tree's optional Stage 2 assignment"),
		assert_eq(active.pokemon_stack.size(), 3, "Headless Grand Tree should evolve through Stage 1 and Stage 2"),
		assert_eq(active.get_pokemon_name(), "Tree Stage2", "The selected Stage 2 should be the final top Pokemon"),
		assert_false(stage2 in player.deck, "The selected Stage 2 should leave the deck during Stadium resolution"),
		assert_eq(str(bridge.get("_pending_choice")), "", "Resolved Grand Tree follow-up should clear the effect interaction prompt"),
	])


func test_counter_distribution_resolver_respects_munkidori_single_target_limit() -> String:
	var resolver := AIStepResolverScript.new()
	var pressure_target := _make_slot(_make_basic_card("Pressure Target"))
	pressure_target.pokemon_stack[0].card_data.hp = 200
	var prize_target := _make_slot(_make_basic_card("Prize Target"))
	prize_target.pokemon_stack[0].card_data.hp = 100
	prize_target.damage_counters = 90
	var targets: Array = [pressure_target, prize_target]
	var assignments: Array = resolver._build_counter_distribution_assignments(
		targets,
		3,
		{
			"id": "target_damage_counters",
			"ui_mode": "counter_distribution",
			"max_assignments": 1,
			"allow_partial": true,
		},
		{},
		[]
	)
	var first_assignment: Dictionary = assignments[0] if not assignments.is_empty() else {}

	return run_checks([
		assert_eq(assignments.size(), 1, "Munkidori counter planning must choose exactly one opponent target"),
		assert_eq(first_assignment.get("target"), prize_target, "The single target should be the available prize target, not a leftover-pressure target"),
		assert_eq(int(first_assignment.get("amount", 0)), 10, "With partial movement allowed, Munkidori should move only the counters needed for the one-target KO"),
	])


func test_legal_action_builder_keeps_followup_ability_runtime_interactive() -> String:
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	var effect := AbilityMoveDamageCountersToOpponentScript.new(3)
	gsm.effect_processor.register_effect("munkidori_builder_followup_test", effect)

	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var munkidori := _make_slot(_make_basic_card_with_ability("Munkidori", "Adrena-Brain", "munkidori_builder_followup_test", 0))
	munkidori.attached_energy.append(_make_energy_card("Darkness Energy", "D", 0))
	var source := _make_slot(_make_basic_card("Drifloon"))
	source.damage_counters = 30
	player.active_pokemon = munkidori
	player.bench = [source]
	var opponent_active_data := CardData.new()
	opponent_active_data.name = "Iron Hands ex"
	opponent_active_data.card_type = "Pokemon"
	opponent_active_data.stage = "Basic"
	opponent_active_data.hp = 230
	opponent.active_pokemon = _make_slot(CardInstance.create(opponent_active_data, 1))
	opponent.bench.clear()

	var builder := AILegalActionBuilderScript.new()
	var actions: Array[Dictionary] = builder.build_actions(gsm, 0, false)
	var ability_action: Dictionary = {}
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == "use_ability" and action.get("source_slot") == munkidori:
			ability_action = action
			break
	return run_checks([
		assert_false(ability_action.is_empty(), "Munkidori ability should be legal when it has Dark Energy and a damaged own source"),
		assert_true(bool(ability_action.get("requires_interaction", false)), "Follow-up abilities must remain bridge-interactive instead of being pre-resolved without target placement"),
		assert_true((ability_action.get("targets", []) as Array).is_empty(), "Builder should not pre-resolve partial Munkidori targets without the follow-up counter placement"),
	])


func test_bridge_accepts_modern_battle_scene_success_hook_signature() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	bridge._refresh_ui_after_successful_action(false, 1)
	return assert_true(true,
		"HeadlessMatchBridge should accept the BattleScene success hook signature with action_player_index")


func test_bridge_accepts_modern_battle_scene_end_turn_signature() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	bridge.bind(gsm)
	bridge._on_end_turn(1)
	return assert_true(true,
		"HeadlessMatchBridge should accept the BattleScene end-turn signature with action_player_index")


func test_bootstrap_pending_setup_recovers_mulligan_prompt_from_action_log() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.action_log.append(GameAction.create(GameAction.ActionType.MULLIGAN, 0, {}, 0, "Seeded missed mulligan prompt"))
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()
	return run_checks([
		assert_eq(str(bridge.get("_pending_choice")), "mulligan_extra_draw", "bootstrap_pending_setup should recover the missed mulligan prompt"),
		assert_eq(bridge.get_pending_prompt_owner(), 1, "bootstrap_pending_setup should recover the mulligan beneficiary from the missed action log"),
	])


func test_bootstrap_pending_setup_resumes_from_missing_active_player() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.players[0].active_pokemon = _make_slot(_make_basic_card("P0 Active"))
	gsm.game_state.players[0].hand = [_make_basic_card("P0 Basic")]
	gsm.game_state.players[1].hand = [_make_basic_card("P1 Basic")]
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()
	return run_checks([
		assert_eq(str(bridge.get("_pending_choice")), "setup_active_1", "bootstrap_pending_setup should resume from the player missing an active Pokemon"),
		assert_eq(bridge.get_pending_prompt_owner(), 1, "The resumed setup prompt should belong to the missing-active player"),
	])


func test_get_pending_prompt_owner_uses_dialog_player_for_setup_active() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.set("_pending_choice", "setup_active_1")
	bridge.set("_dialog_data", {"player": 1})
	return run_checks([
		assert_eq(bridge.get_pending_prompt_owner(), 1, "setup_active ownership should come from _dialog_data.player"),
	])


func test_get_pending_prompt_owner_prefers_effect_interaction_dialog_chooser_fields() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.set("_pending_choice", "effect_interaction")
	bridge.set("_dialog_data", {
		"chooser_player_index": 1,
		"player": 0,
		"opponent_chooses": true,
	})
	var chooser_owner := bridge.get_pending_prompt_owner()
	bridge.set("_dialog_data", {
		"player": 0,
		"opponent_chooses": true,
	})
	var opponent_choice_owner := bridge.get_pending_prompt_owner()
	return run_checks([
		assert_eq(chooser_owner, 1, "effect_interaction ownership should prefer chooser_player_index when present"),
		assert_eq(opponent_choice_owner, 1, "effect_interaction ownership should derive the chooser from opponent_chooses when no explicit chooser is present"),
	])


func test_headless_match_bridge_marks_unsupported_prompt_as_no_progress() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	bridge._on_player_choice_required("unsupported_prompt", {"reason": "unsupported"})
	return run_checks([
		assert_eq(str(bridge.get("_pending_choice")), "unsupported_prompt", "Unsupported prompts should be preserved by the bridge"),
		assert_eq(bridge.get("_dialog_data"), {"reason": "unsupported"}, "Unsupported prompts should keep their dialog payload"),
		assert_false(bridge.can_resolve_pending_prompt(), "Unsupported prompts should not be claimed as resolvable"),
	])


func test_bridge_resolves_mulligan_extra_draw_prompt() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.players[0].hand = [_make_basic_card("P0 Basic")]
	gsm.game_state.players[0].deck = [_make_filler_card("P0 Deck")]
	gsm.game_state.players[1].hand = [_make_basic_card("P1 Basic")]
	gsm.game_state.players[1].deck = [_make_filler_card("P1 Deck")]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "mulligan_extra_draw")
	bridge.set("_dialog_data", {"beneficiary": 1, "mulligan_count": 1})

	var handled := bridge.resolve_pending_prompt()
	return run_checks([
		assert_true(handled, "The bridge should resolve mulligan_extra_draw itself"),
		assert_eq(gsm.game_state.players[1].hand.size(), 2, "The mulligan beneficiary should draw the extra card"),
		assert_eq(str(bridge.get("_pending_choice")), "setup_active_0", "Resolving mulligan should hand off to the setup flow"),
	])


func test_bridge_resolves_setup_active_prompt() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	var lead := _make_basic_card("Lead Basic")
	var bench := _make_basic_card("Bench Basic")
	gsm.game_state.players[1].hand = [lead, bench]
	gsm.game_state.players[1].deck = [_make_filler_card("P1 Deck 1"), _make_filler_card("P1 Deck 2")]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "setup_active_1")
	bridge.set("_dialog_data", {
		"player": 1,
		"basics": [lead, bench],
	})

	var handled := bridge.resolve_pending_prompt()
	return run_checks([
		assert_true(handled, "The bridge should resolve setup_active prompts"),
		assert_not_null(gsm.game_state.players[1].active_pokemon, "setup_active should place an active Pokemon"),
		assert_eq(gsm.game_state.players[1].active_pokemon.get_pokemon_name(), "Lead Basic", "setup_active should choose the first available Basic"),
		assert_eq(str(bridge.get("_pending_choice")), "setup_bench_1", "setup_active should continue into the bench setup prompt"),
	])


func test_bridge_resolves_setup_bench_prompt() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := SetupCompletionSpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	gsm.game_state.players[0].active_pokemon = _make_slot(_make_basic_card("P0 Active"))
	gsm.game_state.players[1].active_pokemon = _make_slot(_make_basic_card("P1 Active"))
	var bench_card := _make_basic_card("P1 Bench")
	gsm.game_state.players[1].hand = [bench_card]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "setup_bench_1")
	bridge.set("_dialog_data", {
		"player": 1,
		"cards": [bench_card],
	})

	var handled := bridge.resolve_pending_prompt()
	return run_checks([
		assert_true(handled, "The bridge should resolve setup_bench prompts"),
		assert_eq(gsm.game_state.players[1].bench.size(), 1, "setup_bench should place the planned Basic onto the bench"),
		assert_eq(gsm.setup_complete_calls.size(), 1, "setup_bench should hand off to setup completion"),
		assert_eq(gsm.setup_complete_calls[0], 0, "setup_bench should finish setup through setup_complete"),
		assert_eq(str(bridge.get("_pending_choice")), "", "setup_bench should clear the pending prompt after completion"),
	])


func test_bridge_resolves_take_prize_prompt() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	var prize_card := _make_filler_card("Prize Card")
	gsm.game_state.players[1].set_prizes([prize_card])
	gsm.set("_pending_prize_player_index", 1)
	gsm.set("_pending_prize_remaining", 1)
	bridge.bind(gsm)
	bridge.set("_pending_choice", "take_prize")
	bridge.set("_dialog_data", {"player": 1})

	var handled := bridge.resolve_pending_prompt()
	return run_checks([
		assert_true(handled, "The bridge should resolve take_prize prompts"),
		assert_eq(gsm.game_state.players[1].prizes.size(), 0, "take_prize should remove the prize card"),
		assert_true(prize_card in gsm.game_state.players[1].hand, "take_prize should move the prize into hand"),
		assert_eq(str(bridge.get("_pending_choice")), "", "take_prize should clear the pending prompt"),
	])


func test_bridge_exposes_send_out_prompt_to_ai_owner() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	var replacement := _make_slot(_make_basic_card("Replacement Basic"))
	gsm.game_state.players[1].bench = [replacement]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "send_out")
	bridge.set("_dialog_data", {"player": 1})
	return run_checks([
		assert_false(bridge.can_resolve_pending_prompt(), "send_out should be delegated to the owning AI instead of auto-resolved by the bridge"),
		assert_eq(bridge.get_pending_prompt_owner(), 1, "send_out ownership should still be exposed to the benchmark loop"),
		assert_eq(str(bridge.get("_pending_choice")), "send_out", "The bridge should preserve the send_out prompt until the AI handles it"),
	])


func test_bridge_does_not_auto_resolve_send_out_even_if_called_directly() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	var replacement := _make_slot(_make_basic_card("Replacement Basic"))
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.players[1].bench = [replacement]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "send_out")
	bridge.set("_dialog_data", {"player": 1})

	var handled := bridge.resolve_pending_prompt()
	return run_checks([
		assert_false(handled, "send_out should never be auto-resolved by the bridge"),
		assert_eq(gsm.game_state.players[1].active_pokemon, null, "Direct bridge resolution should not move a replacement to the active slot"),
		assert_eq(str(bridge.get("_pending_choice")), "send_out", "Failed direct resolution should restore the pending send_out prompt"),
	])


func test_ai_resolves_send_out_through_headless_bridge_with_deck_strategy() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 0
	var energy_bench := _make_slot(_make_basic_card("Energy Bench"))
	energy_bench.attached_energy.append(_make_energy_card("Lightning Energy", "L"))
	var preferred_bench := _make_slot(_make_basic_card("Preferred Bench"))
	gsm.game_state.players[1].bench = [energy_bench, preferred_bench]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "send_out")
	bridge.set("_dialog_data", {"player": 1})
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	ai.set_deck_strategy(FakeSendOutStrategy.new("Preferred Bench"))

	var handled := ai.run_single_step(bridge, gsm)
	return run_checks([
		assert_true(handled, "The owning AI should resolve send_out through the headless bridge"),
		assert_eq(gsm.game_state.players[1].active_pokemon, preferred_bench, "Headless send_out should now respect deck-local handoff scoring"),
		assert_eq(str(bridge.get("_pending_choice")), "", "The prompt should clear after AI-owned headless send_out resolution"),
	])


func test_bench_limit_cleanup_uses_bound_ai_strategy() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var discard_me := _make_slot(_make_basic_card("Discard Me"))
	var keep_a := _make_slot(_make_basic_card("Keep A"))
	var keep_b := _make_slot(_make_basic_card("Keep B"))
	var keep_c := _make_slot(_make_basic_card("Keep C"))
	var keep_d := _make_slot(_make_basic_card("Keep D"))
	var fallback_last := _make_slot(_make_basic_card("Fallback Last"))
	gsm.game_state.players[1].bench = [discard_me, keep_a, keep_b, keep_c, keep_d, fallback_last]
	bridge.bind(gsm)
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	ai.set_deck_strategy(FakeBenchCleanupStrategy.new("Discard Me"))
	bridge.set_ai_controllers(null, ai)

	bridge.call("_on_player_choice_required", "bench_limit_cleanup", {
		"player": 1,
		"steps": [{
			"id": "csv9c207_zero_area_discard_p1",
			"items": gsm.game_state.players[1].bench.duplicate(),
			"min_select": 1,
			"max_select": 1,
			"chooser_player_index": 1,
		}],
	})

	return run_checks([
		assert_false(discard_me in gsm.game_state.players[1].bench, "Headless bench cleanup should discard the strategy-selected slot"),
		assert_true(fallback_last in gsm.game_state.players[1].bench, "Strategy cleanup should override the old last-slot fallback"),
		assert_eq(gsm.game_state.players[1].bench.size(), 5, "Bench cleanup should trim to the default limit"),
	])


func test_ai_resolves_send_out_through_headless_bridge_with_learned_overlay() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 0
	var energy_bench := _make_slot(_make_basic_card("Energy Bench"))
	energy_bench.attached_energy.append(_make_energy_card("Lightning Energy", "L"))
	var plain_bench := _make_slot(_make_basic_card("Plain Bench"))
	gsm.game_state.players[1].bench = [energy_bench, plain_bench]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "send_out")
	bridge.set("_dialog_data", {"player": 1})
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	ai.set("_interaction_scorer", FakeSendOutInteractionScorer.new())

	var handled := ai.run_single_step(bridge, gsm)
	return run_checks([
		assert_true(handled, "The owning AI should resolve send_out through the headless bridge when an interaction scorer is injected"),
		assert_eq(gsm.game_state.players[1].active_pokemon, plain_bench, "Headless send_out should also allow the learned interaction overlay to override the generic fallback"),
		assert_eq(str(bridge.get("_pending_choice")), "", "The prompt should clear after learned headless send_out resolution"),
	])


func test_ai_resolves_heavy_baton_through_headless_bridge_with_deck_strategy() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := HeavyBatonResolveSpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	var energy_bench := _make_slot(_make_basic_card("Energy Baton Bench"))
	energy_bench.attached_energy.append(_make_energy_card("Lightning Energy", "L"))
	var preferred_bench := _make_slot(_make_basic_card("Preferred Baton Bench"))
	gsm.game_state.players[1].bench = [energy_bench, preferred_bench]
	bridge.bind(gsm)
	bridge.set("_pending_choice", "heavy_baton_target")
	bridge.set("_dialog_data", {"player": 1, "bench": [energy_bench, preferred_bench], "count": 3, "source_name": "Heavy Baton"})
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	ai.set_deck_strategy(FakeHandoffStrategy.new("heavy_baton_target", "Preferred Baton Bench"))

	var handled := ai.run_single_step(bridge, gsm)
	return run_checks([
		assert_true(handled, "The owning AI should resolve heavy_baton_target through the headless bridge"),
		assert_eq(gsm.resolve_heavy_baton_choice_calls, 1, "Headless bridge should route Heavy Baton resolution through GameStateMachine"),
		assert_eq(gsm.resolved_heavy_baton_player_index, 1, "Heavy Baton resolution should preserve the prompt owner"),
		assert_eq(gsm.resolved_heavy_baton_target, preferred_bench, "Headless Heavy Baton should respect deck-local handoff scoring"),
		assert_eq(str(bridge.get("_pending_choice")), "", "The prompt should clear after AI-owned headless Heavy Baton resolution"),
	])


func test_bridge_starts_granted_attack_effect_interaction_for_tm_turbo_energize() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	var attacker := _make_slot(_make_basic_card("Iron Thorns ex"))
	attacker.attached_energy.append(_make_energy_card("Lightning Energy", "L"))
	attacker.attached_tool = _make_tool_card("Technical Machine: Turbo Energize", "2614722b9b28d9df8fd769b926ec82f2")
	var bench_target := _make_slot(_make_basic_card("Bench Future"))
	var defender := _make_slot(_make_basic_card("Defender"))
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[0].bench = [bench_target]
	gsm.game_state.players[0].deck = [
		_make_energy_card("Lightning Energy", "L"),
		_make_energy_card("Fighting Energy", "F"),
	]
	gsm.game_state.players[1].active_pokemon = defender
	bridge.bind(gsm)
	var granted_attacks: Array[Dictionary] = gsm.effect_processor.get_granted_attacks(attacker, gsm.game_state)
	var handled := false
	if not granted_attacks.is_empty():
		handled = bridge._try_use_granted_attack_with_interaction(0, attacker, granted_attacks[0])
	return run_checks([
		assert_eq(granted_attacks.size(), 1, "TM Turbo Energize should grant exactly one attack"),
		assert_true(handled, "Headless bridge should start granted-attack interaction when TM Turbo Energize needs assignments"),
		assert_eq(str(bridge.get("_pending_choice")), "effect_interaction", "Granted attack interaction should enter effect_interaction mode"),
		assert_eq(bridge.get_pending_prompt_owner(), 0, "Granted attack interaction should belong to the acting player"),
	])


func test_bridge_starts_bench_entry_effect_interaction_for_iron_leaves_ex() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	var active := _make_slot(_make_basic_card("Active Arceus"))
	active.attached_energy.append(_make_energy_card("Grass Energy", "G"))
	gsm.game_state.players[0].active_pokemon = active

	var iron_cd := CardData.new()
	iron_cd.name = "Iron Leaves ex"
	iron_cd.card_type = "Pokemon"
	iron_cd.stage = "Basic"
	iron_cd.hp = 220
	iron_cd.mechanic = "ex"
	iron_cd.effect_id = "2e307380eb013c4e20db0a19816ba3b9"
	iron_cd.abilities = [{"name": "快速游标", "text": ""}]
	var iron_card := CardInstance.create(iron_cd, 0)
	gsm.game_state.players[0].hand = [iron_card]

	bridge.bind(gsm)
	var handled := bridge._try_play_to_bench(0, iron_card, "")
	return run_checks([
		assert_true(handled, "Headless bridge should accept playing Iron Leaves ex to the Bench"),
		assert_eq(str(bridge.get("_pending_choice")), "effect_interaction", "Bench-entry on-play abilities should enter effect_interaction in headless mode"),
		assert_eq(bridge.get_pending_prompt_owner(), 0, "The bench-entry interaction should belong to the acting player"),
	])


func test_bridge_does_not_auto_use_first_turn_draw_when_played_to_bench() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	var gsm := _make_gsm()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 1
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.players[0].active_pokemon = _make_slot(_make_basic_card("Active"))

	var squawk_cd := CardData.new()
	squawk_cd.name = "Squawkabilly ex"
	squawk_cd.name_en = "Squawkabilly ex"
	squawk_cd.card_type = "Pokemon"
	squawk_cd.stage = "Basic"
	squawk_cd.hp = 160
	squawk_cd.energy_type = "C"
	squawk_cd.mechanic = "ex"
	squawk_cd.effect_id = "headless_squawk_first_turn_draw"
	squawk_cd.abilities = [{"name": "Squawk and Seize", "text": ""}]
	gsm.effect_processor.register_effect(squawk_cd.effect_id, AbilityFirstTurnDrawScript.new(6))
	var squawk := CardInstance.create(squawk_cd, 0)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand = [squawk, _make_filler_card("Keep A"), _make_filler_card("Keep B")]
	for i: int in 6:
		player.deck.append(_make_filler_card("Draw %d" % i))

	bridge.bind(gsm)
	var handled := bridge._try_play_to_bench(0, squawk, "")
	var bench_slot: PokemonSlot = player.bench[0] if not player.bench.is_empty() else null

	return run_checks([
		assert_true(handled, "Headless bridge should allow Squawkabilly ex to enter the Bench"),
		assert_eq(str(bridge.get("_pending_choice")), "", "Activated first-turn draw should not create a bench-entry interaction prompt"),
		assert_eq(player.hand.size(), 2, "Headless bench placement should not discard and redraw the remaining hand"),
		assert_eq(player.discard_pile.size(), 0, "Headless bench placement should not discard the current hand"),
		assert_eq(player.deck.size(), 6, "Headless bench placement should not draw cards"),
		assert_true(gsm.effect_processor.can_use_ability(bench_slot, gsm.game_state, 0), "The Ability should remain available for an explicit use_ability action"),
		assert_false(bench_slot.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == AbilityFirstTurnDrawScript.USED_KEY), "The Ability should not be marked used by headless bench placement"),
	])
