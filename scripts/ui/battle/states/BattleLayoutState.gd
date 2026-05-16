class_name BattleLayoutState
extends RefCounted

const DEFAULT_PLAY_CARD_SIZE := Vector2(130, 182)
const DEFAULT_DIALOG_CARD_SIZE := Vector2(148, 208)
const DEFAULT_DETAIL_CARD_SIZE := Vector2(300, 420)

var play_card_size: Vector2 = DEFAULT_PLAY_CARD_SIZE
var dialog_card_size: Vector2 = DEFAULT_DIALOG_CARD_SIZE
var detail_card_size: Vector2 = DEFAULT_DETAIL_CARD_SIZE
var portrait_layout_frame_rect: Rect2 = Rect2()
var portrait_layout_full_size: Vector2 = Vector2.ZERO
var rotated_portrait_canvas_active: bool = false
var rotated_portrait_physical_viewport_size: Vector2 = Vector2.ZERO
var active_battle_layout_mode: String = ""


func reset() -> void:
	play_card_size = DEFAULT_PLAY_CARD_SIZE
	dialog_card_size = DEFAULT_DIALOG_CARD_SIZE
	detail_card_size = DEFAULT_DETAIL_CARD_SIZE
	portrait_layout_frame_rect = Rect2()
	portrait_layout_full_size = Vector2.ZERO
	rotated_portrait_canvas_active = false
	rotated_portrait_physical_viewport_size = Vector2.ZERO
	active_battle_layout_mode = ""
