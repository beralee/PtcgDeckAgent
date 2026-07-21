class_name V18CPGDeckSemanticCompiler
extends RefCounted

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")


func compile(deck: DeckData, profile: Dictionary) -> Dictionary:
	var cards: Array[Dictionary] = []
	var role_counts: Dictionary = {}
	if deck != null:
		for entry: Dictionary in deck.cards:
			var semantic := _compile_entry(entry, profile)
			cards.append(semantic)
			for role: String in semantic.get("roles", []):
				role_counts[role] = int(role_counts.get(role, 0)) + int(entry.get("count", 1))
	var manifest := {
		"schema_version": 1,
		"semantic_version": int(profile.get("semantic_version", 1)),
		"deck_id": int(profile.get("deck_id", 0)),
		"deck_content_fingerprint": deck_content_fingerprint(deck),
		"strategy_id": str(profile.get("strategy_id", "")),
		"primary_module": str(profile.get("primary_module", "")),
		"modules": (profile.get("modules", []) as Array).duplicate(true) if profile.get("modules", []) is Array else [],
		"cards": cards,
		"role_counts": role_counts,
	}
	manifest["manifest_hash"] = ContractsScript.stable_hash(manifest)
	return manifest


static func deck_content_fingerprint(deck: DeckData) -> String:
	if deck == null:
		return ""
	# Only hash gameplay-bearing deck content. Import timestamps and localized
	# display metadata may change without changing a benchmark matchup.
	return ContractsScript.stable_hash({
		"deck_id": int(deck.id),
		"cards": deck.cards.duplicate(true),
		"total_cards": int(deck.total_cards),
		"strategy": str(deck.strategy),
	})


func roles_for_card_ref(card_ref: Dictionary, manifest: Dictionary) -> Array[String]:
	var uid := str(card_ref.get("uid", ""))
	for raw_card: Variant in manifest.get("cards", []):
		if raw_card is Dictionary and str((raw_card as Dictionary).get("uid", "")) == uid:
			var roles: Array[String] = []
			for role: Variant in (raw_card as Dictionary).get("roles", []):
				roles.append(str(role))
			return roles
	return _infer_roles(
		str(card_ref.get("name", "")),
		str(card_ref.get("type", "")),
		str(card_ref.get("effect_id", ""))
	)


func roles_for_card_data(data: CardData, manifest: Dictionary = {}) -> Array[String]:
	if data == null:
		return []
	var ref := {
		"uid": data.get_uid(),
		"name": data.name_en if data.name_en != "" else data.name,
		"type": data.card_type,
		"effect_id": data.effect_id,
	}
	var roles := roles_for_card_ref(ref, manifest)
	var text := (str(data.name) + " " + str(data.name_en) + " " + str(data.description)).to_lower()
	if _contains_any(text, ["search your deck", "从自己的牌库", "choose up to", "选择最多"]):
		roles.append("search_engine")
	if _contains_any(text, ["basic energy", "基本能量", "energy card", "能量卡"]):
		roles.append("energy_access")
	if _contains_any(text, ["attach", "附着", "from your discard", "弃牌区"]):
		roles.append("supporter_acceleration")
	if _contains_any(text, ["switch your active", "交换自己的战斗", "switch 1 of", "替换"]):
		roles.append("pivot")
	return _unique(roles)


func _compile_entry(entry: Dictionary, profile: Dictionary = {}) -> Dictionary:
	var uid := "%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]
	var name := str(entry.get("name_en", ""))
	if name == "":
		name = str(entry.get("name", ""))
	var roles := _infer_roles(name, str(entry.get("card_type", "")), str(entry.get("effect_id", "")))
	roles.append_array(_profile_roles(entry, profile))
	roles = _apply_profile_role_overrides(uid, roles, profile)
	return {
		"uid": uid,
		"effect_id": str(entry.get("effect_id", "")),
		"name": name,
		"type": str(entry.get("card_type", "")),
		"count": int(entry.get("count", 1)),
		"roles": _unique(roles),
	}


func _apply_profile_role_overrides(uid: String, roles: Array[String], profile: Dictionary) -> Array[String]:
	var result := _unique(roles)
	var all_overrides: Dictionary = profile.get("semantic_role_overrides", {}) \
		if profile.get("semantic_role_overrides", {}) is Dictionary else {}
	var override: Dictionary = all_overrides.get(uid, {}) if all_overrides.get(uid, {}) is Dictionary else {}
	for raw_role: Variant in override.get("remove", []):
		result.erase(str(raw_role))
	for raw_role: Variant in override.get("add", []):
		var role := str(raw_role)
		if role != "" and role not in result:
			result.append(role)
	return result


