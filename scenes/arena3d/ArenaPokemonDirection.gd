extends RefCounted
## Authored world-space blocking. Time is local to the presentation, never the rules clock.
## duration, decisive impact, public-result reveal, character scale.
const TIMINGS := {
	"dragapult": [3.15,1.28,2.55,1.40],
	"charizard": [3.40,1.48,2.72,1.62],
	"munkidori": [2.80,1.60,2.24,1.65],
	"ceruledge": [3.05,1.55,2.40,1.48],
	"terapagos": [3.45,1.72,2.75,1.45],
	"grimmsnarl": [3.20,1.42,2.55,1.57],
	"zoroark": [3.25,1.72,2.55,1.52],
	"archaludon": [3.40,1.62,2.72,1.45],
	"ho_oh": [3.50,1.70,2.85,1.40],
	"budew": [2.85,1.15,2.25,1.42],
	"garchomp": [3.50,2.20,2.88,1.42],
	"raging_bolt": [3.85,1.75,3.10,1.40],
	"pikachu_tera": [3.20,1.45,2.58,1.48],
	"gardevoir": [2.85,1.55,2.28,1.45],
}

static func profile(id: String) -> Dictionary:
	var p: Array=TIMINGS.get(id,[1.95,.82,1.62,1.52])
	return {"duration":float(p[0]),"hit":float(p[1]),"settle":float(p[2]),"scale":float(p[3])}

static func _path(points: Array, t: float) -> Vector3:
	for i: int in points.size()-1:
		if t<=float(points[i+1][0]):
			var u:=clampf((t-float(points[i][0]))/(float(points[i+1][0])-float(points[i][0])),0,1)
			return (points[i][1] as Vector3).lerp(points[i+1][1],u*u*(3-2*u))
	return points.back()[1]

static func _position(id: String,t: float,a: Vector3,b: Vector3) -> Vector3:
	var forward: Vector3=(b-a).normalized()
	if forward.length_squared()<.01:forward=Vector3.FORWARD
	var side:=forward.cross(Vector3.UP)
	var p:=profile(id)
	var hit: float=p.hit
	var wind:=smoothstep(.2,hit-.22,t)*(1-smoothstep(hit,hit+.22,t))
	var strike:=smoothstep(hit-.24,hit,t)*(1-smoothstep(hit+.25,p.settle,t))
	match id:
		"garchomp":
			return _path([[0,a],[.38,a+Vector3.UP*.8],[.70,a-side*4.6+forward*1.2+Vector3.UP*2.4],[1.20,a+side*4.4+forward*3.5+Vector3.UP*2.8],[1.70,b-side*4.0+forward*.8+Vector3.UP*1.8],[2.20,b+Vector3.UP*.5],[2.46,b+forward*2.5+Vector3.UP*1.4],[3.12,a+Vector3.UP*.5]],t)
		"zoroark":
			if t<1.32:return a+Vector3(0,-.22*wind,0)
			return _path([[1.32,b+side*1.65-forward*.2],[1.72,b-side*.48],[2.0,b+side*.8],[2.72,a]],t)
		"ceruledge":
			return _path([[0,a],[.60,a-forward*.35],[1.06,a-forward*.35],[1.32,b-side*1.25],[1.56,b+side*1.05],[1.86,b-side*.5],[2.55,a]],t)+Vector3.UP*.15
		"charizard":return a-forward*(wind*.38)+Vector3.UP*(.25+sin(clampf(t/.90,0,1)*PI*.5)*1.35*(1-smoothstep(2.65,3.25,t)))
		"dragapult":return a+side*sin(t*2.1)*.62+Vector3.UP*(.55+sin(t*1.8)*.3)+forward*strike*.45
		"munkidori":return a+Vector3.UP*(.18+sin(t*PI/2.8)*.28)
		"terapagos":return a+Vector3.UP*(.25+smoothstep(.2,1.2,t)*(1-smoothstep(2.7,3.2,t))*1.45)
		"grimmsnarl":return a+forward*strike*1.10+Vector3.UP*(.13-wind*.14)
		"archaludon":return a+Vector3.UP*(.18-wind*.12+sin(maxf(0,t-hit)*16)*exp(-maxf(0,t-hit)*9)*.03)
		"ho_oh":
			var u:=clampf((t-.28)/2.4,0,1)
			return a+side*sin(u*TAU)*2.5+forward*(1-cos(u*TAU))*1.2+Vector3.UP*(.5+sin(u*PI)*2.1)
		"budew":return a+side*sin(t*12)*wind*.07+Vector3.UP*(.10+sin(clampf((t-.62)/.66,0,1)*PI)*.80)
		"raging_bolt":return a+Vector3.UP*(.10+sin(clampf((t-1.0)/.75,0,1)*PI)*.28)
		"pikachu_tera":return a+forward*strike*.85+side*sin(t*7)*wind*.10+Vector3.UP*(.12+sin(clampf((t-.66)/1.05,0,1)*PI)*1.6)
		"gardevoir":return a+Vector3.UP*(.25+sin(clampf(t/2.85,0,1)*PI)*.65)
	return a+Vector3.UP*.2

