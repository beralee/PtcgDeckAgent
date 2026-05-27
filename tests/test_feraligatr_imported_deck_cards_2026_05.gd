class_name TestFeraligatrImportedDeckCards202605
extends TestBase

const AbilityTorrentHeartScript = preload("res://scripts/effects/pokemon_effects/AbilityTorrentHeart.gd")
const AbilityPreEvolutionAttacksScript = preload("res://scripts/effects/pokemon_effects/AbilityPreEvolutionAttacks.gd")
const AttackDefenderRetreatLockNextTurnScript = preload("res://scripts/effects/pokemon_effects/AttackDefenderRetreatLockNextTurn.gd")
const AttackSwitchSelfToBenchScript = preload("res://scripts/effects/pokemon_effects/AttackSwitchSelfToBench.gd")

const EFFECT_TOTODILE := "f70ca79aa9a395b44c6ab39dda0062d3"
const EFFECT_CROCONAW := "d0d0f124636acb646f26f6b06c203d80"
const EFFECT_FERALIGATR := "db55f545bfa9fdddaf526a23431e7434"
const EFFECT_RELICANTH := "d348652e6296773db8b777e20e79fa4c"


func test_csv7c_052_053_054_118_imported_deck_effect_ids_register() -> String:
	var processor := EffectProcessor.new()
	var totodile := _make_totodile()
	var croconaw := _make_croconaw()
	var feraligatr := _make_feraligatr()
	var relicanth := _make_relicanth()
	processor.register_pokemon_card(totodile)
	processor.register_pokemon_card(croconaw)
	processor.register_pokemon_card(feraligatr)
	processor.register_pokemon_card(relicanth)

	var totodile_slot := _make_slot(totodile, 0)
	var croconaw_slot := _make_slot(croconaw, 0)
	return run_checks([
		assert_true(processor.get_attack_effects_for_slot(totodile_slot, 0)[0] is AttackDefenderRetreatLockNextTurnScript, "CSV7C_052 should register Gnawing retreat lock by effect_id"),
		assert_true(processor.get_attack_effects_for_slot(croconaw_slot, 0)[0] is AttackSwitchSelfToBenchScript, "CSV7C_053 should register Reverse Thrust switch by effect_id"),
		assert_true(processor.get_effect(EFFECT_FERALIGATR) is AbilityTorrentHeartScript, "CSV7C_054 should register Torrent Heart by effect_id"),
		assert_true(processor.has_attack_effect(EFFECT_FERALIGATR), "CSV7C_054 should register Giant Wave self lock by effect_id"),
		assert_true(processor.get_effect(EFFECT_RELICANTH) is AbilityPreEvolutionAttacksScript, "CSV7C_118 should register Memory Dive by effect_id"),
	])


func test_csv7c_052_totodile_gnawing_locks_defender_retreat_next_turn() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var totodile := _make_totodile()
	processor.register_pokemon_card(totodile)
	state.players[0].active_pokemon = _make_slot(totodile, 0)
	state.players[1].active_pokemon = _make_slot(_make_basic("Target", "C", 130), 1)
	state.players[1].active_pokemon.attached_energy.append(CardInstance.create(_make_energy("Colorless", "C"), 1))
	state.players[1].bench = [_make_slot(_make_basic("Backup", "C", 80), 1)]

	processor.execute_attack_effect(state.players[0].active_pokemon, 0, state.players[1].active_pokemon, state)
	state.turn_number = 3
	state.current_player_index = 1
	var validator := RuleValidator.new()
	return assert_false(validator.can_retreat(state, 1, processor), "CSV7C_052 should prevent the damaged defender from retreating during the next opponent turn")


