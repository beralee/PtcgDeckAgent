class_name TestImportedUnimplementedCards202605
extends TestBase

const AttackCoinFlipDiscardOpponentActiveEnergyScript = preload("res://scripts/effects/pokemon_effects/AttackCoinFlipDiscardOpponentActiveEnergy.gd")
const AttackMoveAttachedEnergyToOwnBenchScript = preload("res://scripts/effects/pokemon_effects/AttackMoveAttachedEnergyToOwnBench.gd")


class CountingHeadsCoinFlipper:
	extends CoinFlipper

	var flip_count := 0

	func flip() -> bool:
		flip_count += 1
		coin_flipped.emit(true)
		return true


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


func _add_dummy_prizes(state: GameState, count: int = 6) -> void:
	for pi: int in state.players.size():
		for i: int in count:
			state.players[pi].prizes.append(CardInstance.create(_trainer("Prize %d-%d" % [pi, i], "Item", ""), pi))


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


func _scyther_151c() -> CardData:
	return _pokemon(
		"Scyther 151C",
		"fe8b1bda35af50a16e59e2dcd7cd473f",
		[
			{"name": "Assist Slash", "cost": "G", "damage": "20", "text": "Attach a Basic Grass Energy from discard to a Benched Pokemon.", "is_vstar_power": false},
			{"name": "Slice Blade", "cost": "GCC", "damage": "70", "text": "", "is_vstar_power": false},
		],
		[],
		"G",
		70
	)


func _rellor_csv4c() -> CardData:
	return _pokemon(
		"Rellor CSV4C",
		"1b1e45dbcbf4b21a5af893ad492b7c66",
		[{"name": "Rollout", "cost": "CC", "damage": "30x", "text": "Flip coins until tails. This attack does 30 damage for each heads.", "is_vstar_power": false}],
		[],
		"G",
		50
	)


func _scizor_csv4c() -> CardData:
	return _pokemon(
		"Scizor CSV4C",
		"0fc11aeb024998d63c530b67f99c8bbb",
		[
			{"name": "Punishing Scissors", "cost": "M", "damage": "10+", "text": "This attack does 50 more damage for each of your opponent's Pokemon in play that has an Ability.", "is_vstar_power": false},
			{"name": "Cut", "cost": "MM", "damage": "70", "text": "", "is_vstar_power": false},
		],
		[],
		"M",
		140,
		"Stage 1"
	)


func _rabsca_csv7c() -> CardData:
	return _pokemon(
		"Rabsca CSV7C",
		"4e41398ab9262f85910de1d9b3a4f027",
		[{"name": "Psychic", "cost": "G", "damage": "10+", "text": "This attack does 30 more damage for each Energy attached to your opponent's Active Pokemon.", "is_vstar_power": false}],
		[{"name": "Spherical Shield", "text": "Your Benched Pokemon are protected from damage and effects of attacks from your opponent's Pokemon."}],
		"G",
		70,
		"Stage 1"
	)


func _thwackey_csv8c() -> CardData:
	return _pokemon(
		"Thwackey CSV8C",
		"936b27cc51f950a455c824375d621421",
		[{"name": "Beat", "cost": "GG", "damage": "50", "text": "", "is_vstar_power": false}],
		[{"name": "Boom Boom Drum", "text": "If your Active Pokemon has Festival Lead, search your deck for a card."}],
		"G",
		100,
		"Stage 1"
	)


func _rillaboom_csv8c() -> CardData:
	return _pokemon(
		"Rillaboom CSV8C",
		"266f2933c7baa1b640d9b55a38c76db4",
		[
			{"name": "Drum Beating", "cost": "G", "damage": "60", "text": "During your opponent's next turn, the Defending Pokemon's attacks and retreat cost increase by Colorless.", "is_vstar_power": false},
			{"name": "Wood Hammer", "cost": "GG", "damage": "180", "text": "This Pokemon also does 50 damage to itself.", "is_vstar_power": false},
		],
		[],
		"G",
		180,
		"Stage 2"
	)


func _applin_csv8c() -> CardData:
	return _pokemon(
		"Applin CSV8C",
		"95d820ef31a7e8ad71a89fcf8fb85c90",
		[{"name": "Rollout", "cost": "G", "damage": "10+", "text": "Flip a coin. If heads, this attack does 20 more damage.", "is_vstar_power": false}],
		[],
		"G",
		40
	)


func _dipplin_csv8c() -> CardData:
	return _pokemon(
		"Dipplin CSV8C",
		"144b6904892dc89e3efb81067c5668c4",
		[{"name": "Do the Wave", "cost": "G", "damage": "20×", "text": "This attack does 20 damage for each of your Benched Pokemon.", "is_vstar_power": false}],
		[{"name": "Festival Lead", "text": "If Festival Grounds is in play, this Pokemon can attack twice."}],
		"G",
		80,
		"Stage 1"
	)


func _lana_csv7c() -> CardData:
	return _trainer("Lana's Aid CSV7C", "Supporter", "b79ddb9a6aab6d346f6a1f71b7fcd3de")


func _bug_catching_set_csv8c() -> CardData:
	return _trainer("Bug Catching Set CSV8C", "Item", "adf4d1157e58b1421d1b6d0871b2fc88")


func _festival_grounds_csv8c() -> CardData:
	return _trainer("Festival Grounds CSV8C", "Stadium", "357d55b54ded5db071b55ebe165749fc")


func _cynthias_ambition_csnc() -> CardData:
	return _trainer("Cynthia's Ambition CSNC", "Supporter", "2e5819cd4e1c354b8a9945525c54ec71")


func _goldeen_csv8c() -> CardData:
	return _pokemon(
		"Goldeen CSV8C",
		"7580acd5669bac12cb1af8007d2e6a6a",
		[{"name": "Whirlpool", "cost": "CC", "damage": "10", "text": "Flip a coin. If heads, discard an Energy from your opponent's Active Pokemon.", "is_vstar_power": false}],
		[{"name": "Festival Lead", "text": "If Festival Grounds is in play, this Pokemon can attack twice."}],
		"W",
		60
	)


func _rellor_csv7c_030() -> CardData:
	return _pokemon(
		"Rellor CSV7C 030",
		"c2d6b5ec0bc365112105fea079a22fd7",
		[{"name": "Tiny Reckless Charge", "cost": "C", "damage": "30", "text": "This Pokemon also does 10 damage to itself.", "is_vstar_power": false}],
		[],
		"G",
		50
	)


func _morpeko_csv3c() -> CardData:
	var cd := _pokemon(
		"Morpeko CSV3C",
		"f189ac39dca6332f0b3af7b65cea8220",
		[{"name": "Energy Wheel", "cost": "DD", "damage": "70", "text": "Move 2 Darkness Energy from this Pokemon to 1 of your Benched Pokemon.", "is_vstar_power": false}],
		[{"name": "Hungry Dash", "text": "If this Pokemon has no Energy attached, it has no Retreat Cost."}],
		"L",
		70
	)
	cd.retreat_cost = 1
	return cd


