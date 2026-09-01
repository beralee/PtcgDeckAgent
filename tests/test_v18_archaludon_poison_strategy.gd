class_name TestV18ArchaludonMetalStrategy
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const CARD_DATABASE_SCRIPT = preload("res://scripts/autoload/CardDatabase.gd")
const DECK_ID := 800017280
const MARNIE_DECK_ID := 800018501
const DECK_DIR := "res://data/bundled_user/decks"
const EXPECTED_DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18ArchaludonPoison.gd"
const LEGACY_POISON_COUNTS := {
	"CSV9C_136": 4, "CSV9C_138": 3, "CSV6C_095": 2, "CSV9C_127": 2,
	"CSV2C_105": 2, "CSV9C_078": 1, "CSV8C_135": 1, "151C_151": 1,
	"CSV8C_199": 4, "CSV3C_123": 2, "CSV1C_121": 2, "CSVH1aC_023": 2,
	"CSV6C_125": 1, "CSVH1C_043": 4, "CSV1C_112": 4, "CSV2C_113": 3,
	"CSV8C_183": 3, "CSV6C_115": 2, "CSV8C_176": 1, "CSV1C_111": 1,
	"CSV6C_118": 3, "CSV8C_187": 2, "CSV7C_200": 3, "CSVE1C_MET": 7,
}


func test_legacy_poison_seed_migrates_but_a_user_edited_variant_does_not() -> String:
	var bundled: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%d.json" % [DECK_DIR, DECK_ID]))
	var legacy := {
		"id": DECK_ID,
		"source_provider": "limitless",
		"source_id": "17280",
		"deck_name": "18.0 毒桥龙",
		"variant_name": "18.0 毒桥龙",
		"total_cards": 60,
		"strategy": "keep-user-strategy",
		"cards": _entries_from_counts(LEGACY_POISON_COUNTS),
	}
	var edited: Dictionary = legacy.duplicate(true)
	(edited["cards"][0] as Dictionary)["count"] = int((edited["cards"][0] as Dictionary)["count"]) + 1
	var migration_db: Node = CARD_DATABASE_SCRIPT.new()
	var edited_db: Node = CARD_DATABASE_SCRIPT.new()
	var migrated: bool = bool(migration_db.call("_merge_bundled_deck_migrations", bundled, legacy))
	var edited_migrated: bool = bool(edited_db.call("_merge_bundled_deck_migrations", bundled, edited))
	var result: String = run_checks([
		assert_true(bool(migrated), "The exact previously seeded poison list should migrate on restart"),
		assert_eq(str(legacy.get("deck_name", "")), "18.0 铝钢龙钢铁防线", "The migrated seed should expose the new deck name"),
		assert_eq(_dictionary_card_count(legacy, "CSV9C_138"), 4, "The migrated seed should contain four Archaludon ex"),
		assert_eq(_dictionary_card_count(legacy, "CSV6C_095"), 0, "The migrated seed should remove the symmetric poison package"),
		assert_eq(str(legacy.get("strategy", "")), "keep-user-strategy", "Migration should preserve unrelated user strategy text"),
		assert_false(bool(edited_migrated), "A one-count user edit must make the exact seed migration fail closed"),
		assert_eq(str(edited.get("deck_name", "")), "18.0 毒桥龙", "A user-edited variant must remain untouched"),
	])
	migration_db.free()
	edited_db.free()
	return result


func test_real_deck_anchors_the_complete_archaludon_metal_engine() -> String:
	var deck := _load_deck(DECK_ID)
	return run_checks([
		assert_not_null(deck, "The real 18.0 Archaludon deck should load"),
		assert_eq(deck.total_cards if deck != null else 0, 60, "Archaludon must remain a 60-card built-in deck"),
		assert_eq(_deck_effect_id(deck, "CSV9C", "138"), "ecce5b1818ae13630c3a09449489c424", "Strategy must anchor Alloy Build"),
		assert_eq(_deck_effect_id(deck, "CS5bC", "052"), "04653d073ffc3ca2202746e4f9aebabd", "The matchup list must anchor Manaphy's Bench protection"),
		assert_eq(_deck_count(deck, "CSV9C", "136"), 4, "The deck needs four Duraludon starters"),
		assert_eq(_deck_count(deck, "CSV9C", "138"), 4, "The deck needs four Alloy Build evolutions"),
		assert_eq(_deck_count(deck, "CS5bC", "052"), 1, "One Manaphy is enough for Bench protection without crowding metal routes"),
		assert_eq(_deck_count(deck, "CSV6C", "115"), 4, "Four Earthen Vessel maximize early Metal discard fuel"),
		assert_eq(_deck_count(deck, "CSV1C", "121"), 4, "Four Research keep the launch turn moving"),
		assert_eq(_deck_count(deck, "CSVH1aC", "023"), 2, "Two Boss plus Pal Pad are enough for the Munkidori prize route"),
		assert_eq(_deck_count(deck, "CSVE1C", "MET"), 12, "Twelve Metal Energy sustain repeated Alloy Build routes"),
		assert_eq(_deck_count(deck, "151C", "151"), 0, "Mew ex is cut as a two-Prize Bench liability"),
		assert_eq(_deck_count(deck, "CSV6C", "095"), 0, "Symmetric poison is cut because it accelerates Grimmsnarl's damage plan"),
	])


