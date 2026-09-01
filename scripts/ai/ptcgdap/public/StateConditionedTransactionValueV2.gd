class_name StateConditionedTransactionValueV2
extends RefCounted

const TreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")

const PROFILE_ID := "ptcgdap-state-conditioned-transaction-value-v2"
const ENCODER_PROFILE_ID := "ptcgdap-public-state-features-v2"
const RESULT_PROFILE_ID := "ptcgdap-state-conditioned-transaction-value-result-v2"
const TRAINING_PROFILE_ID := "ptcgdap-joint-decision-training-v2"
const FALLBACK_PROFILE_ID := "ptcgdap-turn-program-value-v1"
const MAX_SAFE_INTEGER := 9007199254740991
const MAX_WEIGHT := 100000

const PRIVATE_KEYS := {
	"deck_order": true, "face_down_prizes": true, "private_state": true,
	"private_rng_state": true, "search_begin_input": true, "callback": true,
	"ticket": true, "command": true, "object_ref": true, "instance_id": true,
	"raw_private_hash": true, "training_oracle_identity": true,
}
const FALLBACK_FEATURES := [
	"prize_gain_milli", "board_development_milli", "attack_pressure_milli",
	"next_turn_continuity_milli", "hand_quality_milli", "disruption_milli",
	"resource_preservation_milli", "risk_milli", "unresolved_debt_milli",
]
const BASE_STATE_FEATURES := [
	"bias_milli", "turn.progress_milli", "self.hand.count_milli",
	"self.hand.shortage_milli", "self.hand.abundance_milli",
	"opponent.hand.count_milli", "opponent.hand.shortage_milli",
	"opponent.hand.excess_milli", "hand.advantage_milli",
	"self.deck.depletion_milli", "opponent.deck.depletion_milli",
	"self.prize.progress_milli", "opponent.prize.progress_milli",
	"prize.advantage_milli", "self.board.count_milli",
	"opponent.board.count_milli", "self.board.bench_space_milli",
	"self.board.energy_milli", "self.board.energy_debt_milli",
	"self.board.attack_ready_milli", "self.board.damage_milli",
	"opponent.board.energy_milli", "opponent.board.energy_debt_milli",
	"opponent.board.attack_ready_milli", "opponent.board.damage_milli",
	"self.discard.count_milli", "opponent.discard.count_milli",
	"turn.supporter_available_milli", "turn.supporter_spent_milli",
	"turn.manual_attachment_available_milli", "turn.manual_attachment_spent_milli",
	"turn.retreat_available_milli", "turn.retreat_spent_milli",
]
const ROLE_ZONES := [
	"self.hand", "self.board", "self.discard", "opponent.board", "opponent.discard",
]
const ACTION_FEATURES := [
	"outcome.prize_gain_milli", "outcome.board_development_milli",
	"outcome.attack_pressure_milli", "outcome.next_turn_continuity_milli",
	"outcome.hand_quality_milli", "outcome.disruption_milli",
	"outcome.resource_preservation_milli", "outcome.risk_milli",
	"outcome.unresolved_debt_milli", "outcome.final_prize_knockout_milli",
	"program.step_count_milli", "program.nonterminal_count_milli",
	"program.deadline_milli", "program.terminal_attack_milli",
	"program.terminal_end_turn_milli",
]
const ACTION_ROLE_CHANNELS := ["card", "source", "target"]
const ACTION_EFFECT_KINDS := [
	"ability", "attack", "bench", "conversion", "damage_transfer",
	"disruption", "draw", "end_turn", "energy", "evolution", "handoff",
	"search", "tool",
]
const ACTION_RESOURCE_CLAIMS := [
	"none", "supporter", "manual_attachment", "retreat", "unknown",
]
const MODEL_KEYS := [
	"profile_id", "model_version", "feature_schema_version", "role_names",
	"uid_roles", "fallback_value_model", "state_value_weights_milli",
	"action_value_weights_milli", "interaction_weights_milli", "calibration",
	"training",
]


