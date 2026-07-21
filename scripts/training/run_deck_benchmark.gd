## 通用卡组 vs 密勒顿基准测试
## 用法：
##   godot --headless --path . res://scripts/training/run_deck_benchmark.tscn -- \
##     --deck-id=578647 --games=100 --seed-base=5000 --json-output=user://benchmark_result.json
##
## 参数：
##   --deck-id=N          必填，被测卡组 ID
##   --anchor-id=N        可选，对手卡组 ID（默认密勒顿 575720）
##   --games=N            可选，对局数（默认 100）
##   --seed-base=N        可选，种子起始值（默认 5000）
##   --max-steps=N        可选，每局最大步数（默认 200）
##   --json-output=PATH   可选，结果 JSON 输出路径
##   --decision-mode=MODE 可选，rules_only / rules_plus_learned / heuristic_only
extends Control

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DeckStrategyV18ProfileCatalogScript = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")
const AIFixedDeckOrderRegistryScript = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")

const DEFAULT_ANCHOR_ID := 575720
const DEFAULT_GAMES := 100
const DEFAULT_SEED_BASE := 5000
const DEFAULT_MAX_STEPS := 200
const PROVENANCE_SCHEMA_VERSION := 1
const AI_SOURCE_ROOT := "res://scripts/ai"
const BENCHMARK_RUNNER_SOURCE_PATH := "res://scripts/training/run_deck_benchmark.gd"


class BenchmarkTraceCollector:
	var traces: Array = []

	func record_trace(trace) -> void:
		if trace == null:
			return
		traces.append(trace.clone())


