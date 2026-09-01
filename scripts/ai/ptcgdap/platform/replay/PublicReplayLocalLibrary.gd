class_name PtcgDAPPublicReplayLocalLibrary
extends RefCounted

const StoreScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayStore.gd"
)

const DEFAULT_STORAGE_NAMESPACE := "live-community"

var _store: Variant = null


static func create(
	contract_owner: Variant,
	storage_namespace: String = DEFAULT_STORAGE_NAMESPACE
) -> Dictionary:
	var store_created: Dictionary = StoreScript.create(
		contract_owner, storage_namespace, "community_challenge"
	)
	if not bool(store_created.get("accepted", false)):
		return store_created
	var library := new()
	library._store = store_created.get("store")
	return {
		"accepted": true,
		"error_code": "",
		"library": library,
		"authoritative": false,
		"grants": [],
	}


func list_replays() -> Dictionary:
	if _store == null:
		return _failure("local_replay_library_unavailable")
	var scanned: Dictionary = _store.list_available_index()
	if not bool(scanned.get("accepted", false)):
		return scanned
	var entries: Array = []
	var rejected_count := int(scanned.get("rejected_count", 0))
	for index_entry: Variant in scanned.get("entries", []):
		if not index_entry is Dictionary:
			rejected_count += 1
			continue
		entries.append(_summary(index_entry))
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_started := str(left.get("started_at_utc", ""))
		var right_started := str(right.get("started_at_utc", ""))
		if left_started != right_started:
			return left_started > right_started
		return str(left.get("replay_id", "")) > str(right.get("replay_id", ""))
	)
	return {
		"accepted": true,
		"error_code": "",
		"entries": entries,
		"rejected_count": rejected_count,
		"authoritative": false,
		"grants": [],
	}


func load_replay(replay_id: String) -> Dictionary:
	if _store == null:
		return _failure("local_replay_library_unavailable")
	return _store.load_replay(replay_id)


func audit_snapshot() -> Dictionary:
	return {
		"document_type": "public_replay_local_library_audit_v1",
		"schema_version": 1,
		"source": "local",
		"private_replay_used": false,
		"engine_invocations": 0,
		"ticket_invocations": 0,
		"callback_invocations": 0,
		"authoritative": false,
		"grants": [],
	}


static func _summary(index_entry: Dictionary) -> Dictionary:
	var match_id := str(index_entry.get("match_id", ""))
	return {
		"source": "local",
		"replay_id": str(index_entry.get("replay_id", "")),
		"match_id": match_id,
		"frame_count": int(index_entry.get("frame_count", 0)),
		"started_at_utc": _timestamp_from_match_id(match_id),
		"strategy_id": "",
		"authoritative": false,
		"grants": [],
	}


static func _timestamp_from_match_id(match_id: String) -> String:
	for token: String in match_id.split("-", false):
		if not token.is_valid_int():
			continue
		var candidate := token.to_int()
		if candidate >= 946684800 and candidate <= 4102444800:
			return "%sZ" % Time.get_datetime_string_from_unix_time(candidate)
	return ""


static func _failure(code: String) -> Dictionary:
	return {
		"accepted": false,
		"error_code": code,
		"authoritative": false,
		"grants": [],
	}
