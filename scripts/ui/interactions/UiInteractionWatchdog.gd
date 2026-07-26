class_name UiInteractionWatchdog
extends Node

signal recovery_requested(session: UiInteractionSession)

const POLL_INTERVAL_SECONDS := 0.25

var _registry: UiInteractionSessionRegistry = null
var _recovery_callback: Callable = Callable()
var _elapsed_seconds: float = 0.0


func setup(registry: UiInteractionSessionRegistry, recovery_callback: Callable = Callable()) -> void:
	_registry = registry
	_recovery_callback = recovery_callback
	set_process(registry != null)


func release() -> void:
	set_process(false)
	_registry = null
	_recovery_callback = Callable()


func tick(now_msec: int = -1) -> UiInteractionSession:
	if _registry == null:
		return null
	var timed_out := _registry.timeout_if_stalled(now_msec, "interaction_watchdog_timeout")
	if timed_out == null:
		return null
	recovery_requested.emit(timed_out)
	if _recovery_callback.is_valid():
		_recovery_callback.call(timed_out)
	return timed_out


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	if _elapsed_seconds < POLL_INTERVAL_SECONDS:
		return
	_elapsed_seconds = 0.0
	tick()

