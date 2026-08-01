class_name V18CPGCandidateTransitionEvaluator
extends RefCounted

const ContractsScript = preload(
	"res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd"
)
const RegistryScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGTransitionRegistry.gd"
)

var _registry = RegistryScript.new()


func evaluate(
	candidate: Dictionary,
	transition_state: Dictionary,
	observation: Dictionary,
	_profile: Dictionary = {}
) -> Dictionary:
	var operator := _registry.operator_for(candidate)
	# Candidate transitions mutate only public board/quota state.  Keep immutable
	# facts, ledger, and Prize Clock behind source_state_hash instead of deep
	# copying them for every beam item; this is the main v3 latency bound.
	var predicted := _prediction_state(transition_state)
	var checkpoint := str(candidate.get("checkpoint_after", "action_resolved"))
	var information_boundary := _registry.is_information_boundary(candidate)
	var supported := operator != RegistryScript.UNSUPPORTED
	var reason := ""
	if supported:
		reason = _apply_operator(operator, candidate, predicted)
		supported = reason == ""
	var action_id := str(
		candidate.get(
			"safe_prefix_action_id",
			candidate.get("action_ref", {}).get("id", "")
		)
	)
	var result := {
		"schema_version": ContractsScript.TRANSITION_SCHEMA_VERSION,
		"candidate_id": str(candidate.get("candidate_id", "")),
		"action_id": action_id,
		"operator": operator,
		"supported": supported,
		"unsupported_reason": reason,
		"exact_current_action": action_id != "",
		"checkpoint_after": checkpoint,
		"requires_reobservation": information_boundary or checkpoint != "terminal",
		"prediction_class": (
			"exact_public_transition" if supported and not information_boundary
			else "information_checkpoint" if information_boundary
			else "transition_unsupported"
		),
		"predicted_state": predicted,
	}
	if supported:
		result["predicted_state"]["state_hash"] = ContractsScript.stable_hash(
			_without_hash(result["predicted_state"])
		)
		result["transition_certificate"] = {
			"public_only": true,
			"source_state_hash": str(transition_state.get("state_hash", "")),
			"predicted_state_hash": str(result["predicted_state"].get("state_hash", "")),
			"operator": operator,
			"action_id": action_id,
		}
	return result


