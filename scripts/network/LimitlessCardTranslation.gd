class_name LimitlessCardTranslation
extends RefCounted

const Parser := preload("res://scripts/network/LimitlessCardParser.gd")

const TRANSLATIONS := {
	"SVI/85": {
		"name": "奇鲁莉安",
		"description": "魔法射击 30\n\n精神强念 60+\n造成对手的战斗宝可梦身上附加的能量数量x20点追加伤害。",
		"attacks": {
			"Magical Shot": {
				"name_zh": "魔法射击",
				"text_zh": "",
			},
			"Psychic": {
				"name_zh": "精神强念",
				"text_zh": "造成对手的战斗宝可梦身上附加的能量数量x20点追加伤害。",
			},
		},
	},
	"PRE/4": {
		"name": "含羞苞",
		"description": "刺痒花粉 10\n在对手的下个回合，对手不能从手牌打出物品卡。",
		"attacks": {
			"Itchy Pollen": {
				"name_zh": "刺痒花粉",
				"text_zh": "在对手的下个回合，对手不能从手牌打出物品卡。",
			},
		},
	},
	"PRE/77": {
		"name": "咕咕",
		"description": "特性: 不眠\n这只宝可梦不会陷入睡眠。\n\n撞击 20",
		"abilities": {
			"Insomnia": {
				"name_zh": "不眠",
				"text_zh": "这只宝可梦不会陷入睡眠。",
			},
		},
		"attacks": {
			"Tackle": {
				"name_zh": "撞击",
				"text_zh": "",
			},
		},
	},
	"SCR/114": {
		"name": "咕咕",
		"description": "三连刺 10x\n投掷3次硬币，造成正面次数x10点伤害。",
		"attacks": {
			"Triple Stab": {
				"name_zh": "三连刺",
				"text_zh": "投掷3次硬币，造成正面次数x10点伤害。",
			},
		},
	},
	"SCR/115": {
		"name": "猫头夜鹰",
		"description": "特性: 宝石搜寻者\n在自己的回合，当你从手牌将这只宝可梦放置到场上使自己的1只宝可梦进化时，若自己的场上有太晶宝可梦，可从自己的牌库选择最多2张训练家卡，给对手看后加入手牌。然后重洗牌库。\n\n高速翼击 60",
		"abilities": {
			"Jewel Seeker": {
				"name_zh": "宝石搜寻者",
				"text_zh": "在自己的回合，当你从手牌将这只宝可梦放置到场上使自己的1只宝可梦进化时，若自己的场上有太晶宝可梦，可从自己的牌库选择最多2张训练家卡，给对手看后加入手牌。然后重洗牌库。",
			},
		},
		"attacks": {
			"Speed Wing": {
				"name_zh": "高速翼击",
				"text_zh": "",
			},
		},
	},
	"SCR/118": {
		"name": "旋转洛托姆",
		"description": "特性: 风扇呼唤\n在自己的最初回合时可使用1次。从自己的牌库选择最多3张HP为100以下的无色宝可梦，给对手看后加入手牌。然后重洗牌库。在自己的回合，不能使用超过1次风扇呼唤特性。\n\n突击着陆 70\n若场上没有竞技场卡，这个招式不造成伤害。",
		"abilities": {
			"Fan Call": {
				"name_zh": "风扇呼唤",
				"text_zh": "在自己的最初回合时可使用1次。从自己的牌库选择最多3张HP为100以下的无色宝可梦，给对手看后加入手牌。然后重洗牌库。在自己的回合，不能使用超过1次风扇呼唤特性。",
			},
		},
		"attacks": {
			"Assault Landing": {
				"name_zh": "突击着陆",
				"text_zh": "若场上没有竞技场卡，这个招式不造成伤害。",
			},
		},
	},
	"SCR/131": {
		"name": "零之大空洞",
		"description": "自己的场上有太晶宝可梦的玩家，备战区上限变为8只。\n\n若某位玩家的场上不再有太晶宝可梦，那位玩家从自己的备战区丢弃宝可梦，直到剩下5只为止。当这张卡离开场上时，双方玩家从自己的备战区丢弃宝可梦，直到剩下5只为止，由打出这张卡的玩家先丢弃。",
	},
	"SCR/133": {
		"name": "赤松",
		"description": "从自己的牌库选择最多2张不同属性的基本能量卡，给对手看后，其中1张加入手牌，将另一张附于自己的1只宝可梦身上。然后重洗牌库。",
	},
	"SSP/76": {
		"name": "拉帝亚斯ex",
		"description": "特性: 空中航线\n自己的场上的基础宝可梦没有撤退费用。\n\n无限之刃 200\n在自己的下个回合，这只宝可梦不能使用招式。",
		"abilities": {
			"Skyliner": {
				"name_zh": "空中航线",
				"text_zh": "自己的场上的基础宝可梦没有撤退费用。",
			},
		},
		"attacks": {
			"Eon Blade": {
				"name_zh": "无限之刃",
				"text_zh": "在自己的下个回合，这只宝可梦不能使用招式。",
			},
		},
	},
	"SSP/170": {
		"name": "席蓝",
		"description": "从自己的牌库选择最多3张宝可梦ex，给对手看后加入手牌。然后重洗牌库。",
	},
	"DRI/10": {
		"name": "谢米",
		"description": "特性: 花幕\n防止对手的宝可梦使用招式对自己的备战区没有规则框的宝可梦造成的所有伤害。（宝可梦ex、宝可梦V等拥有规则框。）\n\n粉碎踢 30",
		"abilities": {
			"Flower Curtain": {
				"name_zh": "花幕",
				"text_zh": "防止对手的宝可梦使用招式对自己的备战区没有规则框的宝可梦造成的所有伤害。（宝可梦ex、宝可梦V等拥有规则框。）",
			},
		},
		"attacks": {
			"Smash Kick": {
				"name_zh": "粉碎踢",
				"text_zh": "",
			},
		},
	},
	"DRI/134": {
		"name": "玛俐的捣蛋小妖",
		"description": "顺手牵羊\n抽1张卡。\n\n螺旋拳 10",
		"attacks": {
			"Filch": {
				"name_zh": "顺手牵羊",
				"text_zh": "抽1张卡。",
			},
			"Corkscrew Punch": {
				"name_zh": "螺旋拳",
				"text_zh": "",
			},
		},
	},
	"DRI/135": {
		"name": "玛俐的诈唬魔",
		"description": "螺旋拳 60",
		"attacks": {
			"Corkscrew Punch": {
				"name_zh": "螺旋拳",
				"text_zh": "",
			},
		},
	},
	"DRI/136": {
		"name": "玛俐的长毛巨魔ex",
		"description": "特性: 朋克提升\n在自己的回合，当你从手牌将这只宝可梦放置到场上使自己的1只宝可梦进化时，可从自己的牌库选择最多5张基本恶能量卡，以任意方式附于自己的玛俐的宝可梦身上。然后重洗牌库。\n\n暗影子弹 180\n这个招式也对对手的1只备战宝可梦造成30点伤害。（备战宝可梦不计算弱点、抵抗力。）",
		"abilities": {
			"Punk Up": {
				"name_zh": "朋克提升",
				"text_zh": "在自己的回合，当你从手牌将这只宝可梦放置到场上使自己的1只宝可梦进化时，可从自己的牌库选择最多5张基本恶能量卡，以任意方式附于自己的玛俐的宝可梦身上。然后重洗牌库。",
			},
		},
		"attacks": {
			"Shadow Bullet": {
				"name_zh": "暗影子弹",
				"text_zh": "这个招式也对对手的1只备战宝可梦造成30点伤害。（备战宝可梦不计算弱点、抵抗力。）",
			},
		},
	},
	"DRI/169": {
		"name": "尖钉镇道馆",
		"description": "每位玩家在自己的回合时，可使用1次。从自己的牌库选择1张玛俐的宝可梦，给对手看后加入手牌。然后那位玩家重洗牌库。",
	},
	"JTG/8": {
		"name": "沙铃仙人掌",
		"description": "特性: 爆裂针刺\n若这只宝可梦在战斗场受到对手的宝可梦招式的伤害而被击倒，在攻击宝可梦身上放置6个伤害指示物。\n\n围困 20\n在对手的下个回合，防守宝可梦不能撤退。",
		"abilities": {
			"Exploding Needles": {
				"name_zh": "爆裂针刺",
				"text_zh": "若这只宝可梦在战斗场受到对手的宝可梦招式的伤害而被击倒，在攻击宝可梦身上放置6个伤害指示物。",
			},
		},
		"attacks": {
			"Corner": {
				"name_zh": "围困",
				"text_zh": "在对手的下个回合，防守宝可梦不能撤退。",
			},
		},
	},
	"JTG/26": {
		"name": "N的火红不倒翁",
		"description": "滚动撞击 20\n\n火花 50",
		"attacks": {
			"Rolling Tackle": {
				"name_zh": "滚动撞击",
				"text_zh": "",
			},
			"Flare": {
				"name_zh": "火花",
				"text_zh": "",
			},
		},
	},
	"JTG/27": {
		"name": "N的达摩狒狒",
		"description": "回火气流 30x\n造成对手弃牌区的基本能量卡数量x30点伤害。\n\n火焰体大炮 90\n丢弃这只宝可梦身上附加的所有能量，这个招式也对对手的1只备战宝可梦造成90点伤害。（备战宝可梦不计算弱点、抵抗力。）",
		"attacks": {
			"Back Draft": {
				"name_zh": "回火气流",
				"text_zh": "造成对手弃牌区的基本能量卡数量x30点伤害。",
			},
			"Flamebody Cannon": {
				"name_zh": "火焰体大炮",
				"text_zh": "丢弃这只宝可梦身上附加的所有能量，这个招式也对对手的1只备战宝可梦造成90点伤害。（备战宝可梦不计算弱点、抵抗力。）",
			},
		},
	},
	"JTG/56": {
		"name": "莉莉艾的皮皮ex",
		"description": "特性: 妖精地带\n对手场上的各龙属性宝可梦的弱点变为超属性。（弱点按x2计算。）\n\n满月轮舞曲 20+\n双方备战区的宝可梦每有1只，追加20点伤害。",
		"abilities": {
			"Fairy Zone": {
				"name_zh": "妖精地带",
				"text_zh": "对手场上的各龙属性宝可梦的弱点变为超属性。（弱点按x2计算。）",
			},
		},
		"attacks": {
			"Full Moon Rondo": {
				"name_zh": "满月轮舞曲",
				"text_zh": "双方备战区的宝可梦每有1只，追加20点伤害。",
			},
		},
	},
	"JTG/146": {
		"name": "小刚的侦察",
		"description": "从自己的牌库选择最多2张基础宝可梦或1张进化宝可梦，给对手看后加入手牌。然后重洗牌库。",
	},
	"JTG/152": {
		"name": "N的城堡",
		"description": "场上的N的宝可梦（双方玩家的）没有撤退费用。",
	},
	"JTG/97": {
		"name": "N的索罗亚",
		"description": "抓 20",
		"attacks": {
			"Scratch": {
				"name_zh": "抓",
				"text_zh": "",
			},
		},
	},
	"JTG/98": {
		"name": "N的索罗亚克ex",
		"description": "特性: 交易\n若要使用这个特性，必须从自己的手牌中丢弃1张卡。在自己的回合时可使用1次，抽2张卡。\n\n暗夜小丑\n选择自己备战区的1只N的宝可梦拥有的1个招式，作为这个招式使用。",
		"abilities": {
			"Trade": {
				"name_zh": "交易",
				"text_zh": "若要使用这个特性，必须从自己的手牌中丢弃1张卡。在自己的回合时可使用1次，抽2张卡。",
			},
		},
		"attacks": {
			"Night Joker": {
				"name_zh": "暗夜小丑",
				"text_zh": "选择自己备战区的1只N的宝可梦拥有的1个招式，作为这个招式使用。",
			},
		},
	},
	"JTG/116": {
		"name": "N的莱希拉姆",
		"description": "强力愤怒 20x\n造成这只宝可梦身上放置的伤害指示物的数量x20点伤害。\n\n高洁火焰 170",
		"attacks": {
			"Powerful Rage": {
				"name_zh": "强力愤怒",
				"text_zh": "造成这只宝可梦身上放置的伤害指示物的数量x20点伤害。",
			},
			"Virtuous Flame": {
				"name_zh": "高洁火焰",
				"text_zh": "",
			},
		},
	},
	"JTG/153": {
		"name": "N的PP提升",
		"description": "从自己的弃牌区选择1张基本能量卡，附于自己的1只备战区的N的宝可梦身上。",
	},
	"BLK/79": {
		"name": "气球",
		"description": "附有这张卡的宝可梦的撤退所需能量减少2个无色能量。",
	},
}


