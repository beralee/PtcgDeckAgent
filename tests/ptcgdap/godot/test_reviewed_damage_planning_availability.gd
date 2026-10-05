class_name TestReviewedDamagePlanningAvailability
extends "res://tests/ptcgdap/godot/test_damage_planning_availability.gd"

# Every existing catalog-gap invariant must also hold for the newer profile.
func _spec() -> Dictionary:
	var spec := super._spec()
	spec.policy["damage_forecast_profile"] = "reviewed-gust-v1"
	return spec

# Keep the inherited matrix discoverable and prove this availability repair
# does not grant compatibility to an unrecognized forecast mode.
func test_unknown_forecast_profile_is_still_rejected() -> String:
	var spec := _spec()
	spec.policy.damage_forecast_profile = "unrecognized-forecast-v999"
	var compiled := Policy.compile_local_uid(spec.policy, spec.allowed_card_uids)
	return run_checks([
		assert_false(compiled.accepted),
		assert_eq(compiled.error_code, "invalid_damage_forecast_profile"),
	])
