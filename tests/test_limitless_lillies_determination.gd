class_name TestLimitlessLilliesDetermination
extends TestBase

const Parser := preload("res://scripts/network/LimitlessCardParser.gd")
const Resolver := preload("res://scripts/network/LimitlessCardResolver.gd")
const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")

const CARD_UID := "LEN_MEG_119"
const CARD_PATH := "res://data/bundled_user/cards/LEN_MEG_119.json"
const IMAGE_PATH := "res://data/bundled_user/cards/images/LEN_MEG/119.png.bin"
const EFFECT_ID := "47fdbe7775a150170eeced33c27c1c72"


func test_page_parses_and_generates_translated_limitless_card() -> String:
	var parsed := Parser.parse_card_html(_card_html(), "https://limitlesstcg.com/cards/MEG/119")
	var resolved := Resolver.resolve_card(parsed, [])
	var card: CardData = resolved.get("card", null)
	var prints := _packed_to_array(parsed.get("source_prints", PackedStringArray()))
	return run_checks([
		assert_eq(str(parsed.get("name", "")), "Lillie's Determination", "Parser should preserve the English rule-facing name"),
		assert_eq(str(parsed.get("card_type", "")), "Supporter", "Parser should map Trainer - Supporter"),
		assert_eq(str(parsed.get("regulation_mark", "")), "I", "Parser should read the regulation mark"),
		assert_contains(prints, "MEG/169", "Parser should preserve the alternate Mega Evolution print"),
		assert_contains(prints, "ASC/192", "Parser should preserve the Ascended Heroes print"),
		assert_contains(prints, "JP/M1L/62", "Parser should preserve the Japanese Mega Brave print"),
		assert_true(bool(resolved.get("generated", false)), "A missing MEG/119 implementation should generate a LEN card"),
		assert_not_null(card, "Resolver should generate MEG/119"),
		assert_eq(card.get_uid() if card != null else "", CARD_UID, "Generated card should use the LEN_MEG namespace"),
		assert_eq(card.name if card != null else "", "Lillie's Determination", "Generated rule name should stay English"),
		assert_eq(card.name_zh if card != null else "", "莉莉艾的决意", "Generated display name should use the Chinese translation"),
		assert_str_contains(card.description if card != null else "", "抽出8张卡", "Generated details should include the six-Prize draw bonus"),
		assert_eq(card.effect_id if card != null else "", EFFECT_ID, "Generated effect id should stay deterministic"),
		assert_eq(card.image_url if card != null else "", CardData.build_limitless_image_url("MEG", "119"), "Generated image URL should use the Limitless convention"),
	])


func test_card_is_complete_runnable_and_bundled() -> String:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARD_PATH))
	var card := CardData.from_dict(raw) if raw is Dictionary else null
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var db := CardDatabaseScript.new()
	var pooled_uids := {}
	for pooled: CardData in db.get_all_cards():
		if pooled != null:
			pooled_uids[pooled.get_uid()] = true
	var resolved_image := CardData.resolve_existing_image_path(
		CardData.get_image_candidate_paths("LEN_MEG", "119", "user://cards/images/__missing_limitless_lillie__/119.png")
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
		assert_not_null(card, "Bundled Lillie's Determination JSON should deserialize"),
		assert_str_contains(manifest, CARD_PATH, "Bundled manifest should include the card JSON"),
		assert_str_contains(manifest, IMAGE_PATH, "Bundled manifest should include the card image"),
		assert_true(CardData.is_valid_card_image_file(IMAGE_PATH), "Bundled card image should be valid"),
		assert_eq(decode_error, OK, "Godot should decode the bundled card image"),
		assert_true(resolved_image.begins_with(IMAGE_PATH), "Missing user cache should fall back to the bundled image"),
		assert_true(pooled_uids.has(CARD_UID), "The card should be visible in the full card pool"),
	]
	if card != null:
		checks.append(assert_eq(card.name, "Lillie's Determination", "Bundled rule-facing name should stay English"))
		checks.append(assert_eq(card.display_name(), "莉莉艾的决意", "UI display helper should prefer the Chinese name"))
		checks.append(assert_eq(card.source_provider, "limitless", "Source provider should remain auditable"))
		checks.append(assert_eq(card.source_url, "https://limitlesstcg.com/cards/MEG/119", "Source URL should remain auditable"))
		checks.append(assert_eq(card.source_set_code, "MEG", "Source set should remain auditable"))
		checks.append(assert_eq(card.source_card_index, "119", "Source number should remain auditable"))
		checks.append(assert_false(CardImplementationStatus.is_unimplemented(card), "The card should be registered as runnable"))
	db.free()
	return run_checks(checks)


