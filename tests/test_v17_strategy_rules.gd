class_name TestV17StrategyRules
extends TestBase

const StrategyArchaludon = preload("res://scripts/ai/DeckStrategy17ArchaludonDialga.gd")
const StrategyWaterTurtle = preload("res://scripts/ai/DeckStrategy17WaterTurtle.gd")
const StrategyPalkiaGholdengo = preload("res://scripts/ai/DeckStrategy17PalkiaGholdengo.gd")
const StrategyBombCharizard = preload("res://scripts/ai/DeckStrategy17BombCharizard.gd")


func _pokemon(
	name: String,
	energy_type: String = "C",
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	effect_id: String = "",
	evolves_from: String = "",
	set_code: String = "",
	card_index: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.mechanic = mechanic
	cd.effect_id = effect_id
	cd.evolves_from = evolves_from
	cd.set_code = set_code
	cd.card_index = card_index
	return cd


func _energy(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _trainer(name: String, trainer_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = trainer_type
	return cd


func _slot(cd: CardData, owner_index: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(cd, owner_index))
	return slot


func _attach_energy(slot: PokemonSlot, energy_type: String, count: int) -> void:
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_energy("%s %d" % [energy_type, i], energy_type), 0))


func test_v17_archaludon_models_dialga_metal_blast_scaling() -> String:
	var strategy := StrategyArchaludon.new()
	var dialga := _pokemon("Origin Forme Dialga VSTAR", "M", 280, "VSTAR", "VSTAR")
	dialga.attacks = [
		{"name": "Metal Blast", "cost": "MM", "damage": "40+", "text": "This attack does 40 more damage for each Metal Energy attached to this Pokemon."},
	]
	var slot := _slot(dialga)
	_attach_energy(slot, "M", 3)

	var prediction: Dictionary = strategy.predict_attacker_damage(slot)

	return run_checks([
		assert_true(int(prediction.get("damage", 0)) >= 160, "Dialga VSTAR should value Metal Blast as 40 plus attached Metal Energy scaling"),
	])


func test_v17_water_turtle_glass_trumpet_prefers_terapagos_over_fan_rotom() -> String:
	var strategy := StrategyWaterTurtle.new()
	var fan := _slot(_pokemon("Fan Rotom", "C", 70, "Basic", "", "", "", "CSV9C", "161"))
	var terapagos := _slot(_pokemon("Terapagos ex", "C", 230, "Basic", "ex", "", "", "CSV9C", "175"))
	var step := {"id": "csv9c178_energy_assignments"}

	var fan_score := strategy.score_interaction_target(fan, step, {})
	var terapagos_score := strategy.score_interaction_target(terapagos, step, {})

	return run_checks([
		assert_true(terapagos_score > fan_score, "Glass Trumpet assignment should prefer Terapagos ex over Fan Rotom"),
	])


func test_v17_palkia_gholdengo_models_make_it_rain_energy_burst() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var gholdengo := _pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "", "Gimmighoul")
	gholdengo.attacks = [
		{"name": "Make It Rain", "cost": "M", "damage": "50x", "text": "Discard any amount of Basic Energy from your hand. This attack does 50 damage for each card you discarded in this way."},
	]
	var slot := _slot(gholdengo)
	_attach_energy(slot, "M", 1)

	var prediction: Dictionary = strategy.predict_attacker_damage(slot, 4)

	return run_checks([
		assert_true(int(prediction.get("damage", 0)) >= 200, "Gholdengo ex should model Make It Rain from available hand Energy count"),
	])


func test_v17_palkia_gholdengo_stops_bonus_draw_when_deck_is_thin() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "", "Gimmighoul"))
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", "L", 220, "Basic", "ex"), 1)
	for i: int in 4:
		player.deck.append(CardInstance.create(_energy("Metal Energy %d" % i, "M"), 0))
	state.players.append(player)
	state.players.append(opponent)

	var score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": player.active_pokemon}, state, 0)

	return assert_true(score <= 60.0, "Gholdengo draw ability should be suppressed when the deck is already thin (score=%f)" % score)


