class_name TestV18GardevoirVariantsStrategy
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18GardevoirVariants.gd")
const DECK_DIR := "res://data/bundled_user/decks"
const NO_BALLOON_DECK_ID := 800017097
const RABSCA_DECK_ID := 800018105

const GARDEVOIR_EFFECT_ID := "bd134d7d84e9f1a837a74b061fcb5f40"
const MUNKIDORI_EFFECT_ID := "66fee12502043db7d92b97b0d62b0f59"
const RELLOR_EFFECT_ID := "c2d6b5ec0bc365112105fea079a22fd7"
const RABSCA_EFFECT_ID := "4e41398ab9262f85910de1d9b3a4f027"


func test_real_decklists_configure_exact_variant_identities() -> String:
	var no_balloon := _load_deck(NO_BALLOON_DECK_ID)
	var rabsca := _load_deck(RABSCA_DECK_ID)
	var no_balloon_strategy := _strategy_for_deck(NO_BALLOON_DECK_ID)
	var rabsca_strategy := _strategy_for_deck(RABSCA_DECK_ID)
	return run_checks([
		assert_not_null(no_balloon, "The bundled No Balloon Gardevoir deck should load"),
		assert_not_null(rabsca, "The bundled Rabsca Gardevoir deck should load"),
		assert_eq(_deck_effect_count(no_balloon, GARDEVOIR_EFFECT_ID), 2, "No Balloon should contain two real Gardevoir ex"),
		assert_eq(_deck_effect_count(no_balloon, MUNKIDORI_EFFECT_ID), 3, "No Balloon should contain three real Munkidori"),
		assert_eq(_deck_effect_count(rabsca, RELLOR_EFFECT_ID), 1, "Rabsca should contain one real Rellor"),
		assert_eq(_deck_effect_count(rabsca, RABSCA_EFFECT_ID), 1, "Rabsca should contain one real Rabsca"),
		assert_eq(str(no_balloon_strategy.call("get_strategy_id")), "v18_gardevoir_variants_800017097_delegate", "No Balloon should have a deck-scoped identity"),
		assert_eq(str(rabsca_strategy.call("get_strategy_id")), "v18_gardevoir_variants_800018105_delegate", "Rabsca should have a deck-scoped identity"),
	])


func test_no_balloon_opening_keeps_a_free_pivot_and_two_ralts() -> String:
	var strategy := _strategy_for_deck(NO_BALLOON_DECK_ID)
	var player := PlayerState.new()
	player.hand.assign([
		_instance(_pokemon("Ralts", "Ralts", "Basic", "", "P", "C", "10")),
		_instance(_pokemon("Budew", "Budew", "Basic", "", "G", "", "10")),
		_instance(_pokemon("Ralts", "Ralts", "Basic", "", "P", "C", "10")),
		_instance(_pokemon("Drifloon", "Drifloon", "Basic", "", "P", "P", "10")),
		_instance(_pokemon("Munkidori", "Munkidori", "Basic", "", "P", "PC", "60", MUNKIDORI_EFFECT_ID)),
	])
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	var bench_names := _hand_names(player, plan.get("bench_hand_indices", []))
	return run_checks([
		assert_eq(_hand_name(player, int(plan.get("active_hand_index", -1))), "Budew", "Budew should absorb the opening Active slot"),
		assert_eq(bench_names.count("Ralts"), 2, "Both Ralts lanes should be established before support padding"),
		assert_true("Drifloon" in bench_names, "No Balloon should keep its one-prize attacker in the opening shell"),
		assert_false("Munkidori" in bench_names, "Munkidori must not crowd out the attacker before Darkness is useful"),
	])


