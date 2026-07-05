class_name TestCSV95C081IronValiantEx
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const AbilityTachyonBitsScript := preload("res://scripts/effects/pokemon_effects/AbilityTachyonBits.gd")
const AttackSelfAllAttacksLockNextTurnScript := preload("res://scripts/effects/pokemon_effects/AttackSelfAllAttacksLockNextTurn.gd")

const EFFECT_ID := "b417ad06ad8e4aa783b35fe1f3f27010"


func test_csv95c_081_registers_tachyon_bits_and_laser_blade_by_effect_id() -> String:
	CardImplementationStatus.clear_cache()
	var card := _iron_valiant()
	if card == null:
		return assert_not_null(card, "CSV9.5C_081 should load from the bundled card pool")
	var processor := EffectProcessor.new()
	var slot := _make_slot(card, 0)

	processor.register_pokemon_card(card)
	var ability_effect := processor.get_effect(EFFECT_ID)
	var attack_effects := processor.get_attack_effects_for_slot(slot, 0)
	var ability_is_tachyon := ability_effect != null and is_instance_of(ability_effect, AbilityTachyonBitsScript)
	var attack_is_lock := not attack_effects.is_empty() and is_instance_of(attack_effects[0], AttackSelfAllAttacksLockNextTurnScript)

	return run_checks([
		assert_eq(str(card.name_en), "Iron Valiant ex", "CSV9.5C_081 should keep source English name"),
		assert_true(card.is_future_pokemon(), "CSV9.5C_081 should keep the Future tag from the API label"),
		assert_eq(card.abilities.size(), 1, "CSV9.5C_081 should import Tachyon Bits"),
		assert_eq(card.attacks.size(), 1, "CSV9.5C_081 should import Laser Blade"),
		assert_true(ability_is_tachyon, "CSV9.5C_081 should register Tachyon Bits by API effect_id"),
		assert_true(processor.has_attack_effect(EFFECT_ID), "CSV9.5C_081 should register Laser Blade by API effect_id"),
		assert_eq(attack_effects.size(), 1, "Laser Blade should have one self-lock effect"),
		assert_true(attack_is_lock, "Laser Blade should use the whole-Pokemon next-turn attack lock"),
		assert_false(CardImplementationStatus.is_unimplemented(card), "CSV9.5C_081 should not be marked unimplemented after registration"),
	])


func test_csv95c_081_tachyon_bits_uses_switch_entry_marker_and_targets_opponent_pokemon() -> String:
	var card := _iron_valiant()
	if card == null:
		return assert_not_null(card, "CSV9.5C_081 should load from the bundled card pool")
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var pivot := _make_slot(_pokemon("Pivot", "C", 100), 0)
	var iron_valiant := _make_slot(card, 0)
	var opponent_active := _make_slot(_pokemon("Opponent Active", "C", 300), 1)
	var opponent_bench := _make_slot(_pokemon("Opponent Bench", "C", 100), 1)
	player.active_pokemon = pivot
	player.bench.append(iron_valiant)
	opponent.active_pokemon = opponent_active
	opponent.bench.append(opponent_bench)
	var switch_cart := CardInstance.create(_trainer("Switch Cart", "Item", "8342fe3eeec6f897f3271be1aa26a412"), 0)
	player.hand.append(switch_cart)
	gsm.effect_processor.register_pokemon_card(card)
	var effect := gsm.effect_processor.get_effect(EFFECT_ID)
	var blocked_while_benched := gsm.effect_processor.can_use_ability(iron_valiant, gsm.game_state, 0)

	var switched := gsm.play_trainer(0, switch_cart, [{"switch_target": [iron_valiant]}])
	var can_use_after_switch := gsm.effect_processor.can_use_ability(iron_valiant, gsm.game_state, 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(iron_valiant.get_top_card(), gsm.game_state) if effect != null else []
	var step_items: Array = steps[0].get("items", []) if not steps.is_empty() else []
	var min_select := int(steps[0].get("min_select", 0)) if not steps.is_empty() else 0
	var max_select := int(steps[0].get("max_select", 0)) if not steps.is_empty() else 0
	var used := gsm.use_ability(0, iron_valiant, 0, [{"tachyon_bits_target": [opponent_bench]}])
	var repeat_allowed := gsm.effect_processor.can_use_ability(iron_valiant, gsm.game_state, 0)

	return run_checks([
		assert_false(blocked_while_benched, "Tachyon Bits should require Iron Valiant ex to be in the Active Spot"),
		assert_true(switched, "Switch Cart should move CSV9.5C_081 from Bench to Active"),
		assert_true(can_use_after_switch, "Tachyon Bits should be usable after moving from Bench to Active during its owner's turn"),
		assert_eq(steps.size(), 1, "Tachyon Bits should expose one target-selection interaction"),
		assert_eq(min_select, 1, "Tachyon Bits should require one target"),
		assert_eq(max_select, 1, "Tachyon Bits should select at most one target"),
		assert_true(opponent_active in step_items, "Tachyon Bits should allow targeting the opponent Active Pokemon"),
		assert_true(opponent_bench in step_items, "Tachyon Bits should allow targeting an opponent Benched Pokemon"),
		assert_true(used, "Tachyon Bits should resolve through GameStateMachine.use_ability"),
		assert_eq(opponent_active.damage_counters, 0, "Tachyon Bits should not damage the unselected opponent Active Pokemon"),
		assert_eq(opponent_bench.damage_counters, 20, "Tachyon Bits should place 2 damage counters on the selected opponent Pokemon"),
		assert_false(repeat_allowed, "Tachyon Bits should be once during the turn"),
	])


func test_csv95c_081_laser_blade_deals_200_and_locks_next_own_turn_attack() -> String:
	var card := _iron_valiant()
	if card == null:
		return assert_not_null(card, "CSV9.5C_081 should load from the bundled card pool")
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var attacker := _make_slot(card, 0)
	var defender := _make_slot(_pokemon("Defender", "C", 300), 1)
	player.active_pokemon = attacker
	opponent.active_pokemon = defender
	_attach_energy(attacker, 0, "P", 2)
	_attach_energy(attacker, 0, "C", 1)
	gsm.effect_processor.register_pokemon_card(card)

	var used := gsm.use_attack(0, 0)
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var locked_next_own_turn := not gsm.can_use_attack(0, 0)
	var lock_type := str(attacker.effects[0].get("type", "")) if not attacker.effects.is_empty() else ""

	return run_checks([
		assert_true(used, "Laser Blade should be usable with PPC attached"),
		assert_eq(defender.damage_counters, 200, "Laser Blade should deal its printed 200 damage"),
		assert_eq(attacker.effects.size(), 1, "Laser Blade should add one attack-lock marker"),
		assert_eq(lock_type, "attack_lock_all", "Laser Blade should record a whole-Pokemon attack lock marker"),
		assert_true(locked_next_own_turn, "Laser Blade should block the attack on the next own turn"),
	])


func _iron_valiant() -> CardData:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card("CSV9.5C", "081")
	db.free()
	return card


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	return state


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _pokemon(name: String, energy_type: String = "C", hp: int = 100) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.attacks = [{"name": "Tackle", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	return cd


func _trainer(name: String, card_type: String, effect_id: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	cd.description = name
	return cd


func _energy(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int = 1) -> void:
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index))
