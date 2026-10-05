extends Node3D
## Physical public board hardware and lighting. No gameplay state is retained.
var world: Node3D
var frame: Dictionary = {}
var rewards: Array[Dictionary] = []
var lamps: Array[OmniLight3D] = []
var reward_ready := false
var clock := 0.0
var theme_id := ""
var particles: GPUParticles3D
var hit_lights: Array[OmniLight3D] = []
var reward_light: OmniLight3D
var hover_light: OmniLight3D
var reward_motes: GPUParticles3D
var last_reward_key: Array = []
var rewards_settled := false

func _ready() -> void:
	var module: PackedScene = load("res://assets/arena3d/portable/reward_cradle.glb" if world.low_quality else "res://assets/arena3d/product-v5/reward_cradle.glb")
	for mine in [false,true]:
		for index in range(6):
			var cradle: Node3D = module.instantiate()
			add_child(cradle)
			var back: MeshInstance3D = world._card_body(1.18,1.68,.055,.075,Color("25364a"))
			add_child(back)
			var face := MeshInstance3D.new()
			face.mesh = world._rounded_mesh(1.18,1.68,.075)
			var mat := StandardMaterial3D.new()
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_texture = preload("res://scenes/arena3d/ArenaCardBacks.gd").for_side(mine)
			mat.albedo_color = Color(.73,.73,.73)
			mat.roughness = .62
			mat.metallic = .2
			face.material_override = mat
			face.position.y = .0285
			back.add_child(face)
			rewards.append({"mine":mine,"index":index,"cradle":cradle,"card":back,"face":face})
	if world.low_quality: return
	for side in [-1,1]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(side*8,3.0,0)
		lamp.omni_range = 12
		lamp.light_energy = 1.2
		lamp.light_size = 3
		lamp.shadow_enabled = true
		add_child(lamp)
		lamps.append(lamp)
	for i in range(2):
		var lamp := OmniLight3D.new()
		lamp.light_energy = 0
		lamp.omni_range = 9
		lamp.light_size = .8
		add_child(lamp)
		hit_lights.append(lamp)
	particles = GPUParticles3D.new()
	particles.amount = 38
	particles.lifetime = 8
	particles.preprocess = 6
	particles.visibility_aabb = AABB(Vector3(-25,-1,-10),Vector3(50,8,20))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(18,1,7)
	process.gravity = Vector3(0,.08,0)
	process.initial_velocity_min = .04
	process.initial_velocity_max = .18
	process.direction = Vector3(0,1,0)
	process.scale_min = .4
	process.scale_max = 1.0
	particles.process_material = process
	var mote := SphereMesh.new()
	mote.radius = .023
	mote.height = .046
	mote.radial_segments = 6
	mote.rings = 3
	mote.material = world._material(Color("6bd2f1"),1.8)
	particles.draw_pass_1 = mote
	particles.position.y = .5
	add_child(particles)
	reward_light = OmniLight3D.new()
	reward_light.light_color = Color("ffd678")
	reward_light.omni_range = 6.5
	reward_light.light_size = 1
	add_child(reward_light)
	hover_light = OmniLight3D.new()
	hover_light.omni_range = 4
	hover_light.light_size = .6
	add_child(hover_light)
	reward_motes = particles.duplicate() as GPUParticles3D
	reward_motes.amount = 18
	reward_motes.lifetime = 2.4
	reward_motes.preprocess = 0
	reward_motes.process_material = process.duplicate()
	reward_motes.process_material.emission_box_extents = Vector3(1.8,.1,1.2)
	reward_motes.process_material.initial_velocity_min = .4
	reward_motes.process_material.initial_velocity_max = .9
	reward_motes.draw_pass_1 = mote.duplicate()
	reward_motes.draw_pass_1.material = world._material(Color("ffd778"),2.5)
	add_child(reward_motes)

func flash_targets(ids: Array[String], attribute: String, delay: float, speed: float) -> void:
	if not world.motion_enabled: return
	for i in range(mini(hit_lights.size(),ids.size())):
		var light := hit_lights[i]
		light.position = world.positions.get(ids[i],Vector3.ZERO)+Vector3(0,1.3,0)
		light.light_color = world.COLORS.get(attribute,Color.WHITE)
		var tween: Tween = world._effect_tween()
		tween.set_speed_scale(speed)
		tween.tween_interval(delay)
		tween.tween_property(light,"light_energy",9.0,.045)
		tween.tween_property(light,"light_energy",0.0,.38).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func clear() -> void:
	for light in hit_lights: light.light_energy = 0

func _tint(node: Node, accent: Color) -> void:
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var original: Material = node.mesh.surface_get_material(surface)
			if original is StandardMaterial3D and "Status light" in original.resource_name:
				var material := original.duplicate() as StandardMaterial3D
				material.albedo_color = accent
				material.emission = accent
				material.emission_enabled = true
				material.emission_energy_multiplier = 1.5
				node.set_surface_override_material(surface,material)
	for child in node.get_children(): _tint(child,accent)

