class_name TestTcgMikCSV9C187191CSV7C144
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const DeckEditorScript := preload("res://scenes/deck_editor/DeckEditor.gd")


func test_imported_card_manifest_images_full_pool_and_deck_editor_categories() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var expected := {
		"CSV9C_187": {"set": "CSV9C", "index": "187", "category": 2},
		"CSV9C_191": {"set": "CSV9C", "index": "191", "category": 3},
		"CSV7C_144": {"set": "CSV7C", "index": "144", "category": 0},
	}
	var pooled: Dictionary = {}
	for card: CardData in db.get_all_cards():
		pooled[card.get_uid()] = card
	var editor: Control = DeckEditorScript.new()
	editor.call("_build_pool")
	var categories: Array = editor.get("_pool_by_category")
	var checks: Array[String] = []
	for uid: String in expected:
		var meta: Dictionary = expected[uid]
		var json_path := "res://data/bundled_user/cards/%s.json" % uid
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [meta["set"], meta["index"]]
		checks.append(assert_true(json_path in manifest and image_path in manifest, "%s JSON and image should be in the export manifest" % uid))
		checks.append(assert_true(FileAccess.file_exists(json_path), "%s bundled JSON should exist" % uid))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should be a valid card image" % uid))
		checks.append(assert_true(pooled.has(uid), "%s should be visible through CardDatabase.get_all_cards" % uid))
		var category: Array = categories[int(meta["category"])]
		checks.append(assert_true(category.any(func(card: CardData) -> bool: return card.get_uid() == uid), "%s should appear in its DeckEditor category" % uid))
	editor.free()
	return run_checks(checks)


func test_imported_cards_are_bundled_and_registered() -> String:
	var db := CardDatabaseScript.new()
	var processor := EffectProcessor.new()
	var expected := {
		"CSV9C_187": "2a9598f0151a2851d9c3011d69e70089",
		"CSV9C_191": "6aac84f2cdc661d1ebbcbbd38ee890e4",
		"CSV7C_144": "6c13a1afb0238ba7cea406803c64383d",
	}
	var checks: Array[String] = []
	for uid: String in expected:
		var parts := uid.split("_")
		var card: CardData = db.get_card(parts[0], parts[1])
		checks.append(assert_not_null(card, "%s should load from the bundled card pool" % uid))
		if card == null:
			continue
		checks.append(assert_eq(card.effect_id, expected[uid], "%s should preserve the API effect_id" % uid))
		processor.register_pokemon_card(card)
		if card.card_type == "Pokemon":
			checks.append(assert_true(processor.has_attack_effect(card.effect_id), "%s should register its scripted attacks" % uid))
		else:
			checks.append(assert_true(processor.has_effect(card.effect_id), "%s should register its trainer/tool effect" % uid))
	return run_checks(checks)


func test_miracle_headset_exposes_optional_supporter_selection_and_moves_only_selected_cards() -> String:
	var state := _state()
	var player := state.players[0]
	var headset := CardInstance.create(_trainer("Miracle Headset", "Item", "2a9598f0151a2851d9c3011d69e70089"), 0)
	var supporter_a := CardInstance.create(_trainer("Supporter A", "Supporter"), 0)
	var supporter_b := CardInstance.create(_trainer("Supporter B", "Supporter"), 0)
	var item := CardInstance.create(_trainer("Item", "Item"), 0)
	player.discard_pile.assign([supporter_a, supporter_b, item])
	var processor := EffectProcessor.new()
	var effect := processor.get_effect(headset.card_data.effect_id)
	var steps: Array = effect.get_interaction_steps(headset, state) if effect != null else []
	if effect != null:
		effect.execute(headset, [{"supporters_to_hand": [supporter_b]}], state)
	return run_checks([
		assert_not_null(effect, "Miracle Headset should have an effect"),
		assert_eq(steps.size(), 1, "Miracle Headset should expose one discard-pile choice"),
		assert_eq(int(steps[0].get("min_select", -1)) if not steps.is_empty() else -1, 0, "Miracle Headset selection should be optional"),
		assert_eq(int(steps[0].get("max_select", -1)) if not steps.is_empty() else -1, 2, "Miracle Headset should allow up to 2 Supporters"),
		assert_true(supporter_b in player.hand, "The selected Supporter should move to hand"),
		assert_true(supporter_a in player.discard_pile and item in player.discard_pile, "Unselected and illegal cards should remain in discard"),
	])


