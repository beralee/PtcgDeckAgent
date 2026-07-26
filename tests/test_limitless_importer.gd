class_name TestLimitlessImporter
extends TestBase

const Parser := preload("res://scripts/network/LimitlessCardParser.gd")
const Resolver := preload("res://scripts/network/LimitlessCardResolver.gd")
const DeckImporterScript := preload("res://scripts/network/DeckImporter.gd")


func test_parse_arven_extracts_print_group_and_image() -> String:
	var parsed := Parser.parse_card_html(_arven_html(), "https://limitlesstcg.com/cards/OBF/186")
	var prints := _packed_to_array(parsed.get("source_prints", PackedStringArray()))
	return run_checks([
		assert_eq(parsed.get("name_en", ""), "Arven", "Arven name should parse from card text"),
		assert_eq(parsed.get("card_type", ""), "Supporter", "Trainer subtype should map to local card type"),
		assert_eq(parsed.get("source_set_code", ""), "OBF", "Source set should come from URL"),
		assert_eq(parsed.get("source_card_index", ""), "186", "Source number should normalize as a number"),
		assert_contains(prints, "SVI/166", "Same-print list should include the playable SVI Arven print"),
		assert_str_contains(parsed.get("image_url", ""), "OBF_186_R_EN.png", "Parser should keep Limitless CDN card image"),
		assert_str_contains(parsed.get("description", ""), "Pokemon Tool", "Supporter rules text should be preserved"),
	])


func test_parse_ns_zoroark_ex_extracts_ability_and_attack() -> String:
	var parsed := Parser.parse_card_html(_ns_zoroark_html(), "https://limitlesstcg.com/cards/JTG/98")
	var abilities: Array = parsed.get("abilities", [])
	var attacks: Array = parsed.get("attacks", [])
	var ability: Dictionary = abilities[0] if abilities.size() > 0 else {}
	var attack: Dictionary = attacks[0] if attacks.size() > 0 else {}
	return run_checks([
		assert_eq(parsed.get("card_type", ""), "Pokemon", "Pokemon type should parse"),
		assert_eq(parsed.get("mechanic", ""), "ex", "ex suffix should become mechanic"),
		assert_eq(parsed.get("stage", ""), "Stage 1", "Stage should parse from type line"),
		assert_eq(parsed.get("evolves_from", ""), "N's Zorua", "Evolution source should parse from type line"),
		assert_eq(parsed.get("energy_type", ""), "D", "Darkness should map to D"),
		assert_eq(int(parsed.get("hp", 0)), 280, "HP should parse from type line"),
		assert_eq(parsed.get("weakness_energy", ""), "G", "Weakness energy should parse from card-text-wrr"),
		assert_eq(parsed.get("weakness_value", ""), "x2", "Limitless weakness without an explicit value should default to x2"),
		assert_eq(parsed.get("resistance_energy", ""), "", "Resistance none should remain empty"),
		assert_eq(parsed.get("resistance_value", ""), "", "Resistance none should remain empty"),
		assert_eq(int(parsed.get("retreat_cost", 0)), 2, "Retreat cost should parse from card-text-wrr"),
		assert_eq(parsed.get("artist", ""), "takuyoa", "Artist should parse from card-text-artist"),
		assert_eq(ability.get("name", ""), "Trade", "Ability name should parse"),
		assert_str_contains(ability.get("text", ""), "draw 2 cards", "Ability text should parse"),
		assert_eq(attack.get("name", ""), "Night Joker", "Attack name should parse"),
		assert_eq(attack.get("cost", ""), "DD", "Attack cost should normalize to internal symbols"),
	])


func test_parse_secret_box_marks_ace_spec_from_lookup() -> String:
	var parsed := Parser.parse_card_html(_secret_box_html(), "https://limitlesstcg.com/cards/TWM/163")
	var tags := _packed_to_array(parsed.get("is_tags", PackedStringArray()))
	return run_checks([
		assert_eq(parsed.get("card_type", ""), "Item", "Secret Box should parse as Item"),
		assert_eq(parsed.get("mechanic", ""), "ACE SPEC", "Known ACE SPEC refs should be tagged even when detail HTML omits it"),
		assert_contains(tags, "ACE SPEC", "ACE SPEC should be present in tags"),
	])


