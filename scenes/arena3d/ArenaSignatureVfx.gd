extends Node3D
## Public, committed visual outcomes only. No rules, choices or engine references.
const Ready := preload("res://scripts/ui/battle/BattleReadyVfxRegistry.gd")
const Actor := preload("res://scenes/arena3d/ArenaPokemonActor.gd")
const Catalog := preload("res://scenes/arena3d/ArenaPokemonCatalog.gd")
const Direction := preload("res://scenes/arena3d/ArenaPokemonDirection.gd")
const StageVfx := preload("res://scenes/arena3d/ArenaPokemonStageVfx.gd")
const ATTACK_HIT := 0.82
const ATTACK_SETTLE := 1.62
const DURATION := 1.95
var world: Node3D
var sequences: Array[Dictionary] = []
var played := 0
var last_outcome: Dictionary = {}

static func profile(card: Dictionary) -> Dictionary:
	var id := Catalog.identify(card)
	if id == "": return {}
	var specs := {"dragapult":Ready.DRAGAPULT_READY_ASSET_SPECS,"charizard":Ready.CHARIZARD_READY_ASSET_SPECS,"munkidori":Ready.MUNKIDORI_READY_ASSET_SPECS,
		"ceruledge":Ready.CERULEDGE_READY_ASSET_SPECS,"terapagos":Ready.TERAPAGOS_READY_ASSET_SPECS,"grimmsnarl":Ready.MARNIES_GRIMMSNARL_READY_ASSET_SPECS,
		"zoroark":Ready.NS_ZOROARK_READY_ASSET_SPECS,"archaludon":Ready.ARCHALUDON_READY_ASSET_SPECS,"ho_oh":Ready.ETHANS_HO_OH_READY_ASSET_SPECS,
		"budew":Ready.BUDEW_READY_ASSET_SPECS,"garchomp":Ready.CYNTHIAS_GARCHOMP_READY_ASSET_SPECS,"raging_bolt":Ready.RAGING_BOLT_READY_ASSET_SPECS,"pikachu_tera":Ready.LIGHTNING_READY_ASSET_SPECS,"gardevoir":Ready.GARDEVOIR_READY_ASSET_SPECS}
	return {"id":id,"spec":specs[id].burst,"color":Color(Catalog.ENTRIES[id].color),"size":6.2 if id=="budew" or id=="munkidori" else 8.7}

static func slot_id(spec: Dictionary, view: int) -> String:
	var player := int(spec.get("player_index", -1))
	if player not in [0, 1]: return ""
	var side := "my" if player == view else "opp"
	if spec.get("slot_kind", "") == "active": return side + "_active"
	var index := int(spec.get("slot_index", -1))
	if spec.get("slot_kind", "") == "bench" and index >= 0 and index < 8:
		return side + "_bench_%d" % index
	return ""

