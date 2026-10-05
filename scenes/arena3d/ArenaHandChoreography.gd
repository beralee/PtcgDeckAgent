extends Control
## Transparent full-window 3D flights. Inputs are anonymous public counts only.
signal busy_changed(value: bool)
const Backs := preload("res://scenes/arena3d/ArenaCardBacks.gd")
const Platform := preload("res://scenes/arena3d/ArenaPlatform.gd")
var quality_high := false
var presenter: Control
var battle: Control
var viewport: SubViewport
var camera: Camera3D
var space: Node3D
var caption: Label
var pending: Array[Dictionary] = []
var active := false
var flush_queued := false
var generation := 0
var active_view := -1
var tween: Tween
var moving: Array[Dictionary] = []
var history: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var phase := ""
var hidden_draw_count := 0
var hidden_cards: Array[Control] = []

func _ready() -> void:
	name = "ArenaHandTransfers"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 35
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	quality_high = presenter.quality_high
	viewport.msaa_3d = Platform.msaa(quality_high)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	space = Node3D.new()
	viewport.add_child(space)
	camera = Camera3D.new()
	camera.fov = 40
	# Pixel-space cards sit hundreds of units from the camera. A tiny near
	# plane loses enough depth precision to stripe the face against its body.
	camera.near = 50
	camera.far = 10000
	camera.current = true
	viewport.add_child(camera)
	var display := TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.texture = viewport.get_texture()
	add_child(display)
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size",22)
	caption.add_theme_color_override("font_color",Color("e6f3fb"))
	caption.add_theme_color_override("font_outline_color",Color("0a1724"))
	caption.add_theme_constant_override("outline_size",7)
	add_child(caption)
	resized.connect(func(): clear(); _resize())
	_resize()
	hide()

func _resize() -> void:
	viewport.size = Platform.render_size(size,2560 if quality_high else Platform.LOW_RENDER_EDGE)
	camera.position.z = maxf(1,size.y/(2*tan(deg_to_rad(20))))
	caption.position = Vector2(size.x*.5-300,size.y*.44)
	caption.size = Vector2(600,40)

func configure_quality(high: bool) -> void:
	if quality_high == high: return
	quality_high = high
	viewport.msaa_3d = Platform.msaa(high)
	_resize()

func is_busy() -> bool: return active or not pending.is_empty()

func enqueue(events: Array[Dictionary]) -> void:
	if events.is_empty() or not presenter.world.motion_enabled: return
	if active_view != -1 and active_view != int(battle.get("_view_player")): clear()
	active_view = int(battle.get("_view_player"))
	var was_busy := is_busy()
	for event in events:
		pending.append(event.duplicate())
		if bool(event.mine):
			if event.direction == "return": battle.get("_hand_scroll").modulate.a = 0
			elif event.direction == "draw": hidden_draw_count += int(event.count)
	if not was_busy: busy_changed.emit(true)
	if not active and not flush_queued:
		flush_queued = true
		call_deferred("_flush",generation)

func _flush(expected: int) -> void:
	if expected != generation: return
	flush_queued = false
	# An attack can end its engine turn before its visual outcome lands. Keep
	# the following draw queued until the board's presentation clock releases.
	if presenter.motion.busy_time > 0 or presenter.motion.hold > 0: return
	if pending.is_empty() or not presenter.world.motion_enabled:
		clear()
		return
	var outward: Array[Dictionary] = []
	var inward: Array[Dictionary] = []
	for event in pending:
		var target: Array[Dictionary] = inward if event.direction == "draw" else outward
		var merged := false
		for same in target:
			if same.mine == event.mine and same.direction == event.direction:
				same.count += event.count
				merged = true
				break
		if not merged: target.append(event.duplicate())
	pending.clear()
	active = true
	show()
	_mask_drawn_cards()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if not outward.is_empty(): _play_phase(outward,func(): _play_phase(inward,_finish))
	else: _play_phase(inward,_finish)

func _hand_point(mine: bool, index: int, count: int) -> Vector2:
	var rect: Rect2 = battle.get("_hand_scroll").get_global_rect()
	var spread := minf(size.x*.60, maxf(0,count-1)*_height()*.52)
	var t := float(index)/maxi(1,count-1)-.5 if count > 1 else 0.0
	return Vector2(size.x*.5+t*spread,rect.get_center().y if mine else 24+t*t*25)

func _pile_point(mine: bool, discard: bool = false) -> Vector2:
	var at: Vector3 = presenter.world.side_zones.location("my" if mine else "opp","discard" if discard else "deck")
	return presenter.get_global_transform()*presenter.world.project(at)

func _height() -> float: return clampf(size.y*.145,106,165)

func _point(at: Vector2, depth: float = 0) -> Vector3:
	return Vector3(at.x-size.x*.5,size.y*.5-at.y,depth)