func test_parse_deck_entries_uses_limitless_data_attrs() -> String:
	var parsed := Parser.parse_deck_html(_deck_html(), "https://limitlesstcg.com/decks/list/18921")
	var cards: Array = parsed.get("cards", [])
	var first: Dictionary = cards[0] if cards.size() > 0 else {}
	var last: Dictionary = cards[cards.size() - 1] if cards.size() > 0 else {}
	return run_checks([
		assert_eq(int(parsed.get("id", 0)), 800018921, "Limitless deck id should use the high positive local namespace"),
		assert_eq(int(parsed.get("total_cards", 0)), 12, "Deck parser should add row counts"),
		assert_eq(first.get("source_set_code", ""), "JTG", "Deck entries should read data-set"),
		assert_eq(first.get("source_card_index", ""), "97", "Deck entries should read data-number"),
		assert_eq(first.get("name_en", ""), "N's Zorua", "Deck entries should read card names"),
		assert_eq(last.get("card_type", ""), "Basic Energy", "Energy section/basic-energy attr should produce Basic Energy"),
	])


func test_parse_deck_title_removes_limitless_price_markup() -> String:
	var parsed := Parser.parse_deck_html(_priced_deck_html(), "https://limitlesstcg.com/decks/list/18497")
	return run_checks([
		assert_eq(str(parsed.get("deck_name", "")), "Gardevoir", "Deck title should not include price or whitespace markup"),
	])


func test_parse_full_trainer_page_keeps_only_card_rules_text() -> String:
	var parsed := Parser.parse_card_html(_full_trainer_page_html(), "https://limitlesstcg.com/cards/SCR/133")
	return run_checks([
		assert_eq(str(parsed.get("name", "")), "Crispin", "Full trainer page should parse the card name"),
		assert_eq(str(parsed.get("card_type", "")), "Supporter", "Full trainer page should parse the trainer subtype"),
		assert_eq(str(parsed.get("description", "")), "Search your deck for up to 2 Basic Energy cards of different types, reveal them, and put 1 of them into your hand. Attach the other to 1 of your Pokemon. Then, shuffle your deck.", "Trainer description should stop at the card text section"),
		assert_false(str(parsed.get("description", "")).contains("Decklists that include this card"), "Trainer description should not include the rest of the web page"),
		assert_false(str(parsed.get("description", "")).contains("Illustrated by"), "Trainer description should not include artist text"),
	])


func test_provider_ref_distinguishes_limitless_from_tcg_mik() -> String:
	var limitless := DeckImporterScript.parse_provider_ref("https://limitlesstcg.com/decks/list/18921")
	var tcg_mik := DeckImporterScript.parse_provider_ref("https://tcg.mik.moe/decks/list/123")
	var raw := DeckImporterScript.parse_provider_ref("456")
	return run_checks([
		assert_eq(limitless.get("provider", ""), "limitless", "Limitless host should route to Limitless importer"),
		assert_eq(int(limitless.get("local_id", 0)), 800018921, "Limitless id should use high positive local namespace"),
		assert_eq(tcg_mik.get("provider", ""), "tcg_mik", "tcg.mik host should keep existing importer"),
		assert_eq(raw.get("provider", ""), "tcg_mik", "Raw numeric input should preserve existing behavior"),
		assert_eq(DeckImporterScript.parse_deck_id("https://limitlesstcg.com/decks/list/18921"), -1, "Legacy tcg.mik parser must not swallow Limitless URLs"),
	])


func test_provider_ref_requires_supported_host_and_route() -> String:
	var embedded_limitless := DeckImporterScript.parse_provider_ref("https://example.test/?next=https://limitlesstcg.com/decks/list/18921")
	var path_only := DeckImporterScript.parse_provider_ref("decks/list/18921")
	var wrong_route := DeckImporterScript.parse_provider_ref("https://limitlesstcg.com/cards/JTG/98")
	var wrong_host := DeckImporterScript.parse_provider_ref("https://example.test/decks/list/18921")
	return run_checks([
		assert_eq(embedded_limitless.get("provider", ""), "", "Provider parser should not accept embedded Limitless URLs inside another host"),
		assert_eq(path_only.get("provider", ""), "", "Provider parser should require a supported host for deck paths"),
		assert_eq(wrong_route.get("provider", ""), "", "Provider parser should reject Limitless non-deck routes"),
		assert_eq(wrong_host.get("provider", ""), "", "Provider parser should reject unsupported hosts"),
	])


