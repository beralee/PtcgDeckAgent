class_name V18CPGRagingBoltContinuityDemand
extends RefCounted


func solve(
	observation: Dictionary,
	facts: Dictionary,
	prize_clock: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var parameters: Dictionary = profile.get("module_parameters", {}).get(
		"energy_burst",
		{}
	) if profile.get("module_parameters", {}) is Dictionary \
			and profile.get("module_parameters", {}).get("energy_burst", {}) is Dictionary \
		else {}
	var damage_per_unit := maxi(1, int(parameters.get("damage_per_discard", 70)))
	var win_now := bool(facts.get("prize", {}).get("win_now", false))
	var target_hp := 0 if win_now else _dynamic_target_hp(
		observation,
		bool(facts.get("attack", {}).get("ko_available", false))
	)
	var required_units := 0 if win_now else ceili(
		float(maxi(0, target_hp)) / float(damage_per_unit)
	)
	var sequence: Array = prize_clock.get("own", {}).get("robust", {}).get(
		"prize_sequence",
		[]
	) if prize_clock.get("own", {}) is Dictionary \
			and prize_clock.get("own", {}).get("robust", {}) is Dictionary \
			and prize_clock.get("own", {}).get("robust", {}).get("prize_sequence", []) is Array \
			else []
	var current_lane := _count_board_uids(
		observation.get("own", {}),
		["CSV9C_155"]
	)
	var future_lane := _count_board_uids(
		observation.get("own", {}),
		["CSV9C_154", "CSV9.5C_141"]
	)
	return {
		"extension": "raging_bolt",
		"remaining_attack_windows": 0 if win_now else maxi(1, sequence.size()),
		"next_target_damage": target_hp,
		"damage_per_unit": damage_per_unit,
		"dynamic_damage_units_required": required_units,
		"required_banked_damage_units": required_units,
		"noctowl_current_lane": current_lane,
		"hoothoot_future_lane": future_lane,
		"minimum_current_search_lane": 0 if win_now else 1,
		"minimum_future_search_root": (
			0 if win_now or sequence.size() <= 1 else 1
		),
	}


func _dynamic_target_hp(observation: Dictionary, current_ko: bool) -> int:
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	if not current_ko:
		return int(active.get("remaining_hp", 0))
	var public_next_hp := 0
	for raw_slot: Variant in opponent.get("bench", []):
		if raw_slot is Dictionary:
			public_next_hp = maxi(
				public_next_hp,
				int((raw_slot as Dictionary).get("remaining_hp", 0))
			)
	return public_next_hp if public_next_hp > 0 \
		else int(active.get("remaining_hp", 0))


func _count_board_uids(side_value: Variant, uids: Array[String]) -> int:
	if not (side_value is Dictionary):
		return 0
	var side: Dictionary = side_value
	var slots: Array = []
	if side.get("active", {}) is Dictionary:
		slots.append(side.get("active", {}))
	if side.get("bench", []) is Array:
		slots.append_array(side.get("bench", []))
	var result := 0
	for raw_slot: Variant in slots:
		if not (raw_slot is Dictionary):
			continue
		var pokemon: Dictionary = (raw_slot as Dictionary).get("pokemon", {}) \
			if (raw_slot as Dictionary).get("pokemon", {}) is Dictionary else {}
		if str(pokemon.get("uid", "")).to_upper() in uids:
			result += 1
	return result
