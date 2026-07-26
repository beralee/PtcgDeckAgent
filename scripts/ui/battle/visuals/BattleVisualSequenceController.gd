class_name BattleVisualSequenceController
extends RefCounted

const SnapshotScript := preload("res://scripts/ui/battle/visuals/BattleVisualSnapshot.gd")
const EventBuilderScript := preload("res://scripts/ui/battle/visuals/BattleVisualEventBuilder.gd")
const ZoneAnimatorScript := preload("res://scripts/ui/battle/visuals/BattleZoneTransferAnimator.gd")
const FeedbackAnimatorScript := preload("res://scripts/ui/battle/visuals/BattleStateFeedbackAnimator.gd")

const SOFT_QUEUE_LIMIT := 48

var _scene: Object = null
var _zone_animator: RefCounted = ZoneAnimatorScript.new()
var _feedback_animator: RefCounted = FeedbackAnimatorScript.new()
var _queue: Array[Dictionary] = []
var _active_event: Dictionary = {}
var _baseline_snapshot: Dictionary = {}
var _view_player: int = -1
var _generation: int = 0
var _submitted_events: int = 0
var _last_state_transition_signature: String = ""


func setup(scene: Object) -> void:
	if _scene is Control:
		var previous := _scene as Control
		var previous_callback := Callable(self, "_on_scene_resized")
		if previous.resized.is_connected(previous_callback):
			previous.resized.disconnect(previous_callback)
	_scene = scene
	if _scene is Control:
		var scene_control := _scene as Control
		var callback := Callable(self, "_on_scene_resized")
		if not scene_control.resized.is_connected(callback):
			scene_control.resized.connect(callback)


func set_animators_for_tests(zone_animator: RefCounted, feedback_animator: RefCounted) -> void:
	_zone_animator = zone_animator
	_feedback_animator = feedback_animator


func prime_snapshot(game_state: GameState, view_player: int) -> void:
	clear("prime_snapshot")
	if not bool(GameManager.battle_effects_enabled):
		_baseline_snapshot = {}
		_view_player = view_player
		_last_state_transition_signature = ""
		return
	_baseline_snapshot = SnapshotScript.capture(game_state)
	_view_player = view_player
	_last_state_transition_signature = ""


func capture_action(
	action: GameAction,
	game_state: GameState,
	view_player: int,
	suppressed_semantics: Array = []
) -> Array[Dictionary]:
	if game_state == null or not bool(GameManager.battle_effects_enabled):
		return []
	if _baseline_snapshot.is_empty() or _view_player != view_player:
		prime_snapshot(game_state, view_player)
		return []
	var before := _baseline_snapshot
	var captured_after: Dictionary = SnapshotScript.capture(game_state)
	var after: Dictionary = SnapshotScript.retain_temporarily_missing_cards(before, captured_after)
	var transition := _transition_signature(before, after)
	var events: Array[Dictionary] = EventBuilderScript.build(before, captured_after, action, view_player)
	events = _filter_suppressed_events(events, suppressed_semantics)
	_baseline_snapshot = after
	_view_player = view_player
	_last_state_transition_signature = transition
	enqueue_events(events)
	return events


func sync_after_refresh(game_state: GameState, view_player: int) -> Array[Dictionary]:
	if game_state == null or not bool(GameManager.battle_effects_enabled):
		return []
	if _baseline_snapshot.is_empty() or _view_player != view_player:
		prime_snapshot(game_state, view_player)
		return []
	var captured_after: Dictionary = SnapshotScript.capture(game_state)
	var after: Dictionary = SnapshotScript.retain_temporarily_missing_cards(_baseline_snapshot, captured_after)
	var transition := _transition_signature(_baseline_snapshot, after)
	if transition == _last_state_transition_signature or SnapshotScript.signature(_baseline_snapshot) == SnapshotScript.signature(after):
		_baseline_snapshot = after
		return []
	var events: Array[Dictionary] = EventBuilderScript.build(_baseline_snapshot, captured_after, null, view_player)
	_baseline_snapshot = after
	_last_state_transition_signature = transition
	enqueue_events(events)
	return events


func enqueue_events(events: Array) -> void:
	if not bool(GameManager.battle_effects_enabled):
		clear("effects_disabled")
		return
	for event_variant: Variant in events:
		if not event_variant is Dictionary:
			continue
		var event: Dictionary = (event_variant as Dictionary).duplicate(true)
		if event.is_empty():
			continue
		_queue.append(event)
		_submitted_events += 1
	_compact_queue_if_needed()
	if _active_event.is_empty() and not _queue.is_empty():
		_set_input_blocked(true)
		_start_next()