func test_exactly_six_prizes_shuffles_hand_and_draws_eight() -> String:
	var result := _play_card(6)
	return run_checks([
		assert_true(bool(result.get("played", false)), "Lillie's Determination should play through GameStateMachine"),
		assert_eq(int(result.get("hand_count", -1)), 8, "Exactly six remaining Prizes should draw eight cards"),
		assert_eq(int(result.get("deck_count", -1)), 6, "Two hand cards should be shuffled into the deck before eight are drawn"),
		assert_true(bool(result.get("supporter_discarded", false)), "The played Supporter should enter the discard pile"),
		assert_true(bool(result.get("fillers_preserved", false)), "Shuffled hand cards should remain in hand or deck, never be discarded"),
	])


func test_fewer_than_six_prizes_draws_six() -> String:
	var result := _play_card(5)
	return run_checks([
		assert_true(bool(result.get("played", false)), "Lillie's Determination should remain playable after taking a Prize"),
		assert_eq(int(result.get("hand_count", -1)), 6, "Any Prize count other than exactly six should draw six cards"),
		assert_eq(int(result.get("deck_count", -1)), 8, "The shuffled deck should retain eight cards after drawing six"),
	])


func test_existing_limitless_decks_use_the_real_card_instead_of_research() -> String:
	var checks: Array[String] = []
	for deck_id: int in [800021836, 800025404, 800026575]:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/decks/%d.json" % deck_id))
		var cards: Array = raw.get("cards", []) if raw is Dictionary else []
		var matched: Dictionary = {}
		for entry: Variant in cards:
			if not (entry is Dictionary):
				continue
			if str(entry.get("source_set_code", "")) == "MEG" and str(entry.get("source_card_index", "")) == "119":
				matched = entry
				break
		checks.append(assert_eq(str(matched.get("set_code", "")), "LEN_MEG", "Deck %d should use the exact imported MEG card" % deck_id))
		checks.append(assert_eq(str(matched.get("card_index", "")), "119", "Deck %d should preserve the source card number" % deck_id))
		checks.append(assert_eq(str(matched.get("effect_id", "")), EFFECT_ID, "Deck %d should use Lillie's Determination semantics" % deck_id))
		checks.append(assert_eq(int(matched.get("count", 0)), 4, "Deck %d should preserve all four copies" % deck_id))
		checks.append(assert_eq(str(matched.get("source_name", "")), "Lillie's Determination", "Deck %d should retain the Limitless source name" % deck_id))
	return run_checks(checks)


func _play_card(prize_count: int) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARD_PATH))
	var card_data := CardData.from_dict(raw) if raw is Dictionary else null
	if card_data == null:
		return {}
	var gsm := GameStateMachine.new()
	gsm.game_state = _state(prize_count)
	var player: PlayerState = gsm.game_state.players[0]
	var supporter := CardInstance.create(card_data, 0)
	var filler_a := CardInstance.create(_trainer("Filler A"), 0)
	var filler_b := CardInstance.create(_trainer("Filler B"), 0)
	player.hand = [supporter, filler_a, filler_b]
	for index: int in 12:
		player.deck.append(CardInstance.create(_trainer("Deck Card %d" % index), 0))
	var played := gsm.play_trainer(0, supporter, [])
	var result := {
		"played": played,
		"hand_count": player.hand.size(),
		"deck_count": player.deck.size(),
		"supporter_discarded": supporter in player.discard_pile,
		"fillers_preserved": (filler_a in player.hand or filler_a in player.deck) and (filler_b in player.hand or filler_b in player.deck),
	}
	gsm.prepare_for_disposal()
	return result


func _state(prize_count: int) -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		for prize_index: int in prize_count:
			player.prizes.append(CardInstance.create(_trainer("Prize %d-%d" % [player_index, prize_index]), player_index))
		state.players.append(player)
	return state


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


func _card_html() -> String:
	return """
		<img class="card shadow resp-w" src="https://limitlesstcg.nyc3.cdn.digitaloceanspaces.com/tpci/MEG/MEG_119_R_EN_LG.png" data-src="https://limitlesstcg.nyc3.cdn.digitaloceanspaces.com/tpci/MEG/MEG_119_R_EN.png">
		<div class="card-text">
			<div class="card-text-section">
				<p class="card-text-title"><span class="card-text-name"><a href="/cards/MEG/119">Lillie's Determination</a></span></p>
				<p class="card-text-type">Trainer - Supporter</p>
			</div>
			<div class="card-text-section">Shuffle your hand into your deck. Then, draw 6 cards. If you have exactly 6 Prize cards remaining, draw 8 cards instead.</div>
			<div class="card-text-section card-text-artist">Illustrated by <a href="/cards?q=!artist:atsushi_furusawa">Atsushi Furusawa</a></div>
		</div>
		<div class="regulation-mark">I Regulation Mark • <a href="/cards/MEG/119/formats">More formats</a></div>
		<div class="prints-current-details"><span>Mega Evolution (MEG)</span><span>#119 · Uncommon</span></div>
		<a href="/cards/MEG/169">Mega Evolution #169</a>
		<a href="/cards/MEG/184">Mega Evolution #184</a>
		<a href="/cards/ASC/192">Ascended Heroes #192</a>
		<a href="/cards/jp/M1L/62">Mega Brave #62</a>
	"""
