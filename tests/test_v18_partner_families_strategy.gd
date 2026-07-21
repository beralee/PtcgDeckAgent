class_name TestV18PartnerFamiliesStrategy
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18PartnerFamilies.gd")
const DECK_DIR := "res://data/bundled_user/decks"

const ETHAN_HO_OH_DECK_ID := 800018539
const CYNTHIA_GARCHOMP_DECK_ID := 800018543
const ETHAN_TYPHLOSION_DECK_ID := 800018880


func test_partner_family_delegate_configures_all_three_deck_scoped_identities() -> String:
	var checks: Array[String] = []
	for deck_id: int in [ETHAN_HO_OH_DECK_ID, CYNTHIA_GARCHOMP_DECK_ID, ETHAN_TYPHLOSION_DECK_ID]:
		var strategy := _strategy_for_deck(deck_id)
		checks.append(assert_not_null(strategy, "Partner-family deck %d should configure its delegate" % deck_id))
		if strategy != null:
			checks.append(assert_eq(
				str(strategy.call("get_strategy_id")),
				_expected_delegate_id(deck_id),
				"Partner-family delegates should preserve their existing V18 identity contract"
			))
	return run_checks(checks)


func test_partner_family_turn_contracts_keep_the_v18_shape() -> String:
	var checks: Array[String] = []
	for deck_id: int in [ETHAN_HO_OH_DECK_ID, CYNTHIA_GARCHOMP_DECK_ID, ETHAN_TYPHLOSION_DECK_ID]:
		var strategy := _strategy_for_deck(deck_id)
		var state := _make_state()
		var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
		checks.append(assert_false(str(contract.get("id", "")).is_empty(), "Deck %d should emit a plan id" % deck_id))
		checks.append(assert_true(str(contract.get("phase", "")) in ["setup", "launch", "convert", "rebuild", "close"], "Deck %d should use a V18 phase" % deck_id))
		checks.append(assert_true(contract.get("owner", null) is Dictionary, "Deck %d should declare route ownership" % deck_id))
		checks.append(assert_true(contract.get("priorities", null) is Dictionary, "Deck %d should declare route priorities" % deck_id))
		var constraints: Dictionary = contract.get("constraints", {})
		checks.append(assert_true(constraints.has("forbid_engine_churn"), "Deck %d should preserve the churn guard" % deck_id))
		checks.append(assert_true(constraints.has("forbid_extra_bench_padding"), "Deck %d should preserve the bench guard" % deck_id))
	return run_checks(checks)


func test_ethans_ho_oh_concentrates_golden_flame_on_the_live_attacker() -> String:
	var strategy := _strategy_for_deck(ETHAN_HO_OH_DECK_ID)
	var state := _make_state()
	var player := state.players[0]
	var funded := _slot(_pokemon("阿响的凤王ex", "Basic", "", "R", "RRRR", "160"))
	funded.attached_energy.assign([
		_instance(_energy("基本火能量", "R")),
		_instance(_energy("基本火能量", "R")),
	])
	var empty := _slot(_pokemon("阿响的凤王ex", "Basic", "", "R", "RRRR", "160"))
	var off_route := _slot(_pokemon("阿响的火球鼠", "Basic", "", "R", "R", "30"))
	player.bench.assign([funded, empty, off_route])
	var step := {"id": "attach_fire_to_benched_ethan"}
	var context := {"game_state": state, "player_index": 0}
	var funded_score: float = strategy.call("score_interaction_target", funded, step, context)
	var empty_score: float = strategy.call("score_interaction_target", empty, step, context)
	var off_route_score: float = strategy.call("score_interaction_target", off_route, step, context)
	return run_checks([
		assert_true(funded_score >= empty_score + 500.0, "Golden Flame should finish a two-Energy Ho-Oh before spreading Energy"),
		assert_true(funded_score >= off_route_score + 1500.0, "Golden Flame should not accelerate an off-route Ethan Pokemon"),
	])


