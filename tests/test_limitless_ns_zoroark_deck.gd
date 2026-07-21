class_name TestLimitlessNsZoroarkDeck
extends TestBase

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const BattleCardViewScript = preload("res://scenes/battle/BattleCardView.gd")

const REMOVED_NS_ZOROARK_DECK_ID := 800018921
const NAIC_NS_ZOROARK_DECK_ID := 800018502
const RULE_CHARIZARD_DECK_ID := 575716
const KEY_CARD_REFS := [
	{"set": "CSV10C", "index": "144", "name": "N的索罗亚", "source_name": "N's Zorua"},
	{"set": "CSV10C", "index": "145", "name": "N的索罗亚克ex", "source_name": "N's Zoroark ex"},
	{"set": "CSV10C", "index": "166", "name": "N的莱希拉姆", "source_name": "N's Reshiram"},
	{"set": "CSV10C", "index": "190", "name": "N的PP提升剂", "source_name": "N's PP Up"},
]


class TraceCollector extends RefCounted:
	var traces: Array = []

	func record_trace(trace) -> void:
		if trace == null:
			return
		traces.append(trace.clone())


func test_standalone_limitless_ns_zoroark_deck_is_removed_from_bundled_ai_decks() -> String:
	var ai_deck: DeckData = CardDatabase.get_ai_deck(REMOVED_NS_ZOROARK_DECK_ID)
	var player_deck: DeckData = CardDatabase.get_deck(REMOVED_NS_ZOROARK_DECK_ID)
	var supported_ids := CardDatabase.get_supported_ai_deck_ids()
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	return run_checks([
		assert_false(REMOVED_NS_ZOROARK_DECK_ID in supported_ids, "Standalone N's Zoroark deck should not be exposed in the supported AI deck ids"),
		assert_null(ai_deck, "Standalone N's Zoroark deck should not load through CardDatabase.get_ai_deck"),
		assert_null(player_deck, "Standalone N's Zoroark deck should not load through CardDatabase.get_deck"),
		assert_false(FileAccess.file_exists("res://data/bundled_user/decks/%d.json" % REMOVED_NS_ZOROARK_DECK_ID), "Standalone N's Zoroark bundled JSON should be deleted"),
		assert_false(manifest.contains("res://data/bundled_user/decks/%d.json" % REMOVED_NS_ZOROARK_DECK_ID), "Bundled manifest should not seed the standalone N's Zoroark deck JSON"),
	])


func test_v18_ns_zoroark_deck_uses_simplified_chinese_cards() -> String:
	var deck: DeckData = CardDatabase.get_deck(NAIC_NS_ZOROARK_DECK_ID)
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var total_count := _deck_total_count(deck)
	var refs := _deck_card_refs(deck)
	var checks: Array[String] = [
		assert_not_null(deck, "18.0 N's Zoroark deck should load through CardDatabase.get_deck"),
		assert_eq(deck.deck_name, "18.0 N的索罗亚克", "18.0 N's Zoroark deck should use the new series name"),
		assert_eq(total_count, 60, "18.0 N's Zoroark deck should contain exactly 60 cards"),
		assert_str_contains(manifest, "res://data/bundled_user/decks/%d.json" % NAIC_NS_ZOROARK_DECK_ID, "Bundled manifest should seed the 18.0 N's Zoroark deck JSON"),
	]
	for ref: String in refs:
		checks.append(assert_false(ref.begins_with("LEN_"), "18.0 N's Zoroark deck should not retain generated Limitless ref %s" % ref))
	for spec: Dictionary in KEY_CARD_REFS:
		var card_ref := "%s_%s" % [str(spec["set"]), str(spec["index"])]
		checks.append(assert_contains(refs, card_ref, "Deck should include key Simplified-Chinese card %s" % card_ref))
		checks.append(assert_str_contains(manifest, "res://data/bundled_user/cards/%s.json" % card_ref, "Manifest should include key Simplified-Chinese card %s" % card_ref))
	return run_checks(checks)


