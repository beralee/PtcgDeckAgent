class_name BattleLivePacingProfile
extends RefCounted

const DEFAULT_PROFILE_ID := "author_realtime_v1"
const CINEMATIC_PROFILE_ID := "cinematic_v1"


static func resolve_profile(requested_profile_id: String) -> Dictionary:
	var requested := requested_profile_id.strip_edges().to_lower()
	var selected := requested if requested in [DEFAULT_PROFILE_ID, CINEMATIC_PROFILE_ID] else DEFAULT_PROFILE_ID
	var profile := _profile(selected)
	profile["requested_profile_id"] = requested
	profile["fallback_used"] = not requested.is_empty() and requested != selected
	return profile


static func _profile(profile_id: String) -> Dictionary:
	if profile_id == CINEMATIC_PROFILE_ID:
		return {
			"profile_id": CINEMATIC_PROFILE_ID,
			"action_pause_seconds": 2.0,
			"visual_playback_speed": 1.0,
			"rollback_profile": true,
		}
	return {
		"profile_id": DEFAULT_PROFILE_ID,
		"action_pause_seconds": 0.12,
		"visual_playback_speed": 1.5,
		"rollback_profile": false,
	}
