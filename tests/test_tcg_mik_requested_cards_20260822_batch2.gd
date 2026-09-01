class_name TestTcgMikRequestedCards20260822Batch2
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const DeckEditorScript := preload("res://scenes/deck_editor/DeckEditor.gd")
const AttackSelfAllAttacksLockNextTurnScript := preload("res://scripts/effects/pokemon_effects/AttackSelfAllAttacksLockNextTurn.gd")
const AttackTMEvolutionScript := preload("res://scripts/effects/pokemon_effects/AttackTMEvolution.gd")
const GrandTreeScript := preload("res://scripts/effects/stadium_effects/CSV9C205GrandTree.gd")

const OKIDOGI_EFFECT_PATH := "res://scripts/effects/pokemon_effects/AbilityOkidogiAdrenalinePower.gd"
const LILLIGANT_EFFECT_PATH := "res://scripts/effects/pokemon_effects/AbilityTypeTeamDamageBoost.gd"
const PALAFIN_EFFECT_PATH := "res://scripts/effects/pokemon_effects/AbilityPalafinZeroToHero.gd"
const PALAFIN_EX_EFFECT_PATH := "res://scripts/effects/pokemon_effects/AbilityPalafinHeroSpiritRestriction.gd"

const OKIDOGI_EFFECT_ID := "cc0285c411d9f2c4d7c3f0c486cd2667"
const PETILIL_EFFECT_ID := "f727c4fb3a5816eb5cdf2d06b2c37324"
const LILLIGANT_EFFECT_ID := "29caf0a046110a6cc450e04e493bdfa2"
const PALAFIN_EFFECT_ID := "3c38a9d3798223dfe455c2bc898f78b6"
const PALAFIN_EX_EFFECT_ID := "1b97f4552b78e850d48100edf4d82c95"


func test_batch2_cards_preserve_source_metadata_assets_and_editor_visibility() -> String:
	CardImplementationStatus.clear_cache()
	var specs := [
		{"set": "CSV9.5C", "index": "101", "name": "够赞狗", "name_en": "Okidogi", "effect_id": OKIDOGI_EFFECT_ID, "stage": "Basic", "hp": 130, "attacks": 1, "abilities": 1},
		{"set": "CSVH4eC", "index": "001", "name": "百合根娃娃", "name_en": "Petilil", "effect_id": PETILIL_EFFECT_ID, "stage": "Basic", "hp": 50, "attacks": 1, "abilities": 0},
		{"set": "CSVH4eC", "index": "002", "name": "裙儿小姐", "name_en": "Lilligant", "effect_id": LILLIGANT_EFFECT_ID, "stage": "Stage 1", "hp": 110, "attacks": 1, "abilities": 1},
		{"set": "CSV9.5C", "index": "051", "name": "海豚侠", "name_en": "Palafin", "effect_id": PALAFIN_EFFECT_ID, "stage": "Stage 1", "hp": 100, "attacks": 1, "abilities": 1},
		{"set": "CSV9.5C", "index": "052", "name": "海豚侠ex", "name_en": "Palafin ex", "effect_id": PALAFIN_EX_EFFECT_ID, "stage": "Stage 1", "hp": 340, "attacks": 1, "abilities": 1},
	]
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var db := CardDatabaseScript.new()
	var pooled_uids := {}
	for pooled: CardData in db.get_all_cards():
		if pooled != null:
			pooled_uids[pooled.get_uid()] = true
	var checks: Array[String] = []
	for spec: Dictionary in specs:
		var set_code := str(spec.get("set", ""))
		var card_index := str(spec.get("index", ""))
		var uid := "%s_%s" % [set_code, card_index]
		var card_path := "res://data/bundled_user/cards/%s.json" % uid
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card := _load_card(set_code, card_index)
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled JSON should exist" % uid))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should be valid" % uid))
		checks.append(assert_str_contains(manifest, card_path, "%s JSON should be listed in the bundled manifest" % uid))
		checks.append(assert_str_contains(manifest, image_path, "%s image should be listed in the bundled manifest" % uid))
		checks.append(assert_not_null(card, "%s should deserialize from its bundled JSON" % uid))
		checks.append(assert_true(pooled_uids.has(uid), "%s should appear in the complete card pool" % uid))
		if card == null:
			continue
		checks.append(assert_eq(card.name, str(spec.get("name", "")), "%s should preserve its API Chinese name" % uid))
		checks.append(assert_eq(card.name_en, str(spec.get("name_en", "")), "%s should preserve its API English name" % uid))
		checks.append(assert_eq(card.effect_id, str(spec.get("effect_id", "")), "%s should preserve its stable effect_id" % uid))
		checks.append(assert_eq(card.stage, str(spec.get("stage", "")), "%s should preserve its stage" % uid))
		checks.append(assert_eq(card.hp, int(spec.get("hp", -1)), "%s should preserve its printed HP" % uid))
		checks.append(assert_eq(card.attacks.size(), int(spec.get("attacks", -1)), "%s should preserve every attack" % uid))
		checks.append(assert_eq(card.abilities.size(), int(spec.get("abilities", -1)), "%s should preserve every Ability" % uid))
		checks.append(assert_eq(card.source_provider, "tcg_mik", "%s should retain source provenance" % uid))
		checks.append(assert_eq(card.source_url, "https://tcg.mik.moe/cards/%s/%s" % [set_code, card_index], "%s should retain its source URL" % uid))
	db.free()

	var editor := DeckEditorScript.new()
	editor.call("_build_pool")
	var editor_uids := {}
	var categories: Array = editor.get("_pool_by_category")
	if not categories.is_empty():
		for pooled: CardData in categories[0]:
			editor_uids[pooled.get_uid()] = true
	for spec: Dictionary in specs:
		var uid := "%s_%s" % [str(spec.get("set", "")), str(spec.get("index", ""))]
		checks.append(assert_true(editor_uids.has(uid), "%s should be selectable in the DeckEditor Pokemon tab" % uid))
	editor.free()
	return run_checks(checks)


