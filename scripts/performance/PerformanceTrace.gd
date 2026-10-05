extends RefCounted

## Opt-in, bounded, local timings. No observations, paths, cards or payloads.
static var _enabled := "--ptcgdap-performance-trace" in OS.get_cmdline_user_args()
static var _samples: Array = []
static var _mutex := Mutex.new()
const MAX_SAMPLES := 8192

static func begin() -> int:
	return Time.get_ticks_usec() if _enabled else 0

static func end(stage: String, started: int) -> void:
	if started <= 0: return
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	_mutex.lock()
	if _samples.size() < MAX_SAMPLES:
		_samples.append({"stage": stage, "duration_ms": elapsed})
	_mutex.unlock()

static func snapshot() -> Array:
	_mutex.lock()
	var result := _samples.duplicate(true)
	_mutex.unlock()
	return result
