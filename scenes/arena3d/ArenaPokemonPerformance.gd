extends Node3D
## Bounded local mesh VFX. One surface, one light; no independent timers or randomness.
var actor: Node3D
var effect: MeshInstance3D
var lamp: OmniLight3D
var ghosts: Array[Node3D] = []
var surface: SurfaceTool
var vertex_count := 0
var flame_mesh: MeshInstance3D
var low_quality := false
var sample_tick := -1
var sampled_active := false

func build(owner_actor: Node3D) -> void:
	actor = owner_actor
	low_quality = actor.low_quality
	effect = MeshInstance3D.new()
	effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	effect.material_override = material
	add_child(effect)
	lamp = OmniLight3D.new()
	lamp.omni_range = 7.0
	lamp.light_color = Color(actor.Catalog.ENTRIES[actor.species].color)
	lamp.light_energy = 0
	lamp.visible = not actor.low_quality
	add_child(lamp)
	if actor.species=="charizard":
		flame_mesh=MeshInstance3D.new()
		flame_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var flame_material:=StandardMaterial3D.new()
		flame_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		flame_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		flame_material.cull_mode=BaseMaterial3D.CULL_DISABLED
		flame_material.vertex_color_use_as_albedo=true
		flame_material.albedo_texture=load("res://assets/arena3d/pokemon/vfx/dragon-breath-v2.png")
		flame_mesh.material_override=flame_material
		add_child(flame_mesh)
	if actor.species == "zoroark":
		for i: int in 2:
			var ghost: Node3D = actor.model.duplicate()
			var ghost_mat := StandardMaterial3D.new()
			ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost_mat.albedo_color = Color(.45,.12,.31,.14-i*.035)
			for part: MeshInstance3D in ghost.find_children("*","MeshInstance3D",true,false):
				part.material_override = ghost_mat
				part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ghost)
			ghost.visible = false
			ghosts.append(ghost)

