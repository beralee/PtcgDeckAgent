class_name TestTcgMikRequestedCards20260822Batch1
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const DeckEditorScript := preload("res://scenes/deck_editor/DeckEditor.gd")
const AttackBonusIfDefenderDamagedScript := preload("res://scripts/effects/pokemon_effects/AttackBonusIfDefenderDamaged.gd")
const AttackSelfLockNextTurnScript := preload("res://scripts/effects/pokemon_effects/AttackSelfLockNextTurn.gd")
const AttackSelfDamageCounterBonusScript := preload("res://scripts/effects/pokemon_effects/AttackSelfDamageCounterBonus.gd")
const EffectSelfDamageScript := preload("res://scripts/effects/pokemon_effects/EffectSelfDamage.gd")
const AttackCoinFlipBonusDamageScript := preload("res://scripts/effects/pokemon_effects/AttackCoinFlipBonusDamage.gd")

const MIRAIDON_EFFECT_ID := "c996546aa1c4254d9f1c41d265b9f016"
const KORAIDON_EFFECT_ID := "1d75a8974ad24952cc961bbb1a27ffc8"
const CLODSIRE_EFFECT_ID := "87cc640402d6b606ee4ef78b7c9d2689"
const WOOPER_EFFECT_ID := "ffa371eb22d9dfd66abab6a42085d22a"
const OKIDOGI_EFFECT_ID := "0da4be5989cece0719477261c8571fd9"


class RiggedCoinFlipper:
	extends CoinFlipper

	var results: Array[bool] = []

	func _init(sequence: Array[bool]) -> void:
		results = sequence.duplicate()

	func flip() -> bool:
		var value := true
		if not results.is_empty():
			value = results.pop_front()
		coin_flipped.emit(value)
		return value


func test_batch1_cards_preserve_source_metadata_assets_and_editor_visibility() -> String:
	CardImplementationStatus.clear_cache()
	var specs := [
		{"set": "CSVH4C", "index": "024", "name": "密勒顿ex", "name_en": "Miraidon ex", "effect_id": MIRAIDON_EFFECT_ID, "stage": "Basic", "attacks": 2, "abilities": 0},
		{"set": "CSVH5pC", "index": "006", "name": "故勒顿ex", "name_en": "Koraidon ex", "effect_id": KORAIDON_EFFECT_ID, "stage": "Basic", "attacks": 2, "abilities": 0},
		{"set": "CSVL1C", "index": "039", "name": "帕底亚 土王ex", "name_en": "Paldean Clodsire ex", "effect_id": CLODSIRE_EFFECT_ID, "stage": "Stage 1", "attacks": 1, "abilities": 1},
		{"set": "CBB4C", "index": "0501", "name": "帕底亚 乌波", "name_en": "Paldean Wooper", "effect_id": WOOPER_EFFECT_ID, "stage": "Basic", "attacks": 1, "abilities": 0},
		{"set": "CSV8C", "index": "133", "name": "够赞狗ex", "name_en": "Okidogi ex", "effect_id": OKIDOGI_EFFECT_ID, "stage": "Basic", "attacks": 2, "abilities": 0},
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
		var card: CardData = db.get_card(set_code, card_index)
		var bundled_card := _load_card(set_code, card_index)
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled JSON should exist" % uid))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should be a valid card image" % uid))
		checks.append(assert_str_contains(manifest, card_path, "%s JSON should be listed in the bundled manifest" % uid))
		checks.append(assert_str_contains(manifest, image_path, "%s image should be listed in the bundled manifest" % uid))
		checks.append(assert_not_null(card, "%s should load through CardDatabase" % uid))
		checks.append(assert_true(pooled_uids.has(uid), "%s should appear in the complete card pool" % uid))
		if card == null:
			continue
		checks.append(assert_eq(card.name, str(spec.get("name", "")), "%s should preserve the API Chinese name" % uid))
		checks.append(assert_eq(card.name_en, str(spec.get("name_en", "")), "%s should preserve the API English name" % uid))
		checks.append(assert_eq(card.effect_id, str(spec.get("effect_id", "")), "%s should preserve its stable effect_id" % uid))
		checks.append(assert_eq(card.stage, str(spec.get("stage", "")), "%s should preserve its evolution stage" % uid))
		checks.append(assert_eq(card.attacks.size(), int(spec.get("attacks", -1)), "%s should preserve every printed attack" % uid))
		checks.append(assert_eq(card.abilities.size(), int(spec.get("abilities", -1)), "%s should preserve every printed Ability" % uid))
		checks.append(assert_eq(bundled_card.source_provider if bundled_card != null else "", "tcg_mik", "%s should retain source provenance" % uid))
		checks.append(assert_eq(bundled_card.source_url if bundled_card != null else "", "https://tcg.mik.moe/cards/%s/%s" % [set_code, card_index], "%s should retain its exact source URL" % uid))
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


