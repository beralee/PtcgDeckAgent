class_name TestRagingBoltChurnDiscipline
extends TestBase

const RagingBoltStrategyScript = preload("res://scripts/ai/DeckStrategyRagingBoltOgerpon.gd")


func _make_game_state(turn_number: int = 7) -> GameState:
	var gs := GameState.new()
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = turn_number
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gs.players.append(player)
	return gs


func _make_pokemon_cd(name: String, hp: int = 100, retreat_cost: int = 1, attacks: Array = []) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.hp = hp
	cd.retreat_cost = retreat_cost
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_raging_bolt_cd() -> CardData:
	var cd := _make_pokemon_cd("Raging Bolt ex", 240, 3, [
		{"name": "Burst Roar", "cost": "C", "damage": "", "text": "Discard your hand and draw 6."},
		{"name": "Bellowing Thunder", "cost": "LF", "damage": "70x", "text": "Discard any Basic Energy from your Pokemon."},
	])
	cd.mechanic = "ex"
	cd.ancient_trait = "Ancient"
	cd.is_tags.append("Ancient")
	return cd


func _make_ogerpon_cd() -> CardData:
	var cd := _make_pokemon_cd("Teal Mask Ogerpon ex", 210, 1, [
		{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+", "text": ""},
	])
	cd.mechanic = "ex"
	cd.energy_type = "G"
	return cd


func _make_slot(cd: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(cd, owner))
	return slot


func _make_energy(name: String, provides: String, owner: int = 0) -> CardInstance:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = provides
	return CardInstance.create(cd, owner)


func _make_special_energy(name: String, owner: int = 0) -> CardInstance:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Special Energy"
	return CardInstance.create(cd, owner)


func _make_trainer(name: String, card_type: String = "Item", owner: int = 0) -> CardInstance:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	return CardInstance.create(cd, owner)


func _contract_has_bonus(contract: Dictionary, kind: String, card_name: String) -> bool:
	var bonuses: Array = contract.get("action_bonuses", [])
	for item: Variant in bonuses:
		if not (item is Dictionary):
			continue
		var bonus: Dictionary = item
		if str(bonus.get("kind", "")) != kind:
			continue
		var names: Array = bonus.get("card_names", [])
		for raw_name: Variant in names:
			if str(raw_name) == card_name:
				return true
	return false


func _contract_has_energy_bonus(contract: Dictionary, energy_type: String) -> bool:
	var bonuses: Array = contract.get("action_bonuses", [])
	for item: Variant in bonuses:
		if not (item is Dictionary):
			continue
		var bonus: Dictionary = item
		if str(bonus.get("kind", "")) != "attach_energy":
			continue
		var energy_types: Array = bonus.get("energy_types", [])
		for raw_type: Variant in energy_types:
			if str(raw_type) == energy_type:
				return true
	return false


func test_continuity_contract_requests_backup_shell_before_nonterminal_attack() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.active_pokemon.attached_energy.append(_make_energy("Fighting Energy", "F"))
	player.active_pokemon.attached_energy.append(_make_energy("Grass Energy", "G"))
	for i: int in 18:
		player.deck.append(_make_trainer("Filler%d" % i))

	var turn_plan: Dictionary = strategy.build_turn_plan(gs, 0, {"prompt_kind": "action_selection"})
	var contract: Dictionary = strategy.build_continuity_contract(gs, 0, turn_plan)
	var debt: Dictionary = contract.get("setup_debt", {})
	return run_checks([
		assert_true(bool(contract.get("enabled", false)), "Continuity contract should be enabled when a lone ready Bolt can attack but backup shell is missing"),
		assert_true(bool(contract.get("safe_setup_before_attack", false)), "Continuity contract should request safe setup before the terminal attack"),
		assert_true(bool(debt.get("needs_second_raging_bolt", false)), "Continuity debt should include the missing second Raging Bolt"),
		assert_true(bool(debt.get("needs_ogerpon", false)), "Continuity debt should include the missing Teal Mask Ogerpon engine"),
		assert_true(_contract_has_bonus(contract, "play_basic_to_bench", "Raging Bolt ex"), "Continuity bonuses should reward benching backup Raging Bolt"),
		assert_true(_contract_has_bonus(contract, "play_basic_to_bench", "Teal Mask Ogerpon ex"), "Continuity bonuses should reward benching Teal Mask Ogerpon"),
		assert_true(_contract_has_bonus(contract, "play_trainer", "Nest Ball"), "Continuity bonuses should reward search that fills backup shell"),
	])


func test_continuity_contract_rewards_ogerpon_and_energy_relay() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.active_pokemon.attached_energy.append(_make_energy("Fighting Energy", "F"))
	player.active_pokemon.attached_energy.append(_make_energy("Grass Energy", "G"))
	var backup_bolt := _make_slot(_make_raging_bolt_cd(), 0)
	backup_bolt.attached_energy.append(_make_energy("Lightning Energy", "L"))
	var ogerpon := _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(backup_bolt)
	player.bench.append(ogerpon)
	player.hand.append(_make_energy("Grass Energy", "G"))
	player.discard_pile.append(_make_energy("Fighting Energy", "F"))
	for i: int in 18:
		player.deck.append(_make_trainer("Filler%d" % i))

	var turn_plan: Dictionary = strategy.build_turn_plan(gs, 0, {"prompt_kind": "action_selection"})
	var contract: Dictionary = strategy.build_continuity_contract(gs, 0, turn_plan)
	var debt: Dictionary = contract.get("setup_debt", {})
	return run_checks([
		assert_true(bool(contract.get("enabled", false)), "Continuity contract should be enabled when follow-up energy is still owed"),
		assert_true(bool(debt.get("needs_ogerpon_charge", false)), "Continuity debt should include using Teal Mask Ogerpon when Grass is in hand"),
		assert_true(bool(debt.get("needs_follow_up_energy", false)), "Continuity debt should include charging the backup Raging Bolt"),
		assert_true(_contract_has_bonus(contract, "use_ability", "Teal Mask Ogerpon ex"), "Continuity bonuses should reward Teal Mask Ogerpon's Energy acceleration"),
		assert_true(_contract_has_energy_bonus(contract, "F"), "Continuity bonuses should reward manual/Sada Fighting Energy relay to backup Bolt"),
		assert_true(_contract_has_bonus(contract, "play_trainer", "Professor Sada's Vitality"), "Continuity bonuses should reward Sada as a relay action"),
		assert_true(_contract_has_bonus(contract, "play_trainer", "Earthen Vessel"), "Continuity bonuses should reward Vessel for safe basic Energy setup"),
	])


func test_continuity_contract_disables_for_final_prize_ko() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(10)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.active_pokemon.attached_energy.append(_make_energy("Fighting Energy", "F"))
	player.active_pokemon.attached_energy.append(_make_energy("Grass Energy", "G"))
	player.bench.append(_make_slot(_make_ogerpon_cd(), 0))
	player.hand.append(_make_energy("Grass Energy", "G"))
	player.prizes.append(_make_trainer("FinalPrize"))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", 210, 1), 1)
	for i: int in 18:
		player.deck.append(_make_trainer("Filler%d" % i))

	var contract: Dictionary = strategy.build_continuity_contract(gs, 0, {
		"flags": {"final_prize_ko": true},
	})
	return run_checks([
		assert_false(bool(contract.get("enabled", false)), "Final-prize KO should disable pre-terminal continuity bonuses"),
		assert_false(bool(contract.get("safe_setup_before_attack", false)), "Final-prize KO should remain terminal"),
		assert_true(bool(contract.get("terminal_attack_locked", false)), "Contract should explain that terminal attack priority locked setup out"),
	])


func test_low_deck_redraw_attack_stays_below_end_turn() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(13)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.hand = [_make_trainer("Night Stretcher")]
	for i: int in 4:
		player.deck.append(_make_trainer("Filler%d" % i))

	var redraw_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 0,
		"attack_name": "Burst Roar",
		"projected_damage": 0,
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		redraw_score <= end_score,
		"Low-deck Raging Bolt should not prefer hand-discard redraw attack over ending turn (redraw=%f end=%f)" % [redraw_score, end_score]
	)


