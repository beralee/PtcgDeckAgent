extends "res://scripts/ai/DeckStrategy17LLMBase.gd"


func _llm_strategy_id() -> String:
	return "v17_palkia_gholdengo_llm"


func _rules_strategy_path() -> String:
	return "res://scripts/ai/DeckStrategy17PalkiaGholdengo.gd"


func _deck_display_name() -> String:
	return "17.0 水龙赛富豪"


func _deck_primary_attackers() -> Array[String]:
	return ["Gholdengo ex", "赛富豪ex", "Gimmighoul", "索财灵", "CSV9C_096", "Origin Forme Palkia VSTAR", "Origin Forme Palkia V", "起源帕路奇亚VSTAR", "起源帕路奇亚V"]


func _deck_secondary_attackers() -> Array[String]:
	return ["Radiant Greninja", "Iron Bundle"]


func _deck_support_pokemon() -> Array[String]:
	return ["Radiant Greninja", "Fezandipiti ex", "Manaphy", "Iron Bundle"]


func _deck_energy_banks() -> Array[String]:
	return ["Gholdengo ex", "Origin Forme Palkia VSTAR"]


func _deck_primary_attacks() -> Array:
	return [
		{"pokemon": "Gholdengo ex", "attack": "Make It Rain"},
		{"pokemon": "赛富豪ex", "attack": "淘金潮"},
		{"pokemon": "Origin Forme Palkia VSTAR", "attack": "Subspace Swell"},
		{"pokemon": "起源帕路奇亚VSTAR", "attack": "亚空潮漩"},
	]


func _deck_low_value_attacks() -> Array:
	return [{"pokemon": "索财灵", "attack": "撞击"}]


func _deck_evolution_lines() -> Array:
	return [
		{"basic": "Gimmighoul", "stages": ["Gholdengo ex"], "role": "primary_attacker", "desired_count": 2, "energy": {"M": 1}},
		{"basic": "索财灵", "stages": ["赛富豪ex"], "role": "primary_attacker", "desired_count": 2, "energy": {"M": 1}},
		{"basic": "Origin Forme Palkia V", "stages": ["Origin Forme Palkia VSTAR"], "role": "secondary_attacker", "desired_count": 1, "energy": {"W": 2}},
	]


func _deck_energy_needs() -> Dictionary:
	return {
		"Gholdengo ex": {"M": 1},
		"Origin Forme Palkia V": {"W": 2},
		"Origin Forme Palkia VSTAR": {"W": 2},
	}


func _deck_route_terms() -> Array[String]:
	return ["淘金潮", "嘉奖硬币", "能量搜索PRO", "高级能量回收", "能量回收", "大地容器", "亚空潮漩", "星耀空扉", "基本钢能量", "基本水能量"]


func _deck_core_plan() -> PackedStringArray:
	return PackedStringArray([
		"【核心计划】前期铺 Gimmighoul 与 Palkia V，T2 优先完成 Gholdengo ex 或 Palkia VSTAR 的有效攻击路线。",
		"【赛富豪路线】Gholdengo ex 的 Make It Rain 需要手牌基础能量作为伤害资源。Energy Search Pro、Superior Energy Retrieval、Energy Retrieval 和 Earthen Vessel 都应服务于本回合斩杀或下回合连续进攻。",
		"【水龙路线】Palkia VSTAR 是稳定副打手和能量压力点。若 Gholdengo 缺能量或进化件，Palkia 可以承担 T2/T3 进攻。",
		"【资源原则】Make It Rain 只丢达到击倒或高压所需的最少能量；低牌库时不要为了额外抽滤牺牲已经成立的攻击路线。",
	])
