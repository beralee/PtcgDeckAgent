extends SceneTree


const ProfileCatalogScript = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")
const OUTPUT_DIR := "res://data/bundled_user/ai_fixed_deck_orders"
const OPENING_SIZE := 7
const PRIZE_SIZE := 6
const BRIDGE_SIZE := 6
const GENERATOR_VERSION := 16

var _card_db: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_card_db = root.get_node_or_null("/root/CardDatabase")
	if _card_db == null:
		push_error("CardDatabase autoload is unavailable")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var failures: Array[String] = []
	for profile: Dictionary in ProfileCatalogScript.all_profiles():
		var result := _generate_profile_order(profile)
		if not bool(result.get("ok", false)):
			failures.append(str(result.get("error", "unknown error")))
		else:
			print("V18_FIXED_ORDER %d %s" % [int(profile.get("deck_id", 0)), str(result.get("summary", ""))])
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _generate_profile_order(profile: Dictionary) -> Dictionary:
	var deck_id := int(profile.get("deck_id", 0))
	var deck: DeckData = _card_db.call("get_deck", deck_id)
	if deck == null:
		return {"ok": false, "error": "Deck %d could not be loaded" % deck_id}
	var pool := _build_copy_pool(deck)
	if pool.size() != 60:
		return {"ok": false, "error": "Deck %d has %d loadable cards instead of 60" % [deck_id, pool.size()]}
	var route_energy_symbols := _route_energy_symbols(profile, pool)

	var opening: Array[Dictionary] = []
	var opening_uids: Dictionary = {}
	var hint_error := _take_strong_order_hints(opening, pool, profile, "opening_cards", opening_uids, OPENING_SIZE)
	if hint_error != "":
		return {"ok": false, "error": "Deck %d opening hints: %s" % [deck_id, hint_error]}
	_take_if_space(opening, OPENING_SIZE, pool, profile, "active_priority", "basic", opening_uids, true)
	_take_if_space(opening, OPENING_SIZE, pool, profile, "bench_priority", "basic", opening_uids, true)
	_take_if_space(opening, OPENING_SIZE, pool, profile, "trainer_priority", "trainer", opening_uids, true)
	_take_if_space(opening, OPENING_SIZE, pool, profile, "trainer_priority", "trainer", opening_uids, true)
	_take_route_energy_if_space(opening, OPENING_SIZE, pool, profile, opening_uids, route_energy_symbols)
	_take_route_energy_if_space(opening, OPENING_SIZE, pool, profile, opening_uids, route_energy_symbols)
	_take_if_space(opening, OPENING_SIZE, pool, profile, "bench_priority", "basic", opening_uids, true)
	while opening.size() < OPENING_SIZE:
		_take_into(opening, pool, profile, "search_priority", "basic", opening_uids, false)
		if opening.size() < OPENING_SIZE:
			_take_into(opening, pool, profile, "trainer_priority", "trainer", opening_uids, false)

	var bridge: Array[Dictionary] = []
	var bridge_uids: Dictionary = {}
	hint_error = _take_strong_order_hints(bridge, pool, profile, "bridge_cards", bridge_uids, BRIDGE_SIZE)
	if hint_error != "":
		return {"ok": false, "error": "Deck %d bridge hints: %s" % [deck_id, hint_error]}
	_take_if_space(bridge, BRIDGE_SIZE, pool, profile, "evolution_priority", "evolution", bridge_uids, false)
	_take_if_space(bridge, BRIDGE_SIZE, pool, profile, "evolution_priority", "evolution", bridge_uids, false)
	_take_route_energy_if_space(bridge, BRIDGE_SIZE, pool, profile, bridge_uids, route_energy_symbols)
	_take_if_space(bridge, BRIDGE_SIZE, pool, profile, "trainer_priority", "trainer", bridge_uids, true)
	_take_if_space(bridge, BRIDGE_SIZE, pool, profile, "search_priority", "pokemon", bridge_uids, false)
	_take_route_energy_if_space(bridge, BRIDGE_SIZE, pool, profile, bridge_uids, route_energy_symbols)
	while bridge.size() < BRIDGE_SIZE:
		_take_into(bridge, pool, profile, "search_priority", "any", bridge_uids, false)

	var prizes := _take_prizes(pool, profile, deck)
	var controlled_prefix: Array[Dictionary] = []
	controlled_prefix.append_array(opening)
	controlled_prefix.append_array(prizes)
	controlled_prefix.append_array(bridge)
	var ordered := _complete_order(controlled_prefix, pool)
	var validation_error := _validate_order(deck, ordered)
	if validation_error != "":
		return {"ok": false, "error": "Deck %d: %s" % [deck_id, validation_error]}

	var serialized: Array[Dictionary] = []
	for item: Dictionary in ordered:
		serialized.append({
			"set_code": str(item.get("set_code", "")),
			"card_index": str(item.get("card_index", "")),
		})
	var payload := {
		"deck_id": deck_id,
		"deck_name": str(profile.get("deck_name", deck.deck_name)),
		"strategy_id": str(profile.get("strategy_id", "")),
		"generator_version": GENERATOR_VERSION,
		"description": "Cards 1-7 are the setup hand, 8-13 are controlled prizes, 14-19 bridge the first evolution and attack route, and 20-60 preserve the remaining production copies.",
		"top_to_bottom": serialized,
	}
	var output_path := "%s/%d.json" % [OUTPUT_DIR, deck_id]
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Deck %d fixed order could not be written" % deck_id}
	file.store_string(JSON.stringify(payload, "\t", false) + "\n")
	file.close()
	return {
		"ok": true,
		"summary": "opening=%s bridge=%s" % [_names(opening), _names(bridge)],
	}