func test_limitless_ns_zoroark_key_cards_build_and_are_implemented() -> String:
	var deck: DeckData = CardDatabase.get_deck(NAIC_NS_ZOROARK_DECK_ID)
	var instances := CardDatabase.build_deck_instances(deck, 0) if deck != null else []
	var checks: Array[String] = [
		assert_not_null(deck, "NAIC N's Zoroark deck should load before building instances"),
		assert_eq(instances.size(), 60, "NAIC N's Zoroark deck should build all 60 card instances"),
	]
	for spec: Dictionary in KEY_CARD_REFS:
		var set_code := str(spec["set"])
		var card_index := str(spec["index"])
		var card: CardData = CardDatabase.get_card(set_code, card_index)
		checks.append(assert_not_null(card, "Key card %s/%s should load from CardDatabase" % [set_code, card_index]))
		if card != null:
			checks.append(assert_eq(str(card.name), str(spec["name"]), "Key card %s/%s should use its Simplified-Chinese rule name" % [set_code, card_index]))
			checks.append(assert_eq(card.display_name(), str(spec["name"]), "Key card %s/%s should display its Simplified-Chinese name" % [set_code, card_index]))
			checks.append(assert_false(CardImplementationStatus.is_unimplemented(card),
				"Key card %s/%s should not be marked unimplemented: %s" % [set_code, card_index, CardImplementationStatus.get_reason(card)]))
	return run_checks(checks)


func test_limitless_ns_zoroark_generated_card_details_are_translated_without_breaking_rule_names() -> String:
	var zoroark := CardDatabase.get_card("LEN_JTG", "98")
	var reshiram := CardDatabase.get_card("LEN_JTG", "116")
	var pp_up := CardDatabase.get_card("LEN_JTG", "153")
	var air_balloon := CardDatabase.get_card("LEN_BLK", "79")
	var ability: Dictionary = zoroark.abilities[0] if zoroark != null and zoroark.abilities.size() > 0 else {}
	var night_joker: Dictionary = zoroark.attacks[0] if zoroark != null and zoroark.attacks.size() > 0 else {}
	var powerful_rage: Dictionary = reshiram.attacks[0] if reshiram != null and reshiram.attacks.size() > 0 else {}
	return run_checks([
		assert_not_null(zoroark, "Translated N's Zoroark ex should load"),
		assert_eq(str(ability.get("name", "")), "Trade", "Trade rule name should remain English"),
		assert_eq(CardData.dictionary_display_name(ability), "交易", "Trade detail name should display Chinese"),
		assert_str_contains(CardData.dictionary_display_text(ability), "抽2张卡", "Trade detail text should display Chinese"),
		assert_eq(str(night_joker.get("name", "")), "Night Joker", "Night Joker rule name should remain English"),
		assert_eq(CardData.dictionary_display_name(night_joker), "暗夜小丑", "Night Joker detail name should display Chinese"),
		assert_str_contains(CardData.dictionary_display_text(night_joker), "备战区", "Night Joker detail text should display Chinese"),
		assert_str_contains(CardData.dictionary_display_text(night_joker), "1个招式", "Night Joker detail text should describe attack copying"),
		assert_eq(str(powerful_rage.get("name", "")), "Powerful Rage", "Powerful Rage rule name should remain English"),
		assert_eq(CardData.dictionary_display_name(powerful_rage), "强力愤怒", "Powerful Rage detail name should display Chinese"),
		assert_str_contains(CardData.dictionary_display_text(powerful_rage), "伤害指示物", "Powerful Rage detail text should display Chinese"),
		assert_str_contains(pp_up.description if pp_up != null else "", "弃牌区", "N's PP Up description should display Chinese"),
		assert_str_contains(air_balloon.description if air_balloon != null else "", "撤退所需能量", "Air Balloon description should display Chinese"),
	])


func test_limitless_ns_zoroark_deck_entries_display_translated_generated_cards() -> String:
	var deck: DeckData = CardDatabase.get_deck(NAIC_NS_ZOROARK_DECK_ID)
	var checks: Array[String] = [
		assert_not_null(deck, "N's Zoroark AI deck should load before translated entry checks"),
	]
	if deck == null:
		return run_checks(checks)
	for spec: Dictionary in KEY_CARD_REFS:
		var entry := _find_deck_entry(deck, str(spec["set"]), str(spec["index"]))
		checks.append(assert_false(entry.is_empty(), "Deck should include translated entry %s/%s" % [spec["set"], spec["index"]]))
		if not entry.is_empty():
			checks.append(assert_eq(str(entry.get("name", "")), str(spec["name"]), "Deck entry should display Simplified-Chinese name for %s/%s" % [spec["set"], spec["index"]]))
			checks.append(assert_eq(str(entry.get("source_name", "")), str(spec["source_name"]), "Deck entry should preserve Limitless source name for %s/%s" % [spec["set"], spec["index"]]))
			checks.append(assert_eq(str(entry.get("resolved_via", "")), "simplified_chinese_reprint", "Deck entry should record its Simplified-Chinese replacement for %s/%s" % [spec["set"], spec["index"]]))
	return run_checks(checks)


