class_name DeckTrainingPresentation
extends RefCounted


const MIN_FOCUS_LENGTH := 20
const MIN_ORDERED_STEPS := 4
const MIN_BAIT_LINES := 2
const MIN_GUIDE_LENGTH := 160


static func goal_summary(scenario: Dictionary) -> String:
	var turn_limit := clampi(int(scenario.get("turn_limit", 1)), 1, 2)
	var goal_variant: Variant = scenario.get("goal", {})
	var goal: Dictionary = goal_variant if goal_variant is Dictionary else {}
	var authored_summary := str(goal.get("summary", "")).strip_edges()
	if authored_summary != "":
		return authored_summary
	var goal_type := str(goal.get("type", ""))
	if goal_type == "compound":
		var progress_variant: Variant = goal.get("progress_goal", {})
		goal = progress_variant if progress_variant is Dictionary else {}
		goal_type = str(goal.get("type", ""))
	if goal_type == "target_knockouts":
		var targets_variant: Variant = goal.get("targets", [])
		var target_count := (targets_variant as Array).size() if targets_variant is Array else 0
		var required := maxi(1, int(goal.get("required", target_count)))
		return "%d回合击倒%d个指定目标" % [turn_limit, required]
	if goal_type == "prizes":
		return "%d回合拿%d奖" % [turn_limit, maxi(1, int(goal.get("count", 1)))]
	var fallback := str(scenario.get("objective", "")).strip_edges()
	return fallback if fallback != "" else "%d回合完成本关目标" % turn_limit


static func guide_text(scenario: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("本关目标：%s" % goal_summary(scenario))

	var focus := str(scenario.get("focus", "")).strip_edges()
	if focus != "":
		lines.append("")
		lines.append("解题思路")
		lines.append(focus)

	var design_contract_variant: Variant = scenario.get("design_contract", {})
	var design_contract: Dictionary = design_contract_variant if design_contract_variant is Dictionary else {}
	var combo_variant: Variant = design_contract.get("combo_contract", {})
	var combo: Dictionary = combo_variant if combo_variant is Dictionary else {}
	var steps_variant: Variant = combo.get("ordered_steps", [])
	var steps: Array = steps_variant if steps_variant is Array else []
	if not steps.is_empty():
		lines.append("")
		lines.append("操作步骤")
		for index: int in steps.size():
			lines.append("%d. %s" % [index + 1, str(steps[index]).strip_edges()])

	var baits_variant: Variant = design_contract.get("bait_lines", [])
	var baits: Array = baits_variant if baits_variant is Array else []
	if not baits.is_empty():
		lines.append("")
		lines.append("容易踩坑")
		for bait_variant: Variant in baits:
			if not (bait_variant is Dictionary):
				continue
			var bait: Dictionary = bait_variant
			var opening := str(bait.get("opening", "")).strip_edges()
			var reason := str(bait.get("fails_because", "")).strip_edges()
			var equation := str(bait.get("failed_equation", "")).strip_edges()
			var line := "• "
			if opening != "":
				line += "%s： " % opening
			line += reason
			if equation != "":
				line += "（%s）" % equation
			lines.append(line)

	var climax_variant: Variant = design_contract.get("climax_contract", {})
	var climax: Dictionary = climax_variant if climax_variant is Dictionary else {}
	var payoff := str(climax.get("exact_payoff", "")).strip_edges()
	if payoff != "":
		lines.append("")
		lines.append("完成标志")
		lines.append(payoff)

	return "\n".join(lines)


static func instruction_issues(scenario: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var scenario_id := str(scenario.get("id", "<unknown>"))
	var focus := str(scenario.get("focus", "")).strip_edges()
	if focus.length() < MIN_FOCUS_LENGTH:
		issues.append("%s focus is too short" % scenario_id)

	var design_contract_variant: Variant = scenario.get("design_contract", {})
	var design_contract: Dictionary = design_contract_variant if design_contract_variant is Dictionary else {}
	var combo_variant: Variant = design_contract.get("combo_contract", {})
	var combo: Dictionary = combo_variant if combo_variant is Dictionary else {}
	var steps_variant: Variant = combo.get("ordered_steps", [])
	var steps: Array = steps_variant if steps_variant is Array else []
	if steps.size() < MIN_ORDERED_STEPS:
		issues.append("%s needs at least %d ordered steps" % [scenario_id, MIN_ORDERED_STEPS])
	for index: int in steps.size():
		if str(steps[index]).strip_edges() == "":
			issues.append("%s has an empty operation step at %d" % [scenario_id, index + 1])

	var baits_variant: Variant = design_contract.get("bait_lines", [])
	var baits: Array = baits_variant if baits_variant is Array else []
	if baits.size() < MIN_BAIT_LINES:
		issues.append("%s needs at least %d losing-line explanations" % [scenario_id, MIN_BAIT_LINES])
	for index: int in baits.size():
		if not (baits[index] is Dictionary):
			issues.append("%s bait line %d is invalid" % [scenario_id, index + 1])
			continue
		var bait: Dictionary = baits[index]
		if str(bait.get("fails_because", "")).strip_edges() == "":
			issues.append("%s bait line %d does not explain the failure" % [scenario_id, index + 1])

	if guide_text(scenario).length() < MIN_GUIDE_LENGTH:
		issues.append("%s assembled guide is too short" % scenario_id)
	return issues
