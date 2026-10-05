extends RefCounted
## Three beats: anticipation, species action, follow-through. Sampling is reversible.
static func sample(a: Node3D, age: float, active: bool) -> void:
	var w := smoothstep(.16,.54,age)*(1.0-smoothstep(.58,.79,age)) if active else 0.0
	var h := smoothstep(.58,.82,age)*(1.0-smoothstep(.98,1.56,age)) if active else 0.0
	var r := smoothstep(.93,1.14,age)*(1.0-smoothstep(1.32,1.70,age)) if active else 0.0
	var b := sin(age*2.4)
	var turns := {"Head":Vector3(b*.025,sin(age*1.7)*.055,0),"Body":Vector3(0,0,b*.013),"Tail":Vector3(sin(age*2.1)*.07,sin(age*2.8)*.19,0)}
	var moves: Dictionary = {}
	match str(a.species):
		"dragapult":
			moves.Body = Vector3(0,b*.075-w*.16,w*-.15)
			turns.Head = Vector3(-w*.18+h*.12,h*.06,w*.06)
			turns.Tail = Vector3(b*.09+h*.12,sin(age*3)*.31+w*.28,sin(age*2)*.09)
			turns.Arm_L = Vector3(-w*.24,-h*.24,-w*.18)
			turns.Arm_R = Vector3(-w*.24,h*.24,w*.18)
			for side: String in ["L","R"]:
				var delay := .56 if side == "L" else .65
				var flight := smoothstep(delay,delay+.42,age) if active else 0.0
				moves["Dreepy_"+side] = Vector3((-1 if side=="L" else 1)*sin(flight*PI)*.45,sin(flight*PI)*.40,flight*4.8)
				turns["Dreepy_"+side] = Vector3(-sin(flight*PI)*.19,0,sin(age*5)*.04)
		"charizard":
			turns.Body = Vector3(-w*.18+h*.20,0,0)
			turns.Head = Vector3(-w*.27+h*.15,0,0)
			turns.Jaw = Vector3(h*.59+w*.10,0,0)
			for side: String in ["L","R"]:
				var s := -1.0 if side == "L" else 1.0
				turns["Wing_"+side] = Vector3(0,-s*(.07+w*.20),s*(.08+sin(age*4.3)*.12+w*.35-h*.26))
				turns["Arm_"+side] = Vector3(-w*.18,0,s*w*.22)
			a.scale_joint("Flame",Vector3(1+b*.05,1+sin(age*15)*.12+w*.22,1))
		"munkidori":
			turns.Body = Vector3(w*.10,-w*.20+h*.13,0)
			turns.Head = Vector3(-.06-w*.07,sin(age*1.6)*.12,-.06+h*.06)
			turns.Arm_L = Vector3(-w*.30,w*.20,-w*.24+h*.12)
			turns.Arm_R = Vector3(-h*.70,h*.12,-h*.38)
			turns.Tail = Vector3(sin(age*2)*.12,sin(age*3)*.34,w*.15)
		"ceruledge":
			moves.Body = Vector3(0,-w*.20,h*.72-r*.17)
			turns.Body = Vector3(w*.11,-w*.60+h*.67-r*.21,0)
			turns.Head = Vector3(-w*.12,-h*.23,0)
			turns.Arm_L = Vector3(-w*1.90+h*.72,-w*.48+h*.5,-w*.32+h*.68)
			turns.Arm_R = Vector3(-w*1.65+h*.88,w*.54-h*.78,w*.34-h*.66)
			turns.Blade_L = Vector3(h*.20,0,-h*.15)
			turns.Blade_R = Vector3(-r*.27,0,h*.16)
			turns.Leg_L = Vector3(-h*.26,0,-w*.08)
			turns.Leg_R = Vector3(h*.20,0,w*.10)
			turns.Flame = Vector3(sin(age*7)*.09,0,sin(age*5)*.08)
		"terapagos":
			moves.Body = Vector3(0,.10+b*.09+w*.16,0)
			turns.Head = Vector3(-w*.23+h*.13,sin(age*1.5)*.07,0)
			turns.Orbit = Vector3(0,age*.52+h*.50,0)
			turns.Crown = Vector3(0,sin(age*1.6)*.12,0)
			turns.Arm_L = Vector3(-w*.24,0,-.08-b*.06)
			turns.Arm_R = Vector3(-w*.24,0,.08+b*.06)
			a.scale_joint("Shell",Vector3.ONE*(1+w*.025))
		"grimmsnarl":
			moves.Body = Vector3(0,-w*.14,h*.38)
			turns.Body = Vector3(-w*.08+h*.12,-w*.46+h*.46,0)
			turns.Head = Vector3(w*.08,-h*.18,0)
			turns.Arm_R = Vector3(-w*.50+h*.85,-w*.30+h*.70,w*.27-h*.14)
			turns.Arm_L = Vector3(-w*.38,w*.20,-h*.32)
			turns.Hair_L = Vector3(0,sin(age*3)*.12,-w*.22+r*.15)
			turns.Hair_R = Vector3(0,sin(age*3+.7)*.12,w*.22-r*.15)
		"zoroark":
			moves.Body = Vector3(-w*.16+h*.30,-w*.25,h*.80)
			turns.Body = Vector3(w*.12,-w*.36+h*.60,0)
			turns.Head = Vector3(-w*.10,-h*.32,0)
			turns.Mane = Vector3(-h*.22,sin(age*2)*.13-w*.24,-h*.16)
			turns.ManeTip = Vector3(sin(age*3)*.15,-h*.28,h*.30)
			turns.Arm_R = Vector3(-w*.6+h*.62,-h*.4,-h*.3)
			turns.Arm_L = Vector3(-w*.35+h*.30,h*.3,h*.2)
		"archaludon":
			moves.Body = Vector3(0,-w*.08+sin(h*PI)*.06,0)
			turns.Body = Vector3(-w*.12+h*.17,0,0)
			turns.Head = Vector3(-w*.07+h*.14,0,0)
			turns.Arm_L = Vector3(-w*.25+h*.27,0,-w*.12)
			turns.Arm_R = Vector3(-w*.25+h*.27,0,w*.12)
		"ho_oh":
			moves.Body = Vector3(0,.22+b*.07+w*.35+h*.23,0)
			var flap := sin(age*3.7)*.19
			turns.Wing_L = Vector3(0,w*.1,-flap-w*.45+h*.48)
			turns.Wing_R = Vector3(0,-w*.1,flap+w*.45-h*.48)
			turns.WingTip_L = Vector3(0,0,-sin(age*3.7-.45)*.15-h*.10)
			turns.WingTip_R = Vector3(0,0,sin(age*3.7-.45)*.15+h*.10)
			turns.Head = Vector3(-w*.23+h*.12,0,0)
			turns.Jaw = Vector3(h*.20,0,0)
			turns.Tail = Vector3(-w*.18+h*.17,sin(age*2)*.08,0)
		"budew":
			moves.Body = Vector3(0,maxf(0,sin(h*PI))*.22-w*.12,0)
			a.scale_joint("Body",Vector3(1+w*.08,1-w*.08,1+w*.05))
			turns.Head = Vector3(-w*.08+h*.09,0,b*.06)
			turns.Petal_L = Vector3(-h*.08,0,-h*.48)
			turns.Petal_R = Vector3(-h*.08,0,h*.48)
		"garchomp":
			moves.Body = Vector3(0,-w*.16+r*.08,0)
			turns.Body = Vector3(w*.06,0,sin(age*9)*w*.08)
			turns.Head = Vector3(-w*.19+h*.15,0,0)
			turns.Arm_L = Vector3(w*1.05,-w*.16,-w*.34-h*.50)
			turns.Arm_R = Vector3(w*1.05,w*.16,w*.34+h*.50)
			turns.Leg_L = Vector3(w*.60,0,-w*.08)
			turns.Leg_R = Vector3(w*.60,0,w*.08)
			turns.Tail = Vector3(.02,sin(age*2)*.13-w*.43+h*.47,0)
			turns.Jaw = Vector3(h*.27,0,0)
		"raging_bolt":
			turns.Neck = Vector3(w*.15-h*.15,0,w*.035)
			turns.Head = Vector3(-w*.17+h*.25,0,0)
			turns.Cloud = Vector3(0,b*.11+w*.24,0)
			a.scale_joint("Cloud",Vector3(1+w*.12,1+w*.17,1+w*.12))
			moves.Body = Vector3(0,-w*.06+h*.035,0)
			turns.Leg_L = Vector3(-w*.06,0,0)
			turns.Leg_R = Vector3(-w*.06,0,0)
		"pikachu_tera":
			moves.Body = Vector3(0,-w*.15+sin(h*PI)*.43,h*.35)
			turns.Head = Vector3(-w*.10+h*.07,0,0)
			turns.Ear_L = Vector3(-w*.24,0,-b*.055-w*.19)
			turns.Ear_R = Vector3(-w*.18,0,b*.07+w*.23)
			turns.Arm_L = Vector3(-w*.42+h*.18,0,-h*.28)
			turns.Arm_R = Vector3(-w*.42+h*.18,0,h*.28)
			turns.Tail = Vector3(0,sin(age*3)*.13+w*.35,-h*.25)
			turns.Crown = Vector3(0,b*.03,0)
		"gardevoir":
			moves.Body=Vector3(0,b*.045+w*.06,0)
			turns.Body=Vector3(-w*.045,sin(age*2)*.06,0)
			turns.Head=Vector3(-w*.12+h*.10,0,-b*.035)
			turns.Arm_L=Vector3(-w*.55-h*.42,-w*.35,-w*.65+h*.15)
			turns.Arm_R=Vector3(-w*.55-h*.42,w*.35,w*.65-h*.15)
			turns.Hand_L=Vector3(-h*.3,0,-w*.17)
			turns.Hand_R=Vector3(-h*.3,0,w*.17)
			turns.Skirt_L=Vector3(b*.07,0,-w*.12-h*.10)
			turns.Skirt_R=Vector3(-b*.07,0,w*.12+h*.10)
			turns.Hair=Vector3(-b*.035,sin(age*1.4)*.05,0)
			a.scale_joint("Heart",Vector3.ONE*(1+w*.10+h*.06))
	for id: String in turns: a.turn(id,turns[id])
	for id: String in moves: a.move_joint(id,moves[id])
