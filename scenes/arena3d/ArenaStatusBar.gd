extends Control
## Five compact status entries; actions still belong to the battle scene.
const Hud := preload("res://scenes/arena3d/ArenaCompactHud.gd")
var presenter: Control
var turn: Label
var buttons: Array[Button] = []
var owners: Array[Button] = []

func setup(p: Control) -> void:
	presenter = p
	name = "ArenaStatusBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	var background := Panel.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142b24")
	style.border_color = Color("92835a")
	style.border_width_bottom = 1
	background.add_theme_stylebox_override("panel",style)
	add_child(background)
	turn = Label.new()
	turn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(turn)
	for spec: Array in [["对手手牌","BtnOpponentHand"],["AI","BtnBattleDiscussAI"],["宙斯","BtnZeusHelp"],["退出","BtnBack"]]:
		var owner := p.battle.find_child(spec[1],true,false) as Button
		owners.append(owner)
		var button: Button = p._button(spec[0],func():
			if is_instance_valid(owner) and owner.visible and not owner.disabled: owner.pressed.emit()
		)
		button.reparent(self,false)
		buttons.append(button)
	hide()

func arrange(metrics: Dictionary, width: float) -> float:
	var s: float = metrics.scale
	var gap := 4.0*s
	var h: float = metrics.target
	position = Vector2.ZERO
	size = Vector2(width,h+gap*2)
	var weights := [1.25,2.0,.85,.95,.95]
	var available := width-gap*6
	var x := gap
	var controls: Array[Control] = [turn]
	controls.append_array(buttons)
	for i in range(controls.size()):
		var w: float = available*weights[i]/6.0
		Hud.place(controls[i],Vector2(x,gap),Vector2(w,h),roundi(12*s))
		x += w+gap
	show()
	return size.y

func sync(frame: Dictionary) -> void:
	if frame.is_empty(): return
	turn.text = "回合 %d" % int(frame.turn)
	turn.modulate = Color("ffe4a0") if frame.current == frame.view else Color("c7d4cd")
	buttons[0].text = "对手手牌 %d" % int(frame.players[1-frame.view].hand_count)
	for i in range(buttons.size()):
		buttons[i].disabled = not is_instance_valid(owners[i]) or not owners[i].visible or owners[i].disabled