func test_imported_unimplemented_batch_status_is_implemented() -> String:
	CardImplementationStatus.clear_cache()
	var processor := EffectProcessor.new()
	var samurott_vstar := _samurott_vstar()
	var samurott_v := _samurott_v()
	var chansey := _chansey()
	var magnemite := _magnemite_svp()
	var scyther := _scyther_151c()
	var rellor := _rellor_csv4c()
	var scizor := _scizor_csv4c()
	var rabsca := _rabsca_csv7c()
	var thwackey := _thwackey_csv8c()
	var rillaboom := _rillaboom_csv8c()
	var applin := _applin_csv8c()
	var dipplin := _dipplin_csv8c()
	var goldeen := _goldeen_csv8c()
	var rellor_csv7c := _rellor_csv7c_030()
	var morpeko := _morpeko_csv3c()
	processor.register_pokemon_card(samurott_vstar)
	processor.register_pokemon_card(samurott_v)
	processor.register_pokemon_card(chansey)
	processor.register_pokemon_card(magnemite)
	processor.register_pokemon_card(scyther)
	processor.register_pokemon_card(rellor)
	processor.register_pokemon_card(scizor)
	processor.register_pokemon_card(rabsca)
	processor.register_pokemon_card(thwackey)
	processor.register_pokemon_card(rillaboom)
	processor.register_pokemon_card(applin)
	processor.register_pokemon_card(dipplin)
	processor.register_pokemon_card(goldeen)
	processor.register_pokemon_card(rellor_csv7c)
	processor.register_pokemon_card(morpeko)

	var gapejaw := _trainer("大嘴沼泽", "Stadium", "8784f5412bf62ce1356d2480df0b139b")
	var lana := _lana_csv7c()
	var bug_set := _bug_catching_set_csv8c()
	var festival := _festival_grounds_csv8c()
	var cynthia := _cynthias_ambition_csnc()
	return run_checks([
		assert_not_null(processor.get_effect(gapejaw.effect_id), "Gapejaw Bog should be registered as a Stadium effect"),
		assert_not_null(processor.get_effect(lana.effect_id), "Lana's Aid should be registered as a Supporter effect"),
		assert_not_null(processor.get_effect(cynthia.effect_id), "Cynthia's Ambition should be registered as a Supporter effect"),
		assert_not_null(processor.get_effect(bug_set.effect_id), "Bug Catching Set should be registered as an Item effect"),
		assert_not_null(processor.get_effect(festival.effect_id), "Festival Grounds should be registered as a Stadium effect"),
		assert_not_null(processor.get_effect(samurott_vstar.effect_id), "Hisuian Samurott VSTAR ability should register by effect_id"),
		assert_true(processor.has_attack_effect(samurott_vstar.effect_id), "Hisuian Samurott VSTAR attack bonus should register"),
		assert_true(processor.has_attack_effect(samurott_v.effect_id), "Hisuian Samurott V attack effects should register"),
		assert_true(processor.has_attack_effect(chansey.effect_id), "Chansey attack effects should register"),
		assert_true(processor.has_attack_effect(magnemite.effect_id), "SVP_102 Magnemite attack effect should register"),
		assert_true(processor.has_attack_effect(scyther.effect_id), "Scyther Assist Slash should register"),
		assert_true(processor.has_attack_effect(rellor.effect_id), "Rellor coin multiplier should register"),
		assert_true(processor.has_attack_effect(scizor.effect_id), "Scizor Punishing Scissors should register"),
		assert_not_null(processor.get_effect(rabsca.effect_id), "Rabsca Spherical Shield should register"),
		assert_true(processor.has_attack_effect(rabsca.effect_id), "Rabsca Psychic should register"),
		assert_not_null(processor.get_effect(thwackey.effect_id), "Thwackey Boom Boom Drum should register"),
		assert_true(processor.has_attack_effect(rillaboom.effect_id), "Rillaboom attack effects should register"),
		assert_true(processor.has_attack_effect(applin.effect_id), "Applin coin bonus should register"),
		assert_not_null(processor.get_effect(dipplin.effect_id), "Dipplin Festival Lead should register"),
		assert_true(processor.has_attack_effect(dipplin.effect_id), "Dipplin bench-count attack should register"),
		assert_not_null(processor.get_effect(goldeen.effect_id), "Goldeen Festival Lead should register"),
		assert_true(processor.has_attack_effect(goldeen.effect_id), "Goldeen Whirlpool should register"),
		assert_true(processor.has_attack_effect(rellor_csv7c.effect_id), "CSV7C Rellor self-damage attack should register"),
		assert_not_null(processor.get_effect(morpeko.effect_id), "Morpeko Hungry Dash should register"),
		assert_true(processor.has_attack_effect(morpeko.effect_id), "Morpeko Energy Wheel should register"),
		assert_false(CardImplementationStatus.is_unimplemented(gapejaw), "Gapejaw Bog should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(lana), "Lana's Aid should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(cynthia), "Cynthia's Ambition should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(bug_set), "Bug Catching Set should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(festival), "Festival Grounds should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(samurott_vstar), "Hisuian Samurott VSTAR should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(samurott_v), "Hisuian Samurott V should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(chansey), "CSV8C Chansey should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(magnemite), "SVP_102 Magnemite should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(scyther), "Scyther should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(rellor), "Rellor should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(scizor), "Scizor should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(rabsca), "Rabsca should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(thwackey), "Thwackey should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(rillaboom), "Rillaboom should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(applin), "Applin should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(dipplin), "Dipplin should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(goldeen), "Goldeen should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(rellor_csv7c), "CSV7C Rellor should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(morpeko), "Morpeko should not show the unimplemented badge"),
	])


func test_csnc_020_cynthias_ambition_draws_to_five_or_eight() -> String:
	var normal_gsm := _make_gsm()
	var normal_player: PlayerState = normal_gsm.game_state.players[0]
	var normal_cynthia := CardInstance.create(_cynthias_ambition_csnc(), 0)
	normal_player.hand.append(normal_cynthia)
	normal_player.hand.append(CardInstance.create(_trainer("Keep A", "Item", "none"), 0))
	normal_player.hand.append(CardInstance.create(_trainer("Keep B", "Item", "none"), 0))
	normal_player.hand.append(CardInstance.create(_trainer("Keep C", "Item", "none"), 0))
	normal_player.hand.append(CardInstance.create(_trainer("Keep D", "Item", "none"), 0))
	for i: int in 10:
		normal_player.deck.append(CardInstance.create(_trainer("Normal Draw %d" % i, "Item", "none"), 0))
	var normal_effect: BaseEffect = normal_gsm.effect_processor.get_effect(normal_cynthia.card_data.effect_id)
	var normal_can_before_play: bool = normal_effect.can_execute(normal_cynthia, normal_gsm.game_state)
	var normal_played := normal_gsm.play_trainer(0, normal_cynthia, [])

	var ko_gsm := _make_gsm()
	var ko_player: PlayerState = ko_gsm.game_state.players[0]
	ko_gsm.game_state.last_knockout_turn_against[0] = ko_gsm.game_state.turn_number - 1
	var ko_cynthia := CardInstance.create(_cynthias_ambition_csnc(), 0)
	ko_player.hand.append(ko_cynthia)
	for i: int in 7:
		ko_player.hand.append(CardInstance.create(_trainer("KO Keep %d" % i, "Item", "none"), 0))
	for i: int in 10:
		ko_player.deck.append(CardInstance.create(_trainer("KO Draw %d" % i, "Item", "none"), 0))
	var ko_effect: BaseEffect = ko_gsm.effect_processor.get_effect(ko_cynthia.card_data.effect_id)
	var ko_can_before_play: bool = ko_effect.can_execute(ko_cynthia, ko_gsm.game_state)
	var ko_played := ko_gsm.play_trainer(0, ko_cynthia, [])

	return run_checks([
		assert_true(normal_can_before_play, "Cynthia's Ambition should pass pre-play checks with five cards including Cynthia"),
		assert_true(normal_played, "Cynthia's Ambition should be playable with hand below five"),
		assert_eq(normal_player.hand.size(), 5, "Cynthia's Ambition should draw until the player has five cards"),
		assert_true(ko_can_before_play, "Cynthia's Ambition should pass pre-play checks with eight cards including Cynthia after a knockout"),
		assert_true(ko_played, "Cynthia's Ambition should be playable after a previous-turn knockout"),
		assert_eq(ko_player.hand.size(), 8, "Cynthia's Ambition should draw until the player has eight cards after a previous-turn knockout"),
	])


func test_csv8c_050_goldeen_festival_lead_and_whirlpool() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var goldeen := _make_slot(_goldeen_csv8c(), 0)
	player.active_pokemon = goldeen
	opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 100), 1)
	var opponent_energy := CardInstance.create(_energy("Opponent Fire Energy", "R"), 1)
	opponent.active_pokemon.attached_energy.append(opponent_energy)
	gsm.game_state.stadium_card = CardInstance.create(_festival_grounds_csv8c(), 0)
	gsm.game_state.stadium_owner_index = 0
	gsm.effect_processor.register_pokemon_card(goldeen.get_card_data())

	var flipper := CountingHeadsCoinFlipper.new()
	var effect: BaseEffect = AttackCoinFlipDiscardOpponentActiveEnergyScript.new(0, flipper)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(goldeen.get_top_card(), goldeen.get_card_data().attacks[0], gsm.game_state)
	var preview_steps_again: Array[Dictionary] = effect.get_attack_interaction_steps(goldeen.get_top_card(), goldeen.get_card_data().attacks[0], gsm.game_state)
	effect.set_attack_interaction_context([{
		AttackCoinFlipDiscardOpponentActiveEnergyScript.ENERGY_STEP_ID: [opponent_energy],
	}])
	effect.execute_attack(goldeen, opponent.active_pokemon, 0, gsm.game_state)

	return run_checks([
		assert_true(AbilityFestivalLead.has_festival_lead(goldeen), "Goldeen should count as a Festival Lead Pokemon"),
		assert_true(AbilityFestivalLead.can_take_second_attack(goldeen, gsm.game_state), "Goldeen should be eligible for a second attack under Festival Grounds"),
		assert_eq(steps.size(), 1, "Whirlpool should ask which opponent Active Energy to discard if heads"),
		assert_eq(preview_steps_again.size(), 1, "Whirlpool preview should be stable across repeated legal-action scans"),
		assert_eq(flipper.flip_count, 1, "Whirlpool should flip only during attack execution, not during interaction preview"),
		assert_contains(opponent.discard_pile, opponent_energy, "Whirlpool should discard the selected opponent Active Energy on heads"),
		assert_false(opponent_energy in opponent.active_pokemon.attached_energy, "Discarded Energy should leave the opponent Active"),
	])


func test_csv7c_030_rellor_damages_itself_after_attack() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var rellor := _make_slot(_rellor_csv7c_030(), 0)
	player.active_pokemon = rellor
	opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 100), 1)
	_attach_energy(rellor, 0, "C", 1)
	gsm.effect_processor.register_pokemon_card(rellor.get_card_data())

	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(attacked, "CSV7C Rellor should attack with one Colorless Energy"),
		assert_eq(opponent.active_pokemon.damage_counters, 30, "Tiny Reckless Charge should deal 30 damage"),
		assert_eq(rellor.damage_counters, 10, "Tiny Reckless Charge should deal 10 self damage"),
	])


