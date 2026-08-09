class_name TestAIWatchdog
extends TestBase

const BattleAIWatchdogScript = preload("res://scripts/ui/battle/ai/BattleAIWatchdog.gd")


class WatchdogStrategy extends RefCounted:
	var forced_turns: Array[int] = []

	func force_rules_for_turn(turn_number: int, _reason: String = "") -> void:
		forced_turns.append(turn_number)


class WatchdogAI extends RefCounted:
	var player_index: int = 1
	var _deck_strategy: RefCounted = WatchdogStrategy.new()

	func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
		return game_state != null and not ui_blocked and game_state.current_player_index == player_index


class WatchdogGSM extends GameStateMachine:
	var authoritative_pending_decision: Dictionary = {}

	func get_pending_decision_snapshot() -> Dictionary:
		return authoritative_pending_decision.duplicate(true)


class WatchdogScene extends Control:
	var _gsm: GameStateMachine = null
	var _ai_opponent: RefCounted = WatchdogAI.new()
	var _battle_mode: String = "live"
	var _pending_choice: String = ""
	var _dialog_data: Dictionary = {}
	var _pending_effect_player_index: int = -1
	var _pending_effect_step_index: int = -1
	var _pending_effect_steps: Array[Dictionary] = []
	var _pending_prize_player_index: int = -1
	var _pending_prize_remaining: int = 0
	var _pending_prize_animating: bool = false
	var _battle_visual_input_blocked: bool = false
	var _draw_reveal_active: bool = false
	var _draw_reveal_queue: Array[GameAction] = []
	var _coin_animating: bool = false
	var _coin_flip_queue: Array[bool] = []
	var _coin_animation_resume_effect_step: bool = false
	var _ai_action_pause_timer: Variant = null
	var _ai_running: bool = false
	var _ai_step_scheduled: bool = false
	var _ai_followup_requested: bool = false
	var _ai_llm_waiting: bool = false
	var maybe_calls: int = 0
	var pause_finish_calls: int = 0
	var coin_finish_calls: int = 0
	var draw_finish_calls: int = 0
	var prize_finish_calls: int = 0
	var visual_finish_calls: int = 0
	var authoritative_reconcile_calls: int = 0
	var reset_effect_calls: int = 0
	var refresh_calls: int = 0
	var end_turn_calls: int = 0
	var stale_prompt_dismiss_calls: int = 0
	var logs: Array[String] = []

	func _init() -> void:
		_gsm = WatchdogGSM.new()
		_gsm.game_state = GameState.new()
		_gsm.game_state.current_player_index = 1
		_gsm.game_state.phase = GameState.GamePhase.MAIN
		_gsm.game_state.turn_number = 4
		for player_index: int in 2:
			var player := PlayerState.new()
			player.player_index = player_index
			_gsm.game_state.players.append(player)

	func _ensure_ai_opponent() -> void:
		pass

	func _is_review_mode() -> bool:
		return false

	func _is_ai_action_pause_active() -> bool:
		return _ai_action_pause_timer != null

	func _get_effect_interaction_prompt_player_index() -> int:
		if _pending_choice != "effect_interaction":
			return -1
		if _pending_effect_step_index < 0 or _pending_effect_step_index >= _pending_effect_steps.size():
			return -1
		return _pending_effect_player_index

	func _maybe_run_ai() -> void:
		maybe_calls += 1

	func _on_ai_action_pause_finished() -> void:
		pause_finish_calls += 1
		_ai_action_pause_timer = null
		_maybe_run_ai()

	func _on_coin_animation_finished() -> void:
		coin_finish_calls += 1
		_coin_animating = false
		_coin_flip_queue.clear()
		_maybe_run_ai()

	func _ai_watchdog_force_finish_draw_reveal() -> void:
		draw_finish_calls += 1
		_draw_reveal_active = false
		_draw_reveal_queue.clear()
		_maybe_run_ai()

	func _ai_watchdog_force_finish_prize_animation() -> void:
		prize_finish_calls += 1
		_pending_prize_animating = false
		_maybe_run_ai()

	func _ai_watchdog_force_finish_visual_sequence() -> void:
		visual_finish_calls += 1
		_battle_visual_input_blocked = false
		_maybe_run_ai()

	func _ai_watchdog_reconcile_authoritative_decision() -> bool:
		authoritative_reconcile_calls += 1
		var decision := (_gsm as WatchdogGSM).authoritative_pending_decision
		if decision.is_empty():
			return false
		_pending_choice = str(decision.get("scene_choice", "effect_interaction"))
		_pending_effect_player_index = int(decision.get("owner_player_index", -1))
		_pending_effect_step_index = 0
		_pending_effect_steps = [{"id": "reconciled", "items": ["fallback"]}]
		_maybe_run_ai()
		return true

	func _reset_effect_interaction() -> void:
		reset_effect_calls += 1
		_pending_choice = ""
		_pending_effect_player_index = -1
		_pending_effect_step_index = -1
		_pending_effect_steps.clear()

	func _refresh_ui() -> void:
		refresh_calls += 1

	func _on_end_turn(_player_index: int = -1) -> void:
		end_turn_calls += 1

	func _ai_watchdog_dismiss_stale_human_turn_prompt() -> bool:
		stale_prompt_dismiss_calls += 1
		if not _pending_choice in ["pokemon_action", "zeus_help"]:
			return false
		_pending_choice = ""
		_maybe_run_ai()
		return true

	func _runtime_log(event: String, detail: String = "") -> void:
		logs.append("%s:%s" % [event, detail])


