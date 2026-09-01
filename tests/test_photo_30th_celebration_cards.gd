class_name TestPhoto30thCelebrationCards
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const AbilityOwnBenchAttacksScript := preload("res://scripts/effects/pokemon_effects/AbilityOwnBenchAttacks.gd")
const AttackExtraPrizeScript := preload("res://scripts/effects/pokemon_effects/AttackExtraPrize.gd")
const AttackSwitchSelfToBenchScript := preload("res://scripts/effects/pokemon_effects/AttackSwitchSelfToBench.gd")

const UNOWN_EFFECT_ID := "6f032c3b7bf63df90da2a8d8886ac9b6"
const MEW_EFFECT_ID := "9256615fd387482e220b7e2630343eb7"
const UNOWN_PATH := "res://data/bundled_user/cards/M6A_060.json"
const MEW_PATH := "res://data/bundled_user/cards/30THC_057.json"
const UNOWN_IMAGE := "res://data/bundled_user/cards/images/M6A/060.png.bin"
const MEW_IMAGE := "res://data/bundled_user/cards/images/30THC/057.png.bin"


func test_photo_cards_bundle_auditable_identity_text_and_images() -> String:
	var db := CardDatabaseScript.new()
	var unown: CardData = db.get_card("M6A", "060")
	var mew: CardData = db.get_card("30THC", "057")
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var checks: Array[String] = [
		assert_not_null(unown, "M6A_060 Unown should load from the bundled card pool"),
		assert_not_null(mew, "30THC_057 Mew ex should load from the bundled card pool"),
		assert_str_contains(manifest, UNOWN_PATH, "Manifest should include the photographed Unown JSON"),
		assert_str_contains(manifest, MEW_PATH, "Manifest should include the photographed Mew ex JSON"),
		assert_str_contains(manifest, UNOWN_IMAGE, "Manifest should include the photographed Unown image"),
		assert_str_contains(manifest, MEW_IMAGE, "Manifest should include the photographed Mew ex image"),
		_assert_image_decodes(UNOWN_IMAGE, "Unown"),
		_assert_image_decodes(MEW_IMAGE, "Mew ex"),
		assert_true(_resolved_bundled_image("M6A", "060").begins_with(UNOWN_IMAGE), "Unown should fall back to its bundled photo when user cache is absent"),
		assert_true(_resolved_bundled_image("30THC", "057").begins_with(MEW_IMAGE), "Mew ex should fall back to its bundled photo when user cache is absent"),
	]
	if unown != null:
		checks.append_array([
			assert_eq(unown.name, "Unown", "Unown rule-facing identity should stay English"),
			assert_eq(unown.name_zh, "未知图腾", "Unown should expose its Chinese display name"),
			assert_eq(unown.display_name(), "未知图腾", "Unown UI name should prefer Chinese"),
			assert_eq(unown.hp, 80, "Unown should preserve the photographed 80 HP"),
			assert_eq(str(unown.attacks[0].get("name", "")), "Mystery Signal", "Unown attack identity should stay stable in English"),
			assert_eq(CardData.dictionary_display_name(unown.attacks[0]), "神秘信号", "Unown attack UI should use Chinese"),
			assert_eq(unown.source_provider, "user_photo", "Unown should retain its photo source provenance"),
			assert_eq(unown.source_language, "ja", "Unown should retain its Japanese source language"),
			assert_eq(unown.source_url, "https://www.serebii.net/card/30thcelebrationjapan/060.shtml", "Unown should retain its verification URL"),
			assert_false(CardImplementationStatus.is_unimplemented(unown), "Unown should be marked runnable after its attack effect is registered"),
		])
	if mew != null:
		checks.append_array([
			assert_eq(mew.name, "Mew ex", "Mew ex rule-facing identity should stay English"),
			assert_eq(mew.name_zh, "梦幻ex", "Mew ex should expose its Chinese display name"),
			assert_eq(mew.display_name(), "梦幻ex", "Mew ex UI name should prefer Chinese"),
			assert_eq(mew.hp, 160, "Mew ex should preserve the photographed 160 HP"),
			assert_eq(mew.mechanic, "ex", "Mew ex should retain its two-Prize rule-box mechanic"),
			assert_eq(str(mew.abilities[0].get("name", "")), "Memory Helix", "Mew ex Ability identity should stay stable in English"),
			assert_eq(CardData.dictionary_display_name(mew.abilities[0]), "记忆螺旋", "Mew ex Ability UI should use Chinese"),
			assert_eq(str(mew.attacks[0].get("name", "")), "Teleportation Burst", "Mew ex attack identity should stay stable in English"),
			assert_eq(CardData.dictionary_display_name(mew.attacks[0]), "瞬移破坏", "Mew ex attack UI should use Chinese"),
			assert_eq(mew.source_language, "zh-CN", "Mew ex should retain its Simplified Chinese source language"),
			assert_eq(mew.source_set_code, "30th C", "Mew ex should preserve the set code printed on the photo"),
			assert_false(CardImplementationStatus.is_unimplemented(mew), "Mew ex should be marked runnable after its Ability and attack effects are registered"),
		])
	db.free()
	return run_checks(checks)


