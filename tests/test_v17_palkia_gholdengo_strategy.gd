class_name TestV17PalkiaGholdengoStrategy
extends TestBase

const StrategyPalkiaGholdengo = preload("res://scripts/ai/DeckStrategy17PalkiaGholdengo.gd")


func _pokemon(
	pname: String,
	energy_type: String = "C",
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	evolves_from: String = "",
	retreat_cost: int = 1
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.mechanic = mechanic
	cd.evolves_from = evolves_from
	cd.retreat_cost = retreat_cost
	return cd


func _trainer(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	return cd


func _energy(pname: String, provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Basic Energy"
	cd.energy_type = provides
	cd.energy_provides = provides
	return cd


func _card(cd: CardData, owner_index: int = 0) -> CardInstance:
	return CardInstance.create(cd, owner_index)


func _slot(cd: CardData, owner_index: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_card(cd, owner_index))
	return slot


func _attach(slot: PokemonSlot, provides: String, count: int) -> void:
	for i: int in count:
		slot.attached_energy.append(_card(_energy("%s Energy %d" % [provides, i], provides), 0))


func _game_state() -> GameState:
	var gs := GameState.new()
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", "L", 220, "Basic", "ex"), 1)
	gs.players.append(player)
	gs.players.append(opponent)
	return gs


func test_ready_gholdengo_preserves_extra_hand_energy_for_make_it_rain() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	_attach(player.active_pokemon, "M", 1)
	var hand_energy := _card(_energy("Basic Metal Energy", "M"), 0)
	var superior := _card(_trainer("Superior Energy Retrieval"), 0)
	player.hand.append(hand_energy)
	player.hand.append(superior)
	player.hand.append(_card(_trainer("Nest Ball"), 0))
	player.hand.append(_card(_trainer("Night Stretcher"), 0))
	for i: int in 4:
		player.discard_pile.append(_card(_energy("Discard Metal Energy %d" % i, "M"), 0))

	var extra_attach_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": hand_energy,
		"target_slot": player.active_pokemon,
	}, gs, 0)
	var recovery_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": superior,
	}, gs, 0)

	return run_checks([
		assert_true(recovery_score > extra_attach_score, "Energy recovery should outrank spending Make It Rain fuel on a ready Gholdengo when recovery creates a stronger burst (recovery=%f attach=%f)" % [recovery_score, extra_attach_score]),
	])


func test_opening_setup_leads_gimmighoul_over_lightning_weak_palkia_v() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var player := PlayerState.new()
	player.player_index = 0
	player.hand.append(_card(_pokemon("Origin Forme Palkia V", "W", 220, "Basic", "V", "", 2), 0))
	player.hand.append(_card(_pokemon("Gimmighoul", "M", 70, "Basic", "", "", 1), 0))
	player.hand.append(_card(_pokemon("Manaphy", "W", 70, "Basic", "", "", 1), 0))

	var plan: Dictionary = strategy.plan_opening_setup(player)
	var active_idx := int(plan.get("active_hand_index", -1))
	var bench_indices: Array = plan.get("bench_hand_indices", [])
	var active_name := ""
	if active_idx >= 0 and active_idx < player.hand.size():
		active_name = player.hand[active_idx].card_data.name_en

	return run_checks([
		assert_eq(active_name, "Gimmighoul", "17.0 Gholdengo should open Gimmighoul active and keep Palkia V as a bench setup piece"),
		assert_true(bench_indices.has(0), "Opening setup should still bench Palkia V when available"),
	])


func test_critical_deck_suppresses_dead_ciphermaniac_and_gust() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	_attach(player.active_pokemon, "M", 1)
	for i: int in 2:
		player.deck.append(_card(_trainer("Deck filler %d" % i), 0))
	var ciphermaniac := _card(_trainer("Ciphermaniac's Codebreaking", "Supporter"), 0)
	var boss := _card(_trainer("Boss's Orders", "Supporter"), 0)

	var cipher_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": ciphermaniac,
	}, gs, 0)
	var boss_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": boss,
	}, gs, 0)

	return run_checks([
		assert_true(cipher_score <= 60.0, "Critical deck should not spend Ciphermaniac without an immediate attack route (score=%f)" % cipher_score),
		assert_true(boss_score <= 80.0, "Critical deck should not gust when the active attacker cannot convert a KO (score=%f)" % boss_score),
	])