func test_no_balloon_psychic_embrace_unlocks_the_active_retreat_bridge() -> String:
	var strategy := _strategy_for_deck(NO_BALLOON_DECK_ID)
	var state := _state_with_deck(20)
	var player: PlayerState = state.players[0]
	var active := _slot(_pokemon("Gardevoir ex", "Gardevoir ex", "Stage 2", "Kirlia", "P", "PPC", "190", GARDEVOIR_EFFECT_ID, 2, 310))
	active.attached_energy.append(_instance(_energy("Psychic Energy", "P")))
	var ready_drifloon := _slot(_pokemon("Drifloon", "Drifloon", "Basic", "", "P", "P", "10", "", 1, 70))
	ready_drifloon.attached_energy.append(_instance(_energy("Psychic Energy", "P")))
	var kirlia := _slot(_pokemon("Kirlia", "Kirlia", "Stage 1", "Ralts", "P", "C", "30", "", 2, 80))
	player.active_pokemon = active
	player.bench.assign([ready_drifloon, kirlia])
	player.discard_pile.append(_instance(_energy("Psychic Energy", "P")))
	var step := {"id": "embrace_target", "max_select": 1}
	var context := {"game_state": state, "player_index": 0, "all_items": [kirlia, active]}
	var active_score: float = strategy.call("score_interaction_target", active, step, context)
	var kirlia_score: float = strategy.call("score_interaction_target", kirlia, step, context)
	var picked: Array = strategy.call("pick_interaction_items", [kirlia, active], step, context)
	return run_checks([
		assert_true(active_score >= kirlia_score + 1200.0, "The final retreat Energy belongs on the trapped Active"),
		assert_true(picked.size() == 1 and picked[0] == active, "Psychic Embrace should deterministically unlock the ready attacker"),
	])


func test_no_balloon_manual_attachment_and_handoff_complete_the_same_route() -> String:
	var strategy := _strategy_for_deck(NO_BALLOON_DECK_ID)
	var state := _state_with_deck(20)
	var player: PlayerState = state.players[0]
	var active := _slot(_pokemon("Munkidori", "Munkidori", "Basic", "", "P", "PC", "60", MUNKIDORI_EFFECT_ID, 1, 110))
	var ready := _slot(_pokemon("Scream Tail", "Scream Tail", "Basic", "", "P", "PC", "80", "", 1, 90))
	ready.attached_energy.assign([_instance(_energy("Psychic Energy", "P")), _instance(_energy("Darkness Energy", "D"))])
	var kirlia := _slot(_pokemon("Kirlia", "Kirlia", "Stage 1", "Ralts", "P", "C", "30", "", 2, 80))
	player.active_pokemon = active
	player.bench.assign([ready, kirlia])
	var psychic := _instance(_energy("Psychic Energy", "P"))
	var bridge_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": psychic, "target_slot": active}, state, 0)
	var dead_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": psychic, "target_slot": kirlia}, state, 0)
	active.attached_energy.append(psychic)
	var retreat_score: float = strategy.call("score_action_absolute", {"kind": "retreat", "bench_target": ready}, state, 0)
	var kirlia_handoff: float = strategy.call("score_handoff_target", kirlia, {"id": "switch_target"}, {"game_state": state, "player_index": 0})
	var ready_handoff: float = strategy.call("score_handoff_target", ready, {"id": "switch_target"}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_true(bridge_score >= dead_score + 1000.0, "Manual Energy should pay retreat rather than strand on Kirlia"),
		assert_true(retreat_score >= 1200.0, "A paid retreat into the ready attacker should dominate setup churn"),
		assert_true(ready_handoff >= kirlia_handoff + 1200.0, "The ready one-prize attacker should own the handoff"),
	])


func test_rabsca_opening_reserves_rellor_and_two_ralts() -> String:
	var strategy := _strategy_for_deck(RABSCA_DECK_ID)
	var player := PlayerState.new()
	player.hand.assign([
		_instance(_pokemon("Mew ex", "Mew ex", "Basic", "", "P", "C", "10")),
		_instance(_pokemon("Ralts", "Ralts", "Basic", "", "P", "C", "10")),
		_instance(_pokemon("Rellor", "Rellor", "Basic", "", "G", "C", "30", RELLOR_EFFECT_ID)),
		_instance(_pokemon("Ralts", "Ralts", "Basic", "", "P", "C", "10")),
		_instance(_pokemon("Munkidori", "Munkidori", "Basic", "", "P", "PC", "60", MUNKIDORI_EFFECT_ID)),
	])
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	var bench_names := _hand_names(player, plan.get("bench_hand_indices", []))
	return run_checks([
		assert_eq(_hand_name(player, int(plan.get("active_hand_index", -1))), "Mew ex", "Mew ex should be the low-retreat opening pivot"),
		assert_eq(bench_names.count("Ralts"), 2, "Both Gardevoir lanes should be opened"),
		assert_true("Rellor" in bench_names, "Rellor must be reserved for the shield lane"),
		assert_false("Munkidori" in bench_names, "The shield lane should not be crowded out by optional support"),
	])


