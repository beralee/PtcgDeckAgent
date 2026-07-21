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
	var reset_effect_calls: int = 0
	var refresh_calls: int = 0
	var end_turn_calls: int = 0
	var logs: Array[String] = []

	func _init() -> void:
		_gsm = GameStateMachine.new()
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
		return _pending_effect_player_index if _pending_choice == "effect_interaction" else -1

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