func _apply_operator(
	operator: String,
	candidate: Dictionary,
	state: Dictionary
) -> String:
	var action: Dictionary = candidate.get("action_ref", {}) \
		if candidate.get("action_ref", {}) is Dictionary else {}
	match operator:
		RegistryScript.ATTACH_ENERGY:
			if not bool(state.get("quotas", {}).get("energy_attachment", false)):
				return "energy_quota_spent"
			var target := _own_slot(str(action.get("target", "")), state)
			var card: Dictionary = action.get("card", {}) \
				if action.get("card", {}) is Dictionary else {}
			if target.is_empty() or card.is_empty():
				return "unbound_attachment"
			(target.get("energy", []) as Array).append(card.duplicate(true))
			target["energy_count"] = int(target.get("energy_count", 0)) + 1
			state["quotas"]["energy_attachment"] = false
		RegistryScript.BENCH:
			var own: Dictionary = state.get("own", {})
			var bench: Array = own.get("bench", [])
			if bench.size() >= _bench_capacity(state):
				return "bench_full"
			var card: Dictionary = action.get("card", {}) \
				if action.get("card", {}) is Dictionary else {}
			if card.is_empty():
				return "unbound_basic"
			bench.append({
				"slot_id": "projected:bench:%s" % str(card.get("instance_id", -1)),
				"pokemon": card.duplicate(true),
				"energy": [],
				"energy_count": 0,
				"tool": {},
				"damage": 0,
				"remaining_hp": int(card.get("hp", 0)),
				"max_hp": int(card.get("hp", 0)),
				"prize_count": 1,
				"retreat_cost": 0,
				"ability_used": false,
				"tera": false,
			})
			own["bench_count"] = bench.size()
			own["bench_slots_free"] = maxi(
				0,
				_bench_capacity(state) - bench.size()
			)
			own["bench_full"] = int(own.get("bench_slots_free", 0)) == 0
			own["overflow_if_default_capacity"] = maxi(
				0,
				bench.size() - int(own.get("default_bench_capacity", 5))
			)
		RegistryScript.EVOLVE:
			if str(action.get("target", "")) == "" \
					or not _own_slot_exists(str(action.get("target", "")), state):
				return "unbound_evolution_target"
		RegistryScript.PLAY_STADIUM:
			if not bool(state.get("quotas", {}).get("stadium", false)):
				return "stadium_quota_spent"
			state["stadium"] = (
				action.get("card", {}) as Dictionary
			).duplicate(true) if action.get("card", {}) is Dictionary else {}
			state["quotas"]["stadium"] = false
		RegistryScript.RETREAT_OR_SWITCH:
			if not bool(state.get("quotas", {}).get("retreat", false)) \
					and str(candidate.get("action_kind", "")) == "retreat":
				return "retreat_quota_spent"
			var target := _own_slot(str(action.get("target", "")), state)
			if target.is_empty():
				return "unbound_pivot_target"
			var old_active: Dictionary = state.get("own", {}).get("active", {})
			var bench: Array = state.get("own", {}).get("bench", [])
			var target_index := bench.find(target)
			if target_index < 0:
				return "pivot_target_not_benched"
			bench[target_index] = old_active
			state["own"]["active"] = target
			if str(candidate.get("action_kind", "")) == "retreat":
				state["quotas"]["retreat"] = false
		RegistryScript.ATTACK, RegistryScript.END_TURN:
			state["terminal"] = true
		RegistryScript.USE_PUBLIC_ABILITY:
			var source := _own_slot(str(action.get("source", "")), state)
			if source.is_empty():
				return "unbound_ability_source"
			source["ability_used"] = true
		RegistryScript.GUST, RegistryScript.RECOVER_PUBLIC_ZONE, \
				RegistryScript.MOVE_PUBLIC_ENERGY, RegistryScript.MOVE_PUBLIC_DAMAGE:
			# These operators are typed but their exact movement/selection is
			# interaction-owned.  They remain a reobservation boundary and never
			# manufacture a local verified advantage.
			pass
		_:
			return "unsupported_operator"
	return ""


func _own_slot(slot_id: String, state: Dictionary) -> Dictionary:
	if slot_id == "":
		return {}
	var own: Dictionary = state.get("own", {}) \
		if state.get("own", {}) is Dictionary else {}
	var active: Dictionary = own.get("active", {}) \
		if own.get("active", {}) is Dictionary else {}
	if str(active.get("slot_id", "")) == slot_id:
		return active
	for raw_slot: Variant in own.get("bench", []):
		if raw_slot is Dictionary and str((raw_slot as Dictionary).get("slot_id", "")) == slot_id:
			return raw_slot as Dictionary
	return {}


func _own_slot_exists(slot_id: String, state: Dictionary) -> bool:
	return not _own_slot(slot_id, state).is_empty()


func _bench_capacity(state: Dictionary) -> int:
	var own: Dictionary = state.get("own", {}) \
		if state.get("own", {}) is Dictionary else {}
	return int(own.get("bench_capacity", 5))


func _without_hash(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	result.erase("state_hash")
	return result


func _prediction_state(source: Dictionary) -> Dictionary:
	return {
		"schema_version": int(source.get("schema_version", 0)),
		"observation_hash": str(source.get("observation_hash", "")),
		"source_state_hash": str(source.get("state_hash", "")),
		"turn": (
			source.get("turn", {}) as Dictionary
		).duplicate(true) if source.get("turn", {}) is Dictionary else {},
		"quotas": (
			source.get("quotas", {}) as Dictionary
		).duplicate(true) if source.get("quotas", {}) is Dictionary else {},
		"own": (
			source.get("own", {}) as Dictionary
		).duplicate(true) if source.get("own", {}) is Dictionary else {},
		"opponent": (
			source.get("opponent", {}) as Dictionary
		).duplicate(true) if source.get("opponent", {}) is Dictionary else {},
		"stadium": (
			source.get("stadium", {}) as Dictionary
		).duplicate(true) if source.get("stadium", {}) is Dictionary else {},
	}
