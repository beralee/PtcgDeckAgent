class_name V18CPGThreatResponseSolver
extends RefCounted


func solve(observation: Dictionary) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
	var active: Dictionary = opponent.get("active", {}) if opponent.get("active", {}) is Dictionary else {}
	var bench: Array = opponent.get("bench", []) if opponent.get("bench", []) is Array else []
	var own_active: Dictionary = own.get("active", {}) if own.get("active", {}) is Dictionary else {}
	var opponent_energy := _board_energy_count(opponent)
	var own_active_prizes := int(own_active.get("prize_count", 1))
	var own_active_hp := int(own_active.get("remaining_hp", 0))
	var posture: Array[String] = ["development"]
	if not active.is_empty():
		posture.append("active_ko")
	if not bench.is_empty():
		posture.append("credible_gust")
	var public_counter_ko_risk := clampf(float(opponent_energy) / 3.0, 0.0, 1.0)
	if own_active_hp >= 260:
		public_counter_ko_risk *= 0.75
	var recovery_cost := float(own_active_prizes) * 1.5 + float(_slot_energy_count(own_active)) * 0.6
	return {
		"schema_version": 2,
		"expected": posture,
		"credible_worst": ["gust_engine_ko", "hand_reset"],
		"public_counter_ko_risk": public_counter_ko_risk,
		"active_loss_recovery_cost": recovery_cost,
		"opponent_visible_energy": opponent_energy,
		"uncertainty": 0.45 if opponent_energy >= 2 else 0.7,
	}


func _board_energy_count(side: Dictionary) -> int:
	var result := _slot_energy_count(side.get("active", {}))
	for raw_slot: Variant in side.get("bench", []):
		result += _slot_energy_count(raw_slot)
	return result


func _slot_energy_count(raw_slot: Variant) -> int:
	if not (raw_slot is Dictionary):
		return 0
	var slot: Dictionary = raw_slot
	return int(slot.get("energy_count", (slot.get("energy", []) as Array).size() if slot.get("energy", []) is Array else 0))