func test_low_deck_draw_abilities_cool_off() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(13)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var ogerpon := _make_slot(_make_ogerpon_cd(), 0)
	var greninja := _make_slot(_make_pokemon_cd("Radiant Greninja", 130, 1), 0)
	player.bench.append(ogerpon)
	player.bench.append(greninja)
	player.hand.append(_make_energy("Grass Energy", "G"))
	for i: int in 3:
		player.deck.append(_make_trainer("Filler%d" % i))

	var ogerpon_score: float = strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": ogerpon,
	}, gs, 0)
	var greninja_score: float = strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": greninja,
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return run_checks([
		assert_true(ogerpon_score <= end_score, "Low-deck Ogerpon draw should cool off (ogerpon=%f end=%f)" % [ogerpon_score, end_score]),
		assert_true(greninja_score <= end_score, "Low-deck Greninja draw-2 should cool off (greninja=%f end=%f)" % [greninja_score, end_score]),
	])


func test_off_plan_grass_attach_to_support_without_handoff_stays_below_end_turn() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Iron Bundle", 100, 1), 0)
	for i: int in 20:
		player.deck.append(_make_trainer("Filler%d" % i))
	var grass := _make_energy("Grass Energy", "G")

	var attach_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": grass,
		"target_slot": player.active_pokemon,
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		attach_score <= end_score,
		"Grass attach to Iron Bundle without a real Raging Bolt handoff should be below end turn (attach=%f end=%f)" % [attach_score, end_score]
	)