func _ready() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var deck_id: int = int(options.get("deck_id", 0))
	var anchor_id: int = int(options.get("anchor_id", DEFAULT_ANCHOR_ID))
	var games: int = int(options.get("games", DEFAULT_GAMES))
	var seed_base: int = int(options.get("seed_base", DEFAULT_SEED_BASE))
	var max_steps: int = int(options.get("max_steps", DEFAULT_MAX_STEPS))
	var json_output: String = str(options.get("json_output", ""))
	var deck_decision_mode: String = str(options.get("deck_decision_mode", options.get("decision_mode", "")))
	var anchor_decision_mode: String = str(options.get("anchor_decision_mode", ""))
	var deck_strong_fixed_opening: bool = bool(options.get("deck_strong_fixed_opening", false))
	var anchor_strong_fixed_opening: bool = bool(options.get("anchor_strong_fixed_opening", false))
	var trace_game: int = int(options.get("trace_game", 0))
	var trace_jsonl_output: String = str(options.get("trace_jsonl_output", ""))
	var decision_mode: String = deck_decision_mode

	if deck_id <= 0:
		print("[错误] 缺少 --deck-id 参数")
		_quit(1)
		return

	var deck: DeckData = CardDatabase.get_deck(deck_id)
	var anchor_deck: DeckData = CardDatabase.get_deck(anchor_id)
	if deck == null:
		print("[错误] 无法加载卡组 %d" % deck_id)
		_quit(1)
		return
	if anchor_deck == null:
		print("[错误] 无法加载锚定卡组 %d" % anchor_id)
		_quit(1)
		return

	var source_provenance := _build_source_provenance()
	var deck_strategy_provenance := _build_strategy_provenance(deck)
	var anchor_strategy_provenance := _build_strategy_provenance(anchor_deck)

	print("===== 卡组基准测试 =====")
	print("被测卡组: %s (%d)" % [deck.deck_name, deck_id])
	print("对手卡组: %s (%d)" % [anchor_deck.deck_name, anchor_id])
	print("对局数: %d  种子起始: %d  最大步数: %d" % [games, seed_base, max_steps])
	if decision_mode != "":
		print("决策模式: %s" % decision_mode)
	print("")

	var runner := AIBenchmarkRunnerScript.new()
	var fixed_order_registry := AIFixedDeckOrderRegistryScript.new()
	var start_time := Time.get_ticks_msec()

	var wins: int = 0
	var losses: int = 0
	var draws: int = 0
	var total_turns: int = 0
	var failure_reasons: Dictionary = {}
	var per_game: Array[Dictionary] = []
	var turn_list_wins: Array[int] = []
	var turn_list_losses: Array[int] = []
	var trace_collector: BenchmarkTraceCollector = null
	var trace_provenance: Dictionary = {}

	for i: int in games:
		var seed_val: int = seed_base + i
		var tracked_player: int = i % 2
		var gsm := GameStateMachine.new()
		if gsm.coin_flipper != null:
			var rng: Variant = gsm.coin_flipper.get("_rng")
			if rng is RandomNumberGenerator:
				(rng as RandomNumberGenerator).seed = seed_val
		var ps := PlayerState.new()
		if ps.has_method("set_forced_shuffle_seed"):
			ps.call("set_forced_shuffle_seed", seed_val)

		var p0_deck: DeckData = deck if tracked_player == 0 else anchor_deck
		var p1_deck: DeckData = anchor_deck if tracked_player == 0 else deck
		var p0_strong_fixed: bool = deck_strong_fixed_opening if tracked_player == 0 else anchor_strong_fixed_opening
		var p1_strong_fixed: bool = anchor_strong_fixed_opening if tracked_player == 0 else deck_strong_fixed_opening
		var p0_fixed_order_path := _apply_fixed_order_if_enabled(gsm, 0, int(p0_deck.id), p0_strong_fixed, fixed_order_registry)
		var p1_fixed_order_path := _apply_fixed_order_if_enabled(gsm, 1, int(p1_deck.id), p1_strong_fixed, fixed_order_registry)
		gsm.start_game(p0_deck, p1_deck, 0)

		var p0_decision_mode := deck_decision_mode if tracked_player == 0 else anchor_decision_mode
		var p1_decision_mode := anchor_decision_mode if tracked_player == 0 else deck_decision_mode
		var p0_ai := _make_ai(0, p0_deck, p0_decision_mode, p0_strong_fixed)
		var p1_ai := _make_ai(1, p1_deck, p1_decision_mode, p1_strong_fixed)
		var p0_strategy_provenance: Dictionary = deck_strategy_provenance if tracked_player == 0 else anchor_strategy_provenance
		var p1_strategy_provenance: Dictionary = anchor_strategy_provenance if tracked_player == 0 else deck_strategy_provenance
		var game_provenance := {
			"schema_version": PROVENANCE_SCHEMA_VERSION,
			"seed": seed_val,
			"tracked_player": tracked_player,
			"source": source_provenance.duplicate(true),
			"players": {
				"0": _build_player_provenance(p0_strategy_provenance, p0_strong_fixed, p0_fixed_order_path),
				"1": _build_player_provenance(p1_strategy_provenance, p1_strong_fixed, p1_fixed_order_path),
			},
		}
		var game_trace_collector: BenchmarkTraceCollector = null
		if trace_jsonl_output != "" and trace_game == i + 1:
			game_trace_collector = BenchmarkTraceCollector.new()
			trace_collector = game_trace_collector
			trace_provenance = game_provenance.duplicate(true)
			trace_provenance["game"] = i + 1

		var result: Dictionary = runner.run_headless_duel(p0_ai, p1_ai, gsm, max_steps, Callable(), game_trace_collector)

		if ps.has_method("clear_forced_shuffle_seed"):
			ps.call("clear_forced_shuffle_seed")

		var winner_index: int = int(result.get("winner_index", -1))
		var turn_count: int = int(result.get("turn_count", 0))
		total_turns += turn_count

		var outcome: String = "draw"
		if winner_index == tracked_player:
			wins += 1
			outcome = "win"
			turn_list_wins.append(turn_count)
		elif winner_index >= 0:
			losses += 1
			outcome = "loss"
			turn_list_losses.append(turn_count)
		else:
			draws += 1

		var fr: String = str(result.get("failure_reason", ""))
		if fr != "":
			failure_reasons[fr] = int(failure_reasons.get(fr, 0)) + 1

		per_game.append({
			"game": i + 1,
			"seed": seed_val,
			"tracked_player": tracked_player,
			"outcome": outcome,
			"turns": turn_count,
			"steps": int(result.get("steps", 0)),
			"failure_reason": fr,
			"stalled": bool(result.get("stalled", false)),
			"terminated_by_cap": bool(result.get("terminated_by_cap", false)),
			"player_0_fixed_order_path": p0_fixed_order_path,
			"player_1_fixed_order_path": p1_fixed_order_path,
			"provenance": game_provenance,
		})

		if (i + 1) % 10 == 0:
			print("  进度: %d/%d  胜:%d  负:%d  平:%d" % [i + 1, games, wins, losses, draws])

	var elapsed: float = float(Time.get_ticks_msec() - start_time) / 1000.0
	var total: int = maxi(games, 1)
	var win_rate: float = float(wins) / float(total)
	var avg_turns: float = float(total_turns) / float(total)
	var source_provenance_at_end := _build_source_provenance()
	var source_changed_during_run := str(source_provenance.get("fingerprint", "")) != str(source_provenance_at_end.get("fingerprint", ""))
	if not trace_provenance.is_empty():
		trace_provenance["source_at_end"] = source_provenance_at_end.duplicate(true)
		trace_provenance["source_changed_during_run"] = source_changed_during_run

	# 判定基准是否干净
	var is_clean: bool = true
	var dirty_reasons: Array[String] = []
	for dirty_key: String in ["unsupported_prompt", "unsupported_interaction_step", "action_cap_reached", "stalled_no_progress"]:
		if int(failure_reasons.get(dirty_key, 0)) > 0:
			is_clean = false
			dirty_reasons.append("%s:%d" % [dirty_key, int(failure_reasons[dirty_key])])
	if source_changed_during_run:
		is_clean = false
		dirty_reasons.append("source_changed_during_run")

	print("")
	print("===== 结果 =====")
	print("胜: %d (%.1f%%)  负: %d (%.1f%%)  平: %d (%.1f%%)" % [
		wins, win_rate * 100.0,
		losses, float(losses) / float(total) * 100.0,
		draws, float(draws) / float(total) * 100.0])
	print("平均回合: %.1f  耗时: %.1f秒" % [avg_turns, elapsed])
	if not turn_list_wins.is_empty():
		turn_list_wins.sort()
		print("胜局回合: 中位数=%d 范围=%d-%d" % [
			turn_list_wins[turn_list_wins.size() / 2],
			turn_list_wins[0], turn_list_wins[-1]])
	if not turn_list_losses.is_empty():
		turn_list_losses.sort()
		print("败局回合: 中位数=%d 范围=%d-%d" % [
			turn_list_losses[turn_list_losses.size() / 2],
			turn_list_losses[0], turn_list_losses[-1]])
	if not failure_reasons.is_empty():
		print("失败原因: %s" % JSON.stringify(failure_reasons))
	print("基准干净: %s%s" % ["是" if is_clean else "否", (" (%s)" % ", ".join(dirty_reasons)) if not dirty_reasons.is_empty() else ""])

	# 导出 JSON
	var report := {
		"deck_id": deck_id,
		"deck_name": deck.deck_name,
		"anchor_id": anchor_id,
		"anchor_name": anchor_deck.deck_name,
		"games": games,
		"seed_base": seed_base,
		"decision_mode": decision_mode,
		"deck_decision_mode": deck_decision_mode,
		"anchor_decision_mode": anchor_decision_mode,
		"deck_strong_fixed_opening": deck_strong_fixed_opening,
		"anchor_strong_fixed_opening": anchor_strong_fixed_opening,
		"trace_game": trace_game,
		"trace_jsonl_output": trace_jsonl_output,
		"wins": wins,
		"losses": losses,
		"draws": draws,
		"win_rate": win_rate,
		"avg_turns": avg_turns,
		"is_clean": is_clean,
		"failure_reasons": failure_reasons,
		"elapsed_seconds": elapsed,
		"timestamp": Time.get_datetime_string_from_system(),
		"provenance": {
			"schema_version": PROVENANCE_SCHEMA_VERSION,
			"source": source_provenance,
			"source_at_end": source_provenance_at_end,
			"source_changed_during_run": source_changed_during_run,
			"deck_strategy": deck_strategy_provenance,
			"anchor_strategy": anchor_strategy_provenance,
		},
		"per_game": per_game,
	}

	if json_output != "":
		var file := FileAccess.open(json_output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_json_ascii_safe(report), "\t"))
			file.close()
			print("结果导出: %s" % json_output)
		else:
			print("[警告] 无法写入 %s" % json_output)

	if trace_jsonl_output != "" and trace_collector != null:
		_write_trace_jsonl(trace_jsonl_output, trace_collector.traces, trace_provenance)
		print("Trace JSONL exported: %s" % trace_jsonl_output)

	_quit(0)