func test_effect_ids_bind_to_extra_prize_bench_copy_and_optional_switch() -> String:
	var unown := _load_card(UNOWN_PATH)
	var mew := _load_card(MEW_PATH)
	if unown == null or mew == null:
		return "Photographed 30th Celebration card JSON is missing"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(unown)
	processor.register_pokemon_card(mew)
	var unown_slot := _slot(unown, 0)
	var mew_slot := _slot(mew, 0)
	var unown_effects := processor.get_attack_effects_for_slot(unown_slot, 0)
	var mew_effects := processor.get_attack_effects_for_slot(mew_slot, 0)
	var checks: Array[String] = [
		assert_true(processor.get_effect(MEW_EFFECT_ID) is AbilityOwnBenchAttacksScript, "Memory Helix should register the own-Bench attack grant effect"),
		assert_eq(unown_effects.size(), 1, "Mystery Signal should register exactly one attack effect"),
		assert_true(unown_effects[0] is AttackExtraPrizeScript, "Mystery Signal should bind the damage-KO extra-Prize effect"),
		assert_eq(mew_effects.size(), 1, "Teleportation Burst should register exactly one attack effect"),
		assert_true(mew_effects[0] is AttackSwitchSelfToBenchScript, "Teleportation Burst should bind the optional self-switch effect"),
	]
	processor.prepare_for_disposal()
	return run_checks(checks)


