class_name BattleMatchEndQuickReviewBuilder
extends RefCounted


func build_payload(match_end_stats: Dictionary, view_player: int, review_match_dir: String) -> Dictionary:
	var stats := match_end_stats.duplicate(true)
	normalize_stats(stats, view_player)
	stats["deck_names"] = [
		GameManager.resolve_battle_player_display_name(0),
		GameManager.resolve_battle_player_display_name(1),
	]
	stats["review_subject"] = subject(stats, view_player)
	var digest := digest_context(review_match_dir)
	if not digest.is_empty():
		stats["quick_review_context"] = digest
	var strategies := deck_strategies()
	if not strategies.is_empty():
		stats["deck_strategies"] = strategies
	return stats


func normalize_stats(stats: Dictionary, view_player: int) -> void:
	var subject_index := subject_player_index(stats, view_player)
	var opponent_index := 1 - subject_index
	var players_variant: Variant = stats.get("players", [])
	if players_variant is Array:
		var players: Array = players_variant
		if subject_index >= 0 and subject_index < players.size() and players[subject_index] is Dictionary:
			stats["view_player"] = (players[subject_index] as Dictionary).duplicate(true)
		if opponent_index >= 0 and opponent_index < players.size() and players[opponent_index] is Dictionary:
			stats["opponent"] = (players[opponent_index] as Dictionary).duplicate(true)
	stats["view_player_index"] = subject_index
	stats["opponent_index"] = opponent_index
	stats["is_view_player_winner"] = int(stats.get("winner_index", -1)) == subject_index
	stats["result_label"] = "胜利" if bool(stats.get("is_view_player_winner", false)) else "失败"


func subject_player_index(stats: Dictionary = {}, view_player: int = 0) -> int:
	if GameManager.current_mode == GameManager.GameMode.VS_AI or GameManager.is_tournament_battle_active():
		return 0
	return clampi(int(stats.get("view_player_index", view_player)), 0, 1)


func subject(stats: Dictionary, view_player: int) -> Dictionary:
	var subject_index := subject_player_index(stats, view_player)
	var opponent_index := int(stats.get("opponent_index", 1 - subject_index))
	var is_winner := bool(stats.get("is_view_player_winner", int(stats.get("winner_index", -1)) == subject_index))
	var subject_stats: Dictionary = stats.get("view_player", {})
	var opponent_stats: Dictionary = stats.get("opponent", {})
	return {
		"role": "current_view_player",
		"player_index": subject_index,
		"label": GameManager.resolve_battle_player_display_name(subject_index),
		"deck_name": deck_name(subject_index),
		"opponent_index": opponent_index,
		"opponent_label": GameManager.resolve_battle_player_display_name(opponent_index),
		"opponent_deck_name": deck_name(opponent_index),
		"result": "win" if is_winner else "loss",
		"result_label": "胜利" if is_winner else "失败",
		"prizes_taken": int(subject_stats.get("prizes_taken", 0)),
		"opponent_prizes_taken": int(opponent_stats.get("prizes_taken", 0)),
		"review_instruction": "只评价当前玩家的胜负原因、打牌过程和下一盘改进；对手只作为当前玩家需要应对的压力或窗口。",
	}


func deck_name(player_index: int) -> String:
	var deck: DeckData = GameManager.resolve_selected_battle_deck(player_index)
	return deck.deck_name if deck != null else ""


func digest_context(review_match_dir: String) -> Dictionary:
	var digest := read_digest(review_match_dir)
	if digest.is_empty():
		return {}
	var context := {
		"meta": digest.get("meta", {}),
		"opening": digest.get("opening", {}),
		"key_moments": key_moments_from_digest(digest),
		"critical_sequences": compact_sequences(digest.get("critical_sequences", []), 3),
		"recent_turns": recent_turns(digest.get("turn_summaries", []), 3),
	}
	var last := last_turn(digest.get("turn_summaries", []))
	if not last.is_empty():
		context["last_turn"] = last
	return context


func read_digest(review_match_dir: String) -> Dictionary:
	var match_dir := review_match_dir.strip_edges()
	if match_dir == "":
		return {}
	var path := match_dir.path_join("llm_digest.json")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func key_moments_from_digest(digest: Dictionary) -> Array[Dictionary]:
	var moments: Array[Dictionary] = []
	var points_variant: Variant = digest.get("inflection_points", [])
	if points_variant is Array:
		for point_variant: Variant in points_variant:
			if not (point_variant is Dictionary):
				continue
			var point: Dictionary = point_variant
			var summary := str(point.get("summary", "")).strip_edges()
			if summary == "":
				continue
			moments.append({
				"turn_number": int(point.get("turn_number", 0)),
				"player_index": int(point.get("player_index", -1)),
				"kind": str(point.get("kind", "")),
				"summary": summary.left(160),
			})
			if moments.size() >= 4:
				return moments
	if not moments.is_empty():
		return moments
	var sequences_variant: Variant = digest.get("critical_sequences", [])
	if sequences_variant is Array:
		for sequence_variant: Variant in sequences_variant:
			if not (sequence_variant is Dictionary):
				continue
			var sequence: Dictionary = sequence_variant
			var summary := str(sequence.get("summary", "")).strip_edges()
			if summary == "":
				var actions: Array = sequence.get("actions", [])
				for action_variant: Variant in actions:
					var action_text := str(action_variant).strip_edges()
					if action_text != "":
						summary = action_text
						break
			if summary == "":
				continue
			moments.append({
				"turn_number": int(sequence.get("turn_number", 0)),
				"player_index": int(sequence.get("player_index", -1)),
				"kind": str(sequence.get("kind", "critical_sequence")),
				"summary": summary.left(160),
			})
			if moments.size() >= 3:
				return moments
	return moments


