class_name DeckTrainingTacticScanner
extends RefCounted


const DEFAULT_RECIPES_PATH := "res://data/deck_training/tactic_recipes.json"

const COUNTER_ROLES := [
	"ability_lock",
	"bench_protection",
	"damage_modifier",
	"devolution",
	"free_retreat",
	"item_lock",
	"prize_modifier",
	"tool_lock",
	"weakness_rewrite",
]


func scan(target_catalog: Dictionary, recipes_path: String = DEFAULT_RECIPES_PATH) -> Dictionary:
	var errors: Array[String] = []
	var recipe_load := _load_json_dictionary(recipes_path)
	if not bool(recipe_load.get("ok", false)):
		return {"ok": false, "errors": [str(recipe_load.get("error", "invalid tactic recipes"))], "decks": []}
	var recipe_catalog: Dictionary = recipe_load.get("data", {})
	if int(recipe_catalog.get("format_version", 0)) != 1:
		errors.append("unsupported tactic recipe format")
	var recipes_by_deck_variant: Variant = recipe_catalog.get("decks", null)
	if not (recipes_by_deck_variant is Dictionary):
		errors.append("tactic recipe decks must be a Dictionary")
		return {"ok": false, "errors": errors, "decks": []}
	var recipes_by_deck: Dictionary = recipes_by_deck_variant
	var deck_results: Array[Dictionary] = []
	for target_variant: Variant in target_catalog.get("targets", []):
		if not (target_variant is Dictionary):
			continue
		var target: Dictionary = (target_variant as Dictionary).duplicate(true)
		target["minimum_tactic_patterns"] = int(target_catalog.get("minimum_tactic_patterns", 3))
		var deck_key := str(target.get("deck_key", ""))
		var result := _scan_target(target, recipes_by_deck.get(deck_key, []))
		deck_results.append(result)
		for error: Variant in result.get("errors", []):
			errors.append("%s: %s" % [deck_key, str(error)])
	for deck_key_variant: Variant in recipes_by_deck.keys():
		var deck_key := str(deck_key_variant)
		var found := false
		for target_variant: Variant in target_catalog.get("targets", []):
			if target_variant is Dictionary and str((target_variant as Dictionary).get("deck_key", "")) == deck_key:
				found = true
				break
		if not found:
			errors.append("recipes contain unknown target deck_key: %s" % deck_key)
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"decks": deck_results,
		"recipe_count": _sum_recipe_count(deck_results),
		"tech_candidate_count": _sum_tech_candidate_count(deck_results),
	}