static func default_model(
	uid_roles: Dictionary = {}, training_run_id: String = "untrained-default-v2"
) -> Dictionary:
	var mapping := uid_roles.duplicate(true)
	var role_set := {}
	for assigned_value: Variant in mapping.values():
		if assigned_value is Array:
			for role: Variant in assigned_value:
				role_set[str(role)] = true
	var role_names: Array = role_set.keys()
	role_names.sort()
	return {
		"profile_id": PROFILE_ID,
		"model_version": 1,
		"feature_schema_version": 2,
		"role_names": role_names,
		"uid_roles": mapping,
		"fallback_value_model": {
			"profile_id": FALLBACK_PROFILE_ID,
			"model_version": 1,
			"feature_weights_milli": {
				"prize_gain_milli": 4000,
				"board_development_milli": 900,
				"attack_pressure_milli": 1100,
				"next_turn_continuity_milli": 1300,
				"hand_quality_milli": 500,
				"disruption_milli": 700,
				"resource_preservation_milli": 800,
				"risk_milli": -2000,
				"unresolved_debt_milli": -1000,
			},
		},
		"state_value_weights_milli": {},
		"action_value_weights_milli": {},
		"interaction_weights_milli": {},
		"calibration": {
			"temperature_milli": 1000,
			"bias_utility": 0,
			"clip_abs_utility": 20000000,
			"minimum_override_margin_utility": 0,
		},
		"training": {
			"profile_id": TRAINING_PROFILE_ID,
			"run_id": training_run_id,
			"label_profile_id": "ptcgdap-public-better-than-self-v2",
			"dataset_sha256": "0".repeat(64),
			"weights_sha256": "0".repeat(64),
		},
	}


static func model_error(value: Variant) -> String:
	if not value is Dictionary or not _exact_keys(value, MODEL_KEYS) \
			or value.get("profile_id") != PROFILE_ID \
			or not _safe_int(value.get("model_version")) \
			or int(value.get("model_version")) < 1 \
			or value.get("feature_schema_version") != 2 \
			or not value.get("role_names") is Array \
			or value.get("role_names", []).size() > 32 \
			or not value.get("uid_roles") is Dictionary:
		return "invalid_state_conditioned_value_model"
	var roles := {}
	for role_value: Variant in value.get("role_names", []):
		if not _identifier(role_value) or roles.has(role_value):
			return "invalid_state_conditioned_value_model"
		roles[role_value] = true
	for uid: Variant in value.get("uid_roles", {}):
		var assigned: Variant = value.get("uid_roles", {}).get(uid)
		if typeof(uid) != TYPE_STRING or str(uid).is_empty() or str(uid).length() > 128 \
				or not assigned is Array or assigned.is_empty():
			return "invalid_state_conditioned_value_model"
		var seen := {}
		for role: Variant in assigned:
			if not roles.has(role) or seen.has(role):
				return "invalid_state_conditioned_value_model"
			seen[role] = true
	if not _fallback_model_valid(value.get("fallback_value_model")):
		return "invalid_state_conditioned_value_model"
	var state_features := _available_state_features(value)
	var action_features := _available_action_features(value)
	if not _weights_valid(value.get("state_value_weights_milli"), state_features) \
			or not _weights_valid(value.get("action_value_weights_milli"), action_features) \
			or not value.get("interaction_weights_milli") is Dictionary:
		return "invalid_state_conditioned_value_model"
	for pair_value: Variant in value.get("interaction_weights_milli", {}):
		var parts: PackedStringArray = str(pair_value).split("::", false, 1)
		var weight: Variant = value.get("interaction_weights_milli", {}).get(pair_value)
		if parts.size() != 2 or not state_features.has(parts[0]) \
				or not action_features.has(parts[1]) or not _bounded_weight(weight):
			return "invalid_state_conditioned_value_model"
	var calibration: Variant = value.get("calibration")
	if not calibration is Dictionary or not _exact_keys(calibration, [
		"temperature_milli", "bias_utility", "clip_abs_utility",
		"minimum_override_margin_utility",
	]) or not _safe_int(calibration.get("temperature_milli")) \
			or int(calibration.get("temperature_milli")) < 100 \
			or int(calibration.get("temperature_milli")) > 10000 \
			or not _safe_signed_int(calibration.get("bias_utility")) \
			or not _safe_int(calibration.get("clip_abs_utility")) \
			or int(calibration.get("clip_abs_utility")) < 1 \
			or int(calibration.get("clip_abs_utility")) > 100000000 \
			or not _safe_int(calibration.get("minimum_override_margin_utility")) \
			or int(calibration.get("minimum_override_margin_utility")) > 10000000:
		return "invalid_state_conditioned_value_model"
	var training: Variant = value.get("training")
	if not training is Dictionary or not _exact_keys(training, [
		"profile_id", "run_id", "label_profile_id", "dataset_sha256", "weights_sha256",
	]) or training.get("profile_id") != TRAINING_PROFILE_ID \
			or not _identifier(training.get("run_id")) \
			or not _identifier(training.get("label_profile_id")) \
			or not _sha(training.get("dataset_sha256")) \
			or not _sha(training.get("weights_sha256")):
		return "invalid_state_conditioned_value_model"
	return ""