func test_bolt_attach_prefers_missing_core_type_over_duplicate() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	var duplicate_lightning := _make_energy("Lightning Energy", "L")
	var missing_fighting := _make_energy("Fighting Energy", "F")

	var duplicate_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": duplicate_lightning,
		"target_slot": player.active_pokemon,
	}, gs, 0)
	var missing_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": missing_fighting,
		"target_slot": player.active_pokemon,
	}, gs, 0)
	return assert_gt(
		missing_score,
		duplicate_score + 250.0,
		"Raging Bolt should complete L+F before attaching duplicate core energy (F=%f duplicate L=%f)" % [missing_score, duplicate_score]
	)


func test_bravery_charm_does_not_attach_to_support_pokemon() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	var greninja := _make_slot(_make_pokemon_cd("Radiant Greninja", 130, 1), 0)
	player.bench.append(greninja)
	var charm := _make_trainer("Bravery Charm", "Tool")

	var support_score: float = strategy.score_action_absolute({
		"kind": "attach_tool",
		"card": charm,
		"target_slot": greninja,
	}, gs, 0)
	var attacker_score: float = strategy.score_action_absolute({
		"kind": "attach_tool",
		"card": charm,
		"target_slot": player.active_pokemon,
	}, gs, 0)
	return run_checks([
		assert_true(support_score <= 0.0, "Bravery Charm should not consume itself on Radiant Greninja support (got %f)" % support_score),
		assert_gt(attacker_score, support_score, "Bravery Charm should prefer Raging Bolt over support Pokemon"),
	])


func test_night_stretcher_energy_only_recovery_cools_off_when_bolt_ready() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(9)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.active_pokemon.attached_energy.append(_make_energy("Fighting Energy", "F"))
	player.active_pokemon.attached_energy.append(_make_energy("Grass Energy", "G"))
	player.discard_pile.append(_make_energy("Lightning Energy", "L"))
	for i: int in 12:
		player.deck.append(_make_trainer("Filler%d" % i))
	var stretcher := _make_trainer("Night Stretcher")

	var stretcher_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": stretcher,
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		stretcher_score <= end_score,
		"Night Stretcher should cool off when it only recovers spare Energy and Raging Bolt is ready (stretcher=%f end=%f)" % [stretcher_score, end_score]
	)


