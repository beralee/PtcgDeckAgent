extends RefCounted
## Presentation-only direction. Names/legality still belong to the card catalog.
const PROFILES := {
	"iono":{"line":"聚光灯就位！","style":"broadcast","effect":"hand","hit":.94,"resolve":1.72,"duration":3.08},
	"arven":{"line":"准备好下一步","style":"search","effect":"search","hit":1.08,"resolve":1.82,"duration":3.10},
	"research":{"line":"让研究继续前进","style":"data","effect":"hand","hit":1.04,"resolve":1.76,"duration":3.08},
	"turo":{"line":"将可能性带回未来","style":"temporal","effect":"return","hit":1.12,"resolve":1.88,"duration":3.22},
	"cipher":{"line":"答案已经揭晓","style":"code","effect":"search","hit":1.10,"resolve":1.85,"duration":3.14},
	"crispin":{"line":"火候，恰到好处！","style":"flame","effect":"energy","hit":.96,"resolve":1.72,"duration":3.02},
	"briar":{"line":"照亮晶辉的可能","style":"crystal","effect":"boost","hit":1.13,"resolve":1.88,"duration":3.24},
	"carmine":{"line":"现在，轮到我了！","style":"fan","effect":"hand","hit":.92,"resolve":1.66,"duration":2.96},
	"sada":{"line":"唤醒远古的力量","style":"primal","effect":"energy","hit":1.02,"resolve":1.78,"duration":3.15},
	"blackbelt":{"line":"全力，突破！","style":"impact","effect":"boost","hit":.90,"resolve":1.66,"duration":2.94},
	"cilan":{"line":"发现新的可能","style":"search","effect":"search","hit":1.12,"resolve":1.86,"duration":3.14},
	"kieran":{"line":"这次，一定要赢！","style":"impact","effect":"boost","hit":.93,"resolve":1.70,"duration":3.02},
	"judge":{"line":"重新开始！","style":"whistle","effect":"hand","hit":.98,"resolve":1.72,"duration":3.00},
	"lana":{"line":"让伙伴回到身边","style":"wave","effect":"recover","hit":1.14,"resolve":1.90,"duration":3.26},
	"lillie":{"line":"我已经下定决心","style":"stars","effect":"hand","hit":1.12,"resolve":1.90,"duration":3.30},
	"brock":{"line":"寻找可靠的伙伴","style":"strata","effect":"search","hit":1.04,"resolve":1.80,"duration":3.10},
	"penny":{"line":"回来吧，有我在","style":"pixel","effect":"return","hit":1.09,"resolve":1.85,"duration":3.20},
}

static func profile(id: String) -> Dictionary:
	return PROFILES.get(id,{}).duplicate(true)

static func sheet_path(id: String) -> String:
	return "res://assets/arena3d/supporters/characters/%s.png" % id