func _scan_target(target: Dictionary, recipes_variant: Variant) -> Dictionary:
	var errors: Array[String] = []
	var deck_key := str(target.get("deck_key", ""))
	var deck_id := int(target.get("deck_id", 0))
	var deck_load := _load_json_dictionary("res://data/bundled_user/decks/%d.json" % deck_id)
	if not bool(deck_load.get("ok", false)):
		return {"deck_key": deck_key, "deck_id": deck_id, "ok": false, "errors": [deck_load.get("error", "missing deck")]}
	var deck: Dictionary = deck_load.get("data", {})
	var card_inventory: Dictionary = {}
	var semantic_cards: Array[Dictionary] = []
	var tech_candidates: Array[Dictionary] = []
	for entry_variant: Variant in deck.get("cards", []):
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var card_ref := _entry_ref(entry)
		card_inventory[card_ref] = entry
		if str(entry.get("card_type", "")).contains("Energy"):
			continue
		var card_load := _load_json_dictionary(_card_path(card_ref))
		if not bool(card_load.get("ok", false)):
			errors.append("cannot scan %s: %s" % [card_ref, str(card_load.get("error", "invalid card"))])
			continue
		var card: Dictionary = card_load.get("data", {})
		var roles := infer_roles(str(card.get("description", "")))
		if roles.is_empty():
			continue
		var semantic := {
			"card_ref": card_ref,
			"name": str(card.get("name", entry.get("name", ""))),
			"count": int(entry.get("count", 0)),
			"roles": roles,
		}
		semantic_cards.append(semantic)
		if int(entry.get("count", 0)) <= 1 and _has_any_role(roles, COUNTER_ROLES):
			tech_candidates.append(semantic.duplicate(true))

	var recipes: Array = recipes_variant if recipes_variant is Array else []
	var validated_recipes: Array[Dictionary] = []
	var seen_recipe_ids: Dictionary = {}
	for recipe_variant: Variant in recipes:
		if not (recipe_variant is Dictionary):
			errors.append("recipe entry must be a Dictionary")
			continue
		var recipe: Dictionary = (recipe_variant as Dictionary).duplicate(true)
		var recipe_errors := _validate_recipe(recipe, card_inventory, seen_recipe_ids)
		recipe["ok"] = recipe_errors.is_empty()
		recipe["errors"] = recipe_errors
		validated_recipes.append(recipe)
		for error: String in recipe_errors:
			errors.append("%s: %s" % [str(recipe.get("id", "unnamed")), error])
	var minimum_patterns := int(target.get("minimum_tactic_patterns", 3))
	if validated_recipes.size() < minimum_patterns:
		errors.append("needs at least %d verified tactic recipes" % minimum_patterns)
	return {
		"deck_key": deck_key,
		"deck_id": deck_id,
		"cards_scanned": card_inventory.size(),
		"semantic_cards": semantic_cards,
		"tech_candidates": tech_candidates,
		"recipes": validated_recipes,
		"recipe_count": validated_recipes.size(),
		"ok": errors.is_empty(),
		"errors": errors,
	}


func infer_roles(description: String) -> Array[String]:
	var roles: Array[String] = []
	_add_role_if(roles, "self_ko_damage", description.contains("令这只宝可梦【昏厥】") and description.contains("伤害指示物"))
	_add_role_if(roles, "damage_counter_move", description.contains("转放于对手") and description.contains("伤害指示物"))
	_add_role_if(roles, "bench_damage", description.contains("备战宝可梦") and (description.contains("造成") or description.contains("伤害指示物")))
	_add_role_if(roles, "gust", description.contains("备战宝可梦") and description.contains("互换"))
	_add_role_if(roles, "item_lock", description.contains("无法从手牌使出物品"))
	_add_role_if(roles, "ability_lock", description.contains("特性") and description.contains("全部消除"))
	_add_role_if(roles, "tool_lock", description.contains("宝可梦道具") and description.contains("效果，全部消除"))
	_add_role_if(roles, "bench_protection", description.contains("备战宝可梦") and description.contains("不会受到") and description.contains("伤害"))
	_add_role_if(roles, "weakness_rewrite", description.contains("弱点全部变为"))
	_add_role_if(roles, "devolution", description.contains("使其退化"))
	_add_role_if(roles, "damage_modifier", description.contains("造成的伤害") and (description.contains("+30") or description.contains("+40")))
	_add_role_if(roles, "prize_modifier", description.contains("多拿取1张奖赏卡") or description.contains("奖赏卡将增加1张"))
	_add_role_if(roles, "free_retreat", description.contains("撤退") and description.contains("全部消除"))
	_add_role_if(roles, "energy_acceleration", description.contains("能量") and description.contains("附着于"))
	_add_role_if(roles, "energy_move", description.contains("能量") and description.contains("转附于"))
	_add_role_if(roles, "attack_copy", description.contains("作为这个招式使用"))
	_add_role_if(roles, "search", description.contains("选择自己牌库中"))
	_add_role_if(roles, "draw", description.contains("抽取") and description.contains("牌库"))
	return roles