func _with_vs_ai(callback: Callable) -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var result: String = str(callback.call())
	GameManager.current_mode = previous_mode
	return result


func test_watchdog_recovers_lost_ai_schedule_after_soft_timeout() -> String:
	return _with_vs_ai(func() -> String:
		var scene := WatchdogScene.new()
		var watchdog := BattleAIWatchdogScript.new()
		watchdog.setup(scene)
		watchdog.notify_activity("turn_start", 1000)
		scene._ai_step_scheduled = true
		var result: Dictionary = watchdog.tick(4500)
		var checks := run_checks([
			assert_eq(str(result.get("action", "")), "reschedule", "A stale scheduled flag should use the soft recovery path"),
			assert_false(scene._ai_step_scheduled, "Soft recovery should clear the stale scheduled flag before retrying"),
			assert_eq(scene.maybe_calls, 1, "Soft recovery should re-check AI scheduling"),
		])
		scene.free()
		return checks
	)


func test_watchdog_force_finishes_expired_ai_pause() -> String:
	return _with_vs_ai(func() -> String:
		var scene := WatchdogScene.new()
		# AI end-turn advances ownership before the presentation pause completes.
		scene._gsm.game_state.current_player_index = 0
		scene._ai_action_pause_timer = true
		var watchdog := BattleAIWatchdogScript.new()
		watchdog.setup(scene)
		watchdog.notify_activity("action_pause", 1000)
		var result: Dictionary = watchdog.tick(7500)
		var checks := run_checks([
			assert_eq(str(result.get("action", "")), "finish_action_pause", "An expired action pause should be completed"),
			assert_eq(scene.pause_finish_calls, 1, "Watchdog should route pause recovery through the normal finish callback"),
			assert_null(scene._ai_action_pause_timer, "Pause recovery should remove the AI blocker"),
		])
		scene.free()
		return checks
	)


func test_watchdog_force_finishes_stuck_coin_and_draw_animations() -> String:
	return _with_vs_ai(func() -> String:
		var coin_scene := WatchdogScene.new()
		coin_scene._coin_animating = true
		var coin_watchdog := BattleAIWatchdogScript.new()
		coin_watchdog.setup(coin_scene)
		coin_watchdog.notify_activity("coin", 1000)
		var coin_result: Dictionary = coin_watchdog.tick(7500)

		var draw_scene := WatchdogScene.new()
		draw_scene._draw_reveal_active = true
		var draw_watchdog := BattleAIWatchdogScript.new()
		draw_watchdog.setup(draw_scene)
		draw_watchdog.notify_activity("draw", 1000)
		var draw_result: Dictionary = draw_watchdog.tick(7500)
		var checks := run_checks([
			assert_eq(str(coin_result.get("action", "")), "finish_coin_animation", "A stuck coin animation should use its normal finish path"),
			assert_eq(coin_scene.coin_finish_calls, 1, "Coin recovery should invoke the animation completion callback"),
			assert_eq(str(draw_result.get("action", "")), "finish_draw_reveal", "A stuck draw reveal should use its force-finish bridge"),
			assert_eq(draw_scene.draw_finish_calls, 1, "Draw recovery should clear the reveal through the scene bridge"),
		])
		coin_scene.free()
		draw_scene.free()
		return checks
	)


