extends SceneTree
## Seed only an explicitly isolated test APPDATA with a real completed public replay.
const Contracts = preload("res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd")
const Store = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayStore.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	if OS.get_environment("PTCGDAP_SEED_ISOLATED_HISTORY") != "1":
		push_error("Explicit test-only user-data opt-in is required")
		quit(1)
		return
	# Load after autoload initialization: this owner binds CardDatabase.
	var acceptance: Script = load("res://scripts/ai/ptcgdap/acceptance/MarniePublicReplayAcceptance.gd")
	var report: Dictionary = acceptance.new().run(root.get_node("CardDatabase"), {
		"catalog_sources": preload("res://tests/ptcgdap/godot/support/LegacyAuthorStrategyFixtures.gd").sources(),
		"seed": 84590, "max_steps": 700,
	})
	if not report.get("is_clean", false) or not report.get("complete_match_finished", false):
		push_error("Public full-match fixture failed: %s" % report)
		quit(1)
		return
	var owner: Variant = Contracts.load_default().owner
	var artifact: Dictionary = report.artifact
	artifact.match_envelope.lane = "community_challenge"
	artifact.manifest.replay_id = "v062-completed-local-history"
	var envelope: Dictionary = owner.validate_document(artifact.match_envelope)
	artifact.manifest.match_envelope_sha256 = envelope.canonical_sha256
	var saved: Dictionary = Store.create(owner, "live-community", "community_challenge").store.save_completed(artifact)
	print("SEEDED_PUBLIC_HISTORY: %s" % JSON.stringify({
		"accepted": saved.get("accepted", false), "replay_id": artifact.manifest.replay_id,
		"frames": artifact.frames.size(), "complete_match_finished": report.complete_match_finished,
		"official_verified": false, "production_ready": false,
	}))
	quit(0 if saved.get("accepted", false) else 1)