func _make_ai(
	player_index: int,
	deck: DeckData,
	decision_mode_override: String = "",
	strong_fixed_opening: bool = false
) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	var registry := DeckStrategyRegistryScript.new()
	var strategy = registry.apply_strategy_for_deck(ai, deck)
	if strong_fixed_opening:
		ai.use_mcts = false
		ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	if strategy != null and strategy.has_method("get_strategy_id"):
		# 尝试加载 value net
		var strategy_id: String = str(strategy.call("get_strategy_id"))
		var vnet_path := "user://ai_agents/%s_value_net.json" % strategy_id
		if strategy.has_method("load_value_net"):
			if strategy.load_value_net(vnet_path):
				var vnet = strategy.get_value_net() if strategy.has_method("get_value_net") else null
				if vnet != null:
					ai._mcts_planner.value_net = vnet
				var encoder_class = strategy.get_state_encoder_class() if strategy.has_method("get_state_encoder_class") else null
				if encoder_class != null:
					ai._mcts_planner.state_encoder_class = encoder_class
	if decision_mode_override != "":
		ai.decision_runtime_mode = decision_mode_override
	return ai


func _apply_fixed_order_if_enabled(
	gsm: GameStateMachine,
	player_index: int,
	deck_id: int,
	enabled: bool,
	fixed_order_registry: RefCounted
) -> String:
	if not enabled or gsm == null or fixed_order_registry == null:
		return ""
	var fixed_order_path := str(fixed_order_registry.call("get_fixed_order_path", deck_id))
	if fixed_order_path == "":
		return ""
	var loaded_order: Variant = fixed_order_registry.call("load_fixed_order_from_path", fixed_order_path)
	if not loaded_order is Array:
		return ""
	var fixed_order: Array[Dictionary] = []
	for entry_variant: Variant in loaded_order:
		if entry_variant is Dictionary:
			fixed_order.append((entry_variant as Dictionary).duplicate(true))
	if fixed_order.is_empty():
		return ""
	gsm.set_deck_order_override(player_index, fixed_order)
	return fixed_order_path


