extends Node
## Keep the existing hand cards and their input handlers; only arrange their poses.
var presenter: Control
var battle: Control
var pointer := Vector2(-100,-100)
var hovered: BattleCardView
var poses: Dictionary = {}
var bases: Dictionary = {}
var last_card_id := ""
var last_point := Vector2.ZERO
var pointer_down := false
var touch_layout := false

func _ready() -> void:
	process_priority = 100

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton: pointer = event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_down = event.pressed
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var card := pick(event.position)
		if card != null and card.card_instance != null:
			last_card_id = str(card.card_instance.instance_id)
			last_point = event.position

func pick(point: Vector2) -> BattleCardView:
	var scroll: Control = battle.get("_hand_scroll")
	if not PointerGeometry.control_visible_viewport_point(scroll,point): return null
	if is_instance_valid(hovered) and PointerGeometry.control_visible_viewport_point(hovered,point): return hovered
	var row: Control = battle.get("_hand_container")
	for i in range(row.get_child_count()-1,-1,-1):
		var card := row.get_child(i) as BattleCardView
		if card != null and PointerGeometry.control_visible_viewport_point(card,point): return card
	return null

func _process(delta: float) -> void:
	var row: HBoxContainer = battle.get("_hand_container")
	var scroll: ScrollContainer = battle.get("_hand_scroll")
	if row == null or scroll == null: return
	var cards: Array[BattleCardView] = []
	for child in row.get_children():
		if child is BattleCardView: cards.append(child)
	if cards.is_empty():
		hovered = null
		return
	if presenter.platform_metrics.touch:
		# Let the existing scroll owner arrange mobile cards. A moving fan would
		# invalidate its scroll range and the physical finger's hit rectangle.
		for card in cards:
			card.rotation = 0
			card.pivot_offset = Vector2.ZERO
			card.z_index = 0
		if not touch_layout: row.queue_sort()
		touch_layout = true
		hovered = null
		poses.clear()
		return
	touch_layout = false
	var width := cards[0].custom_minimum_size.x
	var step := width+row.get_theme_constant("separation")
	var full_width := width+step*(cards.size()-1)
	var start := maxf(0,(row.size.x-full_width)*.5)
	var candidate: BattleCardView
	bases.clear()
	for i in range(cards.size()):
		var t := (float(i)/(cards.size()-1)*2-1) if cards.size() > 1 else 0.0
		var base := Vector2(start+i*step,18+t*t*6)
		bases[cards[i]] = base
		var point := row.get_global_transform().affine_inverse()*pointer
		if Rect2(base,cards[i].custom_minimum_size).has_point(point): candidate = cards[i]
	if is_instance_valid(hovered) and PointerGeometry.control_visible_viewport_point(hovered,pointer): candidate = hovered
	if not PointerGeometry.control_visible_viewport_point(scroll,pointer) or battle.call("_is_board_modal_overlay_visible"):
		candidate = null
	hovered = candidate
	var live := {}
	for i in range(cards.size()):
		var card := cards[i]
		var t := (float(i)/(cards.size()-1)*2-1) if cards.size() > 1 else 0.0
		var is_hover := card == hovered
		var at: Vector2 = bases[card]-Vector2(0,18 if is_hover else 0)
		var angle := 0.0 if is_hover else deg_to_rad(t*4.0)
		var key := card.get_instance_id()
		live[key] = true
		var previous: Dictionary = poses.get(key,{"at":at,"angle":angle})
		var blend := 1-exp(-delta*18) if presenter.world.motion_enabled else 1.0
		if pointer_down: blend = 0.0
		var pose := {"at":Vector2(previous.at).lerp(at,blend),"angle":lerpf(float(previous.angle),angle,blend)}
		poses[key] = pose
		card.pivot_offset = Vector2(width*.5,card.custom_minimum_size.y)
		card.position = pose.at
		card.rotation = pose.angle
		card.z_index = 100 if is_hover else i+5
	for key in poses.keys():
		if not live.has(key): poses.erase(key)
