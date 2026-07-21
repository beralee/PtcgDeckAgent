class_name DeckStrategyV18ProfileCatalog
extends RefCounted

const PROFILE_VERSION := 14

const STRONG_ORDER_HINTS := {
	18000230: {
		"opening_cards": [
			"CSV8C_157", "CSV8C_157", "151C_004", "CSV5C_015",
			"CSVH1C_045", "CSVE1C_FIR", "CSV1C_127",
		],
		"bridge_cards": [
			"CSV8C_159", "CSV5C_075", "CSV8C_158",
			"CSVH1C_045", "CSV1C_127", "CSV1C_127",
		],
	},
	800015934: {
		"opening_cards": [
			"CSV9C_175", "CSV9C_161", "CSV9C_154", "CSV9.5C_141",
			"Grass Energy", "Water Energy", "CSV9C_155",
		],
		"bridge_cards": [
			"CSV9C_155", "Grass Energy", "Professor Turo's Scenario",
			"Energy Switch", "Nest Ball", "Earthen Vessel",
		],
	},
	800017407: {
		"opening_cards": [
			"CSV10C_218", "CSV10C_161", "CSV10C_201", "CSV10C_201",
			"CSVE1C_DAR", "CSV4C_129", "CSV10C_175",
		],
		"bridge_cards": [
			"CSV10C_161", "CSV8C_094", "CSVE1C_DAR",
			"CSV10C_195", "CSV10C_175", "CSVE1C_DAR",
		],
	},
	800017643: {
		"opening_cards": [
			"CSV9C_153", "CSV9C_161", "CSV9C_154", "CSV9.5C_141",
			"Fire Energy", "Water Energy", "CSV9.5C_023",
		],
		"bridge_cards": [
			"CSV9C_155", "Fire Energy", "Switch",
			"Kieran", "Nest Ball", "Water Energy",
		],
	},
	800017097: {
		"opening_cards": [
			"Ralts", "Munkidori", "Scream Tail", "Gardevoir ex",
			"Rare Candy", "Psychic Energy", "Psychic Energy",
		],
		"bridge_cards": [
			"Bravery Charm", "Psychic Energy", "Artazon",
			"Night Stretcher", "Munkidori", "Psychic Energy",
		],
	},
	800018105: {
		"opening_cards": [
			"Ralts", "Munkidori", "Scream Tail", "Gardevoir ex",
			"Rare Candy", "Psychic Energy", "Psychic Energy",
		],
		"bridge_cards": [
			"Bravery Charm", "Psychic Energy", "Artazon",
			"Night Stretcher", "Munkidori", "Psychic Energy",
		],
	},
	800018497: {
		"opening_cards": [
			"Ralts", "Munkidori", "Scream Tail", "Gardevoir ex",
			"Rare Candy", "Psychic Energy", "Psychic Energy",
		],
		"bridge_cards": [
			"Bravery Charm", "Psychic Energy", "Artazon",
			"Night Stretcher", "Munkidori", "Psychic Energy",
		],
	},
	800018498: {
		"opening_cards": [
			"Ralts", "Munkidori", "Scream Tail", "Gardevoir ex",
			"Rare Candy", "Psychic Energy", "Psychic Energy",
		],
		"bridge_cards": [
			"Bravery Charm", "Psychic Energy", "Artazon",
			"Night Stretcher", "Munkidori", "Psychic Energy",
		],
	},
	800033475: {
		"opening_cards": [
			"含羞苞", "蜻蜻蜓", "友好宝芬", "招式学习器 进化",
			"基本草能量", "基本草能量", "高级球",
		],
		"bridge_cards": [
			"远古巨蜓ex", "远古巨蜓ex", "基本草能量",
			"巢穴球", "远古巨蜓ex", "基本草能量",
		],
	},
	800018539: {
		"opening_cards": [
			"梦幻ex", "阿响的凤王ex", "炭小侍", "大地容器",
			"基本火能量", "基本火能量", "巢穴球",
		],
		"bridge_cards": [
			"红莲铠骑", "红莲铠骑", "基本火能量",
			"基本火能量", "宝可梦交替", "能量回收",
		],
	},
	800018509: {
		"opening_cards": [
			"猛雷鼓ex", "厄诡椪 碧草面具ex", "咕咕", "基本草能量",
			"基本斗能量", "基本雷能量", "奥琳博士的气魄",
		],
		"bridge_cards": [
			"猫头夜鹰", "猛雷鼓ex", "奥琳博士的气魄",
			"大地容器", "基本斗能量", "基本雷能量",
		],
	},
	800018543: {
		"opening_cards": [
			"CSV9.5C_004", "CSV10C_111", "CSV7C_177", "CSV5C_119",
			"CSVE1C_FIG", "CSVE1C_FIG", "CSV10C_004",
		],
		"bridge_cards": [
			"CSV10C_113", "CSV10C_112", "CSVE1C_FIG",
			"CSV10C_005", "CSV10C_200", "CSVE1C_FIG",
		],
	},
	800018880: {
		"opening_cards": [
			"CSV10C_028", "CSV1C_123", "CSV7C_177", "CSV1C_112",
			"CSVE1C_FIR", "CSVE1C_FIR", "CSV9C_023",
		],
		"bridge_cards": [
			"151C_016", "CSV10C_030", "CSVE1C_FIR",
			"CSV7C_177", "CSV10C_030", "CSVE1C_FIR",
		],
	},
}

