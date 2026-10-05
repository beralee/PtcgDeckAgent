extends RefCounted

## Bench event durations are visual estimates, never completion authority.
const DATA_PATH := "res://data/performance/scene_loading_baselines.json"
static var _profiles: Dictionary = {}
static var _loaded := false

static func expected_ms(event_id: String, repeated: bool, os_name: String = OS.get_name(), editor_binary: bool = OS.has_feature("editor")) -> float:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(DATA_PATH):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
			if data is Dictionary and data.get("schema_version") == 1 and data.get("profiles") is Dictionary:
				_profiles = data.profiles
	var profile := ""
	if os_name == "Windows":
		profile = "windows_editor" if editor_binary else "windows_release"
	elif os_name == "Android":
		profile = "android_emulator_reference"
	var events: Dictionary = _profiles.get(profile, {})
	var event: Dictionary = events.get(event_id, {})
	var sample: Dictionary = event.get("warm_in_process" if repeated else "first_in_process", {})
	var duration := float(sample.get("expected_ms", 0.0))
	return duration if is_finite(duration) and duration > 0.0 else 0.0

static func estimated_fraction(elapsed_ms: float, duration_ms: float) -> float:
	if duration_ms <= 0.0:
		return 0.0
	var ratio := maxf(0.0, elapsed_ms / duration_ms)
	# Reach 90% at the measured median, then ease toward 95% if slower.
	# Only actual readiness can fill the remaining part of the bar.
	return 0.9 * minf(ratio, 1.0) + 0.05 * (1.0 - exp(-maxf(ratio - 1.0, 0.0)))