func test_v17_palkia_gholdengo_suppresses_fezandipiti_when_deck_is_thin() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "", "Gimmighoul"))
	var fezandipiti := _slot(_pokemon("Fezandipiti ex", "D", 210, "Basic", "ex"))
	player.bench.append(fezandipiti)
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", "L", 220, "Basic", "ex"), 1)
	for i: int in 5:
		player.deck.append(CardInstance.create(_energy("Metal Energy %d" % i, "M"), 0))
	state.players.append(player)
	state.players.append(opponent)

	var score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": fezandipiti}, state, 0)

	return assert_true(score <= 0.0, "Fezandipiti draw should be negative when the deck is thin (score=%f)" % score)


func test_v17_palkia_gholdengo_uses_v17_initial_turn_contract() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "", "Gimmighoul"))
	_attach_energy(player.active_pokemon, "M", 1)
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", "L", 220, "Basic", "ex"), 1)
	state.players.append(player)
	state.players.append(opponent)

	var contract: Dictionary = strategy.build_turn_contract(state, 0, {})
	var owner: Dictionary = contract.get("owner", {})

	return run_checks([
		assert_eq(str(contract.get("id", "")), "v17_palkia_gholdengo_rules", "17.0 Palkia/Gholdengo should use its v17 rules turn contract"),
		assert_eq(str(owner.get("turn_owner_name", "")), "Gholdengo ex", "Ready Gholdengo ex should own the turn contract"),
	])


func test_v17_palkia_gholdengo_opening_poffin_outranks_vessel() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	player.active_pokemon = _slot(_pokemon("Manaphy", "W", 70))
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", "L", 220, "Basic", "ex"), 1)
	state.players.append(player)
	state.players.append(opponent)

	var poffin_score := strategy.score_action_absolute({"kind": "play_trainer", "card": CardInstance.create(_trainer("Buddy-Buddy Poffin"), 0)}, state, 0)
	var vessel_score := strategy.score_action_absolute({"kind": "play_trainer", "card": CardInstance.create(_trainer("Earthen Vessel"), 0)}, state, 0)

	return assert_true(poffin_score > vessel_score, "Opening Buddy-Buddy Poffin should outrank Earthen Vessel before Gimmighoul/Palkia are established (poffin=%f vessel=%f)" % [poffin_score, vessel_score])


func test_v17_palkia_gholdengo_delays_gimmighoul_attack_until_board_is_built() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	player.active_pokemon = _slot(_pokemon("Gimmighoul", "M", 70, "Basic", "", "", "", "CSV9C", "096"))
	_attach_energy(player.active_pokemon, "M", 1)
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", "L", 220, "Basic", "ex"), 1)
	state.players.append(player)
	state.players.append(opponent)

	var attack_score := strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 0,
		"projected_damage": 0,
		"requires_interaction": true,
	}, state, 0)
	var poffin_score := strategy.score_action_absolute({"kind": "play_trainer", "card": CardInstance.create(_trainer("Buddy-Buddy Poffin"), 0)}, state, 0)
	var palkia_score := strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": CardInstance.create(_pokemon("Origin Forme Palkia V", "W", 220, "Basic", "V"), 0)}, state, 0)
	var backup_gimmighoul_score := strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": CardInstance.create(_pokemon("Gimmighoul", "M", 70, "Basic", "", "", "", "CSV9C", "096"), 0)}, state, 0)

	return run_checks([
		assert_true(poffin_score > attack_score + 150.0, "Opening setup search should outrank zero-damage Gimmighoul attack (poffin=%f attack=%f)" % [poffin_score, attack_score]),
		assert_true(palkia_score > attack_score + 100.0, "Opening Palkia bench should outrank zero-damage Gimmighoul attack (palkia=%f attack=%f)" % [palkia_score, attack_score]),
		assert_true(backup_gimmighoul_score > attack_score + 100.0, "Opening backup Gimmighoul bench should outrank zero-damage Gimmighoul attack (backup=%f attack=%f)" % [backup_gimmighoul_score, attack_score]),
	])


