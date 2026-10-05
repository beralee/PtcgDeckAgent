extends Control
## Choreographs copied public frames. Never owns a legal choice or engine state.
signal busy_changed(value: bool)
var world: Node3D
var shown: Dictionary = {}
var hold := 0.0
var busy_time := 0.0
var ability_animation_active := false
var was_enabled := true
var event_count := 0
var attack_count := 0
var vfx := preload("res://scripts/ui/battle/BattleAttackVfxController.gd").new()
var transient_nodes: Array[Node] = []
var overlay_tweens: Array[Tween] = []
var knockouts: Array[Dictionary] = []
var hit_damage := 0
var fast_enabled := false
var arrival_origins: Dictionary = {}
var hand_transfer: Control
var last_embrace_key := ""
var embrace_repeats := 0
var reward_queue: Array[Dictionary] = []
var reward_history: Array[int] = []
var reward_chain := [0,0]

func _ready() -> void:
	fast_enabled = preload("res://scenes/arena3d/ArenaTheme.gd").option("fast",false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 25
	resized.connect(clear)

func is_busy() -> bool:
	return busy_time > 0 or not reward_queue.is_empty() or (is_instance_valid(hand_transfer) and hand_transfer.is_busy())

func allows_live_actions_during_ability() -> bool:
	return ability_animation_active and busy_time > 0 and reward_queue.is_empty() and (
		not is_instance_valid(hand_transfer) or not hand_transfer.is_busy()
	)

func _process(delta: float) -> void:
	if world == null: return
	world.motion_speed = 1.8 if fast_enabled else 1.0
	if was_enabled and not world.motion_enabled: clear()
	was_enabled = world.motion_enabled
	hold = maxf(0,hold-delta)
	if busy_time > 0:
		busy_time = maxf(0,busy_time-delta)
		if busy_time == 0: ability_animation_active = false
		if busy_time == 0 and not is_busy(): busy_changed.emit(false)
	if not reward_queue.is_empty() and busy_time == 0 and hold == 0 and (not is_instance_valid(hand_transfer) or not hand_transfer.is_busy()):
		var reward: Dictionary = reward_queue.pop_front()
		var celebration := preload("res://scenes/arena3d/ArenaPrizeCelebration.gd").new()
		celebration.count = reward.total
		celebration.batch = reward.batch
		celebration.mine = reward.mine
		celebration.duration = (1.65+.13*reward.total)/(1.8 if fast_enabled else 1.0)
		add_child(celebration)
		transient_nodes.append(celebration)
		busy_time = celebration.duration
		reward_history.append(reward.total)
		world._play_sound("evolve")
	transient_nodes = transient_nodes.filter(func(node): return is_instance_valid(node))
	overlay_tweens = overlay_tweens.filter(func(tween): return tween != null and tween.is_valid())

func clear() -> void:
	var busy := is_busy()
	if is_instance_valid(hand_transfer): hand_transfer.clear()
	for tween: Tween in overlay_tweens:
		if tween != null and tween.is_valid(): tween.kill()
	overlay_tweens.clear()
	for child in get_children(): child.queue_free()
	transient_nodes.clear()
	knockouts.clear()
	reward_queue.clear()
	arrival_origins.clear()
	hit_damage = 0
	hold = 0
	busy_time = 0
	ability_animation_active = false
	if world != null: world.clear_effects()
	if busy: busy_changed.emit(false)

func _tween() -> Tween:
	var tween := create_tween().set_speed_scale(1.8 if fast_enabled else 1.0)
	overlay_tweens.append(tween)
	return tween

func present(frame: Dictionary, allow_hold: bool = true) -> Dictionary:
	# A hotseat handover changes the meaning of my/opp everywhere at once.
	# Never hold or animate the former viewer's piles under the new buttons.
	if not shown.is_empty() and frame.get("view",0) != shown.get("view",0):
		clear()
		shown = frame.duplicate(true)
		world.display(shown)
		return shown
	if allow_hold and hold > 0 and not shown.is_empty(): return shown
	if frame == shown: return shown
	var before := shown
	shown = frame.duplicate(true)
	world.display(shown)
	if before.is_empty() or not world.motion_enabled: return shown
	var old_slots: Dictionary = before.get("slots",{}).duplicate()
	var new_slots: Dictionary = frame.get("slots",{}).duplicate()
	if not before.get("stadium_card",{}).is_empty(): old_slots.stadium = before.stadium_card
	if not frame.get("stadium_card",{}).is_empty(): new_slots.stadium = frame.stadium_card
	var changed_slots: Dictionary = old_slots.duplicate()
	changed_slots.merge(new_slots,true)
	for id: String in changed_slots:
		var old: Dictionary = old_slots.get(id,{"empty":true})
		var now: Dictionary = new_slots.get(id,{"empty":true})
		var knocked := false
		for index in range(knockouts.size()):
			var entry: Dictionary = knockouts[index]
			if id.begins_with(entry.side) and old.get("name","") == entry.name and (id.ends_with("active") or old != now):
				knockouts.remove_at(index)
				knocked = true
				break
		if knocked:
			if hit_damage > 0: float_text(id,"−"+str(hit_damage),Color("fff2db"),46)
			depart(id,old,true)
			world._play_sound("impact")
		if old == now: continue
		if not old.get("empty",true) and now.get("empty",true):
			# A move is not a knockout: match only unambiguous public card faces.
			var moved := false
			for other: String in new_slots:
				if other != id and _identity(new_slots[other]) != "" and _identity(new_slots[other]) == _identity(old):
					moved = true
			if not moved and not knocked:
				depart(id,old)
			continue
		if now.get("empty",true) or now.get("concealed",false): continue
		if old.get("empty",true) or _identity(old) != _identity(now):
			var evolution: bool = not old.get("empty",true) and int(now.get("evolution",1)) > int(old.get("evolution",1))
			var origin: Vector3 = arrival_origins.get(_identity(now),Vector3.ZERO)
			arrival_origins.erase(_identity(now))
			for other: String in old_slots:
				if other != id and _identity(old_slots[other]) == _identity(now) and _identity(new_slots.get(other,{})) != _identity(now):
					origin = world.positions.get(other,Vector3.ZERO)
			world.animate_card(id,"evolve" if evolution else "arrive",origin)
			if evolution:
				float_text(id,"进化",Color("b9f5ec"),25)
				world._play_sound("evolve")
			else: world._play_sound("card")
			if evolution: halo(id,Color("9bf2de"))
		if not old.get("empty",true) and _identity(old) == _identity(now):
			var damage: int = int(old.get("hp",0)) - int(now.get("hp",0))
			if damage != 0:
				world.animate_card(id,"damage" if damage > 0 else "evolve")
				float_text(id,("−" if damage > 0 else "+") + str(absi(damage)),Color("fff2db") if damage > 0 else Color("91f6b7"),46)
				world._play_sound("impact" if damage > 0 else "card")
			if now.get("tool",false) and now.get("tool_image","") != old.get("tool_image",""):
				world.fly_card(preload("res://scenes/arena3d/ArenaCardBacks.gd").for_side(id.begins_with("my")),Vector3(0,1,11 if id.begins_with("my") else -11),world.positions[id],.55,true)
				halo(id,Color("f5d583"))
		var energy_delta: int = now.get("energy",[]).size()-old.get("energy",[]).size()
		if energy_delta > 0:
			attach_energy(id,now.get("type","C"),energy_delta)
			event_count += 1
	if frame.get("turn",0) != before.get("turn",0) and frame.get("turn",0) > 0:
		banner("你的回合" if frame.current == frame.view else "对手回合",Color("b2efd8") if frame.current == frame.view else Color("ecc6b8"))
	hit_damage = 0
	return shown

func _identity(card: Dictionary) -> String:
	return str(card.get("visual_id",card.get("uid","")))

func start_attack(mine: bool, attribute: String, title: String, target_ids: Array[String], damage: int = 0, counters: Array[Dictionary] = []) -> void:
	if not world.motion_enabled: return
	var source_id := "my_active" if mine else "opp_active"
	var source: Vector2 = get_global_transform() * world.project(world.positions[source_id])
	var targets: Array = []
	for id: String in target_ids:
		if world.positions.has(id): targets.append({"position":get_global_transform() * world.project(world.positions[id]),"anchor":null,"impact_style":"damage"})
	if targets.is_empty(): targets.append({"position":get_global_transform() * world.project(world.positions["opp_active" if mine else "my_active"]),"anchor":null,"impact_style":"damage"})
	world.animate_card(source_id,"attack")
	var speed := 1.8 if fast_enabled else 1.0
	# All targets share the authored choreography; portable actors use baked LODs.
	var signature: bool = world.signature_vfx.play_attack(shown.get("slots",{}).get(source_id,{}),source_id,target_ids,counters,speed)
	if not signature:
		world._play_sound("charge")
		vfx.play_projected_vfx(self,attribute,source,targets,world.card_screen_rect(source_id).size.x,speed)
	var light_targets: Array[String] = target_ids.duplicate()
	if light_targets.is_empty(): light_targets.append("opp_active" if mine else "my_active")
	var timing: Dictionary=world.signature_vfx.timing() if signature else {"hit":.30,"settle":.44,"duration":.95}
	world.dynamics.flash_targets(light_targets,attribute,timing.hit,speed)
	hold = float(timing.settle) / speed
	hit_damage = damage
	busy_time = float(timing.duration) / speed
	ability_animation_active = false
	busy_changed.emit(true)
	attack_count += 1
	banner(title if title != "" else "攻击",world.COLORS.get(attribute,Color.WHITE),float(timing.settle) if signature else .42)

func start_counter_transfer(card: Dictionary, caster: String, source: String, target: String, count: int, title: String) -> bool:
	if not world.motion_enabled: return false
	var speed := 1.8 if fast_enabled else 1.0
	if not world.signature_vfx.play_transfer(card,caster,source,target,count,speed): return false
	ability_animation_active = busy_time <= 0 or ability_animation_active
	hold = world.signature_vfx.remaining_time(true)
	busy_time = maxf(busy_time, world.signature_vfx.remaining_time())
	busy_changed.emit(true)
	var targets: Array[String] = [target]
	world.dynamics.flash_targets(targets,"P",1.90,speed)
	banner(title + " · %d 个伤害指示物" % count,Color("dbb6ff"),2.20)
	return true

func start_psychic_embrace(cue: Dictionary) -> bool:
	if not world.motion_enabled:return false
	if cue.get("species","") != "gardevoir" or not cue.get("public",false): return false
	var key := "%s:%s" % [cue.get("turn",-1),cue.get("card",{}).get("visual_id","")]
	if key == last_embrace_key and world.positions.has(str(cue.get("target",""))):
		# The first activation shows the model. Repeated legal attachments in
		# this turn use a short target pulse and immediately expose fresh choices.
		embrace_repeats += 1
		halo(cue.target,Color("efbce9"))
		float_text(cue.target,"超能量 +1",Color("efbce9"),28)
		world._play_sound("card")
		return true
	var speed:=1.8 if fast_enabled else 1.0
	if not world.signature_vfx.play_embrace(cue,speed):return false
	ability_animation_active = busy_time <= 0 or ability_animation_active
	last_embrace_key = key
	hold=world.signature_vfx.remaining_time(true)
	busy_time=maxf(busy_time, world.signature_vfx.remaining_time())
	busy_changed.emit(true)
	banner(str(cue.get("title","精神拥抱"))+" · 超能量 +1 / 指示物 +2",Color("efbce9"),2.20)
	return true

func queue_prize_reward(owner: int, count: int, mine: bool) -> void:
	if count <= 0 or owner not in [0,1] or not world.motion_enabled: return
	ability_animation_active = false
	reward_chain[owner] = mini(6,int(reward_chain[owner])+count)
	reward_queue.append({"total":reward_chain[owner],"batch":count,"mine":mine})
	busy_changed.emit(true)

func start_supporter(cue: Dictionary) -> bool:
	if world == null or not world.motion_enabled: return false
	var speed := 1.8 if fast_enabled else 1.0
	if not world.supporter_vfx.play(cue,speed): return false
	# Keep the copied pre-effect board while the motif resolves. Existing hand
	# movement queues then resume, using their own anonymous count-only payloads.
	hold = world.supporter_vfx.resolution_time() / speed
	busy_time = world.supporter_vfx.duration() / speed
	ability_animation_active = false
	busy_changed.emit(true)
	return true

func float_text(id: String, value: String, color: Color, font_size: int, vertical_offset: float = 0) -> void:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",Color(.025,.035,.04,.96))
	label.add_theme_constant_override("outline_size",7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(240,64)
	label.position = world.project(world.positions[id]) - Vector2(120,40)
	label.position.y += vertical_offset
	label.pivot_offset = label.size*.5
	label.scale = Vector2(.6,.6)
	add_child(label)
	transient_nodes.append(label)
	var tween := _tween()
	tween.tween_property(label,"scale",Vector2.ONE,.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label,"position:y",label.position.y-26,.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(.18)
	tween.tween_property(label,"modulate:a",0,.22)
	tween.tween_callback(label.queue_free)
	event_count += 1

func banner(value: String, color: Color = Color.WHITE, duration: float = .42) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",23)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",Color("081013"))
	label.add_theme_constant_override("outline_size",8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(330,44)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(24,world.screen_origin.y+44)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("101e1b",.94)
	plate.border_color = color
	plate.border_width_left = 3
	plate.content_margin_left = 12
	plate.content_margin_right = 12
	plate.set_corner_radius_all(5)
	label.add_theme_stylebox_override("normal",plate)
	label.modulate.a = 0
	add_child(label)
	transient_nodes.append(label)
	var tween := _tween()
	tween.tween_property(label,"modulate:a",1,.1)
	tween.tween_interval(duration)
	tween.tween_property(label,"modulate:a",0,.18)
	tween.tween_callback(label.queue_free)

func halo(id: String, color: Color) -> void:
	var rect: Rect2 = world.card_screen_rect(id).grow(6)
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = rect.position
	frame.size = rect.size
	frame.pivot_offset = rect.size*.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color,.04)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(color,.3)
	style.shadow_size = 18
	frame.add_theme_stylebox_override("panel",style)
	add_child(frame)
	transient_nodes.append(frame)
	var tween := _tween().set_parallel(true)
	tween.tween_property(frame,"scale",Vector2(1.16,1.16),.5)
	tween.tween_property(frame,"modulate:a",0,.5)
	tween.chain().tween_callback(frame.queue_free)

func attach_energy(id: String, attribute: String, count: int) -> void:
	var target: Vector2 = world.project(world.positions[id])
	var start := Vector2(size.x*.5,size.y+30) if id.begins_with("my") else Vector2(size.x*.5,-30)
	var color: Color = world.COLORS.get(attribute,Color.WHITE)
	var orb := Label.new()
	orb.text = "+%d" % count
	orb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	orb.add_theme_font_size_override("font_size",22)
	orb.add_theme_color_override("font_color",Color("101a24"))
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.size = Vector2(42,42)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(21)
	style.shadow_color = Color(color,.45)
	style.shadow_size = 16
	orb.add_theme_stylebox_override("normal",style)
	orb.position = start
	add_child(orb)
	transient_nodes.append(orb)
	var tween := _tween()
	tween.tween_method(func(t: float): orb.position = start.lerp(target-Vector2(21,21),t)+Vector2(sin(t*PI)*65,0),0.0,1.0,.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		world.animate_card(id,"energy")
		halo(id,color)
		world._play_sound("card")
	)
	tween.tween_property(orb,"modulate:a",0,.12)
	tween.tween_callback(orb.queue_free)

func depart(id: String, old: Dictionary, knocked: bool = false) -> void:
	if old.get("concealed",false): return
	if knocked:
		ability_animation_active = false
		busy_time = maxf(busy_time,.65)
		busy_changed.emit(true)
	var path: String = old.get("image","")
	if not world.texture_cache.has(path): return
	world.fly_card(world.texture_cache[path],world.positions[id],world.side_zones.location("my" if id.begins_with("my") else "opp","discard")+Vector3(0,.7,0),.65,true)
	float_text(id,"击倒" if knocked else "离场",Color("ffd0a3"),27,45)
	event_count += 1
func zone_flight(mine: bool, prize: bool) -> void:
	if not world.motion_enabled: return
	var start3d: Vector3 = world.prize_position(1,mine) if prize else world.side_zones.location("my" if mine else "opp","deck")+Vector3(0,.7,0)
	world.fly_card(preload("res://scenes/arena3d/ArenaCardBacks.gd").for_side(mine),start3d,Vector3(0,1,11 if mine else -11),.65,false)
	world._play_sound("card")
	if prize: banner("领取奖赏",Color("f6d688"))
	event_count += 1