func test_csv3c_086_morpeko_free_retreat_and_energy_wheel() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var morpeko := _make_slot(_morpeko_csv3c(), 0)
	var bench := _make_slot(_pokemon("Bench Target", "", [], [], "D", 100), 0)
	player.active_pokemon = morpeko
	player.bench.append(bench)
	opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 100), 1)
	gsm.effect_processor.register_pokemon_card(morpeko.get_card_data())

	var free_retreat := gsm.effect_processor.get_effective_retreat_cost(morpeko, gsm.game_state)
	var energies := _attach_energy(morpeko, 0, "D", 2)
	var paid_retreat := gsm.effect_processor.get_effective_retreat_cost(morpeko, gsm.game_state)
	var attacked := gsm.use_attack(0, 0, [{
		AttackMoveAttachedEnergyToOwnBenchScript.ENERGY_STEP_ID: energies,
		AttackMoveAttachedEnergyToOwnBenchScript.TARGET_STEP_ID: [bench],
	}])

	return run_checks([
		assert_eq(free_retreat, 0, "Morpeko should have no Retreat Cost while it has no Energy attached"),
		assert_eq(paid_retreat, 1, "Morpeko should use its printed Retreat Cost once Energy is attached"),
		assert_true(attacked, "Energy Wheel should be usable with two Darkness Energy"),
		assert_eq(opponent.active_pokemon.damage_counters, 70, "Energy Wheel should deal 70 damage"),
		assert_eq(morpeko.attached_energy.size(), 0, "Energy Wheel should move selected Darkness Energy off Morpeko"),
		assert_contains(bench.attached_energy, energies[0], "First selected Darkness Energy should move to the Benched Pokemon"),
		assert_contains(bench.attached_energy, energies[1], "Second selected Darkness Energy should move to the Benched Pokemon"),
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


func test_151c_123_scyther_attaches_basic_grass_from_discard_to_bench() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var scyther := _make_slot(_scyther_151c(), 0)
	var target := _make_slot(_pokemon("Bench Target", "", [], [], "G", 120), 0)
	player.active_pokemon = scyther
	player.bench.append(target)
	opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	_attach_energy(scyther, 0, "G", 1)
	var grass := CardInstance.create(_energy("Grass Energy", "G"), 0)
	var fire := CardInstance.create(_energy("Fire Energy", "R"), 0)
	player.discard_pile.append_array([grass, fire])
	gsm.effect_processor.register_pokemon_card(scyther.get_card_data())

	var attacked := gsm.use_attack(0, 0, [{
		AttackAttachBasicEnergyFromDiscard.ENERGY_STEP_ID: [grass],
		AttackAttachBasicEnergyFromDiscard.TARGET_STEP_ID: [target],
	}])

	return run_checks([
		assert_true(attacked, "Scyther should use Assist Slash"),
		assert_contains(target.attached_energy, grass, "Assist Slash should attach the selected Basic Grass Energy to the Bench"),
		assert_contains(player.discard_pile, fire, "Off-type Basic Energy should remain in discard"),
		assert_false(grass in player.discard_pile, "Attached Grass Energy should leave discard"),
	])


func test_csv4c_081_scizor_counts_opponent_pokemon_with_abilities() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var scizor := _make_slot(_scizor_csv4c(), 0)
	player.active_pokemon = scizor
	opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [{"name": "Ability A", "text": "A"}], "C", 300), 1)
	opponent.bench.append(_make_slot(_pokemon("Opponent Bench Ability", "", [], [{"name": "Ability B", "text": "B"}], "C", 100), 1))
	opponent.bench.append(_make_slot(_pokemon("Opponent Bench Vanilla", "", [], [], "C", 100), 1))
	_attach_energy(scizor, 0, "M", 1)
	gsm.effect_processor.register_pokemon_card(scizor.get_card_data())

	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(attacked, "Scizor should use Punishing Scissors"),
		assert_eq(opponent.active_pokemon.damage_counters, 110, "Punishing Scissors should deal 10 plus 50 for each of two opposing Ability Pokemon"),
	])


func test_csv7c_031_rabsca_counts_active_energy_and_protects_bench() -> String:
	var damage_gsm := _make_gsm()
	var damage_player: PlayerState = damage_gsm.game_state.players[0]
	var damage_opponent: PlayerState = damage_gsm.game_state.players[1]
	var rabsca := _make_slot(_rabsca_csv7c(), 0)
	damage_player.active_pokemon = rabsca
	damage_opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	_attach_energy(rabsca, 0, "G", 1)
	_attach_energy(damage_opponent.active_pokemon, 1, "C", 2)
	damage_gsm.effect_processor.register_pokemon_card(rabsca.get_card_data())
	var attacked := damage_gsm.use_attack(0, 0)

	var protect_state := _make_state()
	var shield_owner: PlayerState = protect_state.players[0]
	var attacking_player: PlayerState = protect_state.players[1]
	shield_owner.active_pokemon = _make_slot(_rabsca_csv7c(), 0)
	var protected_bench := _make_slot(_pokemon("Protected Bench", "", [], [], "C", 100), 0)
	shield_owner.bench.append(protected_bench)
	var bench_attacker := _make_slot(_pokemon("Bench Sniper", "", [], [], "C", 100), 1)
	attacking_player.active_pokemon = bench_attacker
	EffectBenchDamage.new(30, true, "opponent").execute_attack(bench_attacker, shield_owner.active_pokemon, 0, protect_state)

	return run_checks([
		assert_true(attacked, "Rabsca should use Psychic"),
		assert_eq(damage_opponent.active_pokemon.damage_counters, 70, "Psychic should deal 10 plus 30 for each of two defender Energy"),
		assert_eq(protected_bench.damage_counters, 0, "Spherical Shield should protect Benched Pokemon from opponent attack damage"),
	])


func test_csv7c_031_rabsca_blocks_bench_attack_effects() -> String:
	var state := _make_state()
	state.current_player_index = 1
	var shield_owner: PlayerState = state.players[0]
	var attacking_player: PlayerState = state.players[1]
	shield_owner.active_pokemon = _make_slot(_rabsca_csv7c(), 0)
	var protected_bench := _make_slot(_pokemon("Protected Bench", "", [], [], "C", 200), 0)
	var bench_tool := CardInstance.create(_trainer("Bench Tool", "Pokemon Tool", "tool-effect"), 0)
	protected_bench.attached_tool = bench_tool
	shield_owner.bench.append(protected_bench)
	var attacker := _make_slot(_pokemon("Effect Attacker", "", [], [], "C", 200), 1)
	attacker.damage_counters = 30
	attacking_player.active_pokemon = attacker

	var any_target := AttackAnyTargetDamage.new(40)
	any_target.set_attack_interaction_context([{"any_target": [protected_bench]}])
	any_target.execute_attack(attacker, shield_owner.active_pokemon, 0, state)

	var move_counters := AttackMoveOwnDamageCountersToOpponent.new(20, 0)
	move_counters.set_attack_interaction_context([{AttackMoveOwnDamageCountersToOpponent.TARGET_STEP_ID: [protected_bench]}])
	move_counters.execute_attack(attacker, shield_owner.active_pokemon, 0, state)

	var self_counter_damage := AttackSelfDamageCounterTargetDamage.new(20)
	self_counter_damage.set_attack_interaction_context([{"target_pokemon": [protected_bench]}])
	self_counter_damage.execute_attack(attacker, shield_owner.active_pokemon, 0, state)

	var discard_tools := AttackDiscardOpponentTools.new(1, 0)
	discard_tools.set_attack_interaction_context([{AttackDiscardOpponentTools.STEP_ID: [bench_tool]}])
	discard_tools.execute_attack(attacker, shield_owner.active_pokemon, 0, state)

	return run_checks([
		assert_eq(protected_bench.damage_counters, 0, "Spherical Shield should block opponent any-target and counter-placement attack effects on Bench"),
		assert_eq(attacker.damage_counters, 30, "Blocked counter-moving effects should not remove counters from the attacker side"),
		assert_eq(protected_bench.attached_tool, bench_tool, "Spherical Shield should block attack effects that discard a Benched Pokemon's tool"),
		assert_false(bench_tool in shield_owner.discard_pile, "Blocked Bench tool should not move to discard"),
	])


func test_csv7c_193_lanas_aid_recovers_non_rule_pokemon_and_basic_energy() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var normal_pokemon := CardInstance.create(_pokemon("Normal Pokemon"), 0)
	var rule_pokemon := CardInstance.create(_pokemon("Rule Box Pokemon", "", [], [], "C", 200, "Basic", "ex"), 0)
	var grass_energy := CardInstance.create(_energy("Grass Energy", "G"), 0)
	var lana := CardInstance.create(_lana_csv7c(), 0)
	player.hand.append(lana)
	player.discard_pile.append_array([normal_pokemon, rule_pokemon, grass_energy])

	var played := gsm.play_trainer(0, lana, [{
		EffectLanasAid.STEP_ID: [normal_pokemon, rule_pokemon, grass_energy],
	}])

	return run_checks([
		assert_true(played, "Lana's Aid should be playable with valid discard targets"),
		assert_contains(player.hand, normal_pokemon, "Lana's Aid should recover non-rule-box Pokemon"),
		assert_contains(player.hand, grass_energy, "Lana's Aid should recover Basic Energy"),
		assert_contains(player.discard_pile, rule_pokemon, "Lana's Aid should not recover rule-box Pokemon"),
	])


func test_csv8c_182_bug_catching_set_only_uses_top_seven() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var bug_set := CardInstance.create(_bug_catching_set_csv8c(), 0)
	var top_grass_pokemon := CardInstance.create(_pokemon("Top Grass Pokemon", "", [], [], "G"), 0)
	var top_grass_energy := CardInstance.create(_energy("Top Grass Energy", "G"), 0)
	var top_fire_pokemon := CardInstance.create(_pokemon("Top Fire Pokemon", "", [], [], "R"), 0)
	var deep_grass_pokemon := CardInstance.create(_pokemon("Deep Grass Pokemon", "", [], [], "G"), 0)
	player.hand.append(bug_set)
	player.deck.append_array([
		top_grass_pokemon,
		top_fire_pokemon,
		top_grass_energy,
		CardInstance.create(_trainer("Top Item A", "Item", "none_a"), 0),
		CardInstance.create(_trainer("Top Item B", "Item", "none_b"), 0),
		CardInstance.create(_trainer("Top Item C", "Item", "none_c"), 0),
		CardInstance.create(_trainer("Top Item D", "Item", "none_d"), 0),
		deep_grass_pokemon,
	])

	var played := gsm.play_trainer(0, bug_set, [{
		EffectBugCatchingSet.STEP_ID: [top_grass_pokemon, top_grass_energy, deep_grass_pokemon],
	}])

	return run_checks([
		assert_true(played, "Bug Catching Set should be playable"),
		assert_contains(player.hand, top_grass_pokemon, "Bug Catching Set should take matching Grass Pokemon from the top seven"),
		assert_contains(player.hand, top_grass_energy, "Bug Catching Set should take Basic Grass Energy from the top seven"),
		assert_contains(player.deck, deep_grass_pokemon, "Bug Catching Set should not take matching cards below the top seven"),
		assert_contains(player.deck, top_fire_pokemon, "Bug Catching Set should leave nonmatching top-seven cards in deck"),
	])


