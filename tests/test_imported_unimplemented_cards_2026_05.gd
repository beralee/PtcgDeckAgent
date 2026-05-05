class_name TestImportedUnimplementedCards202605
extends TestBase


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


func _pokemon(
	name: String,
	effect_id: String = "",
	attacks: Array[Dictionary] = [],
	abilities: Array[Dictionary] = [],
	energy_type: String = "C",
	hp: int = 300,
	stage: String = "Basic",
	mechanic: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.effect_id = effect_id
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.mechanic = mechanic
	cd.attacks = attacks
	cd.abilities = abilities
	return cd


func _trainer(name: String, card_type: String, effect_id: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	cd.description = name
	return cd


func _energy(name: String, energy_type: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for i: int in count:
		var energy := CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index)
		slot.attached_energy.append(energy)
		result.append(energy)
	return result


func _samurott_vstar() -> CardData:
	return _pokemon(
		"洗翠 大剑鬼VSTAR",
		"a0383c4a4ff14425610be52afedf41ae",
		[{"name": "残忍之刃", "cost": "DD", "damage": "110+", "text": "如果对手的战斗宝可梦身上放置有伤害指示物的话，则追加造成110点伤害。", "is_vstar_power": false}],
		[{"name": "残月星耀", "text": "给对手的1只宝可梦身上，放置4个伤害指示物。"}],
		"D",
		270,
		"VSTAR",
		"V"
	)


func _samurott_v() -> CardData:
	return _pokemon(
		"洗翠 大剑鬼V",
		"a8f9150f088068e75cc8acf87773691a",
		[
			{"name": "深青坠击", "cost": "D", "damage": "", "text": "选择放于对手场上宝可梦身上最多2张「宝可梦道具」，放于弃牌区。", "is_vstar_power": false},
			{"name": "暗影之刃", "cost": "DDD", "damage": "180", "text": "选择附着于这只宝可梦身上的1个能量，放于弃牌区。", "is_vstar_power": false},
		],
		[],
		"D",
		220,
		"Basic",
		"V"
	)


func _chansey() -> CardData:
	return _pokemon(
		"吉利蛋",
		"ebbb788ed6a19af88042c8b125d5b8a5",
		[
			{"name": "幸运附着", "cost": "C", "damage": "", "text": "选择自己手牌中的1张基本能量，附着于自己的宝可梦身上。", "is_vstar_power": false},
			{"name": "潜力", "cost": "CCC", "damage": "80", "text": "在下一个自己的回合，这只宝可梦无法使用招式。", "is_vstar_power": false},
		],
		[],
		"C",
		120
	)


func _magnemite_svp() -> CardData:
	return _pokemon(
		"小磁怪",
		"03866b81bfc30ea4727f58e792c6dd2a",
		[
			{"name": "磁力充能", "cost": "C", "damage": "", "text": "选择自己弃牌区中最多2张基本雷能量，附着于1只备战宝可梦身上。", "is_vstar_power": false},
			{"name": "高速球", "cost": "LC", "damage": "20", "text": "", "is_vstar_power": false},
		],
		[],
		"L",
		50
	)


func test_imported_unimplemented_batch_status_is_implemented() -> String:
	CardImplementationStatus.clear_cache()
	var processor := EffectProcessor.new()
	var samurott_vstar := _samurott_vstar()
	var samurott_v := _samurott_v()
	var chansey := _chansey()
	var magnemite := _magnemite_svp()
	processor.register_pokemon_card(samurott_vstar)
	processor.register_pokemon_card(samurott_v)
	processor.register_pokemon_card(chansey)
	processor.register_pokemon_card(magnemite)

	var gapejaw := _trainer("大嘴沼泽", "Stadium", "8784f5412bf62ce1356d2480df0b139b")
	return run_checks([
		assert_not_null(processor.get_effect(gapejaw.effect_id), "Gapejaw Bog should be registered as a Stadium effect"),
		assert_not_null(processor.get_effect(samurott_vstar.effect_id), "Hisuian Samurott VSTAR ability should register by effect_id"),
		assert_true(processor.has_attack_effect(samurott_vstar.effect_id), "Hisuian Samurott VSTAR attack bonus should register"),
		assert_true(processor.has_attack_effect(samurott_v.effect_id), "Hisuian Samurott V attack effects should register"),
		assert_true(processor.has_attack_effect(chansey.effect_id), "Chansey attack effects should register"),
		assert_true(processor.has_attack_effect(magnemite.effect_id), "SVP_102 Magnemite attack effect should register"),
		assert_false(CardImplementationStatus.is_unimplemented(gapejaw), "Gapejaw Bog should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(samurott_vstar), "Hisuian Samurott VSTAR should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(samurott_v), "Hisuian Samurott V should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(chansey), "CSV8C Chansey should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(magnemite), "SVP_102 Magnemite should not show the unimplemented badge"),
	])


func test_cs5_5c_066_gapejaw_bog_damages_basic_played_from_hand_to_bench() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = _make_slot(_pokemon("Own Active"), 0)
	opponent.active_pokemon = _make_slot(_pokemon("Opp Active"), 1)

	var stadium := CardInstance.create(_trainer("大嘴沼泽", "Stadium", "8784f5412bf62ce1356d2480df0b139b"), 0)
	var basic := CardInstance.create(_pokemon("Bench Basic"), 0)
	player.hand.append(stadium)
	player.hand.append(basic)

	var stadium_ok := gsm.play_stadium(0, stadium)
	var bench_ok := gsm.play_basic_to_bench(0, basic, false)

	return run_checks([
		assert_true(stadium_ok, "Gapejaw Bog should be playable"),
		assert_true(bench_ok, "Basic Pokemon should be playable to Bench"),
		assert_eq(player.bench[0].damage_counters, 20, "Gapejaw Bog should place 2 damage counters on the Benched Basic"),
	])


func test_cs5ac_086_hisuian_samurott_vstar_places_counters_and_bonus_damage() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var samurott := _make_slot(_samurott_vstar(), 0)
	var opp_active := _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	var opp_bench := _make_slot(_pokemon("Opponent Bench", "", [], [], "C", 120), 1)
	player.active_pokemon = samurott
	opponent.active_pokemon = opp_active
	opponent.bench.append(opp_bench)
	_attach_energy(samurott, 0, "D", 2)
	gsm.effect_processor.register_pokemon_card(samurott.get_card_data())

	var effect: BaseEffect = gsm.effect_processor.get_effect(samurott.get_card_data().effect_id)
	var steps := effect.get_interaction_steps(samurott.get_top_card(), gsm.game_state)
	var used_ability := gsm.use_ability(0, samurott, 0, [{
		"opponent_pokemon_damage_counter_target": [opp_bench],
	}])
	opp_active.damage_counters = 10
	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_eq(steps.size(), 1, "Moon Cleave Star should ask for one opposing Pokemon target"),
		assert_true(used_ability, "Moon Cleave Star should be usable on own turn"),
		assert_eq(opp_bench.damage_counters, 40, "Moon Cleave Star should place 4 damage counters"),
		assert_true(gsm.game_state.vstar_power_used[0], "Moon Cleave Star should consume the player's VSTAR power"),
		assert_true(attacked, "Merciless Blade should be usable with two Darkness Energy"),
		assert_eq(opp_active.damage_counters, 230, "Merciless Blade should add 220 when the opponent Active is damaged"),
	])