static func is_model(value: Variant) -> bool:
	return model_error(value).is_empty()


static func encode_public_state(frame: Variant, model: Variant) -> Dictionary:
	var error := model_error(model)
	if not error.is_empty():
		return _error(error)
	if _contains_private(frame):
		return _error("private_state_conditioned_value_input")
	if not frame is Dictionary or frame.get("schema_version") != 2 \
			or frame.get("profile_id") != "ptcgdap-competitive-public-frame-v2" \
			or not frame.get("public_state") is Dictionary:
		return _error("invalid_state_conditioned_value_frame")
	var state: Dictionary = frame.get("public_state")
	var own: Variant = state.get("self")
	var opponent: Variant = state.get("opponent")
	if not own is Dictionary or not opponent is Dictionary:
		return _error("invalid_state_conditioned_value_frame")
	var own_hand := _cards(own.get("hand", []))
	var own_board := _board(own)
	var opposing_board := _board(opponent)
	var own_discard := _cards(own.get("discard", []))
	var opposing_discard := _cards(opponent.get("discard", []))
	var opponent_hand_count: Variant = opponent.get("hand_count", 0)
	var own_prizes: Variant = own.get("prizes_remaining", 0)
	var opponent_prizes: Variant = opponent.get("prizes_remaining", 0)
	var own_deck: Variant = own.get("deck_count", 0)
	var opponent_deck: Variant = opponent.get("deck_count", 0)
	var turn_number: Variant = state.get("turn_number", 0)
	for amount: Variant in [opponent_hand_count, own_prizes, opponent_prizes, own_deck, opponent_deck, turn_number]:
		if not _safe_int(amount):
			return _error("invalid_state_conditioned_value_frame")
	var own_hand_count := own_hand.size()
	var own_metrics := _board_metrics(own_board)
	var opponent_metrics := _board_metrics(opposing_board)
	var turn: Dictionary = own.get("turn", {}) if own.get("turn", {}) is Dictionary else {}
	var features := {
		"bias_milli": 1000,
		"turn.progress_milli": mini(1000, int(turn_number) * 50),
		"self.hand.count_milli": _scaled_count(own_hand_count),
		"self.hand.shortage_milli": mini(1000, maxi(0, 5 - own_hand_count) * 200),
		"self.hand.abundance_milli": mini(1000, maxi(0, own_hand_count - 5) * 200),
		"opponent.hand.count_milli": _scaled_count(int(opponent_hand_count)),
		"opponent.hand.shortage_milli": mini(1000, maxi(0, 4 - int(opponent_hand_count)) * 250),
		"opponent.hand.excess_milli": mini(1000, maxi(0, int(opponent_hand_count) - 4) * 250),
		"hand.advantage_milli": _clip((own_hand_count - int(opponent_hand_count)) * 125),
		"self.deck.depletion_milli": mini(1000, maxi(0, 60 - int(own_deck)) * 17),
		"opponent.deck.depletion_milli": mini(1000, maxi(0, 60 - int(opponent_deck)) * 17),
		"self.prize.progress_milli": mini(1000, maxi(0, 6 - int(own_prizes)) * 167),
		"opponent.prize.progress_milli": mini(1000, maxi(0, 6 - int(opponent_prizes)) * 167),
		"prize.advantage_milli": _clip((int(opponent_prizes) - int(own_prizes)) * 167),
		"self.board.count_milli": mini(1000, own_board.size() * 167),
		"opponent.board.count_milli": mini(1000, opposing_board.size() * 167),
		"self.board.bench_space_milli": mini(1000, maxi(0, 5 - _cards(own.get("bench", [])).size()) * 200),
		"self.board.energy_milli": own_metrics.get("energy_milli"),
		"self.board.energy_debt_milli": own_metrics.get("energy_debt_milli"),
		"self.board.attack_ready_milli": own_metrics.get("attack_ready_milli"),
		"self.board.damage_milli": own_metrics.get("damage_milli"),
		"opponent.board.energy_milli": opponent_metrics.get("energy_milli"),
		"opponent.board.energy_debt_milli": opponent_metrics.get("energy_debt_milli"),
		"opponent.board.attack_ready_milli": opponent_metrics.get("attack_ready_milli"),
		"opponent.board.damage_milli": opponent_metrics.get("damage_milli"),
		"self.discard.count_milli": _scaled_count(own_discard.size(), 20),
		"opponent.discard.count_milli": _scaled_count(opposing_discard.size(), 20),
		"turn.supporter_available_milli": 1000 if turn.get("supporter_available", true) == true else 0,
		"turn.supporter_spent_milli": 0 if turn.get("supporter_available", true) == true else 1000,
		"turn.manual_attachment_available_milli": 1000 if turn.get("manual_attachment_available", true) == true else 0,
		"turn.manual_attachment_spent_milli": 0 if turn.get("manual_attachment_available", true) == true else 1000,
		"turn.retreat_available_milli": 1000 if turn.get("retreat_available", true) == true else 0,
		"turn.retreat_spent_milli": 0 if turn.get("retreat_available", true) == true else 1000,
	}
	for key: Variant in _role_feature_names(model.get("role_names", [])):
		features[key] = 0
	var zones := {
		"self.hand": own_hand, "self.board": own_board, "self.discard": own_discard,
		"opponent.board": opposing_board, "opponent.discard": opposing_discard,
	}
	for zone: Variant in zones:
		var counts := {}
		for role: Variant in model.get("role_names", []):
			counts[role] = 0
		for card_value: Variant in zones.get(zone, []):
			for role: Variant in model.get("uid_roles", {}).get(_uid(card_value), []):
				counts[role] = int(counts.get(role, 0)) + 1
		for role: Variant in counts:
			features["%s.role.%s_milli" % [zone, role]] = mini(1000, int(counts[role]) * 250)
	var payload := {
		"accepted": true, "error_code": "", "profile_id": ENCODER_PROFILE_ID,
		"public_only": true, "authoritative": false,
		"source": frame.get("source", {}).duplicate(true),
		"features_milli": features,
	}
	var result := payload.duplicate(true)
	result["audit_hash"] = _audit_hash(payload)
	return result


