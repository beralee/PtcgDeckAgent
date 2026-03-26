class_name BenchmarkEvaluator
extends RefCounted

const EVENT_TO_DECK_KEY: Dictionary = {
	"miraidon_bench_developed": "miraidon",
	"electric_generator_resolved": "miraidon",
	"miraidon_attack_ready": "miraidon",
	"gardevoir_stage2_online": "gardevoir",
	"psychic_embrace_resolved": "gardevoir",
	"gardevoir_energy_loop_online": "gardevoir",
	"charizard_stage2_online": "charizard_ex",
	"charizard_evolution_support_used": "charizard_ex",
	"charizard_attack_ready": "charizard_ex",
}

const EVENT_ORDER: Array[String] = [
	"miraidon_bench_developed",
	"electric_generator_resolved",
	"miraidon_attack_ready",
	"gardevoir_stage2_online",
	"psychic_embrace_resolved",
	"gardevoir_energy_loop_online",
	"charizard_stage2_online",
	"charizard_evolution_support_used",
	"charizard_attack_ready",
]

const PASS_THRESHOLD := 0.30


func summarize_pairing(matches: Array[Dictionary], pairing_name: String) -> Dictionary:
	var summary := _make_empty_summary(pairing_name)
	var total_matches: int = matches.size()
	summary["total_matches"] = total_matches

	var pairing_deck_keys := _collect_pairing_deck_keys(matches)
	var deck_a_id := _get_pairing_deck_id(matches, "deck_a")
	var deck_b_id := _get_pairing_deck_id(matches, "deck_b")
	var wins_a: int = 0
	var wins_b: int = 0
	var turn_total: int = 0
	var stall_count: int = 0
	var cap_count: int = 0
	var failure_breakdown: Dictionary = {}
	var identity_breakdown: Dictionary = summary["identity_event_breakdown"]

	for event_key: String in EVENT_ORDER:
		var event_summary: Dictionary = identity_breakdown.get(event_key, {})
		var applicable_matches: int = 0
		var event_deck_key: String = str(EVENT_TO_DECK_KEY.get(event_key, ""))
		if pairing_deck_keys.has(event_deck_key):
			applicable_matches = total_matches
		event_summary["applicable_matches"] = applicable_matches
		event_summary["hit_matches"] = 0
		event_summary["hit_rate"] = 0.0
		identity_breakdown[event_key] = event_summary

	for match_variant: Variant in matches:
		if not match_variant is Dictionary:
			continue
		var match: Dictionary = match_variant
		turn_total += int(match.get("turn_count", 0))

		var failure_reason: String = str(match.get("failure_reason", ""))
		if failure_reason == "stalled_no_progress":
			stall_count += 1
		if failure_reason == "action_cap_reached":
			cap_count += 1
		if failure_reason != "" and failure_reason != "normal_game_end":
			failure_breakdown[failure_reason] = int(failure_breakdown.get(failure_reason, 0)) + 1

		var winner_index: int = int(match.get("winner_index", -1))
		var player_0_deck_id: int = int(match.get("player_0_deck_id", -1))
		var player_1_deck_id: int = int(match.get("player_1_deck_id", -1))
		if winner_index == 0:
			if player_0_deck_id == deck_a_id:
				wins_a += 1
			elif player_0_deck_id == deck_b_id:
				wins_b += 1
		elif winner_index == 1:
			if player_1_deck_id == deck_a_id:
				wins_a += 1
			elif player_1_deck_id == deck_b_id:
				wins_b += 1

		var identity_hits: Dictionary = _get_identity_hits(match)
		for event_key: String in EVENT_ORDER:
			var event_summary: Dictionary = identity_breakdown.get(event_key, {})
			if int(event_summary.get("applicable_matches", 0)) <= 0:
				continue
			if _get_identity_hit_value(identity_hits, event_key):
				event_summary["hit_matches"] = int(event_summary.get("hit_matches", 0)) + 1
			identity_breakdown[event_key] = event_summary

	for event_key: String in EVENT_ORDER:
		var event_summary: Dictionary = identity_breakdown.get(event_key, {})
		var applicable_matches: int = int(event_summary.get("applicable_matches", 0))
		var hit_matches: int = int(event_summary.get("hit_matches", 0))
		event_summary["hit_rate"] = 0.0 if applicable_matches <= 0 else float(hit_matches) / float(applicable_matches)
		identity_breakdown[event_key] = event_summary

	var applicable_event_count: int = 0
	var passed_event_count: int = 0
	for event_key: String in EVENT_ORDER:
		var event_summary: Dictionary = identity_breakdown.get(event_key, {})
		var applicable_matches: int = int(event_summary.get("applicable_matches", 0))
		if applicable_matches <= 0:
			continue
		applicable_event_count += 1
		if float(event_summary.get("hit_rate", 0.0)) >= PASS_THRESHOLD:
			passed_event_count += 1

	summary["wins_a"] = wins_a
	summary["wins_b"] = wins_b
	summary["win_rate_a"] = 0.0 if total_matches <= 0 else float(wins_a) / float(total_matches)
	summary["win_rate_b"] = 0.0 if total_matches <= 0 else float(wins_b) / float(total_matches)
	summary["average_turn_count"] = 0.0 if total_matches <= 0 else float(turn_total) / float(total_matches)
	summary["avg_turn_count"] = summary["average_turn_count"]
	summary["stall_rate"] = 0.0 if total_matches <= 0 else float(stall_count) / float(total_matches)
	summary["cap_termination_rate"] = 0.0 if total_matches <= 0 else float(cap_count) / float(total_matches)
	summary["failure_breakdown"] = failure_breakdown
	summary["identity_event_breakdown"] = identity_breakdown
	summary["identity_check_pass_rate"] = 0.0 if applicable_event_count <= 0 else float(passed_event_count) / float(applicable_event_count)
	return summary