func test_memory_helix_grants_every_bench_attack_obeys_cost_and_copies_ko_effect() -> String:
	var unown := _load_card(UNOWN_PATH)
	var mew := _load_card(MEW_PATH)
	if unown == null or mew == null:
		return "Photographed 30th Celebration card JSON is missing"
	var gsm := _gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var mew_slot := _slot(mew, 0)
	var unown_slot := _slot(unown, 0)
	var toolbox := _pokemon("Bench Toolbox", 100, [
		_attack("Tap", "P", "10"),
		_attack("Double Hit", "PC", "50"),
	])
	toolbox.effect_id = "photo_30th_bench_toolbox"
	var toolbox_slot := _slot(toolbox, 0)
	player.active_pokemon = mew_slot
	player.bench = [unown_slot, toolbox_slot]
	opponent.active_pokemon = _slot(_pokemon("40 HP Target", 40), 1)
	opponent.bench = [_slot(_pokemon("Replacement", 100), 1)]
	for index: int in 4:
		player.prizes.append(CardInstance.create(_pokemon("Prize %d" % index, 10), 0))
	for index: int in 6:
		opponent.prizes.append(CardInstance.create(_pokemon("Opponent Prize %d" % index, 10), 1))
	gsm.effect_processor.register_pokemon_card(mew)
	gsm.effect_processor.register_pokemon_card(unown)
	gsm.effect_processor.register_pokemon_card(toolbox)

	mew_slot.attached_energy.append(CardInstance.create(_energy("Psychic A", "P"), 0))
	var granted := gsm.effect_processor.get_granted_attacks(mew_slot, gsm.game_state)
	var names: Array[String] = []
	for attack: Dictionary in granted:
		names.append(str(attack.get("name", "")))
	var mystery := _find_granted_attack(granted, UNOWN_EFFECT_ID, 0)
	var can_use_with_one := gsm.rule_validator.can_use_granted_attack(gsm.game_state, 0, mew_slot, mystery, gsm.effect_processor)
	mew_slot.attached_energy.append(CardInstance.create(_energy("Psychic B", "P"), 0))
	var can_use_with_two := gsm.rule_validator.can_use_granted_attack(gsm.game_state, 0, mew_slot, mystery, gsm.effect_processor)
	var used := gsm.use_granted_attack(0, mew_slot, mystery)
	var pending_before_prizes := int(gsm.get("_pending_prize_remaining"))
	var took_first := gsm.resolve_take_prize(0, 0)
	var took_second := gsm.resolve_take_prize(0, 1)
	var other_target_grants := gsm.effect_processor.get_granted_attacks(unown_slot, gsm.game_state)

	var checks: Array[String] = [
		assert_eq(granted.size(), 3, "Memory Helix should grant every printed attack from both Benched Pokemon"),
		assert_contains(names, "Mystery Signal", "Memory Helix should grant Unown's attack"),
		assert_contains(names, "Tap", "Memory Helix should grant a first attack from another Benched Pokemon"),
		assert_contains(names, "Double Hit", "Memory Helix should grant later attacks, not only attack 0"),
		assert_false(can_use_with_one, "Mew ex should not use Mystery Signal with only one Psychic Energy"),
		assert_true(can_use_with_two, "Mew ex should use Mystery Signal after meeting its printed PP cost"),
		assert_true(used, "Mew ex should execute the granted Mystery Signal through GameStateMachine"),
		assert_eq(pending_before_prizes, 2, "Copied Mystery Signal should queue the normal Prize plus one extra Prize"),
		assert_true(took_first, "Copied Mystery Signal should allow the first explicit Prize selection"),
		assert_true(took_second, "Copied Mystery Signal should allow the second explicit Prize selection"),
		assert_eq(player.hand.size(), 2, "Copied Mystery Signal should take the normal Prize plus one extra Prize"),
		assert_eq(player.prizes.size(), 2, "Copied Mystery Signal should remove two cards from a four-card Prize pile"),
		assert_eq(other_target_grants.size(), 0, "Memory Helix should grant attacks only to the Mew ex that owns the Ability"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_teleportation_burst_deals_30_and_switches_to_selected_bench_pokemon() -> String:
	var mew := _load_card(MEW_PATH)
	if mew == null:
		return "Photographed Mew ex JSON is missing"
	var gsm := _gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var mew_slot := _slot(mew, 0)
	var selected := _slot(_pokemon("Selected Pivot", 100), 0)
	var unselected := _slot(_pokemon("Unselected Pivot", 100), 0)
	player.active_pokemon = mew_slot
	player.bench = [unselected, selected]
	opponent.active_pokemon = _slot(_pokemon("Target", 120), 1)
	mew_slot.attached_energy.append(CardInstance.create(_energy("Psychic", "P"), 0))
	gsm.effect_processor.register_pokemon_card(mew)

	var effects := gsm.effect_processor.get_attack_effects_for_slot(mew_slot, 0)
	var steps: Array[Dictionary] = effects[0].get_attack_interaction_steps(
		mew_slot.get_top_card(),
		mew.attacks[0],
		gsm.game_state
	) if not effects.is_empty() else []
	var used := gsm.use_attack(0, 0, [{"switch_target": [selected]}])
	var checks: Array[String] = [
		assert_eq(steps.size(), 1, "Teleportation Burst should expose one optional Bench switch interaction"),
		assert_true(bool(steps[0].get("allow_cancel", false)) if not steps.is_empty() else false, "Teleportation Burst's switch should be optional"),
		assert_true(used, "Mew ex should use Teleportation Burst with one Psychic Energy"),
		assert_eq(opponent.active_pokemon.damage_counters, 30, "Teleportation Burst should deal its printed 30 damage"),
		assert_eq(player.active_pokemon, selected, "Teleportation Burst should promote the selected Benched Pokemon"),
		assert_contains(player.bench, mew_slot, "Mew ex should move to the Bench after the optional switch"),
		assert_contains(player.bench, unselected, "The unselected Benched Pokemon should remain on the Bench"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func _gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	gsm.game_state = state
	gsm.effect_processor.bind_game_state_machine(gsm)
	return gsm


func _load_card(path: String) -> CardData:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(raw) if raw is Dictionary else null


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	slot.turn_played = 0
	return slot


func _pokemon(name: String, hp: int, attacks: Array[Dictionary] = []) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = hp
	card.attacks = attacks
	return card


func _attack(name: String, cost: String, damage: String, text: String = "") -> Dictionary:
	return {
		"name": name,
		"cost": cost,
		"damage": damage,
		"text": text,
		"is_vstar_power": false,
	}


func _energy(name: String, energy_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_provides = energy_type
	card.energy_type = energy_type
	return card


func _find_granted_attack(attacks: Array[Dictionary], original_effect_id: String, original_attack_index: int) -> Dictionary:
	for attack: Dictionary in attacks:
		if (
			str(attack.get("original_effect_id", "")) == original_effect_id
			and int(attack.get("original_attack_index", -1)) == original_attack_index
		):
			return attack
	return {}


func _resolved_bundled_image(set_code: String, card_index: String) -> String:
	return CardData.resolve_existing_image_path(CardData.get_image_candidate_paths(
		set_code,
		card_index,
		"user://cards/images/__missing_photo_30th__/%s.png" % card_index
	))


func _assert_image_decodes(path: String, label: String) -> String:
	if not CardData.is_valid_card_image_file(path):
		return "%s bundled image should have a supported image signature" % label
	var bytes := FileAccess.get_file_as_bytes(path)
	var image := Image.new()
	var error := ERR_FILE_UNRECOGNIZED
	if CardData.has_png_signature(bytes):
		error = image.load_png_from_buffer(bytes)
	elif CardData.has_jpg_signature(bytes):
		error = image.load_jpg_from_buffer(bytes)
	elif CardData.has_webp_signature(bytes):
		error = image.load_webp_from_buffer(bytes)
	return assert_eq(error, OK, "%s bundled image should decode in Godot" % label)