func test_csv95c101_okidogi_darkness_energy_adds_exact_hp_and_active_damage() -> String:
	var card := _load_card("CSV9.5C", "101")
	if card == null:
		return assert_not_null(card, "CSV9.5C_101 should load")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var okidogi := _slot(card, 0)
	state.players[0].active_pokemon = okidogi
	var effect := processor.get_effect(OKIDOGI_EFFECT_ID)
	var base_hp := processor.get_effective_max_hp(okidogi, state)
	var base_damage_bonus := processor.get_attacker_modifier(okidogi, state, state.players[1].active_pokemon)
	okidogi.attached_energy.append(_energy_instance("Basic Darkness", "D", 0))
	var boosted_hp := processor.get_effective_max_hp(okidogi, state)
	var boosted_damage := processor.get_attacker_modifier(okidogi, state, state.players[1].active_pokemon)
	var bench_target := _slot(_pokemon("Bench Target", "F", 100), 1)
	state.players[1].bench = [bench_target]
	var bench_damage := processor.get_attacker_modifier(okidogi, state, bench_target)
	return run_checks([
		assert_eq(_effect_path(effect), OKIDOGI_EFFECT_PATH, "Adrenaline Power should register by effect_id"),
		assert_eq(base_hp, 130, "Okidogi should keep its printed 130 HP without attached Darkness Energy"),
		assert_eq(base_damage_bonus, 0, "Okidogi should gain no damage without attached Darkness Energy"),
		assert_eq(boosted_hp, 230, "Attached Darkness Energy should add exactly 100 HP"),
		assert_eq(boosted_damage, 100, "Attached Darkness Energy should add exactly 100 damage to the opponent Active"),
		assert_eq(bench_damage, 0, "Adrenaline Power should not add damage to a Benched target"),
	])