func test_amulet_of_hope_searches_up_to_three_only_after_attack_damage_knockout() -> String:
	var state := _state()
	var owner := state.players[0]
	var amulet := CardInstance.create(_trainer("Amulet of Hope", "Tool", "6aac84f2cdc661d1ebbcbbd38ee890e4"), 0)
	var holder := owner.active_pokemon
	holder.attached_tool = amulet
	var selected := [
		CardInstance.create(_trainer("Any A", "Item"), 0),
		CardInstance.create(_pokemon("Any B"), 0),
		CardInstance.create(_trainer("Any C", "Supporter"), 0),
	]
	var unselected := CardInstance.create(_trainer("Any D", "Stadium"), 0)
	owner.deck.assign(selected + [unselected])
	var processor := EffectProcessor.new()
	var effect := processor.get_effect(amulet.card_data.effect_id)
	var steps: Array = effect.get_knockout_interaction_steps(holder, state) if effect != null else []
	if effect != null:
		effect.resolve_attack_damage_knockout(holder, state, {"cards_to_hand": selected})
	return run_checks([
		assert_not_null(effect, "Amulet of Hope should have an effect"),
		assert_eq(int(steps[0].get("min_select", -1)) if not steps.is_empty() else -1, 0, "Amulet search should allow zero cards"),
		assert_eq(int(steps[0].get("max_select", -1)) if not steps.is_empty() else -1, 3, "Amulet search should cap at three cards"),
		assert_true(selected.all(func(card: CardInstance) -> bool: return card in owner.hand), "All three selected arbitrary cards should move to hand"),
		assert_true(unselected in owner.deck, "Unselected cards should remain in deck"),
	])


func test_amulet_of_hope_pauses_real_knockout_flow_for_player_choice_then_resumes() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state.players.clear()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _slot(_pokemon("Active %d" % pi), pi)
		gsm.game_state.players.append(player)
	var holder := gsm.game_state.players[0].active_pokemon
	holder.attached_tool = CardInstance.create(_trainer("Amulet of Hope", "Tool", "6aac84f2cdc661d1ebbcbbd38ee890e4"), 0)
	var chosen := CardInstance.create(_trainer("Chosen", "Item"), 0)
	gsm.game_state.players[0].deck.append(chosen)
	var prompts: Array[Dictionary] = []
	gsm.player_choice_required.connect(func(kind: String, data: Dictionary) -> void: prompts.append({"kind": kind, "data": data}))
	var knockout_ids: Dictionary = gsm.get("_attack_damage_knockout_slot_ids")
	knockout_ids[int(holder.get_instance_id())] = true
	var paused: bool = not bool(gsm.call("_finalize_knockout", 0, holder, true))
	var resumed: bool = gsm.resolve_amulet_of_hope_choice(0, [{"cards_to_hand": [chosen]}])
	return run_checks([
		assert_true(paused, "Attack-damage knockout should pause before moving the Amulet holder to discard"),
		assert_eq(str(prompts[0].get("kind", "")) if not prompts.is_empty() else "", "amulet_of_hope_knockout", "The engine should request the Amulet search interaction"),
		assert_true(chosen in gsm.game_state.players[0].hand, "Resolving the interaction should move the chosen card to hand"),
		assert_true(resumed, "Knockout settlement should resume after the Amulet choice"),
	])


func test_scizor_ex_attack_branches_reduce_damage_and_scale_with_zero_to_two_own_metal_energy() -> String:
	var state := _state()
	var scizor := _pokemon("Scizor ex")
	scizor.effect_id = "6c13a1afb0238ba7cea406803c64383d"
	scizor.attacks = [_attack("Steel Wing", "CC", "70"), _attack("Cross Breaker", "MM", "120×")]
	var attacker := _slot(scizor, 0)
	state.players[0].active_pokemon = attacker
	var metal_a := CardInstance.create(_energy("Metal A", "M"), 0)
	var metal_b := CardInstance.create(_energy("Metal B", "M"), 0)
	var fire := CardInstance.create(_energy("Fire", "R"), 0)
	attacker.attached_energy.assign([metal_a, metal_b, fire])
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(scizor)
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [])
	var reduction := processor.get_defender_modifier(attacker, state, state.players[1].active_pokemon)
	state.turn_number += 1
	reduction = processor.get_defender_modifier(attacker, state, state.players[1].active_pokemon)
	var targets := [{"discard_scizor_metal_energy": [metal_a, metal_b]}]
	var bonus := processor.get_attack_damage_modifier(attacker, state.players[1].active_pokemon, scizor.attacks[1], state, targets, 1)
	processor.execute_attack_effect(attacker, 1, state.players[1].active_pokemon, state, targets)
	return run_checks([
		assert_eq(reduction, -50, "Steel Wing should reduce damage by 50 during the next opponent turn"),
		assert_eq(bonus, 120, "Discarding two Metal Energy should add 120 to printed 120 for 240 total"),
		assert_true(metal_a in state.players[0].discard_pile and metal_b in state.players[0].discard_pile, "Both selected Metal Energy should be discarded"),
		assert_true(fire in attacker.attached_energy, "Non-Metal Energy should remain attached"),
	])


func _state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _slot(_pokemon("Active %d" % pi), pi)
		state.players.append(player)
	return state


func _trainer(name: String, card_type: String, effect_id: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = card_type
	card.effect_id = effect_id
	return card


func _pokemon(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 300
	return card


func _energy(name: String, energy_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return card


func _attack(name: String, cost: String, damage: String) -> Dictionary:
	return {"name": name, "cost": cost, "damage": damage, "text": "", "is_vstar_power": false}


func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