func test_resolver_maps_arven_same_print_to_local_card() -> String:
	var local := CardData.new()
	local.name = "阿枫"
	local.name_en = "Arven"
	local.card_type = "Supporter"
	local.set_code = "CSV1C"
	local.card_index = "123"
	local.set_code_en = "SVI"
	local.card_index_en = "166"
	local.effect_id = "arven_effect"
	var parsed := Parser.parse_card_html(_arven_html(), "https://limitlesstcg.com/cards/OBF/186")
	var resolved := Resolver.resolve_card(parsed, [local])
	var card: CardData = resolved.get("card", null)
	return run_checks([
		assert_not_null(card, "Resolver should return a card"),
		assert_false(bool(resolved.get("generated", true)), "Same-print Arven should use local implementation"),
		assert_eq(card.get_uid(), "CSV1C_123", "Resolver should map OBF/186 to local SVI/166 Arven"),
		assert_eq(resolved.get("resolved_via", ""), "same_print_group", "Resolution reason should explain the mapping"),
	])


func test_resolver_fails_closed_on_ambiguous_same_print_effects() -> String:
	var local_a := _make_local_print("CSV1C", "123", "Arven", "Supporter", "SVI", "166", "effect_a")
	var local_b := _make_local_print("CSV9C", "999", "Arven", "Supporter", "PAF", "235", "effect_b")
	var parsed := Parser.parse_card_html(_arven_html(), "https://limitlesstcg.com/cards/OBF/186")
	var resolved := Resolver.resolve_card(parsed, [local_a, local_b])
	var errors: Array = resolved.get("errors", [])
	return run_checks([
		assert_null(resolved.get("card", null), "Ambiguous same-print candidates with different effects should not return a card"),
		assert_false(bool(resolved.get("generated", true)), "Ambiguous same-print candidates should fail closed instead of generating a duplicate LEN card"),
		assert_true(not errors.is_empty(), "Ambiguous same-print failures should report a resolver error"),
	])


func test_resolver_maps_basic_energy_to_canonical_card() -> String:
	var darkness := CardData.new()
	darkness.name = "Basic Darkness Energy"
	darkness.name_en = "Darkness Energy"
	darkness.card_type = "Basic Energy"
	darkness.set_code = "CSVE1C"
	darkness.card_index = "DAR"
	darkness.set_code_en = "SVE"
	darkness.card_index_en = "7"
	darkness.energy_provides = "D"
	var parsed := Parser.parse_card_html(_darkness_energy_html(), "https://limitlesstcg.com/cards/SVE/7")
	var resolved := Resolver.resolve_card(parsed, [darkness])
	var card: CardData = resolved.get("card", null)
	return run_checks([
		assert_false(bool(resolved.get("generated", true)), "Basic Energy should map to the canonical local card"),
		assert_eq(card.get_uid(), "CSVE1C_DAR", "SVE/7 Darkness Energy should use local Darkness Energy"),
		assert_eq(resolved.get("resolved_via", ""), "exact_print", "Exact English set/number should win for energies"),
	])


func test_generated_limitless_card_source_collision_is_detected() -> String:
	var parsed := Parser.parse_card_html(_ns_pp_up_html(), "https://limitlesstcg.com/cards/JTG/153")
	var resolved := Resolver.resolve_card(parsed, [])
	var generated: CardData = resolved.get("card", null)
	var conflicting := CardData.new()
	conflicting.set_code = "LEN_JTG"
	conflicting.card_index = "153"
	conflicting.source_provider = "limitless"
	conflicting.source_set_code = "JTG"
	conflicting.source_card_index = "999"
	conflicting.source_language = "en"
	var matching := CardData.new()
	matching.set_code = "LEN_JTG"
	matching.card_index = "153"
	matching.source_provider = "limitless"
	matching.source_set_code = "JTG"
	matching.source_card_index = "153"
	matching.source_language = "en"
	return run_checks([
		assert_not_null(generated, "Generated PP Up card should exist for collision checks"),
		assert_true(DeckImporterScript.generated_limitless_card_has_source_collision(conflicting, generated), "Different Limitless source metadata should be treated as a collision"),
		assert_false(DeckImporterScript.generated_limitless_card_has_source_collision(matching, generated), "Matching Limitless source metadata should be reusable"),
	])