func test_v17_palkia_gholdengo_pays_retreat_for_blocking_support_active() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	var manaphy := _pokemon("Manaphy", "W", 70)
	manaphy.retreat_cost = 1
	player.active_pokemon = _slot(manaphy)
	var gholdengo_slot := _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "", "Gimmighoul"))
	_attach_energy(gholdengo_slot, "M", 1)
	player.bench.append(gholdengo_slot)
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", "L", 220, "Basic", "ex"), 1)
	state.players.append(player)
	state.players.append(opponent)
	var water := CardInstance.create(_energy("Basic Water Energy", "W"), 0)
	var metal := CardInstance.create(_energy("Basic Metal Energy", "M"), 0)

	var active_attach_score := strategy.score_action_absolute({"kind": "attach_energy", "card": water, "target_slot": player.active_pokemon}, state, 0)
	var bench_attach_score := strategy.score_action_absolute({"kind": "attach_energy", "card": metal, "target_slot": gholdengo_slot}, state, 0)

	return assert_true(active_attach_score > bench_attach_score, "When a support active blocks a ready Gholdengo, attach should pay retreat before padding the bench attacker (active=%f bench=%f)" % [active_attach_score, bench_attach_score])


func test_v17_palkia_gholdengo_retreats_support_active_into_ready_attacker() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	var manaphy := _pokemon("Manaphy", "W", 70)
	manaphy.retreat_cost = 1
	player.active_pokemon = _slot(manaphy)
	_attach_energy(player.active_pokemon, "W", 1)
	var gholdengo_slot := _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "", "Gimmighoul"))
	_attach_energy(gholdengo_slot, "M", 1)
	player.bench.append(gholdengo_slot)
	for i: int in 4:
		player.hand.append(CardInstance.create(_energy("Metal Energy %d" % i, "M"), 0))
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", "L", 220, "Basic", "ex"), 1)
	state.players.append(player)
	state.players.append(opponent)

	var retreat_score := strategy.score_action_absolute({"kind": "retreat", "bench_target": gholdengo_slot}, state, 0)
	var draw_score := strategy.score_action_absolute({"kind": "use_ability", "source_slot": gholdengo_slot}, state, 0)
	var handoff_score := strategy.score_handoff_target(gholdengo_slot, {"id": "send_out"}, {"game_state": state, "player_index": 0})

	return run_checks([
		assert_true(retreat_score > draw_score + 300.0, "Ready Gholdengo should force retreat before more draw from a blocking support active (retreat=%f draw=%f)" % [retreat_score, draw_score]),
		assert_true(handoff_score >= 900.0, "Ready Gholdengo should receive a decisive send-out score (handoff=%f)" % handoff_score),
	])


func test_v17_palkia_gholdengo_recovers_energy_before_low_damage_make_it_rain() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "", "Gimmighoul"))
	_attach_energy(player.active_pokemon, "M", 1)
	var ser := CardInstance.create(_trainer("Superior Energy Retrieval"), 0)
	player.hand.append(ser)
	player.hand.append(CardInstance.create(_trainer("Nest Ball"), 0))
	player.hand.append(CardInstance.create(_trainer("Night Stretcher"), 0))
	for i: int in 4:
		player.discard_pile.append(CardInstance.create(_energy("Discard Metal Energy %d" % i, "M"), 0))
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", "L", 220, "Basic", "ex"), 1)
	opponent.active_pokemon.damage_counters = 40
	state.players.append(player)
	state.players.append(opponent)

	var attack_score := strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 0,
		"attack_name": "Make It Rain",
		"projected_damage": 50,
		"projected_knockout": false,
	}, state, 0)
	var recovery_score := strategy.score_action_absolute({"kind": "play_trainer", "card": ser}, state, 0)

	return assert_true(recovery_score > attack_score + 250.0, "Gholdengo should recover discard Energy before taking a low-damage Make It Rain line (recovery=%f attack=%f)" % [recovery_score, attack_score])