func compact_sequences(sequences_variant: Variant, max_items: int) -> Array[Dictionary]:
	var compact: Array[Dictionary] = []
	if not (sequences_variant is Array):
		return compact
	for sequence_variant: Variant in sequences_variant:
		if not (sequence_variant is Dictionary):
			continue
		var sequence: Dictionary = sequence_variant
		compact.append({
			"turn_number": int(sequence.get("turn_number", 0)),
			"player_index": int(sequence.get("player_index", -1)),
			"kind": str(sequence.get("kind", "")),
			"summary": str(sequence.get("summary", "")).left(160),
			"actions": compact_string_array(sequence.get("actions", []), 4),
		})
		if compact.size() >= max_items:
			break
	return compact


func recent_turns(turns_variant: Variant, max_items: int) -> Array[Dictionary]:
	var turns: Array = turns_variant if turns_variant is Array else []
	var recent: Array[Dictionary] = []
	var start_index: int = maxi(0, turns.size() - max_items)
	for i: int in range(start_index, turns.size()):
		var turn_variant: Variant = turns[i]
		if turn_variant is Dictionary:
			recent.append(compact_turn(turn_variant as Dictionary))
	return recent


func last_turn(turns_variant: Variant) -> Dictionary:
	if not (turns_variant is Array):
		return {}
	var turns: Array = turns_variant
	for i: int in range(turns.size() - 1, -1, -1):
		if turns[i] is Dictionary:
			return compact_turn(turns[i] as Dictionary)
	return {}


func compact_turn(turn: Dictionary) -> Dictionary:
	return {
		"turn_number": int(turn.get("turn_number", 0)),
		"key_actions": compact_action_summaries(turn.get("key_actions", []), 4),
		"key_choices": compact_choice_summaries(turn.get("key_choices", []), 3),
	}


func compact_action_summaries(actions_variant: Variant, max_items: int) -> Array[Dictionary]:
	var compact: Array[Dictionary] = []
	if not (actions_variant is Array):
		return compact
	for action_variant: Variant in actions_variant:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var description := str(action.get("description", "")).strip_edges()
		if description == "":
			continue
		compact.append({
			"player_index": int(action.get("player_index", -1)),
			"description": description.left(160),
			"attack_name": str(action.get("attack_name", "")),
			"damage": int(action.get("damage", 0)),
			"prize_count": int(action.get("prize_count", 0)),
		})
		if compact.size() >= max_items:
			break
	return compact


func compact_choice_summaries(choices_variant: Variant, max_items: int) -> Array[Dictionary]:
	var compact: Array[Dictionary] = []
	if not (choices_variant is Array):
		return compact
	for choice_variant: Variant in choices_variant:
		if not (choice_variant is Dictionary):
			continue
		var choice: Dictionary = choice_variant
		compact.append({
			"player_index": int(choice.get("player_index", -1)),
			"title": str(choice.get("title", "")).left(120),
			"selected_labels": compact_string_array(choice.get("selected_labels", []), 4),
			"option_labels": compact_string_array(choice.get("option_labels", []), 6),
		})
		if compact.size() >= max_items:
			break
	return compact


func compact_string_array(values_variant: Variant, max_items: int) -> Array[String]:
	var compact: Array[String] = []
	if not (values_variant is Array):
		return compact
	for value_variant: Variant in values_variant:
		var value := str(value_variant).strip_edges()
		if value == "":
			continue
		compact.append(value.left(120))
		if compact.size() >= max_items:
			break
	return compact


func deck_strategies() -> Array[Dictionary]:
	var strategies: Array[Dictionary] = []
	for player_index: int in range(GameManager.selected_deck_ids.size()):
		var deck_id: int = int(GameManager.selected_deck_ids[player_index])
		var deck: DeckData = CardDatabase.get_deck(deck_id) if deck_id > 0 else null
		if deck == null:
			continue
		var strategy := deck.strategy.strip_edges()
		if strategy == "":
			continue
		strategies.append({
			"player_index": player_index,
			"deck_name": deck.deck_name,
			"strategy": strategy.left(700),
		})
	return strategies