static func action_features(program: Variant, outcome: Variant, model: Variant) -> Variant:
	if not program is Dictionary or not outcome is Dictionary:
		return null
	for feature: String in FALLBACK_FEATURES:
		if not _safe_int(outcome.get(feature)):
			return null
	var final_prize: Variant = outcome.get("final_prize_knockout", 0)
	var steps: Variant = program.get("semantic_steps")
	var deadline: Variant = program.get("deadline_turns", 0)
	if final_prize not in [0, 1] or not steps is Array or steps.is_empty() \
			or not _safe_int(deadline):
		return null
	var result := {}
	for feature: String in FALLBACK_FEATURES:
		result["outcome.%s" % feature] = outcome.get(feature)
	var terminal: Variant = steps[-1].get("terminal_kind") if steps[-1] is Dictionary else null
	var nonterminal := 0
	for step_value: Variant in steps:
		if step_value is Dictionary and step_value.get("terminal_kind") == "none":
			nonterminal += 1
	result.merge({
		"outcome.final_prize_knockout_milli": int(final_prize) * 1000,
		"program.step_count_milli": mini(1000, steps.size() * 100),
		"program.nonterminal_count_milli": mini(1000, nonterminal * 100),
		"program.deadline_milli": mini(1000, int(deadline) * 125),
		"program.terminal_attack_milli": 1000 if terminal == "attack" else 0,
		"program.terminal_end_turn_milli": 1000 if terminal == "end_turn" else 0,
	})
	var context: Variant = program.get("public_action_context", {})
	if context == null:
		context = {}
	if not context is Dictionary:
		return null
	var effect_kinds: Variant = context.get("current_effect_kinds", [])
	var resource_claims: Variant = context.get("current_resource_claims", [])
	if not effect_kinds is Array or not resource_claims is Array:
		return null
	for kind: Variant in effect_kinds:
		if kind not in ACTION_EFFECT_KINDS:
			return null
	for claim: Variant in resource_claims:
		if claim not in ACTION_RESOURCE_CLAIMS:
			return null
	for kind: String in ACTION_EFFECT_KINDS:
		result["program.current_effect.%s_milli" % kind] = 1000 if kind in effect_kinds else 0
	for claim: String in ACTION_RESOURCE_CLAIMS:
		result["program.current_resource.%s_milli" % claim] = 1000 if claim in resource_claims else 0
	for channel: String in ACTION_ROLE_CHANNELS:
		var values: Variant = context.get("%s_uids" % channel, [])
		if not values is Array:
			return null
		var counts := {}
		for role: Variant in model.get("role_names", []):
			counts[role] = 0
		for uid_value: Variant in values:
			if typeof(uid_value) != TYPE_STRING:
				return null
			for role: Variant in model.get("uid_roles", {}).get(uid_value, []):
				counts[role] = int(counts.get(role, 0)) + 1
		for role: Variant in counts:
			result["action.%s.role.%s_milli" % [channel, role]] = mini(
				1000, int(counts.get(role)) * 250
			)
	return result