const DRAGAPULT_CHARIZARD := "res://scripts/ai/DeckStrategyDragapultCharizard.gd"
const DRAGAPULT_DUSKNOIR := "res://scripts/ai/DeckStrategyDragapultDusknoir.gd"
const PURE_DRAGAPULT := "res://scripts/ai/DeckStrategy175PureDragapult.gd"
const GARDEVOIR := "res://scripts/ai/DeckStrategyGardevoir.gd"
const RAGING_BOLT := "res://scripts/ai/DeckStrategyRagingBoltOgerpon.gd"
const NS_ZOROARK := "res://scripts/ai/DeckStrategyNsZoroark.gd"
const GHOLDENGO := "res://scripts/ai/DeckStrategyV18Gholdengo.gd"
const YANMEGA := "res://scripts/ai/DeckStrategyV18Yanmega.gd"
const ETHANS_HO_OH := "res://scripts/ai/DeckStrategyV18EthanHoOh.gd"
const STAGE2_CORE := "res://scripts/ai/DeckStrategyV18Stage2Core.gd"
const TERAPAGOS_NOCTOWL := "res://scripts/ai/DeckStrategy17WaterTurtle.gd"
const BLAZIKEN_DRAGAPULT_FAMILY := "res://scripts/ai/DeckStrategyV18BlazikenDragapult.gd"
const CONTROL_GRASS_FAMILY := "res://scripts/ai/DeckStrategyV18ControlGrass.gd"
const DARK_CHARACTER_FAMILY := "res://scripts/ai/DeckStrategyV18DarkCharacterFamily.gd"
const DRAGAPULT_FAMILY := "res://scripts/ai/DeckStrategyV18DragapultFamily.gd"
const GARDEVOIR_FAMILY := "res://scripts/ai/DeckStrategyV18GardevoirFamily.gd"
const GARDEVOIR_VARIANTS_FAMILY := "res://scripts/ai/DeckStrategyV18GardevoirVariants.gd"
const HOP_FROSLASS_FAMILY := "res://scripts/ai/DeckStrategyV18HopFroslass.gd"
const MARNIE_CYNTHIA_FAMILY := "res://scripts/ai/DeckStrategyV18MarnieCynthia.gd"
const PARTNER_FAMILIES := "res://scripts/ai/DeckStrategyV18PartnerFamilies.gd"
const PIDGEOT_ACADEMY_FAMILY := "res://scripts/ai/DeckStrategyV18PidgeotAcademy.gd"
const TERA_NOCTOWL_FAMILY := "res://scripts/ai/DeckStrategyV18TeraNoctowl.gd"

