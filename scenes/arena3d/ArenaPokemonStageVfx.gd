extends "res://scenes/arena3d/ArenaPokemonPerformance.gd"
## Species-owned stage geometry. One bounded mesh, sampled from the same sequence clock.
const Direction := preload("res://scenes/arena3d/ArenaPokemonDirection.gd")
var sampled_species := ""

func setup() -> void:
	effect=MeshInstance3D.new()
	effect.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo=true
	material.render_priority=2
	effect.material_override=material
	add_child(effect)

func _stroke(points: Array[Vector3],width: float,color: Color,floor_plane: bool=false) -> void:
	for i: int in range(0,points.size()-1,2 if low_quality else 1):
		var next := mini(i+(2 if low_quality else 1),points.size()-1)
		var axis: Vector3=(points[next]-points[i]).cross(Vector3.UP if floor_plane else Vector3.FORWARD)
		if axis.length_squared()<.00001:axis=Vector3.RIGHT
		var side:=axis.normalized()*width
		_triangle(points[i]-side,points[i]+side,points[next]-side,color)
		_triangle(points[next]-side,points[i]+side,points[next]+side,color)

func _ring(at: Vector3,radius: float,width: float,color: Color,vertical: bool=false) -> void:
	var pts: Array[Vector3]=[]
	for i: int in 49:
		var a:=i*TAU/48
		pts.append(at+(Vector3(cos(a),sin(a),0) if vertical else Vector3(cos(a),0,sin(a)))*radius)
	_stroke(pts,width,color,not vertical)

func _shard(at: Vector3,size: float,color: Color) -> void:
	var top:=at+Vector3.UP*size*2.4
	var base: Array[Vector3]=[at+Vector3(-size,0,0),at+Vector3(0,0,size),at+Vector3(size,0,0),at+Vector3(0,0,-size)]
	for i: int in 4:_triangle(base[i],base[(i+1)%4],top,color.darkened(i*.12))

func _thunder_column(from: Vector3,to: Vector3,t: float,alpha: float,seed: int) -> void:
	# A stage-scale thunder strike needs a readable core and branching corona.
	# Joint-local sparks are deliberately much finer than this world-space column.
	var points: Array[Vector3]=[]
	var tick:=floorf(t*30)
	for i: int in 15:
		var u:=float(i)/14
		points.append(from.lerp(to,u)+Vector3(sin(i*12.7+tick+seed)*.38,0,cos(i*7.3+tick+seed)*.18)*sin(u*PI))
	_stroke(points,.32,Color("b4a2ff",alpha*.13))
	_stroke(points,.14,Color("e1c3ff",alpha*.48))
	_stroke(points,.048,Color("fff9df",alpha))
	for branch: int in 3:
		var start: Vector3=points[4+branch*3]
		var sign_x: float=-1.0 if (branch+seed)%2 else 1.0
		var fork: Array[Vector3]=[start,start+Vector3(sign_x*.7,-.42,.15),start+Vector3(sign_x*.42,-.76,.25),start+Vector3(sign_x*1.25,-1.1,.35)]
		_stroke(fork,.027,Color("eee0ff",alpha*.76))

func _shadow_curtain(opacity: float) -> void:
	# Soft edges blend into the physical table instead of revealing a black rectangle.
	var columns := 8 if low_quality else 16
	var rows := 5 if low_quality else 10
	for x: int in columns:
		for z: int in rows:
			var corners: Array[Vector3]=[]
			for offset: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				corners.append(Vector3(-22+(x+offset.x)*44.0/columns,.62,-12+(z+offset.y)*24.0/rows))
			for index: int in [0,1,2,2,1,3]:
				var point:=corners[index]
				var alpha:=smoothstep(0,4,22-absf(point.x))*smoothstep(0,3,12-absf(point.z))*opacity
				surface.set_color(Color("04020d",alpha));surface.add_vertex(point);vertex_count+=1

func _slash(at: Vector3,angle: float,radius: float,alpha: float,color: Color) -> void:
	var pts: Array[Vector3]=[]
	for i: int in 28:
		var a: float=-1.05+i*2.10/27
		pts.append(at+Vector3(sin(a)*radius,cos(a)*radius*.60,0).rotated(Vector3.FORWARD,angle))
	_ribbon(pts,.18,Color(color,alpha*.28))
	_ribbon(pts,.052,Color.WHITE*Color(1,1,1,alpha))

