class_name TestV17ArchaludonDialgaStrategy
extends TestBase

const StrategyArchaludon = preload("res://scripts/ai/DeckStrategy17ArchaludonDialga.gd")


func _pokemon(
	name: String,
	energy_type: String = "M",
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
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
	cd.evolves_from = evolves_from
	cd.set_code = set_code
	cd.card_index = card_index
	return cd


func _energy(name: String = "Basic Metal Energy", energy_type: String = "M") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _trainer(name: String, card_type: String = "Supporter") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	return cd


func _slot(cd: CardData, owner_index: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(cd, owner_index))
	return slot


func _attach_energy(slot: PokemonSlot, count: int) -> void:
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_energy("Basic Metal Energy %d" % i), 0))


func _state_with_player(player: PlayerState) -> GameState:
	var state := GameState.new()
	var opponent := PlayerState.new()
	opponent.player_index = 1
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", "L", 220, "Basic", "ex"), 1)
	state.players.append(player)
	state.players.append(opponent)
	return state


func test_opening_starts_duraludon_before_dialga_v() -> String:
	var strategy := StrategyArchaludon.new()
	var player := PlayerState.new()
	player.player_index = 0
	player.hand.append(CardInstance.create(_pokemon("Origin Forme Dialga V", "M", 220, "Basic", "V"), 0))
	player.hand.append(CardInstance.create(_pokemon("Duraludon", "M", 130, "Basic", "", "", "CSV9C", "136"), 0))

	var setup: Dictionary = strategy.plan_opening_setup(player)

	return assert_eq(int(setup.get("active_hand_index", -1)), 1, "Opening setup should start Duraludon over Dialga V")


func test_alloy_build_assignment_finishes_archaludon_attack_first() -> String:
	var strategy := StrategyArchaludon.new()
	var player := PlayerState.new()
	player.player_index = 0
	var archaludon := _pokemon("Archaludon ex", "M", 300, "Stage 1", "ex", "Duraludon", "CSV9C", "138")
	archaludon.attacks = [{"name": "Metal Defender", "cost": "MMM", "damage": "220"}]
	var dialga := _pokemon("Origin Forme Dialga V", "M", 220, "Basic", "V")
	dialga.attacks = [{"name": "Metal Coating", "cost": "C", "damage": ""}]
	player.active_pokemon = _slot(archaludon)
	_attach_energy(player.active_pokemon, 2)
	var dialga_slot := _slot(dialga)
	_attach_energy(dialga_slot, 1)
	player.bench.append(dialga_slot)
	var mew_slot := _slot(_pokemon("Mew ex", "P", 180, "Basic", "ex"))
	player.bench.append(mew_slot)
	var state := _state_with_player(player)
	var step := {"id": "alloy_build_assignments"}
	var context := {"game_state": state, "player_index": 0}

	var arch_score := strategy.score_interaction_target(player.active_pokemon, step, context)
	var dialga_score := strategy.score_interaction_target(dialga_slot, step, context)
	var mew_score := strategy.score_interaction_target(mew_slot, step, context)

	return run_checks([
		assert_true(arch_score > dialga_score, "Alloy Build should finish active Archaludon before padding Dialga V"),
		assert_true(arch_score > mew_score, "Alloy Build should not route Metal Energy to support Pokemon while Archaludon is one short"),
	])


func test_dialga_metal_coating_needs_discard_fuel() -> String:
	var strategy := StrategyArchaludon.new()
	var player := PlayerState.new()
	player.player_index = 0
	var dialga := _pokemon("Origin Forme Dialga V", "M", 220, "Basic", "V")
	dialga.attacks = [{"name": "Metal Coating", "cost": "C", "damage": ""}]
	player.active_pokemon = _slot(dialga)
	_attach_energy(player.active_pokemon, 1)
	var state := _state_with_player(player)
	var action := {"kind": "attack", "attack_index": 0, "attack_name": "Metal Coating", "projected_damage": 0}

	var no_fuel_score := strategy.score_action_absolute(action, state, 0)
	player.discard_pile.append(CardInstance.create(_energy("Discard Metal Energy 1"), 0))
	player.discard_pile.append(CardInstance.create(_energy("Discard Metal Energy 2"), 0))
	var fueled_score := strategy.score_action_absolute(action, state, 0)

	return run_checks([
		assert_true(no_fuel_score < 100.0, "Metal Coating should be low value without discard Metal Energy"),
		assert_true(fueled_score > no_fuel_score + 500.0, "Metal Coating should become valuable when it can attach discard Metal Energy"),
	])