const FAMILY_DELEGATE_OVERRIDES := {
	18000625: BLAZIKEN_DRAGAPULT_FAMILY,
	800015734: DRAGAPULT_FAMILY,
	800015934: TERA_NOCTOWL_FAMILY,
	800017097: GARDEVOIR_VARIANTS_FAMILY,
	800017407: HOP_FROSLASS_FAMILY,
	800017631: HOP_FROSLASS_FAMILY,
	800017643: TERA_NOCTOWL_FAMILY,
	800018105: GARDEVOIR_VARIANTS_FAMILY,
	800018359: PIDGEOT_ACADEMY_FAMILY,
	800018498: PIDGEOT_ACADEMY_FAMILY,
	800018500: CONTROL_GRASS_FAMILY,
	800018501: MARNIE_CYNTHIA_FAMILY,
	800018543: MARNIE_CYNTHIA_FAMILY,
	800018880: PARTNER_FAMILIES,
	800019125: DRAGAPULT_FAMILY,
}


static func all_profiles() -> Array[Dictionary]:
	return [
		_profile(18000230, "18.0 喷火龙多龙巴鲁托", "dragapult_charizard", "双二阶压制",
			["多龙巴鲁托ex", "喷火龙ex"], ["含羞苞", "多龙梅西亚", "小火龙", "古玉鱼"],
			["多龙梅西亚", "小火龙", "愿增猿", "吉雉鸡ex", "摔角鹰人"],
			["多龙巴鲁托ex", "喷火龙ex", "古玉鱼"], ["多龙巴鲁托ex", "喷火龙ex", "多龙奇", "火恐龙"],
			["多龙巴鲁托ex", "喷火龙ex", "多龙奇", "小火龙"], ["喷火龙ex", "多龙奇", "愿增猿"],
			["友好宝芬", "高级球", "神奇糖果", "派帕", "招式学习器 进化", "大地容器"], DRAGAPULT_CHARIZARD),
		_profile(18000625, "18.0 愿增猿火焰鸡", "munkidori_blaziken", "伤害搬运与能量循环",
			["火焰鸡ex", "愿增猿"], ["含羞苞", "火稚鸡", "谜拟丘", "谢米"],
			["火稚鸡", "愿增猿", "桃歹郎", "吉雉鸡ex"],
			["火焰鸡ex", "愿增猿", "火焰鸡"], ["火焰鸡ex", "力壮鸡", "火焰鸡"],
			["火焰鸡ex", "愿增猿", "桃歹郎"], ["火焰鸡ex", "愿增猿", "吉雉鸡ex"],
			["高级球", "招式学习器 进化", "派帕", "大地容器", "夜间担架", "深钵镇"], STAGE2_CORE),
		_profile(800015734, "18.0 自爆多龙巴鲁托", "dusknoir_dragapult", "伤害指示物精确收割",
			["多龙巴鲁托ex", "黑夜魔灵"], ["含羞苞", "多龙梅西亚", "夜巡灵", "洛托姆V"],
			["多龙梅西亚", "夜巡灵", "洛托姆V", "吉雉鸡ex", "光辉胡地"],
			["多龙巴鲁托ex", "黑夜魔灵"], ["多龙巴鲁托ex", "黑夜魔灵", "多龙奇", "彷徨夜灵"],
			["多龙巴鲁托ex", "黑夜魔灵", "多龙奇"], ["黑夜魔灵", "多龙奇", "洛托姆V"],
			["友好宝芬", "高级球", "神奇糖果", "派帕", "璀璨结晶", "大地容器"], DRAGAPULT_DUSKNOIR),
		_profile(800015934, "18.0 Tord太晶盒", "tord_tera_box", "太晶多属性工具箱",
			["太乐巴戈斯ex", "厄诡椪 水井面具ex", "皮卡丘ex"], ["旋转洛托姆", "咕咕", "百变怪", "梦幻ex"],
			["咕咕", "旋转洛托姆", "厄诡椪 碧草面具ex", "太乐巴戈斯ex", "拉帝亚斯ex"],
			["太乐巴戈斯ex", "厄诡椪 水井面具ex", "皮卡丘ex", "月月熊 赫月ex"], ["猫头夜鹰"],
			["猫头夜鹰", "太乐巴戈斯ex", "厄诡椪 水井面具ex"], ["猫头夜鹰", "厄诡椪 碧草面具ex", "旋转洛托姆"],
			["零之大空洞", "赤松", "巢穴球", "Energy Switch", "大地容器", "Professor Turo's Scenario"], TERAPAGOS_NOCTOWL),
		_profile(800016834, "18.0 纯赛富豪", "pure_gholdengo", "能量爆发与资源回收",
			["赛富豪ex", "索财灵"], ["索财灵", "铁包袱", "愿增猿"],
			["索财灵", "赛富豪ex", "吉雉鸡ex", "愿增猿"],
			["赛富豪ex"], ["赛富豪ex", "赛富豪"], ["赛富豪ex", "赛富豪", "索财灵"],
			["赛富豪ex", "吉雉鸡ex", "愿增猿"],
			["超级能量回收", "友好宝芬", "高级球", "暗码迷的解读", "招式学习器 进化", "大地容器"], GHOLDENGO),
		_profile(800017047, "18.0 象牙猪火焰鸡", "mamoswine_blaziken", "多进化链能量加速",
			["象牙猪ex", "火焰鸡ex", "大比鸟ex"], ["小山猪", "火稚鸡", "波波"],
			["小山猪", "火稚鸡", "波波", "吉雉鸡ex"],
			["象牙猪ex", "火焰鸡ex", "伦琴猫"], ["象牙猪ex", "火焰鸡ex", "大比鸟ex", "长毛猪", "力壮鸡", "比比鸟"],
			["象牙猪ex", "火焰鸡ex", "大比鸟ex"], ["火焰鸡ex", "大比鸟ex"],
			["神奇糖果", "友好宝芬", "高级球", "派帕", "招式学习器 进化", "大地容器"], STAGE2_CORE),
		_profile(800017097, "18.0 无碟沙奈朵", "no_balloon_gardevoir", "精神拥抱伤害搬运",
			["沙奈朵ex", "愿增猿"], ["含羞苞", "拉鲁拉丝", "皮宝宝"],
			["拉鲁拉丝", "愿增猿", "莉莉艾的皮皮ex", "吉雉鸡ex"],
			["沙奈朵ex", "吼叫尾", "莉莉艾的皮皮ex"], ["沙奈朵ex", "奇鲁莉安"],
			["沙奈朵ex", "奇鲁莉安", "愿增猿"], ["沙奈朵ex", "奇鲁莉安", "愿增猿"],
			["高级球", "大地容器", "巢穴球", "神奇糖果", "夜间担架", "深钵镇"], GARDEVOIR),
		_profile(800017407, "18.0 赫普苍响", "hops_zacian", "道具强化单回合爆发",
			["赫普的苍响ex", "赫普的卡比兽", "赫普的古月鸟"], ["赫普的古月鸟", "赫普的卡比兽", "梦幻ex"],
			["赫普的苍响ex", "赫普的卡比兽", "愿增猿", "拉帝亚斯ex"],
			["赫普的苍响ex", "赫普的卡比兽", "月月熊 赫月ex"], ["赫普的苍响ex"],
			["赫普的苍响ex", "赫普的卡比兽", "赫普的古月鸟"], ["愿增猿", "吉雉鸡ex"],
			["赫普的包包", "赫普的讲究头带", "巢穴球", "大地容器", "派帕", "化朗镇"]),
		_profile(800017631, "18.0 雪妖女愿增猿", "froslass_munkidori", "特性伤害累积控制",
			["含羞苞", "愿增猿", "月月熊 赫月ex"], ["含羞苞", "雪童子", "愿增猿"],
			["雪童子", "愿增猿", "含羞苞", "月月熊 赫月ex"],
			["愿增猿", "月月熊 赫月ex", "沙铃仙人掌"], ["雪妖女"],
			["雪妖女", "愿增猿", "月月熊 赫月ex"], ["雪妖女", "愿增猿"],
			["友好宝芬", "夜间担架", "反击捕捉器", "招式学习器 进化", "大地容器", "深钵镇"]),
		_profile(800017643, "18.0 火伊布猫头夜鹰", "flareon_noctowl", "太晶伊布多属性工具箱",
			["火伊布ex", "仙子伊布ex", "厄诡椪 水井面具ex"], ["旋转洛托姆", "咕咕", "伊布"],
			["咕咕", "伊布", "旋转洛托姆", "拉帝亚斯ex"],
			["火伊布ex", "仙子伊布ex", "叶伊布ex", "厄诡椪 水井面具ex"], ["猫头夜鹰", "火伊布ex", "仙子伊布ex", "叶伊布ex"],
			["猫头夜鹰", "火伊布ex", "仙子伊布ex"], ["猫头夜鹰", "旋转洛托姆"],
			["零之大空洞", "赤松", "太晶珠", "巢穴球", "Switch", "友好宝芬"]),
		_profile(800018105, "18.0 虫甲圣沙奈朵", "rabsca_gardevoir", "精神拥抱与备战保护",
			["沙奈朵ex", "愿增猿"], ["含羞苞", "拉鲁拉丝", "虫滚泥"],
			["拉鲁拉丝", "虫滚泥", "愿增猿", "梦幻ex"],
			["沙奈朵ex", "飘飘球", "吼叫尾"], ["沙奈朵ex", "奇鲁莉安", "虫甲圣"],
			["沙奈朵ex", "奇鲁莉安", "虫甲圣"], ["沙奈朵ex", "奇鲁莉安", "愿增猿", "虫甲圣"],
			["高级球", "大地容器", "招式学习器 进化", "巢穴球", "神奇糖果", "深钵镇"], GARDEVOIR),
		_profile(800018359, "18.0 大比鸟控制", "pidgeot_control", "资源封锁与循环",
			["大比鸟ex", "盐石巨灵", "美纳斯"], ["含羞苞", "波波", "盐石宝", "皮宝宝"],
			["波波", "盐石宝", "丑丑鱼", "盖诺赛克特", "拉帝亚斯ex"],
			["盐石巨灵", "大比鸟ex", "爆焰龟兽", "月月熊 赫月ex"], ["大比鸟ex", "盐石巨灵", "美纳斯", "比比鸟"],
			["大比鸟ex", "盐石巨灵", "美纳斯"], ["大比鸟ex", "盐石巨灵"],
			["神奇糖果", "派帕", "小刚的发掘", "朋友手册", "反击捕捉器", "调换票"], STAGE2_CORE),
		_profile(800018497, "18.0 沙奈朵", "gardevoir", "精神拥抱主轴",
			["沙奈朵ex", "愿增猿"], ["拉鲁拉丝", "梦幻ex"],
			["拉鲁拉丝", "愿增猿", "莉莉艾的皮皮ex", "吉雉鸡ex"],
			["沙奈朵ex", "吼叫尾", "莉莉艾的皮皮ex"], ["沙奈朵ex", "奇鲁莉安"],
			["沙奈朵ex", "奇鲁莉安", "愿增猿"], ["沙奈朵ex", "奇鲁莉安", "愿增猿"],
			["高级球", "大地容器", "巢穴球", "神奇糖果", "夜间担架", "招式学习器 进化"], GARDEVOIR),
		_profile(800018498, "18.0 学院沙奈朵", "academy_gardevoir", "学院节奏精神拥抱",
			["沙奈朵ex", "愿增猿"], ["含羞苞", "拉鲁拉丝", "谢米"],
			["拉鲁拉丝", "愿增猿", "莉莉艾的皮皮ex", "吉雉鸡ex"],
			["沙奈朵ex", "飘飘球", "吼叫尾"], ["沙奈朵ex", "奇鲁莉安"],
			["沙奈朵ex", "奇鲁莉安", "愿增猿"], ["沙奈朵ex", "奇鲁莉安", "愿增猿"],
			["高级球", "大地容器", "招式学习器 进化", "巢穴球", "夜间担架", "深钵镇"], GARDEVOIR),
		_profile(800018499, "18.0 多龙巴鲁托", "pure_dragapult", "幻影潜袭铺伤",
			["多龙巴鲁托ex"], ["含羞苞", "多龙梅西亚", "沙铃仙人掌"],
			["多龙梅西亚", "愿增猿", "拉帝亚斯ex", "吉雉鸡ex"],
			["多龙巴鲁托ex", "月月熊 赫月ex"], ["多龙巴鲁托ex", "多龙奇"],
			["多龙巴鲁托ex", "多龙奇", "愿增猿"], ["多龙奇", "愿增猿", "吉雉鸡ex"],
			["友好宝芬", "高级球", "小刚的发掘", "反击捕捉器", "夜间担架", "阻碍之塔"], PURE_DRAGAPULT),
		_profile(800018500, "18.0 陆地水母厄诡椪", "toedscruel_ogerpon", "草能量横向展开",
			["陆地水母ex", "厄诡椪 碧草面具ex"], ["原野水母", "厄诡椪 碧草面具ex", "梦幻ex"],
			["原野水母", "厄诡椪 碧草面具ex", "铁斑叶ex", "拉帝亚斯ex"],
			["陆地水母ex", "厄诡椪 碧草面具ex", "铁斑叶ex"], ["陆地水母ex", "陆地水母"],
			["陆地水母ex", "厄诡椪 碧草面具ex", "铁斑叶ex"], ["厄诡椪 碧草面具ex", "陆地水母ex"],
			["捕虫套装", "巢穴球", "能量转移", "高级球", "零之大空洞", "厉害钓竿"]),
		_profile(800018501, "18.0 玛俐的长毛巨魔", "marnies_grimmsnarl", "恶能量加速与特性铺伤",
			["玛俐的长毛巨魔ex", "愿增猿"], ["含羞苞", "玛俐的捣蛋小妖", "雪童子"],
			["玛俐的捣蛋小妖", "雪童子", "愿增猿", "谢米"],
			["玛俐的长毛巨魔ex", "愿增猿"], ["玛俐的长毛巨魔ex", "玛俐的诈唬魔", "雪妖女"],
			["玛俐的长毛巨魔ex", "玛俐的诈唬魔", "雪妖女"], ["玛俐的长毛巨魔ex", "雪妖女", "愿增猿"],
			["友好宝芬", "神奇糖果", "巢穴球", "招式学习器 进化", "尖钉镇道馆", "能量输送"], STAGE2_CORE),
		_profile(800018502, "18.0 N的索罗亚克", "ns_zoroark", "暗夜小丑招式工具箱",
			["N的索罗亚克ex", "N的莱希拉姆"], ["皮宝宝", "N的索罗亚", "N的火红不倒翁"],
			["N的索罗亚", "N的莱希拉姆", "愿增猿", "吉雉鸡ex"],
			["N的索罗亚克ex", "N的莱希拉姆", "月月熊 赫月ex"], ["N的索罗亚克ex", "N的达摩狒狒"],
			["N的索罗亚克ex", "N的莱希拉姆", "N的达摩狒狒"], ["N的索罗亚克ex", "愿增猿", "吉雉鸡ex"],
			["友好宝芬", "N的PP提升剂", "夜间担架", "能量转移", "秘密箱", "N的城堡"], NS_ZOROARK),
		_profile(800018509, "18.0 猛雷鼓厄诡椪", "raging_bolt_ogerpon", "能量丢弃一击收割",
			["猛雷鼓ex", "厄诡椪 碧草面具ex"], ["旋转洛托姆", "咕咕", "百变怪"],
			["咕咕", "厄诡椪 碧草面具ex", "猛雷鼓ex", "旋转洛托姆", "拉帝亚斯ex"],
			["猛雷鼓ex", "厄诡椪 碧草面具ex", "月月熊 赫月ex"], ["猫头夜鹰"],
			["猫头夜鹰", "猛雷鼓ex", "厄诡椪 碧草面具ex"], ["猫头夜鹰", "厄诡椪 碧草面具ex", "旋转洛托姆"],
			["大地容器", "奥琳博士的气魄", "CSV9C_196", "巢穴球", "高级球", "零之大空洞", "夜间担架"], RAGING_BOLT),
		_profile(800018539, "18.0 阿响凤王", "ethans_ho_oh", "火能量加速工具箱",
			["阿响的凤王ex", "厄诡椪 火灶面具ex", "铁臂膀ex"], ["炭小侍", "梦幻ex", "怒鹦哥ex"],
			["炭小侍", "阿响的凤王ex", "愿增猿", "拉帝亚斯ex"],
			["阿响的凤王ex", "厄诡椪 火灶面具ex", "铁臂膀ex", "月月熊 赫月ex"], ["红莲铠骑"],
			["阿响的凤王ex", "红莲铠骑", "铁臂膀ex"], ["阿响的凤王ex", "红莲铠骑", "愿增猿"],
			["巢穴球", "高级球", "大地容器", "能量回收", "零之大空洞", "夜间担架"], ETHANS_HO_OH),
		_profile(800018543, "18.0 竹兰烈咬陆鲨", "cynthias_garchomp", "竹兰联动连续进攻",
			["竹兰的烈咬陆鲨ex", "竹兰的花岩怪"], ["含羞苞", "竹兰的圆陆鲨", "竹兰的花岩怪"],
			["竹兰的圆陆鲨", "竹兰的毒蔷薇", "愿增猿"],
			["竹兰的烈咬陆鲨ex", "竹兰的罗丝雷朵"], ["竹兰的烈咬陆鲨ex", "竹兰的尖牙陆鲨", "竹兰的罗丝雷朵"],
			["竹兰的烈咬陆鲨ex", "竹兰的罗丝雷朵", "竹兰的尖牙陆鲨"], ["竹兰的烈咬陆鲨ex", "竹兰的罗丝雷朵", "愿增猿"],
			["友好宝芬", "竹兰的力量负重", "招式学习器 进化", "大地容器", "夜间担架", "火箭队的监视塔"], STAGE2_CORE),
		_profile(800018880, "18.0 阿响火暴兽", "ethans_typhlosion", "阿响牌库循环爆发",
			["阿响的火暴兽", "大比鸟ex"], ["阿响的火球鼠", "波波"],
			["阿响的火球鼠", "波波", "比克提尼", "吉雉鸡ex"],
			["阿响的火暴兽", "比克提尼"], ["阿响的火暴兽", "大比鸟ex", "阿响的火岩鼠", "比比鸟"],
			["阿响的火暴兽", "大比鸟ex", "阿响的火岩鼠"], ["大比鸟ex", "阿响的火暴兽"],
			["友好宝芬", "高级球", "阿响的冒险", "派帕", "招式学习器 进化", "神奇糖果"], STAGE2_CORE),
		_profile(800019125, "18.0 火焰鸡多龙巴鲁托", "blaziken_dragapult", "火焰鸡加速多龙",
			["多龙巴鲁托ex", "火焰鸡ex"], ["含羞苞", "多龙梅西亚", "火稚鸡"],
			["多龙梅西亚", "火稚鸡", "愿增猿", "吉雉鸡ex"],
			["多龙巴鲁托ex", "火焰鸡ex", "古玉鱼"], ["多龙巴鲁托ex", "火焰鸡ex", "多龙奇", "力壮鸡"],
			["多龙巴鲁托ex", "火焰鸡ex", "多龙奇"], ["火焰鸡ex", "多龙奇", "愿增猿"],
			["高级球", "友好宝芬", "神奇糖果", "派帕", "大地容器", "招式学习器 进化"], PURE_DRAGAPULT),
		_profile(800033475, "18.0 远古巨蜓", "yanmega_dudunsparce", "零撤退连击与循环抽牌",
			["远古巨蜓ex", "土龙节节ex"], ["含羞苞", "蜻蜻蜓", "土龙弟弟", "石居蟹"],
			["蜻蜻蜓", "土龙弟弟", "石居蟹", "米立龙"],
			["远古巨蜓ex", "土龙节节ex", "岩殿居蟹"], ["远古巨蜓ex", "土龙节节", "土龙节节ex", "岩殿居蟹"],
			["远古巨蜓ex", "土龙节节", "土龙节节ex"], ["土龙节节", "土龙节节ex"],
			["友好宝芬", "高级球", "巢穴球", "厉害钓竿", "招式学习器 进化", "夜间担架"], YANMEGA),
	]


