class_name BattleInteractionVfxCatalog
extends RefCounted

const PROFILES := {
	"legal_target_glow": {"duration": -1.0, "layer": "persistent"},
	"attribute_action_glow": {"duration": -1.0, "layer": "persistent"},
	"flow_path": {"duration": -1.0, "layer": "persistent"},
	"multi_target_fanout": {"duration": -1.0, "layer": "persistent"},
	"success_converge": {"duration": 0.62, "layer": "transient"},
	"invalid_recoil": {"duration": 0.46, "layer": "transient"},
	"touch_ripple": {"duration": 0.32, "layer": "transient"},
	"energy_orbit": {"duration": 0.72, "layer": "transient"},
	"tool_lock": {"duration": 0.62, "layer": "transient"},
	"retreat_swap": {"duration": 0.74, "layer": "transient"},
	"ability_ripple": {"duration": 0.68, "layer": "transient"},
	"attack_ready": {"duration": -1.0, "layer": "persistent"},
	"phase_sweep": {"duration": 0.78, "layer": "transient"},
	"low_hp_pulse": {"duration": -1.0, "layer": "persistent"},
	"combo_cadence": {"duration": 0.58, "layer": "transient"},
}

const ATTRIBUTE_COLORS := {
	"R": Color(1.0, 0.32, 0.14, 0.92),
	"W": Color(0.18, 0.62, 1.0, 0.92),
	"L": Color(1.0, 0.86, 0.16, 0.94),
	"G": Color(0.25, 0.86, 0.35, 0.92),
	"P": Color(0.76, 0.38, 1.0, 0.92),
	"D": Color(0.32, 0.28, 0.48, 0.95),
	"F": Color(0.86, 0.45, 0.22, 0.92),
	"M": Color(0.54, 0.72, 0.78, 0.94),
	"N": Color(0.45, 0.36, 0.88, 0.94),
	"C": Color(0.64, 0.72, 0.78, 0.88),
}


static func has_effect(effect_id: String) -> bool:
	return PROFILES.has(effect_id)


static func profile(effect_id: String) -> Dictionary:
	return (PROFILES.get(effect_id, {}) as Dictionary).duplicate(true)


static func duration(effect_id: String) -> float:
	return float((PROFILES.get(effect_id, {}) as Dictionary).get("duration", 0.5))


static func attribute_color(energy_type: String) -> Color:
	var normalized := energy_type.strip_edges().to_upper()
	return ATTRIBUTE_COLORS.get(normalized, ATTRIBUTE_COLORS["C"]) as Color