static func sample(id: String,t: float,source: Vector3,target: Vector3) -> Dictionary:
	var p:=profile(id)
	var visibility:=smoothstep(0,.18,t)*(1-smoothstep(p.duration-.48,p.duration-.10,t))
	var at:=_position(id,t,source,target)
	var direction: Vector3=target-source
	var pitch:=0.0
	var roll:=0.0
	var darkness:=0.0
	var quake:=0.0
	var flash:=0.0
	if id=="garchomp" and t>.35 and t<3.13:
		direction=_position(id,t+.02,source,target)-_position(id,t-.02,source,target)
		pitch=PI*.43
		roll=clampf(direction.x*.35,-.65,.65)
	if id=="ho_oh":roll=sin(t*3)*.22
	if id=="archaludon":pitch=smoothstep(.55,1.3,t)*(1-smoothstep(2.2,2.8,t))*.52
	if id=="zoroark":
		darkness=smoothstep(.25,.60,t)*(1-smoothstep(2.05,2.75,t))*.86
		visibility*=1-smoothstep(.30,.53,t) if t<1.30 else smoothstep(1.30,1.43,t)
	if id=="raging_bolt":
		darkness=smoothstep(.25,1.2,t)*(1-smoothstep(2.7,3.7,t))*.52
		var q:=maxf(0,t-p.hit)
		quake=(1-smoothstep(0,1.75,q))*smoothstep(0,.035,q)
		flash=exp(-pow((t-p.hit)/.065,2))*.65+exp(-pow((t-p.hit-.23)/.045,2))*.3
	elif id in ["charizard","grimmsnarl","archaludon","garchomp","pikachu_tera"]:
		var q:=maxf(0,t-p.hit)
		quake=smoothstep(0,.025,q)*(1-smoothstep(.06,.36,q))*(.34 if id!="garchomp" else .46)
	if id=="terapagos":darkness=smoothstep(.35,1.0,t)*(1-smoothstep(2.1,3.1,t))*.25
	var clip_age: float=lerpf(0,.82,clampf(t/p.hit,0,1)) if t<=p.hit else lerpf(.82,1.95,clampf((t-p.hit)/(p.duration-p.hit),0,1))
	if t>=p.duration or t<0:visibility=0;darkness=0;quake=0;flash=0
	return {"position":at,"yaw":atan2(direction.x,direction.z),"pitch":pitch,"roll":roll,"visibility":visibility,"darkness":darkness,"quake":quake,"flash":flash,"clip_age":clip_age,"focus":smoothstep(0,.35,t)*(1-smoothstep(p.settle,p.duration,t)),"scale":p.scale}