func test_ethans_ho_oh_switches_from_support_to_a_ready_ho_oh() -> String:
	var strategy := _strategy_for_deck(ETHAN_HO_OH_DECK_ID)
	var state := _make_state()
	var player := state.players[0]
	player.active_pokemon = _slot(_pokemon("梦幻ex", "Basic", "", "P", "C", "30"))
	var ready := _slot(_pokemon("阿响的凤王ex", "Basic", "", "R", "RRRR", "160"))
	for _index: int in 4:
		ready.attached_energy.append(_instance(_energy("基本火能量", "R")))
	var filler := _slot(_pokemon("炭小侍", "Basic", "", "R", "R", "20"))
	player.bench.assign([ready, filler])
	var step := {"id": "switch_to_active"}
	var context := {"game_state": state, "player_index": 0}
	var ready_score: float = strategy.call("score_handoff_target", ready, step, context)
	var filler_score: float = strategy.call("score_handoff_target", filler, step, context)
	return assert_true(ready_score >= filler_score + 1800.0, "A ready Ho-Oh should own the attack handoff")


func test_ethans_ho_oh_armarouge_preserves_the_more_funded_backup() -> String:
	var strategy := _strategy_for_deck(ETHAN_HO_OH_DECK_ID)
	var state := _make_state()
	var player := state.players[0]
	player.active_pokemon = _slot(_pokemon("阿响的凤王ex", "Basic", "", "R", "RRRR", "160"))
	var low_source := _slot(_pokemon("阿响的凤王ex", "Basic", "", "R", "RRRR", "160"))
	var low_fire := _instance(_energy("基本火能量", "R"))
	low_source.attached_energy.append(low_fire)
	var high_source := _slot(_pokemon("阿响的凤王ex", "Basic", "", "R", "RRRR", "160"))
	var high_fire := _instance(_energy("基本火能量", "R"))
	for energy: CardInstance in [
		high_fire,
		_instance(_energy("基本火能量", "R")),
		_instance(_energy("基本火能量", "R")),
	]:
		high_source.attached_energy.append(energy)
	player.bench.assign([low_source, high_source])
	var step := {"id": "move_fire_energy_from_bench_to_active"}
	var context := {"game_state": state, "player_index": 0}
	var low_score: float = strategy.call("score_interaction_target", low_fire, step, context)
	var high_score: float = strategy.call("score_interaction_target", high_fire, step, context)
	return assert_true(low_score >= high_score + 500.0, "Armarouge should pull Fire from the less-funded Ho-Oh first")


func test_ethans_typhlosion_routes_search_through_quilava_then_typhlosion() -> String:
	var strategy := _strategy_for_deck(ETHAN_TYPHLOSION_DECK_ID)
	var state := _make_state()
	var player := state.players[0]
	player.bench.append(_slot(_pokemon("阿响的火球鼠", "Basic", "", "R", "R", "30")))
	var quilava := _instance(_pokemon("阿响的火岩鼠", "Stage 1", "阿响的火球鼠", "R", "R", "40"))
	var typhlosion := _instance(_pokemon("阿响的火暴兽", "Stage 2", "阿响的火岩鼠", "R", "R", "40+"))
	var fire := _instance(_energy("基本火能量", "R"))
	var step := {"id": "search_cards"}
	var context := {"game_state": state, "player_index": 0}
	var quilava_score: float = strategy.call("score_interaction_target", quilava, step, context)
	var typhlosion_score: float = strategy.call("score_interaction_target", typhlosion, step, context)
	var fire_score: float = strategy.call("score_interaction_target", fire, step, context)
	player.bench[0].pokemon_stack.append(quilava)
	var live_typhlosion_score: float = strategy.call("score_interaction_target", typhlosion, step, context)
	return run_checks([
		assert_true(quilava_score >= typhlosion_score + 1000.0, "Ethan's Adventure should find the playable middle stage before a dead Stage 2"),
		assert_true(live_typhlosion_score >= fire_score + 700.0, "Once Quilava is in play, Ethan's Adventure should complete Typhlosion"),
	])


func test_ethans_typhlosion_turns_adventure_into_partner_blast_fuel() -> String:
	var strategy := _strategy_for_deck(ETHAN_TYPHLOSION_DECK_ID)
	var adventure := _instance(_trainer("阿响的冒险", "Supporter"))
	var fire := _instance(_energy("基本火能量", "R"))
	var rod := _instance(_trainer("厉害钓竿", "Item"))
	return run_checks([
		assert_true(int(strategy.call("get_discard_priority", adventure)) >= 90, "Ethan's Adventure should be a preferred discard once found"),
		assert_true(int(strategy.call("get_discard_priority", adventure)) >= int(strategy.call("get_discard_priority", fire)) + 60, "Partner Blast fuel should be discarded before Fire Energy"),
		assert_true(int(strategy.call("get_discard_priority", adventure)) >= int(strategy.call("get_discard_priority", rod)) + 40, "Recovery should survive while Adventure enters the discard pile"),
	])