func test_csv7c_054_feraligatr_torrent_heart_adds_damage_and_locks_giant_wave() -> String:
	var gsm := _make_gsm()
	var feraligatr := _make_feraligatr()
	gsm.effect_processor.register_pokemon_card(feraligatr)
	gsm.game_state.players[0].active_pokemon = _make_slot(feraligatr, 0)
	gsm.game_state.players[0].active_pokemon.attached_energy.append(CardInstance.create(_make_energy("Water A", "W"), 0))
	gsm.game_state.players[0].active_pokemon.attached_energy.append(CardInstance.create(_make_energy("Water B", "W"), 0))
	gsm.game_state.players[1].active_pokemon = _make_slot(_make_basic("Target", "C", 320), 1)

	var ability_used := gsm.effect_processor.execute_ability_effect(gsm.game_state.players[0].active_pokemon, 0, [], gsm.game_state)
	var attacked := gsm.use_attack(0, 0)
	gsm.game_state.turn_number = 4
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var locked_reason := gsm.get_attack_unusable_reason(0, 0)
	return run_checks([
		assert_true(ability_used, "Torrent Heart should be usable during its owner's turn"),
		assert_eq(gsm.game_state.players[0].active_pokemon.damage_counters, 50, "Torrent Heart should place 5 damage counters on Feraligatr"),
		assert_true(attacked, "Feraligatr should be able to use Giant Wave with WW attached"),
		assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, 280, "Torrent Heart should add 120 damage to Giant Wave"),
		assert_true(locked_reason != "", "Giant Wave should be locked on Feraligatr's next own turn"),
	])


func test_csv7c_118_relicanth_grants_previous_evolution_attacks_to_feraligatr() -> String:
	var gsm := _make_gsm()
	_register_feraligatr_line(gsm.effect_processor)
	var line_slot := _make_feraligatr_line_slot(0)
	gsm.game_state.players[0].active_pokemon = line_slot
	gsm.game_state.players[0].active_pokemon.attached_energy.append(CardInstance.create(_make_energy("Water", "W"), 0))
	gsm.game_state.players[0].bench = [
		_make_slot(_make_relicanth(), 0),
		_make_slot(_make_basic("Switch Target", "C", 80), 0),
	]

	var granted := gsm.effect_processor.get_granted_attacks(line_slot, gsm.game_state)
	var names: Array[String] = []
	for attack: Dictionary in granted:
		names.append(str(attack.get("name", "")))
	return run_checks([
		assert_contains(names, "啃住", "Relicanth should grant Totodile's attack to evolved Feraligatr"),
		assert_contains(names, "逆向喷射", "Relicanth should grant Croconaw's attack to evolved Feraligatr"),
		assert_true(gsm.rule_validator.can_use_granted_attack(gsm.game_state, 0, line_slot, _find_granted_attack(granted, "啃住"), gsm.effect_processor), "Granted Totodile attack should pass the normal energy gate"),
	])


func test_csv7c_118_granted_reverse_thrust_uses_source_attack_effect() -> String:
	var gsm := _make_gsm()
	_register_feraligatr_line(gsm.effect_processor)
	var line_slot := _make_feraligatr_line_slot(0)
	var switch_target := _make_slot(_make_basic("Switch Target", "C", 80), 0)
	gsm.game_state.players[0].active_pokemon = line_slot
	gsm.game_state.players[0].active_pokemon.attached_energy.append(CardInstance.create(_make_energy("Water", "W"), 0))
	gsm.game_state.players[0].bench = [
		_make_slot(_make_relicanth(), 0),
		switch_target,
	]
	gsm.game_state.players[1].active_pokemon = _make_slot(_make_basic("Target", "C", 120), 1)

	var granted := _find_granted_attack(gsm.effect_processor.get_granted_attacks(line_slot, gsm.game_state), "逆向喷射")
	var steps := gsm.effect_processor.get_granted_attack_interaction_steps(line_slot, granted, gsm.game_state)
	var used := gsm.use_granted_attack(0, line_slot, granted, [{"switch_target": [switch_target]}])
	return run_checks([
		assert_eq(steps.size(), 1, "Granted Reverse Thrust should reuse Croconaw's switch interaction"),
		assert_true(used, "Granted Reverse Thrust should execute through GameStateMachine"),
		assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, 30, "Granted Reverse Thrust should deal Croconaw's 30 damage"),
		assert_eq(gsm.game_state.players[0].active_pokemon, switch_target, "Granted Reverse Thrust should switch Feraligatr with the selected Bench Pokemon"),
	])


