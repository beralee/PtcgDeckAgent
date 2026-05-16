extends "res://scripts/ai/DeckStrategy17LLMBase.gd"


func _llm_strategy_id() -> String:
	return "v17_bomb_charizard_llm"


func _rules_strategy_path() -> String:
	return "res://scripts/ai/DeckStrategy17BombCharizard.gd"


func _deck_display_name() -> String:
	return "17.0 自爆恶喷"


func _deck_primary_attackers() -> Array[String]:
	return ["Charizard ex", "喷火龙ex", "Charmander", "小火龙", "Radiant Charizard", "光辉喷火龙"]


func _deck_secondary_attackers() -> Array[String]:
	return ["Dusknoir", "黑夜魔灵", "Dusclops", "彷徨夜灵", "Bloodmoon Ursaluna ex"]


func _deck_support_pokemon() -> Array[String]:
	return ["Pidgeot ex", "大比鸟ex", "Pidgey", "波波", "Rotom V", "Lumineon V", "Fezandipiti ex", "Duskull", "夜巡灵", "Dusclops", "彷徨夜灵", "Dusknoir", "黑夜魔灵"]


func _deck_primary_attacks() -> Array:
	return [
		{"pokemon": "Charizard ex", "attack": "Burning Darkness"},
		{"pokemon": "喷火龙ex", "attack": "燃烧黑暗"},
		{"pokemon": "Radiant Charizard", "attack": "Combustion Blast"},
		{"pokemon": "光辉喷火龙", "attack": "燃烧爆破"},
	]


func _deck_low_value_attacks() -> Array:
	return [
		{"pokemon": "Pidgey", "attack": "起风"},
		{"pokemon": "夜巡灵", "attack": "喃喃自语"},
	]


func _deck_evolution_lines() -> Array:
	return [
		{"basic": "Charmander", "stages": ["Charmeleon", "Charizard ex"], "role": "primary_attacker", "desired_count": 2, "energy": {"R": 2}},
		{"basic": "Pidgey", "stages": ["Pidgeotto", "Pidgeot ex"], "role": "support", "desired_count": 1},
		{"basic": "Duskull", "stages": ["Dusclops", "Dusknoir"], "role": "prize_conversion", "desired_count": 1},
	]


func _deck_energy_needs() -> Dictionary:
	return {
		"Charmander": {"R": 2},
		"Charizard ex": {"R": 2},
		"Radiant Charizard": {"R": 1},
	}


func _deck_route_terms() -> Array[String]:
	return ["烈炎支配", "燃烧黑暗", "音速搜索", "咒怨炸弹", "神奇糖果", "派帕", "Arven", "反击捕捉器", "顶尖捕捉器", "基本火能量"]


func _deck_core_plan() -> PackedStringArray:
	return PackedStringArray([
		"【核心计划】先建立 Charmander 与 Pidgey 两条线，T2 通过 Rare Candy / Arven / Pidgeot ex 完成 Charizard ex 并开始连续进攻。",
		"【自爆路线】Dusknoir/Dusclops 只在能直接拿奖、补足 Charizard 斩杀线或改变奖赏 race 时使用；不要为了触发效果无意义送奖。",
		"【资源原则】Rare Candy、Charizard ex、Pidgeot ex、Arven 和关键火能是连续两轮进攻核心。若本回合已经能攻击拿奖，先搜索保护下回合续航，再攻击。",
		"【攻击前动作】Pidgeot ex 搜索、Charizard ex 加速、Boss/Counter Catcher、Dusknoir 斩杀与工具都应排在攻击前；Rotom V 终端抽牌只能在无其他有效路线时使用。",
	])