func build_text_summary(summary: Dictionary) -> String:
	var pairing := str(summary.get("pairing", ""))
	var total_matches: int = int(summary.get("total_matches", 0))
	var wins_a: int = int(summary.get("wins_a", 0))
	var wins_b: int = int(summary.get("wins_b", 0))
	var win_rate_a: float = float(summary.get("win_rate_a", 0.0))
	var win_rate_b: float = float(summary.get("win_rate_b", 0.0))
	var average_turn_count: float = float(summary.get("average_turn_count", summary.get("avg_turn_count", 0.0)))
	var stall_count: int = _rate_to_count(float(summary.get("stall_rate", 0.0)), total_matches)
	var cap_count: int = _rate_to_count(float(summary.get("cap_termination_rate", 0.0)), total_matches)
	var pass_rate: float = float(summary.get("identity_check_pass_rate", 0.0))
	return "%s | matches=%d | wins_a=%d (win_rate_a=%.1f%%) | wins_b=%d (win_rate_b=%.1f%%) | average_turn_count=%.2f | stalls=%d | caps=%d | identity_check_pass_rate=%.1f%%" % [
		pairing,
		total_matches,
		wins_a,
		win_rate_a * 100.0,
		wins_b,
		win_rate_b * 100.0,
		average_turn_count,
		stall_count,
		cap_count,
		pass_rate * 100.0,
	]


func _make_empty_summary(pairing_name: String) -> Dictionary:
	var identity_event_breakdown := {}
	for event_key: String in EVENT_ORDER:
		identity_event_breakdown[event_key] = {
			"applicable_matches": 0,
			"hit_matches": 0,
			"hit_rate": 0.0,
		}
	return {
		"pairing": pairing_name,
		"total_matches": 0,
		"wins_a": 0,
		"wins_b": 0,
		"win_rate_a": 0.0,
		"win_rate_b": 0.0,
		"avg_turn_count": 0.0,
		"stall_rate": 0.0,
		"cap_termination_rate": 0.0,
		"failure_breakdown": {},
		"identity_check_pass_rate": 0.0,
		"identity_event_breakdown": identity_event_breakdown,
	}


func _collect_pairing_deck_keys(matches: Array[Dictionary]) -> Dictionary:
	var deck_keys: Dictionary = {}
	for match_variant: Variant in matches:
		if not match_variant is Dictionary:
			continue
		var match: Dictionary = match_variant
		var deck_a_variant: Variant = match.get("deck_a", {})
		var deck_b_variant: Variant = match.get("deck_b", {})
		var deck_a: Dictionary = deck_a_variant if deck_a_variant is Dictionary else {}
		var deck_b: Dictionary = deck_b_variant if deck_b_variant is Dictionary else {}
		var deck_a_key: String = str(deck_a.get("deck_key", ""))
		var deck_b_key: String = str(deck_b.get("deck_key", ""))
		if deck_a_key != "":
			deck_keys[deck_a_key] = true
		if deck_b_key != "":
			deck_keys[deck_b_key] = true
	return deck_keys


func _get_pairing_deck_id(matches: Array[Dictionary], deck_label: String) -> int:
	for match_variant: Variant in matches:
		if not match_variant is Dictionary:
			continue
		var match: Dictionary = match_variant
		var deck_variant: Variant = match.get(deck_label, {})
		var deck: Dictionary = deck_variant if deck_variant is Dictionary else {}
		var deck_id: int = int(deck.get("deck_id", -1))
		if deck_id > 0:
			return deck_id
	return -1


func _get_identity_hits(match: Dictionary) -> Dictionary:
	var raw_identity_hits: Variant = match.get("identity_hits", {})
	if raw_identity_hits is Dictionary:
		return raw_identity_hits
	return {}


func _get_identity_hit_value(identity_hits: Dictionary, event_key: String) -> bool:
	if identity_hits.has(event_key):
		return bool(identity_hits.get(event_key, false))
	for key: Variant in identity_hits.keys():
		var nested: Variant = identity_hits.get(key)
		if nested is Dictionary and (nested as Dictionary).has(event_key):
			return bool((nested as Dictionary).get(event_key, false))
	return false


func _rate_to_count(rate: float, total_matches: int) -> int:
	if total_matches <= 0:
		return 0
	return int(round(rate * float(total_matches)))