static func score(frame: Variant, program: Variant, outcome: Variant, model: Variant) -> Dictionary:
	var encoded := encode_public_state(frame, model)
	if not bool(encoded.get("accepted", false)):
		return encoded
	var action: Variant = action_features(program, outcome, model)
	if action == null:
		return _error("invalid_state_conditioned_value_program")
	var state: Dictionary = encoded.get("features_milli", {})
	var fallback: Dictionary = model.get("fallback_value_model", {}).get("feature_weights_milli", {})
	var base := 0
	for feature: String in FALLBACK_FEATURES:
		base += int(outcome.get(feature)) * int(fallback.get(feature))
	var state_head := 0
	for name: Variant in model.get("state_value_weights_milli", {}):
		state_head += int(state.get(name)) * int(model.get("state_value_weights_milli", {}).get(name))
	var action_head := 0
	for name: Variant in model.get("action_value_weights_milli", {}):
		action_head += int(action.get(name)) * int(model.get("action_value_weights_milli", {}).get(name))
	var interaction_head := 0
	for pair: Variant in model.get("interaction_weights_milli", {}):
		var parts: PackedStringArray = str(pair).split("::", false, 1)
		interaction_head += _trunc_div(
			int(state.get(parts[0])) * int(action.get(parts[1]))
				* int(model.get("interaction_weights_milli", {}).get(pair)),
			1000
		)
	var calibration: Dictionary = model.get("calibration", {})
	var raw_adjustment := state_head + action_head + interaction_head \
		+ int(calibration.get("bias_utility"))
	var adjustment := _trunc_div(
		raw_adjustment * 1000, int(calibration.get("temperature_milli"))
	)
	var clip_abs := int(calibration.get("clip_abs_utility"))
	adjustment = mini(clip_abs, maxi(-clip_abs, adjustment))
	var payload := {
		"accepted": true, "error_code": "", "profile_id": RESULT_PROFILE_ID,
		"public_only": true, "authoritative": false,
		"model_version": model.get("model_version"),
		"source": frame.get("source", {}).duplicate(true),
		"base_utility": base, "state_value": state_head,
		"action_value": action_head, "interaction_value": interaction_head,
		"conditioned_adjustment": adjustment, "total_utility": base + adjustment,
		"state_feature_hash": encoded.get("audit_hash", ""),
		"action_feature_hash": _audit_hash(action),
	}
	var result := payload.duplicate(true)
	result["audit_hash"] = _audit_hash(payload)
	return result


static func _board_metrics(cards: Array) -> Dictionary:
	var energy := 0
	var debt := 0
	var ready := 0
	var damage := 0
	for card_value: Variant in cards:
		if not card_value is Dictionary:
			continue
		energy += _card_int(card_value, "attached_energy_count")
		debt += _card_int(card_value, "energy_debt")
		ready += int(card_value.get("attack_ready") == true)
		if typeof(card_value.get("damage_counters")) == TYPE_INT:
			damage += maxi(0, int(card_value.get("damage_counters")))
		elif typeof(card_value.get("max_hp")) == TYPE_INT \
				and typeof(card_value.get("remaining_hp")) == TYPE_INT:
			damage += int(maxi(0, int(card_value.get("max_hp")) - int(card_value.get("remaining_hp"))) / 10)
	return {
		"energy_milli": mini(1000, energy * 125),
		"energy_debt_milli": mini(1000, debt * 125),
		"attack_ready_milli": mini(1000, ready * 250),
		"damage_milli": mini(1000, damage * 50),
	}


