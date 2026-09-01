class_name PtcgDAPExactReleaseChallengeBinder
extends RefCounted

const ContractScript = preload("res://scripts/ai/ptcgdap/platform/service/StrategyPlatformServiceContract.gd")


static func bind(intent: Variant, catalog: Variant) -> Dictionary:
	if not intent is Dictionary:
		return _failure("challenge_intent_invalid")
	if (
		intent.get("document_type") != "exact_release_challenge_intent_v1"
		or intent.get("schema_version") != 1
		or intent.get("authoritative") != false
		or intent.get("runtime_authority") != false
		or intent.get("grants") != []
	):
		return _failure("challenge_authority_invalid")
	if (
		intent.get("start_mode") != "development_built_in"
		or intent.get("player_start_allowed") != true
		or catalog == null
		or not catalog.has_method("list_metadata_records")
	):
		return _failure("challenge_start_unavailable")
	var identity: Variant = intent.get("release_identity")
	var requested: Variant = intent.get("local_selection")
	if not identity is Dictionary or not requested is Dictionary:
		return _failure("challenge_intent_invalid")
	if (
		not ContractScript.safe_identifier(identity.get("strategy_id"))
		or not ContractScript.safe_identifier(identity.get("package_id"))
		or not ContractScript.safe_identifier(identity.get("package_version"), 64)
		or not ContractScript.valid_sha256(identity.get("archive_sha256"))
		or not ContractScript.valid_sha256(identity.get("manifest_canonical_sha256"))
		or identity.get("replay_id") != intent.get("replay_id")
		or requested.get("package_id") != identity.get("package_id")
		or requested.get("package_version") != identity.get("package_version")
		or requested.get("archive_sha256") != identity.get("archive_sha256")
	):
		return _failure("challenge_identity_mismatch")
	var local_match: Dictionary = {}
	for candidate: Variant in catalog.list_metadata_records():
		if not candidate is Dictionary:
			continue
		if (
			candidate.get("package_id") == identity.get("package_id")
			and candidate.get("package_version") == identity.get("package_version")
			and candidate.get("archive_sha256") == identity.get("archive_sha256")
			and candidate.get("manifest_canonical_sha256") == identity.get("manifest_canonical_sha256")
			and candidate.get("install_source") == "built_in"
		):
			local_match = candidate
			break
	if local_match.is_empty():
		return _failure("challenge_package_not_installed")
	return {
		"accepted": true,
		"error_code": "",
		"challenge_id": intent.get("challenge_id"),
		"replay_id": intent.get("replay_id"),
		"release_id": intent.get("release_id"),
		"selection": {
			"package_id": identity.get("package_id"),
			"package_version": identity.get("package_version"),
			"archive_sha256": identity.get("archive_sha256"),
			"display_name_snapshot": str(requested.get("display_name_snapshot", "")),
			"install_source": "built_in",
		},
		"runtime_authority": false,
		"authoritative": false,
		"grants": [],
	}


static func _failure(code: String) -> Dictionary:
	return {
		"accepted": false,
		"error_code": code,
		"runtime_authority": false,
		"authoritative": false,
		"grants": [],
	}