func _parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {
		"deck_id": 0,
		"anchor_id": DEFAULT_ANCHOR_ID,
		"games": DEFAULT_GAMES,
		"seed_base": DEFAULT_SEED_BASE,
		"max_steps": DEFAULT_MAX_STEPS,
		"json_output": "",
		"decision_mode": "",
		"deck_decision_mode": "",
		"anchor_decision_mode": "",
		"deck_strong_fixed_opening": false,
		"anchor_strong_fixed_opening": false,
		"trace_game": 0,
		"trace_jsonl_output": "",
	}
	for arg: String in args:
		if arg.begins_with("--deck-id="):
			parsed["deck_id"] = int(arg.split("=")[1])
		elif arg.begins_with("--anchor-id="):
			parsed["anchor_id"] = int(arg.split("=")[1])
		elif arg.begins_with("--games="):
			parsed["games"] = max(1, int(arg.split("=")[1]))
		elif arg.begins_with("--seed-base="):
			parsed["seed_base"] = int(arg.split("=")[1])
		elif arg.begins_with("--max-steps="):
			parsed["max_steps"] = max(1, int(arg.split("=")[1]))
		elif arg.begins_with("--json-output="):
			parsed["json_output"] = arg.split("=")[1]
		elif arg.begins_with("--decision-mode="):
			parsed["decision_mode"] = arg.split("=")[1]
			parsed["deck_decision_mode"] = arg.split("=")[1]
		elif arg.begins_with("--deck-decision-mode="):
			parsed["deck_decision_mode"] = arg.split("=")[1]
		elif arg.begins_with("--anchor-decision-mode="):
			parsed["anchor_decision_mode"] = arg.split("=")[1]
		elif arg == "--strong-fixed-opening":
			parsed["deck_strong_fixed_opening"] = true
			parsed["anchor_strong_fixed_opening"] = true
		elif arg.begins_with("--strong-fixed-opening="):
			var enabled := _parse_bool(arg.split("=")[1])
			parsed["deck_strong_fixed_opening"] = enabled
			parsed["anchor_strong_fixed_opening"] = enabled
		elif arg == "--deck-strong-fixed-opening":
			parsed["deck_strong_fixed_opening"] = true
		elif arg.begins_with("--deck-strong-fixed-opening="):
			parsed["deck_strong_fixed_opening"] = _parse_bool(arg.split("=")[1])
		elif arg == "--anchor-strong-fixed-opening":
			parsed["anchor_strong_fixed_opening"] = true
		elif arg.begins_with("--anchor-strong-fixed-opening="):
			parsed["anchor_strong_fixed_opening"] = _parse_bool(arg.split("=")[1])
		elif arg.begins_with("--trace-game="):
			parsed["trace_game"] = max(1, int(arg.split("=")[1]))
		elif arg.begins_with("--trace-jsonl-output="):
			parsed["trace_jsonl_output"] = arg.split("=")[1]
	return parsed