func test_limitless_ns_zoroark_card_view_uses_translated_display_name() -> String:
	var card := CardDatabase.get_card("CSV10C", "145")
	var view: BattleCardView = BattleCardViewScript.new()
	view.setup_from_card_data(card, BattleCardView.MODE_HAND)
	var title_label := view.get("_title_label") as Label
	var placeholder := view.get("_placeholder") as Label
	var result := run_checks([
		assert_not_null(card, "N's Zoroark ex should load before card view display check"),
		assert_not_null(title_label, "BattleCardView should build a title label"),
		assert_eq(title_label.text if title_label != null else "", "N的索罗亚克ex", "BattleCardView overlay title should use translated display name"),
		assert_false((title_label.text if title_label != null else "").contains("N's Zoroark ex"), "BattleCardView title should not expose the English rule name when name_zh exists"),
		assert_eq(placeholder.text if placeholder != null else "", "N的索罗亚克ex", "BattleCardView placeholder should use translated display name when art is unavailable"),
	])
	view.free()
	return result


func test_limitless_ns_zoroark_generated_cards_have_bundled_images() -> String:
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var checks: Array[String] = []
	for spec: Dictionary in KEY_CARD_REFS:
		var set_code := str(spec["set"])
		var card_index := str(spec["index"])
		var expected_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var resolved := CardData.resolve_existing_image_path(
			CardData.get_image_candidate_paths(set_code, card_index, "user://cards/images/__missing_limitless__/%s.png" % card_index)
		)
		var bytes := FileAccess.get_file_as_bytes(expected_path)
		var image := Image.new()
		var decode_err := ERR_FILE_UNRECOGNIZED
		if CardData.has_png_signature(bytes):
			decode_err = image.load_png_from_buffer(bytes)
		elif CardData.has_jpg_signature(bytes):
			decode_err = image.load_jpg_from_buffer(bytes)
		elif CardData.has_webp_signature(bytes):
			decode_err = image.load_webp_from_buffer(bytes)
		checks.append(assert_str_contains(manifest, expected_path, "Manifest should bundle image for %s/%s" % [set_code, card_index]))
		checks.append(assert_true(CardData.is_valid_card_image_file(expected_path), "Bundled image should be a valid card image for %s/%s" % [set_code, card_index]))
		checks.append(assert_eq(decode_err, OK, "Bundled image should decode in a supported format for %s/%s" % [set_code, card_index]))
		checks.append(assert_true(resolved.begins_with(expected_path), "Image resolver should fall back to bundled Limitless image for %s/%s" % [set_code, card_index]))
	return run_checks(checks)


func test_bundled_limitless_ns_zoroark_entries_keep_source_audit_metadata() -> String:
	var deck: DeckData = CardDatabase.get_deck(NAIC_NS_ZOROARK_DECK_ID)
	var checks: Array[String] = [
		assert_not_null(deck, "N's Zoroark AI deck should load before source metadata audit"),
	]
	if deck == null:
		return run_checks(checks)
	for entry: Dictionary in deck.cards:
		var local_ref := "%s/%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]
		checks.append(assert_eq(str(entry.get("source_provider", "")), "limitless", "%s should preserve source provider" % local_ref))
		checks.append(assert_true(str(entry.get("source_set_code", "")) != "", "%s should preserve source set" % local_ref))
		checks.append(assert_true(str(entry.get("source_card_index", "")) != "", "%s should preserve source card number" % local_ref))
		checks.append(assert_true(str(entry.get("source_name", "")) != "", "%s should preserve source display name" % local_ref))
		checks.append(assert_true(str(entry.get("resolved_via", "")) in ["exact_print", "same_print_group", "generated_limitless_card", "basic_energy", "simplified_chinese_reprint", "simplified_chinese_deck_rebuild"],
			"%s should preserve a known resolution reason" % local_ref))
	return run_checks(checks)


func test_limitless_ns_zoroark_strategy_registry_mapping() -> String:
	var deck: DeckData = CardDatabase.get_deck(NAIC_NS_ZOROARK_DECK_ID)
	var registry := DeckStrategyRegistryScript.new()
	var strategy_id := registry.resolve_strategy_id_for_deck(deck)
	var strategy := registry.resolve_strategy_for_deck(deck)
	var delegate: Variant = strategy.get("_delegate") if strategy != null else null
	var delegate_script: Variant = delegate.get_script() if delegate is RefCounted else null
	return run_checks([
		assert_eq(strategy_id, "v18_800018502_ns_zoroark", "DeckStrategyRegistry should preserve the deck-scoped V18 profile id"),
		assert_not_null(strategy, "DeckStrategyRegistry should instantiate the N's Zoroark V18 strategy"),
		assert_eq(str(strategy.get_strategy_id()) if strategy != null and strategy.has_method("get_strategy_id") else "", strategy_id, "Instantiated strategy should report the Registry's outer strategy id"),
		assert_true(delegate is RefCounted, "The N's Zoroark V18 strategy should configure its mature delegate"),
		assert_eq(str(delegate_script.resource_path) if delegate_script is Script else "", "res://scripts/ai/DeckStrategyNsZoroark.gd", "Deck 800018502 should delegate to DeckStrategyNsZoroark"),
		assert_eq(str(delegate.call("get_strategy_id")) if delegate is RefCounted else "", "ns_zoroark", "The mature N's Zoroark delegate should retain its family strategy id"),
	])


