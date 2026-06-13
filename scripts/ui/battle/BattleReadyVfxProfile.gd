class_name BattleReadyVfxProfile
extends RefCounted


var profile_id: String = ""
var rule_id: String = ""
var asset_specs: Dictionary = {}
var duration: float = 0.72
var effect_size: Vector2 = Vector2(210.0, 210.0)
var anchor_offset: Vector2 = Vector2(0.0, -18.0)
var start_scale: float = 0.62
var peak_scale: float = 1.16
var hold_scale: float = 1.06
var end_scale: float = 1.02
var hold_ratio: float = 0.0
var flipbook_ratio: float = 0.82
var portrait_duration: float = 0.0
var portrait_effect_width_ratio: float = 0.0
var portrait_effect_min_size: float = 0.0
var portrait_effect_max_size: float = 0.0
var portrait_anchor_offset_ratio: Vector2 = Vector2.ZERO
var flash_color: Color = Color(1.0, 0.55, 0.82, 0.26)
var flash_enabled: bool = true