func test_ethans_typhlosion_prefers_partner_blast_after_two_adventures() -> String:
	var strategy := _strategy_for_deck(ETHAN_TYPHLOSION_DECK_ID)
	var state := _make_state()
	var player := state.players[0]
	var typhlosion := _slot(_pokemon("阿响的火暴兽", "Stage 2", "阿响的火岩鼠", "R", "R", "40+"))
	typhlosion.attached_energy.append(_instance(_energy("基本火能量", "R")))
	player.active_pokemon = typhlosion
	player.discard_pile.assign([
		_instance(_trainer("阿响的冒险", "Supporter")),
		_instance(_trainer("阿响的冒险", "Supporter")),
	])
	var partner_score: float = strategy.call("score_action_absolute", {
		"kind": "attack", "source_slot": typhlosion, "attack_index": 0,
		"attack_name": "搭档爆破", "projected_damage": 160,
	}, state, 0)
	var end_score: float = strategy.call("score_action_absolute", {"kind": "end_turn"}, state, 0)
	return assert_true(partner_score >= end_score + 2500.0, "Two discarded Adventures should turn Partner Blast into the conversion route")


func test_cynthias_gabite_searches_the_live_evolution_before_padding() -> String:
	var strategy := _strategy_for_deck(CYNTHIA_GARCHOMP_DECK_ID)
	var state := _make_state()
	var player := state.players[0]
	player.bench.append(_slot(_pokemon("竹兰的尖牙陆鲨", "Stage 1", "竹兰的圆陆鲨", "F", "F", "40")))
	var garchomp := _instance(_pokemon("竹兰的烈咬陆鲨ex", "Stage 2", "竹兰的尖牙陆鲨", "F", "F", "100"))
	var spiritomb := _instance(_pokemon("竹兰的花岩怪", "Basic", "", "D", "C", "10x"))
	var step := {"id": "csv10c_named_pokemon_search"}
	var context := {"game_state": state, "player_index": 0}
	var garchomp_score: float = strategy.call("score_interaction_target", garchomp, step, context)
	var spiritomb_score: float = strategy.call("score_interaction_target", spiritomb, step, context)
	return assert_true(garchomp_score >= spiritomb_score + 1500.0, "King's Call should complete the live Garchomp chain before adding a situational Basic")


func test_partner_family_key_cards_match_english_names_and_uids() -> String:
	var typhlosion_strategy := _strategy_for_deck(ETHAN_TYPHLOSION_DECK_ID)
	var english_typhlosion := _instance(_pokemon("Ethan's Typhlosion", "Stage 2", "Ethan's Quilava", "R", "R", "40+"))
	var garchomp_strategy := _strategy_for_deck(CYNTHIA_GARCHOMP_DECK_ID)
	var uid_garchomp_data := _pokemon("Imported attacker", "Stage 2", "Cynthia's Gabite", "F", "F", "100")
	uid_garchomp_data.set_code = "CSV10C"
	uid_garchomp_data.card_index = "113"
	var uid_garchomp := _instance(uid_garchomp_data)
	return run_checks([
		assert_true(int(typhlosion_strategy.call("get_search_priority", english_typhlosion)) >= 900, "English Ethan identities should retain the Typhlosion route"),
		assert_true(int(garchomp_strategy.call("get_search_priority", uid_garchomp)) >= 900, "Card UID matching should retain the Garchomp route"),
	])