func fallback_from_failure(
	failed_result: Dictionary,
	match_end_stats: Dictionary,
	winner_index: int,
	view_player: int,
	review_match_dir: String
) -> Dictionary:
	var fallback := local_review(match_end_stats, winner_index, view_player, review_match_dir)
	fallback["status"] = "ai_failed_fallback"
	fallback["ai_error"] = error_message(failed_result)
	fallback["failed_ai_result"] = failed_result.duplicate(true)
	return fallback


func error_message(result: Dictionary) -> String:
	var error: Dictionary = {}
	var errors_variant: Variant = result.get("errors", [])
	if errors_variant is Array:
		var errors_array := errors_variant as Array
		if not errors_array.is_empty() and errors_array[0] is Dictionary:
			error = errors_array[0] as Dictionary
	var error_type := str(error.get("error_type", result.get("error_type", ""))).strip_edges()
	var message := str(error.get("message", result.get("message", ""))).strip_edges()
	var http_code := int(error.get("http_code", result.get("http_code", 0)))
	var request_error := int(error.get("request_error", result.get("request_error", 0)))
	var diagnostic := ("%s %s" % [error_type, message]).to_lower()
	if diagnostic.contains("timeout") or diagnostic.contains("timed out"):
		return "AI 快评超时，已使用本地专业快评。"
	if diagnostic.contains("connect") or diagnostic.contains("resolve") or diagnostic.contains("network") or diagnostic.contains("tls") or diagnostic.contains("no response"):
		return "AI 服务暂时连接不上，已使用本地专业快评。"
	if http_code == 401 or http_code == 403:
		return "AI 服务鉴权失败，已使用本地专业快评。请稍后检查 AI 设置里的 API Key。"
	if http_code == 429:
		return "AI 服务请求过于频繁，已使用本地专业快评。"
	if http_code >= 500:
		return "AI 服务暂时异常，已使用本地专业快评。"
	if http_code > 0:
		return "AI 服务返回 %d，已使用本地专业快评。" % http_code
	if request_error != OK:
		return "AI 快评请求未能发出，已使用本地专业快评。"
	return "AI 快评暂不可用，已使用本地专业快评。"


func local_review(match_end_stats: Dictionary, winner_index: int, view_player: int, review_match_dir: String) -> Dictionary:
	var review_stats := match_end_stats.duplicate(true)
	normalize_stats(review_stats, view_player)
	var subject_index := subject_player_index(review_stats, view_player)
	var is_win := winner_index == subject_index
	var player_stats: Dictionary = review_stats.get("view_player", {})
	var opponent_stats: Dictionary = review_stats.get("opponent", {})
	var prize_gap := int(player_stats.get("prizes_taken", 0)) - int(opponent_stats.get("prizes_taken", 0))
	var score := 56
	score += 14 if is_win else -8
	score += prize_gap * 5
	score += mini(8, int(player_stats.get("max_damage", 0)) / 40)
	score += mini(6, int(player_stats.get("knockouts", 0)) * 2)
	score += mini(6, int(player_stats.get("tempo_actions", 0)) / 2)
	score = clampi(score, 32, 95)
	var digest := digest_context(review_match_dir)
	var key_moment := primary_key_moment_text(digest.get("key_moments", []))
	var headline := ""
	var praise := ""
	var improvement := ""
	var next_goal := ""
	if is_win:
		headline = "主线兑现到位，奖赏节奏领先"
		praise = "关键节点处理清晰，%s。" % key_moment if key_moment != "" else "奖赏推进、攻击兑现和终结节奏比较明确。"
		improvement = "继续检查前两回合是否有更少资源消耗的同等攻击路线。"
		next_goal = "下一盘保持主攻手成型速度，同时避免在攻击已成立后继续无效挖牌。"
	else:
		headline = "需要复盘关键窗口的资源顺序"
		praise = "这盘至少留下了明确的复盘节点，%s。" % key_moment if key_moment != "" else "本局统计足够定位奖赏差和启动节奏问题。"
		improvement = "优先倒推关键节点前一回合：是否应先找攻击手、能量、换位或保留干扰资源。"
		next_goal = "下一盘把前两回合目标压缩成：稳定站场、完成能量路线、制造第一次有效击倒。"
	return {
		"status": "local",
		"score": score,
		"grade": grade_for_score(score),
		"headline": headline,
		"praise": praise,
		"improvement": improvement,
		"next_goal": next_goal,
		"key_moment": key_moment,
	}


func primary_key_moment_text(moments_variant: Variant) -> String:
	if not (moments_variant is Array):
		return ""
	var moments: Array = moments_variant
	for moment_variant: Variant in moments:
		if not (moment_variant is Dictionary):
			continue
		var moment: Dictionary = moment_variant
		var summary := str(moment.get("summary", "")).strip_edges()
		if summary == "":
			continue
		var turn_number := int(moment.get("turn_number", 0))
		return "第%d回合 %s" % [turn_number, summary] if turn_number > 0 else summary
	return ""


func grade_for_score(score: int) -> String:
	if score >= 90:
		return "S"
	if score >= 78:
		return "A"
	if score >= 66:
		return "B"
	if score >= 52:
		return "C"
	return "D"
