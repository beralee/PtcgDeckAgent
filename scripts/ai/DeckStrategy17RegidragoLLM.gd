extends "res://scripts/ai/DeckStrategy17LLMBase.gd"


func _llm_strategy_id() -> String:
	return "v17_regidrago_llm"


func _rules_strategy_path() -> String:
	return "res://scripts/ai/DeckStrategy17Regidrago.gd"


func _deck_display_name() -> String:
	return "17.0 龙柱"


func _deck_primary_attackers() -> Array[String]:
	return ["Regidrago VSTAR", "雷吉铎拉戈VSTAR", "Regidrago V", "雷吉铎拉戈V"]


func _deck_secondary_attackers() -> Array[String]:
	return ["Radiant Charizard", "光辉喷火龙", "Alolan Exeggutor ex", "阿罗拉 椰蛋树ex", "Kyurem", "酋雷姆"]


func _deck_support_pokemon() -> Array[String]:
	return [
		"Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex",
		"Squawkabilly ex", "怒鹦哥ex",
		"Fezandipiti ex", "吉雉鸡ex",
		"Mew ex", "梦幻ex",
		"Cleffa", "皮宝宝",
		"Hawlucha", "摔角鹰人",
		"Dragapult ex", "多龙巴鲁托ex",
		"Giratina VSTAR", "骑拉帝纳VSTAR",
		"Hisuian Goodra VSTAR", "洗翠 黏美龙VSTAR",
	]


func _deck_energy_banks() -> Array[String]:
	return ["Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex"]


func _deck_primary_attacks() -> Array:
	return [
		{"pokemon": "Regidrago VSTAR", "attack": "Apex Dragon"},
		{"pokemon": "雷吉铎拉戈VSTAR", "attack": "巨龙无双"},
		{"pokemon": "Dragapult ex", "attack": "Phantom Dive"},
		{"pokemon": "多龙巴鲁托ex", "attack": "幻影潜袭"},
		{"pokemon": "Giratina VSTAR", "attack": "Lost Impact"},
		{"pokemon": "骑拉帝纳VSTAR", "attack": "迷失冲击"},
		{"pokemon": "Alolan Exeggutor ex", "attack": "Tropical Frenzy"},
		{"pokemon": "阿罗拉 椰蛋树ex", "attack": "热带狂热"},
		{"pokemon": "Kyurem", "attack": "Trifrost"},
		{"pokemon": "酋雷姆", "attack": "三重冰霜"},
	]


func _deck_low_value_attacks() -> Array:
	return [
		{"pokemon": "Regidrago V", "attack": "Celestial Roar"},
		{"pokemon": "雷吉铎拉戈V", "attack": "天之呐喊"},
	]


func _deck_setup_draw_attacks() -> Array:
	return [
		{"pokemon": "Regidrago V", "attack": "Celestial Roar"},
		{"pokemon": "雷吉铎拉戈V", "attack": "天之呐喊"},
	]


func _deck_evolution_lines() -> Array:
	return [
		{"basic": "Regidrago V", "stages": ["Regidrago VSTAR"], "role": "primary_attacker", "desired_count": 2, "energy": {"G": 2, "R": 1}},
		{"basic": "雷吉铎拉戈V", "stages": ["雷吉铎拉戈VSTAR"], "role": "primary_attacker", "desired_count": 2, "energy": {"G": 2, "R": 1}},
	]


func _deck_energy_needs() -> Dictionary:
	return {
		"Regidrago V": {"G": 2, "R": 1},
		"Regidrago VSTAR": {"G": 2, "R": 1},
		"Teal Mask Ogerpon ex": {"G": 1},
		"雷吉铎拉戈V": {"G": 2, "R": 1},
		"雷吉铎拉戈VSTAR": {"G": 2, "R": 1},
		"厄诡椪 碧草面具ex": {"G": 1},
	}


func _deck_route_terms() -> Array[String]:
	return [
		"巨龙无双", "碧草之舞", "能量转移", "高级球", "博士的研究",
		"热带狂热", "三重冰霜", "幻影潜袭", "迷失冲击", "天之呐喊",
		"基本草能量", "基本火能量",
	]


func _deck_core_plan() -> PackedStringArray:
	return PackedStringArray([
		"【核心计划】T1 铺两只 Regidrago V、两只 Teal Mask Ogerpon ex 和 Squawkabilly ex，利用 Ogerpon 贴草抽牌，再用 Energy Switch 把草能转给 Regidrago，让主攻手接近 GGR 费用。",
		"【T2 转化】优先进化 Regidrago VSTAR，并用 Ultra Ball / Research 等把 Dragapult ex、Giratina VSTAR、Hisuian Goodra VSTAR、Alolan Exeggutor ex 或 Kyurem 等龙系燃料送进弃牌区。",
		"【攻击选择】Apex Dragon 复制弃牌区龙系招式。对展开型后场优先复制 Dragapult ex 的 Phantom Dive；需要高单点时用 Giratina VSTAR；需要特殊局面时选择 Goodra/Exeggutor/Kyurem。",
		"【资源原则】龙系燃料在手里通常是弃牌资源，不要用 Nest Ball 把它们放到后场；Super Rod/Night Stretcher 不要把唯一 Dragapult ex 等关键燃料洗回去，除非是救命续航。",
		"【撤退原则】已经带攻击能量的 Regidrago 路线所有者不能随便付能撤退到支援位；只有能交接给已就绪攻击手时才换位。",
	])