func test_registry_resolves_a_deck_scoped_v18_profile_and_delegate() -> String:
	var deck := _load_deck(DECK_ID)
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	var strategy: RefCounted = registry.call("resolve_strategy_for_deck", deck) if deck != null else null
	var delegate: Variant = strategy.get("_delegate") if strategy != null else null
	return run_checks([
		assert_not_null(strategy, "Archaludon Metal should resolve through the V18 Registry"),
		assert_eq(str(strategy.call("get_strategy_id")) if strategy != null else "", "v18_800017280_archaludon_metal", "Registry should expose the deck-scoped V18 identity"),
		assert_true(delegate is RefCounted, "Archaludon Metal should configure a dedicated delegate"),
		assert_eq(_script_path(delegate), EXPECTED_DELEGATE_PATH, "Registry should wire the dedicated Archaludon Metal delegate"),
	])


func test_opening_starts_duraludon_and_preserves_two_attack_routes() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_not_null(strategy, "Archaludon Metal strategy must exist before opening policy can be tested")
	var player := PlayerState.new()
	player.player_index = 0
	player.hand.assign([
		_instance(_load_card("CS5bC_052")),
		_instance(_load_card("CSV9C_136")),
		_instance(_load_card("CSV2C_105")),
		_instance(_load_card("CSV9C_136")),
		_instance(_load_card("CSV9C_078")),
		_instance(_load_card("CSV8C_135")),
	])
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	var active_name := _hand_card_name(player, int(plan.get("active_hand_index", -1)))
	var bench_names := _hand_card_names(player, plan.get("bench_hand_indices", []))
	return run_checks([
		assert_eq(active_name, "铝钢龙", "Duraludon should own the opening Active slot"),
		assert_true("铝钢龙" in bench_names, "Opening setup should preserve a second Archaludon route"),
		assert_true("玛纳霏" in bench_names, "Opening setup should retain Bench protection against Grimmsnarl"),
		assert_true("怒鹦哥ex" in bench_names, "Opening setup should retain the first-turn discard and draw engine"),
		assert_true(bench_names.size() <= 4, "Opening setup must preserve one Bench slot for rebuilding"),
	])


func test_marnie_matchup_prioritizes_manaphy_bench_protection() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_not_null(strategy, "Archaludon Metal strategy must exist before Manaphy protection can be tested")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_load_card("CSV9C_136"))
	var manaphy := _instance(_load_card("CS5bC_052"))
	var backup := _instance(_load_card("CSV9C_136"))
	var early_manaphy_score: float = strategy.call("score_action_absolute", {"kind": "play_basic_to_bench", "card": manaphy}, state, 0)
	var backup_score: float = strategy.call("score_action_absolute", {"kind": "play_basic_to_bench", "card": backup}, state, 0)
	player.bench.append(_slot(_load_card("CSV9C_136")))
	var protected_score: float = strategy.call("score_action_absolute", {"kind": "play_basic_to_bench", "card": manaphy}, state, 0)
	return run_checks([
		assert_true(backup_score >= early_manaphy_score + 500.0, "The second Metal route should be established before optional protection"),
		assert_true(protected_score >= 4000.0, "Once two Metal routes exist, Manaphy should enter before Grimmsnarl spreads Bench damage"),
	])
