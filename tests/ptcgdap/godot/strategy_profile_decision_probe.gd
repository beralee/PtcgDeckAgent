extends SceneTree
const Planner = preload("res://scripts/ai/ptcgdap/public/PublicPlanComparison.gd")
const Core = preload("res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd")

func ints(v: Variant) -> Variant:
	if v is float: return int(v)
	if v is Array:
		var out := []
		for x: Variant in v: out.append(ints(x))
		return out
	if v is Dictionary:
		var out := {}
		for k: Variant in v: out[k] = ints(v[k])
		return out
	return v

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var payload: Dictionary = ints(JSON.parse_string(FileAccess.get_file_as_string(args[0])))
	var failures := []; var rows := []; var max_us := 0
	for c: Dictionary in payload.cases:
		var start := Time.get_ticks_usec(); var actual := Planner.compare_plans(c.frame,c.ordered,c.get("profile","resource-continuity-v1"))
		max_us = maxi(max_us,Time.get_ticks_usec()-start)
		rows.append({"id":c.id,"result":actual})
		if actual != c.expected: failures.append(c.id)
	var compiled := Core.compile_local_uid(payload.policy,payload.allowed)
	if not compiled.accepted: failures.append(compiled.error_code)
	else:
		for c: Dictionary in payload.decisions:
			var a: Dictionary = c.authority
			var actual := Core.decide(compiled.policy,c.frame,a.mandatory_indexes,a.terminal_indexes,a.base_hard_tiers,a.base_vetoed_indexes)
			var compact := {"accepted":actual.accepted,"error_code":actual.error_code,"selected_indexes":actual.selected_indexes}
			rows.append({"id":c.id,"result":compact})
			if compact != c.expected: failures.append(c.id)
	for c: Dictionary in payload.get("compile_cases",[]):
		var actual := Core.compile_local_uid(c.policy,payload.allowed)
		if {"accepted":actual.accepted,"error_code":actual.error_code} != c.expected: failures.append(c.id)
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows,"failures":failures,"max_usec":max_us},"  ")); file.close()
	print(JSON.stringify({"cases":rows.size(),"failures":failures,"max_usec":max_us}))
	quit(0 if failures.is_empty() else 1)