func test_send_out_prefers_ready_archaludon_over_unready_dialga() -> String:
	var strategy := StrategyArchaludon.new()
	var player := PlayerState.new()
	player.player_index = 0
	var archaludon := _pokemon("Archaludon ex", "M", 300, "Stage 1", "ex", "Duraludon", "CSV9C", "138")
	archaludon.attacks = [{"name": "Metal Defender", "cost": "MMM", "damage": "220"}]
	var dialga := _pokemon("Origin Forme Dialga V", "M", 220, "Basic", "V")
	dialga.attacks = [{"name": "Metal Coating", "cost": "C", "damage": ""}]
	var arch_slot := _slot(archaludon)
	_attach_energy(arch_slot, 3)
	var dialga_slot := _slot(dialga)
	_attach_energy(dialga_slot, 1)
	player.bench.append(arch_slot)
	player.bench.append(dialga_slot)
	var state := _state_with_player(player)
	var context := {"game_state": state, "player_index": 0}

	var arch_score := strategy.score_handoff_target(arch_slot, {"id": "send_out"}, context)
	var dialga_score := strategy.score_handoff_target(dialga_slot, {"id": "send_out"}, context)

	return assert_true(arch_score > dialga_score, "Send-out should prefer a ready Archaludon attacker over unready Dialga V")


func test_conversion_attach_starts_dialga_vstar_after_ready_archaludon() -> String:
	var strategy := StrategyArchaludon.new()
	var player := PlayerState.new()
	player.player_index = 0
	var archaludon := _pokemon("Archaludon ex", "M", 300, "Stage 1", "ex", "Duraludon", "CSV9C", "138")
	archaludon.attacks = [{"name": "Metal Defender", "cost": "MMM", "damage": "220"}]
	player.active_pokemon = _slot(archaludon)
	_attach_energy(player.active_pokemon, 3)
	var dialga := _pokemon("Origin Forme Dialga VSTAR", "M", 280, "VSTAR", "VSTAR", "Origin Forme Dialga V")
	dialga.attacks = [
		{"name": "Metal Blast", "cost": "C", "damage": "40+"},
		{"name": "Star Chronos", "cost": "MMMMC", "damage": "220"},
	]
	var dialga_slot := _slot(dialga)
	player.bench.append(dialga_slot)
	var state := _state_with_player(player)
	var energy_card := CardInstance.create(_energy("Manual Metal Energy"), 0)

	var arch_score := strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": energy_card,
		"target_slot": player.active_pokemon,
	}, state, 0)
	var dialga_score := strategy.score_action_absolute({
		"kind": "attach_energy",
		"card": energy_card,
		"target_slot": dialga_slot,
	}, state, 0)

	return assert_true(
		dialga_score > arch_score,
		"Once Archaludon is already attacking, manual Metal attachments should start the Dialga VSTAR conversion route"
	)


func test_thin_deck_research_cools_off_with_ready_attacker() -> String:
	var strategy := StrategyArchaludon.new()
	var player := PlayerState.new()
	player.player_index = 0
	var archaludon := _pokemon("Archaludon ex", "M", 300, "Stage 1", "ex", "Duraludon", "CSV9C", "138")
	archaludon.attacks = [{"name": "Metal Defender", "cost": "MMM", "damage": "220"}]
	player.active_pokemon = _slot(archaludon)
	_attach_energy(player.active_pokemon, 3)
	for i: int in 10:
		player.deck.append(CardInstance.create(_energy("Deck Metal %d" % i), 0))
	var state := _state_with_player(player)
	var research := CardInstance.create(_trainer("Professor's Research"), 0)

	var score := strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": research,
		"productive": true,
	}, state, 0)

	return assert_true(score <= 70.0, "Research should cool off before deck-out pressure becomes critical when a ready attacker is already live")


func test_mid_thin_deck_research_cools_off_before_deck_out_line() -> String:
	var strategy := StrategyArchaludon.new()
	var player := PlayerState.new()
	player.player_index = 0
	var archaludon := _pokemon("Archaludon ex", "M", 300, "Stage 1", "ex", "Duraludon", "CSV9C", "138")
	archaludon.attacks = [{"name": "Metal Defender", "cost": "MMM", "damage": "220"}]
	player.active_pokemon = _slot(archaludon)
	_attach_energy(player.active_pokemon, 3)
	for i: int in 14:
		player.deck.append(CardInstance.create(_energy("Deck Metal %d" % i), 0))
	var state := _state_with_player(player)
	var research := CardInstance.create(_trainer("Professor's Research"), 0)

	var score := strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": research,
		"productive": true,
	}, state, 0)

	return assert_true(score <= 70.0, "Research should cool off once a ready attacker is live and deck is at the mid-thin line")


func test_mid_thin_deck_fezandipiti_cools_off_with_ready_attacker() -> String:
	var strategy := StrategyArchaludon.new()
	var player := PlayerState.new()
	player.player_index = 0
	var archaludon := _pokemon("Archaludon ex", "M", 300, "Stage 1", "ex", "Duraludon", "CSV9C", "138")
	archaludon.attacks = [{"name": "Metal Defender", "cost": "MMM", "damage": "220"}]
	player.active_pokemon = _slot(archaludon)
	_attach_energy(player.active_pokemon, 3)
	var fezandipiti := _slot(_pokemon("Fezandipiti ex", "D", 210, "Basic", "ex"))
	player.bench.append(fezandipiti)
	for i: int in 14:
		player.deck.append(CardInstance.create(_energy("Deck Metal %d" % i), 0))
	var state := _state_with_player(player)

	var score := strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": fezandipiti,
		"ability_index": 0,
	}, state, 0)

	return assert_true(score <= 55.0, "Fezandipiti draw should cool off at the mid-thin line when a ready attacker is already live")