func test_manual_and_alloy_energy_finish_archaludon_before_support_pokemon() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_not_null(strategy, "Archaludon Metal strategy must exist before energy policy can be tested")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var archaludon := _slot(_load_card("CSV9C_138"))
	var backup := _slot(_load_card("CSV9C_136"))
	var squawkabilly := _slot(_load_card("CSV2C_105"))
	player.active_pokemon = archaludon
	player.bench.assign([backup, squawkabilly])
	_attach_metal(archaludon, 2)
	var metal := _instance(_load_card("CSVE1C_MET"))
	var active_attach: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": metal, "target_slot": archaludon}, state, 0)
	var support_attach: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": metal, "target_slot": squawkabilly}, state, 0)
	var step := {"id": "csv9c_metal_discard_assignments"}
	var active_assign: float = strategy.call("score_interaction_target", archaludon, step, {"game_state": state, "player_index": 0})
	var backup_assign: float = strategy.call("score_interaction_target", backup, step, {
		"game_state": state, "player_index": 0,
		"pending_assignment_counts": {archaludon.get_instance_id(): 1},
	})
	return run_checks([
		assert_true(active_attach >= support_attach + 1800.0, "Manual Metal must finish the live Archaludon instead of funding Squawkabilly"),
		assert_true(active_assign >= 4500.0, "Alloy Build should complete the current MMM attacker first"),
		assert_true(backup_assign >= 2600.0, "After MMM is complete, Alloy Build should start the backup Duraludon route"),
	])


func test_ready_archaludon_owns_handoff_and_attack_over_squawkabilly() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_not_null(strategy, "Archaludon Metal strategy must exist before handoff policy can be tested")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var active_squawk := _slot(_load_card("CSV2C_105"))
	var archaludon := _slot(_load_card("CSV9C_138"))
	_attach_metal(active_squawk, 1)
	_attach_metal(archaludon, 3)
	player.active_pokemon = active_squawk
	player.bench.append(archaludon)
	var context := {"game_state": state, "player_index": 0}
	var handoff_arch: float = strategy.call("score_handoff_target", archaludon, {"id": "send_out"}, context)
	var handoff_squawk: float = strategy.call("score_handoff_target", active_squawk, {"id": "send_out"}, context)
	var arch_attack: float = strategy.call("score_action_absolute", {"kind": "attack", "source_slot": archaludon, "attack_index": 0, "projected_damage": 220}, state, 0)
	var squawk_attack: float = strategy.call("score_action_absolute", {"kind": "attack", "source_slot": active_squawk, "attack_index": 0, "projected_damage": 20}, state, 0)
	return run_checks([
		assert_true(handoff_arch >= handoff_squawk + 1800.0, "A ready Archaludon must own the next Active handoff"),
		assert_true(arch_attack >= squawk_attack + 1800.0, "A ready Archaludon attack must dominate Squawkabilly's setup attack"),
	])


func test_ready_archaludon_routes_manual_energy_to_the_backup_attacker() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_not_null(strategy, "Archaludon Metal strategy must exist before backup continuity can be tested")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var current := _slot(_load_card("CSV9C_138"))
	var backup := _slot(_load_card("CSV9C_136"))
	_attach_metal(current, 3)
	player.active_pokemon = current
	player.bench.append(backup)
	var metal := _instance(_load_card("CSVE1C_MET"))
	var current_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": metal, "target_slot": current}, state, 0)
	var backup_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": metal, "target_slot": backup}, state, 0)
	return assert_true(backup_score >= current_score + 1800.0, "Once the current Archaludon has MMM, manual Energy must start the backup route")


func test_secret_box_builds_the_second_route_before_fuel_or_gust() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_not_null(strategy, "Archaludon Metal strategy must exist before Secret Box policy can be tested")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_load_card("CSV9C_136"))
	var nest_ball := _instance(_load_card("CSVH1C_043"))
	var vessel := _instance(_load_card("CSV6C_115"))
	var carmine := _instance(_load_card("CSV8C_199"))
	var boss := _instance(_load_card("CSVH1aC_023"))
	var item_step := {"id": "search_item"}
	var supporter_step := {"id": "search_supporter"}
	var context := {"game_state": state, "player_index": 0}
	var nest_score: float = strategy.call("score_interaction_target", nest_ball, item_step, context)
	var vessel_score: float = strategy.call("score_interaction_target", vessel, item_step, context)
	var carmine_score: float = strategy.call("score_interaction_target", carmine, supporter_step, context)
	var boss_score: float = strategy.call("score_interaction_target", boss, supporter_step, context)
	return run_checks([
		assert_true(nest_score >= vessel_score - 1000.0, "Secret Box should keep the second Duraludon and Metal-fuel routes in the same setup tier"),
		assert_true(carmine_score >= boss_score + 900.0, "Without a ready attacker, Secret Box should find setup draw instead of dead gust"),
	])


