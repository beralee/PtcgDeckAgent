class_name TestMarniePublicReplayAcceptance
extends TestBase

const AcceptanceScript = preload("res://scripts/ai/ptcgdap/acceptance/MarniePublicReplayAcceptance.gd")
const ContractScript = preload("res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd")
const ViewerScene = preload("res://scenes/ptcgdap_public_replay/PublicReplayViewer.tscn")


func test_exact_marnie_live_public_owner_captures_complete_ui_only_replay() -> String:
	var report: Dictionary = AcceptanceScript.new().run(CardDatabase, {
		"catalog_sources": preload("res://tests/ptcgdap/godot/support/LegacyAuthorStrategyFixtures.gd").sources(),
		"seed": 84590,
		"max_steps": 700,
	})
	if not bool(report.get("is_clean", false)):
		return "public replay acceptance failed: %s" % report
	var artifact: Dictionary = report.get("artifact", {})
	var frames: Array = artifact.get("frames", [])
	var serialized := JSON.stringify(artifact).to_lower()
	var forbidden := [
		"\"hand\"", "\"deck\"", "\"prizes\"", "search_begin_input",
		"private_rng_state", "private_replay_snapshot", "instance_id", "object_id",
		"game_state", "action_ticket", "engine_object", "private_sentinel",
	]
	var checks: Array[String] = [
		assert_eq(report.get("document_type"), "marnie_public_replay_acceptance_v1"),
		assert_true(bool(report.get("complete_match_finished", false))),
		assert_true(bool(report.get("terminal", false))),
		assert_true(int(report.get("steps", 0)) > 0),
		assert_eq(frames.size(), int(report.get("steps", 0)) + 1),
		assert_eq(frames[0].get("event_kind"), "match_started"),
		assert_eq(frames[-1].get("event_kind"), "match_finished"),
		assert_eq(artifact.get("match_envelope", {}).get("lane"), "developer_local"),
		assert_eq(artifact.get("match_envelope", {}).get("seat_assignment"), [1, 0]),
		assert_false(bool(report.get("production_ready", true))),
		assert_false(bool(report.get("official_verified", true))),
		assert_false(bool(report.get("online_published", true))),
		assert_eq(report.get("capture_audit", {}).get("engine_invocations"), 0),
		assert_eq(report.get("presentation_audit", {}).get("engine_invocations"), 0),
		assert_eq(report.get("presentation_audit", {}).get("ticket_invocations"), 0),
		assert_eq(report.get("presentation_audit", {}).get("callback_invocations"), 0),
	]
	for token: String in forbidden:
		checks.append(assert_false(serialized.contains(token), token))
	checks.append_array(await _verify_live_capture_in_viewer(artifact))
	return run_checks(checks)


func _verify_live_capture_in_viewer(artifact: Dictionary) -> Array[String]:
	# Full-match coverage comes from this run's real capture, never a local
	# historical receipt or the three-frame synthetic layout fixture.
	var loaded := ContractScript.load_default()
	if not bool(loaded.get("accepted", false)):
		return ["Replay contract owner could not be loaded"]
	var source_before := JSON.stringify(artifact)
	var viewer: Control = ViewerScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(viewer)
	await tree.process_frame
	var opened: Dictionary = viewer.load_public_replay(loaded.owner, artifact.manifest, artifact.frames, artifact.match_envelope)
	var checks: Array[String] = [assert_true(bool(opened.get("accepted", false)), str(opened))]
	if bool(opened.get("accepted", false)):
		for ordinal: int in artifact.frames.size():
			var frame: Dictionary = artifact.frames[ordinal]
			var view: Dictionary = viewer.current_view()
			checks.append(assert_eq(view.get("ordinal"), ordinal, "Viewer must visit each captured frame"))
			checks.append(assert_eq(view.get("event_kind"), frame.event_kind))
			for field: String in ["board", "public_cards", "zone_counts"]:
				checks.append(assert_eq(view.get(field), frame.public_state[field], "Viewer must preserve public state: " + field))
			if ordinal + 1 < artifact.frames.size():
				viewer.show_next()
		var audit: Dictionary = viewer.presentation_audit()
		for counter: String in ["engine_invocations", "ticket_invocations", "callback_invocations"]:
			checks.append(assert_eq(audit.get(counter), 0, counter))
		checks.append(assert_eq(viewer.current_view().get("event_kind"), "match_finished"))
		checks.append(assert_eq(JSON.stringify(artifact), source_before, "Playback must not mutate captured evidence"))
	tree.root.remove_child(viewer)
	viewer.free()
	return checks


func test_public_replay_acceptance_is_repeatable_for_same_seed_identity_scope() -> String:
	var report: Dictionary = AcceptanceScript.new().run(CardDatabase, {
		"catalog_sources": preload("res://tests/ptcgdap/godot/support/LegacyAuthorStrategyFixtures.gd").sources(),
		"seed": 84591,
		"max_steps": 700,
	})
	return run_checks([
		assert_true(bool(report.get("is_clean", false))),
		assert_eq(report.get("strategy_id"), "ptcgdap.marnie.18.0.package-local-v1"),
		assert_eq(report.get("package_id"), "ptcgdap.marnie.windows-local"),
		assert_eq(report.get("candidate_deck_id"), 800018501),
		assert_eq(report.get("baseline_deck_id"), 575720),
		assert_eq(report.get("source_authority"), "ptcgdap_author_public_owner_v1"),
	])