func test_rabsca_tm_evolution_picks_both_required_stage_one_lanes() -> String:
	var strategy := _strategy_for_deck(RABSCA_DECK_ID)
	var state := _state_with_deck(24)
	var player: PlayerState = state.players[0]
	var ralts := _slot(_pokemon("Ralts", "Ralts", "Basic", "", "P", "C", "10"))
	var rellor := _slot(_pokemon("Rellor", "Rellor", "Basic", "", "G", "C", "30", RELLOR_EFFECT_ID))
	var support := _slot(_pokemon("Munkidori", "Munkidori", "Basic", "", "P", "PC", "60", MUNKIDORI_EFFECT_ID))
	player.bench.assign([support, rellor, ralts])
	var kirlia := _instance(_pokemon("Kirlia", "Kirlia", "Stage 1", "Ralts", "P", "C", "30"))
	var rabsca := _instance(_pokemon("Rabsca", "Rabsca", "Stage 1", "Rellor", "G", "G", "10", RABSCA_EFFECT_ID))
	var filler := _instance(_pokemon("Filler", "Filler", "Stage 1", "Other", "C", "C", "10"))
	var context := {"game_state": state, "player_index": 0}
	var picked_slots: Array = strategy.call("pick_interaction_items", [support, rellor, ralts], {"id": "evolution_bench", "max_select": 2}, context)
	var picked_cards: Array = strategy.call("pick_interaction_items", [filler, rabsca, kirlia], {"id": "evolution_cards", "max_select": 2}, context)
	return run_checks([
		assert_true(picked_slots.size() == 2 and ralts in picked_slots and rellor in picked_slots, "TM Evolution should select Ralts and Rellor together"),
		assert_true(picked_cards.size() == 2 and kirlia in picked_cards and rabsca in picked_cards, "TM Evolution should fetch Kirlia and Rabsca together"),
	])


func test_rabsca_shield_becomes_mandatory_under_bench_pressure() -> String:
	var strategy := _strategy_for_deck(RABSCA_DECK_ID)
	var state := _state_with_deck(24)
	var player: PlayerState = state.players[0]
	var rellor := _slot(_pokemon("Rellor", "Rellor", "Basic", "", "G", "C", "30", RELLOR_EFFECT_ID))
	player.bench.append(rellor)
	state.players[1].active_pokemon = _slot(_pokemon("Spread attacker", "Spread attacker", "Basic", "", "P", "PC", "120", "", 1, 220, "This attack does 60 damage to 2 of your opponent's Benched Pokemon."))
	var rabsca := _instance(_pokemon("Rabsca", "Rabsca", "Stage 1", "Rellor", "G", "G", "10", RABSCA_EFFECT_ID))
	var off_route := _instance(_pokemon("Kirlia", "Kirlia", "Stage 1", "Ralts", "P", "C", "30"))
	var shield_score: float = strategy.call("score_action_absolute", {"kind": "evolve", "card": rabsca, "target_slot": rellor}, state, 0)
	var off_route_score: float = strategy.call("score_interaction_target", off_route, {"id": "search_pokemon"}, {"game_state": state, "player_index": 0})
	var shield_search: float = strategy.call("score_interaction_target", rabsca, {"id": "search_pokemon"}, {"game_state": state, "player_index": 0})
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {})
	return run_checks([
		assert_true(shield_score >= 2200.0, "Rabsca evolution should be mandatory against visible Bench damage"),
		assert_true(shield_search >= off_route_score + 800.0, "Search should complete the exposed shield lane"),
		assert_true(bool(contract.get("flags", {}).get("rabsca_guard_debt", false)), "The turn contract should expose Rabsca guard debt"),
	])


