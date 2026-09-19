class_name PublicReplayFixtureFactory
extends RefCounted

const ServiceContractScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayServiceContract.gd"
)

# Synthetic public UI fixture, included in Git; not a full-match receipt.
const UI_FIXTURE := (
	"res://tests/ptcgdap/fixtures/public_replay_ui.json"
)


static func load_developer_artifact() -> Dictionary:
	if not FileAccess.file_exists(UI_FIXTURE):
		return {}
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(UI_FIXTURE))
	if not decoded is Dictionary or not decoded.get("artifact") is Dictionary:
		return {}
	return ServiceContractScript.coerce_integral_numbers(decoded.get("artifact")).duplicate(true)


static func build_community_artifact(
	contract_owner: Variant,
	replay_id: String = "community-marnie-84590"
) -> Dictionary:
	var artifact := load_developer_artifact()
	if artifact.is_empty() or contract_owner == null:
		return {}
	artifact.get("match_envelope", {})["lane"] = "community_challenge"
	artifact.get("manifest", {})["replay_id"] = replay_id
	var envelope_result: Dictionary = contract_owner.validate_document(
		artifact.get("match_envelope")
	)
	if not bool(envelope_result.get("accepted", false)):
		return {}
	artifact.get("manifest", {})["match_envelope_sha256"] = str(
		envelope_result.get("canonical_sha256", "")
	)
	var replay_result: Dictionary = contract_owner.validate_replay(
		artifact.get("manifest"), artifact.get("frames")
	)
	return artifact if bool(replay_result.get("accepted", false)) else {}