func test_csvh4ec001_is_vanilla_and_csvh4ec002_sunny_day_boosts_only_grass_fire() -> String:
	var petilil_card := _load_card("CSVH4eC", "001")
	var lilligant_card := _load_card("CSVH4eC", "002")
	if petilil_card == null or lilligant_card == null:
		return "CSVH4eC_001 and CSVH4eC_002 should load"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(petilil_card)
	processor.register_pokemon_card(lilligant_card)
	var state := _make_state()
	var lilligant := _slot(lilligant_card, 0)
	state.players[0].bench = [lilligant]
	var grass := _slot(_pokemon("Grass Attacker", "G", 120), 0)
	var fire := _slot(_pokemon("Fire Attacker", "R", 120), 0)
	var water := _slot(_pokemon("Water Attacker", "W", 120), 0)
	var defender := state.players[1].active_pokemon
	var effect := processor.get_effect(LILLIGANT_EFFECT_ID)
	return run_checks([
		assert_true(processor.get_attack_effects_for_slot(_slot(petilil_card, 0), 0).is_empty(), "Petilil's printed 30-damage attack should remain vanilla"),
		assert_eq(_effect_path(effect), LILLIGANT_EFFECT_PATH, "Sunny Day should register as a continuous team damage boost"),
		assert_eq(processor.get_attacker_modifier(grass, state, defender), 20, "Sunny Day should add 20 for a Grass attacker"),
		assert_eq(processor.get_attacker_modifier(fire, state, defender), 20, "Sunny Day should add 20 for a Fire attacker"),
		assert_eq(processor.get_attacker_modifier(water, state, defender), 0, "Sunny Day should not boost other types"),
	])