static func _cards(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				result.append(item)
	return result


static func _board(player: Dictionary) -> Array:
	var result := _cards(player.get("active", []))
	result.append_array(_cards(player.get("bench", [])))
	return result


static func _uid(card: Dictionary) -> String:
	return str(card.get("local_card_uid", "")) \
		if typeof(card.get("local_card_uid", "")) == TYPE_STRING else ""


static func _card_int(card: Dictionary, key: String) -> int:
	return maxi(0, int(card.get(key))) if typeof(card.get(key)) == TYPE_INT else 0


static func _role_feature_names(role_names: Array) -> Dictionary:
	var result := {}
	for zone: String in ROLE_ZONES:
		for role: Variant in role_names:
			result["%s.role.%s_milli" % [zone, role]] = true
	return result


static func _available_state_features(model: Dictionary) -> Dictionary:
	var result := _as_set(BASE_STATE_FEATURES)
	result.merge(_role_feature_names(model.get("role_names", [])))
	return result


static func _available_action_features(model: Dictionary) -> Dictionary:
	var result := _as_set(ACTION_FEATURES)
	for kind: String in ACTION_EFFECT_KINDS:
		result["program.current_effect.%s_milli" % kind] = true
	for claim: String in ACTION_RESOURCE_CLAIMS:
		result["program.current_resource.%s_milli" % claim] = true
	for channel: String in ACTION_ROLE_CHANNELS:
		for role: Variant in model.get("role_names", []):
			result["action.%s.role.%s_milli" % [channel, role]] = true
	return result


static func _fallback_model_valid(value: Variant) -> bool:
	if not value is Dictionary or not _exact_keys(value, [
		"profile_id", "model_version", "feature_weights_milli",
	]) or value.get("profile_id") != FALLBACK_PROFILE_ID \
			or not _safe_int(value.get("model_version")) \
			or int(value.get("model_version")) < 1 \
			or not value.get("feature_weights_milli") is Dictionary \
			or not _exact_keys(value.get("feature_weights_milli", {}), FALLBACK_FEATURES):
		return false
	for weight: Variant in value.get("feature_weights_milli", {}).values():
		if not _bounded_weight(weight):
			return false
	return true


static func _weights_valid(value: Variant, allowed: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	for key: Variant in value:
		if not allowed.has(key) or not _bounded_weight(value.get(key)):
			return false
	return true


static func _contains_private(value: Variant) -> bool:
	var stack: Array = [value]
	while not stack.is_empty():
		var current: Variant = stack.pop_back()
		if current is Dictionary:
			for key: Variant in current:
				if typeof(key) != TYPE_STRING or PRIVATE_KEYS.has(str(key).to_lower()):
					return true
				stack.append(current.get(key))
		elif current is Array:
			stack.append_array(current)
	return false


static func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).is_empty() or str(value).length() > 128:
		return false
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789._-"
	var text := str(value)
	if not (text[0] in "abcdefghijklmnopqrstuvwxyz0123456789"):
		return false
	for character: String in text:
		if character not in allowed:
			return false
	return true


static func _sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for character: String in str(value):
		if character not in "0123456789ABCDEF":
			return false
	return true


static func _safe_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0 and int(value) <= MAX_SAFE_INTEGER


static func _safe_signed_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and abs(int(value)) <= MAX_SAFE_INTEGER


static func _bounded_weight(value: Variant) -> bool:
	return _safe_signed_int(value) and abs(int(value)) <= MAX_WEIGHT


static func _scaled_count(value: int, maximum: int = 10) -> int:
	return mini(maximum, maxi(0, value)) * int(1000 / maximum)


static func _clip(value: int, low: int = -1000, high: int = 1000) -> int:
	return mini(high, maxi(low, value))


static func _trunc_div(numerator: int, denominator: int) -> int:
	return (-1 if numerator < 0 else 1) * int(abs(numerator) / denominator)


static func _as_set(values: Array) -> Dictionary:
	var result := {}
	for value: Variant in values:
		result[value] = true
	return result


static func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _audit_hash(value: Variant) -> String:
	var result: Dictionary = TreeHashScript.hash_tree(value, "public_observation")
	return str(result.get("sha256", "")) if bool(result.get("ok", false)) else ""


static func _error(code: String) -> Dictionary:
	return {
		"accepted": false, "error_code": code, "profile_id": RESULT_PROFILE_ID,
		"public_only": true, "authoritative": false, "features_milli": {},
		"audit_hash": "",
	}