func test_partner_real_special_energy_ids_pay_their_printed_any_type_routes() -> String:
	var strategy := _strategy_for_deck(ETHAN_HO_OH_DECK_ID)
	var luminous_data := _load_card("CSV1C_127")
	var legacy_data := _load_card("CSV8C_207")
	var luminous := _instance(luminous_data)
	var legacy := _instance(legacy_data)
	var suppressed_target := _slot(_pokemon("阿响的凤王ex", "Basic", "", "R", "RRRR", "160"))
	suppressed_target.attached_energy.append(legacy)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var ho_oh := _slot(_pokemon("阿响的凤王ex", "Basic", "", "R", "RRRR", "160"))
	var filler := _slot(_pokemon("炭小侍", "Basic", "", "R", "R", "20"))
	player.bench.assign([ho_oh, filler])
	var luminous_to_ho_oh: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": luminous, "target_slot": ho_oh,
	}, state, 0)
	var luminous_to_filler: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": luminous, "target_slot": filler,
	}, state, 0)
	var legacy_route := _instance(_load_card("CSV8C_207"))
	var legacy_to_ho_oh: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": legacy_route, "target_slot": ho_oh,
	}, state, 0)
	var legacy_to_filler: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": legacy_route, "target_slot": filler,
	}, state, 0)
	return run_checks([
		assert_eq(str(luminous_data.effect_id), "540ee48bb93584e4bfe3d7f5d0ee0efc", "The real CSV1C_127 ID should anchor Luminous Energy recognition"),
		assert_eq(str(legacy_data.effect_id), "6f31b7241a181631016466e561f148f3", "The real CSV8C_207 ID should anchor Legacy Energy recognition"),
		assert_true(bool(strategy.call("_energy_pays", luminous, "R")), "Real Luminous Energy should pay Ho-Oh's Fire requirement"),
		assert_true(bool(strategy.call("_energy_pays", luminous, "D")), "Real Luminous Energy should also expose its Darkness route"),
		assert_true(bool(strategy.call("_energy_pays", legacy, "R")), "Real Legacy Energy should pay any typed requirement"),
		assert_false(bool(strategy.call("_energy_pays", luminous, "R", suppressed_target)), "Luminous Energy should stop paying Fire beside another Special Energy"),
		assert_true(bool(strategy.call("_energy_pays", luminous, "C", suppressed_target)), "A suppressed Luminous Energy should still pay Colorless"),
		assert_true(luminous_to_ho_oh >= luminous_to_filler + 3000.0, "Real Luminous Energy should follow Ho-Oh's Fire attachment route"),
		assert_true(legacy_to_ho_oh >= legacy_to_filler + 3000.0, "Real Legacy Energy should follow Ho-Oh's Fire attachment route"),
	])


func test_cynthias_real_fighting_and_luminous_ids_keep_the_543_energy_routes_separate() -> String:
	var strategy := _strategy_for_deck(CYNTHIA_GARCHOMP_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var garchomp := _slot(_pokemon("竹兰的烈咬陆鲨ex", "Stage 2", "竹兰的尖牙陆鲨", "F", "FF", "260"))
	var munkidori := _slot(_pokemon("愿增猿", "Basic", "", "D", "P", "30"))
	player.active_pokemon = garchomp
	player.bench.append(munkidori)
	var fighting := _instance(_load_card("CSVE1C_FIG"))
	var luminous := _instance(_load_card("CSV1C_127"))
	var fighting_to_garchomp: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": fighting, "target_slot": garchomp,
	}, state, 0)
	var luminous_to_munkidori_before_funding: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": luminous, "target_slot": munkidori,
	}, state, 0)
	garchomp.attached_energy.append(fighting)
	var luminous_to_munkidori_after_funding: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": luminous, "target_slot": munkidori,
	}, state, 0)
	var fighting_to_munkidori: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": _instance(_load_card("CSVE1C_FIG")), "target_slot": munkidori,
	}, state, 0)
	return run_checks([
		assert_true(fighting_to_garchomp >= luminous_to_munkidori_before_funding + 1500.0, "Deck 800018543 should fund Garchomp's Fighting route before the Munkidori bridge"),
		assert_true(luminous_to_munkidori_after_funding >= luminous_to_munkidori_before_funding + 700.0, "Once Garchomp is funded, Luminous Energy should open the Darkness route on Munkidori"),
		assert_true(luminous_to_munkidori_after_funding >= fighting_to_munkidori + 2000.0, "Basic Fighting Energy should remain on the Garchomp route instead of being assigned to Munkidori"),
	])