func _register_feraligatr_line(processor: EffectProcessor) -> void:
	processor.register_pokemon_card(_make_totodile())
	processor.register_pokemon_card(_make_croconaw())
	processor.register_pokemon_card(_make_feraligatr())
	processor.register_pokemon_card(_make_relicanth())


func _find_granted_attack(attacks: Array[Dictionary], attack_name: String) -> Dictionary:
	for attack: Dictionary in attacks:
		if str(attack.get("name", "")) == attack_name:
			return attack
	return {}


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.effect_processor.bind_game_state_machine(gsm)
	return gsm


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_make_basic("Active%d" % pi, "C", 130), pi)
		player.bench.append(_make_slot(_make_basic("Bench%d" % pi, "C", 80), pi))
		state.players.append(player)
	return state


func _make_feraligatr_line_slot(owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_make_totodile(), owner))
	slot.pokemon_stack.append(CardInstance.create(_make_croconaw(), owner))
	slot.pokemon_stack.append(CardInstance.create(_make_feraligatr(), owner))
	slot.turn_played = 0
	slot.turn_evolved = 0
	return slot


func _make_slot(card_data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_totodile() -> CardData:
	return _make_pokemon(
		"小锯鳄",
		"Totodile",
		"W",
		70,
		"Basic",
		"",
		EFFECT_TOTODILE,
		[{"name": "啃住", "cost": "W", "damage": "10", "text": "The Defending Pokemon can't retreat during your opponent's next turn.", "is_vstar_power": false}],
		[]
	)


func _make_croconaw() -> CardData:
	return _make_pokemon(
		"蓝鳄",
		"Croconaw",
		"W",
		90,
		"Stage 1",
		"小锯鳄",
		EFFECT_CROCONAW,
		[{"name": "逆向喷射", "cost": "W", "damage": "30", "text": "Switch this Pokemon with 1 of your Benched Pokemon.", "is_vstar_power": false}],
		[]
	)


func _make_feraligatr() -> CardData:
	return _make_pokemon(
		"大力鳄",
		"Feraligatr",
		"W",
		180,
		"Stage 2",
		"蓝鳄",
		EFFECT_FERALIGATR,
		[{"name": "骇浪", "cost": "WW", "damage": "160", "text": "During your next turn, this Pokemon can't use Giant Wave.", "is_vstar_power": false}],
		[{"name": "奔流之心", "text": "Once during your turn, put 5 damage counters on this Pokemon. If you do, this Pokemon's attacks do 120 more damage to your opponent's Active Pokemon this turn."}]
	)


func _make_relicanth() -> CardData:
	return _make_pokemon(
		"古空棘鱼",
		"Relicanth",
		"F",
		100,
		"Basic",
		"",
		EFFECT_RELICANTH,
		[{"name": "鳍之利刃", "cost": "FC", "damage": "30", "text": "", "is_vstar_power": false}],
		[{"name": "深潜回忆", "text": "Your evolved Pokemon can use any attacks from their previous Evolutions."}]
	)


func _make_basic(name: String, energy_type: String, hp: int) -> CardData:
	return _make_pokemon(name, name, energy_type, hp, "Basic", "", "", [{"name": "Test Attack", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}], [])


func _make_pokemon(
	name: String,
	name_en: String,
	energy_type: String,
	hp: int,
	stage: String,
	evolves_from: String,
	effect_id: String,
	attacks: Array,
	abilities: Array
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name_en
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.evolves_from = evolves_from
	cd.effect_id = effect_id
	for attack: Variant in attacks:
		if attack is Dictionary:
			cd.attacks.append((attack as Dictionary).duplicate(true))
	for ability: Variant in abilities:
		if ability is Dictionary:
			cd.abilities.append((ability as Dictionary).duplicate(true))
	return cd


func _make_energy(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_type
	return cd