func test_csvh4c024_miraidon_exact_conditional_bonus_and_same_attack_lock() -> String:
	var card := _load_card("CSVH4C", "024")
	if card == null:
		return assert_not_null(card, "CSVH4C_024 should load")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var attacker := _slot(card, 0)
	var defender := state.players[1].active_pokemon
	state.players[0].active_pokemon = attacker
	var first_effects := processor.get_attack_effects_for_slot(attacker, 0)
	var second_effects := processor.get_attack_effects_for_slot(attacker, 1)
	var bonus_effect := _find_effect(first_effects, AttackBonusIfDefenderDamagedScript)
	var lock_effect := _find_effect(second_effects, AttackSelfLockNextTurnScript)
	var healthy_bonus := int(bonus_effect.call("get_damage_bonus", attacker, state)) if bonus_effect != null else -1
	defender.damage_counters = 10
	var damaged_bonus := int(bonus_effect.call("get_damage_bonus", attacker, state)) if bonus_effect != null else -1
	if lock_effect != null:
		lock_effect.call("execute_attack", attacker, defender, 1, state)
	return run_checks([
		assert_not_null(bonus_effect, "Repulsion Bolt should register defender-damaged conditional damage"),
		assert_eq(healthy_bonus, 0, "Repulsion Bolt should stay at 60 against an undamaged Active Pokemon"),
		assert_eq(damaged_bonus, 100, "Repulsion Bolt should add exactly 100 against a damaged Active Pokemon"),
		assert_not_null(lock_effect, "Cyber Drive should register the shared same-attack lock"),
		assert_true(attacker.effects.any(func(entry: Dictionary) -> bool: return str(entry.get("type", "")) == "attack_lock" and int(entry.get("attack_index", -1)) == 1), "Cyber Drive should lock only attack index 1 during Miraidon's next turn"),
	])


func test_csvh5pc006_koraidon_revenge_counter_math_and_recoil_are_exact() -> String:
	var card := _load_card("CSVH5pC", "006")
	if card == null:
		return assert_not_null(card, "CSVH5pC_006 should load")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var attacker := _slot(card, 0)
	state.players[0].active_pokemon = attacker
	attacker.damage_counters = 40
	var first_effects := processor.get_attack_effects_for_slot(attacker, 0)
	var second_effects := processor.get_attack_effects_for_slot(attacker, 1)
	var counter_effect := _find_effect(first_effects, AttackSelfDamageCounterBonusScript)
	var recoil_effect := _find_effect(second_effects, EffectSelfDamageScript)
	var bonus := int(counter_effect.call("get_damage_bonus", attacker, state)) if counter_effect != null else -1
	if recoil_effect != null:
		recoil_effect.call("execute_attack", attacker, state.players[1].active_pokemon, 1, state)
	return run_checks([
		assert_not_null(counter_effect, "Revenge Punishment should use additive self-damage-counter scaling"),
		assert_eq(bonus, 40, "Four damage counters should add exactly 40 to Revenge Punishment's printed 20"),
		assert_not_null(recoil_effect, "Kaiser Tackle should register recoil"),
		assert_eq(attacker.damage_counters, 100, "Kaiser Tackle should add exactly 60 self-damage after the existing 40"),
	])


