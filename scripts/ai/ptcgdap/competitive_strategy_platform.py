from __future__ import annotations

from dataclasses import dataclass
import copy
import hashlib
from pathlib import Path
from typing import Any, Callable, Final

from jsonschema import Draft202012Validator

from .source_lock import canonical_json_v1_bytes, load_json_strict


CONTRACT_RELATIVE_ROOT: Final = Path("contracts/ptcgdap")
BUNDLE_RELATIVE_PATH: Final = CONTRACT_RELATIVE_ROOT / "competitive_strategy_platform_bundle.json"
BUNDLE_ID: Final = "ptcgdap-competitive-strategy-platform-csp-wp0-v1"
PROFILE_ID: Final = "competitive_strategy_platform_contract_v1"
EXPECTED_BUNDLE_CANONICAL_SHA256: Final = "B642E704B92A8A76E0D15D02C20B8CC006C4AD2FEE90324FEEBD35114DF92262"
FRAME_HASH_DOMAIN: Final = b"PTCGDAP\0CSP_PUBLIC_REPLAY_FRAME_V1\0"
MAX_CONTRACT_FILE_BYTES: Final = 2 * 1024 * 1024

_ARTIFACTS: Final = (
    (
        "schema",
        "contracts/ptcgdap/competitive_strategy_platform.schema.json",
    ),
    (
        "profile",
        "contracts/ptcgdap/competitive_strategy_platform_profile.json",
    ),
    (
        "threat_model",
        "contracts/ptcgdap/competitive_strategy_platform_threat_model.json",
    ),
    (
        "vectors",
        "contracts/ptcgdap/competitive_strategy_platform_conformance_vectors.json",
    ),
)

_DOCUMENT_KEYS: Final[dict[str, frozenset[str]]] = {
    "strategy_release_ref_v1": frozenset(
        {
            "document_type",
            "schema_version",
            "strategy_id",
            "release_version",
            "author_id",
            "package_id",
            "archive_sha256",
            "manifest_canonical_sha256",
            "deck_identity",
            "policy_package_sha256",
            "contract_bundle_sha256",
            "catalog_bundle_sha256",
            "runtime_manifest_sha256",
            "platforms",
            "signature_key_id",
            "release_state",
            "revocation_state",
        }
    ),
    "evaluation_profile_v1": frozenset(
        {
            "document_type",
            "schema_version",
            "profile_id",
            "profile_version",
            "visibility",
            "evaluator_id",
            "evaluator_build_sha256",
            "engine_sha256",
            "rules_sha256",
            "card_catalog_sha256",
            "host_contract_sha256",
            "opponents",
            "seat_policy",
            "seed_policy",
            "games_per_pair",
            "limits",
            "outcome_policy",
            "aggregation",
            "replay_policy",
        }
    ),
    "match_envelope_v1": frozenset(
        {
            "document_type",
            "schema_version",
            "match_id",
            "lane",
            "evaluator_id",
            "participants",
            "engine_sha256",
            "rules_sha256",
            "card_catalog_sha256",
            "host_contract_sha256",
            "runtime_manifest_sha256",
            "evaluation_profile_id",
            "evaluation_profile_sha256",
            "seat_assignment",
            "seed_commitment",
            "replay_visibility_profile",
            "started_at_utc",
        }
    ),
    "replay_frame_v1": frozenset(
        {
            "document_type",
            "schema_version",
            "match_id",
            "ordinal",
            "turn_number",
            "phase",
            "acting_seat",
            "event_kind",
            "public_state",
            "decision_trace_sha256",
            "previous_frame_sha256",
        }
    ),
    "replay_manifest_v1": frozenset(
        {
            "document_type",
            "schema_version",
            "replay_id",
            "match_id",
            "match_envelope_sha256",
            "visibility_profile",
            "frame_count",
            "first_frame_sha256",
            "frame_chain_root_sha256",
            "card_asset_catalog_sha256",
            "event_dictionary_sha256",
            "complete",
        }
    ),
    "verified_match_result_v1": frozenset(
        {
            "document_type",
            "schema_version",
            "match_id",
            "match_envelope_sha256",
            "trust_lane",
            "outcome",
            "winner_seat",
            "turn_count",
            "decision_count",
            "fault_counts",
            "dirty",
            "dirty_reasons",
            "replay_manifest_sha256",
            "evidence_sha256",
            "verification",
        }
    ),
    "evaluation_summary_v1": frozenset(
        {
            "document_type",
            "schema_version",
            "strategy_release",
            "evaluation_profile_id",
            "evaluation_profile_sha256",
            "aggregation_version",
            "input_match_ids",
            "counts",
            "fault_counts",
            "win_rate_basis_points",
            "confidence_interval_basis_points",
            "seat_breakdown",
            "matchup_breakdown",
            "materializer_build_sha256",
        }
    ),
}

_FORBIDDEN_PUBLIC_KEYS: Final = frozenset(
    {
        "hand",
        "deck",
        "prizes",
        "deck_order",
        "search_begin_input",
        "private_rng_state",
        "private_replay_snapshot",
        "instance_id",
        "object_id",
        "game_state",
        "game_state_machine",
        "action_ticket",
        "callback",
        "binding",
        "engine_object",
    }
)

_HASH_FIELDS: Final = frozenset(
    {
        "archive_sha256",
        "manifest_canonical_sha256",
        "deck_sha256",
        "policy_package_sha256",
        "contract_bundle_sha256",
        "catalog_bundle_sha256",
        "runtime_manifest_sha256",
        "baseline_sha256",
        "evaluator_build_sha256",
        "engine_sha256",
        "rules_sha256",
        "card_catalog_sha256",
        "host_contract_sha256",
        "evaluation_profile_sha256",
        "commitment_sha256",
        "decision_trace_sha256",
        "previous_frame_sha256",
        "match_envelope_sha256",
        "first_frame_sha256",
        "frame_chain_root_sha256",
        "card_asset_catalog_sha256",
        "event_dictionary_sha256",
        "replay_manifest_sha256",
        "evidence_sha256",
        "materializer_build_sha256",
    }
)