func test_cynthias_tm_evolution_prioritizes_gible_and_gabite() -> String:
	var strategy := _strategy_for_deck(CYNTHIA_GARCHOMP_DECK_ID)
	var gible := _slot(_pokemon("竹兰的圆陆鲨", "Basic", "", "F", "F", "20"))
	var budew := _slot(_pokemon("含羞苞", "Basic", "", "G", "", "0"))
	var gabite := _instance(_pokemon("竹兰的尖牙陆鲨", "Stage 1", "竹兰的圆陆鲨", "F", "F", "40"))
	var munkidori := _instance(_pokemon("愿增猿", "Basic", "", "D", "P", "30"))
	return run_checks([
		assert_true(
			float(strategy.call("score_interaction_target", gible, {"id": "evolution_bench"}, {})) >= float(strategy.call("score_interaction_target", budew, {"id": "evolution_bench"}, {})) + 1800.0,
			"TM Evolution should target Cynthia's Gible before a support pivot"
		),
		assert_true(
			float(strategy.call("score_interaction_target", gabite, {"id": "evolution_cards"}, {})) >= float(strategy.call("score_interaction_target", munkidori, {"id": "evolution_cards"}, {})) + 1800.0,
			"TM Evolution should choose Gabite for the selected Gible"
		),
	])


func test_cynthias_recovery_restores_fighting_energy_after_dragon_blast() -> String:
	var strategy := _strategy_for_deck(CYNTHIA_GARCHOMP_DECK_ID)
	var state := _make_state()
	var player := state.players[0]
	player.active_pokemon = _slot(_pokemon("竹兰的烈咬陆鲨ex", "Stage 2", "竹兰的尖牙陆鲨", "F", "F", "100"))
	var fighting := _instance(_energy("基本斗能量", "F"))
	var darkness := _instance(_energy("基本恶能量", "D"))
	var filler := _instance(_pokemon("含羞苞", "Basic", "", "G", "", "0"))
	player.discard_pile.assign([fighting, darkness, filler])
	var step := {"id": "night_stretcher_choice"}
	var context := {"game_state": state, "player_index": 0}
	var fighting_score: float = strategy.call("score_interaction_target", fighting, step, context)
	var darkness_score: float = strategy.call("score_interaction_target", darkness, step, context)
	return assert_true(fighting_score >= darkness_score + 1200.0, "Night Stretcher should rebuild Garchomp's Fighting attachment after Dragon Blast")


func test_cynthias_handoff_prefers_a_ready_garchomp() -> String:
	var strategy := _strategy_for_deck(CYNTHIA_GARCHOMP_DECK_ID)
	var ready := _slot(_pokemon("竹兰的烈咬陆鲨ex", "Stage 2", "竹兰的尖牙陆鲨", "F", "F", "100"))
	ready.attached_energy.append(_instance(_energy("基本斗能量", "F")))
	var spiritomb := _slot(_pokemon("竹兰的花岩怪", "Basic", "", "D", "C", "10x"))
	var step := {"id": "switch_to_active"}
	var ready_score: float = strategy.call("score_handoff_target", ready, step, {})
	var spiritomb_score: float = strategy.call("score_handoff_target", spiritomb, step, {})
	return assert_true(ready_score >= spiritomb_score + 1800.0, "A one-Energy Garchomp should take the attack handoff")


func _strategy_for_deck(deck_id: int) -> RefCounted:
	var deck := _load_deck(deck_id)
	if deck == null:
		return null
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	strategy.call("configure_from_deck", deck)
	return strategy


func _expected_delegate_id(deck_id: int) -> String:
	if deck_id == ETHAN_HO_OH_DECK_ID:
		return "v18_ethans_ho_oh_core"
	return "v18_stage2_core_%d" % deck_id


func _load_deck(deck_id: int) -> DeckData:
	var path := "%s/%d.json" % [DECK_DIR, deck_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


func _load_card(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	return state


func _slot(card_data: CardData) -> PokemonSlot:
	var result := PokemonSlot.new()
	result.pokemon_stack.append(_instance(card_data))
	return result


func _instance(card_data: CardData) -> CardInstance:
	return CardInstance.create(card_data, 0)


func _pokemon(
	name: String,
	stage: String,
	evolves_from: String,
	energy_type: String,
	attack_cost: String,
	damage: String
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.energy_type = energy_type
	card.hp = 200
	card.attacks = [{"name": "Test attack", "cost": attack_cost, "damage": damage}]
	return card


func _energy(name: String, provides: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_type = provides
	card.energy_provides = provides
	return card


func _trainer(name: String, card_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	return card