func test_low_damage_make_it_rain_waits_for_energy_recovery_or_draw() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	_attach(player.active_pokemon, "M", 1)
	var superior := _card(_trainer("Superior Energy Retrieval"), 0)
	player.hand.append(_card(_energy("Basic Metal Energy", "M"), 0))
	player.hand.append(superior)
	player.hand.append(_card(_trainer("Nest Ball"), 0))
	player.hand.append(_card(_trainer("Night Stretcher"), 0))
	for i: int in 20:
		player.deck.append(_card(_trainer("Deck filler %d" % i), 0))
	for i: int in 4:
		player.discard_pile.append(_card(_energy("Discard Energy %d" % i, "W"), 0))

	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Make It Rain",
		"projected_damage": 50,
	}, gs, 0)
	var recovery_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": superior,
	}, gs, 0)
	var draw_score: float = strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": player.active_pokemon,
		"ability_index": 0,
	}, gs, 0)

	return run_checks([
		assert_true(attack_score <= 360.0, "A 50-damage Make It Rain should be held when recovery/draw can build burst (attack=%f)" % attack_score),
		assert_true(recovery_score > attack_score + 400.0, "Superior Energy Retrieval should outrank weak Make It Rain when it creates a large burst (recovery=%f attack=%f)" % [recovery_score, attack_score]),
		assert_true(draw_score > attack_score, "Gholdengo draw should outrank a weak non-lethal Make It Rain (draw=%f attack=%f)" % [draw_score, attack_score]),
	])


func test_gholdengo_draws_before_nonlethal_make_it_rain_when_not_thin() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	_attach(player.active_pokemon, "M", 1)
	for i: int in 3:
		player.hand.append(_card(_energy("Basic Energy %d" % i, "M"), 0))
	for i: int in 20:
		player.deck.append(_card(_trainer("Deck filler %d" % i), 0))
	gs.players[1].active_pokemon.damage_counters = 0

	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 0,
		"attack_name": "Make It Rain",
		"projected_damage": 150,
	}, gs, 0)
	var draw_score: float = strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": player.active_pokemon,
		"ability_index": 0,
	}, gs, 0)

	return assert_true(draw_score > attack_score, "Active Gholdengo should use its safe draw before a non-lethal Make It Rain when the deck is not thin (draw=%f attack=%f)" % [draw_score, attack_score])


func test_gholdengo_draws_before_lethal_make_it_rain_when_deck_is_safe() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	_attach(player.active_pokemon, "M", 1)
	for i: int in 5:
		player.hand.append(_card(_energy("Basic Energy %d" % i, "M"), 0))
	for i: int in 20:
		player.deck.append(_card(_trainer("Deck filler %d" % i), 0))

	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 0,
		"attack_name": "Make It Rain",
		"projected_damage": 250,
	}, gs, 0)
	var draw_score: float = strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": player.active_pokemon,
		"ability_index": 0,
	}, gs, 0)

	return assert_true(draw_score > attack_score, "Active Gholdengo should take the free draw before a lethal Make It Rain while the deck is safe (draw=%f attack=%f)" % [draw_score, attack_score])


func test_make_it_rain_burst_outranks_nonlethal_churn_when_loaded() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	_attach(player.active_pokemon, "M", 1)
	for i: int in 5:
		player.hand.append(_card(_energy("Basic Energy %d" % i, "M"), 0))
	var ciphermaniac := _card(_trainer("Ciphermaniac's Codebreaking", "Supporter"), 0)
	player.hand.append(ciphermaniac)

	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Make It Rain",
		"projected_damage": 250,
	}, gs, 0)
	var churn_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": ciphermaniac,
	}, gs, 0)

	return assert_true(attack_score > churn_score + 500.0, "Loaded Make It Rain should convert before extra setup churn (attack=%f churn=%f)" % [attack_score, churn_score])


func test_gholdengo_make_it_rain_requires_attached_metal_energy() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	_attach(player.active_pokemon, "W", 1)
	for i: int in 4:
		player.hand.append(_card(_energy("Basic Metal Energy %d" % i, "M"), 0))

	var prediction: Dictionary = strategy.predict_attacker_damage(player.active_pokemon, player.hand.size())
	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_name": "Make It Rain",
		"projected_damage": 200,
	}, gs, 0)

	return run_checks([
		assert_false(bool(prediction.get("can_attack", true)), "Gholdengo should not model Make It Rain as ready without an attached Metal Energy"),
		assert_eq(int(prediction.get("damage", -1)), 0, "Gholdengo damage projection should be zero without Metal attached"),
		assert_true(attack_score <= -900.0, "Illegal no-Metal Make It Rain route should be rejected (score=%f)" % attack_score),
	])


