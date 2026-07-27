class_name V18CPGTransitionRegistry
extends RefCounted

const BENCH := "BENCH"
const EVOLVE := "EVOLVE"
const ATTACH_ENERGY := "ATTACH_ENERGY"
const USE_PUBLIC_ABILITY := "USE_PUBLIC_ABILITY"
const PLAY_STADIUM := "PLAY_STADIUM"
const RETREAT_OR_SWITCH := "RETREAT_OR_SWITCH"
const GUST := "GUST"
const RECOVER_PUBLIC_ZONE := "RECOVER_PUBLIC_ZONE"
const MOVE_PUBLIC_ENERGY := "MOVE_PUBLIC_ENERGY"
const MOVE_PUBLIC_DAMAGE := "MOVE_PUBLIC_DAMAGE"
const ATTACK := "ATTACK"
const END_TURN := "END_TURN"
const UNSUPPORTED := "UNSUPPORTED"


func operator_for(candidate: Dictionary) -> String:
	var kind := str(candidate.get("action_kind", candidate.get("action_ref", {}).get("kind", "")))
	var route_id := str(candidate.get("route_id", ""))
	if kind == "play_basic_to_bench":
		return BENCH
	if kind == "evolve":
		return EVOLVE
	if kind == "attach_energy":
		return ATTACH_ENERGY
	if route_id == "route:damage_counter_control":
		return MOVE_PUBLIC_DAMAGE
	if kind == "use_ability":
		return USE_PUBLIC_ABILITY
	if kind == "play_stadium":
		return PLAY_STADIUM
	if kind == "retreat" or route_id == "route:pivot":
		return RETREAT_OR_SWITCH
	if route_id == "route:gust":
		return GUST
	if route_id == "route:recover":
		return RECOVER_PUBLIC_ZONE
	if route_id == "route:accelerate":
		return MOVE_PUBLIC_ENERGY
	if kind in ["attack", "granted_attack"]:
		return ATTACK
	if kind == "end_turn":
		return END_TURN
	return UNSUPPORTED


func is_information_boundary(candidate: Dictionary) -> bool:
	return str(candidate.get("checkpoint_after", "")) == "information_result" \
		or str(candidate.get("route_id", "")) in [
			"route:information",
			"route:noctowl_search",
			"route:opening_search",
			"route:tutor",
		]


func is_terminal(operator: String) -> bool:
	return operator in [ATTACK, END_TURN]