func test_csvl1c039_clodsire_poison_ability_timing_and_spike_bone_coin_branches() -> String:
	var card := _load_card("CSVL1C", "039")
	if card == null:
		return assert_not_null(card, "CSVL1C_039 should load")
	var processor := EffectProcessor.new(RiggedCoinFlipper.new([false]))
	processor.register_pokemon_card(card)
	var state := _make_state()
	var clodsire := _slot(card, 0)
	state.players[0].bench = [clodsire]
	var ability := processor.get_effect(CLODSIRE_EFFECT_ID)
	var unavailable_without_stadium := ability == null or not bool(ability.call("can_use_ability", clodsire, state))
	state.stadium_card = _trainer_instance("Test Stadium", "Stadium", 0)
	var available_with_stadium := ability != null and bool(ability.call("can_use_ability", clodsire, state))
	var used := processor.execute_ability_effect(clodsire, 0, [], state)
	var reusable_same_turn := processor.can_use_ability(clodsire, state, 0)
	state.turn_number = 2
	state.current_player_index = 1
	var usable_on_opponent_turn := processor.can_use_ability(clodsire, state, 0)

	var tails_attacker := _slot(card, 0)
	state.players[0].active_pokemon = tails_attacker
	state.current_player_index = 0
	var tails_cancelled := processor.attack_damage_cancelled(tails_attacker, 0, state.players[1].active_pokemon, state)
	processor.execute_attack_effect(tails_attacker, 0, state.players[1].active_pokemon, state)
	var tails_locked := tails_attacker.effects.any(func(entry: Dictionary) -> bool: return str(entry.get("type", "")) == "attack_lock_all")

	var heads_processor := EffectProcessor.new(RiggedCoinFlipper.new([true]))
	heads_processor.register_pokemon_card(card)
	var heads_attacker := _slot(card, 0)
	state.players[0].active_pokemon = heads_attacker
	var heads_cancelled := heads_processor.attack_damage_cancelled(heads_attacker, 0, state.players[1].active_pokemon, state)
	heads_processor.execute_attack_effect(heads_attacker, 0, state.players[1].active_pokemon, state)
	var heads_locked := heads_attacker.effects.any(func(entry: Dictionary) -> bool: return str(entry.get("type", "")) == "attack_lock_all" and int(entry.get("source_attack_index", -1)) == 0)
	return run_checks([
		assert_not_null(ability, "Toxic Wetland should register as Clodsire ex's Ability"),
		assert_true(unavailable_without_stadium, "Toxic Wetland should require a Stadium in play"),
		assert_true(available_with_stadium, "Toxic Wetland should be usable during its owner's turn while a Stadium is in play"),
		assert_true(used, "Toxic Wetland should resolve through EffectProcessor"),
		assert_true(state.players[1].active_pokemon.status_conditions.get("poisoned", false), "Toxic Wetland should Poison only the opponent's Active Pokemon"),
		assert_false(reusable_same_turn, "Toxic Wetland should be limited to once during the owner's turn"),
		assert_false(usable_on_opponent_turn, "Toxic Wetland should never be usable during the opponent's turn"),
		assert_true(tails_cancelled, "Spike Bone should deal no damage on tails"),
		assert_false(tails_locked, "Spike Bone should not lock Clodsire's attacks on tails"),
		assert_false(heads_cancelled, "Spike Bone should deal its printed 200 damage on heads"),
		assert_true(heads_locked, "Spike Bone should lock all of Clodsire's attacks during its next turn on heads"),
	])