func _play_phase(events: Array[Dictionary], finished: Callable) -> void:
	_clear_cards()
	if events.is_empty():
		finished.call()
		return
	var draw: bool = events[0].direction == "draw"
	if draw: battle.get("_hand_scroll").modulate.a = 1
	phase = "deal" if draw else "collect"
	var total := 0
	var max_cards := 1
	for event in events:
		history.append(event.duplicate())
		if history.size() > 24: history.pop_front()
		total += int(event.count)
		var count := mini(12,int(event.count))
		max_cards = maxi(max_cards,count)
		for i in range(count):
			var node: MeshInstance3D = presenter.world._card_body(_height()*.716,_height(),2.0,_height()*.035,Color("233447"))
			space.add_child(node)
			var face := MeshInstance3D.new()
			face.mesh = presenter.world._rounded_mesh(_height()*.716,_height(),_height()*.035)
			face.position.y = 1.1
			var material := StandardMaterial3D.new()
			material.albedo_texture = Backs.for_side(bool(event.mine))
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
			face.material_override = material
			node.add_child(face)
			node.rotation.x = PI*.5
			var hand := _hand_point(bool(event.mine),i,count)
			var hand_cards: Control = battle.get("_hand_container")
			if draw and event.mine and count <= hand_cards.get_child_count():
				var card: Control = hand_cards.get_child(hand_cards.get_child_count()-count+i)
				hand = card.get_global_transform()*(card.size*.5)
			var pile := _pile_point(bool(event.mine),event.direction == "discard")
			var fan := (float(i)/maxi(1,count-1)-.5)*.20
			moving.append({"node":node,"hand":hand,"pile":pile,"mine":event.mine,"index":i,"count":count,"fan":fan,"draw":draw})
			trails.append({"points":PackedVector2Array(),"color":Color("89cfeb") if event.mine else Color("e8c27d")})
	caption.text = ("抽取手牌" if draw else "手牌回库" if events[0].direction == "return" else "整理手牌")+"  ·  %d 张"%total
	presenter.world._play_sound("card")
	var duration := 1.05 + (max_cards-1)*.035
	tween = create_tween().set_speed_scale(1.8 if presenter.motion.fast_enabled else 1.0)
	tween.tween_method(_pose,0.0,duration,duration)
	tween.tween_callback(finished)

func _pose(clock: float) -> void:
	for entry in moving:
		var t := clampf((clock-float(entry.index)*.035)/1.05,0,1)
		var node: Node3D = entry.node
		var hand: Vector2 = entry.hand
		var pile: Vector2 = entry.pile
		var center := _hand_point(bool(entry.mine),0,1)
		var at: Vector2
		var depth := 0.0
		if entry.draw:
			var q := smoothstep(0,1,t)
			var control := (pile+hand)*.5 + Vector2(-size.x*.12,-85 if entry.mine else 85)
			at = pile.lerp(control,q).lerp(control.lerp(hand,q),q)
			depth = sin(t*PI)*155
			node.scale = Vector3.ONE*lerpf(.60,1.0,q)
			node.rotation = Vector3(PI*.5+.20*sin(t*PI),.22*sin(t*PI),lerpf(-.28,float(entry.fan),q))
		else:
			if t < .23:
				var q := smoothstep(0,.23,t)
				at = hand.lerp(center+Vector2(float(entry.index)*2,-24 if entry.mine else 24),q)
				depth = q*75
				node.rotation.z = lerpf(float(entry.fan),-.12,q)
			else:
				var q := smoothstep(.23,1,t)
				var control := (center+pile)*.5+Vector2(-size.x*.08,-160 if entry.mine else 160)
				at = center.lerp(control,q).lerp(control.lerp(pile,q),q)
				depth = sin(q*PI)*180+75*(1-q)
				node.rotation = Vector3(PI*.5+.42*sin(q*PI),-.18*sin(q*PI),-.12-.32*sin(q*PI))
				node.scale = Vector3.ONE*lerpf(1.0,.56,q)
		# Independent depth preserves the slight spacing in the gathered bundle.
		node.position = _point(at,depth+float(entry.index)*.9)
		node.visible = t > 0 and t < .999

func _clear_cards() -> void:
	for entry in moving:
		if is_instance_valid(entry.node): entry.node.queue_free()
	moving.clear()
	trails.clear()
	queue_redraw()

func _finish() -> void:
	_clear_cards()
	active = false
	if not pending.is_empty():
		_flush(generation)
		return
	phase = ""
	_restore_drawn_cards()
	battle.get("_hand_scroll").modulate.a = 1
	hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	busy_changed.emit(false)

func clear() -> void:
	var busy := is_busy()
	generation += 1
	if tween != null and tween.is_valid(): tween.kill()
	pending.clear()
	active = false
	flush_queued = false
	active_view = -1
	phase = ""
	_clear_cards()
	_restore_drawn_cards()
	if is_instance_valid(battle): battle.get("_hand_scroll").modulate.a = 1
	if viewport != null: viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()
	if busy: busy_changed.emit(false)

func _process(_delta: float) -> void:
	if not is_busy(): return
	if not presenter.world.motion_enabled or active_view != int(battle.get("_view_player")):
		clear()
		return
	_mask_drawn_cards()
	if not active and not flush_queued and presenter.motion.busy_time <= 0 and presenter.motion.hold <= 0:
		_flush(generation)
	for i in range(moving.size()):
		var at: Vector2 = camera.unproject_position(moving[i].node.position)
		var points: PackedVector2Array = trails[i].points
		points.append(at)
		if points.size()>7: points.remove_at(0)
		trails[i].points = points
	queue_redraw()

func _mask_drawn_cards() -> void:
	# Draws append to the visible player's hand. Keep pre-existing cards visible
	# during ordinary draws; mask only the newly dealt views, without identities.
	var cards: Control = battle.get("_hand_container")
	for i in range(maxi(0,cards.get_child_count()-hidden_draw_count),cards.get_child_count()):
		var card: Control = cards.get_child(i)
		if card not in hidden_cards: hidden_cards.append(card)
		card.modulate.a = 0

func _restore_drawn_cards() -> void:
	for card in hidden_cards:
		if is_instance_valid(card): card.modulate.a = 1
	hidden_cards.clear()
	hidden_draw_count = 0

func _draw() -> void:
	for trail in trails:
		if trail.points.size() > 1:
			draw_polyline(trail.points,Color(trail.color,.10),7,true)
			draw_polyline(trail.points,Color(trail.color,.40),1.4,true)