static func get_profile_for_deck(deck_id: int) -> Dictionary:
	for profile: Dictionary in all_profiles():
		if int(profile.get("deck_id", 0)) == deck_id:
			return profile.duplicate(true)
	return {}


static func get_profile_for_strategy(strategy_id: String) -> Dictionary:
	for profile: Dictionary in all_profiles():
		if str(profile.get("strategy_id", "")) == strategy_id:
			return profile.duplicate(true)
	return {}


static func strategy_id_for_deck(deck_id: int) -> String:
	return str(get_profile_for_deck(deck_id).get("strategy_id", ""))


static func has_strategy_id(strategy_id: String) -> bool:
	return not get_profile_for_strategy(strategy_id).is_empty()


static func deck_ids() -> Array[int]:
	var result: Array[int] = []
	for profile: Dictionary in all_profiles():
		result.append(int(profile.get("deck_id", 0)))
	return result


static func _profile(
	deck_id: int,
	deck_name: String,
	slug: String,
	archetype: String,
	signatures: Array[String],
	opening_active: Array[String],
	bench_priority: Array[String],
	energy_priority: Array[String],
	evolution_priority: Array[String],
	search_priority: Array[String],
	ability_priority: Array[String],
	trainer_priority: Array[String],
	delegate_script_path: String = ""
) -> Dictionary:
	var result := {
		"profile_version": PROFILE_VERSION,
		"deck_id": deck_id,
		"deck_name": deck_name,
		"strategy_id": "v18_%d_%s" % [deck_id, slug],
		"archetype": archetype,
		"signatures": signatures,
		"active_priority": opening_active,
		"opening_active": opening_active,
		"bench_priority": bench_priority,
		"energy_priority": energy_priority,
		"evolution_priority": evolution_priority,
		"search_priority": search_priority,
		"ability_priority": ability_priority,
		"trainer_priority": trainer_priority,
		"delegate_script_path": str(FAMILY_DELEGATE_OVERRIDES.get(deck_id, delegate_script_path)),
		"continuity": {
			"setup_floor": 2,
			"deck_churn_floor": 8,
			"preserve_route_owner": true,
		},
	}
	if STRONG_ORDER_HINTS.has(deck_id):
		result["strong_order"] = (STRONG_ORDER_HINTS[deck_id] as Dictionary).duplicate(true)
	return result
