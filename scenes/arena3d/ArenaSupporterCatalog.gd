extends RefCounted
## Authored presentation identities, not a legality or strategy registry.
## Sample printings document this version's G/H/I/J collection.
const ENTRIES := {
	"boss":{"name":"老大的指令","aliases":["老大的指令","Boss's Orders"],"printing":["CSVH1aC","023"],"color":"ff4969","accent":"ffbc80","motif":"锁定牵引"},
	"iono":{"name":"奇树","aliases":["奇树","Iono"],"printing":["CSV3C","123"],"color":"8e91ff","accent":"ff80d9","motif":"双极电磁"},
	"arven":{"name":"派帕","aliases":["派帕","Arven"],"printing":["CSV1C","123"],"color":"54d9ff","accent":"ffd18c","motif":"双轨搜寻"},
	"research":{"name":"博士的研究","aliases":["博士的研究","Professor's Research"],"printing":["CSV1C","121"],"color":"79ceff","accent":"e4f6ff","motif":"数据展开"},
	"turo":{"name":"弗图博士的剧本","aliases":["弗图博士的剧本","Professor Turo's Scenario"],"printing":["CSV6C","125"],"color":"a991ff","accent":"7ef4ff","motif":"时空回廊"},
	"cipher":{"name":"暗码迷的解读","aliases":["暗码迷的解读","Ciphermaniac's Codebreaking"],"printing":["CSV7C","191"],"color":"40edbf","accent":"cbffed","motif":"双重解码"},
	"crispin":{"name":"赤松","aliases":["赤松","Crispin"],"printing":["CSV9C","196"],"color":"ff994a","accent":"77dbff","motif":"能量熔炉"},
	"briar":{"name":"白蕾雅","aliases":["白蕾雅","Briar"],"printing":["CSV9C","202"],"color":"ff9ce8","accent":"9edcff","motif":"晶冠共鸣"},
	"carmine":{"name":"丹瑜","aliases":["丹瑜","Carmine"],"printing":["CSV8C","199"],"color":"ff5777","accent":"ffe0a7","motif":"朱红开幕"},
	"sada":{"name":"奥琳博士的气魄","aliases":["奥琳博士的气魄","Professor Sada's Vitality"],"printing":["CSV6C","121"],"color":"ffb756","accent":"ffedb8","motif":"古代苏醒"},
	"blackbelt":{"name":"空手道王的修炼","aliases":["空手道王的修炼","Black Belt's Training"],"printing":["CSV9.5C","188"],"color":"ff9d60","accent":"fff1d8","motif":"破空斗气"},
	"cilan":{"name":"席蓝","aliases":["席蓝","Cilan's Finesse"],"printing":["CSV9C","198"],"color":"7eafff","accent":"ffe8a5","motif":"礼帽邀约"},
	"kieran":{"name":"乌栗","aliases":["乌栗","Kieran"],"printing":["CSV8C","198"],"color":"c07bff","accent":"ff598c","motif":"逆风突进"},
	"judge":{"name":"裁判","aliases":["裁判","Judge"],"printing":["30thDC","037"],"color":"f2cc77","accent":"d3eaff","motif":"秩序天平"},
	"lana":{"name":"水莲的照顾","aliases":["水莲的照顾","Lana's Aid"],"printing":["CSV7C","193"],"color":"4cd4e5","accent":"c6faff","motif":"潮汐回响"},
	"lillie":{"name":"莉莉艾的决心","aliases":["莉莉艾的决心","Lillie's Determination"],"printing":["30thDC","040"],"color":"e5deff","accent":"ffe7a2","motif":"星愿绽放"},
	"brock":{"name":"小刚的发掘","aliases":["小刚的发掘","Brock's Scouting"],"printing":["30thDC","038"],"color":"d6af80","accent":"81e2df","motif":"地脉探寻"},
	"penny":{"name":"牡丹","aliases":["牡丹","Penny"],"printing":["CSV1C","124"],"color":"fb99d9","accent":"96c5ff","motif":"像素归航"},
}

static func identify(card: Dictionary) -> String:
	if not card.get("public",false) or card.get("concealed",true): return ""
	if card.get("card_type","") != "Supporter" or card.get("regulation","") not in ["G","H","I","J"]: return ""
	var names: Array = card.get("identities",[card.get("name","")])
	for id: String in ENTRIES:
		for alias: String in ENTRIES[id].aliases:
			for value: Variant in names:
				if str(value).strip_edges().to_lower() == alias.to_lower(): return id
	return ""
