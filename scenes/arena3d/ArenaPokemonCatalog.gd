extends RefCounted
## Presentation-only identities. Trainer ownership and Tera form stay explicit.
const ENTRIES := {
	"dragapult":{"name":"多龙巴鲁托 ex","en":"PHANTOM DIVE","aliases":["多龙巴鲁托ex","dragapultex"],"color":"65d9d0","detail":"幽灵悬浮 · 双龙出膛 · 幻影潜袭","joints":["Dreepy_L","Dreepy_R","Tail"]},
	"charizard":{"name":"喷火龙 ex","en":"BURNING DARKNESS","aliases":["喷火龙ex","charizardex"],"color":"ffac51","detail":"翼膜张力 · 暗晶王冠 · 炽焰吐息","joints":["Wing_L","Wing_R","Jaw","Flame"]},
	"munkidori":{"name":"愿增猿","en":"ADRENA-BRAIN","aliases":["愿增猿","munkidori"],"color":"d978e9","detail":"指尖念力 · 毒锁脉冲 · 伤害转移","joints":["Arm_L","Arm_R","Tail"]},
	"ceruledge":{"name":"苍炎刃鬼 ex","en":"ABYSSAL FLAMES","aliases":["苍炎刃鬼ex","ceruledgeex"],"color":"a996ff","detail":"幽焰双刃 · 交叉蓄势 · 突进回斩","joints":["Blade_L","Blade_R","Flame"]},
	"terapagos":{"name":"太乐巴戈斯 ex","en":"CROWN OPAL","aliases":["太乐巴戈斯ex","terapagosex"],"color":"73e7ff","detail":"星晶甲壳 · 环轨结晶 · 虹彩聚能","joints":["Shell","Orbit","Crown"]},
	"grimmsnarl":{"name":"玛俐的长毛巨魔 ex","en":"SHADOW BULLET","aliases":["玛俐的长毛巨魔ex","marnie'sgrimmsnarlex","marnie’sgrimmsnarlex"],"color":"c481ed","detail":"发束肌肉 · 重拳扭腰 · 暗影脉冲","joints":["Hair_L","Hair_R","Arm_R"]},
	"zoroark":{"name":"N 的索罗亚克 ex","en":"NIGHT JOKER","aliases":["n的索罗亚克ex","n'szoroarkex","n’szoroarkex"],"color":"e76a91","detail":"流动鬃毛 · 错位幻影 · 利爪突袭","joints":["Mane","ManeTip","Arm_R"]},
	"archaludon":{"name":"铝钢桥龙 ex","en":"METAL DEFENDER","aliases":["铝钢桥龙ex","archaludonex"],"color":"91cafa","detail":"桥桁装甲 · 导电回路 · 重型落桩","joints":["Arm_L","Arm_R","Head"]},
	"ho_oh":{"name":"阿响的凤王 ex","en":"SHINING FEATHERS","aliases":["阿响的凤王ex","ethan'sho-ohex","ethan’sho-ohex"],"color":"ffcb6c","detail":"分层飞羽 · 展翼升空 · 金焰尾迹","joints":["Wing_L","Wing_R","Tail","WingTip_L","WingTip_R"]},
	"budew":{"name":"含羞苞","en":"ITCHY POLLEN","aliases":["含羞苞","budew"],"color":"b5e977","detail":"嫩芽呼吸 · 花苞舒展 · 孢粉飘散","joints":["Petal_L","Petal_R","Head"]},
	"garchomp":{"name":"竹兰的烈咬陆鲨 ex","en":"DRAGON BUSTER","aliases":["竹兰的烈咬陆鲨ex","cynthia'sgarchompex","cynthia’sgarchompex"],"color":"73a5e8","detail":"鲨鳍轮廓 · 压低重心 · 螺旋突进","joints":["Arm_L","Arm_R","Tail","Jaw"]},
	"raging_bolt":{"name":"猛雷鼓 ex","en":"BELLOWING THUNDER","aliases":["猛雷鼓ex","ragingboltex"],"color":"ffda71","detail":"四足踏地 · 雷云翻卷 · 引雷轰落","joints":["Neck","Cloud","Head","Tail"]},
	"pikachu_tera":{"name":"太晶皮卡丘 ex","en":"TOPAZ BOLT","aliases":["皮卡丘ex","pikachuex"],"color":"ffe179","detail":"星晶王冠 · 电颊蓄能 · 黄晶伏特","joints":["Ear_L","Ear_R","Tail","Crown"]},
	"gardevoir":{"name":"沙奈朵 ex","en":"PSYCHIC EMBRACE","aliases":["沙奈朵ex","gardevoirex"],"color":"e4a5ed","detail":"裙摆悬浮 · 心灵牵引 · 精神拥抱","joints":["Heart","Skirt_L","Skirt_R","Hand_L","Hand_R","Hair"]},
}

static func identify(card: Dictionary) -> String:
	if card.get("empty",true) or card.get("concealed",true): return ""
	var label := str(card.get("name","")).to_lower().replace(" ","")
	for id: String in ENTRIES:
		if label not in ENTRIES[id].aliases: continue
		if id=="gardevoir" and str(card.get("uid",card.get("card_id","")))!="CSV2C_055":return ""
		if id == "pikachu_tera":
			var printing := str(card.get("card_id",card.get("uid",card.get("id",""))))
			var tera := str(card.get("ancient_trait",card.get("tera",""))).to_lower()
			if printing != "CSV9C_054" and tera != "tera" and not bool(card.get("is_tera",false)): return ""
		return id
	return ""
