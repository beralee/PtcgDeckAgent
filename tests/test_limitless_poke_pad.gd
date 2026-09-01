class_name TestLimitlessPokePad
extends TestBase

const Parser := preload("res://scripts/network/LimitlessCardParser.gd")
const Resolver := preload("res://scripts/network/LimitlessCardResolver.gd")
const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")

const CARD_UID := "LEN_POR_81"
const CARD_PATH := "res://data/bundled_user/cards/LEN_POR_81.json"
const IMAGE_PATH := "res://data/bundled_user/cards/images/LEN_POR/81.png.bin"
const EFFECT_ID := "37d9368f331023f9145669360477c7ad"


func test_poke_pad_page_parses_and_generates_translated_limitless_card() -> String:
	var parsed := Parser.parse_card_html(_poke_pad_html(), "https://limitlesstcg.com/cards/POR/81")
	var resolved := Resolver.resolve_card(parsed, [])
	var card: CardData = resolved.get("card", null)
	var prints := _packed_to_array(parsed.get("source_prints", PackedStringArray()))
	return run_checks([
		assert_eq(str(parsed.get("name", "")), "Poké Pad", "Parser should preserve the English rule-facing name"),
		assert_eq(str(parsed.get("card_type", "")), "Item", "Parser should map Trainer - Item to Item"),
		assert_eq(str(parsed.get("regulation_mark", "")), "J", "Parser should read a regulation mark written before the label"),
		assert_contains(prints, "ASC/198", "Parser should preserve the Ascended Heroes same-print reference"),
		assert_contains(prints, "POR/113", "Parser should preserve the alternate Perfect Order print"),
		assert_contains(prints, "JP/M3/70", "Parser should preserve complete Japanese print references"),
		assert_contains(prints, "JP/MC/662", "Parser should preserve complete Japanese collection references"),
		assert_true(bool(resolved.get("generated", false)), "A missing POR/81 implementation should generate a LEN card"),
		assert_not_null(card, "Resolver should generate POR/81"),
		assert_eq(card.get_uid() if card != null else "", CARD_UID, "Generated card should use the LEN_POR namespace"),
		assert_eq(card.name if card != null else "", "Poké Pad", "Generated rule name should stay English"),
		assert_eq(card.name_en if card != null else "", "Poké Pad", "Generated English identity should be preserved"),
		assert_eq(card.name_zh if card != null else "", "宝可梦平板", "Generated display name should use the Chinese translation"),
		assert_str_contains(card.description if card != null else "", "没有规则框", "Generated details should use the Chinese translation"),
		assert_eq(card.effect_id if card != null else "", EFFECT_ID, "Generated effect id should stay deterministic"),
		assert_eq(card.image_url if card != null else "", CardData.build_limitless_image_url("POR", "81"), "Generated image URL should use the Limitless image builder convention"),
	])


func test_poke_pad_is_a_complete_runnable_bundled_card() -> String:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARD_PATH))
	var card := CardData.from_dict(raw) if raw is Dictionary else null
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var db := CardDatabaseScript.new()
	var pooled_uids := {}
	for pooled: CardData in db.get_all_cards():
		if pooled != null:
			pooled_uids[pooled.get_uid()] = true
	var resolved_image := CardData.resolve_existing_image_path(
		CardData.get_image_candidate_paths("LEN_POR", "81", "user://cards/images/__missing_limitless_poke_pad__/81.png")
	)
	var image_bytes := FileAccess.get_file_as_bytes(IMAGE_PATH)
	var image := Image.new()
	var decode_error := ERR_FILE_UNRECOGNIZED
	if CardData.has_png_signature(image_bytes):
		decode_error = image.load_png_from_buffer(image_bytes)
	elif CardData.has_jpg_signature(image_bytes):
		decode_error = image.load_jpg_from_buffer(image_bytes)
	elif CardData.has_webp_signature(image_bytes):
		decode_error = image.load_webp_from_buffer(image_bytes)
	var checks: Array[String] = [
		assert_not_null(card, "Bundled Poké Pad JSON should deserialize"),
		assert_str_contains(manifest, CARD_PATH, "Bundled manifest should include Poké Pad JSON"),
		assert_str_contains(manifest, IMAGE_PATH, "Bundled manifest should include Poké Pad image"),
		assert_true(CardData.is_valid_card_image_file(IMAGE_PATH), "Bundled Poké Pad image should be valid"),
		assert_eq(decode_error, OK, "Godot should decode the bundled Poké Pad image"),
		assert_true(resolved_image.begins_with(IMAGE_PATH), "Missing user cache should fall back to the bundled Poké Pad image"),
		assert_true(pooled_uids.has(CARD_UID), "Poké Pad should be visible in the full card pool"),
	]
	if card != null:
		checks.append(assert_eq(card.name, "Poké Pad", "Bundled rule-facing name should stay English"))
		checks.append(assert_eq(card.name_en, "Poké Pad", "Bundled English identity should stay intact"))
		checks.append(assert_eq(card.name_zh, "宝可梦平板", "Bundled display name should be translated"))
		checks.append(assert_eq(card.display_name(), "宝可梦平板", "UI display helper should prefer the Chinese name"))
		checks.append(assert_eq(card.source_provider, "limitless", "Bundled source provider should remain auditable"))
		checks.append(assert_eq(card.source_url, "https://limitlesstcg.com/cards/POR/81", "Bundled source URL should remain auditable"))
		checks.append(assert_eq(card.source_set_code, "POR", "Bundled source set should remain auditable"))
		checks.append(assert_eq(card.source_card_index, "81", "Bundled source number should remain auditable"))
		checks.append(assert_false(CardImplementationStatus.is_unimplemented(card), "Poké Pad should be registered as runnable"))
	db.free()
	return run_checks(checks)