func _parse_bool(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	return normalized in ["1", "true", "yes", "y", "on", "strong"]


func _json_ascii_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var safe_dict := {}
		for raw_key: Variant in (value as Dictionary).keys():
			safe_dict[str(raw_key)] = _json_ascii_safe((value as Dictionary).get(raw_key))
		return safe_dict
	if value is Array:
		var safe_array: Array = []
		for raw_item: Variant in value:
			safe_array.append(_json_ascii_safe(raw_item))
		return safe_array
	if value is String:
		return _ascii_safe_string(str(value))
	return value


func _build_source_provenance() -> Dictionary:
	var source_paths: Array[String] = []
	_collect_gd_source_paths(AI_SOURCE_ROOT, source_paths)
	if not BENCHMARK_RUNNER_SOURCE_PATH in source_paths:
		source_paths.append(BENCHMARK_RUNNER_SOURCE_PATH)
	source_paths.sort()

	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return {}
	var latest_mtime: int = 0
	var file_count: int = 0
	context.update(("%d|" % source_paths.size()).to_utf8_buffer())
	for source_path: String in source_paths:
		if not FileAccess.file_exists(source_path):
			continue
		var bytes := FileAccess.get_file_as_bytes(source_path)
		var path_bytes := source_path.to_utf8_buffer()
		context.update(("%d|" % path_bytes.size()).to_utf8_buffer())
		context.update(path_bytes)
		context.update(("%d|" % bytes.size()).to_utf8_buffer())
		context.update(bytes)
		latest_mtime = maxi(latest_mtime, int(FileAccess.get_modified_time(source_path)))
		file_count += 1
	return {
		"algorithm": "sha256",
		"fingerprint": context.finish().hex_encode(),
		"file_count": file_count,
		"latest_mtime_unix": latest_mtime,
		"source_root": AI_SOURCE_ROOT,
		"runner_path": BENCHMARK_RUNNER_SOURCE_PATH,
	}


func _collect_gd_source_paths(directory_path: String, output: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(directory_path):
		if file_name.ends_with(".gd"):
			output.append(directory_path.path_join(file_name))
	for subdirectory_name: String in DirAccess.get_directories_at(directory_path):
		_collect_gd_source_paths(directory_path.path_join(subdirectory_name), output)


func _build_strategy_provenance(deck: DeckData) -> Dictionary:
	if deck == null:
		return {}
	var registry := DeckStrategyRegistryScript.new()
	var strategy_id := str(registry.resolve_strategy_id_for_deck(deck))
	var strategy = registry.resolve_strategy_for_deck(deck)
	var script_path := ""
	if strategy != null:
		var script_resource: Variant = strategy.get_script()
		if script_resource is Script:
			script_path = str((script_resource as Script).resource_path)
	var provenance := {
		"deck_id": int(deck.id),
		"strategy_id": strategy_id,
		"script_path": script_path,
	}
	provenance["script"] = _build_file_provenance(script_path)
	var profile: Dictionary = DeckStrategyV18ProfileCatalogScript.get_profile_for_strategy(strategy_id)
	provenance["delegate"] = _build_file_provenance(str(profile.get("delegate_script_path", "")))
	return provenance


func _build_player_provenance(strategy_provenance: Dictionary, fixed_requested: bool, fixed_order_path: String) -> Dictionary:
	var provenance := strategy_provenance.duplicate(true)
	provenance["fixed_opening_requested"] = fixed_requested
	provenance["fixed_opening_applied"] = fixed_order_path != ""
	provenance["fixed_order"] = _build_file_provenance(fixed_order_path)
	return provenance


func _build_file_provenance(path: String) -> Dictionary:
	var normalized_path := path.replace("\\", "/")
	if normalized_path == "" or not FileAccess.file_exists(normalized_path):
		return {
			"path": normalized_path,
			"sha256": "",
			"mtime_unix": 0,
		}
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return {"path": normalized_path, "sha256": "", "mtime_unix": 0}
	context.update(FileAccess.get_file_as_bytes(normalized_path))
	return {
		"path": normalized_path,
		"sha256": context.finish().hex_encode(),
		"mtime_unix": int(FileAccess.get_modified_time(normalized_path)),
	}


func _attach_trace_provenance(payload: Dictionary, provenance: Dictionary) -> Dictionary:
	var decorated := payload.duplicate(true)
	decorated["provenance"] = provenance.duplicate(true)
	return decorated


func _write_trace_jsonl(path: String, traces: Array, provenance: Dictionary = {}) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("[warn] failed to write trace JSONL: %s" % path)
		return
	for trace in traces:
		if trace == null:
			continue
		var payload: Dictionary = trace.to_dictionary() if trace.has_method("to_dictionary") else {}
		payload = _attach_trace_provenance(payload, provenance)
		file.store_line(JSON.stringify(_json_ascii_safe(payload)))
	file.close()


func _ascii_safe_string(text: String) -> String:
	var parts := PackedStringArray()
	for i: int in text.length():
		var code := text.unicode_at(i)
		if code >= 32 and code <= 126:
			parts.append(text.substr(i, 1))
		elif code in [9, 10, 13]:
			parts.append(" ")
		else:
			parts.append("?")
	return "".join(parts)


func _quit(code: int) -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(code)