func _build_copy_pool(deck: DeckData) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for entry: Dictionary in deck.cards:
		var set_code := str(entry.get("set_code", ""))
		var card_index := str(entry.get("card_index", ""))
		var card: CardData = _card_db.call("get_card", set_code, card_index)
		if card == null:
			continue
		for _copy_index: int in int(entry.get("count", 0)):
			pool.append({
				"set_code": set_code,
				"card_index": card_index,
				"uid": "%s_%s" % [set_code, card_index],
				"card": card,
			})
	return pool


func _take_into(
	target: Array[Dictionary],
	pool: Array[Dictionary],
	profile: Dictionary,
	profile_key: String,
	kind: String,
	used_uids: Dictionary,
	prefer_distinct: bool
) -> void:
	if pool.is_empty():
		return
	var best_index := _best_pool_index(pool, profile, profile_key, kind, used_uids, prefer_distinct)
	if best_index < 0 and prefer_distinct:
		best_index = _best_pool_index(pool, profile, profile_key, kind, used_uids, false)
	if best_index < 0 and kind != "any":
		best_index = _best_pool_index(pool, profile, profile_key, "any", used_uids, prefer_distinct)
	if best_index < 0:
		return
	var selected: Dictionary = pool[best_index]
	target.append(selected)
	used_uids[str(selected.get("uid", ""))] = true
	pool.remove_at(best_index)


func _take_if_space(
	target: Array[Dictionary],
	limit: int,
	pool: Array[Dictionary],
	profile: Dictionary,
	profile_key: String,
	kind: String,
	used_uids: Dictionary,
	prefer_distinct: bool
) -> void:
	if target.size() >= limit:
		return
	_take_into(target, pool, profile, profile_key, kind, used_uids, prefer_distinct)


func _take_route_energy_if_space(
	target: Array[Dictionary],
	limit: int,
	pool: Array[Dictionary],
	profile: Dictionary,
	used_uids: Dictionary,
	route_symbols: Array[String]
) -> void:
	if target.size() >= limit:
		return
	var picked_energy_count := 0
	for item: Dictionary in target:
		var existing: CardData = item.get("card", null)
		if existing != null and existing.is_energy():
			picked_energy_count += 1
	var wanted_symbol := route_symbols[picked_energy_count % route_symbols.size()] if not route_symbols.is_empty() else ""
	var best_index := -1
	if wanted_symbol != "":
		for index: int in pool.size():
			var candidate: CardData = pool[index].get("card", null)
			if candidate != null and candidate.is_energy() and _energy_provides_symbol(candidate, wanted_symbol):
				best_index = index
				break
	if best_index < 0:
		_take_into(target, pool, profile, "strong_energy_priority", "energy", used_uids, false)
		return
	var selected: Dictionary = pool[best_index]
	target.append(selected)
	used_uids[str(selected.get("uid", ""))] = true
	pool.remove_at(best_index)


