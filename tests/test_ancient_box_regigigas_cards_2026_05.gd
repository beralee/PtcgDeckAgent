class_name TestAncientBoxRegigigasCards202605
extends TestBase

const CardImplementationStatusScript := preload("res://scripts/engine/CardImplementationStatus.gd")


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		var result := false
		if not _results.is_empty():
			result = _results.pop_front()
		coin_flipped.emit(result)
		return result


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


func _make_gsm(flipper: CoinFlipper = null) -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	if flipper != null:
		gsm.coin_flipper = flipper
		gsm.effect_processor = EffectProcessor.new(flipper)
		gsm.effect_processor.bind_game_state_machine(gsm)
	return gsm


func _add_dummy_prizes(state: GameState) -> void:
	for pi: int in state.players.size():
		for i: int in 6:
			state.players[pi].prizes.append(CardInstance.create(_trainer("Prize %d-%d" % [pi, i], "Item", ""), pi))


func _attack(name: String, cost: String = "", damage: String = "", text: String = "") -> Dictionary:
	return {"name": name, "cost": cost, "damage": damage, "text": text, "is_vstar_power": false}


func _pokemon(
	name: String,
	effect_id: String = "",
	attacks: Array[Dictionary] = [],
	abilities: Array[Dictionary] = [],
	energy_type: String = "C",
	hp: int = 300,
	stage: String = "Basic",
	mechanic: String = "",
	name_en: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name_en if name_en != "" else name
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


func _cached_card(uid: String, name: String, name_en: String, card_type: String, extra: Dictionary = {}) -> CardData:
	var parts := uid.split("_", false, 1)
	var payload := {
		"name": name,
		"name_en": name_en,
		"card_type": card_type,
		"set_code": parts[0] if parts.size() > 0 else "",
		"card_index": parts[1] if parts.size() > 1 else "",
		"effect_id": extra.get("effect_id", ""),
		"is_tags": extra.get("is_tags", []),
		"attacks": extra.get("attacks", []),
		"abilities": extra.get("abilities", []),
		"stage": extra.get("stage", ""),
		"hp": extra.get("hp", 0),
	}
	for key: Variant in extra.keys():
		payload[key] = extra[key]
	return CardData.from_dict(payload)


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for i: int in count:
		var energy := CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index)
		slot.attached_energy.append(energy)
		result.append(energy)
	return result


