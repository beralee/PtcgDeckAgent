extends "res://scripts/ai/DeckStrategy17LLMBase.gd"


func _llm_strategy_id() -> String:
	return "v17_dragapult_dusknoir_llm"


func _rules_strategy_path() -> String:
	return "res://scripts/ai/DeckStrategy17DragapultDusknoir.gd"


func _deck_display_name() -> String:
	return "17.0 多龙巴鲁托 / 黑夜魔灵"


func _deck_primary_attackers() -> Array[String]:
	return ["Dragapult ex", "多龙巴鲁托ex", "Dreepy", "多龙梅西亚", "Drakloak", "多龙奇"]


func _deck_secondary_attackers() -> Array[String]:
	return ["Dusknoir", "黑夜魔灵", "Dusclops", "彷徨夜灵", "Radiant Alakazam", "光辉胡地"]


func _deck_support_pokemon() -> Array[String]:
	return ["Duskull", "夜巡灵", "Dusclops", "彷徨夜灵", "Dusknoir", "黑夜魔灵", "Rotom V", "Fezandipiti ex", "Radiant Alakazam", "光辉胡地", "Tatsugiri", "米立龙"]


func _deck_primary_attacks() -> Array:
	return [
		{"pokemon": "Dragapult ex", "attack": "Phantom Dive"},
		{"pokemon": "多龙巴鲁托ex", "attack": "幻影潜袭"},
	]


func _deck_low_value_attacks() -> Array:
	return [
		{"pokemon": "Dragapult ex", "attack": "Jet Head"},
		{"pokemon": "多龙巴鲁托ex", "attack": "喷射头击"},
		{"pokemon": "多龙梅西亚", "attack": "小哀怨"},
	]


func _deck_evolution_lines() -> Array:
	return [
		{"basic": "Dreepy", "stages": ["Drakloak", "Dragapult ex"], "role": "primary_attacker", "desired_count": 2, "energy": {"R": 1, "P": 1}},
		{"basic": "Duskull", "stages": ["Dusclops", "Dusknoir"], "role": "prize_conversion", "desired_count": 1},
	]


func _deck_energy_needs() -> Dictionary:
	return {
		"Dreepy": {"R": 1, "P": 1},
		"Drakloak": {"R": 1, "P": 1},
		"Dragapult ex": {"R": 1, "P": 1},
	}


func _deck_route_terms() -> Array[String]:
	return ["幻影潜袭", "喷射头击", "侦察指令", "咒怨炸弹", "乌栗", "友好宝芬", "神奇糖果", "基本火能量", "基本超能量"]


func _deck_core_plan() -> PackedStringArray:
	return PackedStringArray([
		"【核心计划】前期优先铺 Dreepy，其次 Duskull。T2/T3 以 Dragapult ex 的 Phantom Dive 作为主线，前场 200 并集中后场 6 个指示物制造奖赏地图。",
		"【能量路线】Crispin、手贴和璀璨结晶都优先让 Dragapult 线补齐 Fire + Psychic。不要把关键能量贴给纯支援宝可梦。",
		"【黑夜魔灵路线】Dusclops/Dusknoir 自爆只在能立即拿奖、配合 Phantom Dive 指示物斩杀、或阻止奖赏 race 崩盘时使用。",
		"【攻击原则】Phantom Dive 是主攻击；Jet Head 是低价值 fallback。能打 Phantom Dive 或可通过可见路线达成时，不要用 Jet Head 或 end_turn 截断路线。",
	])
