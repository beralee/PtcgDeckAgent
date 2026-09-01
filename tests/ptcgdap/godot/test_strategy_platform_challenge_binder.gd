class_name TestStrategyPlatformChallengeBinder
extends TestBase

const ContractScript = preload("res://scripts/ai/ptcgdap/platform/service/StrategyPlatformServiceContract.gd")
const BinderScript = preload("res://scripts/ai/ptcgdap/platform/service/ExactReleaseChallengeBinder.gd")

const ARCHIVE_SHA := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
const MANIFEST_SHA := "FC11754ECF7E73AD8C091D9B25D5578914150DE0B5C9D5104F3008162B0B2B11"


class FakeCatalog extends RefCounted:
	var records: Array[Dictionary] = []

	func list_metadata_records() -> Array[Dictionary]:
		return records.duplicate(true)


func _intent() -> Dictionary:
	return {
		"document_type": "exact_release_challenge_intent_v1",
		"schema_version": 1,
		"challenge_id": "challenge-unit",
		"replay_id": "replay-unit",
		"release_id": "release-unit",
		"release_identity": {
			"strategy_id": "ptcgdap.marnie.18.0.package-local-v1",
			"package_id": "ptcgdap.marnie.windows-local",
			"package_version": "0.1.0",
			"archive_sha256": ARCHIVE_SHA,
			"manifest_canonical_sha256": MANIFEST_SHA,
			"replay_id": "replay-unit",
		},
		"start_mode": "development_built_in",
		"player_start_allowed": true,
		"local_selection": {
			"package_id": "ptcgdap.marnie.windows-local",
			"package_version": "0.1.0",
			"archive_sha256": ARCHIVE_SHA,
			"display_name_snapshot": "Marnie strategy",
		},
		"package_path": "/v1/strategy-releases/release-unit/package",
		"runtime_authority": false,
		"authoritative": false,
		"grants": [],
	}


func _catalog() -> FakeCatalog:
	var catalog := FakeCatalog.new()
	catalog.records = [{
		"package_id": "ptcgdap.marnie.windows-local",
		"package_version": "0.1.0",
		"archive_sha256": ARCHIVE_SHA,
		"manifest_canonical_sha256": MANIFEST_SHA,
		"install_source": "built_in",
		"strategy": {"display_name": "Local Marnie"},
	}]
	return catalog


func test_fixed_contract_and_exact_local_rebind_are_non_authoritative() -> String:
	var contract: Dictionary = ContractScript.load_fixed()
	var bound: Dictionary = BinderScript.bind(_intent(), _catalog())
	return run_checks([
		assert_true(bool(contract.get("accepted", false))),
		assert_eq(contract.get("canonical_sha256"), "3C9910759750649CD446BD9491E1427AB42762EA348E77354A66E54F0959B9A0"),
		assert_true(bool(bound.get("accepted", false))),
		assert_eq(bound.get("selection", {}).get("install_source"), "built_in"),
		assert_eq(bound.get("selection", {}).get("archive_sha256"), ARCHIVE_SHA),
		assert_false(bool(bound.get("authoritative", true))),
		assert_false(bool(bound.get("runtime_authority", true))),
		assert_eq(bound.get("grants"), []),
	])


func test_forged_authority_stale_identity_and_missing_local_package_fail_closed() -> String:
	var forged := _intent()
	forged.runtime_authority = true
	var forged_result: Dictionary = BinderScript.bind(forged, _catalog())
	var stale := _intent()
	stale.local_selection.archive_sha256 = "A".repeat(64)
	var stale_result: Dictionary = BinderScript.bind(stale, _catalog())
	var empty_catalog := FakeCatalog.new()
	var missing_result: Dictionary = BinderScript.bind(_intent(), empty_catalog)
	return run_checks([
		assert_eq(forged_result.get("error_code"), "challenge_authority_invalid"),
		assert_eq(stale_result.get("error_code"), "challenge_identity_mismatch"),
		assert_eq(missing_result.get("error_code"), "challenge_package_not_installed"),
	])