func test_rabsca_resources_are_discard_protected_only_while_guard_is_missing() -> String:
	var strategy := _strategy_for_deck(RABSCA_DECK_ID)
	var state := _state_with_deck(24)
	var player: PlayerState = state.players[0]
	player.bench.append(_slot(_pokemon("Rellor", "Rellor", "Basic", "", "G", "C", "30", RELLOR_EFFECT_ID)))
	state.players[1].active_pokemon = _slot(_pokemon("Spread attacker", "Spread attacker", "Basic", "", "P", "PC", "120", "", 1, 220, "Damage to your opponent's Benched Pokemon."))
	var rabsca := _instance(_pokemon("Rabsca", "Rabsca", "Stage 1", "Rellor", "G", "G", "10", RABSCA_EFFECT_ID))
	var psychic := _instance(_energy("Psychic Energy", "P"))
	var rabsca_discard: float = strategy.call("score_interaction_target", rabsca, {"id": "discard_card"}, {"game_state": state, "player_index": 0})
	var psychic_discard: float = strategy.call("score_interaction_target", psychic, {"id": "discard_card"}, {"game_state": state, "player_index": 0})
	player.bench[0].pokemon_stack.append(rabsca)
	var covered_score: float = strategy.call("score_interaction_target", rabsca, {"id": "discard_card"}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_true(psychic_discard >= rabsca_discard + 1000.0, "Psychic Energy should fuel Embrace before discarding the only shield"),
		assert_true(covered_score >= rabsca_discard + 500.0, "A spare Rabsca may become discardable after the shield is online"),
	])


func test_psychic_fuel_and_darkness_attachment_have_distinct_owners() -> String:
	var strategy := _strategy_for_deck(NO_BALLOON_DECK_ID)
	var state := _state_with_deck(24)
	var player: PlayerState = state.players[0]
	var gardevoir := _slot(_pokemon("Gardevoir ex", "Gardevoir ex", "Stage 2", "Kirlia", "P", "PPC", "190", GARDEVOIR_EFFECT_ID, 2, 310))
	var drifloon := _slot(_pokemon("Drifloon", "Drifloon", "Basic", "", "P", "P", "10", "", 1, 70))
	var munkidori := _slot(_pokemon("Munkidori", "Munkidori", "Basic", "", "P", "PC", "60", MUNKIDORI_EFFECT_ID, 1, 110))
	player.active_pokemon = drifloon
	player.bench.assign([gardevoir, munkidori])
	drifloon.attached_energy.append(_instance(_energy("Psychic Energy", "P")))
	drifloon.damage_counters = 40
	var darkness := _instance(_energy("Darkness Energy", "D"))
	var dark_on_munkidori: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": munkidori}, state, 0)
	var dark_on_gardevoir: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": gardevoir}, state, 0)
	var psychic := _instance(_energy("Psychic Energy", "P"))
	var psychic_discard: float = strategy.call("score_interaction_target", psychic, {"id": "discard_card"}, {"game_state": state, "player_index": 0})
	var darkness_discard: float = strategy.call("score_interaction_target", darkness, {"id": "discard_card"}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_true(dark_on_munkidori >= dark_on_gardevoir + 1800.0, "Darkness should activate Adrena-Brain, not become dead Gardevoir Energy"),
		assert_true(psychic_discard >= darkness_discard + 300.0, "Psychic should be the first discard while Embrace fuel is empty"),
	])


func test_prize_exchange_prefers_one_prize_attackers_over_rule_box_padding() -> String:
	var strategy := _strategy_for_deck(NO_BALLOON_DECK_ID)
	var state := _state_with_deck(16)
	var player: PlayerState = state.players[0]
	var drifloon := _slot(_pokemon("Drifloon", "Drifloon", "Basic", "", "P", "P", "10", "", 1, 70))
	drifloon.attached_energy.append(_instance(_energy("Psychic Energy", "P")))
	var clefairy := _slot(_pokemon("Lillie's Clefairy ex", "Lillie's Clefairy ex", "Basic", "", "P", "PC", "20", "", 1, 190))
	clefairy.attached_energy.assign([_instance(_energy("Psychic Energy", "P")), _instance(_energy("Psychic Energy", "P"))])
	player.bench.assign([drifloon, clefairy])
	var context := {"game_state": state, "player_index": 0}
	var one_prize_score: float = strategy.call("score_handoff_target", drifloon, {"id": "send_out"}, context)
	var two_prize_score: float = strategy.call("score_handoff_target", clefairy, {"id": "send_out"}, context)
	return assert_true(one_prize_score >= two_prize_score + 900.0, "The equivalent attack route should preserve the one-prize exchange")


