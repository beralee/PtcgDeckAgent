from __future__ import annotations

from dataclasses import dataclass
import copy
import hashlib
import math
from pathlib import Path
from typing import Any, Final, Mapping

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
    Ed25519PublicKey,
)

from .competitive_strategy_platform import (
    CspContractError,
    CspContractOwner,
    CspContractSet,
    frame_hash,
)
from .source_lock import canonical_json_v1_bytes, load_json_strict


PROFILE_PATH: Final = Path("contracts/ptcgdap/competitive_strategy_evaluator_profile.json")
VECTORS_PATH: Final = Path("contracts/ptcgdap/competitive_strategy_evaluator_conformance_vectors.json")
BUNDLE_PATH: Final = Path("contracts/ptcgdap/competitive_strategy_evaluator_bundle.json")
BUNDLE_ID: Final = "ptcgdap-competitive-strategy-evaluator-csp-wp2-v1"
PROFILE_ID: Final = "ptcgdap-csp-wp2-shadow-profile-v1"
EXPECTED_BUNDLE_CANONICAL_SHA256: Final = "E3D4807BD7D902C4701C243D6DD6E9518C95B11B9752C0EA03E75D1E380AAD49"
EVIDENCE_DOMAIN: Final = b"PTCGDAP\0CSP_EVALUATOR_EVIDENCE_V1\0"
RESULT_DOMAIN: Final = b"PTCGDAP\0CSP_EVALUATOR_RESULT_V1\0"
MAX_SAFE_INTEGER: Final = 9_007_199_254_740_991
FAULT_KEYS: Final = (
    "invalid_output",
    "policy_error",
    "timeout",
    "engine_rejection",
    "fallback",
)
FORCED_LOSS_FAULTS: Final = ("invalid_output", "policy_error", "timeout")
DIRTY_FAULTS: Final = ("engine_rejection", "fallback")
PROFILE_KEYS: Final = frozenset(
    {
        "document_type",
        "schema_version",
        "profile_id",
        "authority_mode",
        "production_authority",
        "grants",
        "evaluator",
        "candidate_release",
        "evaluation_profile",
        "runtime_report_contract",
        "fault_policy",
        "aggregation_contract",
        "materializer_build_sha256",
    }
)
EVIDENCE_KEYS: Final = frozenset(
    {
        "document_type",
        "schema_version",
        "evaluation_profile_sha256",
        "match_envelope",
        "replay_manifest",
        "runtime_report",
        "evidence_verification",
    }
)
RUNTIME_REPORT_KEYS: Final = frozenset(
    {
        "source",
        "terminal",
        "reported_outcome",
        "winner_seat",
        "turn_count",
        "decision_count",
        "fault_counts",
        "runtime_dirty_reasons",
        "replay_contract_accepted",
    }
)
RECORD_KEYS: Final = frozenset({"evidence", "result"})


class CspEvaluatorError(ValueError):
    pass


def _fail(code: str) -> None:
    raise CspEvaluatorError(code)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _canonical_sha(value: object) -> str:
    return _sha256(canonical_json_v1_bytes(value))


def _signed_bytes(domain: bytes, value: object) -> bytes:
    return domain + canonical_json_v1_bytes(value)


def _is_sha256(value: object) -> bool:
    return (
        type(value) is str
        and len(value) == 64
        and all(character in "0123456789ABCDEF" for character in value)
    )


def _is_nonnegative_int(value: object) -> bool:
    return type(value) is int and 0 <= value <= MAX_SAFE_INTEGER


def _is_identifier(value: object) -> bool:
    return (
        type(value) is str
        and 1 <= len(value) <= 160
        and all(character.isalnum() or character in "._:-" for character in value)
    )


def _deepcopy(value: object) -> Any:
    return copy.deepcopy(value)