func test_poke_pad_searches_any_non_rule_box_pokemon_and_rejects_rule_box_cards() -> String:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARD_PATH))
	var card_data := CardData.from_dict(raw) if raw is Dictionary else null
	if card_data == null:
		return "Bundled Poké Pad card is missing"
	var gsm := GameStateMachine.new()
	gsm.game_state = _state()
	var player: PlayerState = gsm.game_state.players[0]
	var normal_basic := CardInstance.create(_pokemon("Normal Basic", "Basic"), 0)
	var pokemon_ex := CardInstance.create(_pokemon("Rule Box ex", "Basic", "ex"), 0)
	var deck_item := CardInstance.create(_trainer("Deck Item"), 0)
	var normal_stage_one := CardInstance.create(_pokemon("Normal Stage One", "Stage 1"), 0)
	var radiant := CardInstance.create(_pokemon("Radiant Pokemon", "Basic", "Radiant", ["Radiant"]), 0)
	var tagged_rule_box := CardInstance.create(_pokemon("Tagged Rule Box", "Stage 2", "", ["Rule Box"]), 0)
	player.deck.append_array([normal_basic, pokemon_ex, deck_item, normal_stage_one, radiant, tagged_rule_box])
	var poke_pad := CardInstance.create(card_data, 0)
	player.hand.append(poke_pad)
	var effect := gsm.effect_processor.get_effect(EFFECT_ID)
	if effect == null:
		gsm.prepare_for_disposal()
		return "Poké Pad effect is not registered"
	var steps: Array[Dictionary] = effect.get_interaction_steps(poke_pad, gsm.game_state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var visible_deck := player.deck.duplicate()
	var played := gsm.play_trainer(0, poke_pad, [{"search_pokemon": [pokemon_ex, normal_stage_one]}])
	var checks: Array[String] = [
		assert_eq(str(step.get("id", "")), "search_pokemon", "Poké Pad should reuse the standard Pokemon-search interaction id"),
		assert_eq(step.get("card_items", []), visible_deck, "Poké Pad should expose the full own deck during search"),
		assert_eq(step.get("items", []), [normal_basic, normal_stage_one], "Only non-Rule Box Pokemon should be selectable"),
		assert_eq(step.get("card_indices", []), [0, -1, -1, 1, -1, -1], "Full-deck indices should disable every illegal card"),
		assert_eq(int(step.get("min_select", -1)), 0, "Hidden-deck search should permit an intentional whiff"),
		assert_eq(int(step.get("max_select", -1)), 1, "Poké Pad should take at most one Pokemon"),
		assert_true(bool(step.get("force_confirm", false)), "Poké Pad should support confirming an empty search"),
		assert_true(played, "Poké Pad should play through GameStateMachine"),
		assert_true(normal_stage_one in player.hand, "Selected non-Rule Box Evolution Pokemon should move to hand"),
		assert_false(pokemon_ex in player.hand, "Rule Box Pokemon should never move to hand"),
		assert_true(pokemon_ex in player.deck and radiant in player.deck and tagged_rule_box in player.deck, "All rejected Rule Box Pokemon should remain in deck"),
		assert_true(poke_pad in player.discard_pile, "Played Poké Pad should be discarded"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func _state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	return state


func _pokemon(name: String, stage: String, mechanic: String = "", tags: Array[String] = []) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 100
	card.energy_type = "C"
	card.mechanic = mechanic
	card.is_tags = PackedStringArray(tags)
	return card


func _trainer(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Item"
	return card


func _packed_to_array(value: Variant) -> Array:
	var result: Array = []
	if value is PackedStringArray or value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result


func _poke_pad_html() -> String:
	return """
		<img class="card shadow resp-w" src="https://limitlesstcg.nyc3.cdn.digitaloceanspaces.com/tpci/POR/POR_081_R_EN_LG.png" data-src="https://limitlesstcg.nyc3.cdn.digitaloceanspaces.com/tpci/POR/POR_081_R_EN.png">
		<div class="card-text">
			<div class="card-text-section">
				<p class="card-text-title"><span class="card-text-name"><a href="/cards/POR/81">Poké Pad</a></span></p>
				<p class="card-text-type">Trainer - Item</p>
			</div>
			<div class="card-text-section">Search your deck for a Pokémon that doesn't have a Rule Box, reveal it, and put it into your hand. Then, shuffle your deck. <span class="reminder-text">(Pokémon ex, Pokémon V, etc. have Rule Boxes.)</span></div>
			<div class="card-text-section card-text-artist">Illustrated by <a href="/cards?q=!artist:studio_bora_inc.">Studio Bora Inc.</a></div>
		</div>
		<div class="regulation-mark">J Regulation Mark • <a href="/cards/POR/81/formats">More formats</a></div>
		<div class="prints-current-details"><span>Perfect Order (POR)</span><span>#81 · Uncommon</span></div>
		<a href="/cards/ASC/198">Ascended Heroes #198</a>
		<a href="/cards/POR/113">Perfect Order #113</a>
		<a href="/cards/jp/MP/85">Mega Promotional Cards #85</a>
		<a href="/cards/jp/MC/662">Starter Decks 100 Battle Collection #662</a>
		<a href="/cards/jp/M3/70">Nihil Zero #70</a>
	"""