func test_ready_bolt_uses_safe_ogerpon_charge_before_nonlethal_attack() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.active_pokemon.attached_energy.append(_make_energy("Fighting Energy", "F"))
	player.active_pokemon.attached_energy.append(_make_energy("Grass Energy", "G"))
	var ogerpon := _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(ogerpon)
	player.hand.append(_make_energy("Grass Energy", "G"))
	for i: int in 18:
		player.deck.append(_make_trainer("Filler%d" % i))

	var ogerpon_score: float = strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": ogerpon,
	}, gs, 0)
	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 1,
		"attack_name": "Bellowing Thunder",
		"projected_damage": 210,
		"projected_knockout": false,
	}, gs, 0)
	return assert_gt(
		ogerpon_score,
		attack_score,
		"Ready Raging Bolt should charge a fresh Ogerpon before a nonlethal pressure attack (ogerpon=%f attack=%f)" % [ogerpon_score, attack_score]
	)


func test_ready_bolt_benches_backup_before_nonlethal_attack() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.active_pokemon.attached_energy.append(_make_energy("Fighting Energy", "F"))
	player.active_pokemon.attached_energy.append(_make_energy("Grass Energy", "G"))
	var backup_card := CardInstance.create(_make_raging_bolt_cd(), 0)
	for i: int in 18:
		player.deck.append(_make_trainer("Filler%d" % i))

	var bench_score: float = strategy.score_action_absolute({
		"kind": "play_basic_to_bench",
		"card": backup_card,
	}, gs, 0)
	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 1,
		"attack_name": "Bellowing Thunder",
		"projected_damage": 210,
		"projected_knockout": false,
	}, gs, 0)
	return assert_gt(
		bench_score,
		attack_score,
		"Ready Raging Bolt should bench a second Bolt before a nonlethal pressure attack (bench=%f attack=%f)" % [bench_score, attack_score]
	)


func test_ready_bolt_attaches_charm_before_nonlethal_attack() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.active_pokemon.attached_energy.append(_make_energy("Fighting Energy", "F"))
	player.active_pokemon.attached_energy.append(_make_energy("Grass Energy", "G"))
	var charm := _make_trainer("Bravery Charm", "Tool")

	var charm_score: float = strategy.score_action_absolute({
		"kind": "attach_tool",
		"card": charm,
		"target_slot": player.active_pokemon,
	}, gs, 0)
	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 1,
		"attack_name": "Bellowing Thunder",
		"projected_damage": 210,
		"projected_knockout": false,
	}, gs, 0)
	return assert_gt(
		charm_score,
		attack_score,
		"Ready Raging Bolt should attach Bravery Charm before a nonlethal pressure attack (charm=%f attack=%f)" % [charm_score, attack_score]
	)


func test_ready_bolt_uses_safe_ogerpon_charge_before_nonfinal_ko() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.active_pokemon.attached_energy.append(_make_energy("Fighting Energy", "F"))
	player.active_pokemon.attached_energy.append(_make_energy("Grass Energy", "G"))
	var ogerpon := _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(ogerpon)
	player.hand.append(_make_energy("Grass Energy", "G"))
	for i: int in 4:
		player.prizes.append(_make_trainer("Prize%d" % i))
	for i: int in 18:
		player.deck.append(_make_trainer("Filler%d" % i))

	var ogerpon_score: float = strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": ogerpon,
	}, gs, 0)
	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 1,
		"attack_name": "Bellowing Thunder",
		"projected_damage": 210,
		"projected_knockout": true,
	}, gs, 0)
	return assert_gt(
		ogerpon_score,
		attack_score,
		"Before a non-final KO, ready Raging Bolt should still take safe Ogerpon charge/draw first (ogerpon=%f attack=%f)" % [ogerpon_score, attack_score]
	)