def _load_exact_bundle(root: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    bundle = load_json_strict(root / BUNDLE_PATH)
    if _canonical_sha(bundle) != EXPECTED_BUNDLE_CANONICAL_SHA256:
        _fail("evaluator_bundle_trust_anchor_mismatch")
    if set(bundle) != {
        "document_type",
        "schema_version",
        "bundle_id",
        "digest_mode",
        "artifact_set_policy",
        "artifacts",
    }:
        _fail("evaluator_bundle_invalid")
    if (
        bundle["document_type"] != "competitive_strategy_evaluator_bundle_v1"
        or bundle["schema_version"] != 1
        or bundle["bundle_id"] != BUNDLE_ID
        or bundle["digest_mode"] != "canonical_json_v1"
        or bundle["artifact_set_policy"] != "exact_ids_paths_hashes_no_duplicates"
    ):
        _fail("evaluator_bundle_invalid")
    expected = (("profile", PROFILE_PATH), ("vectors", VECTORS_PATH))
    if type(bundle["artifacts"]) is not list or len(bundle["artifacts"]) != len(expected):
        _fail("evaluator_bundle_invalid")
    loaded: dict[str, Any] = {}
    for entry, (artifact_id, path) in zip(bundle["artifacts"], expected, strict=True):
        if type(entry) is not dict or set(entry) != {"artifact_id", "path", "canonical_sha256"}:
            _fail("evaluator_bundle_invalid")
        if (
            entry["artifact_id"] != artifact_id
            or entry["path"] != path.as_posix()
            or not _is_sha256(entry["canonical_sha256"])
        ):
            _fail("evaluator_bundle_invalid")
        value = load_json_strict(root / path)
        if _canonical_sha(value) != entry["canonical_sha256"]:
            _fail("evaluator_artifact_hash_mismatch")
        loaded[artifact_id] = value
    return loaded["profile"], loaded["vectors"]


@dataclass(frozen=True)
class CspEvaluatorOwner:
    root: Path
    profile: dict[str, Any]
    vectors: dict[str, Any]
    contracts: CspContractOwner

    @classmethod
    def load_trusted(cls, root: Path | str) -> "CspEvaluatorOwner":
        resolved = Path(root).resolve()
        profile, vectors = _load_exact_bundle(resolved)
        owner = cls.from_documents(resolved, profile, vectors)
        owner._verify_vectors_shape()
        return owner

    @classmethod
    def from_documents(
        cls,
        root: Path | str,
        profile: Mapping[str, Any],
        vectors: Mapping[str, Any] | None = None,
    ) -> "CspEvaluatorOwner":
        resolved = Path(root).resolve()
        owner = cls(
            root=resolved,
            profile=_deepcopy(dict(profile)),
            vectors=_deepcopy(dict(vectors or {})),
            contracts=CspContractOwner(CspContractSet.load_trusted(resolved)),
        )
        owner._validate_profile()
        return owner

    def audit_snapshot(self) -> dict[str, Any]:
        evaluator = self.profile["evaluator"]
        return {
            "profile_id": self.profile["profile_id"],
            "authority_mode": self.profile["authority_mode"],
            "evaluator_id": evaluator["evaluator_id"],
            "key_id": evaluator["key_id"],
            "production_authority": self.profile["production_authority"],
            "authoritative": False,
            "grants": _deepcopy(self.profile["grants"]),
            "bundle_canonical_sha256": EXPECTED_BUNDLE_CANONICAL_SHA256,
        }

    def fault_keys(self) -> tuple[str, ...]:
        return FAULT_KEYS

    def conformance_vectors(self) -> dict[str, Any]:
        return _deepcopy(self.vectors)

    def confidence_interval_audit(self, wins: int, valid: int) -> dict[str, int]:
        if (
            type(wins) is not int
            or type(valid) is not int
            or wins < 0
            or valid < 0
            or wins > valid
            or valid > 100_000
        ):
            _fail("aggregation_input_invalid")
        return self._confidence_interval(wins, valid)

    def issue_record(
        self,
        evidence: Mapping[str, Any],
        private_key: bytes,
        replay_frames: list[Mapping[str, Any]] | None = None,
    ) -> dict[str, Any]:
        unsigned = _deepcopy(dict(evidence))
        if unsigned.get("evidence_verification") is not None:
            _fail("evidence_already_signed")
        self._validate_evidence_identity(unsigned)
        self._validate_runtime_report(unsigned["runtime_report"])
        if type(replay_frames) is not list or not replay_frames:
            _fail("replay_frames_required")
        try:
            self.contracts.validate_replay(unsigned["replay_manifest"], replay_frames)
        except CspContractError as error:
            _fail(str(error))
        key = self._validated_private_key(private_key)
        evidence_payload = _deepcopy(unsigned)
        evidence_payload.pop("evidence_verification")
        evidence_signature = key.sign(_signed_bytes(EVIDENCE_DOMAIN, evidence_payload)).hex().upper()
        signed_evidence = _deepcopy(unsigned)
        signed_evidence["evidence_verification"] = self._verification(evidence_signature)
        result = self._derive_result(signed_evidence)
        if not result["dirty"]:
            result_payload = _deepcopy(result)
            result_payload.pop("verification")
            signature = key.sign(_signed_bytes(RESULT_DOMAIN, result_payload)).hex().upper()
            result["verification"] = self._verification(signature)
        record = {"evidence": signed_evidence, "result": result}
        self.verify_record(record)
        return record

    def verify_record(self, record: Mapping[str, Any]) -> dict[str, Any]:
        if not isinstance(record, Mapping) or set(record) != RECORD_KEYS:
            _fail("evaluation_record_invalid")
        evidence = _deepcopy(record["evidence"])
        result = _deepcopy(record["result"])
        self._validate_evidence_identity(evidence)
        self._validate_runtime_report(evidence["runtime_report"])
        verification = evidence.get("evidence_verification")
        self._verify_signature_shape(verification, "evidence_verification_invalid")
        evidence_payload = _deepcopy(evidence)
        evidence_payload.pop("evidence_verification")
        self._verify_signature(
            EVIDENCE_DOMAIN,
            evidence_payload,
            verification["signature"],
            "evidence_signature_invalid",
        )
        expected_result = self._derive_result(evidence)
        if not isinstance(result, dict):
            _fail("evaluation_result_invalid")
        expected_without_verification = _deepcopy(expected_result)
        expected_without_verification.pop("verification")
        actual_without_verification = _deepcopy(result)
        actual_verification = actual_without_verification.pop("verification", "missing")
        if actual_without_verification != expected_without_verification:
            _fail("evaluation_result_mismatch")
        if expected_result["dirty"]:
            if actual_verification is not None:
                _fail("dirty_result_must_be_unsigned")
        else:
            self._verify_signature_shape(actual_verification, "result_verification_invalid")
            self._verify_signature(
                RESULT_DOMAIN,
                actual_without_verification,
                actual_verification["signature"],
                "result_signature_invalid",
            )
        self._validate_contract(result)
        return {
            "accepted": True,
            "error_code": "",
            "official": not result["dirty"],
            "dirty": result["dirty"],
            "match_id": result["match_id"],
            "grants": [],
        }

    def materialize(self, records: list[Mapping[str, Any]]) -> dict[str, Any]:
        if type(records) is not list or not records:
            _fail("evaluation_inputs_empty")
        if len(records) > 100_000:
            _fail("evaluation_inputs_too_large")
        verified: list[dict[str, Any]] = []
        match_ids: set[str] = set()
        for record in records:
            self.verify_record(record)
            copied = _deepcopy(record)
            match_id = copied["result"]["match_id"]
            if match_id in match_ids:
                _fail("duplicate_match_id")
            match_ids.add(match_id)
            verified.append(copied)
        verified.sort(key=lambda item: item["result"]["match_id"])
        summary = self._aggregate(verified)
        self._validate_contract(summary)
        return summary

    def _validate_profile(self) -> None:
        value = self.profile
        if set(value) != PROFILE_KEYS:
            _fail("evaluator_profile_invalid")
        if (
            value["document_type"] != "competitive_strategy_evaluator_profile_v1"
            or value["schema_version"] != 1
            or value["profile_id"] != PROFILE_ID
            or value["authority_mode"] != "shadow_test_only"
            or value["production_authority"] is not False
            or value["grants"] != []
        ):
            _fail("evaluator_profile_invalid")
        evaluator = value["evaluator"]
        if not isinstance(evaluator, dict) or set(evaluator) != {
            "evaluator_id",
            "key_id",
            "algorithm",
            "public_key_hex",
        }:
            _fail("evaluator_profile_invalid")
        if (
            evaluator["evaluator_id"] != "ptcgdap-csp-wp2-shadow-evaluator"
            or evaluator["key_id"] != "csp-wp2-rfc8032-fixture-key"
            or evaluator["algorithm"] != "ed25519"
            or evaluator["public_key_hex"]
            != "D75A980182B10AB7D54BFED3C964073A0EE172F3DAA62325AF021A68F707511A"
        ):
            _fail("evaluator_profile_invalid")
        self._validate_contract(value["candidate_release"])
        self._validate_contract(value["evaluation_profile"])
        evaluation_profile = value["evaluation_profile"]
        if (
            evaluation_profile["evaluator_id"] != evaluator["evaluator_id"]
            or evaluation_profile["seat_policy"] != "paired_swap"
            or evaluation_profile["seed_policy"]
            != {"capability": "paired_seed_commitment_v1", "disclosure": "commitment_only"}
            or evaluation_profile["outcome_policy"]
            != {
                "draws_allowed": True,
                "invalid_output": "verified_loss_and_fault",
                "policy_error": "verified_loss_and_fault",
                "timeout": "verified_loss_and_fault",
                "dirty": "exclude_from_rank_show_separately",
            }
        ):
            _fail("evaluator_profile_invalid")
        if value["runtime_report_contract"] != {
            "source": "official_evaluator_runtime",
            "terminal_required": True,
            "replay_contract_acceptance_required": True,
            "historical_import_allowed": False,
            "client_self_report_allowed": False,
        }:
            _fail("evaluator_profile_invalid")
        if value["fault_policy"] != {
            "forced_loss_faults": list(FORCED_LOSS_FAULTS),
            "dirty_exclusion_faults": list(DIRTY_FAULTS),
            "runtime_dirty_reasons_excluded": True,
            "faults_visible_in_summary": True,
        }:
            _fail("evaluator_profile_invalid")
        aggregation = value["aggregation_contract"]
        if aggregation != {
            "version": "win_rate_ci_integer_v1",
            "point_estimate": "wins_divided_by_valid",
            "draw_value": "zero_wins",
            "confidence_interval": "wilson_95_integer_fixed_point",
            "below_minimum_interval": "zero_to_ten_thousand",
        }:
            _fail("evaluator_profile_invalid")
        if not _is_sha256(value["materializer_build_sha256"]):
            _fail("evaluator_profile_invalid")

    def _verify_vectors_shape(self) -> None:
        if not isinstance(self.vectors, dict) or set(self.vectors) != {
            "document_type",
            "schema_version",
            "profile_id",
            "records",
            "expected_summary",
            "rejection_cases",
            "confidence_interval_cases",
        }:
            _fail("evaluator_vectors_invalid")
        if (
            self.vectors["document_type"]
            != "competitive_strategy_evaluator_conformance_vectors_v1"
            or self.vectors["schema_version"] != 1
            or self.vectors["profile_id"] != PROFILE_ID
            or type(self.vectors["records"]) is not list
            or len(self.vectors["records"]) != 5
            or type(self.vectors["rejection_cases"]) is not list
            or type(self.vectors["confidence_interval_cases"]) is not list
        ):
            _fail("evaluator_vectors_invalid")

    def _validate_evidence_identity(self, evidence: object) -> None:
        if not isinstance(evidence, dict) or set(evidence) != EVIDENCE_KEYS:
            _fail("evaluation_evidence_invalid")
        if evidence["document_type"] != "evaluator_evidence_v1" or evidence["schema_version"] != 1:
            _fail("evaluation_evidence_invalid")
        profile_hash = _canonical_sha(self.profile["evaluation_profile"])
        if evidence["evaluation_profile_sha256"] != profile_hash:
            _fail("evaluation_profile_mismatch")
        envelope = evidence["match_envelope"]
        replay = evidence["replay_manifest"]
        self._validate_contract(envelope)
        self._validate_contract(replay)
        expected_profile = self.profile["evaluation_profile"]
        if envelope["lane"] != "official_evaluation":
            _fail("match_lane_invalid")
        if (
            envelope["evaluator_id"] != expected_profile["evaluator_id"]
            or envelope["evaluation_profile_id"] != expected_profile["profile_id"]
            or envelope["evaluation_profile_sha256"] != profile_hash
            or envelope["engine_sha256"] != expected_profile["engine_sha256"]
            or envelope["rules_sha256"] != expected_profile["rules_sha256"]
            or envelope["card_catalog_sha256"] != expected_profile["card_catalog_sha256"]
            or envelope["host_contract_sha256"] != expected_profile["host_contract_sha256"]
        ):
            _fail("match_profile_mismatch")
        if envelope["participants"][0] != self._release_participant():
            _fail("strategy_release_mismatch")
        if envelope["participants"][1] != expected_profile["opponents"][0]:
            _fail("opponent_mismatch")
        if replay["match_id"] != envelope["match_id"]:
            _fail("replay_match_mismatch")
        if replay["complete"] is not True:
            _fail("replay_incomplete")
        if replay["match_envelope_sha256"] != _canonical_sha(envelope):
            _fail("replay_envelope_mismatch")

    def _validate_runtime_report(self, report: object) -> None:
        if not isinstance(report, dict) or set(report) != RUNTIME_REPORT_KEYS:
            _fail("runtime_report_invalid")
        if report["source"] != "official_evaluator_runtime":
            _fail("evaluation_source_invalid")
        if type(report["terminal"]) is not bool or report["terminal"] is not True:
            _fail("evaluation_nonterminal")
        if report["replay_contract_accepted"] is not True:
            _fail("replay_contract_not_accepted")
        self._validate_outcome(report["reported_outcome"], report["winner_seat"])
        if not _is_nonnegative_int(report["turn_count"]) or not _is_nonnegative_int(report["decision_count"]):
            _fail("runtime_report_invalid")
        faults = report["fault_counts"]
        if not isinstance(faults, dict) or tuple(faults) != FAULT_KEYS:
            _fail("fault_counts_invalid")
        if any(not _is_nonnegative_int(faults[key]) for key in FAULT_KEYS):
            _fail("fault_counts_invalid")
        reasons = report["runtime_dirty_reasons"]
        if (
            type(reasons) is not list
            or reasons != sorted(set(reasons))
            or any(not _is_identifier(reason) for reason in reasons)
        ):
            _fail("dirty_reasons_invalid")

    def _derive_result(self, evidence: dict[str, Any]) -> dict[str, Any]:
        envelope = evidence["match_envelope"]
        replay = evidence["replay_manifest"]
        report = evidence["runtime_report"]
        target_seat = int(envelope["seat_assignment"][0])
        faults = _deepcopy(report["fault_counts"])
        outcome = report["reported_outcome"]
        winner = report["winner_seat"]
        if any(faults[key] > 0 for key in FORCED_LOSS_FAULTS):
            winner = 1 - target_seat
            outcome = "seat_0_win" if winner == 0 else "seat_1_win"
        dirty_reasons = list(report["runtime_dirty_reasons"])
        for key in DIRTY_FAULTS:
            if faults[key] > 0:
                dirty_reasons.append("fault_%s" % key)
        dirty_reasons = sorted(set(dirty_reasons))
        dirty = bool(dirty_reasons)
        result = {
            "document_type": "verified_match_result_v1",
            "schema_version": 1,
            "match_id": envelope["match_id"],
            "match_envelope_sha256": _canonical_sha(envelope),
            "trust_lane": "rejected_or_dirty" if dirty else "official_verified",
            "outcome": outcome,
            "winner_seat": winner,
            "turn_count": report["turn_count"],
            "decision_count": report["decision_count"],
            "fault_counts": faults,
            "dirty": dirty,
            "dirty_reasons": dirty_reasons,
            "replay_manifest_sha256": _canonical_sha(replay),
            "evidence_sha256": _canonical_sha(evidence),
            "verification": None,
        }
        return result

    def _aggregate(self, records: list[dict[str, Any]]) -> dict[str, Any]:
        counts = {"wins": 0, "losses": 0, "draws": 0, "valid": 0, "dirty": 0}
        faults = {key: 0 for key in FAULT_KEYS}
        seats = {
            0: {"seat": 0, "wins": 0, "losses": 0, "draws": 0},
            1: {"seat": 1, "wins": 0, "losses": 0, "draws": 0},
        }
        opponent_id = self.profile["evaluation_profile"]["opponents"][0]["baseline_id"]
        matchup = {"opponent_id": opponent_id, "wins": 0, "losses": 0, "draws": 0}
        for record in records:
            result = record["result"]
            for key in FAULT_KEYS:
                faults[key] += result["fault_counts"][key]
            if result["dirty"]:
                counts["dirty"] += 1
                continue
            counts["valid"] += 1
            target_seat = int(record["evidence"]["match_envelope"]["seat_assignment"][0])
            if result["outcome"] == "draw":
                kind = "draws"
            elif result["winner_seat"] == target_seat:
                kind = "wins"
            else:
                kind = "losses"
            counts[kind] += 1
            seats[target_seat][kind] += 1
            matchup[kind] += 1
        valid = counts["valid"]
        rate = counts["wins"] * 10_000 // valid if valid else 0
        interval = self._confidence_interval(counts["wins"], valid)
        release = self.profile["candidate_release"]
        profile = self.profile["evaluation_profile"]
        return {
            "document_type": "evaluation_summary_v1",
            "schema_version": 1,
            "strategy_release": {
                "strategy_id": release["strategy_id"],
                "release_version": release["release_version"],
                "archive_sha256": release["archive_sha256"],
            },
            "evaluation_profile_id": profile["profile_id"],
            "evaluation_profile_sha256": _canonical_sha(profile),
            "aggregation_version": "win_rate_ci_integer_v1",
            "input_match_ids": [record["result"]["match_id"] for record in records],
            "counts": counts,
            "fault_counts": faults,
            "win_rate_basis_points": rate,
            "confidence_interval_basis_points": interval,
            "seat_breakdown": [seats[0], seats[1]],
            "matchup_breakdown": [matchup],
            "materializer_build_sha256": self.profile["materializer_build_sha256"],
        }

    def _confidence_interval(self, wins: int, valid: int) -> dict[str, int]:
        minimum = self.profile["evaluation_profile"]["aggregation"]["minimum_publish_games"]
        if valid < minimum:
            return {"low": 0, "high": 10_000}
        scale = 10_000
        z = 19_600
        z_squared = z * z
        radicand = z_squared + (4 * wins * (valid - wins) * scale * scale) // valid
        root = math.isqrt(radicand)
        center = 2 * wins * scale * scale + z_squared
        spread = z * root
        denominator = 2 * (valid * scale * scale + z_squared)
        low_numerator = max(0, center - spread)
        high_numerator = min(denominator, center + spread)
        return {
            "low": (low_numerator * 10_000) // denominator,
            "high": min(10_000, (high_numerator * 10_000 + denominator - 1) // denominator),
        }

    def _validated_private_key(self, private_key: bytes) -> Ed25519PrivateKey:
        if type(private_key) is not bytes or len(private_key) != 32:
            _fail("evaluator_private_key_mismatch")
        try:
            key = Ed25519PrivateKey.from_private_bytes(private_key)
        except ValueError:
            _fail("evaluator_private_key_mismatch")
        public = key.public_key().public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )
        if public.hex().upper() != self.profile["evaluator"]["public_key_hex"]:
            _fail("evaluator_private_key_mismatch")
        return key

    def _verification(self, signature: str) -> dict[str, str]:
        evaluator = self.profile["evaluator"]
        return {
            "evaluator_id": evaluator["evaluator_id"],
            "key_id": evaluator["key_id"],
            "signature": signature,
        }

    def _verify_signature_shape(self, verification: object, code: str) -> None:
        if (
            not isinstance(verification, dict)
            or set(verification) != {"evaluator_id", "key_id", "signature"}
            or verification["evaluator_id"] != self.profile["evaluator"]["evaluator_id"]
            or verification["key_id"] != self.profile["evaluator"]["key_id"]
            or type(verification["signature"]) is not str
            or len(verification["signature"]) != 128
        ):
            _fail(code)

    def _verify_signature(self, domain: bytes, value: object, signature_hex: str, code: str) -> None:
        try:
            signature = bytes.fromhex(signature_hex)
            public = bytes.fromhex(self.profile["evaluator"]["public_key_hex"])
            Ed25519PublicKey.from_public_bytes(public).verify(
                signature,
                _signed_bytes(domain, value),
            )
        except (ValueError, InvalidSignature):
            _fail(code)

    def _validate_contract(self, document: object) -> None:
        try:
            self.contracts.validate_document(document)
        except CspContractError as error:
            _fail(str(error))

    def _release_participant(self) -> dict[str, Any]:
        release = self.profile["candidate_release"]
        participant = {
            key: _deepcopy(release[key])
            for key in (
                "strategy_id",
                "release_version",
                "package_id",
                "archive_sha256",
                "manifest_canonical_sha256",
                "deck_identity",
                "policy_package_sha256",
            )
        }
        return {"participant_kind": "strategy_release", **participant}

    @staticmethod
    def _validate_outcome(outcome: object, winner: object) -> None:
        if outcome == "seat_0_win" and winner == 0:
            return
        if outcome == "seat_1_win" and winner == 1:
            return
        if outcome == "draw" and winner is None:
            return
        _fail("result_outcome_invalid")


def build_replay_fixture(
    owner: CspEvaluatorOwner,
    match_id: str,
    target_seat: int,
    *,
    lane: str = "official_evaluation",
) -> dict[str, Any]:
    if not _is_identifier(match_id) or target_seat not in (0, 1):
        _fail("fixture_input_invalid")
    profile = owner.profile["evaluation_profile"]
    envelope = {
        "document_type": "match_envelope_v1",
        "schema_version": 1,
        "match_id": match_id,
        "lane": lane,
        "evaluator_id": profile["evaluator_id"],
        "participants": [owner._release_participant(), _deepcopy(profile["opponents"][0])],
        "engine_sha256": profile["engine_sha256"],
        "rules_sha256": profile["rules_sha256"],
        "card_catalog_sha256": profile["card_catalog_sha256"],
        "host_contract_sha256": profile["host_contract_sha256"],
        "runtime_manifest_sha256": "9" * 64,
        "evaluation_profile_id": profile["profile_id"],
        "evaluation_profile_sha256": _canonical_sha(profile),
        "seat_assignment": [target_seat, 1 - target_seat],
        "seed_commitment": {
            "capability": profile["seed_policy"]["capability"],
            "commitment_sha256": _canonical_sha({"match_id": match_id, "domain": "csp_wp2_fixture_seed"}),
            "disclosure": "withheld",
        },
        "replay_visibility_profile": "public_at_event_time_v1",
        "started_at_utc": "2026-08-18T00:00:00Z",
    }
    first_frame = {
        "document_type": "replay_frame_v1",
        "schema_version": 1,
        "match_id": match_id,
        "ordinal": 0,
        "turn_number": 0,
        "phase": "setup",
        "acting_seat": 0,
        "event_kind": "match_started",
        "public_state": {
            "zone_counts": [
                {"seat": 0, "hand_count": 7, "deck_count": 46, "prize_count": 6},
                {"seat": 1, "hand_count": 7, "deck_count": 46, "prize_count": 6},
            ],
            "board": [],
            "public_cards": [],
        },
        "decision_trace_sha256": None,
        "previous_frame_sha256": None,
    }
    second_frame = {
        "document_type": "replay_frame_v1",
        "schema_version": 1,
        "match_id": match_id,
        "ordinal": 1,
        "turn_number": 12,
        "phase": "finished",
        "acting_seat": -1,
        "event_kind": "match_finished",
        "public_state": {
            "zone_counts": [
                {"seat": 0, "hand_count": 4, "deck_count": 30, "prize_count": 0},
                {"seat": 1, "hand_count": 5, "deck_count": 31, "prize_count": 2},
            ],
            "board": [],
            "public_cards": [],
        },
        "decision_trace_sha256": None,
        "previous_frame_sha256": frame_hash(first_frame),
    }
    frames = [first_frame, second_frame]
    replay = {
        "document_type": "replay_manifest_v1",
        "schema_version": 1,
        "replay_id": "%s-replay" % match_id,
        "match_id": match_id,
        "match_envelope_sha256": _canonical_sha(envelope),
        "visibility_profile": "public_at_event_time_v1",
        "frame_count": 2,
        "first_frame_sha256": frame_hash(first_frame),
        "frame_chain_root_sha256": frame_hash(second_frame),
        "card_asset_catalog_sha256": profile["card_catalog_sha256"],
        "event_dictionary_sha256": "8" * 64,
        "complete": True,
    }
    return {"match_envelope": envelope, "replay_manifest": replay, "frames": frames}


def build_serial_evaluation_plan(
    owner: CspEvaluatorOwner,
    batch_id: str,
    pair_count: int,
) -> dict[str, Any]:
    if not _is_identifier(batch_id) or type(pair_count) is not int or not 1 <= pair_count <= 50_000:
        _fail("evaluation_plan_invalid")
    profile = owner.profile["evaluation_profile"]
    matches = []
    for pair_ordinal in range(pair_count):
        commitment = _canonical_sha(
            {
                "domain": "csp_wp2_paired_seed_commitment_v1",
                "batch_id": batch_id,
                "pair_ordinal": pair_ordinal,
                "profile_sha256": _canonical_sha(profile),
            }
        )
        for target_seat in (0, 1):
            matches.append(
                {
                    "serial_ordinal": len(matches),
                    "pair_ordinal": pair_ordinal,
                    "target_seat": target_seat,
                    "match_id": "%s-p%05d-s%d" % (batch_id, pair_ordinal, target_seat),
                    "seed_commitment_sha256": commitment,
                }
            )
    return {
        "document_type": "serial_evaluation_plan_v1",
        "schema_version": 1,
        "batch_id": batch_id,
        "execution_mode": "serial_only",
        "evaluation_profile_id": profile["profile_id"],
        "evaluation_profile_sha256": _canonical_sha(profile),
        "strategy_release": {
            "strategy_id": owner.profile["candidate_release"]["strategy_id"],
            "release_version": owner.profile["candidate_release"]["release_version"],
            "archive_sha256": owner.profile["candidate_release"]["archive_sha256"],
        },
        "opponent": _deepcopy(profile["opponents"][0]),
        "pair_count": pair_count,
        "matches": matches,
    }


def build_unsigned_evidence(
    owner: CspEvaluatorOwner,
    replay: Mapping[str, Any],
    *,
    reported_outcome: str,
    winner_seat: int | None,
    fault_counts: Mapping[str, int] | None = None,
    runtime_dirty_reasons: list[str] | None = None,
) -> dict[str, Any]:
    faults = {key: 0 for key in FAULT_KEYS}
    if fault_counts is not None:
        faults = dict(fault_counts)
    return {
        "document_type": "evaluator_evidence_v1",
        "schema_version": 1,
        "evaluation_profile_sha256": _canonical_sha(owner.profile["evaluation_profile"]),
        "match_envelope": _deepcopy(replay["match_envelope"]),
        "replay_manifest": _deepcopy(replay["replay_manifest"]),
        "runtime_report": {
            "source": "official_evaluator_runtime",
            "terminal": True,
            "reported_outcome": reported_outcome,
            "winner_seat": winner_seat,
            "turn_count": 12,
            "decision_count": 42,
            "fault_counts": faults,
            "runtime_dirty_reasons": sorted(set(runtime_dirty_reasons or [])),
            "replay_contract_accepted": True,
        },
        "evidence_verification": None,
    }
