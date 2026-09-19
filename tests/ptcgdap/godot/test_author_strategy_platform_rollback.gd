extends TestBase

const ExecutionGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd")
const PackageLoaderScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const PackageHandleScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd")
const PackageDeckGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckGate.gd")
const FactoryScript = preload("res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd")
const CONTROL_FIXTURE := "res://data/ptcgdap/author_strategy_package_backups/reviewed-raging-bolt-ogerpon-1.0.0-round30-20ED94DE.ptcgai"


class ReadyCatalog extends RefCounted:
	var record: Dictionary = {}
	var handle: Variant = null
	var requests := 0

	func list_ready_records() -> Array[Dictionary]:
		return [record.duplicate(true)]

	func request_ready_match_handle(_id: String, _version: String, _sha: String) -> Dictionary:
		requests += 1
		return {"ok": true, "error_code": "", "handle": handle}


func _fixture() -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(CONTROL_FIXTURE)
	var inspected := PackageLoaderScript.new().inspect_control_distributed_player_match_bytes(
		bytes, FileAccess.get_sha256(CONTROL_FIXTURE).to_upper()
	)
	if not bool(inspected.get("ok", false)):
		return inspected
	var deck_gate := PackageDeckGateScript.build(inspected.get("payloads", {}))
	if not bool(deck_gate.get("ok", false)):
		return deck_gate
	var created := PackageHandleScript.create(
		inspected.get("metadata", {}), inspected.get("payloads", {}), deck_gate.get("local_deck", [])
	)
	if not bool(created.get("ok", false)):
		return created
	var materialized: Dictionary = GameManager.materialize_author_strategy_battle_deck(created.get("handle"))
	if not bool(materialized.get("ok", false)):
		return materialized
	created["deck"] = materialized.get("deck")
	created["metadata"] = inspected.get("metadata", {})
	return created


func _dispose_owner(owner: Variant) -> void:
	if owner == null:
		return
	var adapter: Variant = owner.get("_interaction_adapter")
	owner.close_match()
	# This isolated test has no BattleScene teardown. Drop the existing adapter
	# back-reference after close so the test does not retain the whole owner.
	if adapter != null:
		adapter.set("owner", null)


func test_rollback_blocks_new_matches_but_keeps_bound_owner_integrity_and_trust_checks() -> String:
	await (Engine.get_main_loop() as SceneTree).process_frame
	var setting := "ptcgdap/author_strategy/platforms/%s_enabled" % OS.get_name().to_lower()
	var previous: Variant = ProjectSettings.get_setting(setting, null)
	ProjectSettings.set_setting(setting, true)
	var fixture := _fixture()
	if not bool(fixture.get("ok", false)):
		ProjectSettings.set_setting(setting, previous)
		return "Could not prepare admitted Control fixture: %s" % fixture
	var handle: Variant = fixture.get("handle")
	var deck := fixture.get("deck") as DeckData
	var gsm := GameStateMachine.new()
	gsm.start_game(deck, deck, 0, false, true)
	var built := FactoryScript.build_windows_author_owner(
		handle, gsm, 1, "platform-rollback-existing", ExecutionGateScript.CONTROL_DISTRIBUTED_MODE
	)
	var owner: Variant = built.get("owner")
	if not bool(built.get("ok", false)) or owner == null:
		ProjectSettings.set_setting(setting, previous)
		gsm.prepare_for_disposal()
		return "Could not bind initial Control owner: %s" % built
	var catalog := ReadyCatalog.new()
	catalog.handle = handle
	catalog.record = fixture.get("metadata", {}).duplicate(true)
	catalog.record.merge({"status": "ready", "player_start_allowed": true, "install_source": "user", "install_sources": ["user"]}, true)
	var selection := {
		"package_id": catalog.record.get("package_id"),
		"package_version": catalog.record.get("package_version"),
		"archive_sha256": catalog.record.get("archive_sha256"),
		"install_source": "user",
	}
	var pins: Dictionary = handle.to_public_dict()
	var checks: Array[String] = [assert_true(owner.validate_integrity())]
	ProjectSettings.set_setting(setting, false)
	checks.append(assert_true(owner.validate_integrity(), "Rollback must not invalidate an already bound match"))
	checks.append(assert_eq(ExecutionGateScript.validate_handle_pins(pins, ExecutionGateScript.CONTROL_DISTRIBUTED_MODE), ""))
	var requested := ExecutionGateScript.request_match_handle(catalog, selection)
	checks.append(assert_false(requested.get("ok", true)))
	checks.append(assert_eq(requested.get("error_code"), "author_strategy_platform_disabled"))
	checks.append(assert_eq(catalog.requests, 0, "Disabled new-match admission must reject before reacquiring bytes"))
	var stale_start := FactoryScript.build_windows_author_owner(
		handle, gsm, 1, "platform-rollback-stale-handle", ExecutionGateScript.CONTROL_DISTRIBUTED_MODE
	)
	checks.append(assert_false(stale_start.get("ok", true), "A previously acquired handle cannot start another match after rollback"))
	var unexpected_owner: Variant = stale_start.get("owner")
	if unexpected_owner != null:
		_dispose_owner(unexpected_owner)
	var tampered := pins.duplicate(true)
	tampered["signature_scope"] = "local_import"
	checks.append(assert_false(ExecutionGateScript.validate_handle_pins(tampered, ExecutionGateScript.CONTROL_DISTRIBUTED_MODE).is_empty(), "Active-match integrity must still reject tampered trust pins"))
	ProjectSettings.set_setting(setting, previous)
	_dispose_owner(owner)
	gsm.prepare_for_disposal()
	return run_checks(checks)