func test_csv8c_201_festival_grounds_clears_and_prevents_special_conditions() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var active := _make_slot(_pokemon("Energy Active"), 0)
	var bench := _make_slot(_pokemon("No Energy Bench"), 0)
	player.active_pokemon = active
	player.bench.append(bench)
	opponent.active_pokemon = _make_slot(_pokemon("Opponent Active"), 1)
	_attach_energy(active, 0, "G", 1)
	active.set_status("poisoned", true)
	bench.set_status("asleep", true)
	var stadium := CardInstance.create(_festival_grounds_csv8c(), 0)
	player.hand.append(stadium)

	var played := gsm.play_stadium(0, stadium)
	EffectApplyStatus.new("burned").execute_attack(opponent.active_pokemon, active, 0, gsm.game_state)
	EffectApplyStatus.new("poisoned").execute_attack(opponent.active_pokemon, bench, 0, gsm.game_state)

	return run_checks([
		assert_true(played, "Festival Grounds should be playable"),
		assert_false(active.status_conditions.get("poisoned", false), "Festival Grounds should clear status from Pokemon with Energy"),
		assert_false(active.status_conditions.get("burned", false), "Festival Grounds should prevent new status on Pokemon with Energy"),
		assert_true(bench.status_conditions.get("poisoned", false), "Festival Grounds should not prevent status on Pokemon without Energy"),
	])


func test_csv8c_021_thwackey_search_requires_active_festival_lead() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var thwackey := _make_slot(_thwackey_csv8c(), 0)
	var dipplin := _make_slot(_dipplin_csv8c(), 0)
	var search_card := CardInstance.create(_trainer("Search Target", "Item", "none"), 0)
	player.active_pokemon = _make_slot(_pokemon("Plain Active"), 0)
	player.bench.append(thwackey)
	player.deck.append(search_card)
	opponent.active_pokemon = _make_slot(_pokemon("Opponent Active"), 1)
	gsm.effect_processor.register_pokemon_card(thwackey.get_card_data())
	gsm.effect_processor.register_pokemon_card(dipplin.get_card_data())

	var blocked := gsm.effect_processor.can_use_ability(thwackey, gsm.game_state, 0)
	player.active_pokemon = dipplin
	var used := gsm.use_ability(0, thwackey, 0, [{
		"search_cards": [search_card],
	}])

	return run_checks([
		assert_false(blocked, "Thwackey should not search unless the Active Pokemon has Festival Lead"),
		assert_true(used, "Thwackey should search when the Active Pokemon has Festival Lead"),
		assert_contains(player.hand, search_card, "Thwackey should put the selected card into hand"),
	])


func test_csv8c_022_rillaboom_drum_beating_increases_next_turn_costs() -> String:
	var gsm := _make_gsm()
	_add_dummy_prizes(gsm.game_state)
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var rillaboom := _make_slot(_rillaboom_csv8c(), 0)
	var defender_cd := _pokemon("Defender", "", [{"name": "One Cost Attack", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}], [], "C", 300)
	defender_cd.retreat_cost = 0
	var defender := _make_slot(defender_cd, 1)
	player.active_pokemon = rillaboom
	opponent.active_pokemon = defender
	_attach_energy(rillaboom, 0, "G", 1)
	gsm.effect_processor.register_pokemon_card(rillaboom.get_card_data())

	var attacked := gsm.use_attack(0, 0)
	var colorless_mod := gsm.effect_processor.get_attack_colorless_cost_modifier(defender, defender_cd.attacks[0], gsm.game_state)
	var retreat_cost := gsm.effect_processor.get_effective_retreat_cost(defender, gsm.game_state)

	return run_checks([
		assert_true(attacked, "Rillaboom should use Drum Beating"),
		assert_eq(colorless_mod, 1, "Drum Beating should add one Colorless to defender attacks on the next turn"),
		assert_eq(retreat_cost, 1, "Drum Beating should add one Colorless to defender retreat on the next turn"),
	])


func test_csv8c_024_dipplin_friend_ring_uses_real_multiplier_damage() -> String:
	var gsm_zero := _make_gsm()
	var zero_player: PlayerState = gsm_zero.game_state.players[0]
	var zero_opponent: PlayerState = gsm_zero.game_state.players[1]
	var zero_dipplin := _make_slot(_dipplin_csv8c(), 0)
	zero_player.active_pokemon = zero_dipplin
	zero_opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	for i: int in 3:
		zero_opponent.bench.append(_make_slot(_pokemon("Opponent Bench %d" % i), 1))
	_attach_energy(zero_dipplin, 0, "G", 1)
	gsm_zero.effect_processor.register_pokemon_card(zero_dipplin.get_card_data())

	var zero_attack := gsm_zero.use_attack(0, 0)

	var gsm_two := _make_gsm()
	var two_player: PlayerState = gsm_two.game_state.players[0]
	var two_opponent: PlayerState = gsm_two.game_state.players[1]
	var two_dipplin := _make_slot(_dipplin_csv8c(), 0)
	two_player.active_pokemon = two_dipplin
	for i: int in 2:
		two_player.bench.append(_make_slot(_pokemon("Own Bench %d" % i), 0))
	two_opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	for i: int in 3:
		two_opponent.bench.append(_make_slot(_pokemon("Opponent Bench %d" % i), 1))
	_attach_energy(two_dipplin, 0, "G", 1)
	gsm_two.effect_processor.register_pokemon_card(two_dipplin.get_card_data())

	var two_attack := gsm_two.use_attack(0, 0)

	return run_checks([
		assert_true(gsm_zero.effect_processor.get_effect(zero_dipplin.get_card_data().effect_id) is AbilityFestivalLead, "Dipplin Festival Lead should register by effect_id"),
		assert_true(gsm_zero.effect_processor.has_attack_effect(zero_dipplin.get_card_data().effect_id), "Dipplin Friend Ring should register by effect_id"),
		assert_true(zero_attack, "Dipplin should be able to use Friend Ring with zero Benched Pokemon"),
		assert_eq(zero_opponent.active_pokemon.damage_counters, 0, "Friend Ring should deal 0 damage with no own Benched Pokemon despite the printed 20×"),
		assert_true(two_attack, "Dipplin should be able to use Friend Ring with two Benched Pokemon"),
		assert_eq(two_opponent.active_pokemon.damage_counters, 40, "Friend Ring should count only own Benched Pokemon and deal 2 × 20 damage"),
	])


func test_csv8c_024_dipplin_festival_lead_allows_second_attack() -> String:
	var gsm := _make_gsm()
	_add_dummy_prizes(gsm.game_state)
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var dipplin := _make_slot(_dipplin_csv8c(), 0)
	player.active_pokemon = dipplin
	player.bench.append(_make_slot(_pokemon("Bench A"), 0))
	player.bench.append(_make_slot(_pokemon("Bench B"), 0))
	opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	_attach_energy(dipplin, 0, "G", 1)
	gsm.game_state.stadium_card = CardInstance.create(_festival_grounds_csv8c(), 0)
	gsm.game_state.stadium_owner_index = 0
	gsm.effect_processor.register_pokemon_card(dipplin.get_card_data())

	var first_attack := gsm.use_attack(0, 0)
	var still_player_turn := gsm.game_state.current_player_index == 0 and gsm.game_state.phase == GameState.GamePhase.MAIN
	var second_attack := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(first_attack, "Dipplin should use its first Festival Lead attack"),
		assert_true(still_player_turn, "Festival Lead should return to MAIN for the second attack"),
		assert_true(second_attack, "Dipplin should be able to use the second attack"),
		assert_eq(opponent.active_pokemon.damage_counters, 80, "Two Friend Ring attacks with two Benched Pokemon should deal 80 total damage"),
		assert_eq(gsm.game_state.current_player_index, 1, "After the second Festival Lead attack, the turn should pass to the opponent"),
	])


func _klawf_csv6c() -> CardData:
	var cd := _pokemon(
		"Klawf CSV6C",
		"f986b356ae9703ac2d1667d1897cfdb6",
		[
			{"name": "Crisis Scissors", "cost": "CC", "damage": "30+", "text": "If this Pokemon is affected by a Special Condition, this attack does 160 more damage.", "is_vstar_power": false},
			{"name": "Boiling Press", "cost": "FF", "damage": "80", "text": "This Pokemon is now Burned.", "is_vstar_power": false},
		],
		[],
		"F",
		120
	)
	cd.set_code = "CSV6C"
	cd.card_index = "080"
	cd.is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	return cd


func _brute_bonnet_csv6c() -> CardData:
	var cd := _pokemon(
		"Brute Bonnet CSV6C",
		"a5438c6290fdef331fe1ba579b6f4928",
		[{"name": "Rampaging Hammer", "cost": "DDC", "damage": "120", "text": "During your next turn, this Pokemon can't attack.", "is_vstar_power": false}],
		[{"name": "Toxic Powder", "text": "If this Pokemon has Ancient Booster Energy Capsule attached, both Active Pokemon are now Poisoned."}],
		"D",
		120
	)
	cd.set_code = "CSV6C"
	cd.card_index = "095"
	cd.is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	return cd