func test_csv95c051_zero_to_hero_swaps_only_after_own_turn_active_to_bench_transition() -> String:
	var palafin_card := _load_card("CSV9.5C", "051")
	var palafin_ex_card := _load_card("CSV9.5C", "052")
	if palafin_card == null or palafin_ex_card == null:
		return "CSV9.5C_051 and CSV9.5C_052 should load"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(palafin_card)
	processor.register_pokemon_card(palafin_ex_card)
	var state := _make_state()
	var finizen := _pokemon("波普海豚", "W", 70)
	var palafin := _slot_with_stack([finizen, palafin_card], 0)
	palafin.damage_counters = 50
	var water_energy := _energy_instance("Basic Water", "W", 0)
	palafin.attached_energy = [water_energy]
	palafin.effects.append({"type": "bench_safe_marker", "value": 7})
	var incoming := _slot(_pokemon("Incoming Active", "W", 100), 0)
	state.players[0].active_pokemon = palafin
	state.players[0].bench = [incoming]
	var hero := CardInstance.create(palafin_ex_card, 0)
	var visible_item := _trainer_instance("Visible Item", "Item", 0)
	state.players[0].deck = [visible_item, hero]
	var effect := processor.get_effect(PALAFIN_EFFECT_ID)
	var available_before_switch := processor.can_use_ability(palafin, state, 0)
	var switched := BattleFieldTransitionService.switch_active_with_bench(state, 0, incoming, "zero_to_hero_test")
	var available_after_switch := processor.can_use_ability(palafin, state, 0)
	var steps: Array = effect.get_interaction_steps(palafin.get_top_card(), state) if effect != null else []
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var used := processor.execute_ability_effect(palafin, 0, [{"palafin_ex": [hero]}], state)
	var old_palafin_in_deck := state.players[0].deck.any(func(card: CardInstance) -> bool: return card.card_data == palafin_card)
	return run_checks([
		assert_eq(_effect_path(effect), PALAFIN_EFFECT_PATH, "Zero to Hero should register by effect_id"),
		assert_false(available_before_switch, "Zero to Hero should not be usable before Palafin moves from Active to Bench"),
		assert_true(switched, "The fixture should move Palafin from Active to Bench"),
		assert_true(available_after_switch, "Zero to Hero should become usable after that own-turn transition"),
		assert_eq(str(step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Zero to Hero should show the complete own deck"),
		assert_eq(step.get("card_items", []), [visible_item, hero], "Zero to Hero should keep legal and illegal deck cards visible"),
		assert_eq(step.get("items", []), [hero], "Only Palafin ex should be selectable"),
		assert_true(used, "Zero to Hero should resolve with the selected Palafin ex"),
		assert_eq(palafin.get_card_data(), palafin_ex_card, "The slot's top card should become Palafin ex"),
		assert_eq(palafin.pokemon_stack.size(), 2, "The underlying Finizen should stay in the evolution stack"),
		assert_true(old_palafin_in_deck, "The original Palafin card should return to the deck"),
		assert_eq(palafin.damage_counters, 50, "Damage counters should carry over to Palafin ex"),
		assert_eq(palafin.attached_energy, [water_energy], "Attached cards should carry over to Palafin ex"),
		assert_true(palafin.effects.any(func(entry: Dictionary) -> bool: return str(entry.get("type", "")) == "bench_safe_marker"), "Bench-safe effects should carry over to Palafin ex"),
	])


func test_csv95c052_hero_spirit_blocks_other_evolution_routes_and_attack_locks_all() -> String:
	var palafin_ex_card := _load_card("CSV9.5C", "052")
	if palafin_ex_card == null:
		return assert_not_null(palafin_ex_card, "CSV9.5C_052 should load")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(palafin_ex_card)
	var state := _make_state()
	state.turn_number = 3
	var finizen_slot := _slot(_pokemon("波普海豚", "W", 70), 0)
	finizen_slot.turn_played = 1
	state.players[0].bench = [finizen_slot]
	var hand_hero := CardInstance.create(palafin_ex_card, 0)
	state.players[0].hand = [hand_hero]
	var manual_evolution_allowed := RuleValidator.new().can_evolve(state, 0, finizen_slot, hand_hero, processor)

	var deck_hero := CardInstance.create(palafin_ex_card, 0)
	state.players[0].deck = [deck_hero]
	var tm_attacker := state.players[0].active_pokemon
	var tm_steps := AttackTMEvolutionScript.new().get_granted_attack_interaction_steps(tm_attacker, {}, state)
	var grand_tree_steps := GrandTreeScript.new().get_interaction_steps(_trainer_instance("Grand Tree", "Stadium", 0), state)

	var hero_slot := _slot(palafin_ex_card, 0)
	state.players[0].active_pokemon = hero_slot
	var passive := processor.get_effect(PALAFIN_EX_EFFECT_ID)
	var attack_effects := processor.get_attack_effects_for_slot(hero_slot, 0)
	var lock_effect := _find_effect(attack_effects, AttackSelfAllAttacksLockNextTurnScript)
	if lock_effect != null:
		lock_effect.call("execute_attack", hero_slot, state.players[1].active_pokemon, 0, state)
	return run_checks([
		assert_eq(_effect_path(passive), PALAFIN_EX_EFFECT_PATH, "Hero's Spirit should register as the field-entry restriction"),
		assert_false(manual_evolution_allowed, "Palafin ex should not be playable by normal hand evolution"),
		assert_true(tm_steps.is_empty(), "TM Evolution should not offer Palafin ex as a deck evolution route"),
		assert_true(grand_tree_steps.is_empty(), "Grand Tree should not offer Palafin ex as a deck evolution route"),
		assert_not_null(lock_effect, "Giga Impact should register the all-attacks next-turn lock"),
		assert_true(hero_slot.effects.any(func(entry: Dictionary) -> bool: return str(entry.get("type", "")) == "attack_lock_all"), "Giga Impact should stop Palafin ex from using any attack next turn"),
	])


func _load_card(set_code: String, card_index: String) -> CardData:
	var path := "res://data/bundled_user/cards/%s_%s.json" % [set_code, card_index]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot(_pokemon("Active %d" % owner, "C", 400), owner)
		player.deck = [_trainer_instance("Turn Draw %d" % owner, "Item", owner)]
		player.prizes = [_trainer_instance("Prize %d" % owner, "Item", owner)]
		state.players.append(player)
	return state


func _pokemon(name: String, energy_type: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = energy_type
	card.hp = hp
	card.attacks = [{"name": "Tackle", "cost": "", "damage": "10", "text": "", "is_vstar_power": false}]
	return card


func _slot(card: CardData, owner: int) -> PokemonSlot:
	return _slot_with_stack([card], owner)


func _slot_with_stack(cards: Array, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	for card: CardData in cards:
		slot.pokemon_stack.append(CardInstance.create(card, owner))
	slot.turn_played = 0
	return slot


func _energy_instance(name: String, energy_type: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return CardInstance.create(card, owner)


func _trainer_instance(name: String, card_type: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = card_type
	return CardInstance.create(card, owner)


func _find_effect(effects: Array[BaseEffect], script: Script) -> BaseEffect:
	for effect: BaseEffect in effects:
		if effect != null and is_instance_of(effect, script):
			return effect
	return null


func _effect_path(effect: BaseEffect) -> String:
	if effect == null or effect.get_script() == null:
		return ""
	return str(effect.get_script().resource_path)