func _validate_recipe(recipe: Dictionary, card_inventory: Dictionary, seen: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var recipe_id := str(recipe.get("id", "")).strip_edges()
	if recipe_id == "":
		errors.append("missing id")
	elif seen.has(recipe_id):
		errors.append("duplicate id")
	seen[recipe_id] = true
	var kind := str(recipe.get("kind", ""))
	if kind not in ["combo", "matchup_counter", "sequencing_combo"]:
		errors.append("unsupported kind %s" % kind)
	for field: String in ["name", "trigger", "payoff"]:
		if str(recipe.get(field, "")).strip_edges() == "":
			errors.append("missing %s" % field)
	var source_refs_variant: Variant = recipe.get("source_card_refs", null)
	if not (source_refs_variant is Array) or (source_refs_variant as Array).is_empty():
		errors.append("source_card_refs must not be empty")
	else:
		for ref_variant: Variant in source_refs_variant:
			var card_ref := str(ref_variant)
			if not card_inventory.has(card_ref):
				errors.append("source card is not in frozen deck: %s" % card_ref)
			elif not FileAccess.file_exists(_card_path(card_ref)):
				errors.append("source card data is missing: %s" % card_ref)
	var target_refs: Array = recipe.get("target_card_refs", [])
	if kind == "matchup_counter" and target_refs.is_empty():
		errors.append("matchup_counter needs at least one concrete target card")
	for ref_variant: Variant in target_refs:
		var target_ref := str(ref_variant)
		if not FileAccess.file_exists(_card_path(target_ref)):
			errors.append("target card data is missing: %s" % target_ref)
	var target_predicate_variant: Variant = recipe.get("target_predicate", null)
	if target_predicate_variant is Dictionary and not target_refs.is_empty():
		var predicate_matched := false
		for ref_variant: Variant in target_refs:
			var target_load := _load_json_dictionary(_card_path(str(ref_variant)))
			if bool(target_load.get("ok", false)) and _card_matches_predicate(target_load.get("data", {}), target_predicate_variant):
				predicate_matched = true
				break
		if not predicate_matched:
			errors.append("no target card satisfies target_predicate")
	if (recipe.get("puzzle_hooks", []) as Array).size() < 2:
		errors.append("needs at least two puzzle hooks")
	if (recipe.get("failure_modes", []) as Array).is_empty():
		errors.append("needs at least one failure mode")
	return errors


func _card_matches_predicate(card: Dictionary, predicate_variant: Variant) -> bool:
	if not (predicate_variant is Dictionary):
		return true
	var predicate: Dictionary = predicate_variant
	var field_equals_variant: Variant = predicate.get("field_equals", {})
	if field_equals_variant is Dictionary:
		for field_variant: Variant in (field_equals_variant as Dictionary).keys():
			var field := str(field_variant)
			if str(card.get(field, "")) != str((field_equals_variant as Dictionary).get(field_variant, "")):
				return false
	var description := str(card.get("description", ""))
	for needle_variant: Variant in predicate.get("description_contains", []):
		if not description.contains(str(needle_variant)):
			return false
	return true


func _entry_ref(entry: Dictionary) -> String:
	return "%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]


func _card_path(card_ref: String) -> String:
	return "res://data/bundled_user/cards/%s.json" % card_ref


func _add_role_if(roles: Array[String], role: String, condition: bool) -> void:
	if condition:
		roles.append(role)


func _has_any_role(roles: Array[String], wanted: Array) -> bool:
	for role: String in roles:
		if role in wanted:
			return true
	return false


func _sum_recipe_count(decks: Array[Dictionary]) -> int:
	var total := 0
	for deck: Dictionary in decks:
		total += int(deck.get("recipe_count", 0))
	return total


func _sum_tech_candidate_count(decks: Array[Dictionary]) -> int:
	var total := 0
	for deck: Dictionary in decks:
		total += (deck.get("tech_candidates", []) as Array).size()
	return total


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing JSON: %s" % path, "data": {}}
	var json := JSON.new()
	var parse_error := json.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK or not (json.data is Dictionary):
		return {"ok": false, "error": "invalid JSON %s: %s" % [path, json.get_error_message()], "data": {}}
	return {"ok": true, "error": "", "data": (json.data as Dictionary).duplicate(true)}