func _radiant_sneasler_cs5ac() -> CardData:
	return _pokemon(
		"Radiant Hisuian Sneasler CS5aC",
		"146a354ca20b3943ab792aa29b070fda",
		[{"name": "Poison Jab", "cost": "DCC", "damage": "90", "text": "Your opponent's Active Pokemon is now Poisoned.", "is_vstar_power": false}],
		[{"name": "Poison Peak", "text": "Put 2 more damage counters on your opponent's Poisoned Active Pokemon during Pokemon Check."}],
		"D",
		130,
		"Basic",
		"Radiant"
	)


func _iron_valiant_csv6c() -> CardData:
	var cd := _pokemon(
		"Iron Valiant ex CSV6C",
		"b417ad06ad8e4aa783b35fe1f3f27010",
		[{"name": "Laser Blade", "cost": "PPC", "damage": "200", "text": "During your next turn, this Pokemon can't attack.", "is_vstar_power": false}],
		[{"name": "Tachyon Bits", "text": "When this Pokemon moves from the Bench to the Active Spot, place 2 damage counters on 1 of your opponent's Pokemon."}],
		"P",
		220,
		"Basic",
		"ex"
	)
	cd.set_code = "CSV6C"
	cd.card_index = "066"
	cd.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	return cd


func _oranguru_v_cs5bc() -> CardData:
	return _pokemon(
		"Oranguru V CS5bC",
		"c5783c83303269674231483fede75e99",
		[{"name": "Psychic", "cost": "CCC", "damage": "30+", "text": "This attack does 50 more damage for each Energy attached to your opponent's Active Pokemon.", "is_vstar_power": false}],
		[{"name": "Back Order", "text": "If this Pokemon is in the Active Spot, search your deck for up to 2 Pokemon Tool cards and put them into your hand."}],
		"C",
		210,
		"Basic",
		"V"
	)


func _hisuian_electrode_v_cs55c() -> CardData:
	return _pokemon(
		"Hisuian Electrode V CS5.5C",
		"f9a90aafccf9445be72a6ed15f66bcd6",
		[
			{"name": "Tantrum Blast", "cost": "", "damage": "100x", "text": "This attack does 100 damage for each Special Condition affecting this Pokemon.", "is_vstar_power": false},
			{"name": "Solar Shot", "cost": "GC", "damage": "120", "text": "Discard all Energy from this Pokemon.", "is_vstar_power": false},
		],
		[],
		"G",
		210,
		"Basic",
		"V"
	)


func test_klawf_deck_new_import_status_is_implemented() -> String:
	CardImplementationStatus.clear_cache()
	var processor := EffectProcessor.new()
	var klawf := _klawf_csv6c()
	var brute := _brute_bonnet_csv6c()
	var sneasler := _radiant_sneasler_cs5ac()
	var iron_valiant := _iron_valiant_csv6c()
	var oranguru := _oranguru_v_cs5bc()
	var electrode := _hisuian_electrode_v_cs55c()
	for card: CardData in [klawf, brute, sneasler, iron_valiant, oranguru, electrode]:
		processor.register_pokemon_card(card)
	var ancient_capsule := _trainer("Ancient Booster Energy Capsule", "Tool", "8da8631aa1827b122ec65b712939ad48")
	var glasses := _trainer("Supereffective Glasses", "Tool", "0ad0108e5ab1346d88f6ce11b75028d7")
	var jungle := _trainer("Perilous Jungle", "Stadium", "16a6fb86a8ebd1cffc6f171250057d5c")

	return run_checks([
		assert_true(processor.has_attack_effect(klawf.effect_id), "Klawf attacks should register by imported effect_id"),
		assert_not_null(processor.get_effect(brute.effect_id), "Brute Bonnet Toxic Powder should register"),
		assert_not_null(processor.get_effect(sneasler.effect_id), "Radiant Hisuian Sneasler Poison Peak should register"),
		assert_not_null(processor.get_effect(iron_valiant.effect_id), "Iron Valiant ex Tachyon Bits should register"),
		assert_not_null(processor.get_effect(oranguru.effect_id), "Oranguru V Back Order should register"),
		assert_true(processor.has_attack_effect(electrode.effect_id), "Hisuian Electrode V attacks should register"),
		assert_not_null(processor.get_effect(ancient_capsule.effect_id), "Ancient Booster Energy Capsule should register"),
		assert_not_null(processor.get_effect(glasses.effect_id), "Supereffective Glasses should register"),
		assert_not_null(processor.get_effect(jungle.effect_id), "Perilous Jungle should register"),
		assert_false(CardImplementationStatus.is_unimplemented(klawf), "Klawf should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(brute), "Brute Bonnet should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(sneasler), "Radiant Hisuian Sneasler should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(iron_valiant), "Iron Valiant ex should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(oranguru), "Oranguru V should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(electrode), "Hisuian Electrode V should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(ancient_capsule), "Ancient Booster Energy Capsule should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(glasses), "Supereffective Glasses should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(jungle), "Perilous Jungle should not show the unimplemented badge"),
	])


func test_klawf_and_poison_package_damage_rules() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var klawf := _make_slot(_klawf_csv6c(), 0)
	var defender_cd := _pokemon("Neutral Defender", "", [], [], "C", 300)
	player.active_pokemon = klawf
	opponent.active_pokemon = _make_slot(defender_cd, 1)
	_attach_energy(klawf, 0, "F", 2)
	klawf.set_status("poisoned", true)
	gsm.effect_processor.register_pokemon_card(klawf.get_card_data())

	var attacked := gsm.use_attack(0, 0)

	var poison_state := _make_state()
	var sneasler := _make_slot(_radiant_sneasler_cs5ac(), 0)
	poison_state.players[0].bench.append(sneasler)
	poison_state.players[1].active_pokemon = _make_slot(_pokemon("Poison Target", "", [], [], "C", 300), 1)
	poison_state.players[1].active_pokemon.set_status("poisoned", true)
	poison_state.stadium_card = CardInstance.create(_trainer("Perilous Jungle", "Stadium", "16a6fb86a8ebd1cffc6f171250057d5c"), 0)
	var poison_processor := EffectProcessor.new()
	poison_processor.register_pokemon_card(sneasler.get_card_data())
	poison_processor.process_pokemon_check(poison_state)

	return run_checks([
		assert_true(attacked, "Klawf should attack while poisoned"),
		assert_eq(opponent.active_pokemon.damage_counters, 190, "Crisis Scissors should deal 30 plus 160 while Klawf has a Special Condition"),
		assert_eq(poison_state.players[1].active_pokemon.damage_counters, 50, "Radiant Sneasler plus Perilous Jungle should make Poison place 5 damage counters on non-Darkness Active Pokemon"),
	])


func test_perilous_jungle_poison_boundaries() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var non_dark_active := _make_slot(_pokemon("Non-Dark Active", "", [], [], "C", 300), 0)
	var dark_active := _make_slot(_pokemon("Dark Active", "", [], [], "D", 300), 1)
	var poisoned_bench := _make_slot(_pokemon("Poisoned Bench", "", [], [], "C", 300), 0)
	state.players[0].active_pokemon = non_dark_active
	state.players[0].bench.append(poisoned_bench)
	state.players[1].active_pokemon = dark_active
	state.stadium_card = CardInstance.create(_trainer("Perilous Jungle", "Stadium", "16a6fb86a8ebd1cffc6f171250057d5c"), 0)
	non_dark_active.set_status("poisoned", true)
	dark_active.set_status("poisoned", true)
	poisoned_bench.set_status("poisoned", true)

	processor.process_pokemon_check(state)

	return run_checks([
		assert_eq(non_dark_active.damage_counters, 30, "Perilous Jungle should add 20 poison damage to non-Darkness Active Pokemon"),
		assert_eq(dark_active.damage_counters, 10, "Perilous Jungle should not add poison damage to Darkness Active Pokemon"),
		assert_eq(poisoned_bench.damage_counters, 0, "Perilous Jungle should not damage Benched Pokemon during Pokemon Check"),
	])


func test_ancient_capsule_brute_bonnet_and_supereffective_glasses() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var brute := _make_slot(_brute_bonnet_csv6c(), 0)
	var opponent_active := _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	player.active_pokemon = brute
	opponent.active_pokemon = opponent_active
	var capsule := CardInstance.create(_trainer("Ancient Booster Energy Capsule", "Tool", "8da8631aa1827b122ec65b712939ad48"), 0)
	player.hand.append(capsule)
	brute.set_status("burned", true)
	var attached := gsm.attach_tool(0, capsule, brute)
	gsm.effect_processor.register_pokemon_card(brute.get_card_data())
	var can_use_toxic_powder := gsm.effect_processor.can_use_ability(brute, gsm.game_state, 0)
	var used_toxic_powder := gsm.use_ability(0, brute, 0, [])
	var hp_bonus := gsm.effect_processor.get_hp_modifier(brute, gsm.game_state)

	var suppressed_gsm := _make_gsm()
	var suppressed_player: PlayerState = suppressed_gsm.game_state.players[0]
	var suppressed_opponent: PlayerState = suppressed_gsm.game_state.players[1]
	var suppressed_brute := _make_slot(_brute_bonnet_csv6c(), 0)
	suppressed_player.active_pokemon = suppressed_brute
	suppressed_opponent.active_pokemon = _make_slot(_pokemon("Suppression Target", "", [], [], "C", 300), 1)
	suppressed_brute.attached_tool = CardInstance.create(_trainer("Ancient Booster Energy Capsule", "Tool", "8da8631aa1827b122ec65b712939ad48"), 0)
	suppressed_gsm.game_state.stadium_card = CardInstance.create(_trainer("Jamming Tower", "Stadium", "4e16157bfa88a41e823d058a732df8e0"), 0)
	suppressed_gsm.effect_processor.register_pokemon_card(suppressed_brute.get_card_data())
	var toxic_powder_suppressed := suppressed_gsm.effect_processor.can_use_ability(suppressed_brute, suppressed_gsm.game_state, 0)

	var damage_gsm := _make_gsm()
	var damage_player: PlayerState = damage_gsm.game_state.players[0]
	var damage_opp: PlayerState = damage_gsm.game_state.players[1]
	var attacker_cd := _pokemon("Fighting Attacker", "", [{"name": "Hit", "cost": "F", "damage": "100", "text": "", "is_vstar_power": false}], [], "F", 100)
	var attacker := _make_slot(attacker_cd, 0)
	var weak_defender_cd := _pokemon("Weak Defender", "", [], [], "C", 300)
	weak_defender_cd.weakness_energy = "F"
	weak_defender_cd.weakness_value = "x2"
	damage_player.active_pokemon = attacker
	damage_opp.active_pokemon = _make_slot(weak_defender_cd, 1)
	attacker.attached_tool = CardInstance.create(_trainer("Supereffective Glasses", "Tool", "0ad0108e5ab1346d88f6ce11b75028d7"), 0)
	var preview_damage := damage_gsm.get_attack_preview_damage(0, 0)

	return run_checks([
		assert_true(attached, "Ancient Booster Energy Capsule should attach"),
		assert_false(brute.status_conditions.get("burned", false), "Ancient Booster Energy Capsule should clear existing Special Conditions from Ancient Pokemon"),
		assert_eq(hp_bonus, 60, "Ancient Booster Energy Capsule should give Ancient Pokemon +60 HP"),
		assert_true(can_use_toxic_powder, "Brute Bonnet should be able to use Toxic Powder with Ancient Booster attached"),
		assert_true(used_toxic_powder, "Brute Bonnet Toxic Powder should resolve"),
		assert_false(toxic_powder_suppressed, "Jamming Tower should suppress Ancient Booster and disable Toxic Powder"),
		assert_false(brute.status_conditions.get("poisoned", false), "Ancient Booster should prevent Brute Bonnet from poisoning itself"),
		assert_true(opponent_active.status_conditions.get("poisoned", false), "Toxic Powder should poison the opposing Active Pokemon"),
		assert_eq(preview_damage, 300, "Supereffective Glasses should make weakness x3"),
	])