func test_real_scream_tail_is_not_ready_until_the_damage_scaling_route_is_live() -> String:
	var strategy := _strategy_for_deck(NO_BALLOON_DECK_ID)
	var state := _state_with_deck(16)
	var player: PlayerState = state.players[0]
	var scream_tail := _slot(_load_card("CSV6C", "065"))
	scream_tail.attached_energy.append(_instance(_energy("Psychic Energy", "P")))
	var drifloon := _slot(_load_card("CSV2C", "060"))
	drifloon.attached_energy.assign([_instance(_energy("Psychic Energy", "P")), _instance(_energy("Psychic Energy", "P"))])
	drifloon.damage_counters = 40
	player.bench.assign([scream_tail, drifloon])
	var context := {"game_state": state, "player_index": 0}
	var cold_score: float = strategy.call("score_handoff_target", scream_tail, {"id": "send_out"}, context)
	var drifloon_score: float = strategy.call("score_handoff_target", drifloon, {"id": "send_out"}, context)
	scream_tail.attached_energy.append(_instance(_energy("Darkness Energy", "D")))
	scream_tail.damage_counters = 40
	var live_score: float = strategy.call("score_handoff_target", scream_tail, {"id": "send_out"}, context)
	return run_checks([
		assert_true(drifloon_score >= cold_score + 900.0, "A 30-damage slap must not steal the handoff from a live Balloon Bomb"),
		assert_true(live_score >= 2800.0, "Damaged, fully powered Scream Tail should become a real one-prize handoff owner"),
	])


func test_real_strong_opening_orders_produce_legal_variant_setup() -> String:
	var checks: Array[String] = []
	for deck_id: int in [NO_BALLOON_DECK_ID, RABSCA_DECK_ID]:
		var order_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/bundled_user/ai_fixed_deck_orders/%d.json" % deck_id
		))
		var player := PlayerState.new()
		if order_raw is Dictionary:
			var entries: Array = (order_raw as Dictionary).get("top_to_bottom", [])
			for index: int in mini(7, entries.size()):
				var entry: Dictionary = entries[index]
				player.hand.append(_instance(_load_card(str(entry.get("set_code", "")), str(entry.get("card_index", "")))))
		var strategy := _strategy_for_deck(deck_id)
		var plan: Dictionary = strategy.call("plan_opening_setup", player)
		var active_index := int(plan.get("active_hand_index", -1))
		checks.append(assert_eq(player.hand.size(), 7, "Strong mode should expose exactly seven setup cards for deck %d" % deck_id))
		checks.append(assert_true(active_index >= 0 and active_index < player.hand.size(), "Strong opening should select a legal Active for deck %d" % deck_id))
		if active_index >= 0 and active_index < player.hand.size():
			checks.append(assert_eq(str(player.hand[active_index].card_data.stage), "Basic", "Strong opening Active must be a Basic for deck %d" % deck_id))
		var bench_indices: Array = plan.get("bench_hand_indices", [])
		checks.append(assert_true(bench_indices.size() >= 1, "Strong opening should establish at least one Bench route for deck %d" % deck_id))
	return run_checks(checks)


func test_low_deck_guard_stops_draw_churn_and_keeps_the_attack_route() -> String:
	var strategy := _strategy_for_deck(NO_BALLOON_DECK_ID)
	var state := _state_with_deck(5)
	var player: PlayerState = state.players[0]
	var drifloon := _slot(_pokemon("Drifloon", "Drifloon", "Basic", "", "P", "P", "10", "", 1, 70))
	drifloon.attached_energy.append(_instance(_energy("Psychic Energy", "P")))
	var kirlia := _slot(_pokemon("Kirlia", "Kirlia", "Stage 1", "Ralts", "P", "C", "30", "", 2, 80))
	player.active_pokemon = drifloon
	player.bench.append(kirlia)
	var draw_score: float = strategy.call("score_action_absolute", {"kind": "use_ability", "source_slot": kirlia, "ability_name": "Refinement"}, state, 0)
	var attack_score: float = strategy.call("score_action_absolute", {"kind": "attack", "source_slot": drifloon, "projected_damage": 90, "projected_knockout": false}, state, 0)
	var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {})
	return run_checks([
		assert_true(draw_score <= -1800.0, "Refinement should stop before a self-inflicted deck-out"),
		assert_true(attack_score >= draw_score + 2500.0, "A live attack should convert instead of drawing"),
		assert_true(bool(contract.get("constraints", {}).get("forbid_engine_churn", false)), "The low-deck contract should hard-stop engine churn"),
	])