func sample(age: float, active: bool, target: Vector3) -> void:
	# Only procedural mesh generation is sampled at 30 Hz. Actor transforms and
	# joints, UI and input retain the display-rate clock and original choreography.
	var tick := floori(age*30.0)
	if low_quality and tick == sample_tick and active == sampled_active: return
	sample_tick = tick
	sampled_active = active
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	vertex_count = 0
	var charge := smoothstep(.15,.58,age)*(1.0-smoothstep(.72,.85,age)) if active else 0.0
	var hit := smoothstep(.60,.79,age)*(1.0-smoothstep(1.01,1.49,age)) if active else 0.0
	var fade := 1.0-smoothstep(1.20,1.72,age)
	var tint := Color(actor.Catalog.ENTRIES[actor.species].color)
	lamp.position = actor.local_joint("Head")
	lamp.light_energy = (charge*.38+hit*.62) if active else 0.0
	for ghost: Node3D in ghosts: ghost.visible = false
	if flame_mesh!=null:
		flame_mesh.visible=hit>.01
		if flame_mesh.visible:_flame_volume(actor.mouth_local(),target,age,hit)
	match str(actor.species):
		"dragapult":
			if active:
				for s: int in 2:
					var start: Vector3 = actor.local_joint("Dreepy_L" if s==0 else "Dreepy_R")
					var pts: Array[Vector3] = []
					for j: int in 22:
						var t := float(j)/21
						pts.append(start+Vector3(sin(t*4+age*9)*.10,sin(t*PI)*.13,-t*1.40))
					_ribbon(pts,.065,Color(tint,hit*.65))
		"charizard":
			if hit > 0:
				var from: Vector3 = actor.mouth_local()
				for k: int in 7:
					var pts: Array[Vector3] = []
					for j: int in 22:
						var t := float(j)/21
						var twist := age*17+t*9+k*TAU/7
						pts.append(_breath_point(from,target,t)+Vector3(cos(twist),sin(twist),0)*(.03+t*.25))
					_ribbon(pts,.045+float(k%3)*.026,Color("fff1a0" if k==0 else ("ffb33e" if k%2 else "e85e25"),hit*.72))
			_embers(age,actor.local_joint("Flame"),8,Color("ffb14d"),.26,.4)
		"munkidori":
			if charge+hit > 0:
				var center: Vector3 = actor.local_joint("Arm_L",Vector3(-.28,1.13,.28))
				for k: int in 2:_circle(center,.24+k*.08,age*(2 if k==0 else -3),Color(tint,(charge+hit)*.5),k==0)
				for k: int in 3:_spark(center+Vector3(cos(age*3+k*TAU/3)*.31,sin(age*3+k*TAU/3)*.31,0),.035,Color("f7b4e9",(charge+hit)*.7))
		"ceruledge", "garchomp", "zoroark":
			if hit > 0 and not actor.stage_directed:
				for k: int in (3 if actor.species=="zoroark" else 2):
					var points: Array[Vector3] = []
					for j: int in 27:
						var t := float(j)/26
						var theta := -.90+t*2.4+age*.5
						var v := Vector3(cos(theta)*(1.1+t*.65),sin(theta)*1.3,2.15+sin(t*PI)*.37)
						v = v.rotated(Vector3.FORWARD,(.65 if k==0 else -.65) if actor.species!="zoroark" else -.20)
						if k==1:v.x=-v.x
						points.append(v+Vector3((k-1)*.13 if actor.species=="zoroark" else 0,1.4,0))
					_ribbon(points,.075,Color(tint,hit*.66))
			if actor.species=="zoroark" and not actor.stage_directed:
				for k: int in ghosts.size():
					ghosts[k].visible = active and age>.45 and age<1.16
					ghosts[k].position = Vector3((k*2-1)*(.40+hit*.25),0,-.25-k*.20)
					ghosts[k].rotation.y = (k*2-1)*.15
		"terapagos":
			if charge+hit > 0:
				for k: int in 6:
					var c := Color.from_hsv(float(k)/6,.46,1,(charge+hit)*.65)
					var from := Vector3(cos(k*TAU/6+age)*1.2,1.4,sin(k*TAU/6+age)*1.0)
					var points: Array[Vector3] = []
					for j: int in 18:
						var t := float(j)/17
						points.append(from.lerp(target,t)+Vector3(0,sin(t*PI)*(.75-charge*.3),0))
					if hit>0:_ribbon(points,.028,c)
					_spark(from,.06,c)
		"grimmsnarl":
			if charge+hit > 0:
				var center: Vector3 = actor.local_joint("Arm_R")+Vector3(.8,-.2,.4)
				var travel := smoothstep(.65,1.04,age)
				center = center.lerp(target,travel)
				for k: int in 4:_circle(center,.20+k*.065,age*4+k,Color(tint,(charge+hit)*.43),k%2==0)
		"archaludon":
			if charge+hit > 0:
				for s: int in [-1,1]:
					_bolt(Vector3(s*.9,2.6,0),Vector3(s*.4,.4,.1),age,Color(tint,charge*.80),s)
					if hit>0:_bolt(Vector3(s*.7,1.5,.3),target,age,Color("d7eaff",hit*.75),s+3)
		"ho_oh":
			if active:
				for k: int in 16:
					var t := clampf((age-.52-float(k)*.025)/.8,0,1)
					var sign_x := -1.0 if k%2 else 1.0
					var from := Vector3(sign_x*(.7+float(k%8)*.15),2.0,0)
					var p := from.lerp(target,t)+Vector3(sin(t*PI)*sign_x*.55,sin(t*PI)*.7,0)
					_feather(p,.12,age+k*.4,Color("ffdb82",sin(t*PI)*fade*.8))
		"budew":
			if active:
				for k: int in 34:
					var t := clampf((age-.62-float(k%5)*.021)/1.0,0,1)
					var a := float(k)*2.39996
					var from := Vector3(0,2.0,0)
					var p := from.lerp(target,t)+Vector3(cos(a)*t*.75,sin(a*1.4)*t*.55+sin(t*PI)*.4,0)
					_spark(p,.021+float(k%3)*.008,Color("e8f6a8" if k%3 else "f3b9ce",sin(t*PI)*.7))
		"raging_bolt":
			var cloud: Vector3 = actor.local_joint("Cloud")
			if charge>0:
				for k: int in 3:_bolt(cloud+Vector3(-.5,.09,k*.17),cloud+Vector3(.5,.1,-k*.12),age,Color("d6d5fb",charge*.7),k)
			if hit>0:
				_bolt(cloud,cloud+Vector3(0,1.0,1.0),age,Color("b2e7ff",hit*.85),1)
				_bolt(target+Vector3(0,3.4,0),target,age,Color("ffeaad",hit*.9),3)
				_bolt(target+Vector3(.22,3.3,.1),target,age,Color("caeaff",hit*.7),7)
		"pikachu_tera":
			var head: Vector3 = actor.local_joint("Head")
			if charge>0:
				for s: int in [-1,1]:_bolt(head+Vector3(s*.43,.09,.31),Vector3(s*.53,.40,.1),age,Color("ffe596",charge*.8),s)
			if hit>0:
				for k: int in 3:_bolt(head+Vector3((k-1)*.24,.1,.35),target,age,Color("fff0a5" if k==1 else "efc1ff",hit*.85),k+5)
			for k: int in 7:
				var angle := age*.5+k*TAU/7
				_spark(Vector3(cos(angle)*.9,1.2+sin(age+k)*.7,sin(angle)*.7),.025,Color.from_hsv(float(k)/7,.35,1,.35))
		"gardevoir":
			if charge+hit>0:
				var heart: Vector3=actor.local_joint("Heart")
				_circle(heart,.19+charge*.08,age*3,Color("ffd6ed",(charge+hit)*.65),true)
				for s: int in [-1,1]:_spark(actor.local_joint("Hand_L" if s==-1 else "Hand_R"),.045,Color("cbf3e4",(charge+hit)*.7))
	effect.visible = vertex_count>0
	if vertex_count>0: effect.mesh=surface.commit()
	else: effect.mesh=null
	surface=null