func test_generated_english_card_preserves_limitless_metadata() -> String:
	var parsed := Parser.parse_card_html(_ns_pp_up_html(), "https://limitlesstcg.com/cards/JTG/153")
	var resolved := Resolver.resolve_card(parsed, [])
	var card: CardData = resolved.get("card", null)
	return run_checks([
		assert_true(bool(resolved.get("generated", false)), "Missing English-only cards should generate a LEN card"),
		assert_eq(card.get_uid(), "LEN_JTG_153", "Generated Limitless card should use LEN set namespace"),
		assert_eq(card.source_provider, "limitless", "Generated card should persist source provider"),
		assert_eq(card.source_set_code, "JTG", "Generated card should persist source set"),
		assert_eq(card.image_local_path, "user://cards/images/LEN_JTG/153.png", "Generated card should use local cache path"),
		assert_str_contains(card.image_url, "JTG_153_R_EN.png", "Generated card should keep Limitless CDN image URL"),
	])


func test_generated_limitless_card_applies_chinese_detail_translation() -> String:
	var parsed := Parser.parse_card_html(_ns_zoroark_html(), "https://limitlesstcg.com/cards/JTG/98")
	var resolved := Resolver.resolve_card(parsed, [])
	var card: CardData = resolved.get("card", null)
	var ability: Dictionary = card.abilities[0] if card != null and card.abilities.size() > 0 else {}
	var attack: Dictionary = card.attacks[0] if card != null and card.attacks.size() > 0 else {}
	return run_checks([
		assert_true(bool(resolved.get("generated", false)), "Missing N's Zoroark ex should generate a translated LEN card"),
		assert_eq(card.name, "N's Zoroark ex", "Generated card rule name should stay English"),
		assert_eq(card.name_en, "N's Zoroark ex", "Generated card should preserve English name identity"),
		assert_eq(card.name_zh, "N的索罗亚克ex", "Generated card should store Chinese display name"),
		assert_eq(card.display_name(), "N的索罗亚克ex", "Generated card display name should prefer Chinese"),
		assert_eq(card.evolves_from, "N's Zorua", "Evolution source should stay English for rule matching"),
		assert_str_contains(card.description, "暗夜小丑", "Generated card description should be translated for details"),
		assert_eq(str(ability.get("name", "")), "Trade", "Ability rule name should stay English"),
		assert_eq(CardData.dictionary_display_name(ability), "交易", "Ability display name should prefer Chinese translation"),
		assert_str_contains(CardData.dictionary_display_text(ability), "抽2张卡", "Ability display text should prefer Chinese translation"),
		assert_eq(str(attack.get("name", "")), "Night Joker", "Attack rule name should stay English"),
		assert_eq(CardData.dictionary_display_name(attack), "暗夜小丑", "Attack display name should prefer Chinese translation"),
		assert_str_contains(CardData.dictionary_display_text(attack), "备战区", "Attack display text should prefer Chinese translation"),
		assert_str_contains(CardData.dictionary_display_text(attack), "1个招式", "Attack display text should describe copied-attack selection"),
		assert_str_contains(card.image_url, "JTG_098_R_EN.png", "Translation should not alter the Limitless image URL"),
	])