func test_limitless_ns_zoroark_rule_charizard_headless_duel_does_not_stall() -> String:
	var ns_deck: DeckData = CardDatabase.get_deck(NAIC_NS_ZOROARK_DECK_ID)
	var charizard_deck: DeckData = CardDatabase.get_ai_deck(RULE_CHARIZARD_DECK_ID)
	if ns_deck == null or charizard_deck == null:
		return "N's Zoroark and rule Charizard AI decks should both load"

	var runner := AIBenchmarkRunnerScript.new()
	var gsm := GameStateMachine.new()
	runner.call("_clear_forced_shuffle_seed")
	runner.call("_apply_match_seed", gsm, 18921)
	runner.call("_set_forced_shuffle_seed", 18921)
	gsm.start_game(ns_deck, charizard_deck, 0)

	var registry := DeckStrategyRegistryScript.new()
	var p0_ai := _make_ai(0, ns_deck, registry)
	var p1_ai := _make_ai(1, charizard_deck, registry)
	var trace_collector := TraceCollector.new()
	var result: Dictionary = runner.run_headless_duel(p0_ai, p1_ai, gsm, 360, Callable(), trace_collector)
	runner.call("_clear_forced_shuffle_seed")

	return run_checks([
		assert_false(bool(result.get("stalled", true)), "N's Zoroark vs rule Charizard should not stall; tail=%s result=%s" % [_trace_tail_summary(trace_collector.traces), JSON.stringify(result)]),
		assert_false(bool(result.get("terminated_by_cap", true)), "N's Zoroark vs rule Charizard should finish before the action cap; tail=%s result=%s" % [_trace_tail_summary(trace_collector.traces), JSON.stringify(result)]),
		assert_true(str(result.get("failure_reason", "")) not in ["unsupported_prompt", "unsupported_interaction_step", "stalled_no_progress", "invalid_state_transition"],
			"N's Zoroark vs rule Charizard should not fail on an unresolved headless prompt; tail=%s result=%s" % [_trace_tail_summary(trace_collector.traces), JSON.stringify(result)]),
	])


func _make_ai(player_index: int, deck: DeckData, registry: RefCounted) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	registry.apply_strategy_for_deck(ai, deck)
	return ai


func _deck_total_count(deck: DeckData) -> int:
	if deck == null:
		return 0
	var total := 0
	for entry: Dictionary in deck.cards:
		total += int(entry.get("count", 0))
	return total


func _deck_card_refs(deck: DeckData) -> Array[String]:
	var refs: Array[String] = []
	if deck == null:
		return refs
	for entry: Dictionary in deck.cards:
		refs.append("%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))])
	return refs


func _find_deck_entry(deck: DeckData, set_code: String, card_index: String) -> Dictionary:
	if deck == null:
		return {}
	for entry: Dictionary in deck.cards:
		if str(entry.get("set_code", "")) == set_code and str(entry.get("card_index", "")) == card_index:
			return entry
	return {}


func _trace_tail_summary(traces: Array, limit: int = 28) -> String:
	var start_index := maxi(0, traces.size() - limit)
	var parts: Array[String] = []
	for idx: int in range(start_index, traces.size()):
		var trace = traces[idx]
		if trace == null:
			continue
		var chosen_action: Dictionary = trace.chosen_action if trace.chosen_action is Dictionary else {}
		var card_name := str(chosen_action.get("card_name", chosen_action.get("name", "")))
		var source_name := ""
		var source_slot: Variant = chosen_action.get("source_slot", null)
		if source_slot is PokemonSlot:
			source_name = (source_slot as PokemonSlot).get_pokemon_name()
		var target_name := ""
		var target_slot: Variant = chosen_action.get("target_slot", null)
		if target_slot is PokemonSlot:
			target_name = (target_slot as PokemonSlot).get_pokemon_name()
		parts.append("t%d:p%d:%s:%s:%s:%s:a%d:u%d" % [
			int(trace.turn_number),
			int(trace.player_index),
			str(chosen_action.get("kind", "")),
			source_name,
			card_name,
			target_name,
			int(chosen_action.get("attack_index", -1)),
			int(chosen_action.get("ability_index", -1)),
		])
	return " | ".join(parts)