func _route_energy_symbols(profile: Dictionary, pool: Array[Dictionary]) -> Array[String]:
	var priorities: Variant = profile.get("energy_priority", [])
	if not priorities is Array:
		return []
	for raw_name: Variant in priorities:
		var expected := str(raw_name).to_lower()
		var route_card: CardData = null
		for item: Dictionary in pool:
			var candidate: CardData = item.get("card", null)
			if candidate == null:
				continue
			for label: String in [str(candidate.name), str(candidate.name_en), str(candidate.get_uid()), str(candidate.effect_id)]:
				if label.to_lower() == expected:
					route_card = candidate
					break
			if route_card != null:
				break
		if route_card == null:
			continue
		var symbols := _best_attack_specific_symbols(route_card)
		if not symbols.is_empty():
			return symbols
	return []


func _best_attack_specific_symbols(card: CardData) -> Array[String]:
	var best_symbols: Array[String] = []
	var best_score := -INF
	for attack: Dictionary in card.attacks:
		var cost := CardData.normalize_attack_cost(attack.get("cost", ""))
		var symbols: Array[String] = []
		for index: int in cost.length():
			var symbol := cost.substr(index, 1)
			if symbol not in ["", "0", "C"]:
				symbols.append(symbol)
		var score := float(_damage_number(str(attack.get("damage", "")))) + float(symbols.size()) * 180.0 + float(cost.length()) * 5.0
		if score > best_score:
			best_score = score
			best_symbols = symbols
	return best_symbols


func _damage_number(text: String) -> int:
	var digits := ""
	for index: int in text.length():
		var character := text.substr(index, 1)
		if character >= "0" and character <= "9":
			digits += character
	return int(digits) if digits != "" else 0


func _energy_provides_symbol(card: CardData, symbol: String) -> bool:
	if card == null or not card.is_energy() or symbol == "":
		return false
	return str(card.energy_provides).contains(symbol)


func _take_strong_order_hints(
	target: Array[Dictionary],
	pool: Array[Dictionary],
	profile: Dictionary,
	hint_key: String,
	used_uids: Dictionary,
	limit: int
) -> String:
	var strong_raw: Variant = profile.get("strong_order", {})
	if not (strong_raw is Dictionary):
		return ""
	var hints_raw: Variant = (strong_raw as Dictionary).get(hint_key, [])
	if not (hints_raw is Array):
		return "%s must be an Array" % hint_key
	var hints: Array = hints_raw
	if hints.size() > limit:
		return "%s contains %d cards but the limit is %d" % [hint_key, hints.size(), limit]
	for raw_hint: Variant in hints:
		var hint := str(raw_hint)
		var found_index := _exact_pool_index(pool, hint)
		if found_index < 0:
			return "required card '%s' is unavailable or overused" % hint
		var selected: Dictionary = pool[found_index]
		target.append(selected)
		used_uids[str(selected.get("uid", ""))] = true
		pool.remove_at(found_index)
	return ""


func _exact_pool_index(pool: Array[Dictionary], hint: String) -> int:
	var expected := hint.to_lower()
	for index: int in pool.size():
		var item: Dictionary = pool[index]
		var card: CardData = item.get("card", null)
		if card == null:
			continue
		for label: String in [str(card.name), str(card.name_en), str(card.get_uid()), str(card.effect_id)]:
			if label.to_lower() == expected:
				return index
	return -1


func _best_pool_index(
	pool: Array[Dictionary],
	profile: Dictionary,
	profile_key: String,
	kind: String,
	used_uids: Dictionary,
	prefer_distinct: bool
) -> int:
	var best_index := -1
	var best_score := -INF
	for index: int in pool.size():
		var item: Dictionary = pool[index]
		if prefer_distinct and used_uids.has(str(item.get("uid", ""))):
			continue
		var card: CardData = item.get("card", null)
		if not _kind_matches(card, kind):
			continue
		var score := _profile_rank_score(card, profile, profile_key)
		score += _generic_kind_score(card, kind)
		if score > best_score:
			best_score = score
			best_index = index
	return best_index


func _take_prizes(pool: Array[Dictionary], profile: Dictionary, deck: DeckData) -> Array[Dictionary]:
	var original_counts: Dictionary = {}
	for entry: Dictionary in deck.cards:
		original_counts["%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]] = int(entry.get("count", 0))
	var candidates := pool.duplicate()
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _prize_importance(left, profile, original_counts) < _prize_importance(right, profile, original_counts)
	)
	var prizes: Array[Dictionary] = []
	var prize_counts: Dictionary = {}
	var pool_counts: Dictionary = {}
	for item: Dictionary in pool:
		var uid := str(item.get("uid", ""))
		pool_counts[uid] = int(pool_counts.get(uid, 0)) + 1
	var energy_count := 0
	for candidate: Dictionary in candidates:
		if prizes.size() >= PRIZE_SIZE:
			break
		var card: CardData = candidate.get("card", null)
		var uid := str(candidate.get("uid", ""))
		if int(prize_counts.get(uid, 0)) >= 1:
			continue
		if int(pool_counts.get(uid, 0)) <= 1:
			continue
		if card != null and card.is_energy() and energy_count >= 2:
			continue
		prizes.append(candidate)
		prize_counts[uid] = 1
		if card != null and card.is_energy():
			energy_count += 1
		pool.erase(candidate)
	if prizes.size() < PRIZE_SIZE:
		push_error("Deck %d has only %d safe distinct prize candidates" % [int(profile.get("deck_id", 0)), prizes.size()])
	return prizes