func test_generated_tef_085_drilbur_discards_up_to_three_basic_fighting_energy_on_bench_entry() -> String:
	var drilbur := Resolver.build_generated_card({
		"source_url": "https://limitlesstcg.com/cards/TEF/85",
		"source_set_code": "TEF",
		"source_card_index": "85",
		"source_language": "en",
		"name": "Drilbur",
		"name_en": "Drilbur",
		"card_type": "Pokemon",
		"stage": "Basic",
		"hp": 70,
		"energy_type": "F",
		"abilities": [{
			"name": "Dig Dig Dig",
			"text": "When you play this Pokemon from your hand onto your Bench during your turn, you may search your deck for up to 3 Basic Fighting Energy cards and discard them. Then, shuffle your deck.",
		}],
		"attacks": [{
			"name": "Scratch",
			"cost": "F",
			"damage": "20",
			"text": "",
			"is_vstar_power": false,
		}],
	})
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_limitless_card_test_state()
	var player := gsm.game_state.players[0]
	var drilbur_instance := CardInstance.create(drilbur, 0)
	player.hand.append(drilbur_instance)
	var fighting_a := _make_test_energy("Fighting A", "F", 0)
	var fighting_b := _make_test_energy("Fighting B", "F", 0)
	var fighting_c := _make_test_energy("Fighting C", "F", 0)
	var fighting_d := _make_test_energy("Fighting D", "F", 0)
	var water := _make_test_energy("Water", "W", 0)
	player.deck = [fighting_a, water, fighting_b, fighting_c, fighting_d]

	var played := gsm.play_basic_to_bench(0, drilbur_instance, false)
	var slot: PokemonSlot = player.bench.back() if played and not player.bench.is_empty() else null
	var effect: BaseEffect = gsm.effect_processor.get_ability_effect(slot, 0, gsm.game_state)
	var steps: Array = effect.get_interaction_steps(drilbur_instance, gsm.game_state) if effect != null else []
	var used := gsm.use_ability(0, slot, 0, [{
		"dig_dig_dig_energy": [fighting_a, fighting_b, fighting_c, water],
	}]) if slot != null else false

	return run_checks([
		assert_true(played, "Generated TEF/85 Drilbur should be playable from hand to the Bench"),
		assert_not_null(effect, "Generated Drilbur should register Dig Dig Dig by its English Ability name"),
		assert_eq(steps.size(), 1, "Dig Dig Dig should open one full-deck search interaction"),
		assert_eq(str(steps[0].get("visible_scope", "")) if not steps.is_empty() else "", BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Dig Dig Dig must expose the full own deck search UI"),
		assert_true(used, "Dig Dig Dig should resolve through GameStateMachine"),
		assert_eq(player.discard_pile.size(), 3, "Dig Dig Dig must discard at most three selected Basic Fighting Energy"),
		assert_true(fighting_a in player.discard_pile and fighting_b in player.discard_pile and fighting_c in player.discard_pile, "The three legal selected Fighting Energy should be discarded"),
		assert_true(fighting_d in player.deck and water in player.deck, "Extra and non-Fighting Energy must remain in the deck"),
		assert_false(gsm.effect_processor.can_use_ability(slot, gsm.game_state, 0), "The bench-entry Ability must not be usable twice"),
	])


func _make_limitless_card_test_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 1
	for owner_index: int in 2:
		var player := PlayerState.new()
		player.player_index = owner_index
		var active_data := CardData.new()
		active_data.name = "Active %d" % owner_index
		active_data.card_type = "Pokemon"
		active_data.stage = "Basic"
		active_data.hp = 100
		var active := PokemonSlot.new()
		active.pokemon_stack.append(CardInstance.create(active_data, owner_index))
		player.active_pokemon = active
		state.players.append(player)
	return state


func _make_test_energy(card_name: String, energy_type: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name = card_name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return CardInstance.create(card, owner_index)


func _arven_html() -> String:
	return "\n".join([
		"<html><body>",
		"<img class='card-image' data-src='https://limitlesstcg.nyc3.cdn.digitaloceanspaces.com/tpci/OBF/OBF_186_R_EN.png'>",
		"<div class='card-text-name'>Arven</div>",
		"<div class='card-text-type'>Trainer - Supporter</div>",
		"<div class='card-text-section'>Search your deck for an Item card and a Pokemon Tool card, reveal them, and put them into your hand. Then, shuffle your deck.</div>",
		"<a href='/cards/SVI/166'>Scarlet & Violet 166</a>",
		"<a href='/cards/PAF/235'>Paldean Fates 235</a>",
		"</body></html>",
	])


func _ns_zoroark_html() -> String:
	return "\n".join([
		"<html><body>",
		"<img class='card-image' data-src='https://limitlesstcg.nyc3.cdn.digitaloceanspaces.com/tpci/JTG/JTG_098_R_EN.png'>",
		"<div class='card-text-section'>",
		"<p class='card-text-title'><span class='card-text-name'><a href='/cards/JTG/98'>N's Zoroark ex</a></span> - Darkness - 280 HP</p>",
		"<p class='card-text-type'>Pok" + char(0x00E9) + "mon - Stage 1 - Evolves from <a>N's Zorua</a></p>",
		"</div>",
		"<div class='card-text-section'>",
		"<div class='card-text-ability'><p class='card-text-ability-info'>Ability: Trade</p><p class='card-text-ability-effect'>You must discard a card from your hand in order to use this Ability. Once during your turn, you may draw 2 cards.</p></div>",
		"<div class='card-text-attack'><p class='card-text-attack-info'><span class='ptcg-symbol'>DD</span> Night Joker</p><p class='card-text-attack-effect'>Choose 1 of your Benched N's Pokemon's attacks and use it as this attack.</p></div>",
		"</div>",
		"<div class='card-text-section'><p class='card-text-wrr'>Weakness: Grass <br>Resistance: none <br>Retreat: 2 <br></p></div>",
		"<div class='card-text-section card-text-artist'>Illustrated by <a href='/cards?q=!artist:takuyoa'>takuyoa</a></div>",
		"</body></html>",
	])


func _secret_box_html() -> String:
	return "\n".join([
		"<html><body>",
		"<div class='card-text-name'>Secret Box</div>",
		"<div class='card-text-type'>Trainer - Item</div>",
		"<div class='card-text-section'>You can use this card only if you discard 3 other cards from your hand.</div>",
		"</body></html>",
	])


func _darkness_energy_html() -> String:
	return "\n".join([
		"<html><body>",
		"<div class='card-text-name'>Darkness Energy</div>",
		"<div class='card-text-type'>Energy - Basic Energy</div>",
		"</body></html>",
	])


func _ns_pp_up_html() -> String:
	return "\n".join([
		"<html><body>",
		"<div class='card-text-name'>N's PP Up</div>",
		"<div class='card-text-type'>Trainer - Item</div>",
		"<div class='card-text-section'>Attach a Basic Energy card from your discard pile to 1 of your Benched N's Pokemon.</div>",
		"</body></html>",
	])


func _deck_html() -> String:
	return "\n".join([
		"<html><body>",
		"<h1 class='decklist-title'>N's Zoroark ex</h1>",
		"<div class='decklist-column-title'>Pokemon (8)</div>",
		"<div class='decklist-card' data-set='JTG' data-number='97' data-lang='en'><a class='card-link'><span class='card-count'>4</span><span class='card-name'>N's Zorua</span></a></div>",
		"<div class='decklist-card' data-set='JTG' data-number='98' data-lang='en'><a class='card-link'><span class='card-count'>4</span><span class='card-name'>N's Zoroark ex</span></a></div>",
		"<div class='decklist-column-title'>Energy (4)</div>",
		"<div class='decklist-card' data-set='SVE' data-number='7' data-lang='en' data-basic-energy='7'><a class='card-link'><span class='card-count'>4</span><span class='card-name'>Darkness Energy</span></a></div>",
		"</body></html>",
	])


func _priced_deck_html() -> String:
	return "\n".join([
		"<html><body>",
		"<h1 class='decklist-title'>Gardevoir <a>32.80$</a> 27.29&euro;</h1>",
		"<div class='decklist-column-title'>Pokemon (1)</div>",
		"<div class='decklist-card' data-set='SVI' data-number='84' data-lang='en'><span class='card-count'>1</span><span class='card-name'>Ralts</span></div>",
		"</body></html>",
	])


func _full_trainer_page_html() -> String:
	return "\n".join([
		"<html><body>",
		"<section class='card-page-main'><div class='card-text'>",
		"<div class='card-text-section'><p class='card-text-title'><span class='card-text-name'><a>Crispin</a></span></p><p class='card-text-type'>Trainer - Supporter</p></div>",
		"<div class='card-text-section'>Search your deck for up to 2 Basic Energy cards of different types, reveal them, and put 1 of them into your hand. Attach the other to 1 of your Pokemon. Then, shuffle your deck.</div>",
		"<div class='card-text-section card-text-artist'>Illustrated by <a>GIDORA</a></div>",
		"</div></section>",
		"<section><h2>Decklists that include this card</h2><p>unrelated page content</p></section>",
		"</body></html>",
	])


func _make_local_print(
	set_code: String,
	card_index: String,
	name_en: String,
	card_type: String,
	set_code_en: String,
	card_index_en: String,
	effect_id: String
) -> CardData:
	var card := CardData.new()
	card.name = name_en
	card.name_en = name_en
	card.card_type = card_type
	card.set_code = set_code
	card.card_index = card_index
	card.set_code_en = set_code_en
	card.card_index_en = card_index_en
	card.effect_id = effect_id
	return card


func _packed_to_array(value: Variant) -> Array:
	var result: Array = []
	if value is PackedStringArray:
		for item: String in value:
			result.append(item)
	elif value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result