func test_watchdog_force_finishes_stuck_ai_prize_animation() -> String:
	return _with_vs_ai(func() -> String:
		var scene := WatchdogScene.new()
		scene._pending_choice = "take_prize"
		scene._pending_prize_player_index = 1
		scene._pending_prize_remaining = 1
		scene._pending_prize_animating = true
		var watchdog := BattleAIWatchdogScript.new()
		watchdog.setup(scene)
		watchdog.notify_activity("prize_animation", 1000)
		var result: Dictionary = watchdog.tick(7500)
		var checks := run_checks([
			assert_eq(str(result.get("action", "")), "finish_prize_animation", "A lost prize Tween callback must not block the AI-owned prize prompt forever"),
			assert_eq(scene.prize_finish_calls, 1, "Prize recovery should invoke the scene's idempotent completion bridge"),
			assert_false(scene._pending_prize_animating, "Prize recovery must release the animation latch"),
		])
		scene.free()
		return checks
	)


func test_watchdog_force_finishes_stuck_visual_sequence() -> String:
	return _with_vs_ai(func() -> String:
		var scene := WatchdogScene.new()
		scene._battle_visual_input_blocked = true
		var watchdog := BattleAIWatchdogScript.new()
		watchdog.setup(scene)
		watchdog.notify_activity("visual_sequence", 1000)
		var result: Dictionary = watchdog.tick(7500)
		var checks := run_checks([
			assert_eq(str(result.get("action", "")), "finish_visual_sequence", "A lost visual callback must not block the AI turn forever"),
			assert_eq(scene.visual_finish_calls, 1, "Visual recovery should clear the presentation queue through the scene bridge"),
			assert_false(scene._battle_visual_input_blocked, "Visual recovery must release the AI gate"),
		])
		scene.free()
		return checks
	)


func test_watchdog_dismisses_stale_human_action_hud_during_ai_turn() -> String:
	return _with_vs_ai(func() -> String:
		var scene := WatchdogScene.new()
		scene._pending_choice = "pokemon_action"
		var watchdog := BattleAIWatchdogScript.new()
		watchdog.setup(scene)
		watchdog.notify_activity("stale_human_action_hud", 1000)
		var result: Dictionary = watchdog.tick(7500)
		var checks := run_checks([
			assert_eq(str(result.get("action", "")), "dismiss_stale_human_action_prompt", "A human-only action HUD must stay monitored while the AI owns the turn"),
			assert_eq(scene.stale_prompt_dismiss_calls, 1, "The watchdog should dismiss the stale human prompt exactly once"),
			assert_eq(scene._pending_choice, "", "Stale human prompt recovery must clear the AI blocker"),
			assert_eq(scene.maybe_calls, 1, "Stale human prompt recovery should resume normal AI scheduling"),
		])
		scene.free()
		return checks
	)


func test_watchdog_dismisses_stale_human_helper_prompt_during_ai_turn() -> String:
	return _with_vs_ai(func() -> String:
		var scene := WatchdogScene.new()
		scene._pending_choice = "zeus_help"
		var watchdog := BattleAIWatchdogScript.new()
		watchdog.setup(scene)
		watchdog.notify_activity("stale_human_helper", 1000)
		var result: Dictionary = watchdog.tick(7500)
		var checks := run_checks([
			assert_eq(str(result.get("action", "")), "dismiss_stale_human_action_prompt", "Every human-only mutation prompt must stay monitored while the AI owns the turn"),
			assert_eq(scene.stale_prompt_dismiss_calls, 1, "The watchdog should dismiss the stale helper prompt exactly once"),
			assert_eq(scene._pending_choice, "", "Stale helper recovery must clear the AI blocker"),
			assert_eq(scene.maybe_calls, 1, "Stale helper recovery should resume normal AI scheduling"),
		])
		scene.free()
		return checks
	)


