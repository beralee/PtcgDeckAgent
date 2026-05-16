extends "res://scripts/ai/DeckStrategy17LLMBase.gd"


func _llm_strategy_id() -> String:
	return "v17_water_turtle_llm"


func _rules_strategy_path() -> String:
	return "res://scripts/ai/DeckStrategy17WaterTurtle.gd"


func _deck_display_name() -> String:
	return "17.0 水龙龟"


func _deck_primary_attackers() -> Array[String]:
	return ["Terapagos ex", "太乐巴戈斯ex", "CSV9C_175", "Origin Forme Palkia VSTAR", "Origin Forme Palkia V", "起源帕路奇亚VSTAR", "起源帕路奇亚V"]


func _deck_secondary_attackers() -> Array[String]:
	return ["Radiant Greninja"]


func _deck_support_pokemon() -> Array[String]:
	return ["Hoothoot", "咕咕", "Noctowl", "猫头夜鹰", "Fan Rotom", "旋转洛托姆", "Bidoof", "Bibarel", "Fezandipiti ex", "Radiant Greninja", "CSV9C_154", "CSV9C_155", "CSV9C_161"]


func _deck_energy_banks() -> Array[String]:
	return ["Terapagos ex", "Origin Forme Palkia VSTAR"]


func _deck_primary_attacks() -> Array:
	return [
		{"pokemon": "Terapagos ex", "attack": "Unified Beatdown"},
		{"pokemon": "太乐巴戈斯ex", "attack": "同盟打击"},
		{"pokemon": "太乐巴戈斯ex", "attack": "皇冠蛋白石"},
		{"pokemon": "Origin Forme Palkia VSTAR", "attack": "Subspace Swell"},
		{"pokemon": "起源帕路奇亚VSTAR", "attack": "亚空潮漩"},
	]


func _deck_low_value_attacks() -> Array:
	return [
		{"pokemon": "咕咕", "attack": "三刺击"},
		{"pokemon": "旋转洛托姆", "attack": "突击登陆"},
	]


func _deck_evolution_lines() -> Array:
	return [
		{"basic": "Hoothoot", "stages": ["Noctowl"], "role": "support", "desired_count": 2},
		{"basic": "咕咕", "stages": ["猫头夜鹰"], "role": "support", "desired_count": 2},
		{"basic": "Origin Forme Palkia V", "stages": ["Origin Forme Palkia VSTAR"], "role": "secondary_attacker", "desired_count": 1, "energy": {"W": 2}},
		{"basic": "Bidoof", "stages": ["Bibarel"], "role": "support", "desired_count": 1},
	]


func _deck_energy_needs() -> Dictionary:
	return {
		"Terapagos ex": {"C": 2},
		"Origin Forme Palkia V": {"W": 2},
		"Origin Forme Palkia VSTAR": {"W": 2},
	}


func _deck_route_terms() -> Array[String]:
	return ["零之大空洞", "玻璃喇叭", "猫头夜鹰", "珠贝", "友好宝芬", "同盟打击", "皇冠蛋白石", "亚空潮漩", "星耀空扉", "基本水能量"]


func _deck_core_plan() -> PackedStringArray:
	return PackedStringArray([
		"【核心计划】先铺 Terapagos ex、Hoothoot/Fan Rotom 和 Palkia V，优先打开 Area Zero，让后场数量支撑 Terapagos 与 Palkia 的打点。",
		"【关键路线】T1 以铺场和 Area Zero 为主；Terapagos 后手第一回合不能期待直接出手，目标是 T2 用 Noctowl、Glass Trumpet、Palkia VSTAR 或满后场 Terapagos 打出有效伤害。",
		"【资源原则】Glass Trumpet 的能量优先给 Terapagos ex 或 Palkia 线；不要给纯支援位过量贴能。Noctowl 检索优先找缺失的 Area Zero、Glass Trumpet、进化件或攻击能量。",
		"【攻击前动作】先完成后场扩展、能量分配、Noctowl 检索和换位，再用 Terapagos/Palkia 进攻；高打点已成立时不要继续抽滤到低牌库风险。",
	])