func test_ancient_capsule_status_prevention_boundaries() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var ancient := _make_slot(_brute_bonnet_csv6c(), 0)
	var non_ancient := _make_slot(_pokemon("Non-Ancient Holder", "", [], [], "D", 120), 0)
	state.players[0].active_pokemon = ancient
	state.players[0].bench.append(non_ancient)
	state.players[1].active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	ancient.attached_tool = CardInstance.create(_trainer("Ancient Booster Energy Capsule", "Tool", "8da8631aa1827b122ec65b712939ad48"), 0)
	non_ancient.attached_tool = CardInstance.create(_trainer("Ancient Booster Energy Capsule", "Tool", "8da8631aa1827b122ec65b712939ad48"), 0)
	ancient.set_status("burned", true)
	non_ancient.set_status("burned", true)

	EffectApplyStatus.new("confused").execute_attack(null, ancient, 0, state)
	AttackSelfSleep.new().execute_attack(ancient, null, 0, state)
	state.players[0].deck.append(CardInstance.create(_energy("Dark Energy", "D"), 0))
	AttackAttachBasicEnergyFromDeckToSelfAndStatus.new("D", 1, "poisoned").execute_attack(ancient, null, 0, state)
	EffectApplyStatus.new("poisoned").execute_attack(null, non_ancient, 0, state)

	return run_checks([
		assert_false(ancient.status_conditions.get("burned", false), "Ancient Booster should clear existing Special Conditions when preventing a new one"),
		assert_false(ancient.status_conditions.get("confused", false), "Ancient Booster should prevent Confusion from attack effects"),
		assert_false(ancient.status_conditions.get("asleep", false), "Ancient Booster should prevent self Sleep effects"),
		assert_false(ancient.status_conditions.get("poisoned", false), "Ancient Booster should prevent self Poison effects after attack setup"),
		assert_eq(processor.get_hp_modifier(ancient, state), 60, "Ancient Booster should give Ancient Pokemon +60 HP"),
		assert_eq(processor.get_hp_modifier(non_ancient, state), 0, "Ancient Booster should not give non-Ancient Pokemon +60 HP"),
		assert_true(non_ancient.status_conditions.get("burned", false), "Ancient Booster should not clear statuses from non-Ancient Pokemon"),
		assert_true(non_ancient.status_conditions.get("poisoned", false), "Ancient Booster should not prevent statuses on non-Ancient Pokemon"),
	])


func test_ancient_capsule_and_supereffective_glasses_jamming_tower_boundaries() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var ancient := _make_slot(_brute_bonnet_csv6c(), 0)
	state.players[0].active_pokemon = ancient
	ancient.attached_tool = CardInstance.create(_trainer("Ancient Booster Energy Capsule", "Tool", "8da8631aa1827b122ec65b712939ad48"), 0)
	state.stadium_card = CardInstance.create(_trainer("Jamming Tower", "Stadium", "4e16157bfa88a41e823d058a732df8e0"), 0)
	var protects_without_processor := EffectToolAncientBoosterEnergyCapsule.protects(ancient, state)
	state.shared_turn_flags["_draw_effect_processor"] = processor
	EffectApplyStatus.new("poisoned").execute_attack(null, ancient, 0, state)

	var weak_gsm := _make_gsm()
	var weak_player: PlayerState = weak_gsm.game_state.players[0]
	var weak_opp: PlayerState = weak_gsm.game_state.players[1]
	var attacker_cd := _pokemon("Fighting Attacker", "", [{"name": "Hit", "cost": "F", "damage": "100", "text": "", "is_vstar_power": false}], [], "F", 100)
	var weak_attacker := _make_slot(attacker_cd, 0)
	var weak_defender_cd := _pokemon("Weak Defender", "", [], [], "C", 300)
	weak_defender_cd.weakness_energy = "F"
	weak_defender_cd.weakness_value = "x2"
	weak_player.active_pokemon = weak_attacker
	weak_opp.active_pokemon = _make_slot(weak_defender_cd, 1)
	weak_attacker.attached_tool = CardInstance.create(_trainer("Supereffective Glasses", "Tool", "0ad0108e5ab1346d88f6ce11b75028d7"), 0)
	weak_gsm.game_state.stadium_card = CardInstance.create(_trainer("Jamming Tower", "Stadium", "4e16157bfa88a41e823d058a732df8e0"), 0)
	var jamming_damage := weak_gsm.get_attack_preview_damage(0, 0)

	var neutral_gsm := _make_gsm()
	var neutral_player: PlayerState = neutral_gsm.game_state.players[0]
	var neutral_opp: PlayerState = neutral_gsm.game_state.players[1]
	var neutral_attacker := _make_slot(attacker_cd, 0)
	var neutral_defender_cd := _pokemon("Neutral Defender", "", [], [], "C", 300)
	neutral_defender_cd.weakness_energy = "L"
	neutral_defender_cd.weakness_value = "x2"
	neutral_player.active_pokemon = neutral_attacker
	neutral_opp.active_pokemon = _make_slot(neutral_defender_cd, 1)
	neutral_attacker.attached_tool = CardInstance.create(_trainer("Supereffective Glasses", "Tool", "0ad0108e5ab1346d88f6ce11b75028d7"), 0)
	var neutral_damage := neutral_gsm.get_attack_preview_damage(0, 0)

	return run_checks([
		assert_false(protects_without_processor, "Jamming Tower should suppress Ancient Booster even without an EffectProcessor in shared flags"),
		assert_true(ancient.status_conditions.get("poisoned", false), "Jamming Tower should make Ancient Booster stop preventing Special Conditions"),
		assert_eq(processor.get_hp_modifier(ancient, state), 0, "Jamming Tower should suppress Ancient Booster HP bonus"),
		assert_eq(jamming_damage, 200, "Jamming Tower should suppress Supereffective Glasses and leave normal x2 Weakness"),
		assert_eq(neutral_damage, 100, "Supereffective Glasses should not boost damage when the defender is not weak to the attacker type"),
	])