func test_watchdog_hard_fallback_aborts_ai_effect_and_ends_main_phase_turn() -> String:
	return _with_vs_ai(func() -> String:
		var scene := WatchdogScene.new()
		scene._pending_choice = "effect_interaction"
		scene._pending_effect_player_index = 1
		scene._pending_effect_step_index = 0
		scene._pending_effect_steps = [{"id": "broken_step", "items": []}]
		var watchdog := BattleAIWatchdogScript.new()
		watchdog.setup(scene)
		watchdog.notify_activity("effect", 1000)
		var result: Dictionary = watchdog.tick(13500)
		var checks := run_checks([
			assert_eq(str(result.get("action", "")), "abort_effect_and_end_turn", "A permanently stuck AI effect needs a hard escape"),
			assert_eq(scene.reset_effect_calls, 1, "Hard fallback should clear the stale interaction"),
			assert_eq(scene.refresh_calls, 1, "Hard fallback should refresh the cleared interaction state"),
			assert_eq(scene.end_turn_calls, 1, "Hard fallback should safely yield the AI main-phase turn"),
		])
		scene.free()
		return checks
	)


func test_watchdog_recovers_malformed_ai_effect_prompt_instead_of_becoming_inactive() -> String:
	return _with_vs_ai(func() -> String:
		var scene := WatchdogScene.new()
		scene._pending_choice = "effect_interaction"
		scene._pending_effect_player_index = 1
		scene._pending_effect_step_index = -1
		scene._pending_effect_steps = []
		var watchdog := BattleAIWatchdogScript.new()
		watchdog.setup(scene)
		watchdog.notify_activity("malformed_effect", 1000)
		var result: Dictionary = watchdog.tick(13500)
		var checks := run_checks([
			assert_true(str(result.get("action", "")) in ["abort_effect", "abort_effect_and_end_turn"], "Malformed AI-owned effect state must remain monitored and take a hard recovery path"),
			assert_eq(scene.reset_effect_calls, 1, "Malformed AI-owned effect state should be cleared exactly once"),
		])
		scene.free()
		return checks
	)


func test_watchdog_reconciles_engine_owned_ai_decision_when_scene_prompt_is_missing() -> String:
	return _with_vs_ai(func() -> String:
		var scene := WatchdogScene.new()
		scene._gsm.game_state.current_player_index = 0
		(scene._gsm as WatchdogGSM).authoritative_pending_decision = {
			"kind": "powerglass_end_turn",
			"owner_player_index": 1,
			"scene_choice": "effect_interaction",
		}
		var watchdog := BattleAIWatchdogScript.new()
		watchdog.setup(scene)
		watchdog.notify_activity("engine_pending", 1000)
		var result: Dictionary = watchdog.tick(13500)
		var checks := run_checks([
			assert_eq(str(result.get("action", "")), "reconcile_authoritative_decision", "An engine-owned AI decision must be rebuilt even when BattleScene lost its prompt"),
			assert_eq(scene.authoritative_reconcile_calls, 1, "Authoritative recovery should reconcile the scene exactly once"),
			assert_eq(scene._pending_choice, "effect_interaction", "Reconciliation should restore an actionable scene prompt"),
		])
		scene.free()
		return checks
	)


func test_game_state_machine_exposes_authoritative_prize_decision_snapshot() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	gsm.set("_pending_prize_player_index", 1)
	gsm.set("_pending_prize_remaining", 2)
	var snapshot: Dictionary = gsm.get_pending_decision_snapshot()
	return run_checks([
		assert_eq(str(snapshot.get("kind", "")), "take_prize", "The rule engine should identify its pending prize phase"),
		assert_eq(int(snapshot.get("owner_player_index", -1)), 1, "The authoritative snapshot should preserve the decision owner"),
		assert_eq(int(snapshot.get("count", 0)), 2, "The authoritative snapshot should preserve remaining prize count"),
	])


func test_watchdog_releases_stale_running_flag_while_ai_owns_send_out_prompt() -> String:
	return _with_vs_ai(func() -> String:
		var scene := WatchdogScene.new()
		scene._pending_choice = "send_out"
		scene._dialog_data = {"player": 1}
		scene._ai_running = true
		var watchdog := BattleAIWatchdogScript.new()
		watchdog.setup(scene)
		watchdog.notify_activity("opponent_play_card", 1000)
		var result: Dictionary = watchdog.tick(13500)
		var checks := run_checks([
			assert_eq(str(result.get("action", "")), "release_stale_running_step", "A crashed AI card-play step must not leave the opponent turn permanently marked as running"),
			assert_false(scene._ai_running, "Hard recovery should release the stale AI running flag"),
			assert_false(scene._ai_step_scheduled, "Hard recovery should clear any stale deferred step"),
			assert_eq(scene.maybe_calls, 1, "The recovered AI-owned prompt should be scheduled again"),
		])
		scene.free()
		return checks
	)