func test_final_prize_ko_stays_above_safe_setup() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(10)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.active_pokemon.attached_energy.append(_make_energy("Fighting Energy", "F"))
	player.active_pokemon.attached_energy.append(_make_energy("Grass Energy", "G"))
	var ogerpon := _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(ogerpon)
	player.hand.append(_make_energy("Grass Energy", "G"))
	player.prizes.append(_make_trainer("FinalPrize"))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", 220, 1), 1)
	for i: int in 18:
		player.deck.append(_make_trainer("Filler%d" % i))

	var ogerpon_score: float = strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": ogerpon,
	}, gs, 0)
	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 1,
		"attack_name": "Bellowing Thunder",
		"projected_damage": 220,
		"projected_knockout": true,
	}, gs, 0)
	return assert_gt(
		attack_score,
		ogerpon_score,
		"Final-prize KO should remain terminal and beat optional setup (attack=%f ogerpon=%f)" % [attack_score, ogerpon_score]
	)


func test_temple_stadium_kind_scores_against_special_energy() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", 220, 1), 1)
	opponent.active_pokemon.attached_energy.append(_make_special_energy("Legacy Energy", 1))
	var temple := _make_trainer("Temple of Sinnoh", "Stadium")

	var stadium_score: float = strategy.score_action_absolute({
		"kind": "play_stadium",
		"card": temple,
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_gt(
		stadium_score,
		end_score,
		"Temple of Sinnoh should be scored through play_stadium when opponent has Special Energy (stadium=%f end=%f)" % [stadium_score, end_score]
	)


func test_lost_vacuum_does_not_fire_for_own_stadium_only() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	gs.stadium_card = _make_trainer("Temple of Sinnoh", "Stadium")
	gs.stadium_owner_index = 0
	var vacuum := _make_trainer("Lost Vacuum")

	var vacuum_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": vacuum,
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		vacuum_score <= end_score,
		"Lost Vacuum should not spend a hand card when the only target is our own stadium (vacuum=%f end=%f)" % [vacuum_score, end_score]
	)


func test_lost_vacuum_waits_until_bolt_attack_window() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_ogerpon_cd(), 0)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", 220, 1), 1)
	opponent.active_pokemon.attached_tool = _make_trainer("Bravery Charm", "Tool", 1)
	var vacuum := _make_trainer("Lost Vacuum")

	var vacuum_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": vacuum,
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		vacuum_score <= end_score,
		"Lost Vacuum should not spend resources before Raging Bolt has an attack window (vacuum=%f end=%f)" % [vacuum_score, end_score]
	)


func test_prime_catcher_chinese_alias_waits_for_attack_window() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_ogerpon_cd(), 0)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", 220, 1), 1)
	opponent.bench.append(_make_slot(_make_pokemon_cd("Squawkabilly ex", 160, 1), 1))
	var catcher := _make_trainer("顶尖捕捉器")

	var catcher_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": catcher,
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		catcher_score <= end_score,
		"Prime Catcher should be held before an attack window even when using the Chinese card name (catcher=%f end=%f)" % [catcher_score, end_score]
	)


func test_boss_waits_when_ready_bolt_cannot_enter_active() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Fezandipiti ex", 210, 1), 0)
	var bench_bolt := _make_slot(_make_raging_bolt_cd(), 0)
	bench_bolt.attached_energy.append(_make_energy("Lightning Energy", "L"))
	bench_bolt.attached_energy.append(_make_energy("Fighting Energy", "F"))
	bench_bolt.attached_energy.append(_make_energy("Grass Energy", "G"))
	player.bench.append(bench_bolt)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", 220, 1), 1)
	opponent.bench.append(_make_slot(_make_pokemon_cd("Squawkabilly ex", 160, 1), 1))
	var boss := _make_trainer("Boss's Orders", "Supporter")

	var boss_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": boss,
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		boss_score <= end_score,
		"Boss should not fire just because a ready Bolt exists on bench if it cannot enter active this turn (boss=%f end=%f)" % [boss_score, end_score]
	)


