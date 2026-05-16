extends "res://scripts/ai/DeckStrategy17LLMBase.gd"


func _llm_strategy_id() -> String:
	return "v17_archaludon_dialga_llm"


func _rules_strategy_path() -> String:
	return "res://scripts/ai/DeckStrategy17ArchaludonDialga.gd"


func _deck_display_name() -> String:
	return "17.0 铝钢桥龙 / 帝牙卢卡"


func _deck_primary_attackers() -> Array[String]:
	return ["Archaludon ex", "铝钢桥龙ex", "铝钢龙", "Origin Forme Dialga VSTAR", "Origin Forme Dialga V", "起源帝牙卢卡VSTAR", "起源帝牙卢卡V", "CSV9C_138", "CSV9C_136"]


func _deck_secondary_attackers() -> Array[String]:
	return ["Mew ex", "Radiant Greninja"]


func _deck_support_pokemon() -> Array[String]:
	return ["Mew ex", "Radiant Greninja", "Fezandipiti ex"]


func _deck_energy_banks() -> Array[String]:
	return ["Archaludon ex", "铝钢桥龙ex", "Origin Forme Dialga VSTAR", "起源帝牙卢卡VSTAR"]


func _deck_primary_attacks() -> Array:
	return [
		{"pokemon": "Archaludon ex", "attack": "Metal Defender"},
		{"pokemon": "铝钢桥龙ex", "attack": "金属防卫"},
		{"pokemon": "Origin Forme Dialga VSTAR", "attack": "Metal Blast"},
		{"pokemon": "起源帝牙卢卡VSTAR", "attack": "金属爆裂"},
		{"pokemon": "Origin Forme Dialga VSTAR", "attack": "Star Chronos"},
		{"pokemon": "起源帝牙卢卡VSTAR", "attack": "星辰时钟"},
	]


func _deck_route_terms() -> Array[String]:
	return ["合金建设", "金属防卫", "金属涂层", "金属爆裂", "星辰时钟", "基本钢能量", "大地容器", "高级球"]


func _deck_evolution_lines() -> Array:
	return [
		{"basic": "CSV9C_136", "stages": ["CSV9C_138"], "role": "primary_attacker", "desired_count": 2, "energy": {"M": 3}},
		{"basic": "Origin Forme Dialga V", "stages": ["Origin Forme Dialga VSTAR"], "role": "secondary_attacker", "desired_count": 1, "energy": {"M": 5}},
	]


func _deck_energy_needs() -> Dictionary:
	return {
		"Archaludon ex": {"M": 3},
		"Origin Forme Dialga V": {"M": 2},
		"Origin Forme Dialga VSTAR": {"M": 5},
	}


func _deck_core_plan() -> PackedStringArray:
	return PackedStringArray([
		"【核心计划】先铺 Duraludon 与 Origin Forme Dialga V，利用 Earthen Vessel / Ultra Ball / Radiant Greninja 把 Metal Energy 放进弃牌区，再进化 Archaludon ex 加速金属能量。",
		"【进攻路线】Archaludon ex 是稳定 220 压力；Dialga VSTAR 的 Metal Blast 随金属能量成长，Star Chronos 能制造额外回合，只有能拿奖或形成决定性节奏时才使用。",
		"【资源原则】Metal Energy 是所有路线的核心。弃牌优先服务于 Archaludon ex 的加速，不要把 Archaludon ex、Dialga VSTAR、唯一 Duraludon 或 Dialga V 当作普通弃牌。",
		"【攻击前动作】能量加速、进化、Metal Energy 分配、Prime Catcher/Boss 拿奖都要在攻击前完成；有高压攻击时停止无意义抽滤。",
	])