func test_manual_attach_prefers_metal_on_unready_gholdengo() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	var metal := _card(_energy("Basic Metal Energy", "M"), 0)
	var water := _card(_energy("Basic Water Energy", "W"), 0)

	var metal_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": metal,
		"target_slot": player.active_pokemon,
	}, gs, 0)
	var water_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": water,
		"target_slot": player.active_pokemon,
	}, gs, 0)

	return run_checks([
		assert_true(metal_score > water_score + 700.0, "Unready Gholdengo should take Metal before off-type Make It Rain fuel (metal=%f water=%f)" % [metal_score, water_score]),
		assert_true(water_score <= 120.0, "Off-type first attachment to Gholdengo should stay low priority (score=%f)" % water_score),
	])


func test_manual_attach_prefers_water_on_unready_palkia() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Origin Forme Palkia V", "W", 220, "Basic", "V", "", 2), 0)
	var water := _card(_energy("Basic Water Energy", "W"), 0)
	var metal := _card(_energy("Basic Metal Energy", "M"), 0)

	var water_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": water,
		"target_slot": player.active_pokemon,
	}, gs, 0)
	var metal_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": metal,
		"target_slot": player.active_pokemon,
	}, gs, 0)

	return assert_true(water_score > metal_score + 500.0, "Palkia should take Water Energy before off-type fuel (water=%f metal=%f)" % [water_score, metal_score])


func test_search_target_prefers_gholdengo_evolution_over_palkia_v_when_gimmighoul_ready() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gimmighoul", "M", 70, "Basic", "", "", 1), 0)
	var gholdengo := _card(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	var palkia := _card(_pokemon("Origin Forme Palkia V", "W", 220, "Basic", "V", "", 2), 0)
	var context := {"game_state": gs, "player_index": 0}

	var gholdengo_score: float = strategy.score_interaction_target(gholdengo, {"id": "search_pokemon"}, context)
	var palkia_score: float = strategy.score_interaction_target(palkia, {"id": "search_pokemon"}, context)
	var picked: Array = strategy.pick_interaction_items([palkia, gholdengo], {"id": "search_pokemon", "max_select": 1}, context)
	var picked_name := ""
	if not picked.is_empty() and picked[0] is CardInstance:
		picked_name = (picked[0] as CardInstance).card_data.name_en

	return run_checks([
		assert_true(gholdengo_score > palkia_score + 80.0, "Search should prioritize evolving ready Gimmighoul before the fragile 1-1 Palkia line (gholdengo=%f palkia=%f)" % [gholdengo_score, palkia_score]),
		assert_true(picked_name == "Gholdengo ex", "Search picker should choose Gholdengo ex before Palkia V when Gimmighoul is ready (picked=%s)" % picked_name),
	])


func test_basic_search_prefers_palkia_v_over_duplicate_gimmighoul_after_first_gimmighoul() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gimmighoul", "M", 70, "Basic", "", "", 1), 0)
	var backup_gimmighoul := _card(_pokemon("Gimmighoul", "M", 70, "Basic", "", "", 1), 0)
	var palkia := _card(_pokemon("Origin Forme Palkia V", "W", 220, "Basic", "V", "", 2), 0)
	var context := {"game_state": gs, "player_index": 0}

	var gimmighoul_score: float = strategy.score_interaction_target(backup_gimmighoul, {"id": "basic_pokemon"}, context)
	var palkia_score: float = strategy.score_interaction_target(palkia, {"id": "basic_pokemon"}, context)
	var picked: Array = strategy.pick_interaction_items([backup_gimmighoul, palkia], {"id": "basic_pokemon", "max_select": 1}, context)
	var picked_name := ""
	if not picked.is_empty() and picked[0] is CardInstance:
		picked_name = (picked[0] as CardInstance).card_data.name_en

	return run_checks([
		assert_true(palkia_score > gimmighoul_score + 80.0, "Basic search should establish the one-of Palkia V before taking a third Gimmighoul (palkia=%f gimmighoul=%f)" % [palkia_score, gimmighoul_score]),
		assert_eq(picked_name, "Origin Forme Palkia V", "Basic search picker should choose Palkia V after the first Gimmighoul is online"),
	])


func test_poffin_stops_being_premium_when_only_palkia_v_is_missing() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gimmighoul", "M", 70, "Basic", "", "", 1), 0)
	player.bench.append(_slot(_pokemon("Gimmighoul", "M", 70, "Basic", "", "", 1), 0))
	var poffin := _card(_trainer("Buddy-Buddy Poffin"), 0)
	var nest := _card(_trainer("Nest Ball"), 0)

	var poffin_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": poffin}, gs, 0)
	var nest_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": nest}, gs, 0)

	return run_checks([
		assert_true(nest_score > poffin_score + 120.0, "When Gimmighoul is already established, Nest Ball should fix missing Palkia V before Poffin fetches support filler (nest=%f poffin=%f)" % [nest_score, poffin_score]),
		assert_true(poffin_score <= 300.0, "Poffin should not remain a premium action when the only opening gap is Palkia V (poffin=%f)" % poffin_score),
	])


func test_ready_gholdengo_keeps_hand_energy_as_make_it_rain_fuel() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	_attach(player.active_pokemon, "M", 1)
	var hand_energy := _card(_energy("Basic Metal Energy", "M"), 0)
	player.hand.append(hand_energy)
	for i: int in 16:
		player.deck.append(_card(_trainer("Deck filler %d" % i), 0))

	var attach_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": hand_energy,
		"target_slot": player.active_pokemon,
	}, gs, 0)
	var draw_score: float = strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": player.active_pokemon,
		"ability_index": 0,
	}, gs, 0)

	return run_checks([
		assert_true(attach_score <= 160.0, "Ready Gholdengo should not spend the only hand Energy as extra attachment fuel (attach=%f)" % attach_score),
		assert_true(draw_score > attach_score, "Ready Gholdengo should draw before wasting Make It Rain fuel on extra attachment (draw=%f attach=%f)" % [draw_score, attach_score]),
	])