func test_csnc_007_hisuian_samurott_v_discards_opponent_tools_and_self_energy() -> String:
	var tool_a := CardInstance.create(_trainer("Tool A", "Tool", "tool_a"), 1)
	var tool_b := CardInstance.create(_trainer("Tool B", "Tool", "tool_b"), 1)

	var tool_gsm := _make_gsm()
	var tool_player: PlayerState = tool_gsm.game_state.players[0]
	var tool_opponent: PlayerState = tool_gsm.game_state.players[1]
	var tool_samurott := _make_slot(_samurott_v(), 0)
	tool_player.active_pokemon = tool_samurott
	tool_opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	tool_opponent.active_pokemon.attached_tool = tool_a
	var opp_bench := _make_slot(_pokemon("Opponent Bench", "", [], [], "C", 300), 1)
	opp_bench.attached_tool = tool_b
	tool_opponent.bench.append(opp_bench)
	_attach_energy(tool_samurott, 0, "D", 1)
	tool_gsm.effect_processor.register_pokemon_card(tool_samurott.get_card_data())
	var tool_attack_ok := tool_gsm.use_attack(0, 0, [{
		AttackDiscardOpponentTools.STEP_ID: [tool_a, tool_b],
	}])

	var energy_gsm := _make_gsm()
	var energy_player: PlayerState = energy_gsm.game_state.players[0]
	var energy_opponent: PlayerState = energy_gsm.game_state.players[1]
	var energy_samurott := _make_slot(_samurott_v(), 0)
	energy_player.active_pokemon = energy_samurott
	energy_opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	var energies := _attach_energy(energy_samurott, 0, "D", 3)
	energy_gsm.effect_processor.register_pokemon_card(energy_samurott.get_card_data())
	var energy_attack_ok := energy_gsm.use_attack(0, 1, [{
		AttackDiscardAttachedEnergyFromSelf.STEP_ID: [energies[1]],
	}])

	return run_checks([
		assert_true(tool_attack_ok, "Ceaseless Edge should be usable with one Darkness Energy"),
		assert_eq(tool_opponent.active_pokemon.attached_tool, null, "Selected opponent Active Tool should be discarded"),
		assert_eq(opp_bench.attached_tool, null, "Selected opponent Benched Tool should be discarded"),
		assert_contains(tool_opponent.discard_pile, tool_a, "First selected Tool should move to discard"),
		assert_contains(tool_opponent.discard_pile, tool_b, "Second selected Tool should move to discard"),
		assert_true(energy_attack_ok, "Shadow Slash should be usable with three Darkness Energy"),
		assert_eq(energy_opponent.active_pokemon.damage_counters, 180, "Shadow Slash should deal 180 damage"),
		assert_contains(energy_player.discard_pile, energies[1], "Selected attached Energy should be discarded from Samurott V"),
		assert_false(energies[1] in energy_samurott.attached_energy, "Discarded Energy should leave Samurott V"),
	])