static func apply_to_generated_card(card: CardData) -> bool:
	if card == null:
		return false
	if str(card.source_provider).strip_edges().to_lower() != Parser.SOURCE_PROVIDER:
		return false
	var ref := Parser.card_ref_key(card.source_set_code, card.source_card_index)
	if not TRANSLATIONS.has(ref):
		return false
	var translation: Dictionary = TRANSLATIONS[ref]
	if str(translation.get("name", "")).strip_edges() != "":
		card.name_zh = str(translation.get("name", ""))
	if str(translation.get("description", "")).strip_edges() != "":
		card.description = str(translation.get("description", ""))
	_apply_dictionary_translations(card.abilities, translation.get("abilities", {}))
	_apply_dictionary_translations(card.attacks, translation.get("attacks", {}))
	return true


static func has_translation_for_ref(set_code: String, card_index: String) -> bool:
	return TRANSLATIONS.has(Parser.card_ref_key(set_code, card_index))


static func _apply_dictionary_translations(entries: Array[Dictionary], translation_map: Dictionary) -> void:
	if translation_map.is_empty():
		return
	for idx: int in entries.size():
		var entry := entries[idx].duplicate(true)
		var english_name := str(entry.get("name", "")).strip_edges()
		if not translation_map.has(english_name):
			continue
		var translation: Dictionary = translation_map[english_name]
		if translation.has("name_zh"):
			entry["name_zh"] = str(translation.get("name_zh", ""))
		if translation.has("text_zh"):
			entry["text_zh"] = str(translation.get("text_zh", ""))
		entries[idx] = entry