static func counter_landings(before: Dictionary, after: Dictionary, mine: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var side := "opp_bench_" if mine else "my_bench_"
	for id: String in before.get("slots", {}):
		if not id.begins_with(side): continue
		var old: Dictionary = before.slots[id]
		var now: Dictionary = after.get("slots", {}).get(id, {})
		if old.get("concealed", true) or now.get("concealed", true): continue
		if str(old.get("visual_id", "")) == "" or old.get("visual_id") != now.get("visual_id"): continue
		var amount := int(now.get("damage", 0)) - int(old.get("damage", 0))
		if amount > 0 and amount % 10 == 0:
			result.append({"slot":id, "count":mini(6, amount / 10)})
	return result

func play_attack(card: Dictionary, source: String, targets: Array[String], counters: Array[Dictionary], speed: float) -> bool:
	var style := profile(card)
	if style.is_empty() or style.id in ["munkidori","gardevoir"] or not _valid_slot(source): return false
	var sequence := _summon(style, source, speed)
	sequence.kind = "attack"
	sequence.target = targets[0] if not targets.is_empty() and _valid_slot(targets[0]) else ("opp_active" if source.begins_with("my") else "my_active")
	var defender_id:=Catalog.identify(world.cards.get(sequence.target,{}).get("data",{}))
	if defender_id!="":
		var defender:=Actor.new()
		defender.low_quality = world.low_quality
		sequence.root.add_child(defender)
		defender.build(defender_id)
		defender.stage_directed=true
		sequence.defender=defender
	var impact := Sprite3D.new()
	impact.texture = load("res://assets/textures/vfx/charizard_ex/mid_stream/impact_bloom_flipbook.png" if style.id == "charizard" else "res://assets/textures/vfx/attribute_psychic/source/psychic_impact_bloom.png")
	impact.hframes = 4 if style.id == "charizard" else 1
	impact.pixel_size = 5.0 / (float(impact.texture.get_width()) / impact.hframes)
	impact.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	impact.shaded = false
	impact.render_priority = 4
	impact.visible = false
	sequence.root.add_child(impact)
	sequence.impact = impact
	if style.id == "dragapult":
		var index := 0
		for landing: Dictionary in counters:
			if not _valid_slot(str(landing.slot)): continue
			for i: int in mini(int(landing.count), 6 - index):
				_add_counter(sequence, source, str(landing.slot), index, 1.60 + index * 0.080, 0.43)
				index += 1
	sequences.append(sequence)
	last_outcome = {"kind":"attack", "species":style.id, "source":source, "counters":counters.duplicate(true)}
	played += 1
	return true

func play_transfer(card: Dictionary, caster: String, source: String, target: String, count: int, speed: float) -> bool:
	var style := profile(card)
	if style.get("id", "") != "munkidori" or count < 1 or count > 3: return false
	for id: String in [caster, source, target]:
		if not _valid_slot(id): return false
	var sequence := _summon(style, caster, speed)
	sequence.kind = "transfer"
	sequence.target = target
	for i: int in count:
		_add_counter(sequence, source, target, i, 0.52 + i * 0.13, 1.16)
	sequences.append(sequence)
	last_outcome = {"kind":"transfer", "species":style.id, "caster":caster, "source":source, "target":target, "count":count}
	played += 1
	return true

func play_embrace(cue: Dictionary,speed: float) -> bool:
	if cue.get("species","")!="gardevoir" or not cue.get("public",false):return false
	if not _valid_slot(str(cue.get("caster",""))) or not _valid_slot(str(cue.get("target",""))):return false
	if int(cue.get("energy_count",0))!=1 or int(cue.get("damage",0))!=20:return false
	var style:=profile(cue.get("card",{}))
	if style.get("id","")!="gardevoir":return false
	var sequence:=_summon(style,cue.caster,speed)
	sequence.kind="embrace"
	sequence.target=cue.target
	sequence.cue=cue.duplicate(true)
	sequence.cue.energy_origin=world.side_zones.location("my" if str(cue.caster).begins_with("my") else "opp","discard")+Vector3.UP*.8
	# Rapid repeated embraces queue short pulses, never several overlapping characters.
	var delay:=0.0
	for pending: Dictionary in sequences:delay=maxf(delay,float(pending.get("delay",0))+(float(pending.timing.duration)-float(pending.age))/float(pending.speed))
	sequence.delay=delay
	if delay>0:sequence.speed*=2.0
	sequence.root.visible=delay<=0
	sequences.append(sequence)
	last_outcome={"kind":"embrace","species":"gardevoir","source":cue.caster,"target":cue.target,"energy_count":1,"damage":20}
	played+=1
	return true

func timing() -> Dictionary:
	return Direction.profile(str(last_outcome.get("species","")))

func remaining_time(reveal: bool=false) -> float:
	var remaining:=0.0
	for sequence: Dictionary in sequences:
		remaining=maxf(remaining,float(sequence.get("delay",0))+(float(sequence.timing.settle if reveal else sequence.timing.duration)-float(sequence.age))/float(sequence.speed))
	return maxf(0,remaining)

func _valid_slot(id: String) -> bool:
	return world != null and world.motion_enabled and world.positions.has(id)

func _summon(style: Dictionary, source: String, speed: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "Signature_" + str(style.id)
	add_child(root)
	var actor := Actor.new()
	actor.low_quality = world.low_quality
	root.add_child(actor)
	actor.build(style.id)
	actor.stage_directed=true
	var stage_effect:=StageVfx.new()
	stage_effect.low_quality = world.low_quality
	root.add_child(stage_effect)
	stage_effect.setup()
	var plinth := MeshInstance3D.new()
	var halo := TorusMesh.new()
	halo.inner_radius = 1.40
	halo.outer_radius = 1.44
	halo.rings = 48
	halo.ring_segments = 6
	plinth.mesh = halo
	plinth.material_override = world._material(style.color,1.3)
	root.add_child(plinth)
	plinth.visible=false
	var light := OmniLight3D.new()
	light.light_color = style.color
	light.omni_range = 8.5
	light.light_size = 2.2
	light.light_energy = 0
	light.visible = not world.low_quality
	root.add_child(light)
	# Let actual lights tint the existing felt. An additive floor plane can
	# turn opaque on Compatibility during repeated scene/renderer creation.
	return {"root":root, "actor":actor, "plinth":plinth, "light":light, "stage_effect":stage_effect,"timing":Direction.profile(style.id),"style":style, "source":source, "age":0.0, "speed":speed,"sound_started":false,"delay":0.0,"orbs":[]}

func _add_counter(sequence: Dictionary, source: String, target: String, index: int, delay: float, duration: float) -> void:
	var orb := Node3D.new()
	sequence.root.add_child(orb)
	var bead := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.28
	mesh.radial_segments = 12
	mesh.rings = 6
	bead.mesh = mesh
	bead.material_override = world._material(sequence.style.color, 0.55)
	orb.add_child(bead)
	var aura := Sprite3D.new()
	aura.texture = load("res://assets/textures/vfx/attribute_psychic/source/psychic_charge_orb.png")
	aura.pixel_size = 0.85 / aura.texture.get_width()
	aura.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	aura.modulate = Color(sequence.style.color,0.65)
	orb.add_child(aura)
	var halo := OmniLight3D.new()
	halo.light_color = sequence.style.color
	halo.omni_range = 2.1
	halo.light_energy = 1.7
	halo.visible = not world.low_quality
	orb.add_child(halo)
	var trail: Array[MeshInstance3D] = []
	for j: int in 7:
		var mote := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.026
		tube.bottom_radius = 0.018
		tube.height = 1.0
		tube.radial_segments = 6
		mote.mesh = tube
		mote.material_override = world._material(sequence.style.color, 1.5)
		sequence.root.add_child(mote)
		trail.append(mote)
	sequence.orbs.append({"node":orb, "trail":trail, "source":source, "target":target, "via":sequence.source if sequence.kind == "transfer" else "", "index":index, "delay":delay, "duration":duration})

func _arc(orb: Dictionary, progress: float) -> Vector3:
	var from: Vector3 = world.positions[orb.source] + Vector3(0, 0.24, 0)
	var to: Vector3 = world.positions[orb.target] + Vector3(0, 0.24, 0)
	var bend := (float(orb.index) - 1.0) * 0.28
	if orb.via != "":
		var via: Vector3 = world.positions[orb.via] + Vector3(0,1.4,0)
		if progress < 0.4:
			var t := progress / 0.4
			return from.lerp(via,t) + Vector3(0,sin(PI*t)*0.7,bend)
		var t := (progress-0.4) / 0.6
		return via.lerp(to,t) + Vector3(0,sin(PI*t)*1.5,bend*sin(PI*t))
	return from.lerp(to, progress) + Vector3(sin(PI * progress) * bend, sin(PI * progress) * 2.4, 0)

func _process(delta: float) -> void:
	if world == null: return
	if not world.motion_enabled:
		clear()
		return
	world.signature_focus = 0.0
	world.signature_camera_offset=Vector2.ZERO
	world.signature_roll=0.0
	for i: int in range(sequences.size()-1, -1, -1):
		var sequence: Dictionary = sequences[i]
		if float(sequence.get("delay",0))>0:
			sequence.delay=maxf(0,float(sequence.delay)-delta)
			continue
		sequence.root.visible=true
		if not sequence.sound_started:
			sequence.sound_started=true
			if world.sound_enabled:sequence.actor.play_sound(sequence.speed)
		if not world.sound_enabled and sequence.actor.audio.playing: sequence.actor.audio.stop()
		sequence.age += delta * float(sequence.speed)
		var age: float = sequence.age
		if age >= float(sequence.timing.duration):
			world.invalidate_render()
			sequence.root.queue_free()
			sequences.remove_at(i)
			continue
		var at: Vector3 = world.positions[sequence.source]
		var to: Vector3 = world.positions.get(sequence.target,at+Vector3.FORWARD)
		var direction: Dictionary=Direction.sample(sequence.style.id,age,at,to)
		var hero: Vector3=direction.position
		var strength: float=direction.focus
		if not world.compact_board:
			world.signature_focus=maxf(world.signature_focus,strength*.72)
			world.signature_camera_offset+=Vector2(sin(age*71),cos(age*57))*.31*float(direction.quake)
			world.signature_roll+=sin(age*43)*.011*float(direction.quake)
		if sequence.kind == "attack":
			var target: Vector3 = to
			var impact: Sprite3D = sequence.impact
			var hit_age: float = age-float(sequence.timing.hit)
			impact.visible = sequence.style.id=="charizard" and hit_age >= 0 and hit_age < 0.66
			impact.position = target + Vector3(0,0.9,0)
			impact.frame = mini(impact.hframes-1,int(maxf(0,hit_age)*6.0))
			impact.modulate.a = smoothstep(0,0.06,hit_age)*(1.0-smoothstep(0.28,0.66,hit_age))
			if sequence.style.id != "charizard":
				impact.modulate = Color(sequence.style.color,impact.modulate.a*.45)
			impact.scale = Vector3.ONE * lerpf(0.55,1.18,clampf(hit_age/0.66,0,1))
		var scale_value: float=direction.visibility
		var actor: Node3D = sequence.actor
		actor.position = hero
		actor.visible=scale_value>.015
		actor.scale = Vector3.ONE * maxf(.001,scale_value) * float(direction.scale)
		actor.rotation=Vector3(direction.pitch,direction.yaw,direction.roll)
		if sequence.style.id=="gardevoir":
			var facing: float=0.0 if str(sequence.source).begins_with("opp") else PI
			actor.rotation.y=lerp_angle(facing,float(direction.yaw),.50)
		if sequence.style.id=="garchomp":
			# Fly around the torso's center, not around the original feet on the card.
			var flying:=smoothstep(.30,.55,age)*(1-smoothstep(2.7,3.13,age))
			actor.position+=(Vector3.UP*1.75-actor.basis*Vector3(0,1.75,0))*flying
		actor.target_local = actor.to_local(to+Vector3(0,.45,0))
		actor.pose(direction.clip_age)
		sequence.stage_effect.sample_stage(sequence.style.id,age,at,to,hero,sequence.get("cue",{}))
		if sequence.has("defender"):
			var defender: Node3D=sequence.defender
			var reaction_age: float=age-float(sequence.timing.hit)
			var envelope:=smoothstep(.18,.42,age)*(1-smoothstep(sequence.timing.settle-.15,sequence.timing.duration-.14,age))
			var recoil:=smoothstep(0,.055,reaction_age)*(1-smoothstep(.10,.66,reaction_age))
			defender.visible=envelope>.01
			defender.scale=Vector3.ONE*maxf(.001,envelope)*.92
			var away: Vector3=(to-at).normalized()
			defender.position=to+away*recoil*.75+Vector3.UP*(.16+recoil*.16)
			defender.rotation=Vector3(-recoil*.24,atan2(-away.x,-away.z),sin(age*35)*recoil*.08)
			defender.performance.visible=false
			defender.pose(age,false)
		sequence.plinth.position = at+Vector3(0,.05,0)
		sequence.plinth.scale = Vector3.ONE*maxf(.001,scale_value)
		sequence.light.position = at + Vector3(0, 2.8, 0)
		sequence.light.light_energy = strength * (1.3 if sequence.style.id == "charizard" else .8)+float(direction.flash)*5
		for orb: Dictionary in sequence.orbs:
			var progress := (age - float(orb.delay)) / float(orb.duration)
			orb.node.visible = progress >= 0 and progress <= 1.0
			if orb.node.visible: orb.node.position = _arc(orb, progress)
			for j: int in orb.trail.size():
				var mote: MeshInstance3D = orb.trail[j]
				var p := progress - 0.035 * (j + 1)
				mote.visible = progress >= 0 and progress <= 1.18 and p >= 0 and p <= 1.0
				if mote.visible:
					var a := _arc(orb,p)
					var b := _arc(orb,minf(p+0.042,1.0))
					mote.position = (a+b)*0.5
					if a.distance_to(b) > 0.001: mote.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
					mote.scale = Vector3(1.0-j*0.10,a.distance_to(b),1.0-j*0.10)

func covers_card(id: String) -> bool:
	for sequence: Dictionary in sequences:
		if float(sequence.get("delay",0))>0 or sequence.age >= float(sequence.timing.settle): continue
		if id == sequence.source or id == sequence.target: return true
		if sequence.kind == "transfer" and not sequence.orbs.is_empty() and id == sequence.orbs[0].source: return true
		var at: Vector3 = sequence.actor.global_position + Vector3(0,2.2,0)
		var center: Vector2 = world.project(at)
		var radius: float = center.distance_to(world.project(at + world.camera.global_basis.x * float(sequence.style.size) * 0.30))
		if Rect2(center-Vector2(radius,radius),Vector2.ONE*radius*2).intersects(world.card_screen_rect(id)): return true
	return false

func clear() -> void:
	if is_instance_valid(world): world.invalidate_render()
	if world != null:
		world.signature_focus = 0.0
		world.signature_camera_offset=Vector2.ZERO
		world.signature_roll=0.0
	for sequence: Dictionary in sequences:
		if is_instance_valid(sequence.root): sequence.root.queue_free()
	sequences.clear()