func test_switch_cart_only_gets_premium_score_for_ready_bolt_pivot() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Fezandipiti ex", 210, 1), 0)
	var unready_bolt := _make_slot(_make_raging_bolt_cd(), 0)
	unready_bolt.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.bench.append(unready_bolt)
	var cart := _make_trainer("Switch Cart")

	var cart_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": cart,
	}, gs, 0)
	return assert_true(
		cart_score < 400.0,
		"Switch Cart should not get premium pivot score unless it can reach a ready Raging Bolt (cart=%f)" % cart_score
	)


func test_energy_recovery_prioritizes_missing_bolt_attack_type() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(9)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	var grass := _make_energy("Grass Energy", "G")
	var fighting := _make_energy("Fighting Energy", "F")
	player.discard_pile.append(grass)
	player.discard_pile.append(fighting)
	var step := {"id": "recover_energy"}
	var context := {"game_state": gs, "player_index": 0}

	var fighting_score: float = strategy.score_interaction_target(fighting, step, context)
	var grass_score: float = strategy.score_interaction_target(grass, step, context)
	return assert_gt(
		fighting_score,
		grass_score,
		"Energy recovery should prefer the missing Fighting cost for Raging Bolt over spare Grass (F=%f G=%f)" % [fighting_score, grass_score]
	)


func test_energy_recovery_prioritizes_grass_fuel_after_bolt_cost_ready() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.active_pokemon.attached_energy.append(_make_energy("Fighting Energy", "F"))
	player.bench.append(_make_slot(_make_ogerpon_cd(), 0))
	var grass := _make_energy("Grass Energy", "G")
	var fighting := _make_energy("Fighting Energy", "F")
	player.discard_pile.append(grass)
	player.discard_pile.append(fighting)
	var step := {"id": "recover_energy"}
	var context := {"game_state": gs, "player_index": 0}

	var grass_score: float = strategy.score_interaction_target(grass, step, context)
	var fighting_score: float = strategy.score_interaction_target(fighting, step, context)
	return assert_gt(
		grass_score,
		fighting_score,
		"After Raging Bolt has L+F, recovery should prefer Grass fuel for Ogerpon/Bellowing Thunder damage (G=%f F=%f)" % [grass_score, fighting_score]
	)


func test_one_energy_sada_rebuilds_missing_bolt_cost_above_churn() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(9)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.discard_pile.append(_make_energy("Fighting Energy", "F"))
	var sada := _make_trainer("Professor Sada's Vitality", "Supporter")
	var shoes := _make_trainer("Trekking Shoes")

	var sada_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": sada,
	}, gs, 0)
	var shoes_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": shoes,
	}, gs, 0)
	return assert_gt(
		sada_score,
		shoes_score + 250.0,
		"One-energy Sada should be a decisive rebuild action when it restores missing Raging Bolt cost (Sada=%f Shoes=%f)" % [sada_score, shoes_score]
	)


func test_one_energy_retrieval_rebuilds_missing_bolt_cost_above_churn() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(9)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.discard_pile.append(_make_energy("Fighting Energy", "F"))
	var retrieval := _make_trainer("Energy Retrieval")
	var shoes := _make_trainer("Trekking Shoes")

	var retrieval_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": retrieval,
	}, gs, 0)
	var shoes_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": shoes,
	}, gs, 0)
	return assert_gt(
		retrieval_score,
		shoes_score + 200.0,
		"One-energy Retrieval should be a rebuild action when it recovers missing Raging Bolt cost (Retrieval=%f Shoes=%f)" % [retrieval_score, shoes_score]
	)


func test_boss_orders_without_attack_window_stays_below_end_turn() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Iron Bundle", 100, 1), 0)
	var opponent: PlayerState = gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", 220, 1), 1)
	opponent.bench.append(_make_slot(_make_pokemon_cd("Squawkabilly ex", 160, 1), 1))
	var boss := _make_trainer("Boss's Orders", "Supporter")

	var boss_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": boss,
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		boss_score <= end_score,
		"Boss should be held when there is no Raging Bolt attack window (boss=%f end=%f)" % [boss_score, end_score]
	)