func test_ready_gholdengo_rejects_extra_off_type_attachment_even_with_large_hand() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	_attach(player.active_pokemon, "M", 1)
	var dark := _card(_energy("Basic Darkness Energy", "D"), 0)
	player.hand.append(dark)
	for i: int in 6:
		player.hand.append(_card(_energy("Basic Fuel Energy %d" % i, "W"), 0))
	for i: int in 16:
		player.deck.append(_card(_trainer("Deck filler %d" % i), 0))

	var attach_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": dark,
		"target_slot": player.active_pokemon,
	}, gs, 0)
	var draw_score: float = strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": player.active_pokemon,
		"ability_index": 0,
	}, gs, 0)

	return run_checks([
		assert_true(attach_score <= 160.0, "Ready Gholdengo should not turn off-type hand Energy into dead attachments even with a large hand (attach=%f)" % attach_score),
		assert_true(draw_score > attach_score, "Ready Gholdengo should draw or convert before padding itself with off-type Energy (draw=%f attach=%f)" % [draw_score, attach_score]),
	])


func test_energy_search_prefers_core_metal_and_water_before_off_type_fuel() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_pokemon("Gimmighoul", "M", 70, "Basic", "", "", 1), 0)
	player.bench.append(_slot(_pokemon("Origin Forme Palkia V", "W", 220, "Basic", "V", "", 2), 0))
	var lightning := _card(_energy("Basic Lightning Energy", "L"), 0)
	var psychic := _card(_energy("Basic Psychic Energy", "P"), 0)
	var water := _card(_energy("Basic Water Energy", "W"), 0)
	var metal := _card(_energy("Basic Metal Energy", "M"), 0)
	var context := {"game_state": gs, "player_index": 0}

	var metal_score: float = strategy.score_interaction_target(metal, {"id": "search_energy"}, context)
	var water_score: float = strategy.score_interaction_target(water, {"id": "search_energy"}, context)
	var lightning_score: float = strategy.score_interaction_target(lightning, {"id": "search_energy"}, context)
	var psychic_score: float = strategy.score_interaction_target(psychic, {"id": "search_energy"}, context)
	var picked: Array = strategy.pick_interaction_items([lightning, psychic, water, metal], {"id": "search_energy", "max_select": 2}, context)
	var picked_types: Array[String] = []
	for item: Variant in picked:
		if item is CardInstance:
			picked_types.append((item as CardInstance).card_data.energy_provides)

	return run_checks([
		assert_true(metal_score > lightning_score + 120.0, "Energy search should secure Metal for the Gholdengo line before off-type fuel (metal=%f lightning=%f)" % [metal_score, lightning_score]),
		assert_true(water_score > psychic_score + 80.0, "Energy search should secure Water for the Palkia line before off-type fuel (water=%f psychic=%f)" % [water_score, psychic_score]),
		assert_true(picked_types.has("M") and picked_types.has("W"), "Two-card Energy search should pick Metal and Water before off-type fuel (picked=%s)" % str(picked_types)),
	])