func sample_stage(id: String,t: float,a: Vector3,b: Vector3,hero: Vector3,cue: Dictionary={}) -> void:
	var tick := floori(t*30.0)
	if low_quality and tick == sample_tick and id == sampled_species: return
	sample_tick = tick
	sampled_species = id
	surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);vertex_count=0
	var p:=Direction.profile(id)
	var hit: float=p.hit
	var charge:=smoothstep(.15,hit-.20,t)*(1-smoothstep(hit,hit+.10,t))
	var tail:=smoothstep(hit-.03,hit+.04,t)*(1-smoothstep(p.settle-.15,p.duration-.14,t))
	var blast:=exp(-pow((t-hit)/.22,2))
	var dt:=maxf(0,t-hit)
	var end:=1-smoothstep(p.duration-.48,p.duration-.08,t)
	var forward: Vector3=(b-a).normalized()
	var side:=forward.cross(Vector3.UP)
	var state:=Direction.sample(id,t,a,b)
	# A low shadow curtain covers the felt, while the creature and red eyes remain above it.
	if id in ["zoroark","raging_bolt"] and state.darkness>.01:
		_shadow_curtain(float(state.darkness)*.82)
	match id:
		"garchomp":
			if t>.4 and t<2.58:
				for wing: int in [-1,1]:
					var pts: Array[Vector3]=[]
					for j: int in 20:
						var age:=maxf(.36,t-j*.018)
						pts.append(Direction.sample(id,age,a,b).position+side*wing*.90+Vector3.UP*1.85)
					_ribbon(pts,.15,Color("bdeaff",.72))
				for pass_time: float in [.76,1.28,2.20]:
					var u:=t-pass_time
					if u>0 and u<.28:_ring(Direction.sample(id,pass_time,a,b).position+Vector3.UP*1.85,.4+u*4,.045,Color("def6ff",(1-u/.28)*.65),true)
			if tail>0:
				_slash(b+Vector3.UP*.7,-.70,2.4,tail,Color("66b4ff"))
				_ring(b+Vector3.UP*.12,.2+dt*5.8,.06,Color("bbeaff",tail*.5))
		"zoroark":
			for k: int in 3:
				var center: Vector3=(a if k==0 else b+side*(k*2-3)*2.2)+Vector3.UP*2
				var reveal:=smoothstep(.40,.65,t)*(1-smoothstep(1.22,1.45,t))
				for eye: int in [-1,1]:_spark(center+side*eye*.18,.065,Color("ff315d",reveal))
			for k: int in 20:
				var ang:=k*2.39996+t*1.8
				var center:=b+Vector3(cos(ang)*1.6,.7+fmod(t*1.4+k*.17,2.3),sin(ang)*1.0)
				_shard(center,.23,Color("271539",state.darkness*.64))
			for k: int in 3:
				var cut:=exp(-pow((t-hit-k*.08)/.19,2))
				_slash(b+Vector3((k-1)*.22,1.0,0),-.45,2.25,cut,Color("ff3972"))
		"raging_bolt":
			var cloud:=a+Vector3.UP*5.0
			for k: int in 14:
				var ang:=k*TAU/14+t*.4
				_ring(cloud+Vector3(cos(ang)*1.1,sin(k*1.7)*.23,sin(ang)*.8),.65+charge*.3,.18,Color("39364f",(charge+tail)*.48),true)
			if t>hit-.12 and t<hit+.50:
				for k: int in 4:
					_thunder_column(b+Vector3((k-1.5)*.43,6.5,k*.13),b+Vector3.UP*.3,t,.95 if k==1 else .5,k)
			if tail>0:
				for k: int in 3:_ring(b+Vector3.UP*(.09+k*.025),maxf(.1,dt*6-k*1.2),.09,Color("c6b1ff",tail*(.5-k*.09)))
				for k: int in 14:
					var ang:=k*2.39996
					var pts: Array[Vector3]=[b+Vector3.UP*.08]
					for j: int in 5:pts.append(b+Vector3(cos(ang+.16*sin(j*4+k)),.08,sin(ang+.16*sin(j*4+k)))*Vector3(1+j*.58,1,1+j*.58))
					_stroke(pts,.065,Color("1c1214",tail*.85),true)
					_stroke(pts,.018,Color("ffd28a",tail*.6),true)
					var jump:=maxf(0,sin(minf(PI,dt*(3.7+(k%3)))))
					_shard(b+Vector3(cos(ang)*(1+dt*1.4),.13+jump*(.8+k%3*.3),sin(ang)*(1+dt*1.4)),.18+(k%3)*.065,Color("a18d74",tail))
		"charizard":
			if charge>.01:
				for k: int in 14:
					var ang:=k*2.39996+t*2
					_spark(hero+Vector3(cos(ang)*(1-charge),1.8+sin(ang)*.4,.5),.055,Color("ffc75c",charge))
			if tail>0:
				for k: int in 18:
					var ang:=k*2.39996
					_shard(b+Vector3(cos(ang)*dt*2.1,.3+sin(minf(PI,dt*2))*1.1,sin(ang)*dt*1.4),.09+(k%3)*.045,Color("ff7b32",tail*.65))
				_ring(b+Vector3.UP*.09,1.15+dt*.2,.15,Color("b83916",tail*.46))
		"dragapult":
			for k: int in 2:
				var u:=clampf((t-.70-k*.17)/.72,0,1)
				var from:=a+side*(k*2-1)*1.45+Vector3.UP*2.0
				var pts: Array[Vector3]=[]
				for j: int in 18:
					var v:=maxf(0,u-j*.018)
					pts.append(from.lerp(b+Vector3.UP*.35,v)+side*sin(v*PI)*(k*2-1)*1.25+Vector3.UP*sin(v*PI)*.9)
				if u>0 and u<1:_ribbon(pts,.13,Color("80ffe7",.7))
			if tail>0:_ring(b+Vector3.UP*.5,.3+dt*3,.04,Color("94f7e4",tail*.5),true)
		"ceruledge":
			for k: int in 2:
				var cut:=exp(-pow((t-hit-(k-.5)*.17)/.24,2))
				_slash(b+Vector3.UP*.75,.72 if k==0 else -.72,2.7,cut,Color("9770ff"))
			if tail>0:
				for k: int in 14:_shard(b+Vector3(sin(k*2.4)*1.7,.14+dt*.8,cos(k*2.4)*1.0),.06,Color("9685ff",tail*.5))
		"terapagos":
			for k: int in 12:
				var ang:=k*TAU/12+t*.75
				var c:=Color.from_hsv(k/12.0,.46,1,(charge+tail)*.75)
				var crystal:=a+Vector3(cos(ang)*2.0,1.5+sin(ang*2)*.4,sin(ang)*1.2)
				_shard(crystal,.16,c)
				if tail>0:_stroke([crystal,b+Vector3.UP*.4],.025,Color(c,blast*.85))
			if tail>0:
				for k: int in 6:_ring(b+Vector3.UP*(.15+k*.12),1.7-k*.17,.035,Color.from_hsv(k/6.0,.4,1,tail*.42))
		"grimmsnarl":
			for k: int in 6:
				var u:=clampf((t-.55-k*.055)/.82,0,1)
				var pts: Array[Vector3]=[]
				for j: int in 24:
					var v:=u*j/23
					pts.append(a.lerp(b,v)+Vector3(sin(v*5+k)*.5,.45+sin(v*PI)*1.1,0)+side*(k-2.5)*.16)
				_stroke(pts,.075,Color("362446",(charge+tail)*.85))
				_stroke(pts,.014,Color("c183dc",(charge+tail)*.7))
			if tail>0:_ring(b+Vector3.UP*.22,.4+dt*3.8,.15,Color("9453b2",tail*.5))
		"archaludon":
			for s: int in [-1,1]:
				var start:=a+side*s*.85+Vector3.UP*.7
				if charge>.01:_bolt(start+Vector3.UP*2,start,t,Color("a6e5ff",charge*.7),s)
				if tail>0:
					_stroke([start,b+side*s*.20+Vector3.UP*.45],.08,Color("d0ecff",blast*.9))
					for k: int in 4:_ring(start.lerp(b,float(k)/4),.27,.03,Color("8cb9ff",blast*.8),true)
			if tail>0:
				for k: int in 6:_shard(a+Vector3(cos(k*TAU/6)*1.6,.08,sin(k*TAU/6)*1.3),.35,Color("a8cbdc",tail*.38))
		"ho_oh":
			for k: int in 7:
				var pts: Array[Vector3]=[]
				for j: int in 25:pts.append(Direction.sample(id,maxf(.28,t-j*.027),a,b).position+Vector3(0,.5+k*.09,0))
				_ribbon(pts,.065,Color.from_hsv(k/7.0,.6,1,end*.40))
			if tail>0:
				for k: int in 22:
					var u:=clampf((t-hit+k*.016)/.90,0,1)
					_feather((hero+Vector3.UP*1.3).lerp(b,u)+side*sin(k*2.4)*sin(u*PI)*1.9,.17,k+t,Color("ffdc8a",sin(u*PI)*.75))
		"budew":
			for k: int in 52:
				var u:=clampf((t-.82-(k%7)*.035)/1.25,0,1)
				var ang:=k*2.39996
				var pos: Vector3=(a+Vector3.UP*2.5).lerp(b+Vector3.UP*.55,u)+side*cos(ang)*u*1.8+Vector3.UP*(sin(ang)*u*.6+sin(u*PI)*.55)
				_spark(pos,.04+(k%3)*.015,Color("eff8ab" if k%3 else "f7afc7",sin(u*PI)*.85))
			if tail>0:_ring(b+Vector3.UP*.11,1.15,.045,Color("a9d265",tail*.46))
		"pikachu_tera":
			for k: int in 5:
				var ang: float=k*TAU/5-PI*.5
				var tip:=b+Vector3(cos(ang)*2.1,.22,sin(ang)*2.1)
				var next: float=(k+2)*TAU/5-PI*.5
				if tail>0:_stroke([tip,b+Vector3(cos(next)*2.1,.22,sin(next)*2.1)],.055,Color.from_hsv(k/5.0,.5,1,tail*.8),true)
				if blast>.01:_bolt(hero+Vector3.UP*2.5,tip,t,Color("fff2ad",blast*.8),k)
			if tail>0:
				for k: int in 15:_shard(b+Vector3(sin(k*2.4)*dt*2,.3+sin(minf(PI,dt*3))*.6,cos(k*2.4)*dt*2),.07,Color.from_hsv(k/15.0,.4,1,tail*.7))
		"munkidori":
			for k: int in 8:
				var ang:=k*TAU/8+t*3
				_ring(hero+Vector3(cos(ang)*.42,2.65+sin(ang)*.25,.1),.09,.018,Color("dc85ef",(charge+tail)*.7),true)
		"gardevoir":
			var origin: Vector3=cue.get("energy_origin",a+side*6)
			var heart:=hero+Vector3.UP*2.8
			var u:=clampf((t-.20)/1.30,0,1)
			var orb: Vector3=origin.lerp(heart,u/.50) if u<.50 else heart.lerp(b+Vector3.UP*.7,(u-.50)/.50)
			orb+=Vector3.UP*sin(u*PI)*.70
			if u>0 and u<1:
				_ring(orb,.24,.04,Color("ecc5ff",.95),true)
				_spark(orb,.17,Color("fff4ff",.95))
			for side_sign: int in [-1,1]:
				var pts: Array[Vector3]=[]
				for j: int in 28:
					var v:=float(j)/27
					pts.append(heart.lerp(b+Vector3.UP*.7,v)+side*side_sign*sin(v*PI)*1.3+Vector3.UP*sin(v*PI)*.45)
				_ribbon(pts,.14,Color("ecb4ed",(charge+tail)*.78))
			if tail>0:
				for k: int in 3:_ring(b+Vector3.UP*(.3+k*.32),1.1-k*.15,.065,Color("c6f6d8",tail*.70))
				for s: int in [-1,1]:_spark(b+side*s*.22+Vector3.UP*.9,.075,Color("ff91c0",tail*.9))
	effect.visible=vertex_count>0
	effect.mesh=surface.commit() if vertex_count>0 else null
	surface=null
