extends TestBase

const RIGID_BAND_EFFECT_ID := "6ec876cf4467166edf6e90fa1cc321eb"
const EffectRigidBandScript = preload("res://scripts/effects/tool_effects/EffectRigidBand.gd")


func test_csv2c_114_rigid_band_reduces_damage_to_stage1_holder() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var attacker := _make_slot(_pokemon("Attacker", "Basic", 0), 0)
	var defender := _make_slot(_pokemon("Stage 1 Defender", "Stage 1", 1), 1)
	defender.attached_tool = _tool(1)
	state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon = defender

	var modifier := processor.get_defender_modifier(defender, state, attacker)
	var damage := DamageCalculator.new().calculate_damage(
		attacker,
		defender,
		{"name": "Strike", "cost": "C", "damage": "100", "text": "", "is_vstar_power": false},
		state,
		0,
		0,
		modifier
	)

	return run_checks([
		assert_eq(processor.get_effect(RIGID_BAND_EFFECT_ID).get_script(), EffectRigidBandScript, "Rigid Band effect id should register to EffectRigidBand"),
		assert_eq(modifier, -30, "Rigid Band should reduce damage to the attached Stage 1 Pokemon by 30"),
		assert_eq(damage, 70, "A 100-damage attack should deal 70 after Rigid Band"),
	])


func test_csv2c_114_rigid_band_ignores_non_stage1_holders() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var attacker := _make_slot(_pokemon("Attacker", "Basic", 0), 0)
	var basic_defender := _make_slot(_pokemon("Basic Defender", "Basic", 1), 1)
	var stage2_defender := _make_slot(_pokemon("Stage 2 Defender", "Stage 2", 1), 1)
	basic_defender.attached_tool = _tool(1)
	stage2_defender.attached_tool = _tool(1)

	var basic_modifier := processor.get_defender_modifier(basic_defender, state, attacker)
	var stage2_modifier := processor.get_defender_modifier(stage2_defender, state, attacker)

	return run_checks([
		assert_eq(basic_modifier, 0, "Rigid Band should not reduce damage for Basic Pokemon"),
		assert_eq(stage2_modifier, 0, "Rigid Band should not reduce damage for Stage 2 Pokemon"),
	])


func test_csv2c_114_rigid_band_requires_opponent_attack_source() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var defender := _make_slot(_pokemon("Stage 1 Defender", "Stage 1", 1), 1)
	var same_owner_attacker := _make_slot(_pokemon("Same Owner Source", "Basic", 1), 1)
	defender.attached_tool = _tool(1)

	return run_checks([
		assert_eq(processor.get_defender_modifier(defender, state, same_owner_attacker), 0, "Rigid Band should only apply to opponent Pokemon attacks"),
	])


func test_csv2c_114_rigid_band_respects_tool_suppression() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var attacker := _make_slot(_pokemon("Attacker", "Basic", 0), 0)
	var defender := _make_slot(_pokemon("Stage 1 Defender", "Stage 1", 1), 1)
	defender.attached_tool = _tool(1)
	state.players[1].active_pokemon = defender
	state.stadium_card = _stadium_with_tool_suppression(0)
	state.stadium_owner_index = 0

	return run_checks([
		assert_true(processor.is_tool_effect_suppressed(defender, state), "Test stadium should suppress attached Tool effects"),
		assert_eq(processor.get_defender_modifier(defender, state, attacker), 0, "Rigid Band should be disabled by Tool suppression"),
	])


func _make_state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 2
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_pokemon("Active%d" % pi, "Basic", pi), pi)
		state.players.append(player)
	return state


func _pokemon(name: String, stage: String, owner_index: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 160
	card.energy_type = "C"
	card.retreat_cost = 1
	card.attacks = [{"name": "Strike", "cost": "C", "damage": "100", "text": "", "is_vstar_power": false}]
	return card


func _make_slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot


func _tool(owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name = "坚硬束带"
	card.name_en = "Rigid Band"
	card.card_type = "Tool"
	card.effect_id = RIGID_BAND_EFFECT_ID
	return CardInstance.create(card, owner_index)


func _stadium_with_tool_suppression(owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name = "Ancient Tool Suppression"
	card.card_type = "Stadium"
	card.effect_id = "4e16157bfa88a41e823d058a732df8e0"
	return CardInstance.create(card, owner_index)
