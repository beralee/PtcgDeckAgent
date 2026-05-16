extends "res://scripts/ai/DeckStrategy17LLMBase.gd"


func _llm_strategy_id() -> String:
	return "v17_miraidon_llm"


func _rules_strategy_path() -> String:
	return "res://scripts/ai/DeckStrategy17Miraidon.gd"


func _deck_display_name() -> String:
	return "17.0 密勒顿"


func _deck_primary_attackers() -> Array[String]:
	return ["Miraidon ex", "密勒顿ex", "Iron Hands ex", "铁臂膀ex", "Raikou V", "雷公V", "Raichu V", "雷丘V", "Pikachu ex", "皮卡丘ex", "CSV9C_054"]


func _deck_secondary_attackers() -> Array[String]:
	return ["Zapdos", "Mew ex", "Bloodmoon Ursaluna ex"]


func _deck_support_pokemon() -> Array[String]:
	return ["Latias ex", "拉帝亚斯ex", "Lumineon V", "Squawkabilly ex", "怒鹦哥ex", "Fezandipiti ex", "Iron Bundle", "铁包袱", "Magnemite", "小磁怪", "Magneton", "三合一磁怪"]


func _deck_energy_banks() -> Array[String]:
	return ["Raichu V", "Iron Hands ex"]


func _deck_primary_attacks() -> Array:
	return [
		{"pokemon": "Iron Hands ex", "attack": "Amp You Very Much"},
		{"pokemon": "铁臂膀ex", "attack": "多谢款待"},
		{"pokemon": "Raikou V", "attack": "Lightning Rondo"},
		{"pokemon": "雷公V", "attack": "闪电回旋"},
		{"pokemon": "Miraidon ex", "attack": "Photon Blaster"},
		{"pokemon": "密勒顿ex", "attack": "光子引爆"},
		{"pokemon": "Raichu V", "attack": "Dynamic Spark"},
		{"pokemon": "雷丘V", "attack": "爆能火花"},
		{"pokemon": "皮卡丘ex", "attack": "黄晶伏特"},
	]


func _deck_low_value_attacks() -> Array:
	return [{"pokemon": "Raichu V", "attack": "Fast Charge"}]


func _deck_setup_draw_attacks() -> Array:
	return [{"pokemon": "Raichu V", "attack": "Fast Charge"}]


func _deck_energy_needs() -> Dictionary:
	return {
		"Miraidon ex": {"L": 2, "C": 1},
		"Iron Hands ex": {"L": 2, "C": 1},
		"Raikou V": {"L": 1, "C": 1},
		"Raichu V": {"L": 1},
		"Pikachu ex": {"L": 2},
	}


func _deck_route_terms() -> Array[String]:
	return ["串联装置", "电气发生器", "零之大空洞", "黄晶伏特", "光子引爆", "多谢款待", "闪电回旋", "爆能火花", "基本雷能量"]


func _deck_core_plan() -> PackedStringArray:
	return PackedStringArray([
		"【核心计划】第一目标是 Miraidon ex 或检索牌启动铺场，打开 Area Zero 后把后场铺到 6 只以上，支撑 Raikou V / Miraidon ex / Pikachu ex 的高打点。",
		"【快攻路线】后手第一回合若能用 Raikou V、Miraidon ex、Iron Hands ex 或 Zapdos 直接制造有效伤害，应优先完成铺场、发电、贴能、换位后攻击。",
		"【发电原则】Electric Generator 先确保后场有可接雷能的真实攻击手，再使用。雷能优先给本回合能攻击或下回合能接棒的 Iron Hands ex、Raikou V、Miraidon ex、Pikachu ex。",
		"【资源原则】Raichu V 是终结爆发，不要早期无目的上场或消耗全场雷能；Iron Hands ex 的额外奖赏路线价值很高，能拿奖时优先规划。",
	])