func test_boss_waits_until_archaludon_can_convert_the_gust_into_a_prize() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_not_null(strategy, "Archaludon strategy must exist before Boss timing can be tested")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.active_pokemon = _slot(_load_card("CSV9C_136"))
	opponent.bench.append(_slot(_load_card("CSV8C_094"), 1))
	var boss := _instance(_load_card("CSVH1aC_023"))
	var unready_score: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": boss}, state, 0)
	var archaludon := _slot(_load_card("CSV9C_138"))
	_attach_metal(archaludon, 3)
	player.active_pokemon = archaludon
	var ready_score: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": boss}, state, 0)
	return run_checks([
		assert_true(unready_score <= -1800.0, "Boss must not consume the Supporter action before an attacker is ready"),
		assert_true(ready_score >= unready_score + 5000.0, "A ready Archaludon should unlock the one-hit Boss route"),
	])


func test_opening_keeps_the_available_single_copy_engines() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_not_null(strategy, "Archaludon Metal strategy must exist before opening engine policy can be tested")
	var player := PlayerState.new()
	player.player_index = 0
	player.hand.assign([
		_instance(_load_card("CSV9C_136")),
		_instance(_load_card("CSV8C_135")),
		_instance(_load_card("CS5bC_052")),
		_instance(_load_card("CSV2C_105")),
		_instance(_load_card("CSV9C_078")),
	])
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	var bench_names := _hand_card_names(player, plan.get("bench_hand_indices", []))
	return run_checks([
		assert_true("玛纳霏" in bench_names, "The one-prize Bench shield should remain available"),
		assert_true("怒鹦哥ex" in bench_names, "Squawkabilly should preserve the turn-one discard and draw route"),
		assert_true("拉帝亚斯ex" in bench_names, "Latias should preserve free-retreat mobility"),
		assert_true("吉雉鸡ex" in bench_names, "One Fezandipiti should preserve the comeback draw route after an early knockout"),
		assert_true(bench_names.size() <= 4, "Opening setup must preserve the rebuild slot cap"),
	])


func test_secret_box_banks_turo_and_turo_lifts_the_spread_damage_liability() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_not_null(strategy, "Archaludon Metal strategy must exist before Turo cleanup can be tested")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var archaludon := _slot(_load_card("CSV9C_138"))
	var backup := _slot(_load_card("CSV9C_136"))
	var squawkabilly := _slot(_load_card("CSV2C_105"))
	_attach_metal(archaludon, 3)
	squawkabilly.damage_counters = 60
	player.active_pokemon = archaludon
	player.bench.assign([backup, squawkabilly])
	var turo := _instance(_load_card("CSV6C_125"))
	var carmine := _instance(_load_card("CSV8C_199"))
	var context := {"game_state": state, "player_index": 0}
	var turo_search: float = strategy.call("score_interaction_target", turo, {"id": "search_supporter"}, context)
	var carmine_search: float = strategy.call("score_interaction_target", carmine, {"id": "search_supporter"}, context)
	var turo_action: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": turo}, state, 0)
	var liability_target: float = strategy.call("score_interaction_target", squawkabilly, {"id": "prof_turo_target"}, context)
	var attacker_target: float = strategy.call("score_interaction_target", archaludon, {"id": "prof_turo_target"}, context)
	return run_checks([
		assert_true(turo_search >= carmine_search + 500.0, "Once setup is live, Secret Box should bank Turo before another draw Supporter"),
		assert_true(turo_action >= 3000.0, "Turo should be playable before spread damage converts Squawkabilly into the final two Prizes"),
		assert_true(liability_target >= attacker_target + 2500.0, "Turo must lift the damaged support ex, never the funded Archaludon attacker"),
	])


func test_ready_archaludon_searches_and_recycles_boss_for_munkidori_before_cleanup() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_not_null(strategy, "Archaludon Metal strategy must exist before Boss conversion can be tested")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var archaludon := _slot(_load_card("CSV9C_138"))
	_attach_metal(archaludon, 3)
	player.active_pokemon = archaludon
	opponent.active_pokemon = _slot(_load_card("CSV10C_148"), 1)
	var munkidori := _slot(_load_card("CSV8C_094"), 1)
	opponent.bench.append(munkidori)
	var boss := _instance(_load_card("CSVH1aC_023"))
	var turo := _instance(_load_card("CSV6C_125"))
	var carmine := _instance(_load_card("CSV8C_199"))
	var context := {"game_state": state, "player_index": 0}
	var boss_search: float = strategy.call("score_interaction_target", boss, {"id": "search_supporter"}, context)
	var turo_search: float = strategy.call("score_interaction_target", turo, {"id": "search_supporter"}, context)
	var boss_recovery: float = strategy.call("score_interaction_target", boss, {"id": "pal_pad_recover"}, context)
	var carmine_recovery: float = strategy.call("score_interaction_target", carmine, {"id": "pal_pad_recover"}, context)
	var munkidori_target: float = strategy.call("score_interaction_target", munkidori, {"id": "boss_opponent_bench_target"}, context)
	var grimmsnarl_target: float = strategy.call("score_interaction_target", opponent.active_pokemon, {"id": "boss_opponent_bench_target"}, context)
	return run_checks([
		assert_true(boss_search >= turo_search + 500.0, "A ready Archaludon should search Boss before defensive cleanup when Munkidori is a one-hit target"),
		assert_true(boss_recovery >= carmine_recovery + 1800.0, "Pal Pad should recycle Boss for the matchup's one-Prize engine chain"),
		assert_true(munkidori_target >= grimmsnarl_target + 1500.0, "Boss should remove Munkidori instead of feeding a two-hit Grimmsnarl exchange"),
	])


