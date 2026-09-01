class_name TestTcgMikRequestedCards20260822Batch3
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const DeckEditorScript := preload("res://scenes/deck_editor/DeckEditor.gd")
const AttackSelfAllAttacksLockNextTurnScript := preload("res://scripts/effects/pokemon_effects/AttackSelfAllAttacksLockNextTurn.gd")

const FINIZEN_EFFECT_ID := "a4600d2953dacffa956d665a7fb29b02"


func test_csv8c062_preserves_source_metadata_asset_and_editor_visibility() -> String:
	CardImplementationStatus.clear_cache()
	var card_path := "res://data/bundled_user/cards/CSV8C_062.json"
	var image_path := "res://data/bundled_user/cards/images/CSV8C/062.png.bin"
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var card := _load_card()
	var db := CardDatabaseScript.new()
	var pooled := db.get_all_cards().any(func(item: CardData) -> bool: return item != null and item.get_uid() == "CSV8C_062")
	db.free()
	var editor := DeckEditorScript.new()
	editor.call("_build_pool")
	var editor_visible := false
	var categories: Array = editor.get("_pool_by_category")
	if not categories.is_empty():
		editor_visible = categories[0].any(func(item: CardData) -> bool: return item != null and item.get_uid() == "CSV8C_062")
	editor.free()
	return run_checks([
		assert_true(FileAccess.file_exists(card_path), "CSV8C_062 bundled JSON should exist"),
		assert_true(CardData.is_valid_card_image_file(image_path), "CSV8C_062 bundled image should be valid"),
		assert_str_contains(manifest, card_path, "CSV8C_062 JSON should be listed in the manifest"),
		assert_str_contains(manifest, image_path, "CSV8C_062 image should be listed in the manifest"),
		assert_not_null(card, "CSV8C_062 should deserialize from bundled JSON"),
		assert_eq(card.name if card != null else "", "波普海豚", "CSV8C_062 should preserve its Chinese name"),
		assert_eq(card.name_en if card != null else "", "Finizen", "CSV8C_062 should preserve its English name"),
		assert_eq(card.effect_id if card != null else "", FINIZEN_EFFECT_ID, "CSV8C_062 should preserve its stable effect_id"),
		assert_eq(card.source_url if card != null else "", "https://tcg.mik.moe/cards/CSV8C/062", "CSV8C_062 should retain its exact source URL"),
		assert_true(pooled, "CSV8C_062 should appear in the complete card pool"),
		assert_true(editor_visible, "CSV8C_062 should be selectable in the DeckEditor Pokemon tab"),
	])


func test_csv8c062_aqua_slash_locks_every_attack_during_next_own_turn() -> String:
	var card := _load_card()
	if card == null:
		return assert_not_null(card, "CSV8C_062 should load")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var finizen := _slot(card, 0)
	state.players[0].active_pokemon = finizen
	var effects := processor.get_attack_effects_for_slot(finizen, 0)
	var lock: BaseEffect = null
	for effect: BaseEffect in effects:
		if effect is AttackSelfAllAttacksLockNextTurnScript:
			lock = effect
			break
	if lock != null:
		lock.execute_attack(finizen, state.players[1].active_pokemon, 0, state)
	return run_checks([
		assert_not_null(lock, "Aqua Slash should register the shared all-attacks lock"),
		assert_true(finizen.effects.any(func(entry: Dictionary) -> bool: return str(entry.get("type", "")) == "attack_lock_all" and int(entry.get("source_attack_index", -1)) == 0), "Aqua Slash should stop Finizen from using any attack during its next turn"),
	])


func _load_card() -> CardData:
	var path := "res://data/bundled_user/cards/CSV8C_062.json"
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
		player.active_pokemon = _slot(_pokemon("Active %d" % owner), owner)
		player.deck = [_trainer_instance("Turn Draw %d" % owner, owner)]
		player.prizes = [_trainer_instance("Prize %d" % owner, owner)]
		state.players.append(player)
	return state


func _pokemon(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = 400
	card.attacks = [{"name": "Tackle", "cost": "", "damage": "10", "text": "", "is_vstar_power": false}]
	return card


func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	slot.turn_played = 0
	return slot


func _trainer_instance(name: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Item"
	return CardInstance.create(card, owner)