_FAULT_KEYS: Final = frozenset(
    {"invalid_output", "policy_error", "timeout", "engine_rejection", "fallback"}
)


class CspContractError(ValueError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


@dataclass(frozen=True, slots=True)
class ValidatedCspDocument:
    document_type: str
    canonical_sha256: str

    def to_public_audit(self) -> dict[str, Any]:
        return {
            "document_type": self.document_type,
            "canonical_sha256": self.canonical_sha256,
            "authoritative": False,
            "grants": [],
        }


@dataclass(frozen=True, slots=True)
class ReplayValidation:
    replay_id: str
    match_id: str
    frame_count: int
    frame_chain_root_sha256: str

    def to_public_audit(self) -> dict[str, Any]:
        return {
            "document_type": "replay_validation_v1",
            "replay_id": self.replay_id,
            "match_id": self.match_id,
            "frame_count": self.frame_count,
            "frame_chain_root_sha256": self.frame_chain_root_sha256,
            "authoritative": False,
            "engine_invoked": False,
            "grants": [],
        }


@dataclass(frozen=True, slots=True)
class CspContractSet:
    repository_root: Path
    schema: dict[str, Any]
    profile: dict[str, Any]
    threat_model: dict[str, Any]
    vectors: dict[str, Any]
    bundle_canonical_sha256: str

    @classmethod
    def load_trusted(cls, repository_root: str | Path) -> "CspContractSet":
        root = Path(repository_root).resolve()
        bundle_path = _resolve_beneath(root, BUNDLE_RELATIVE_PATH)
        bundle = _load_bounded_json(bundle_path)
        bundle_hash = _canonical_sha(bundle)
        if bundle_hash != EXPECTED_BUNDLE_CANONICAL_SHA256:
            raise CspContractError("contract_bundle_trust_anchor_mismatch")
        if set(bundle) != {
            "document_type",
            "schema_version",
            "bundle_id",
            "profile_id",
            "digest_mode",
            "artifact_set_policy",
            "artifacts",
        }:
            raise CspContractError("contract_bundle_invalid")
        if (
            bundle["document_type"] != "competitive_strategy_platform_bundle_v1"
            or type(bundle["schema_version"]) is not int
            or bundle["schema_version"] != 1
            or bundle["bundle_id"] != BUNDLE_ID
            or bundle["profile_id"] != PROFILE_ID
            or bundle["digest_mode"] != "canonical_json_v1"
            or bundle["artifact_set_policy"] != "exact_ids_paths_hashes_no_duplicates"
            or type(bundle["artifacts"]) is not list
            or len(bundle["artifacts"]) != len(_ARTIFACTS)
        ):
            raise CspContractError("contract_bundle_invalid")

        expected = {artifact_id: path for artifact_id, path in _ARTIFACTS}
        loaded: dict[str, dict[str, Any]] = {}
        seen: set[str] = set()
        for entry in bundle["artifacts"]:
            if type(entry) is not dict or set(entry) != {
                "artifact_id",
                "path",
                "canonical_sha256",
            }:
                raise CspContractError("contract_bundle_invalid")
            artifact_id = entry["artifact_id"]
            path = entry["path"]
            if (
                type(artifact_id) is not str
                or artifact_id not in expected
                or artifact_id in seen
                or path != expected[artifact_id]
                or not _is_sha256(entry["canonical_sha256"])
            ):
                raise CspContractError("contract_bundle_invalid")
            document = _load_bounded_json(_resolve_beneath(root, Path(path)))
            if _canonical_sha(document) != entry["canonical_sha256"]:
                raise CspContractError("contract_artifact_hash_mismatch")
            loaded[artifact_id] = document
            seen.add(artifact_id)
        if seen != set(expected):
            raise CspContractError("contract_bundle_invalid")

        Draft202012Validator.check_schema(loaded["schema"])
        _validate_profile(loaded["profile"])
        _validate_threat_model(loaded["threat_model"])
        _validate_vectors_shape(loaded["vectors"])
        return cls(
            repository_root=root,
            schema=copy.deepcopy(loaded["schema"]),
            profile=copy.deepcopy(loaded["profile"]),
            threat_model=copy.deepcopy(loaded["threat_model"]),
            vectors=copy.deepcopy(loaded["vectors"]),
            bundle_canonical_sha256=bundle_hash,
        )


class CspContractOwner:
    def __init__(self, contracts: CspContractSet) -> None:
        if type(contracts) is not CspContractSet:
            raise CspContractError("contract_owner_invalid")
        self._profile = copy.deepcopy(contracts.profile)
        self._vectors = copy.deepcopy(contracts.vectors)
        self._schema_validator = Draft202012Validator(copy.deepcopy(contracts.schema))

    @classmethod
    def load_trusted(cls, repository_root: str | Path) -> "CspContractOwner":
        return cls(CspContractSet.load_trusted(repository_root))

    def validate_document(self, document: Any) -> ValidatedCspDocument:
        value = copy.deepcopy(document)
        _reject_forbidden_public_keys(value)
        if type(value) is not dict:
            raise CspContractError("document_invalid")
        document_type = value.get("document_type")
        if type(document_type) is not str or document_type not in _DOCUMENT_KEYS:
            raise CspContractError("document_type_unsupported")
        if set(value) != _DOCUMENT_KEYS[document_type]:
            if document_type == "verified_match_result_v1" and "verification" not in value:
                raise CspContractError("official_verification_required")
            raise CspContractError("unknown_field")
        if type(value.get("schema_version")) is not int or value["schema_version"] != 1:
            raise CspContractError("schema_unsupported")
        canonical = canonical_json_v1_bytes(value)
        max_document_bytes = _positive_int(
            self._profile["limits"]["max_document_bytes"],
            "contract_profile_invalid",
        )
        if len(canonical) > max_document_bytes:
            raise CspContractError("document_too_large")

        validator = _VALIDATORS[document_type]
        validator(value, self._profile)
        errors = sorted(
            self._schema_validator.iter_errors(value),
            key=lambda error: tuple(str(part) for part in error.absolute_path),
        )
        if errors:
            raise CspContractError("schema_invalid")
        return ValidatedCspDocument(document_type, _sha_bytes(canonical))

    def validate_replay(self, manifest: Any, frames: Any) -> ReplayValidation:
        manifest_value = copy.deepcopy(manifest)
        frames_value = copy.deepcopy(frames)
        self.validate_document(manifest_value)
        if type(frames_value) is not list:
            raise CspContractError("replay_chain_invalid")
        max_frames = _positive_int(
            self._profile["limits"]["max_replay_frames"],
            "contract_profile_invalid",
        )
        if len(frames_value) > max_frames:
            raise CspContractError("replay_too_large")
        if not frames_value:
            raise CspContractError("replay_chain_invalid")
        if len(frames_value) != manifest_value["frame_count"]:
            raise CspContractError("replay_chain_invalid")

        expected_previous: str | None = None
        first_hash = ""
        last_hash = ""
        for ordinal, frame in enumerate(frames_value):
            self.validate_document(frame)
            if (
                frame["match_id"] != manifest_value["match_id"]
                or frame["ordinal"] != ordinal
                or frame["previous_frame_sha256"] != expected_previous
            ):
                raise CspContractError("replay_chain_invalid")
            current_hash = frame_hash(frame)
            if ordinal == 0:
                first_hash = current_hash
            last_hash = current_hash
            expected_previous = current_hash
        if (
            manifest_value["first_frame_sha256"] != first_hash
            or manifest_value["frame_chain_root_sha256"] != last_hash
            or not manifest_value["complete"]
        ):
            raise CspContractError("replay_chain_invalid")
        return ReplayValidation(
            replay_id=manifest_value["replay_id"],
            match_id=manifest_value["match_id"],
            frame_count=len(frames_value),
            frame_chain_root_sha256=last_hash,
        )

    def validate_match_against_profile(self, envelope: Any, profile: Any) -> dict[str, Any]:
        envelope_value = copy.deepcopy(envelope)
        profile_value = copy.deepcopy(profile)
        self.validate_document(envelope_value)
        self.validate_document(profile_value)
        comparable = (
            envelope_value["evaluation_profile_id"] == profile_value["profile_id"]
            and envelope_value["evaluator_id"] == profile_value["evaluator_id"]
            and envelope_value["engine_sha256"] == profile_value["engine_sha256"]
            and envelope_value["rules_sha256"] == profile_value["rules_sha256"]
            and envelope_value["card_catalog_sha256"] == profile_value["card_catalog_sha256"]
            and envelope_value["host_contract_sha256"] == profile_value["host_contract_sha256"]
            and envelope_value["replay_visibility_profile"]
            == profile_value["replay_policy"]["visibility_profile"]
        )
        if not comparable:
            raise CspContractError("evaluation_profile_mismatch")
        return {
            "document_type": "match_profile_binding_v1",
            "status": "accepted",
            "authoritative": False,
            "grants": [],
        }

    def run_vector(self, case: Any) -> dict[str, Any]:
        if type(case) is not dict or set(case) not in (
            {"id", "operation", "fixture", "expected"},
            {"id", "operation", "fixture", "mutation", "error_code"},
        ):
            raise CspContractError("vector_invalid")
        fixture_id = case["fixture"]
        fixtures = self._vectors["fixtures"]
        if type(fixture_id) is not str or fixture_id not in fixtures:
            raise CspContractError("vector_invalid")
        value = copy.deepcopy(fixtures[fixture_id])
        if "mutation" in case:
            value = _apply_mutation(value, case["mutation"])
        operation = case["operation"]
        if operation == "validate_document":
            result = self.validate_document(value)
            return {
                "status": "accepted",
                "document_type": result.document_type,
                "authoritative": False,
                "grants": [],
            }
        if operation == "validate_replay":
            result = self.validate_replay(value["manifest"], value["frames"])
            return {
                "status": "accepted",
                "document_type": "replay_validation_v1",
                "frame_count": result.frame_count,
                "authoritative": False,
                "grants": [],
            }
        if operation == "validate_match_against_profile":
            return self.validate_match_against_profile(value["envelope"], value["profile"])
        raise CspContractError("vector_invalid")


def frame_hash(frame: Any) -> str:
    _reject_forbidden_public_keys(frame)
    if type(frame) is not dict:
        raise CspContractError("replay_chain_invalid")
    return _sha_bytes(FRAME_HASH_DOMAIN + canonical_json_v1_bytes(frame))


def _validate_strategy_release(value: dict[str, Any], profile: dict[str, Any]) -> None:
    _require_identifier(value["strategy_id"])
    _require_version(value["release_version"])
    _require_identifier(value["author_id"])
    _require_identifier(value["package_id"])
    _require_hash_fields(value)
    _validate_deck_identity(value["deck_identity"])
    if (
        type(value["platforms"]) is not list
        or not value["platforms"]
        or len(value["platforms"]) > profile["limits"]["max_platforms"]
        or any(platform not in profile["allowed_platforms"] for platform in value["platforms"])
        or len(set(value["platforms"])) != len(value["platforms"])
    ):
        raise CspContractError("release_platform_invalid")
    _require_identifier(value["signature_key_id"])
    if value["release_state"] not in profile["release_states"]:
        raise CspContractError("release_state_invalid")
    if value["revocation_state"] not in profile["revocation_states"]:
        raise CspContractError("release_state_invalid")


def _validate_evaluation_profile(value: dict[str, Any], profile: dict[str, Any]) -> None:
    _require_identifier(value["profile_id"])
    _require_version(value["profile_version"])
    _require_identifier(value["evaluator_id"])
    _require_hash_fields(value)
    if value["visibility"] not in profile["evaluation_visibility"]:
        raise CspContractError("evaluation_profile_invalid")
    if (
        type(value["opponents"]) is not list
        or not value["opponents"]
        or len(value["opponents"]) > profile["limits"]["max_opponents"]
    ):
        raise CspContractError("evaluation_profile_invalid")
    for opponent in value["opponents"]:
        _validate_participant(opponent)
    if value["seat_policy"] != "paired_swap":
        raise CspContractError("evaluation_profile_invalid")
    _require_exact_object(value["seed_policy"], {"capability", "disclosure"}, "evaluation_profile_invalid")
    if (
        value["seed_policy"]["capability"] not in profile["seed_capabilities"]
        or value["seed_policy"]["disclosure"] not in {"public_exact", "commitment_only"}
    ):
        raise CspContractError("evaluation_profile_invalid")
    if not 1 <= _positive_int(value["games_per_pair"], "evaluation_profile_invalid") <= 100000:
        raise CspContractError("evaluation_profile_invalid")
    _require_exact_object(
        value["limits"],
        {"match_time_ms", "decision_time_ms", "memory_mib"},
        "evaluation_profile_invalid",
    )
    for number in value["limits"].values():
        _positive_int(number, "evaluation_profile_invalid")
    _require_exact_object(
        value["outcome_policy"],
        {"draws_allowed", "invalid_output", "policy_error", "timeout", "dirty"},
        "evaluation_profile_invalid",
    )
    if type(value["outcome_policy"]["draws_allowed"]) is not bool:
        raise CspContractError("evaluation_profile_invalid")
    if value["outcome_policy"] != {
        "draws_allowed": value["outcome_policy"]["draws_allowed"],
        "invalid_output": "verified_loss_and_fault",
        "policy_error": "verified_loss_and_fault",
        "timeout": "verified_loss_and_fault",
        "dirty": "exclude_from_rank_show_separately",
    }:
        raise CspContractError("evaluation_profile_invalid")
    _require_exact_object(
        value["aggregation"],
        {"version", "minimum_publish_games", "confidence_level_basis_points"},
        "evaluation_profile_invalid",
    )
    _require_identifier(value["aggregation"]["version"])
    _positive_int(value["aggregation"]["minimum_publish_games"], "evaluation_profile_invalid")
    confidence = _positive_int(
        value["aggregation"]["confidence_level_basis_points"],
        "evaluation_profile_invalid",
    )
    if not 1 <= confidence <= 10000:
        raise CspContractError("evaluation_profile_invalid")
    _require_exact_object(
        value["replay_policy"],
        {"visibility_profile", "sampling"},
        "evaluation_profile_invalid",
    )
    if value["replay_policy"]["visibility_profile"] not in profile["replay_visibility_profiles"]:
        raise CspContractError("evaluation_profile_invalid")
    _require_identifier(value["replay_policy"]["sampling"])


def _validate_match_envelope(value: dict[str, Any], profile: dict[str, Any]) -> None:
    _require_identifier(value["match_id"])
    if value["lane"] not in profile["match_lanes"]:
        raise CspContractError("match_lane_invalid")
    _require_identifier(value["evaluator_id"])
    if type(value["participants"]) is not list or len(value["participants"]) != 2:
        raise CspContractError("match_participants_invalid")
    for participant in value["participants"]:
        _validate_participant(participant)
    _require_hash_fields(value)
    _require_identifier(value["evaluation_profile_id"])
    seat_assignment = value["seat_assignment"]
    if (
        type(seat_assignment) is not list
        or len(seat_assignment) != 2
        or any(type(seat) is not int for seat in seat_assignment)
        or (seat_assignment != [0, 1] and seat_assignment != [1, 0])
    ):
        raise CspContractError("match_participants_invalid")
    _require_exact_object(
        value["seed_commitment"],
        {"capability", "commitment_sha256", "disclosure"},
        "seed_commitment_invalid",
    )
    _require_hash_fields(value["seed_commitment"])
    if (
        value["seed_commitment"]["capability"] not in profile["seed_capabilities"]
        or value["seed_commitment"]["disclosure"] not in {"public", "withheld"}
    ):
        raise CspContractError("seed_commitment_invalid")
    if value["replay_visibility_profile"] not in profile["replay_visibility_profiles"]:
        raise CspContractError("replay_visibility_invalid")
    _require_timestamp(value["started_at_utc"])


def _validate_replay_frame(value: dict[str, Any], profile: dict[str, Any]) -> None:
    _require_identifier(value["match_id"])
    _non_negative_int(value["ordinal"], "replay_frame_invalid")
    _non_negative_int(value["turn_number"], "replay_frame_invalid")
    _require_identifier(value["phase"])
    if type(value["acting_seat"]) is not int or value["acting_seat"] not in {-1, 0, 1}:
        raise CspContractError("replay_frame_invalid")
    _require_identifier(value["event_kind"])
    _require_exact_object(value["public_state"], {"zone_counts", "board", "public_cards"}, "replay_frame_invalid")
    zone_counts = value["public_state"]["zone_counts"]
    if type(zone_counts) is not list or len(zone_counts) != 2:
        raise CspContractError("replay_frame_invalid")
    seats: list[int] = []
    for row in zone_counts:
        _require_exact_object(
            row,
            {"seat", "hand_count", "deck_count", "prize_count"},
            "replay_frame_invalid",
        )
        if type(row["seat"]) is not int or row["seat"] not in {0, 1}:
            raise CspContractError("replay_frame_invalid")
        seats.append(row["seat"])
        for key in ("hand_count", "deck_count", "prize_count"):
            _non_negative_int(row[key], "replay_frame_invalid")
    if sorted(seats) != [0, 1]:
        raise CspContractError("replay_frame_invalid")
    if type(value["public_state"]["board"]) is not list or type(value["public_state"]["public_cards"]) is not list:
        raise CspContractError("replay_frame_invalid")
    if len(value["public_state"]["board"]) > profile["limits"]["max_public_board_entries"]:
        raise CspContractError("replay_frame_invalid")
    if len(value["public_state"]["public_cards"]) > profile["limits"]["max_public_card_entries"]:
        raise CspContractError("replay_frame_invalid")
    for entry in value["public_state"]["board"]:
        _validate_board_entry(entry)
    for entry in value["public_state"]["public_cards"]:
        _validate_public_card_entry(entry)
    _optional_hash(value["decision_trace_sha256"], "replay_frame_invalid")
    _optional_hash(value["previous_frame_sha256"], "replay_frame_invalid")


def _validate_replay_manifest(value: dict[str, Any], profile: dict[str, Any]) -> None:
    _require_identifier(value["replay_id"])
    _require_identifier(value["match_id"])
    _require_hash_fields(value)
    if value["visibility_profile"] not in profile["replay_visibility_profiles"]:
        raise CspContractError("replay_visibility_invalid")
    count = _positive_int(value["frame_count"], "replay_manifest_invalid")
    if count > profile["limits"]["max_replay_frames"]:
        raise CspContractError("replay_too_large")
    if type(value["complete"]) is not bool:
        raise CspContractError("replay_manifest_invalid")


def _validate_verified_result(value: dict[str, Any], profile: dict[str, Any]) -> None:
    _require_identifier(value["match_id"])
    _require_hash_fields(value)
    if value["trust_lane"] not in profile["result_lanes"]:
        raise CspContractError("result_lane_invalid")
    if value["outcome"] not in {"seat_0_win", "seat_1_win", "draw", "aborted"}:
        raise CspContractError("result_outcome_invalid")
    winner = value["winner_seat"]
    if value["outcome"] == "seat_0_win" and (type(winner) is not int or winner != 0):
        raise CspContractError("result_outcome_invalid")
    if value["outcome"] == "seat_1_win" and (type(winner) is not int or winner != 1):
        raise CspContractError("result_outcome_invalid")
    if value["outcome"] in {"draw", "aborted"} and winner is not None:
        raise CspContractError("result_outcome_invalid")
    _non_negative_int(value["turn_count"], "result_counts_invalid")
    _non_negative_int(value["decision_count"], "result_counts_invalid")
    _validate_fault_counts(value["fault_counts"])
    if type(value["dirty"]) is not bool or type(value["dirty_reasons"]) is not list:
        raise CspContractError("result_dirty_invalid")
    if len(value["dirty_reasons"]) > 64 or len(set(value["dirty_reasons"])) != len(value["dirty_reasons"]):
        raise CspContractError("result_dirty_invalid")
    if value["dirty"] != bool(value["dirty_reasons"]):
        raise CspContractError("result_dirty_invalid")
    for reason in value["dirty_reasons"]:
        _require_identifier(reason)
    verification = value["verification"]
    if value["trust_lane"] == "official_verified":
        if value["dirty"]:
            raise CspContractError("lane_authority_mismatch")
        _validate_verification(verification)
    elif verification is not None:
        raise CspContractError("lane_authority_mismatch")
    if value["trust_lane"] == "rejected_or_dirty" and not value["dirty"]:
        raise CspContractError("lane_authority_mismatch")


def _validate_evaluation_summary(value: dict[str, Any], profile: dict[str, Any]) -> None:
    _require_exact_object(
        value["strategy_release"],
        {"strategy_id", "release_version", "archive_sha256"},
        "summary_release_invalid",
    )
    _require_identifier(value["strategy_release"]["strategy_id"])
    _require_version(value["strategy_release"]["release_version"])
    _require_hash_fields(value["strategy_release"])
    _require_identifier(value["evaluation_profile_id"])
    _require_hash_fields(value)
    _require_identifier(value["aggregation_version"])
    match_ids = value["input_match_ids"]
    if (
        type(match_ids) is not list
        or not match_ids
        or len(match_ids) > 100000
        or any(type(match_id) is not str for match_id in match_ids)
        or match_ids != sorted(set(match_ids))
    ):
        raise CspContractError("summary_inputs_invalid")
    for match_id in match_ids:
        _require_identifier(match_id)
    _require_exact_object(value["counts"], {"wins", "losses", "draws", "valid", "dirty"}, "summary_counts_invalid")
    for count in value["counts"].values():
        _non_negative_int(count, "summary_counts_invalid")
    counts = value["counts"]
    if counts["wins"] + counts["losses"] + counts["draws"] != counts["valid"]:
        raise CspContractError("summary_counts_invalid")
    if counts["valid"] + counts["dirty"] != len(match_ids):
        raise CspContractError("summary_counts_invalid")
    _validate_fault_counts(value["fault_counts"])
    rate = _non_negative_int(value["win_rate_basis_points"], "summary_counts_invalid")
    if rate > 10000:
        raise CspContractError("summary_counts_invalid")
    _require_exact_object(
        value["confidence_interval_basis_points"],
        {"low", "high"},
        "summary_counts_invalid",
    )
    low = _non_negative_int(value["confidence_interval_basis_points"]["low"], "summary_counts_invalid")
    high = _non_negative_int(value["confidence_interval_basis_points"]["high"], "summary_counts_invalid")
    if low > rate or rate > high or high > 10000:
        raise CspContractError("summary_counts_invalid")
    _validate_seat_breakdown(value["seat_breakdown"], counts)
    matchups = value["matchup_breakdown"]
    if type(matchups) is not list or len(matchups) > profile["limits"]["max_opponents"]:
        raise CspContractError("summary_counts_invalid")
    for row in matchups:
        _require_exact_object(
            row,
            {"opponent_id", "wins", "losses", "draws"},
            "summary_counts_invalid",
        )
        _require_identifier(row["opponent_id"])
        for key in ("wins", "losses", "draws"):
            _non_negative_int(row[key], "summary_counts_invalid")


_VALIDATORS: Final[dict[str, Callable[[dict[str, Any], dict[str, Any]], None]]] = {
    "strategy_release_ref_v1": _validate_strategy_release,
    "evaluation_profile_v1": _validate_evaluation_profile,
    "match_envelope_v1": _validate_match_envelope,
    "replay_frame_v1": _validate_replay_frame,
    "replay_manifest_v1": _validate_replay_manifest,
    "verified_match_result_v1": _validate_verified_result,
    "evaluation_summary_v1": _validate_evaluation_summary,
}


def _validate_deck_identity(value: Any) -> None:
    _require_exact_object(value, {"domain", "deck_id", "deck_sha256"}, "deck_identity_invalid")
    if value["domain"] not in {"official_card_id_v1", "godot_local_card_uid_v1"}:
        raise CspContractError("deck_identity_invalid")
    _require_identifier(value["deck_id"])
    _require_hash_fields(value)


def _validate_participant(value: Any) -> None:
    if type(value) is not dict:
        raise CspContractError("match_participants_invalid")
    kind = value.get("participant_kind")
    if kind == "platform_baseline":
        _require_exact_object(
            value,
            {"participant_kind", "baseline_id", "baseline_version", "baseline_sha256"},
            "match_participants_invalid",
        )
        _require_identifier(value["baseline_id"])
        _require_version(value["baseline_version"])
        _require_hash_fields(value)
        return
    if kind == "strategy_release":
        _require_exact_object(
            value,
            {
                "participant_kind",
                "strategy_id",
                "release_version",
                "package_id",
                "archive_sha256",
                "manifest_canonical_sha256",
                "deck_identity",
                "policy_package_sha256",
            },
            "match_participants_invalid",
        )
        _require_identifier(value["strategy_id"])
        _require_version(value["release_version"])
        _require_identifier(value["package_id"])
        _require_hash_fields(value)
        _validate_deck_identity(value["deck_identity"])
        return
    raise CspContractError("match_participants_invalid")


def _validate_board_entry(value: Any) -> None:
    _require_exact_object(
        value,
        {"seat", "zone", "slot", "card_uid", "card_serial", "damage", "status"},
        "replay_frame_invalid",
    )
    if type(value["seat"]) is not int or value["seat"] not in {0, 1}:
        raise CspContractError("replay_frame_invalid")
    if value["zone"] not in {"active", "bench", "stadium", "discard", "lost_zone"}:
        raise CspContractError("replay_frame_invalid")
    _non_negative_int(value["slot"], "replay_frame_invalid")
    if value["card_uid"] is not None:
        _require_identifier(value["card_uid"])
    if value["card_serial"] is not None:
        _positive_int(value["card_serial"], "replay_frame_invalid")
    _non_negative_int(value["damage"], "replay_frame_invalid")
    if type(value["status"]) is not list or len(value["status"]) > 32:
        raise CspContractError("replay_frame_invalid")
    for status in value["status"]:
        _require_identifier(status)


def _validate_public_card_entry(value: Any) -> None:
    _require_exact_object(
        value,
        {"seat", "zone", "card_uid", "card_serial"},
        "replay_frame_invalid",
    )
    if type(value["seat"]) is not int or value["seat"] not in {0, 1}:
        raise CspContractError("replay_frame_invalid")
    if value["zone"] not in {"active", "bench", "stadium", "discard", "lost_zone", "revealed"}:
        raise CspContractError("replay_frame_invalid")
    _require_identifier(value["card_uid"])
    if value["card_serial"] is not None:
        _positive_int(value["card_serial"], "replay_frame_invalid")


def _validate_verification(value: Any) -> None:
    _require_exact_object(value, {"evaluator_id", "key_id", "signature"}, "official_verification_required")
    _require_identifier(value["evaluator_id"])
    _require_identifier(value["key_id"])
    if type(value["signature"]) is not str or not 1 <= len(value["signature"]) <= 1024:
        raise CspContractError("official_verification_required")


def _validate_fault_counts(value: Any) -> None:
    _require_exact_object(value, set(_FAULT_KEYS), "result_counts_invalid")
    for count in value.values():
        _non_negative_int(count, "result_counts_invalid")


def _validate_seat_breakdown(value: Any, counts: dict[str, int]) -> None:
    if type(value) is not list or len(value) != 2:
        raise CspContractError("summary_counts_invalid")
    seats: list[int] = []
    totals = {"wins": 0, "losses": 0, "draws": 0}
    for row in value:
        _require_exact_object(row, {"seat", "wins", "losses", "draws"}, "summary_counts_invalid")
        if type(row["seat"]) is not int or row["seat"] not in {0, 1}:
            raise CspContractError("summary_counts_invalid")
        seats.append(row["seat"])
        for key in totals:
            totals[key] += _non_negative_int(row[key], "summary_counts_invalid")
    if sorted(seats) != [0, 1] or any(totals[key] != counts[key] for key in totals):
        raise CspContractError("summary_counts_invalid")


def _validate_profile(value: Any) -> None:
    _require_exact_object(
        value,
        {
            "document_type",
            "schema_version",
            "profile_id",
            "hash_domains",
            "allowed_platforms",
            "release_states",
            "revocation_states",
            "evaluation_visibility",
            "match_lanes",
            "result_lanes",
            "seed_capabilities",
            "replay_visibility_profiles",
            "limits",
            "retention",
        },
        "contract_profile_invalid",
    )
    if (
        value["document_type"] != "competitive_strategy_platform_profile_v1"
        or type(value["schema_version"]) is not int
        or value["schema_version"] != 1
        or value["profile_id"] != PROFILE_ID
    ):
        raise CspContractError("contract_profile_invalid")
    _require_exact_object(
        value["hash_domains"],
        {"document", "replay_frame_prefix_utf8_hex"},
        "contract_profile_invalid",
    )
    if (
        value["hash_domains"]["document"] != "canonical_json_v1_sha256"
        or value["hash_domains"]["replay_frame_prefix_utf8_hex"]
        != FRAME_HASH_DOMAIN.hex().upper()
    ):
        raise CspContractError("contract_profile_invalid")
    list_fields = (
        "allowed_platforms",
        "release_states",
        "revocation_states",
        "evaluation_visibility",
        "match_lanes",
        "result_lanes",
        "seed_capabilities",
        "replay_visibility_profiles",
    )
    for key in list_fields:
        if type(value[key]) is not list or not value[key] or len(set(value[key])) != len(value[key]):
            raise CspContractError("contract_profile_invalid")
        for item in value[key]:
            _require_identifier(item)
    _require_exact_object(
        value["limits"],
        {
            "max_document_bytes",
            "max_replay_frames",
            "max_public_board_entries",
            "max_public_card_entries",
            "max_platforms",
            "max_opponents",
        },
        "contract_profile_invalid",
    )
    for limit in value["limits"].values():
        _positive_int(limit, "contract_profile_invalid")
    _require_exact_object(
        value["retention"],
        {"developer_local", "community_challenge", "official_verified", "rejected_or_dirty"},
        "contract_profile_invalid",
    )
    for lane, rule in value["retention"].items():
        _require_exact_object(
            rule,
            {"platform_upload_allowed", "public_replay_days", "metadata_policy"},
            "contract_profile_invalid",
        )
        if type(rule["platform_upload_allowed"]) is not bool:
            raise CspContractError("contract_profile_invalid")
        _non_negative_int(rule["public_replay_days"], "contract_profile_invalid")
        _require_identifier(rule["metadata_policy"])
        if lane == "developer_local" and (rule["platform_upload_allowed"] or rule["public_replay_days"] != 0):
            raise CspContractError("contract_profile_invalid")


def _validate_threat_model(value: Any) -> None:
    _require_exact_object(
        value,
        {
            "document_type",
            "schema_version",
            "threat_model_id",
            "protected_assets",
            "forbidden_public_keys",
            "trust_boundaries",
            "required_controls",
            "explicit_non_authorities",
        },
        "threat_model_invalid",
    )
    if (
        value["document_type"] != "competitive_strategy_platform_threat_model_v1"
        or type(value["schema_version"]) is not int
        or value["schema_version"] != 1
        or value["threat_model_id"] != "csp-wp0-threat-model-v1"
        or set(value["forbidden_public_keys"]) != set(_FORBIDDEN_PUBLIC_KEYS)
    ):
        raise CspContractError("threat_model_invalid")
    for key in (
        "protected_assets",
        "forbidden_public_keys",
        "trust_boundaries",
        "required_controls",
        "explicit_non_authorities",
    ):
        if type(value[key]) is not list or not value[key] or len(set(value[key])) != len(value[key]):
            raise CspContractError("threat_model_invalid")
        for item in value[key]:
            _require_identifier(item)


def _validate_vectors_shape(value: Any) -> None:
    _require_exact_object(
        value,
        {"document_type", "schema_version", "profile_id", "fixtures", "success_cases", "rejection_cases"},
        "vectors_invalid",
    )
    if (
        value["document_type"] != "competitive_strategy_platform_conformance_vectors_v1"
        or type(value["schema_version"]) is not int
        or value["schema_version"] != 1
        or value["profile_id"] != PROFILE_ID
        or type(value["fixtures"]) is not dict
        or type(value["success_cases"]) is not list
        or type(value["rejection_cases"]) is not list
        or len(value["success_cases"]) < 8
        or len(value["rejection_cases"]) < 16
    ):
        raise CspContractError("vectors_invalid")
    ids: set[str] = set()
    for case in value["success_cases"] + value["rejection_cases"]:
        if type(case) is not dict or type(case.get("id")) is not str or case["id"] in ids:
            raise CspContractError("vectors_invalid")
        ids.add(case["id"])


def _reject_forbidden_public_keys(
    value: Any,
    *,
    _active: set[int] | None = None,
    _state: list[int] | None = None,
    _depth: int = 0,
) -> None:
    if _depth > 128:
        raise CspContractError("document_invalid")
    active = set() if _active is None else _active
    state = [0] if _state is None else _state
    state[0] += 1
    if state[0] > 200_000:
        raise CspContractError("document_invalid")
    if type(value) is dict:
        identity = id(value)
        if identity in active:
            raise CspContractError("document_invalid")
        active.add(identity)
        try:
            for key, child in value.items():
                if type(key) is not str:
                    raise CspContractError("document_invalid")
                if key.lower() in _FORBIDDEN_PUBLIC_KEYS:
                    raise CspContractError("private_field_forbidden")
                _reject_forbidden_public_keys(
                    child,
                    _active=active,
                    _state=state,
                    _depth=_depth + 1,
                )
        finally:
            active.remove(identity)
    elif type(value) is list:
        identity = id(value)
        if identity in active:
            raise CspContractError("document_invalid")
        active.add(identity)
        try:
            for child in value:
                _reject_forbidden_public_keys(
                    child,
                    _active=active,
                    _state=state,
                    _depth=_depth + 1,
                )
        finally:
            active.remove(identity)


def _require_hash_fields(value: dict[str, Any]) -> None:
    for key, child in value.items():
        if key in _HASH_FIELDS and child is not None and not _is_sha256(child):
            raise CspContractError("hash_invalid")
        if type(child) is dict:
            _require_hash_fields(child)


def _optional_hash(value: Any, code: str) -> None:
    if value is not None and not _is_sha256(value):
        raise CspContractError(code)


def _is_sha256(value: Any) -> bool:
    return (
        type(value) is str
        and len(value) == 64
        and all(character in "0123456789ABCDEF" for character in value)
    )


def _require_identifier(value: Any) -> str:
    if (
        type(value) is not str
        or not 1 <= len(value) <= 128
        or value != value.strip()
        or any(ord(character) < 0x20 for character in value)
    ):
        raise CspContractError("identifier_invalid")
    return value


def _require_version(value: Any) -> str:
    text = _require_identifier(value)
    parts = text.split(".")
    if len(parts) != 3 or any(not part.isdigit() for part in parts):
        raise CspContractError("version_invalid")
    return text


def _require_timestamp(value: Any) -> None:
    text = _require_identifier(value)
    if (
        len(text) != 20
        or text[4] != "-"
        or text[7] != "-"
        or text[10] != "T"
        or text[13] != ":"
        or text[16] != ":"
        or text[-1] != "Z"
        or not (text[0:4] + text[5:7] + text[8:10] + text[11:13] + text[14:16] + text[17:19]).isdigit()
    ):
        raise CspContractError("timestamp_invalid")


def _positive_int(value: Any, code: str) -> int:
    if type(value) is not int or value <= 0:
        raise CspContractError(code)
    return value


def _non_negative_int(value: Any, code: str) -> int:
    if type(value) is not int or value < 0:
        raise CspContractError(code)
    return value


def _require_exact_object(value: Any, keys: set[str] | frozenset[str], code: str) -> dict[str, Any]:
    if type(value) is not dict or set(value) != set(keys):
        raise CspContractError(code)
    return value


def _canonical_sha(value: Any) -> str:
    return _sha_bytes(canonical_json_v1_bytes(value))


def _sha_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _load_bounded_json(path: Path) -> dict[str, Any]:
    if not path.is_file() or path.is_symlink() or path.stat().st_size > MAX_CONTRACT_FILE_BYTES:
        raise CspContractError("contract_artifact_invalid")
    value = load_json_strict(path)
    if type(value) is not dict:
        raise CspContractError("contract_artifact_invalid")
    return value


def _resolve_beneath(root: Path, relative: Path) -> Path:
    if relative.is_absolute() or ".." in relative.parts:
        raise CspContractError("contract_path_invalid")
    candidate = (root / relative).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise CspContractError("contract_path_invalid") from exc
    return candidate


def _apply_mutation(value: Any, mutation: Any) -> Any:
    if type(mutation) is not dict or set(mutation) not in (
        {"op", "path", "value"},
        {"op", "path"},
    ):
        raise CspContractError("vector_invalid")
    path = mutation["path"]
    if type(path) is not list or not path:
        raise CspContractError("vector_invalid")
    parent = value
    for part in path[:-1]:
        if type(parent) is dict and type(part) is str and part in parent:
            parent = parent[part]
        elif type(parent) is list and type(part) is int and 0 <= part < len(parent):
            parent = parent[part]
        else:
            raise CspContractError("vector_invalid")
    final = path[-1]
    operation = mutation["op"]
    if operation == "set":
        if type(parent) is dict and type(final) is str:
            parent[final] = copy.deepcopy(mutation["value"])
        elif type(parent) is list and type(final) is int and 0 <= final < len(parent):
            parent[final] = copy.deepcopy(mutation["value"])
        else:
            raise CspContractError("vector_invalid")
    elif operation == "delete":
        if type(parent) is dict and type(final) is str and final in parent:
            del parent[final]
        elif type(parent) is list and type(final) is int and 0 <= final < len(parent):
            del parent[final]
        else:
            raise CspContractError("vector_invalid")
    elif operation == "append":
        if type(parent) is not dict or type(final) is not str or final not in parent:
            raise CspContractError("vector_invalid")
        target = parent[final]
        if type(target) is not list:
            raise CspContractError("vector_invalid")
        target.append(copy.deepcopy(mutation["value"]))
    elif operation == "reverse":
        if type(parent) is not dict or type(final) is not str or final not in parent:
            raise CspContractError("vector_invalid")
        target = parent[final]
        if type(target) is not list:
            raise CspContractError("vector_invalid")
        target.reverse()
    else:
        raise CspContractError("vector_invalid")
    return value


__all__ = [
    "BUNDLE_ID",
    "CspContractError",
    "CspContractOwner",
    "CspContractSet",
    "EXPECTED_BUNDLE_CANONICAL_SHA256",
    "FRAME_HASH_DOMAIN",
    "PROFILE_ID",
    "ReplayValidation",
    "ValidatedCspDocument",
    "frame_hash",
]