func test_v17_palkia_gholdengo_protects_hand_energy_outside_make_it_rain() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var basic_energy := CardInstance.create(_energy("Basic Metal Energy", "M"), 0)
	var spare_trainer := CardInstance.create(_trainer("Nest Ball"), 0)

	var generic_energy_score := strategy.score_interaction_target(basic_energy, {"id": "discard_cards"}, {})
	var generic_trainer_score := strategy.score_interaction_target(spare_trainer, {"id": "discard_cards"}, {})
	var attack_energy_score := strategy.score_interaction_target(basic_energy, {"id": "discard_basic_energy"}, {})
	var attack_trainer_score := strategy.score_interaction_target(spare_trainer, {"id": "discard_basic_energy"}, {})

	return run_checks([
		assert_true(generic_energy_score < generic_trainer_score, "Generic discard costs should preserve Basic Energy for Make It Rain"),
		assert_true(attack_energy_score > attack_trainer_score, "Make It Rain should still discard Basic Energy when the attack prompt asks for it"),
	])


func test_v17_palkia_gholdengo_make_it_rain_discards_minimum_lethal_energy() -> String:
	var strategy := StrategyPalkiaGholdengo.new()
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	player.active_pokemon = _slot(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex", "", "Gimmighoul"))
	_attach_energy(player.active_pokemon, "M", 1)
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", "L", 120, "Basic", "ex"), 1)
	state.players.append(player)
	state.players.append(opponent)
	var energies: Array = [
		CardInstance.create(_energy("Metal Energy", "M"), 0),
		CardInstance.create(_energy("Water Energy", "W"), 0),
		CardInstance.create(_energy("Grass Energy", "G"), 0),
		CardInstance.create(_energy("Fire Energy", "R"), 0),
	]

	var selected: Array = strategy.pick_interaction_items(
		energies,
		{"id": "discard_basic_energy", "max_select": 4},
		{"game_state": state, "player_index": 0}
	)

	return assert_eq(selected.size(), 3, "Make It Rain should discard only the minimum lethal Basic Energy count into a 120 HP target")


func test_v17_bomb_charizard_poffin_builds_charmander_and_pidgey_shell() -> String:
	var strategy := StrategyBombCharizard.new()
	var charmander_a := CardInstance.create(_pokemon("Charmander", "R", 70), 0)
	var charmander_b := CardInstance.create(_pokemon("Charmander", "R", 70), 0)
	var pidgey := CardInstance.create(_pokemon("Pidgey", "C", 60), 0)

	var selected: Array = strategy.pick_interaction_items(
		[charmander_a, charmander_b, pidgey],
		{"id": "buddy_buddy_poffin", "max_select": 2},
		{}
	)

	return run_checks([
		assert_true(pidgey in selected, "Buddy-Buddy Poffin should include Pidgey when paired with Charmander"),
		assert_true(charmander_a in selected or charmander_b in selected, "Buddy-Buddy Poffin should still include one Charmander"),
		assert_false(charmander_a in selected and charmander_b in selected, "Buddy-Buddy Poffin should not spend both picks on duplicate Charmander before Pidgey is established"),
	])


func test_v17_bomb_charizard_models_prize_scaling_damage() -> String:
	var strategy := StrategyBombCharizard.new()
	var charizard := _pokemon("Charizard ex", "R", 330, "Stage 2", "ex", "", "Charmeleon")
	charizard.attacks = [
		{"name": "Burning Darkness", "cost": "RR", "damage": "180+", "text": "This attack does 30 more damage for each Prize card your opponent has taken."},
	]
	var slot := _slot(charizard)
	_attach_energy(slot, "R", 2)

	var prediction: Dictionary = strategy.predict_attacker_damage(slot, 3)

	return run_checks([
		assert_true(int(prediction.get("damage", 0)) >= 270, "Charizard ex should model 30 damage per opponent Prize taken"),
	])