func _prize_importance(item: Dictionary, profile: Dictionary, original_counts: Dictionary) -> float:
	var card: CardData = item.get("card", null)
	if card == null:
		return 0.0
	var importance := 0.0
	for key: String in ["energy_priority", "evolution_priority", "search_priority", "bench_priority", "ability_priority", "trainer_priority"]:
		importance = maxf(importance, _profile_rank_score(card, profile, key))
	var uid := str(item.get("uid", ""))
	if int(original_counts.get(uid, 0)) <= 1:
		importance += 1200.0
	if card.is_energy():
		importance += 240.0
	elif card.is_basic_pokemon():
		importance += 180.0
	return importance


func _profile_rank_score(card: CardData, profile: Dictionary, key: String) -> float:
	if card == null:
		return 0.0
	var values: Variant = profile.get(key, [])
	if not (values is Array):
		return 0.0
	var labels: Array[String] = [str(card.name), str(card.name_en), str(card.get_uid()), str(card.effect_id)]
	for index: int in (values as Array).size():
		var expected := str((values as Array)[index]).to_lower()
		for label: String in labels:
			if label.to_lower() == expected:
				return 2000.0 - float(index) * 80.0
	return 0.0


func _generic_kind_score(card: CardData, kind: String) -> float:
	if card == null:
		return 0.0
	match kind:
		"basic":
			return 300.0 if card.is_basic_pokemon() else 0.0
		"trainer":
			return 220.0 if card.is_trainer() else 0.0
		"energy":
			return 180.0 if card.is_energy() else 0.0
		"evolution":
			return 260.0 if card.is_pokemon() and not card.is_basic_pokemon() else 0.0
		"pokemon":
			return 200.0 if card.is_pokemon() else 0.0
	return 100.0


func _kind_matches(card: CardData, kind: String) -> bool:
	if card == null:
		return false
	match kind:
		"basic":
			return card.is_basic_pokemon()
		"trainer":
			return card.is_trainer()
		"energy":
			return card.is_energy()
		"evolution":
			return card.is_pokemon() and not card.is_basic_pokemon()
		"pokemon":
			return card.is_pokemon()
	return true


func _complete_order(controlled_prefix: Array[Dictionary], remaining_pool: Array[Dictionary]) -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	completed.append_array(controlled_prefix)
	completed.append_array(remaining_pool)
	return completed


func _validate_order(deck: DeckData, order: Array[Dictionary]) -> String:
	if order.size() != 60:
		return "fixed order has %d cards instead of 60" % order.size()
	var allowed: Dictionary = {}
	for entry: Dictionary in deck.cards:
		allowed["%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]] = int(entry.get("count", 0))
	var used: Dictionary = {}
	var opening_has_basic := false
	for index: int in order.size():
		var item: Dictionary = order[index]
		var uid := str(item.get("uid", ""))
		used[uid] = int(used.get(uid, 0)) + 1
		if not allowed.has(uid) or int(used[uid]) > int(allowed.get(uid, 0)):
			return "fixed order overuses %s" % uid
		var card: CardData = item.get("card", null)
		if index < OPENING_SIZE and card != null and card.is_basic_pokemon():
			opening_has_basic = true
	if not opening_has_basic:
		return "opening hand has no Basic Pokemon"
	for uid: String in allowed:
		if int(used.get(uid, 0)) != int(allowed.get(uid, 0)):
			return "fixed order uses %d copies of %s instead of %d" % [
				int(used.get(uid, 0)), uid, int(allowed.get(uid, 0)),
			]
	return ""


func _names(items: Array[Dictionary]) -> String:
	var names: Array[String] = []
	for item: Dictionary in items:
		var card: CardData = item.get("card", null)
		names.append(str(card.name) if card != null else str(item.get("uid", "")))
	return ",".join(names)
