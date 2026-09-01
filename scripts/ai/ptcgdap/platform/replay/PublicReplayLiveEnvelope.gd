class_name PtcgDAPPublicReplayLiveEnvelope
extends RefCounted

const JsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const DevelopmentEnvelopeScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayDevelopmentEnvelope.gd"
)
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const PROFILE_ID := "csp-live-author-public-replay-v1"
const EVALUATOR_ID := "ptcgdap-live-public-capture"
const LANE := "community_challenge"
const VISIBILITY_PROFILE := "public_at_event_time_v1"
const EVENT_DICTIONARY := {
	"match_started": "first public state after the author owner is bound",
	"state_progressed": "public state after a logged live-game action",
	"match_finished": "terminal public state",
}


static func build(
	contract_owner: Variant,
	public_identity: Variant,
	match_id: String,
	opponent_deck_id: int = -1,
	strategy_seat: int = 1,
	opponent_public_identity: Variant = null
) -> Dictionary:
	if contract_owner == null or not contract_owner.has_method("validate_document"):
		return _failure("contract_owner_invalid")
	if not public_identity is Dictionary or not bool(public_identity.get("ok", false)):
		return _failure("public_identity_invalid")
	if public_identity.get("match_id") != match_id:
		return _failure("public_identity_match_mismatch")
	if strategy_seat not in [0, 1]:
		return _failure("public_identity_invalid")
	# Reuse the already-reviewed source-tree provenance builder, then replace every
	# development-fixture semantic field before the envelope becomes observable.
	var provenance_result: Dictionary = DevelopmentEnvelopeScript.build(
		contract_owner, public_identity, 0, match_id
	)
	if not bool(provenance_result.get("accepted", false)):
		return provenance_result
	var source_envelope: Dictionary = provenance_result.get("envelope", {})
	var strategy_participant: Variant = public_identity.get("strategy_participant")
	var card_catalog_sha256: Variant = public_identity.get("card_catalog_sha256")
	if not strategy_participant is Dictionary or typeof(card_catalog_sha256) != TYPE_STRING:
		return _failure("public_identity_invalid")
	var source_participants: Variant = source_envelope.get("participants")
	if not source_participants is Array or source_participants.size() != 2 \
		or not source_participants[1] is Dictionary:
		return _failure("public_identity_invalid")
	var baseline_participant: Dictionary = (source_participants[1] as Dictionary).duplicate(true)
	if opponent_public_identity != null:
		if (
			not opponent_public_identity is Dictionary
			or not bool(opponent_public_identity.get("ok", false))
			or opponent_public_identity.get("match_id") != match_id
			or opponent_public_identity.get("card_catalog_sha256") != card_catalog_sha256
			or not opponent_public_identity.get("strategy_participant") is Dictionary
		):
			return _failure("opponent_public_identity_invalid")
		baseline_participant = (
			opponent_public_identity.get("strategy_participant") as Dictionary
		).duplicate(true)
	elif opponent_deck_id >= 0:
		var rule_baseline: Dictionary = _build_rule_baseline_participant(
			opponent_deck_id, baseline_participant
		)
		if not bool(rule_baseline.get("accepted", false)):
			return rule_baseline
		baseline_participant = rule_baseline.get("participant", {}).duplicate(true)
	var live_profile := {
		"profile_id": PROFILE_ID,
		"lane": LANE,
		"baseline": baseline_participant.get(
			"baseline_id", baseline_participant.get("package_id")
		),
		"visibility_profile": VISIBILITY_PROFILE,
		"result_authority": false,
		"statistics_authority": false,
		"runtime_authority": false,
	}
	var envelope := {
		"document_type": "match_envelope_v1",
		"schema_version": 1,
		"match_id": match_id,
		"lane": LANE,
		"evaluator_id": EVALUATOR_ID,
		"participants": [
			(strategy_participant as Dictionary).duplicate(true),
			baseline_participant,
		],
		"engine_sha256": source_envelope.get("engine_sha256"),
		"rules_sha256": source_envelope.get("rules_sha256"),
		"card_catalog_sha256": card_catalog_sha256,
		"host_contract_sha256": contract_owner.bundle_canonical_sha256(),
		"runtime_manifest_sha256": source_envelope.get("runtime_manifest_sha256"),
		"evaluation_profile_id": PROFILE_ID,
		"evaluation_profile_sha256": _canonical_hash(live_profile),
		"seat_assignment": [strategy_seat, 1 - strategy_seat],
		"seed_commitment": {
			"capability": "none",
			"commitment_sha256": _canonical_hash({
				"domain": "csp_live_unseeded_match_identity_v1",
				"match_id": match_id,
			}),
			"disclosure": "public",
		},
		"replay_visibility_profile": VISIBILITY_PROFILE,
		"started_at_utc": "%sZ" % Time.get_datetime_string_from_system(true),
	}
	var validation: Dictionary = contract_owner.validate_document(envelope)
	if not bool(validation.get("accepted", false)):
		return validation
	return {
		"accepted": true,
		"error_code": "",
		"envelope": envelope,
		"card_asset_catalog_sha256": card_catalog_sha256,
		"event_dictionary_sha256": _canonical_hash(EVENT_DICTIONARY),
		"provenance": {
			"profile": live_profile,
			"evaluation_profile_sha256": envelope.evaluation_profile_sha256,
			"runtime_manifest_sha256": envelope.runtime_manifest_sha256,
		},
		"authoritative": false,
		"grants": [],
	}


static func _build_rule_baseline_participant(
	deck_id: int,
	source_baseline: Dictionary
) -> Dictionary:
	if deck_id <= 0:
		return _failure("rule_baseline_identity_invalid")
	var deck_path := "res://data/bundled_user/decks/%d.json" % deck_id
	if not FileAccess.file_exists(deck_path):
		return _failure("rule_baseline_deck_unavailable")
	var deck_sha256 := FileAccess.get_sha256(deck_path).to_upper()
	var runtime_sha256 := str(source_baseline.get("baseline_sha256", ""))
	var strategy_id := DeckStrategyRegistryScript.strategy_id_for_deck_id(deck_id)
	if not _is_sha256(deck_sha256) or not _is_sha256(runtime_sha256) \
		or strategy_id.strip_edges().is_empty():
		return _failure("rule_baseline_identity_invalid")
	return {
		"accepted": true,
		"error_code": "",
		"participant": {
			"participant_kind": "platform_baseline",
			"baseline_id": "rules-only-%d" % deck_id,
			"baseline_version": "1.0.0",
			"baseline_sha256": _canonical_hash({
				"domain": "ptcgdap_rules_only_baseline_v1",
				"deck_id": str(deck_id),
				"deck_source_sha256": deck_sha256,
				"strategy_id": strategy_id,
				"rules_ai_runtime_sha256": runtime_sha256,
			}),
		},
		"authoritative": false,
		"grants": [],
	}


static func _canonical_hash(value: Variant) -> String:
	var canonical: Dictionary = JsonTreeScript.canonicalize_artifact(value)
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(canonical.get("bytes", PackedByteArray())) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _is_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_upper():
		return false
	for character: String in value:
		if character not in "0123456789ABCDEF":
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code, "authoritative": false, "grants": []}