func _triangle(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	if color.a<.002:return
	for v: Vector3 in [a,b,c]:
		surface.set_color(color)
		surface.add_vertex(v)
		vertex_count+=1

func _ribbon(points: Array[Vector3],width: float,color: Color) -> void:
	for i: int in range(0,points.size()-1,2 if low_quality else 1):
		var next := mini(i+(2 if low_quality else 1),points.size()-1)
		var t := float(i)/maxi(1,points.size()-2)
		var side := (points[next]-points[i]).cross(Vector3.FORWARD)
		if side.length_squared()<.00001: side=Vector3.RIGHT
		var half := side.normalized()*width*maxf(.08,sin(t*PI))
		var c := Color(color,color.a*sin(t*PI))
		_triangle(points[i]-half,points[i]+half,points[next]-half,c)
		_triangle(points[next]-half,points[i]+half,points[next]+half,c)

func _bolt(from: Vector3,to: Vector3,age: float,color: Color,seed: int) -> void:
	var points: Array[Vector3] = []
	var tick := floorf(age*24)
	for i: int in 13:
		var t := float(i)/12
		points.append(from.lerp(to,t)+Vector3(sin(i*13.4+tick+seed),cos(i*7.1+tick*1.4+seed),sin(i*8+seed))*.10*sin(t*PI))
	_ribbon(points,.063,Color(color,color.a*.22))
	_ribbon(points,.023,color)

func _circle(center: Vector3,radius: float,phase: float,color: Color,vertical: bool) -> void:
	var points: Array[Vector3] = []
	for i: int in 33:
		var a := float(i)*TAU/32+phase
		points.append(center+(Vector3(cos(a),sin(a),0) if vertical else Vector3(cos(a),0,sin(a)))*radius)
	_ribbon(points,.017,color)

func _spark(at: Vector3,size: float,color: Color) -> void:
	_triangle(at+Vector3(0,size*2,0),at+Vector3(-size,0,0),at+Vector3(0,-size*2,0),color)
	_triangle(at+Vector3(0,size*2,0),at+Vector3(0,-size*2,0),at+Vector3(size,0,0),color)
	_triangle(at+Vector3(0,size,0),at+Vector3(0,0,-size),at+Vector3(0,-size,0),color)
	_triangle(at+Vector3(0,size,0),at+Vector3(0,-size,0),at+Vector3(0,0,size),color)

func _feather(at: Vector3,size: float,angle: float,color: Color) -> void:
	var axis := Vector3(sin(angle)*size,cos(angle)*size*2,0)
	var width := Vector3(cos(angle)*size*.33,-sin(angle)*size*.33,.02)
	_triangle(at-axis,at-width,at+axis,color)
	_triangle(at-axis,at+axis,at+width,color)

func _embers(age: float,origin: Vector3,count: int,color: Color,spread: float,height: float) -> void:
	for k: int in count:
		var t := fmod(age*.55+float(k)/count,1.0)
		_spark(origin+Vector3(sin(k*2.4+t)*spread,t*height,cos(k*2.4+t)*spread),.022,Color(color,(1-t)*.60))

func _breath_point(from: Vector3,to: Vector3,t: float) -> Vector3:
	# First leave along the muzzle, then bend toward close or low targets.
	# A direct downward ray can otherwise pass through the open lower jaw.
	var control: Vector3 = actor.local_joint("Head",Vector3(0,-.08,1.45))
	return from.lerp(control,t).lerp(control.lerp(to,t),t)

func _flame_volume(from: Vector3,to: Vector3,age: float,opacity: float) -> void:
	var s:=SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axis: Vector3=(to-from).normalized()
	var across:=axis.cross(Vector3.UP).normalized()
	if across.length_squared()<.01:across=Vector3.RIGHT
	var up:=axis.cross(across).normalized()
	for layer: int in 2:
		var width_axis:=up if layer==0 else across
		var segments := 8 if low_quality else 16
		for j: int in segments:
			var pts: Array[Vector3]=[]
			var uvs: Array[Vector2]=[]
			for k: int in 2:
				var t:=float(j+k)/segments
				var center:=_breath_point(from,to,t)+across*sin(age*18+t*8)*t*.045
				var width:=.12+t*.70
				for side: int in [-1,1]:
					pts.append(center+width_axis*side*width)
					uvs.append(Vector2(t,(side+1)*.5))
			for i: int in [0,1,2,2,1,3]:
				s.set_color(Color(1,1,1,opacity*(.88 if layer==0 else .56)))
				s.set_uv(uvs[i])
				s.add_vertex(pts[i])
	flame_mesh.mesh=s.commit()