func clear(_reason: String = "") -> void:
	_generation += 1
	_queue.clear()
	_active_event.clear()
	if _zone_animator != null and _zone_animator.has_method("cancel_all"):
		_zone_animator.call("cancel_all")
	if _feedback_animator != null and _feedback_animator != _zone_animator and _feedback_animator.has_method("cancel_all"):
		_feedback_animator.call("cancel_all")
	_set_input_blocked(false)


func _on_scene_resized() -> void:
	if _active_event.is_empty() and _queue.is_empty():
		return
	clear("scene_resized")


func pending_count() -> int:
	return _queue.size() + (0 if _active_event.is_empty() else 1)


func is_active() -> bool:
	return not _active_event.is_empty()


func submitted_event_count() -> int:
	return _submitted_events


func _start_next() -> void:
	if not _active_event.is_empty():
		return
	if _queue.is_empty():
		_set_input_blocked(false)
		return
	_active_event = _queue.pop_front()
	var animator := _animator_for_event(_active_event)
	if animator == null:
		_active_event.clear()
		_start_next()
		return
	var expected_generation := _generation
	animator.call("play_event", _scene, _active_event, Callable(self, "_on_event_finished").bind(expected_generation))


func _on_event_finished(expected_generation: int) -> void:
	if expected_generation != _generation or _active_event.is_empty():
		return
	var completed_semantic := str(_active_event.get("semantic", ""))
	_active_event.clear()
	if (
		completed_semantic == "knockout"
		and _scene != null
		and is_instance_valid(_scene)
		and _scene.has_method("_refresh_field_after_visual_event")
	):
		_scene.call("_refresh_field_after_visual_event", completed_semantic)
	_start_next()


func _animator_for_event(event: Dictionary) -> RefCounted:
	if _zone_animator != null and _zone_animator.has_method("handles") and bool(_zone_animator.call("handles", event)):
		return _zone_animator
	if _feedback_animator != null and _feedback_animator.has_method("handles") and bool(_feedback_animator.call("handles", event)):
		return _feedback_animator
	return null


func _compact_queue_if_needed() -> void:
	if _queue.size() <= SOFT_QUEUE_LIMIT:
		return
	var compacted: Array[Dictionary] = []
	for event: Dictionary in _queue:
		if not compacted.is_empty() and _can_merge(compacted.back(), event):
			compacted[compacted.size() - 1] = _merge_compatible_events(compacted.back(), event)
			continue
		compacted.append(event)
	_queue = compacted
	while _queue.size() > SOFT_QUEUE_LIMIT:
		_queue.remove_at(0)


func _can_merge(left: Dictionary, right: Dictionary) -> bool:
	return (
		str(left.get("kind", "")) == str(right.get("kind", ""))
		and str(left.get("semantic", "")) == str(right.get("semantic", ""))
		and str(left.get("source_zone", "")) == str(right.get("source_zone", ""))
		and str(left.get("target_zone", "")) == str(right.get("target_zone", ""))
		and str(left.get("slot_key", "")) == str(right.get("slot_key", ""))
		and str(left.get("visibility", "")) == str(right.get("visibility", ""))
		and int(left.get("player_index", -1)) == int(right.get("player_index", -1))
		and int(left.get("owner_index", -1)) == int(right.get("owner_index", -1))
		and int(left.get("view_player", -1)) == int(right.get("view_player", -1))
	)


func _merge_compatible_events(left: Dictionary, right: Dictionary) -> Dictionary:
	if not _can_merge(left, right):
		return left.duplicate(true)
	var merged := left.duplicate(true)
	merged["amount"] = int(left.get("amount", 0)) + int(right.get("amount", 0))
	merged["count"] = int(left.get("count", 0)) + int(right.get("count", 0))
	for array_key: String in ["card_instance_ids", "cards", "card_names"]:
		var values: Array = (left.get(array_key, []) as Array).duplicate()
		values.append_array(right.get(array_key, []))
		merged[array_key] = values
	return merged


func _transition_signature(before: Dictionary, after: Dictionary) -> String:
	return "%s>%s" % [SnapshotScript.signature(before), SnapshotScript.signature(after)]


func _filter_suppressed_events(events: Array[Dictionary], suppressed_semantics: Array) -> Array[Dictionary]:
	if suppressed_semantics.is_empty():
		return events
	if suppressed_semantics.has("*"):
		return []
	var filtered: Array[Dictionary] = []
	for event: Dictionary in events:
		if suppressed_semantics.has(str(event.get("semantic", ""))):
			continue
		filtered.append(event)
	return filtered


func _set_input_blocked(blocked: bool) -> void:
	if _scene != null and _scene.has_method("_set_battle_visual_input_blocked"):
		_scene.call("_set_battle_visual_input_blocked", blocked)