func test_pal_pad_ignores_boss_only_before_bolt_online() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Iron Bundle", 100, 1), 0)
	player.discard_pile.append(_make_trainer("Boss's Orders", "Supporter"))
	var pal_pad := _make_trainer("Pal Pad")

	var pal_pad_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": pal_pad,
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		pal_pad_score <= end_score,
		"Pal Pad should not recover only Boss before the deck has an attack window (pal=%f end=%f)" % [pal_pad_score, end_score]
	)


func test_pokegear_cools_off_when_visible_hit_is_only_boss_without_attack_window() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(1)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Iron Bundle", 100, 1), 0)
	var pokegear := _make_trainer("Pokegear 3.0")
	var boss := _make_trainer("Boss's Orders", "Supporter")

	var gear_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": pokegear,
		"targets": [{"look_top_cards": [boss]}],
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		gear_score <= end_score,
		"Pokegear should not spend itself when the visible hit is only Boss and no attack is online (gear=%f end=%f)" % [gear_score, end_score]
	)


func test_raging_bolt_pressure_gap_requires_lightning_and_fighting() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Grass Energy", "G"))
	player.active_pokemon.attached_energy.append(_make_energy("Grass Energy", "G"))
	player.active_pokemon.attached_energy.append(_make_energy("Grass Energy", "G"))
	var lightning := _make_energy("Lightning Energy", "L")
	var grass := _make_energy("Grass Energy", "G")

	var lightning_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": lightning,
		"target_slot": player.active_pokemon,
	}, gs, 0)
	var grass_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": grass,
		"target_slot": player.active_pokemon,
	}, gs, 0)
	return assert_gt(
		lightning_score,
		grass_score + 250.0,
		"Raging Bolt should not treat three off-type energies as attack-ready; missing L/F must dominate (L=%f G=%f)" % [lightning_score, grass_score]
	)


func test_grass_attach_to_bolt_is_high_when_core_cost_ready_but_needs_fuel() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.active_pokemon.attached_energy.append(_make_energy("Fighting Energy", "F"))
	var ogerpon := _make_slot(_make_ogerpon_cd(), 0)
	player.bench.append(ogerpon)
	var grass := _make_energy("Grass Energy", "G")

	var bolt_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": grass,
		"target_slot": player.active_pokemon,
	}, gs, 0)
	var ogerpon_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": grass,
		"target_slot": ogerpon,
	}, gs, 0)
	return assert_gt(
		bolt_score,
		ogerpon_score + 100.0,
		"Once L+F are ready, the third basic Energy should fuel Bellowing Thunder before charging Ogerpon (Bolt=%f Ogerpon=%f)" % [bolt_score, ogerpon_score]
	)


func test_earthen_vessel_cools_after_ready_bolt_and_discard_fuel() -> String:
	var strategy = RagingBoltStrategyScript.new()
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_raging_bolt_cd(), 0)
	player.active_pokemon.attached_energy.append(_make_energy("Lightning Energy", "L"))
	player.active_pokemon.attached_energy.append(_make_energy("Fighting Energy", "F"))
	player.active_pokemon.attached_energy.append(_make_energy("Grass Energy", "G"))
	player.discard_pile.append(_make_energy("Grass Energy", "G"))
	player.discard_pile.append(_make_energy("Lightning Energy", "L"))
	player.discard_pile.append(_make_energy("Fighting Energy", "F"))
	var vessel := _make_trainer("Earthen Vessel")

	var vessel_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": vessel,
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		vessel_score <= end_score + 50.0,
		"Earthen Vessel should cool off once Raging Bolt is ready and discard fuel already exists (vessel=%f end=%f)" % [vessel_score, end_score]
	)