func test_watchdog_releases_stale_running_flag_outside_main_phase_without_forcing_turn_end() -> String:
	return _with_vs_ai(func() -> String:
		var scene := WatchdogScene.new()
		scene._gsm.game_state.phase = GameState.GamePhase.BETWEEN_TURNS
		scene._ai_running = true
		var watchdog := BattleAIWatchdogScript.new()
		watchdog.setup(scene)
		watchdog.notify_activity("between_turns", 1000)
		var result: Dictionary = watchdog.tick(13500)
		var checks := run_checks([
			assert_eq(str(result.get("action", "")), "release_stale_running_step", "A crashed non-main AI continuation must release the running latch instead of waiting forever"),
			assert_false(scene._ai_running, "Non-main hard recovery should release the stale AI running flag"),
			assert_eq(scene.maybe_calls, 1, "Non-main hard recovery should retry the normal AI scheduler"),
			assert_eq(scene.end_turn_calls, 0, "Recovery outside MAIN must not manufacture an extra end-turn action"),
		])
		scene.free()
		return checks
	)


func test_watchdog_hard_timeout_forces_llm_turn_back_to_rules() -> String:
	return _with_vs_ai(func() -> String:
		var scene := WatchdogScene.new()
		scene._ai_llm_waiting = true
		var watchdog := BattleAIWatchdogScript.new()
		watchdog.setup(scene)
		watchdog.notify_activity("llm", 1000)
		var result: Dictionary = watchdog.tick(13500)
		var strategy := scene._ai_opponent.get("_deck_strategy") as WatchdogStrategy
		var checks := run_checks([
			assert_eq(str(result.get("action", "")), "fallback_llm_rules", "A stalled LLM request should fall back to deterministic rules"),
			assert_false(scene._ai_llm_waiting, "LLM hard recovery should release the wait blocker"),
			assert_eq(strategy.forced_turns, [4], "Only the stalled turn should be forced to rules"),
			assert_eq(scene.maybe_calls, 1, "Rules fallback should immediately resume AI scheduling"),
		])
		scene.free()
		return checks
	)


func test_watchdog_never_resolves_human_owned_prompt() -> String:
	return _with_vs_ai(func() -> String:
		var scene := WatchdogScene.new()
		scene._pending_choice = "effect_interaction"
		scene._pending_effect_player_index = 0
		scene._pending_effect_step_index = 0
		scene._pending_effect_steps = [{"id": "human_step", "items": ["choice"]}]
		var watchdog := BattleAIWatchdogScript.new()
		watchdog.setup(scene)
		watchdog.notify_activity("human_prompt", 1000)
		var result: Dictionary = watchdog.tick(30000)
		var checks := run_checks([
			assert_eq(str(result.get("action", "")), "inactive", "Human-owned prompts must stay outside watchdog recovery"),
			assert_eq(scene.maybe_calls, 0, "Watchdog must not retry AI while a human owns the choice"),
			assert_eq(scene.reset_effect_calls, 0, "Watchdog must not clear a human interaction"),
			assert_eq(scene.end_turn_calls, 0, "Watchdog must not end a turn to bypass a human choice"),
		])
		scene.free()
		return checks
	)


func test_watchdog_stays_disabled_in_two_player_mode() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var scene := WatchdogScene.new()
	var watchdog := BattleAIWatchdogScript.new()
	watchdog.setup(scene)
	watchdog.notify_activity("two_player", 1000)
	var result: Dictionary = watchdog.tick(30000)
	var checks := run_checks([
		assert_eq(str(result.get("action", "")), "inactive", "Two-player battles must stay outside AI watchdog recovery"),
		assert_eq(scene.maybe_calls, 0, "Watchdog must not schedule AI actions in two-player mode"),
		assert_eq(scene.end_turn_calls, 0, "Watchdog must never end a human-controlled turn"),
	])
	GameManager.current_mode = previous_mode
	scene.free()
	return checks