func test_iron_valiant_oranguru_and_electrode_effects() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var old_active := _make_slot(_pokemon("Pivot", "", [{"name": "Tackle", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}], [], "C", 100), 0)
	var iron_valiant := _make_slot(_iron_valiant_csv6c(), 0)
	var opp_bench := _make_slot(_pokemon("Opponent Bench", "", [], [], "C", 100), 1)
	player.active_pokemon = old_active
	player.bench.append(iron_valiant)
	opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	opponent.bench.append(opp_bench)
	var switch_cart := CardInstance.create(_trainer("Switch Cart", "Item", "8342fe3eeec6f897f3271be1aa26a412"), 0)
	player.hand.append(switch_cart)
	gsm.effect_processor.register_pokemon_card(iron_valiant.get_card_data())
	var switched := gsm.play_trainer(0, switch_cart, [{"switch_target": [iron_valiant]}])
	var tachyon_can_use := gsm.effect_processor.can_use_ability(iron_valiant, gsm.game_state, 0)
	var tachyon_used := gsm.use_ability(0, iron_valiant, 0, [{"tachyon_bits_target": [opp_bench]}])

	var oranguru_gsm := _make_gsm()
	var oranguru_player: PlayerState = oranguru_gsm.game_state.players[0]
	var oranguru_opp: PlayerState = oranguru_gsm.game_state.players[1]
	var oranguru := _make_slot(_oranguru_v_cs5bc(), 0)
	oranguru_player.active_pokemon = oranguru
	oranguru_opp.active_pokemon = _make_slot(_pokemon("Energy Defender", "", [], [], "C", 300), 1)
	_attach_energy(oranguru_opp.active_pokemon, 1, "C", 2)
	var tool_a := CardInstance.create(_trainer("Tool A", "Tool", "tool-a"), 0)
	var tool_b := CardInstance.create(_trainer("Tool B", "Tool", "tool-b"), 0)
	var item := CardInstance.create(_trainer("Item", "Item", "item"), 0)
	oranguru_player.deck.append(tool_a)
	oranguru_player.deck.append(item)
	oranguru_player.deck.append(tool_b)
	_attach_energy(oranguru, 0, "C", 3)
	oranguru_gsm.effect_processor.register_pokemon_card(oranguru.get_card_data())
	var oranguru_effect := oranguru_gsm.effect_processor.get_effect(oranguru.get_card_data().effect_id)
	var search_steps := oranguru_effect.get_interaction_steps(oranguru.get_top_card(), oranguru_gsm.game_state)
	oranguru_gsm.use_ability(0, oranguru, 0, [{"search_cards": [tool_a, tool_b]}])
	var oranguru_attack := oranguru_gsm.use_attack(0, 0)

	var electrode_gsm := _make_gsm()
	var electrode_player: PlayerState = electrode_gsm.game_state.players[0]
	var electrode_opp: PlayerState = electrode_gsm.game_state.players[1]
	var electrode := _make_slot(_hisuian_electrode_v_cs55c(), 0)
	electrode_player.active_pokemon = electrode
	electrode_opp.active_pokemon = _make_slot(_pokemon("Electrode Defender", "", [], [], "C", 400), 1)
	electrode.set_status("poisoned", true)
	electrode.set_status("burned", true)
	_attach_energy(electrode, 0, "G", 1)
	_attach_energy(electrode, 0, "C", 1)
	electrode_gsm.effect_processor.register_pokemon_card(electrode.get_card_data())
	var electrode_preview := electrode_gsm.get_attack_preview_damage(0, 0)
	var electrode_attack := electrode_gsm.use_attack(0, 1)

	return run_checks([
		assert_true(switched, "Switch Cart should switch Iron Valiant ex into the Active Spot"),
		assert_true(tachyon_can_use, "Iron Valiant ex should be able to use Tachyon Bits after moving from Bench to Active"),
		assert_true(tachyon_used, "Tachyon Bits should resolve"),
		assert_eq(opp_bench.damage_counters, 20, "Tachyon Bits should place 2 damage counters on the chosen opponent Pokemon"),
		assert_eq(str(search_steps[0].get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Oranguru V search should expose the full own deck for UI inspection"),
		assert_eq(int(search_steps[0].get("selectable_count", 0)), 2, "Oranguru V should only allow Pokemon Tool cards to be selected"),
		assert_true(tool_a in oranguru_player.hand and tool_b in oranguru_player.hand, "Oranguru V should put selected Tool cards into hand"),
		assert_true(oranguru_attack, "Oranguru V should be able to attack"),
		assert_eq(oranguru_opp.active_pokemon.damage_counters, 130, "Oranguru V Psychic should add 50 for each defender Energy"),
		assert_eq(electrode_preview, 200, "Hisuian Electrode V Tantrum Blast should count two Special Conditions"),
		assert_true(electrode_attack, "Hisuian Electrode V should use Solar Shot"),
		assert_eq(electrode.attached_energy.size(), 0, "Solar Shot should discard all attached Energy"),
	])


func _great_tusk_csv7c() -> CardData:
	var cd := _pokemon(
		"Great Tusk CSV7C",
		"23706c5baababfabc76355e59709f4ec",
		[
			{"name": "Land Collapse", "cost": "", "damage": "", "text": "Discard the top card of your opponent's deck. If you played an Ancient Supporter this turn, discard 3 more.", "is_vstar_power": false},
			{"name": "Giant Tusks", "cost": "FF", "damage": "160", "text": "", "is_vstar_power": false},
		],
		[],
		"F",
		140
	)
	cd.is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	return cd


func _mawile_cs6bc() -> CardData:
	return _pokemon(
		"Mawile CS6bC",
		"26afb8b359bdeb40834a9dafbba4218b",
		[
			{"name": "Sweet Trap", "cost": "", "damage": "", "text": "During your opponent's next turn, the Defending Pokemon can't retreat. During your next turn, it takes +90 damage from attacks.", "is_vstar_power": false},
			{"name": "Bite", "cost": "P", "damage": "90", "text": "", "is_vstar_power": false},
		],
		[],
		"P",
		100
	)


func _cached_card_from_dict(uid: String, name: String, name_en: String, card_type: String, effect_id: String, extra: Dictionary = {}) -> CardData:
	var parts := uid.split("_")
	var payload: Dictionary = {
		"name": name,
		"name_en": name_en,
		"card_type": card_type,
		"effect_id": effect_id,
		"set_code": parts[0] if parts.size() > 0 else "",
		"card_index": parts[1] if parts.size() > 1 else "",
		"description": extra.get("description", ""),
		"is_tags": [],
		"attacks": [],
		"abilities": [],
		"stage": "",
		"hp": 0,
		"retreat_cost": 0,
	}
	for key: Variant in extra.keys():
		payload[key] = extra[key]
	return CardData.from_dict(payload)


func _great_tusk_csv7c_cached() -> CardData:
	return _cached_card_from_dict(
		"CSV7C_131",
		"雄伟牙",
		"Great Tusk",
		"Pokemon",
		"23706c5baababfabc76355e59709f4ec",
		{
			"description": "将对手牌库上方1张卡牌放于弃牌区。在这个回合，如果从手牌使出了「古代」支援者的话，则额外将牌库上方3张卡牌放于弃牌区。",
			"energy_type": "F",
			"stage": "Basic",
			"hp": 140,
			"retreat_cost": 3,
			"attacks": [
				{"name": "地基崩溃", "cost": "CC", "damage": "", "text": "将对手牌库上方1张卡牌放于弃牌区。在这个回合，如果从手牌使出了「古代」支援者的话，则额外将牌库上方3张卡牌放于弃牌区。", "is_vstar_power": false},
				{"name": "巨大之牙", "cost": "FFCC", "damage": "160", "text": "", "is_vstar_power": false},
			],
		}
	)


func _explorers_guidance_csv7c_cached() -> CardData:
	return _cached_card_from_dict(
		"CSV7C_195",
		"探险家的向导",
		"Explorer's Guidance",
		"Supporter",
		"0f4743343a173fdba38290050453a8c8",
		{"description": "查看自己牌库上方6张卡牌，选择其中2张卡牌，加入手牌。将剩余的卡牌放于弃牌区。"}
	)


func _ancient_booster_csv6c_cached() -> CardData:
	return _cached_card_from_dict(
		"CSV6C_118",
		"驱劲能量 古代",
		"Ancient Booster Energy Capsule",
		"Tool",
		"8da8631aa1827b122ec65b712939ad48",
		{"description": "身上放有这张卡牌的「古代」宝可梦，最大HP「+60」，那只宝可梦，不会陷入特殊状态，已经处于的特殊状态，也全部恢复。"}
	)


func test_great_tusk_deck_missing_import_status_is_implemented() -> String:
	CardImplementationStatus.clear_cache()
	var processor := EffectProcessor.new()
	var great_tusk := _great_tusk_csv7c()
	var mawile := _mawile_cs6bc()
	processor.register_pokemon_card(great_tusk)
	processor.register_pokemon_card(mawile)
	var explorers := _trainer("Explorer's Guidance", "Supporter", "0f4743343a173fdba38290050453a8c8")
	explorers.description = "Look at the top 6 cards of your deck, put 2 into your hand, and discard the rest."
	var survival_brace := _trainer("Survival Brace", "Tool", "1201698f44df09377c26288931d18b36")
	survival_brace.description = "If the attached Pokemon at full HP would be Knocked Out by attack damage, it remains with 10 HP."
	var wasteland := _trainer("Calamitous Wasteland", "Stadium", "b599512657c5c23024fde7875db3ba2d")
	wasteland.description = "Basic non-Fighting Pokemon have 1 more retreat cost."

	return run_checks([
		assert_true(processor.has_attack_effect(great_tusk.effect_id), "Great Tusk should register Land Collapse"),
		assert_true(processor.has_attack_effect(mawile.effect_id), "Mawile should register Sweet Trap"),
		assert_not_null(processor.get_effect(explorers.effect_id), "Explorer's Guidance should register"),
		assert_not_null(processor.get_effect(survival_brace.effect_id), "Survival Brace should register"),
		assert_not_null(processor.get_effect(wasteland.effect_id), "Calamitous Wasteland should register"),
		assert_false(CardImplementationStatus.is_unimplemented(great_tusk), "Great Tusk should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(mawile), "Mawile should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(explorers), "Explorer's Guidance should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(survival_brace), "Survival Brace should not show the unimplemented badge"),
		assert_false(CardImplementationStatus.is_unimplemented(wasteland), "Calamitous Wasteland should not show the unimplemented badge"),
	])


func test_great_tusk_deck_cached_ancient_tags_drive_synergy() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var great_tusk_cd := _great_tusk_csv7c_cached()
	var explorers_cd := _explorers_guidance_csv7c_cached()
	var capsule_cd := _ancient_booster_csv6c_cached()
	var great_tusk := _make_slot(great_tusk_cd, 0)
	player.active_pokemon = great_tusk
	opponent.active_pokemon = _make_slot(_pokemon("Defender", "", [], [], "C", 100), 1)
	_attach_energy(great_tusk, 0, "C", 2)
	for idx: int in 7:
		opponent.deck.append(CardInstance.create(_trainer("Opponent Deck %d" % idx, "Item", ""), 1))
	var supporter := CardInstance.create(explorers_cd, 0)
	player.hand.append(supporter)
	var looked: Array[CardInstance] = []
	for idx: int in 6:
		var card := CardInstance.create(_trainer("Own Deck %d" % idx, "Item", ""), 0)
		looked.append(card)
		player.deck.append(card)
	var supporter_played := gsm.play_trainer(0, supporter, [{"explorers_guidance_cards": [looked[0], looked[1]]}])
	gsm.effect_processor.register_pokemon_card(great_tusk_cd)
	var attacked := gsm.use_attack(0, 0)

	var capsule := CardInstance.create(capsule_cd, 0)
	great_tusk.attached_tool = capsule
	var hp_bonus := gsm.effect_processor.get_hp_modifier(great_tusk, gsm.game_state)

	return run_checks([
		assert_true(great_tusk_cd.is_ancient_pokemon(), "Imported Great Tusk should receive the Ancient tag from overrides"),
		assert_true(explorers_cd.has_tag(CardData.ANCIENT_TAG), "Imported Explorer's Guidance should count as an Ancient Supporter"),
		assert_true(capsule_cd.has_tag(CardData.ANCIENT_TAG), "Imported Ancient Booster Energy Capsule should count as an Ancient card"),
		assert_true(supporter_played, "Explorer's Guidance should play from imported cached metadata"),
		assert_true(attacked, "Great Tusk should be able to use Land Collapse with two Colorless energy"),
		assert_eq(opponent.discard_pile.size(), 4, "Land Collapse should mill 4 after an imported Ancient Supporter"),
		assert_eq(hp_bonus, 60, "Ancient Booster Energy Capsule should apply to imported Great Tusk"),
	])


func test_explorers_guidance_picks_two_and_discards_the_rest() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var supporter := CardInstance.create(_trainer("Explorer's Guidance", "Supporter", "0f4743343a173fdba38290050453a8c8"), 0)
	player.hand.append(supporter)
	var top_cards: Array[CardInstance] = []
	for idx: int in 7:
		var card := CardInstance.create(_trainer("Deck Card %d" % idx, "Item", "deck-%d" % idx), 0)
		top_cards.append(card)
		player.deck.append(card)

	var played := gsm.play_trainer(0, supporter, [{"explorers_guidance_cards": [top_cards[1], top_cards[4]]}])

	return run_checks([
		assert_true(played, "Explorer's Guidance should play"),
		assert_true(top_cards[1] in player.hand and top_cards[4] in player.hand, "Selected cards should move to hand"),
		assert_true(top_cards[0] in player.discard_pile and top_cards[2] in player.discard_pile and top_cards[3] in player.discard_pile and top_cards[5] in player.discard_pile, "Unselected looked cards should be discarded"),
		assert_true(top_cards[6] in player.deck, "Cards below the top 6 should remain in deck"),
	])


func test_great_tusk_land_collapse_mills_extra_after_ancient_supporter() -> String:
	var normal_gsm := _make_gsm()
	var normal_player: PlayerState = normal_gsm.game_state.players[0]
	var normal_opp: PlayerState = normal_gsm.game_state.players[1]
	var normal_great := _make_slot(_great_tusk_csv7c(), 0)
	normal_player.active_pokemon = normal_great
	normal_opp.active_pokemon = _make_slot(_pokemon("Defender", "", [], [], "C", 100), 1)
	for idx: int in 6:
		normal_opp.deck.append(CardInstance.create(_trainer("Normal Opp Deck %d" % idx, "Item", ""), 1))
	normal_gsm.effect_processor.register_pokemon_card(normal_great.get_card_data())
	var normal_attack := normal_gsm.use_attack(0, 0)

	var ancient_gsm := _make_gsm()
	var ancient_player: PlayerState = ancient_gsm.game_state.players[0]
	var ancient_opp: PlayerState = ancient_gsm.game_state.players[1]
	var ancient_great := _make_slot(_great_tusk_csv7c(), 0)
	ancient_player.active_pokemon = ancient_great
	ancient_opp.active_pokemon = _make_slot(_pokemon("Defender", "", [], [], "C", 100), 1)
	for idx: int in 7:
		ancient_opp.deck.append(CardInstance.create(_trainer("Ancient Opp Deck %d" % idx, "Item", ""), 1))
	var ancient_supporter_cd := _trainer("Ancient Supporter", "Supporter", "")
	ancient_supporter_cd.is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	var ancient_supporter := CardInstance.create(ancient_supporter_cd, 0)
	ancient_player.hand.append(ancient_supporter)
	var supporter_played := ancient_gsm.play_trainer(0, ancient_supporter, [])
	ancient_gsm.effect_processor.register_pokemon_card(ancient_great.get_card_data())
	var ancient_attack := ancient_gsm.use_attack(0, 0)

	return run_checks([
		assert_true(normal_attack, "Great Tusk should attack without an Ancient Supporter"),
		assert_eq(normal_opp.discard_pile.size(), 1, "Land Collapse should mill 1 by default"),
		assert_true(supporter_played, "Ancient Supporter should play and set the turn flag"),
		assert_true(ancient_attack, "Great Tusk should attack after an Ancient Supporter"),
		assert_eq(ancient_opp.discard_pile.size(), 4, "Land Collapse should mill 4 after an Ancient Supporter"),
	])


func test_mawile_sweet_trap_locks_retreat_and_adds_next_own_turn_damage() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var mawile := _make_slot(_mawile_cs6bc(), 0)
	var defender := _make_slot(_pokemon("Sweet Trap Target", "", [], [], "C", 180), 1)
	player.active_pokemon = mawile
	opponent.active_pokemon = defender
	opponent.bench.append(_make_slot(_pokemon("Retreat Bench", "", [], [], "C", 100), 1))
	opponent.deck.append(CardInstance.create(_trainer("Draw Card", "Item", ""), 1))
	gsm.effect_processor.register_pokemon_card(mawile.get_card_data())

	var attacked := gsm.use_attack(0, 0)
	var can_retreat_on_next_opponent_turn := gsm.rule_validator.can_retreat(gsm.game_state, 1, gsm.effect_processor)
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var defender_modifier := gsm.effect_processor.get_defender_modifier(defender, gsm.game_state, mawile)

	return run_checks([
		assert_true(attacked, "Mawile should use Sweet Trap"),
		assert_false(can_retreat_on_next_opponent_turn, "Sweet Trap should prevent retreat during the next opponent turn"),
		assert_eq(defender_modifier, 90, "Sweet Trap should add +90 attack damage on Mawile player's next turn"),
	])


func test_mawile_sweet_trap_clears_when_defender_leaves_active() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var mawile := _make_slot(_mawile_cs6bc(), 0)
	var defender := _make_slot(_pokemon("Sweet Trap Target", "", [], [], "C", 180), 1)
	var replacement := _make_slot(_pokemon("Switch Target", "", [], [], "C", 100), 1)
	player.active_pokemon = mawile
	opponent.active_pokemon = defender
	opponent.bench.append(replacement)
	opponent.deck.append(CardInstance.create(_trainer("Draw Card", "Item", ""), 1))
	gsm.effect_processor.register_pokemon_card(mawile.get_card_data())
	var attacked := gsm.use_attack(0, 0)
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var switch_card := CardInstance.create(_trainer("Switch", "Item", "7c0b20e121c9d0e0d2d8a43524f7494e"), 1)
	opponent.hand.append(switch_card)
	var switched := gsm.play_trainer(1, switch_card, [{"self_switch_target": [replacement]}])
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var defender_modifier := gsm.effect_processor.get_defender_modifier(defender, gsm.game_state, mawile)

	return run_checks([
		assert_true(attacked, "Mawile should use Sweet Trap"),
		assert_true(switched, "Switch should move the Sweet Trap target out of the Active Spot"),
		assert_eq(defender_modifier, 0, "Sweet Trap damage bonus should clear when the affected Pokemon leaves the Active Spot"),
	])


func test_survival_brace_and_calamitous_wasteland_rules() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var attacker_cd := _pokemon("Heavy Attacker", "", [{"name": "Heavy Hit", "cost": "", "damage": "200", "text": "", "is_vstar_power": false}], [], "F", 100)
	var attacker := _make_slot(attacker_cd, 0)
	var defender := _make_slot(_pokemon("Brace Holder", "", [], [], "C", 100), 1)
	var survival := CardInstance.create(_trainer("Survival Brace", "Tool", "1201698f44df09377c26288931d18b36"), 1)
	defender.attached_tool = survival
	player.active_pokemon = attacker
	opponent.active_pokemon = defender
	opponent.deck.append(CardInstance.create(_trainer("Draw Card", "Item", ""), 1))
	var attacked := gsm.use_attack(0, 0)

	var state := _make_state()
	var processor := EffectProcessor.new()
	var colorless_basic := _make_slot(_pokemon("Colorless Basic", "", [], [], "C", 100), 0)
	var fighting_basic := _make_slot(_pokemon("Fighting Basic", "", [], [], "F", 100), 0)
	state.stadium_card = CardInstance.create(_trainer("Calamitous Wasteland", "Stadium", "b599512657c5c23024fde7875db3ba2d"), 0)
	var colorless_modifier := processor.get_retreat_cost_modifier(colorless_basic, state)
	var fighting_modifier := processor.get_retreat_cost_modifier(fighting_basic, state)

	return run_checks([
		assert_true(attacked, "Attack should resolve against Survival Brace"),
		assert_eq(defender.damage_counters, 90, "Survival Brace should leave the full-HP holder at 10 remaining HP"),
		assert_eq(defender.attached_tool, null, "Survival Brace should discard itself after preventing the Knock Out"),
		assert_true(survival in opponent.discard_pile, "Survival Brace should move to its owner's discard pile"),
		assert_eq(opponent.active_pokemon, defender, "Survival Brace should keep the Pokemon in play"),
		assert_eq(colorless_modifier, 1, "Calamitous Wasteland should increase Basic non-Fighting retreat cost"),
		assert_eq(fighting_modifier, 0, "Calamitous Wasteland should not affect Basic Fighting Pokemon"),
	])
