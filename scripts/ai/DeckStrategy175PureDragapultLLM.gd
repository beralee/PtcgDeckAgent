extends "res://scripts/ai/DeckStrategy17DragapultDusknoirLLM.gd"

const BUDEW := "Budew"
const BUDEW_CN := "含羞苞"
const LANCE := "Lance"
const LANCE_CN := "阿渡"


func _llm_strategy_id() -> String:
	return "v175_pure_dragapult_llm"


func _rules_strategy_path() -> String:
	return "res://scripts/ai/DeckStrategy175PureDragapult.gd"


func _deck_display_name() -> String:
	return "17.5 纯多龙"


func _deck_support_pokemon() -> Array[String]:
	var names := super._deck_support_pokemon()
	for name: String in [BUDEW, BUDEW_CN]:
		if not names.has(name):
			names.append(name)
	return names


func _deck_route_terms() -> Array[String]:
	var terms := super._deck_route_terms()
	for term: String in [BUDEW, BUDEW_CN, LANCE, LANCE_CN, "Itchy Pollen", "刺刺花粉", "阿渡检索"]:
		if not terms.has(term):
			terms.append(term)
	return terms


func _deck_core_plan() -> PackedStringArray:
	var lines := super._deck_core_plan()
	lines.insert(0, "【17.5 调整】这套牌用含羞苞做前期缓冲和物品封锁，用阿渡一次拿多龙梅西亚/多龙奇/多龙巴鲁托ex来补齐主线。规则策略仍负责普通评分，LLM 只在结构化 payload 中选择路线。")
	lines.append("【含羞苞策略】Dragapult ex 未成型时，含羞苞是高价值前场缓冲；先完成安全铺场、阿渡/宝芬/巢穴球检索和进化，再用 Itchy Pollen 作为终端封锁。Dragapult ex 已能安全进攻时，不要让含羞苞继续挡住主攻。")
	lines.append("【阿渡策略】阿渡优先补当前多龙线缺口：已有可进化 Dreepy 时先拿 Drakloak；已有 Drakloak 或糖果路线时拿 Dragapult ex；缺第一条线时再拿 Dreepy。不要为了额外基础宝可梦延误第一只 Dragapult ex。")
	lines.append("Action-id discipline: Items and Supporters are still play_trainer ids. Copy exact ids such as play_trainer:cNN from legal_actions or candidate_routes; never invent play_item:* aliases for Buddy-Buddy Poffin, Nest Ball, Arven, Lance, or any other Item/Supporter.")
	lines.append("Attack and Energy ids are also exact. Never invent attack:active:1, attack:<attack_name>, attach_energy:Fire:active, or attach_energy:Psychic:active. Copy the complete legal_actions id with its card instance and displayed attack text, or choose the matching candidate_route id.")
	lines.append("Branch discipline: can_attack only means the phase allows attacks. A branch that starts with an attack must include active_attack_ready with the exact attack_name; a setup-to-attack branch must include the real attack action or a candidate_route id, not only setup plus end_turn.")
	lines.append("Interaction discipline: if a legal_action has an empty interaction_schema, do not add action.interactions. Use selection_policy when available, or pick a listed candidate_route and let rules fallback choose the legal search/discard targets.")
	return lines


func get_llm_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return super.get_llm_setup_role_hint(cd)
	var name := _best_card_name(cd)
	if _v17_name_contains(name, BUDEW) or _v17_name_contains(name, BUDEW_CN):
		return "opening item-lock buffer; promote while Dreepy evolves behind it, then pivot to ready Dragapult ex"
	if _v17_name_contains(name, LANCE) or _v17_name_contains(name, LANCE_CN):
		return "Dragon search supporter; use to assemble Dreepy -> Drakloak -> Dragapult ex in the current missing order"
	return super.get_llm_setup_role_hint(cd)


func get_intent_planner_profile() -> Dictionary:
	var profile := super.get_intent_planner_profile()
	var support_only: Array = profile.get("support_only", []) if profile.get("support_only", []) is Array else []
	for name: String in [BUDEW, BUDEW_CN]:
		if not support_only.has(name):
			support_only.append(name)
	profile["support_only"] = support_only
	var setup_attacks: Array = profile.get("setup_draw_attacks", []) if profile.get("setup_draw_attacks", []) is Array else []
	setup_attacks.append({"pokemon": BUDEW, "attack": "Itchy Pollen"})
	setup_attacks.append({"pokemon": BUDEW_CN, "attack": "刺刺花粉"})
	profile["setup_draw_attacks"] = setup_attacks
	return profile


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	if super._deck_hand_card_is_productive_piece(card_data):
		return true
	var name := _best_card_name(card_data)
	return _v17_name_contains(name, BUDEW) or _v17_name_contains(name, BUDEW_CN) or _v17_name_contains(name, LANCE) or _v17_name_contains(name, LANCE_CN)


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	if super._deck_is_setup_or_resource_card(card_data):
		return true
	var name := _best_card_name(card_data)
	return _v17_name_contains(name, BUDEW) or _v17_name_contains(name, BUDEW_CN) or _v17_name_contains(name, LANCE) or _v17_name_contains(name, LANCE_CN)
