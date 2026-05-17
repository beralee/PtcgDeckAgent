class_name TestScoopUpCyclone
extends TestBase

const SCOOP_UP_CYCLONE_EFFECT_ID := "c1acc32f6333793f261c9c132435fdfa"


func _make_pokemon_data(
	name: String,
	energy_type: String = "M",
	hp: int = 120,
	stage: String = "Basic",
	mechanic: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.mechanic = mechanic
	cd.attacks = [{"name": "Test", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	return cd


func _make_trainer_data(name: String, card_type: String = "Item", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _make_energy_data(name: String, energy_type: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_provides = energy_type
	cd.energy_type = energy_type
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


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
		player.active_pokemon = _make_slot(_make_pokemon_data("Active%d" % pi), pi)
		player.bench.append(_make_slot(_make_pokemon_data("Bench%d_A" % pi), pi))
		player.bench.append(_make_slot(_make_pokemon_data("Bench%d_B" % pi), pi))
		state.players.append(player)

	return state


func test_csv8c_181_scoop_up_cyclone_is_registered() -> String:
	var processor := EffectProcessor.new()

	return assert_true(
		processor.has_effect(SCOOP_UP_CYCLONE_EFFECT_ID),
		"CSV8C_181 Scoop Up Cyclone should be registered as an Item effect"
	)


func test_csv8c_181_scoop_up_cyclone_returns_benched_pokemon_stack_and_attachments_to_hand() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.discard_pile.clear()

	var base := CardInstance.create(_make_pokemon_data("Duraludon", "M", 130, "Basic"), 0)
	var stage1 := CardInstance.create(_make_pokemon_data("Archaludon", "M", 300, "Stage 1", "ex"), 0)
	var target := PokemonSlot.new()
	target.pokemon_stack.append(base)
	target.pokemon_stack.append(stage1)
	target.damage_counters = 60
	target.status_conditions["poisoned"] = true
	target.effects.append({"type": "temporary", "turn": state.turn_number})
	var metal := CardInstance.create(_make_energy_data("Metal Energy", "M"), 0)
	var tool := CardInstance.create(_make_trainer_data("Bravery Charm", "Tool"), 0)
	target.attached_energy.append(metal)
	target.attached_tool = tool
	player.bench.clear()
	player.bench.append(target)

	var card_data := _make_trainer_data("Scoop Up Cyclone", "Item", SCOOP_UP_CYCLONE_EFFECT_ID)
	card_data.is_tags = PackedStringArray(["ACE SPEC"])
	var item := CardInstance.create(card_data, 0)
	player.hand.append(item)

	var effect: BaseEffect = gsm.effect_processor.get_effect(SCOOP_UP_CYCLONE_EFFECT_ID)
	var steps := effect.get_interaction_steps(item, state) if effect != null else []
	var success := gsm.play_trainer(0, item, [{
		"scoop_up_cyclone_target": [target],
	}])

	return run_checks([
		assert_not_null(effect, "CSV8C_181 effect should be present in EffectProcessor"),
		assert_eq(steps.size(), 2, "CSV8C_181 should ask for target and replacement when the Active is also selectable"),
		assert_true(success, "CSV8C_181 should resolve through GameStateMachine"),
		assert_false(target in player.bench, "CSV8C_181 should remove the selected Benched Pokemon from play"),
		assert_contains(player.hand, base, "CSV8C_181 should return the lower Pokemon card to hand"),
		assert_contains(player.hand, stage1, "CSV8C_181 should return the top Pokemon card to hand"),
		assert_contains(player.hand, metal, "CSV8C_181 should return attached Energy to hand"),
		assert_contains(player.hand, tool, "CSV8C_181 should return attached Tool to hand"),
		assert_eq(target.pokemon_stack.size(), 0, "CSV8C_181 should clear the returned slot's Pokemon stack"),
		assert_eq(target.attached_energy.size(), 0, "CSV8C_181 should clear the returned slot's attached Energy"),
		assert_eq(target.attached_tool, null, "CSV8C_181 should clear the returned slot's attached Tool"),
		assert_eq(target.damage_counters, 0, "CSV8C_181 should clear damage from the removed slot"),
		assert_false(target.status_conditions.get("poisoned", false), "CSV8C_181 should clear special status from the removed slot"),
		assert_eq(target.effects.size(), 0, "CSV8C_181 should clear transient slot effects"),
		assert_contains(player.discard_pile, item, "CSV8C_181 should discard the Item after resolution"),
	])


func test_csv8c_181_scoop_up_cyclone_returns_active_with_chosen_replacement() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.discard_pile.clear()

	var active := _make_slot(_make_pokemon_data("Dialga VSTAR", "M", 280, "VSTAR", "VSTAR"), 0)
	var energy := CardInstance.create(_make_energy_data("Metal Energy", "M"), 0)
	active.attached_energy.append(energy)
	player.active_pokemon = active
	player.bench.clear()
	var replacement_a := _make_slot(_make_pokemon_data("Duraludon", "M", 130), 0)
	var replacement_b := _make_slot(_make_pokemon_data("Archaludon ex", "M", 300, "Stage 1", "ex"), 0)
	player.bench.append(replacement_a)
	player.bench.append(replacement_b)

	var card_data := _make_trainer_data("Scoop Up Cyclone", "Item", SCOOP_UP_CYCLONE_EFFECT_ID)
	card_data.is_tags = PackedStringArray(["ACE SPEC"])
	var item := CardInstance.create(card_data, 0)
	player.hand.append(item)
	var active_card := active.get_top_card()

	var success := gsm.play_trainer(0, item, [{
		"scoop_up_cyclone_target": [active],
		"scoop_up_cyclone_replacement": [replacement_b],
	}])

	return run_checks([
		assert_true(success, "CSV8C_181 should resolve when returning the Active with a replacement selected"),
		assert_eq(player.active_pokemon, replacement_b, "CSV8C_181 should promote the chosen replacement"),
		assert_false(replacement_b in player.bench, "CSV8C_181 should remove the chosen replacement from Bench"),
		assert_true(replacement_a in player.bench, "CSV8C_181 should leave unchosen Bench Pokemon on Bench"),
		assert_contains(player.hand, active_card, "CSV8C_181 should return the Active Pokemon card to hand"),
		assert_contains(player.hand, energy, "CSV8C_181 should return Active attached Energy to hand"),
		assert_contains(player.discard_pile, item, "CSV8C_181 should discard itself after returning the Active"),
	])


func test_csv8c_181_scoop_up_cyclone_cannot_return_lone_active() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.clear()
	var card_data := _make_trainer_data("Scoop Up Cyclone", "Item", SCOOP_UP_CYCLONE_EFFECT_ID)
	var item := CardInstance.create(card_data, 0)
	var processor := EffectProcessor.new()
	var effect: BaseEffect = processor.get_effect(SCOOP_UP_CYCLONE_EFFECT_ID)
	var steps := effect.get_interaction_steps(item, state) if effect != null else []

	return run_checks([
		assert_not_null(effect, "CSV8C_181 effect should be registered"),
		assert_false(effect.can_execute(item, state), "CSV8C_181 should be unusable when the lone Active has no replacement"),
		assert_eq(steps.size(), 0, "CSV8C_181 should not expose target choices with only a lone Active"),
	])
