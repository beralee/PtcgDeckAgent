class_name AuthorStrategyRecordingProfile
extends RefCounted

const DEFAULT_PROFILE_ID := "player_compact_v1"
const DEVELOPER_FULL_PROFILE_ID := "developer_full_v1"


static func resolve_profile(requested_profile_id: String) -> Dictionary:
	var requested := requested_profile_id.strip_edges().to_lower()
	var selected := requested if requested in [DEFAULT_PROFILE_ID, DEVELOPER_FULL_PROFILE_ID] else DEFAULT_PROFILE_ID
	var profile := _profile(selected)
	profile["requested_profile_id"] = requested
	profile["fallback_used"] = not requested.is_empty() and requested != selected
	return profile


static func _profile(profile_id: String) -> Dictionary:
	if profile_id == DEVELOPER_FULL_PROFILE_ID:
		return {
			"profile_id": DEVELOPER_FULL_PROFILE_ID,
			"developer_trace_enabled": true,
			"match_evidence_enabled": true,
			"public_replay_enabled": true,
			"public_replay_progress_mode": "action",
			"rollback_profile": true,
		}
	return {
		"profile_id": DEFAULT_PROFILE_ID,
		"developer_trace_enabled": false,
		"match_evidence_enabled": true,
		"public_replay_enabled": true,
		"public_replay_progress_mode": "decision_boundary",
		"rollback_profile": false,
	}
