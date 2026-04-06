extends RefCounted

const BattleI18nScript := preload("res://scripts/ui/battle/BattleI18n.gd")


func format_advice(result: Dictionary, progress_text: String = "") -> String:
	var status := str(result.get("status", ""))
	if status == "running":
		var running_progress := progress_text.strip_edges()
		if running_progress == "":
			running_progress = BattleI18nScript.t("battle.advice.progress")
		return "[b]%s[/b]\n%s" % [BattleI18nScript.t("battle.advice.running_title"), running_progress]

	var lines: Array[String] = []
	lines.append("[b]%s[/b] %s" % [
		BattleI18nScript.t("battle.advice.status_label"),
		_status_text(status),
	])

	if status == "failed":
		lines.append("")
		lines.append("[b]%s[/b]" % BattleI18nScript.t("battle.advice.error_label"))
		for error_variant: Variant in result.get("errors", []):
			if error_variant is Dictionary:
				lines.append("- %s" % str((error_variant as Dictionary).get("message", "")))
		return "\n".join(lines)

	var thesis := str(result.get("strategic_thesis", ""))
	if thesis != "":
		lines.append("")
		lines.append("[b]%s[/b]" % BattleI18nScript.t("battle.advice.thesis_label"))
		lines.append(thesis)

	_append_step_block(lines, BattleI18nScript.t("battle.advice.main_line_label"), result.get("current_turn_main_line", []))
	_append_branch_block(lines, BattleI18nScript.t("battle.advice.branch_label"), result.get("conditional_branches", []))
	_append_goal_block(lines, BattleI18nScript.t("battle.advice.prize_plan_label"), result.get("prize_plan", []))
	_append_string_list(lines, BattleI18nScript.t("battle.advice.rationale_label"), result.get("why_this_line", []))
	_append_risk_block(lines, BattleI18nScript.t("battle.advice.risk_label"), result.get("risk_watchouts", []))

	var confidence := str(result.get("confidence", ""))
	if confidence != "":
		lines.append("")
		lines.append("[b]%s[/b] %s" % [BattleI18nScript.t("battle.advice.confidence_label"), confidence])
	return "\n".join(lines)


func _append_step_block(lines: Array[String], title: String, steps_variant: Variant) -> void:
	if not (steps_variant is Array):
		return
	var steps: Array = steps_variant
	if steps.is_empty():
		return
	lines.append("")
	lines.append("[b]%s[/b]" % title)
	for step_variant: Variant in steps:
		if not (step_variant is Dictionary):
			continue
		var step: Dictionary = step_variant
		lines.append("%d. %s" % [int(step.get("step", 0)), str(step.get("action", ""))])
		var why := str(step.get("why", ""))
		if why != "":
			lines.append("   %s" % why)


func _append_branch_block(lines: Array[String], title: String, branches_variant: Variant) -> void:
	if not (branches_variant is Array):
		return
	var branches: Array = branches_variant
	if branches.is_empty():
		return
	lines.append("")
	lines.append("[b]%s[/b]" % title)
	for branch_variant: Variant in branches:
		if not (branch_variant is Dictionary):
			continue
		var branch: Dictionary = branch_variant
		lines.append("- %s" % BattleI18nScript.t("battle.advice.branch_prefix", {"condition": str(branch.get("if", ""))}))
		for step_variant: Variant in branch.get("then", []):
			lines.append("  - %s" % str(step_variant))


func _append_goal_block(lines: Array[String], title: String, goals_variant: Variant) -> void:
	if not (goals_variant is Array):
		return
	var goals: Array = goals_variant
	if goals.is_empty():
		return
	lines.append("")
	lines.append("[b]%s[/b]" % title)
	for goal_variant: Variant in goals:
		if not (goal_variant is Dictionary):
			continue
		var goal: Dictionary = goal_variant
		lines.append("- [%s] %s" % [str(goal.get("horizon", "")), str(goal.get("goal", ""))])


func _append_string_list(lines: Array[String], title: String, values_variant: Variant) -> void:
	if not (values_variant is Array):
		return
	var values: Array = values_variant
	if values.is_empty():
		return
	lines.append("")
	lines.append("[b]%s[/b]" % title)
	for value_variant: Variant in values:
		lines.append("- %s" % str(value_variant))


func _append_risk_block(lines: Array[String], title: String, risks_variant: Variant) -> void:
	if not (risks_variant is Array):
		return
	var risks: Array = risks_variant
	if risks.is_empty():
		return
	lines.append("")
	lines.append("[b]%s[/b]" % title)
	for risk_variant: Variant in risks:
		if not (risk_variant is Dictionary):
			continue
		var risk: Dictionary = risk_variant
		lines.append("- %s" % str(risk.get("risk", "")))
		var mitigation := str(risk.get("mitigation", ""))
		if mitigation != "":
			lines.append("  %s" % mitigation)


func _status_text(status: String) -> String:
	match status:
		"completed":
			return BattleI18nScript.t("battle.status.completed")
		"partial_success":
			return BattleI18nScript.t("battle.status.partial_success")
		"failed":
			return BattleI18nScript.t("battle.status.failed")
		"running":
			return BattleI18nScript.t("battle.status.running")
		_:
			return status