func test_csv8c_164_chansey_attaches_energy_from_hand_and_self_locks_potential() -> String:
	var attach_gsm := _make_gsm()
	var attach_player: PlayerState = attach_gsm.game_state.players[0]
	var attach_opponent: PlayerState = attach_gsm.game_state.players[1]
	var chansey := _make_slot(_chansey(), 0)
	var bench := _make_slot(_pokemon("Bench Target"), 0)
	attach_player.active_pokemon = chansey
	attach_player.bench.append(bench)
	attach_opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	_attach_energy(chansey, 0, "C", 1)
	var hand_energy := CardInstance.create(_energy("Lightning Energy", "L"), 0)
	attach_player.hand.append(hand_energy)
	attach_gsm.effect_processor.register_pokemon_card(chansey.get_card_data())
	var attach_ok := attach_gsm.use_attack(0, 0, [{
		"hand_basic_energy": [hand_energy],
		"attach_target": [bench],
	}])

	var lock_gsm := _make_gsm()
	var lock_player: PlayerState = lock_gsm.game_state.players[0]
	var lock_opponent: PlayerState = lock_gsm.game_state.players[1]
	var lock_chansey := _make_slot(_chansey(), 0)
	lock_player.active_pokemon = lock_chansey
	lock_opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	_attach_energy(lock_chansey, 0, "C", 3)
	lock_gsm.effect_processor.register_pokemon_card(lock_chansey.get_card_data())
	var potential_ok := lock_gsm.use_attack(0, 1)
	lock_gsm.game_state.turn_number = 4
	lock_gsm.game_state.current_player_index = 0
	lock_gsm.game_state.phase = GameState.GamePhase.MAIN
	var lock_reason := lock_gsm.get_attack_unusable_reason(0, 1)

	return run_checks([
		assert_true(attach_ok, "Lucky Attach should be usable with a Basic Energy in hand"),
		assert_contains(bench.attached_energy, hand_energy, "Lucky Attach should attach selected Basic Energy to the selected Pokemon"),
		assert_false(hand_energy in attach_player.hand, "Attached hand Energy should leave hand"),
		assert_true(potential_ok, "Potential should be usable with three Colorless Energy"),
		assert_true(lock_reason != "", "Potential should lock the same attack on Chansey's next turn"),
	])


func test_svp_102_magnemite_attaches_basic_lightning_from_discard_to_bench() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var magnemite := _make_slot(_magnemite_svp(), 0)
	var target := _make_slot(_pokemon("Bench Target", "", [], [], "L", 120), 0)
	player.active_pokemon = magnemite
	player.bench.append(target)
	opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	_attach_energy(magnemite, 0, "L", 1)
	var lightning_a := CardInstance.create(_energy("Lightning Energy A", "L"), 0)
	var lightning_b := CardInstance.create(_energy("Lightning Energy B", "L"), 0)
	var fighting := CardInstance.create(_energy("Fighting Energy", "F"), 0)
	player.discard_pile.append_array([lightning_a, lightning_b, fighting])
	gsm.effect_processor.register_pokemon_card(magnemite.get_card_data())

	var steps := gsm.effect_processor.get_attack_interaction_steps_by_id(
		magnemite.get_card_data().effect_id,
		0,
		magnemite.get_top_card(),
		magnemite.get_card_data().attacks[0],
		gsm.game_state
	)
	var attacked := gsm.use_attack(0, 0, [{
		AttackAttachBasicEnergyFromDiscard.ENERGY_STEP_ID: [lightning_a, lightning_b],
		AttackAttachBasicEnergyFromDiscard.TARGET_STEP_ID: [target],
	}])

	return run_checks([
		assert_eq(steps.size(), 2, "Magnetic Charge should ask for Lightning Energy and a Bench target"),
		assert_true(attacked, "Magnetic Charge should be usable with Colorless attack cost paid"),
		assert_contains(target.attached_energy, lightning_a, "First selected Lightning Energy should attach to the Benched Pokemon"),
		assert_contains(target.attached_energy, lightning_b, "Second selected Lightning Energy should attach to the Benched Pokemon"),
		assert_contains(player.discard_pile, fighting, "Off-type Basic Energy should stay in discard"),
		assert_false(lightning_a in player.discard_pile, "Attached Lightning Energy should leave discard"),
		assert_false(lightning_b in player.discard_pile, "Attached Lightning Energy should leave discard"),
	])