func test_cbb4c0501_wooper_rollout_adds_twenty_only_on_heads() -> String:
	var card := _load_card("CBB4C", "0501")
	if card == null:
		return assert_not_null(card, "CBB4C_0501 should load")
	var state := _make_state()
	var attacker := _slot(card, 0)
	var defender := state.players[1].active_pokemon
	var heads_processor := EffectProcessor.new(RiggedCoinFlipper.new([true]))
	heads_processor.register_pokemon_card(card)
	var heads_effect := _find_effect(heads_processor.get_attack_effects_for_slot(attacker, 0), AttackCoinFlipBonusDamageScript)
	if heads_effect != null:
		heads_effect.call("execute_attack", attacker, defender, 0, state)
	var heads_bonus := defender.damage_counters
	defender.damage_counters = 0
	var tails_processor := EffectProcessor.new(RiggedCoinFlipper.new([false]))
	tails_processor.register_pokemon_card(card)
	var tails_effect := _find_effect(tails_processor.get_attack_effects_for_slot(attacker, 0), AttackCoinFlipBonusDamageScript)
	if tails_effect != null:
		tails_effect.call("execute_attack", attacker, defender, 0, state)
	return run_checks([
		assert_not_null(heads_effect, "Rollout should register the shared coin-flip bonus effect"),
		assert_eq(heads_bonus, 20, "Rollout should add exactly 20 damage on heads"),
		assert_not_null(tails_effect, "Rollout should retain the coin-flip effect on the tails branch"),
		assert_eq(defender.damage_counters, 0, "Rollout should add no damage on tails"),
	])


func test_csv8c133_okidogi_full_deck_visibility_legality_and_poison_boundary() -> String:
	var card := _load_card("CSV8C", "133")
	if card == null:
		return assert_not_null(card, "CSV8C_133 should load")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var player := state.players[0]
	var attacker := _slot(card, 0)
	player.active_pokemon = attacker
	player.deck.clear()
	var darkness := _energy_instance("Basic Darkness", "D", 0)
	var lightning := _energy_instance("Basic Lightning", "L", 0)
	var item := _trainer_instance("Visible Item", "Item", 0)
	player.deck = [darkness, lightning, item]
	var effects := processor.get_attack_effects_for_slot(attacker, 0)
	var steps: Array = effects[0].get_attack_interaction_steps(attacker.get_top_card(), card.attacks[0], state) if not effects.is_empty() else []
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	if not effects.is_empty():
		effects[0].set_attack_interaction_context([{"energy_assignments": [{"source": darkness, "target": attacker}]}])
		effects[0].execute_attack(attacker, state.players[1].active_pokemon, 0, state)
		effects[0].clear_attack_interaction_context()
	var attached_and_poisoned := darkness in attacker.attached_energy and bool(attacker.status_conditions.get("poisoned", false))

	var decline_attacker := _slot(card, 0)
	player.active_pokemon = decline_attacker
	player.deck = [_energy_instance("Declined Darkness", "D", 0), _trainer_instance("Still Visible", "Item", 0)]
	if not effects.is_empty():
		effects[0].set_attack_interaction_context([{"energy_assignments": []}])
		effects[0].execute_attack(decline_attacker, state.players[1].active_pokemon, 0, state)
		effects[0].clear_attack_interaction_context()
	return run_checks([
		assert_false(effects.is_empty(), "Toxic Muscle should register its deck-to-self Energy attachment effect"),
		assert_eq(str(step.get("source_visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Toxic Muscle should show the complete own deck"),
		assert_eq(step.get("source_card_items", []), [darkness, lightning, item], "Toxic Muscle should keep legal and illegal deck cards visible"),
		assert_eq(step.get("source_items", []), [darkness], "Only Basic Darkness Energy should be selectable"),
		assert_eq(step.get("source_card_indices", []), [0, -1, -1], "Non-Darkness cards should remain visible but disabled"),
		assert_true(attached_and_poisoned, "Attaching at least one Basic Darkness Energy should Poison Okidogi ex"),
		assert_false(decline_attacker.status_conditions.get("poisoned", false), "Explicitly attaching no Energy should not Poison Okidogi ex"),
		assert_true(decline_attacker.attached_energy.is_empty(), "An explicit empty selection should not auto-attach an Energy"),
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
	state.turn_number = 1
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot(_pokemon("Active %d" % owner, 400), owner)
		player.deck = [_trainer_instance("Turn Draw %d" % owner, "Item", owner)]
		player.prizes = [_trainer_instance("Prize %d" % owner, "Item", owner)]
		state.players.append(player)
	return state


func _pokemon(name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = hp
	card.attacks = [{"name": "Tackle", "cost": "", "damage": "10", "text": "", "is_vstar_power": false}]
	return card


func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
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