func _profile_roles(entry: Dictionary, profile: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var rule_profile: Dictionary = profile.get("rule_profile", {}) \
		if profile.get("rule_profile", {}) is Dictionary else {}
	if rule_profile.is_empty():
		return result
	var names: Array[String] = []
	for key: String in ["name", "name_en", "source_name"]:
		var value := str(entry.get(key, "")).strip_edges().to_lower()
		if value != "" and value not in names:
			names.append(value)
	var mappings := {
		"signatures": ["signature_piece"],
		"opening_active": ["opening_active_candidate"],
		"active_priority": ["attacker"],
		"bench_priority": ["development_piece"],
		"energy_priority": ["energy_target", "attacker"],
		"evolution_priority": ["evolution_piece"],
		"search_priority": ["search_target"],
		"ability_priority": ["ability_engine"],
		"trainer_priority": ["trainer_plan_piece"],
	}
	for raw_key: Variant in mappings.keys():
		var key := str(raw_key)
		var configured: Variant = rule_profile.get(key, [])
		if not (configured is Array):
			continue
		var matched := false
		for raw_configured: Variant in configured:
			if str(raw_configured).strip_edges().to_lower() in names:
				matched = true
				break
		if matched:
			for raw_role: Variant in mappings[key]:
				result.append(str(raw_role))
	var modules: Array = profile.get("modules", []) if profile.get("modules", []) is Array else []
	if "stage2_chain" in modules and "evolution_piece" in result:
		result.append("stage2_dependency")
	if "dragapult_spread" in modules and "attacker" in result:
		result.append("spread_attacker_candidate")
	if "gardevoir_embrace" in modules and "energy_target" in result:
		result.append("embrace_target")
	if "copy_attack_toolbox" in modules and "ability_engine" in result:
		result.append("copy_source")
	if "partner_chain" in modules and "signature_piece" in result:
		result.append("partner_piece")
	return _unique(result)


func _infer_roles(name: String, card_type: String, effect_id: String) -> Array[String]:
	var roles: Array[String] = []
	var text := (name + " " + effect_id).to_lower()
	if card_type == "Pokemon":
		roles.append("pokemon")
		if text.contains("noctowl") or name.contains("猫头夜鹰"):
			roles.append_array(["search_engine", "noctowl_search"])
		if text.contains("ogerpon") or name.contains("厄诡椪"):
			roles.append_array(["attacker", "energy_accelerator"])
		if text.contains("raging bolt") or name.contains("猛雷鼓"):
			roles.append_array(["attacker", "energy_burst"])
		if text.contains("flareon") or name.contains("火伊布") or text.contains("terapagos") or name.contains("太乐巴戈斯"):
			roles.append("attacker")
	elif card_type in ["Basic Energy", "Special Energy"]:
		roles.append_array(["energy_source", "typed_energy"])
	elif card_type == "Supporter":
		roles.append("supporter")
	elif card_type == "Stadium":
		roles.append("stadium")
	else:
		roles.append("item")
	if _contains_any(text, ["nest ball", "ultra ball", "buddy-buddy", "poffin", "太晶珠", "巢穴球", "高级球", "友好宝芬"]):
		roles.append("pokemon_search")
	if _contains_any(text, ["earthen vessel", "energy search", "大地容器", "能量输送"]):
		roles.append_array(["energy_access", "typed_energy_access"])
	if _contains_any(text, ["crispin", "sada", "奥琳", "赤松"]):
		roles.append_array(["supporter_acceleration", "energy_access"])
	if _contains_any(text, ["energy switch", "能量转移"]):
		roles.append("energy_mover")
	if _contains_any(text, ["boss", "counter catcher", "反击捕捉器", "老板的指令"]):
		roles.append("gust")
	if _contains_any(text, ["switch", "turo", "调换", "切换", "图罗"]):
		roles.append("pivot")
	if _contains_any(text, ["night stretcher", "super rod", "夜间担架", "厉害钓竿", "回收"]):
		roles.append("recovery")
	if _contains_any(text, ["arven", "派帕"]):
		roles.append("trainer_tutor")
	if _contains_any(text, ["bravery charm", "勇气护符"]):
		roles.append("hp_expansion_tool")
	if _contains_any(text, ["draw", "research", "iono", "judge", "博士", "奇树"]):
		roles.append("draw_engine")
	return _unique(roles)


func _contains_any(text: String, needles: Array[String]) -> bool:
	for needle: String in needles:
		if text.contains(needle.to_lower()):
			return true
	return false


func _unique(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		if value != "" and not result.has(value):
			result.append(value)
	return result