func _process(delta: float) -> void:
	if world.low_quality:
		clock += delta if world.motion_enabled else 0.0
		_update_rewards(delta)
		return
	clock += delta if world.motion_enabled else 0.0
	if theme_id != world.theme_id:
		theme_id = world.theme_id
		var accent := Color(world.ThemeScript.palette(theme_id).accent)
		for entry in rewards: _tint(entry.cradle,accent)
		for lamp in lamps: lamp.light_color = accent
		particles.draw_pass_1.material = world._material(accent,1.8)
	particles.emitting = world.motion_enabled and not world.low_quality
	particles.visible = particles.emitting
	var reward_at: Vector3 = world.prize_position(1,true)+Vector3(0,.2,1.0)
	reward_light.position = reward_at+Vector3(0,1.5,0)
	reward_light.light_energy = (3.8+.5*sin(clock*2.4)) if reward_ready else 0.0
	reward_motes.position = reward_at
	reward_motes.emitting = reward_ready and world.motion_enabled and not world.low_quality and not world.compact_board
	reward_motes.visible = reward_motes.emitting
	var hovered: Dictionary = world.cards.get(world.hover_id,{})
	var hover_target := 0.0
	if not hovered.is_empty() and not hovered.data.get("empty",true) and not hovered.data.get("concealed",false):
		hover_light.position = hovered.node.position+Vector3(0,1,0)
		hover_light.light_color = world.COLORS.get(hovered.data.get("type","C"),Color.WHITE)
		hover_target = 1.4
	hover_light.light_energy = lerpf(hover_light.light_energy,hover_target,1-exp(-delta*12))
	for i in range(lamps.size()):
		lamps[i].light_color = Color(world.ThemeScript.palette(theme_id).accent).lerp(world.stadium_surface.accent,world.stadium_surface.presence*.82)
		lamps[i].position.x = (-1 if i == 0 else 1)*(world.camera.size*.27)+sin(clock*.30+i)*2.0
		lamps[i].position.z = sin(clock*.43+i*PI)*5.2
		lamps[i].light_energy = 1.55 + (.4*sin(clock*.8+i) if world.motion_enabled else 0.0)
	for material: ShaderMaterial in world.stadium_surface.materials:
		material.set_shader_parameter("lamp_a",lamps[0].position)
		material.set_shader_parameter("lamp_b",lamps[1].position)
		material.set_shader_parameter("lamp_tint",lamps[0].light_color)
	world.key.rotation_degrees.y = -32+sin(clock*.18)*8
	_update_rewards(delta)

func _update_rewards(delta: float) -> void:
	if world.low_quality:
		var key: Array = [world.display_size(),world.camera.size,world.compact_board,world.portrait_board,
			world.bench_counts.my,world.bench_counts.opp,frame.get("players",[]),frame.get("view",0),reward_ready]
		if not reward_ready and rewards_settled and key == last_reward_key: return
		last_reward_key = key
	rewards_settled = true
	for entry in rewards:
		var at: Vector3 = world.prize_position(entry.index,entry.mine)
		var scale_value: float = world.prize_width()/1.18
		var stacked: bool = world.compact_board and world.portrait_board
		var cradle_at := Vector3(at.x+(.45 if stacked and entry.index == 0 else 0.0),.21,at.z)
		var cradle_scale := Vector3(scale_value*(1.8 if stacked and entry.index == 0 else 1.0),1,scale_value)
		# Never reset to the narrow scale before applying the stacked width:
		# that enqueues descendant/renderer transforms on every otherwise idle frame.
		if entry.cradle.position != cradle_at: entry.cradle.position = cradle_at
		if entry.cradle.scale != cradle_scale: entry.cradle.scale = cradle_scale
		var occupied := false
		if frame.get("players",[]).size() == 2:
			var player: Dictionary = frame.players[frame.view if entry.mine else 1-frame.view]
			var slots: Array = player.get("prize_slots",[])
			occupied = bool(slots[entry.index]) if slots.size() == 6 else entry.index < player.prizes
		entry.card.visible = occupied
		entry.cradle.visible = not stacked or entry.index == 0
		var ready: bool = reward_ready and entry.mine and occupied
		if ready: world.invalidate_render()
		var lift := .20 if ready else 0.0
		if ready and world.motion_enabled: lift += .10*(sin(clock*2.4+entry.index*.35)+1)
		var destination := Vector3(at.x,at.y-.08+lift,at.z)
		if occupied and entry.card.position.distance_squared_to(destination) > .000001:
			rewards_settled = false
			entry.card.position = entry.card.position.lerp(destination,1-exp(-delta*12))
			world.invalidate_render()
		elif entry.card.position != destination: entry.card.position = destination
		var card_scale := Vector3.ONE*scale_value
		if entry.card.scale != card_scale: entry.card.scale = card_scale
		var tilt := -.10 if ready else 0.0
		if entry.card.rotation.x != tilt: entry.card.rotation.x = tilt
		if not entry.has("ready_style") or bool(entry.ready_style) != ready:
			entry.ready_style = ready
			var material: StandardMaterial3D = entry.face.material_override
			material.emission_enabled = ready
			material.emission = Color("f3cd78")
			material.emission_energy_multiplier = .28 if ready else 0.0