func _setup_battle(gsm: GameStateMachine, attacker_cd: CardData, defender_cd: CardData) -> Array[PokemonSlot]:
	var attacker := _make_slot(attacker_cd, 0)
	var defender := _make_slot(defender_cd, 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	_add_dummy_prizes(gsm.game_state)
	gsm.effect_processor.register_pokemon_card(attacker_cd)
	return [attacker, defender]


func _basic_target(name: String = "Target", mechanic: String = "") -> CardData:
	return _pokemon(name, "", [_attack("Hit", "", "10")], [], "C", 300, "Basic", mechanic)


func test_target_deck_cards_are_registered_as_implemented() -> String:
	CardImplementationStatusScript.clear_cache()
	var cards: Array[CardData] = [
		_pokemon("Liepard", "6027bb335acb1104add360a9425637af", [_attack("Slash", "CC", "60")], [{"name": "Trade", "text": "Discard 1 card from your hand. Draw 2 cards."}], "D", 100, "Stage 1"),
		_pokemon("Purrloin", "32dc6702e4af79d3715c6af88dee65d5", [_attack("Scratch", "C", "10x", "Flip 3 coins.")], [], "D", 60),
		_trainer("Explorer's Guidance", "Supporter", "0f4743343a173fdba38290050453a8c8"),
		_trainer("Escape Rope", "Item", "c6bc96f30e19315b2e59451b3f9b92cd"),
		_pokemon("Regieleki", "2976780d606bf72db47d00825db85124", [_attack("Zap", "C", "20"), _attack("Mega Spark", "LLC", "120", "Discard all Lightning Energy. Do 40 to 2 Benched Pokemon.")], [], "L", 120),
		_pokemon("Regidrago", "a300320fd4775b3a95e5aa87d0c75378", [_attack("Headbutt", "CC", "30"), _attack("Dragon Energy", "GGR", "240-", "Less damage for each damage counter.")], [], "N", 130),
		_pokemon("Regice", "873e6ea15bc769061eda7a433d95e9d6", [_attack("Regi Gate", "C", "", "Search your deck for a Basic Pokemon."), _attack("Blizzard Bind", "WWC", "100", "Pokemon V cannot attack next turn.")], [], "W", 130),
		_pokemon("Regieleki", "627d479a2e71c50d5c8d9bcfdd26bd0b", [_attack("Electromagnetic Sonar", "C", "", "Put a Trainer card from discard into hand."), _attack("Targeted Bolt", "LLC", "", "Discard 2 Lightning Energy and do 120 to a Benched Pokemon.")], [], "L", 130),
		_pokemon("Regirock", "399668227ca75416c9e72e83d1810457", [_attack("Regi Gate", "C", "", "Search your deck for a Basic Pokemon."), _attack("Giga Impact", "FFC", "140", "This Pokemon cannot attack next turn.")], [], "F", 130),
		_pokemon("Registeel", "db12f1eb552377de4cda107fbb6e1eb4", [_attack("Regi Gate", "C", "", "Search your deck for a Basic Pokemon."), _attack("Heavy Slam", "MMC", "220-", "Less damage for each retreat cost.")], [], "M", 130),
		_pokemon("Regidrago", "e49bf2cfe3c7948b0dcebbe1b1b7aa76", [_attack("Giant Fangs", "GRC", "160")], [{"name": "Dragon's Hoard", "text": "If Active, draw until you have 4 cards."}], "N", 130),
		_pokemon("Regigigas", "d699ab2122b5617fe5a5c97e60ae4dac", [_attack("Gigaton Break", "CCCCC", "150+", "If opponent Active is VMAX, add 150.")], [{"name": "Ancient Wisdom", "text": "Attach up to 3 Energy from discard if all Regis are in play."}], "C", 150),
		_pokemon("故勒顿", "fdc7e7c9f0001c433dbb481a9a2d7d08", [_attack("原生乱打", "FC", "30×", "造成自己场上「古代」宝可梦数量×30伤害。"), _attack("撕裂", "RFC", "130", "这个招式的伤害，不计算对手战斗宝可梦身上所附加的效果。")], [], "F", 130, "Basic", "", "Koraidon"),
	]
	var checks: Array[String] = []
	for card: CardData in cards:
		checks.append(assert_false(CardImplementationStatusScript.is_unimplemented(card), "%s should be implemented" % card.name))
	return run_checks(checks)


func test_liepard_trade_discards_selected_hand_card_and_draws_two() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var liepard := _pokemon("Liepard", "6027bb335acb1104add360a9425637af", [], [{"name": "Trade", "text": ""}], "D", 100, "Stage 1")
	var slot := _make_slot(liepard, 0)
	state.players[0].active_pokemon = slot
	gsm.effect_processor.register_pokemon_card(liepard)
	var discard_card := CardInstance.create(_trainer("Discard", "Item", ""), 0)
	var keep_card := CardInstance.create(_trainer("Keep", "Item", ""), 0)
	state.players[0].hand.append_array([discard_card, keep_card])
	state.players[0].deck.append(CardInstance.create(_trainer("Draw 1", "Item", ""), 0))
	state.players[0].deck.append(CardInstance.create(_trainer("Draw 2", "Item", ""), 0))
	var ok := gsm.effect_processor.execute_ability_effect(slot, 0, [{"discard_card": [discard_card]}], state)
	var can_use_again := gsm.effect_processor.can_use_ability(slot, state, 0)
	return run_checks([
		assert_true(ok, "Trade should execute"),
		assert_true(discard_card in state.players[0].discard_pile, "Selected card should be discarded"),
		assert_eq(state.players[0].hand.size(), 3, "Trade should leave kept card plus two draws"),
		assert_false(can_use_again, "Trade should be once per turn"),
	])


func test_purrloin_fixed_three_coin_damage_uses_shared_flipper() -> String:
	var flipper := RiggedCoinFlipper.new([true, false, true])
	var gsm := _make_gsm(flipper)
	var purrloin := _pokemon("Purrloin", "32dc6702e4af79d3715c6af88dee65d5", [_attack("Scratch", "C", "10x", "Flip 3 coins.")], [], "D", 60)
	var slots := _setup_battle(gsm, purrloin, _basic_target())
	_attach_energy(slots[0], 0, "C", 1)
	var used := gsm.use_attack(0, 0)
	return run_checks([
		assert_true(used, "Purrloin should attack"),
		assert_eq(slots[1].damage_counters, 20, "Two heads out of three should deal 20 total damage"),
	])


func test_escape_rope_switches_opponent_first_and_self_second() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var own_active := _make_slot(_basic_target("Own Active"), 0)
	var own_bench := _make_slot(_basic_target("Own Bench"), 0)
	var opp_active := _make_slot(_basic_target("Opp Active"), 1)
	var opp_bench := _make_slot(_basic_target("Opp Bench"), 1)
	state.players[0].active_pokemon = own_active
	state.players[0].bench.append(own_bench)
	state.players[1].active_pokemon = opp_active
	state.players[1].bench.append(opp_bench)
	var rope := CardInstance.create(_trainer("Escape Rope", "Item", "c6bc96f30e19315b2e59451b3f9b92cd"), 0)
	var executed := processor.execute_card_effect(rope, [{"opponent_switch_target": [opp_bench], "self_switch_target": [own_bench]}], state)
	return run_checks([
		assert_true(executed, "Escape Rope should execute"),
		assert_eq(state.players[1].active_pokemon, opp_bench, "Opponent chosen bench should become Active"),
		assert_eq(state.players[0].active_pokemon, own_bench, "Own chosen bench should become Active"),
	])


func test_regieleki_mega_spark_discards_lightning_and_hits_two_bench() -> String:
	var gsm := _make_gsm()
	var regieleki := _pokemon("Regieleki", "2976780d606bf72db47d00825db85124", [_attack("Zap", "C", "20"), _attack("Mega Spark", "LLC", "120", "Discard all Lightning Energy. Do 40 to 2 Benched Pokemon.")], [], "L", 120)
	var slots := _setup_battle(gsm, regieleki, _basic_target("Active Target"))
	_attach_energy(slots[0], 0, "L", 2)
	_attach_energy(slots[0], 0, "C", 1)
	var bench_a := _make_slot(_basic_target("Bench A"), 1)
	var bench_b := _make_slot(_basic_target("Bench B"), 1)
	var bench_c := _make_slot(_basic_target("Bench C"), 1)
	gsm.game_state.players[1].bench.append_array([bench_a, bench_b, bench_c])
	var used := gsm.use_attack(0, 1, [{"opponent_bench_damage_targets": [bench_a, bench_b]}])
	return run_checks([
		assert_true(used, "Mega Spark should execute"),
		assert_eq(slots[1].damage_counters, 120, "Active target should take 120"),
		assert_eq(bench_a.damage_counters, 40, "First chosen bench should take 40"),
		assert_eq(bench_b.damage_counters, 40, "Second chosen bench should take 40"),
		assert_eq(bench_c.damage_counters, 0, "Unchosen bench should not take damage"),
		assert_eq(slots[0].attached_energy.size(), 1, "Only non-Lightning Energy should remain"),
		assert_eq(gsm.game_state.players[0].discard_pile.size(), 2, "Lightning Energy should be discarded"),
	])


func test_regidrago_dragon_energy_reduces_damage_by_own_damage_counters() -> String:
	var gsm := _make_gsm()
	var regidrago := _pokemon("Regidrago", "a300320fd4775b3a95e5aa87d0c75378", [_attack("Headbutt", "CC", "30"), _attack("Dragon Energy", "GGR", "240-", "Less damage for each damage counter.")], [], "N", 130)
	var slots := _setup_battle(gsm, regidrago, _basic_target())
	_attach_energy(slots[0], 0, "G", 2)
	_attach_energy(slots[0], 0, "R", 1)
	slots[0].damage_counters = 30
	var used := gsm.use_attack(0, 1)
	return run_checks([
		assert_true(used, "Dragon Energy should execute"),
		assert_eq(slots[1].damage_counters, 180, "Three damage counters should reduce 240 by 60"),
	])


func test_regice_regi_gate_and_blizzard_bind_v_lock() -> String:
	var gsm := _make_gsm()
	var regice := _pokemon("Regice", "873e6ea15bc769061eda7a433d95e9d6", [_attack("Regi Gate", "C", "", "Search your deck for a Basic Pokemon."), _attack("Blizzard Bind", "WWC", "100", "Pokemon V cannot attack next turn.")], [], "W", 130)
	var defender_cd := _basic_target("Target V", "V")
	var slots := _setup_battle(gsm, regice, defender_cd)
	_attach_energy(slots[0], 0, "C", 1)
	var searched := CardInstance.create(_pokemon("Bench Basic", "", [_attack("Hit", "", "10")]), 0)
	gsm.game_state.players[0].deck.append(searched)
	var gate_used := gsm.use_attack(0, 0, [{"search_basic_pokemon": [searched]}])
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.players[0].active_pokemon = slots[0]
	_attach_energy(slots[0], 0, "W", 2)
	var lock_used := gsm.use_attack(0, 1)
	gsm.game_state.turn_number = 3
	gsm.game_state.current_player_index = 1
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var locked := not gsm.rule_validator.can_use_attack(gsm.game_state, 1, 0, gsm.effect_processor)
	return run_checks([
		assert_true(gate_used, "Regi Gate should execute"),
		assert_true(searched not in gsm.game_state.players[0].deck, "Searched Basic should leave deck"),
		assert_true(gsm.game_state.players[0].bench.any(func(slot: PokemonSlot) -> bool: return slot.get_top_card() == searched), "Searched Basic should be benched"),
		assert_true(lock_used, "Blizzard Bind should execute"),
		assert_true(locked, "Pokemon V defender should be unable to attack next turn"),
	])


func test_regieleki_electromagnetic_sonar_and_targeted_bolt() -> String:
	var gsm := _make_gsm()
	var regieleki := _pokemon("Regieleki", "627d479a2e71c50d5c8d9bcfdd26bd0b", [_attack("Electromagnetic Sonar", "C", "", "Recover Trainer."), _attack("Targeted Bolt", "LLC", "", "Discard 2 Lightning Energy and hit bench.")], [], "L", 130)
	var slots := _setup_battle(gsm, regieleki, _basic_target())
	_attach_energy(slots[0], 0, "C", 1)
	var trainer := CardInstance.create(_trainer("Supporter", "Supporter", ""), 0)
	gsm.game_state.players[0].discard_pile.append(trainer)
	var sonar_used := gsm.use_attack(0, 0, [{"recover_trainer_from_discard": [trainer]}])
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.players[0].active_pokemon = slots[0]
	_attach_energy(slots[0], 0, "L", 2)
	var bench := _make_slot(_basic_target("Bench Target"), 1)
	gsm.game_state.players[1].bench.append(bench)
	var bolt_used := gsm.use_attack(0, 1, [{"bench_target": [bench], "discard_typed_attached_energy_from_self": slots[0].attached_energy.slice(1, 3)}])
	return run_checks([
		assert_true(sonar_used, "Electromagnetic Sonar should execute"),
		assert_true(trainer in gsm.game_state.players[0].hand, "Trainer should move from discard to hand"),
		assert_true(bolt_used, "Targeted Bolt should execute"),
		assert_eq(bench.damage_counters, 120, "Targeted Bolt should hit chosen bench for 120"),
		assert_eq(gsm.game_state.players[0].discard_pile.size(), 2, "Two Lightning Energy should be discarded after the Trainer was recovered"),
	])


func test_regirock_ultimate_impact_locks_same_attack_next_turn() -> String:
	var gsm := _make_gsm()
	var regirock := _pokemon("Regirock", "399668227ca75416c9e72e83d1810457", [_attack("Regi Gate", "C", "", "Search your deck."), _attack("Ultimate Impact", "FFC", "140", "Cannot use this attack next turn.")], [], "F", 130)
	var slots := _setup_battle(gsm, regirock, _basic_target())
	_attach_energy(slots[0], 0, "F", 2)
	_attach_energy(slots[0], 0, "C", 1)
	var used := gsm.use_attack(0, 1)
	gsm.game_state.turn_number = 4
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var can_reuse := gsm.rule_validator.can_use_attack(gsm.game_state, 0, 1, gsm.effect_processor)
	return run_checks([
		assert_true(used, "Ultimate Impact should execute"),
		assert_false(can_reuse, "Same attack should be locked on the next own turn"),
	])


func test_registeel_heavy_slam_reduces_by_opponent_retreat_cost() -> String:
	var gsm := _make_gsm()
	var registeel := _pokemon("Registeel", "db12f1eb552377de4cda107fbb6e1eb4", [_attack("Regi Gate", "C", "", "Search your deck."), _attack("Heavy Slam", "MMC", "220-", "Less damage for retreat cost.")], [], "M", 130)
	var defender := _basic_target("Heavy Target")
	defender.retreat_cost = 3
	var slots := _setup_battle(gsm, registeel, defender)
	_attach_energy(slots[0], 0, "M", 2)
	_attach_energy(slots[0], 0, "C", 1)
	var used := gsm.use_attack(0, 1)
	return run_checks([
		assert_true(used, "Heavy Slam should execute"),
		assert_eq(slots[1].damage_counters, 70, "Retreat cost 3 should reduce 220 by 150"),
	])


func test_regidrago_dragons_hoard_requires_active_and_draws_to_four() -> String:
	var gsm := _make_gsm()
	var regidrago := _pokemon("Regidrago", "e49bf2cfe3c7948b0dcebbe1b1b7aa76", [_attack("Giant Fangs", "GRC", "160")], [{"name": "Dragon's Hoard", "text": "Draw until 4 if Active."}], "N", 130)
	var slot := _make_slot(regidrago, 0)
	gsm.game_state.players[0].active_pokemon = slot
	gsm.effect_processor.register_pokemon_card(regidrago)
	gsm.game_state.players[0].hand.append(CardInstance.create(_trainer("Hand 1", "Item", ""), 0))
	gsm.game_state.players[0].deck.append(CardInstance.create(_trainer("Draw 1", "Item", ""), 0))
	gsm.game_state.players[0].deck.append(CardInstance.create(_trainer("Draw 2", "Item", ""), 0))
	gsm.game_state.players[0].deck.append(CardInstance.create(_trainer("Draw 3", "Item", ""), 0))
	var used := gsm.effect_processor.execute_ability_effect(slot, 0, [], gsm.game_state)
	var hand_size_after_draw := gsm.game_state.players[0].hand.size()
	var can_use_again := gsm.effect_processor.can_use_ability(slot, gsm.game_state, 0)
	gsm.game_state.players[0].active_pokemon = _make_slot(_basic_target("Other"), 0)
	gsm.game_state.players[0].bench.append(slot)
	slot.effects.clear()
	gsm.game_state.players[0].hand.clear()
	var can_use_from_bench := gsm.effect_processor.can_use_ability(slot, gsm.game_state, 0)
	return run_checks([
		assert_true(used, "Dragon's Hoard should execute while Active"),
		assert_eq(hand_size_after_draw, 4, "Dragon's Hoard should draw to four cards"),
		assert_false(can_use_again, "Dragon's Hoard should be once per turn"),
		assert_false(can_use_from_bench, "Dragon's Hoard should require Active Spot"),
	])


func test_regigigas_ancient_wisdom_and_vmax_bonus() -> String:
	var gsm := _make_gsm()
	var regigigas := _pokemon("Regigigas", "d699ab2122b5617fe5a5c97e60ae4dac", [_attack("Gigaton Break", "CCCCC", "150+", "Add 150 against VMAX.")], [{"name": "Ancient Wisdom", "text": "Attach up to 3 Energy from discard."}], "C", 150, "Basic", "", "Regigigas")
	var vmax := _basic_target("Target VMAX", "VMAX")
	var slots := _setup_battle(gsm, regigigas, vmax)
	var required := [
		_pokemon("Regirock", "", [], [], "F", 130, "Basic", "", "Regirock"),
		_pokemon("Regice", "", [], [], "W", 130, "Basic", "", "Regice"),
		_pokemon("Registeel", "", [], [], "M", 130, "Basic", "", "Registeel"),
		_pokemon("Regieleki", "", [], [], "L", 130, "Basic", "", "Regieleki"),
		_pokemon("Regidrago", "", [], [], "N", 130, "Basic", "", "Regidrago"),
	]
	for cd: CardData in required:
		gsm.game_state.players[0].bench.append(_make_slot(cd, 0))
	var energies := [
		CardInstance.create(_energy("Energy A", "C"), 0),
		CardInstance.create(_energy("Energy B", "L"), 0),
		CardInstance.create(_energy("Energy C", "W"), 0),
	]
	gsm.game_state.players[0].discard_pile.append_array(energies)
	var ability_used := gsm.effect_processor.execute_ability_effect(slots[0], 0, [{"ancient_wisdom_energy": energies, "ancient_wisdom_target": [slots[0]]}], gsm.game_state)
	_attach_energy(slots[0], 0, "C", 2)
	var attack_used := gsm.use_attack(0, 0)
	return run_checks([
		assert_true(ability_used, "Ancient Wisdom should execute with all five Regis in play"),
		assert_eq(slots[0].attached_energy.size(), 5, "Ancient Wisdom should attach three Energy to one Pokemon"),
		assert_eq(gsm.game_state.players[0].discard_pile.size(), 0, "Attached Energy should leave discard pile"),
		assert_true(attack_used, "Gigaton Break should execute"),
		assert_eq(slots[1].damage_counters, 300, "VMAX defender should take 150 plus 150 bonus"),
	])


func test_koraidon_primitive_beatdown_counts_own_ancient_pokemon() -> String:
	var gsm := _make_gsm()
	var koraidon := _pokemon("故勒顿", "fdc7e7c9f0001c433dbb481a9a2d7d08", [_attack("原生乱打", "FC", "30×", "造成自己场上「古代」宝可梦数量×30伤害。"), _attack("撕裂", "RFC", "130", "Ignore effects.")], [], "F", 130, "Basic", "", "Koraidon")
	koraidon.is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	var defender := _basic_target("Defender")
	var slots := _setup_battle(gsm, koraidon, defender)
	_attach_energy(slots[0], 0, "F", 1)
	_attach_energy(slots[0], 0, "C", 1)

	var ancient_a := _pokemon("振翼发", "", [], [], "P", 90)
	ancient_a.is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	var ancient_b := _pokemon("轰鸣月", "", [], [], "D", 140)
	ancient_b.is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	var non_ancient := _pokemon("普通宝可梦", "", [], [], "C", 100)
	gsm.game_state.players[0].bench.append(_make_slot(ancient_a, 0))
	gsm.game_state.players[0].bench.append(_make_slot(non_ancient, 0))
	gsm.game_state.players[0].bench.append(_make_slot(ancient_b, 0))

	var used := gsm.use_attack(0, 0)
	return run_checks([
		assert_true(used, "Koraidon should use Primitive Beatdown"),
		assert_eq(slots[1].damage_counters, 90, "Primitive Beatdown should count Active Koraidon plus two Ancient Bench Pokemon"),
	])


func test_koraidon_cached_tag_override_marks_ancient() -> String:
	var koraidon := _cached_card(
		"CSV7C_152",
		"故勒顿",
		"Koraidon",
		"Pokemon",
		{
			"effect_id": "fdc7e7c9f0001c433dbb481a9a2d7d08",
			"stage": "Basic",
			"hp": 140,
			"attacks": [
				_attack("原生乱打", "FC", "30×", "造成自己场上「古代」宝可梦数量×30伤害。"),
				_attack("撕裂", "RFC", "130", "Ignore effects."),
			],
		}
	)
	return run_checks([
		assert_true(koraidon.is_ancient_pokemon(), "CSV7C_152 should receive the Ancient tag from overrides"),
		assert_false(CardImplementationStatusScript.is_unimplemented(koraidon), "Tagged cached Koraidon should still be implemented"),
	])


func test_koraidon_shred_ignores_defender_damage_prevention_only_on_second_attack() -> String:
	var gsm := _make_gsm()
	var koraidon := _pokemon("故勒顿", "fdc7e7c9f0001c433dbb481a9a2d7d08", [_attack("原生乱打", "FC", "30×", "造成自己场上「古代」宝可梦数量×30伤害。"), _attack("撕裂", "RFC", "130", "Ignore effects.")], [], "F", 130, "Basic", "", "Koraidon")
	koraidon.is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	var defender_cd := _basic_target("Protected Defender")
	var slots := _setup_battle(gsm, koraidon, defender_cd)
	slots[1].effects.append({
		"type": AttackCoinFlipPreventDamageAndEffectsNextTurn.PROTECTION_EFFECT_TYPE,
		"turn": gsm.game_state.turn_number - 1,
	})
	_attach_energy(slots[0], 0, "F", 1)
	_attach_energy(slots[0], 0, "C", 1)
	var first_attack_ignores := gsm.effect_processor.attack_ignores_defender_effects(slots[0], 0, gsm.game_state)
	var first_used := gsm.use_attack(0, 0)
	var damage_after_first_attack := slots[1].damage_counters

	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.players[0].active_pokemon = slots[0]
	gsm.game_state.players[1].active_pokemon = slots[1]
	_attach_energy(slots[0], 0, "R", 1)
	var second_attack_ignores := gsm.effect_processor.attack_ignores_defender_effects(slots[0], 1, gsm.game_state)
	var second_used := gsm.use_attack(0, 1)
	return run_checks([
		assert_false(first_attack_ignores, "Primitive Beatdown should not inherit Shred's ignore-defender-effects flag"),
		assert_true(first_used, "Primitive Beatdown should still be a legal attack"),
		assert_eq(damage_after_first_attack, 0, "Primitive Beatdown should still be stopped by defender attack protection"),
		assert_true(second_attack_ignores, "Shred should ignore defender effects during damage calculation"),
		assert_true(second_used, "Shred should execute"),
		assert_eq(slots[1].damage_counters, 130, "Shred should add 130 damage through defender effects"),
	])