func test_low_deck_policy_stops_optional_draw_after_attack_route_is_live() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_not_null(strategy, "Archaludon Metal strategy must exist before low-deck policy can be tested")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var archaludon := _slot(_load_card("CSV9C_138"))
	_attach_metal(archaludon, 3)
	player.active_pokemon = archaludon
	for index: int in 6:
		player.deck.append(_instance(_trainer("低牌库卡 %d" % index, "Item")))
	var research := _instance(_load_card("CSV1C_121"))
	var fezandipiti := _slot(_load_card("CSV8C_135"))
	player.bench.append(fezandipiti)
	var research_score: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": research}, state, 0)
	var draw_score: float = strategy.call("score_action_absolute", {"kind": "use_ability", "source_slot": fezandipiti, "ability_index": 0}, state, 0)
	return run_checks([
		assert_true(research_score <= -1800.0, "Research must stop when a ready attacker is live near deck-out"),
		assert_true(draw_score < 0.0, "Optional Fezandipiti draw must stop near deck-out"),
	])


func _strategy() -> RefCounted:
	var deck := _load_deck(DECK_ID)
	if deck == null:
		return null
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", deck)


func _load_deck(deck_id: int) -> DeckData:
	var path := "%s/%d.json" % [DECK_DIR, deck_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


func _load_card(ref: String) -> CardData:
	var path := "res://data/bundled_user/cards/%s.json" % ref
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _deck_effect_id(deck: DeckData, set_code: String, card_index: String) -> String:
	if deck == null:
		return ""
	for entry: Dictionary in deck.cards:
		if str(entry.get("set_code", "")) == set_code and str(entry.get("card_index", "")) == card_index:
			return str(entry.get("effect_id", ""))
	return ""


func _deck_count(deck: DeckData, set_code: String, card_index: String) -> int:
	if deck == null:
		return 0
	for entry: Dictionary in deck.cards:
		if str(entry.get("set_code", "")) == set_code and str(entry.get("card_index", "")) == card_index:
			return int(entry.get("count", 0))
	return 0

func _entries_from_counts(counts: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_uid: Variant in counts:
		var uid := str(raw_uid)
		var split := uid.split("_", false, 1)
		result.append({
			"set_code": split[0],
			"card_index": split[1],
			"count": int(counts[raw_uid]),
		})
	return result


func _dictionary_card_count(deck: Dictionary, uid: String) -> int:
	for raw_entry: Variant in deck.get("cards", []):
		if raw_entry is Dictionary:
			var entry := raw_entry as Dictionary
			if "%s_%s" % [entry.get("set_code", ""), entry.get("card_index", "")] == uid:
				return int(entry.get("count", 0))
	return 0


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	opponent.active_pokemon = _slot(_load_card("CSV10C_146"), 1)
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	return state


func _slot(card_data: CardData, owner_index: int = 0) -> PokemonSlot:
	var result := PokemonSlot.new()
	result.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	return result


func _instance(card_data: CardData, owner_index: int = 0) -> CardInstance:
	return CardInstance.create(card_data, owner_index)


func _attach_metal(slot: PokemonSlot, count: int) -> void:
	for _index: int in count:
		slot.attached_energy.append(_instance(_load_card("CSVE1C_MET")))


func _trainer(name: String, card_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.name_zh = name
	card.card_type = card_type
	return card


func _hand_card_name(player: PlayerState, index: int) -> String:
	if index < 0 or index >= player.hand.size() or player.hand[index] == null or player.hand[index].card_data == null:
		return ""
	return player.hand[index].card_data.name


func _hand_card_names(player: PlayerState, indices: Array) -> Array[String]:
	var names: Array[String] = []
	for raw_index: Variant in indices:
		var name := _hand_card_name(player, int(raw_index))
		if name != "":
			names.append(name)
	return names


func _script_path(delegate: Variant) -> String:
	if not delegate is RefCounted:
		return ""
	var script: Variant = (delegate as RefCounted).get_script()
	return str(script.resource_path) if script is Script else ""