func test_gust_ko_line_outranks_hitting_large_dragapult_active() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	_attach(player.active_pokemon, "M", 1)
	for i: int in 4:
		player.hand.append(_card(_energy("Basic Energy %d" % i, "M"), 0))
	var boss := _card(_trainer("Boss's Orders", "Supporter"), 0)
	player.hand.append(boss)
	opponent.active_pokemon = _slot(_pokemon("Dragapult ex", "N", 320, "Stage 2", "ex", "Drakloak", 2), 1)
	opponent.bench.append(_slot(_pokemon("Lumineon V", "W", 170, "Basic", "V", "", 2), 1))

	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 0,
		"attack_name": "Make It Rain",
		"projected_damage": 200,
	}, gs, 0)
	var boss_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": boss,
	}, gs, 0)

	return assert_true(boss_score > attack_score + 150.0, "Gholdengo should gust a bench KO instead of dumping four Energy into a nonlethal Dragapult active (boss=%f attack=%f)" % [boss_score, attack_score])


func test_gust_target_picker_prefers_reachable_two_prize_bench_target() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	_attach(player.active_pokemon, "M", 1)
	for i: int in 4:
		player.hand.append(_card(_energy("Basic Energy %d" % i, "M"), 0))
	opponent.active_pokemon = _slot(_pokemon("Dragapult ex", "N", 320, "Stage 2", "ex", "Drakloak", 2), 1)
	var dusknoir := _slot(_pokemon("Dusknoir", "P", 160, "Stage 2", "", "Dusclops", 3), 1)
	var lumineon := _slot(_pokemon("Lumineon V", "W", 170, "Basic", "V", "", 2), 1)
	var dragapult := _slot(_pokemon("Dragapult ex", "N", 320, "Stage 2", "ex", "Drakloak", 2), 1)
	opponent.bench.append(dusknoir)
	opponent.bench.append(lumineon)
	opponent.bench.append(dragapult)

	var context := {"game_state": gs, "player_index": 0}
	var picked: Array = strategy.pick_interaction_items(
		opponent.bench,
		{"id": "opponent_bench_target", "max_select": 1},
		context
	)
	var picked_name := ""
	if not picked.is_empty() and picked[0] is PokemonSlot:
		picked_name = (picked[0] as PokemonSlot).get_card_data().name_en

	return assert_eq(picked_name, "Lumineon V", "Gust target selection should prefer a reachable two-prize KO before a bulky Dragapult ex or one-prize engine")


func test_trace_regression_never_routes_energy_evolution_or_handoff_to_knocked_out_slots() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gs := _game_state()
	var player: PlayerState = gs.players[0]
	var live_gholdengo := _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	var knocked_gimmighoul := _slot(_pokemon("Gimmighoul", "M", 70, "Basic", "", "", 1), 0)
	knocked_gimmighoul.damage_counters = 70
	player.active_pokemon = live_gholdengo
	player.bench.append(knocked_gimmighoul)
	var metal := _card(_energy("Basic Metal Energy", "M"), 0)
	var gholdengo_evo := _card(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "Gimmighoul", 2), 0)
	var context := {"game_state": gs, "player_index": 0}

	var live_attach_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": metal,
		"target_slot": live_gholdengo,
	}, gs, 0)
	var knocked_attach_score: float = strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": metal,
		"target_slot": knocked_gimmighoul,
	}, gs, 0)
	var knocked_evolve_score: float = strategy.score_action_absolute({
		"kind": "evolve",
		"card": gholdengo_evo,
		"target_slot": knocked_gimmighoul,
	}, gs, 0)
	var knocked_interaction_score: float = strategy.score_interaction_target(knocked_gimmighoul, {"id": "attach_energy"}, context)
	var knocked_handoff_score: float = strategy.score_handoff_target(knocked_gimmighoul, {"id": "send_out"}, context)

	return run_checks([
		assert_true(live_attach_score > knocked_attach_score + 1000.0, "Manual attach should prefer a live attacker over a knocked-out Gimmighoul (live=%f knocked=%f)" % [live_attach_score, knocked_attach_score]),
		assert_true(knocked_evolve_score < -90000.0, "Knocked-out slots should not be evolution targets"),
		assert_true(knocked_interaction_score < -90000.0, "Knocked-out slots should not be interaction targets"),
		assert_true(knocked_handoff_score < -90000.0, "Knocked-out slots should not be send-out targets"),
	])