func test_normal_and_strong_use_the_same_variant_contract() -> String:
	var checks: Array[String] = []
	for deck_id: int in [NO_BALLOON_DECK_ID, RABSCA_DECK_ID]:
		var normal := _strategy_for_deck(deck_id)
		var strong := _strategy_for_deck(deck_id)
		var state := _state_with_deck(30)
		var normal_contract: Dictionary = normal.call("build_turn_contract", state, 0, {"strong_fixed_opening": false})
		var strong_contract: Dictionary = strong.call("build_turn_contract", state, 0, {"strong_fixed_opening": true})
		checks.append(assert_eq(normal_contract.get("owner", {}), strong_contract.get("owner", {}), "Opening mode must not fork route ownership for deck %d" % deck_id))
		checks.append(assert_eq(normal_contract.get("priorities", {}), strong_contract.get("priorities", {}), "Opening mode must not fork tactical priorities for deck %d" % deck_id))
		checks.append(assert_true(normal_contract.get("constraints", null) is Dictionary, "Normal mode should expose constraints"))
		checks.append(assert_true(strong_contract.get("constraints", null) is Dictionary, "Strong mode should expose constraints"))
	return run_checks(checks)


func _strategy_for_deck(deck_id: int) -> RefCounted:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	strategy.call("configure_from_deck", _load_deck(deck_id))
	return strategy


func _load_deck(deck_id: int) -> DeckData:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%d.json" % [DECK_DIR, deck_id]))
	return DeckData.from_dict(raw) if raw is Dictionary else null


func _deck_effect_count(deck: DeckData, effect_id: String) -> int:
	var total := 0
	if deck == null:
		return total
	for entry_variant: Variant in deck.cards:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("effect_id", "")) == effect_id:
			total += int((entry_variant as Dictionary).get("count", 0))
	return total


func _state_with_deck(deck_size: int) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	for index: int in deck_size:
		player.deck.append(_instance(_trainer("Deck card %d" % index)))
	for index: int in 6:
		player.prizes.append(_instance(_trainer("Prize %d" % index)))
		opponent.prizes.append(_instance(_trainer("Opponent prize %d" % index)))
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	return state


func _pokemon(
	name: String,
	name_en: String,
	stage: String,
	evolves_from: String,
	energy_type: String,
	cost: String,
	damage: String,
	effect_id: String = "",
	retreat_cost: int = 1,
	hp: int = 100,
	attack_text: String = ""
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.energy_type = energy_type
	card.effect_id = effect_id
	card.retreat_cost = retreat_cost
	card.hp = hp
	card.attacks = [{"name": "Test attack", "cost": cost, "damage": damage, "text": attack_text}]
	return card


func _energy(name: String, provides: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_provides = provides
	return card


func _trainer(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Supporter"
	return card


func _load_card(set_code: String, card_index: String) -> CardData:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s_%s.json" % [set_code, card_index]
	))
	return CardData.from_dict(raw) if raw is Dictionary else CardData.new()


func _instance(data: CardData) -> CardInstance:
	return CardInstance.create(data, 0)


func _slot(data: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_instance(data))
	return slot


func _hand_name(player: PlayerState, index: int) -> String:
	if index < 0 or index >= player.hand.size():
		return ""
	var card: CardInstance = player.hand[index]
	return str(card.card_data.name_en) if card != null and card.card_data != null else ""


func _hand_names(player: PlayerState, indices: Array) -> Array[String]:
	var names: Array[String] = []
	for index_variant: Variant in indices:
		names.append(_hand_name(player, int(index_variant)))
	return names
