from __future__ import annotations

import copy
import argparse
import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.competitive_strategy_evaluator import (
    CspEvaluatorOwner,
    PROFILE_ID,
    build_replay_fixture,
    build_unsigned_evidence,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes


PRIVATE_KEY = bytes.fromhex(
    "9D61B19DEFFD5A60BA844AF492EC2CC4"
    "4449C5697B326919703BAC031CAE7F60"
)


def sha(value: object) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def rendered_json(value: object) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(rendered_json(value), encoding="utf-8")


def profile() -> dict:
    candidate = {
        "document_type": "strategy_release_ref_v1",
        "schema_version": 1,
        "strategy_id": "ptcgdap.marnie.18.0.package-local-v1",
        "release_version": "0.1.0",
        "author_id": "ptcgdap",
        "package_id": "ptcgdap.marnie.windows-local",
        "archive_sha256": "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E",
        "manifest_canonical_sha256": "FC1170163029FF57830B2933C87560B84F63B53382F6FCBC53D981BCBB93444F",
        "deck_identity": {
            "domain": "godot_local_card_uid_v1",
            "deck_id": "800018501",
            "deck_sha256": "F40AEE3218B49CA1863AC0F8193885B279B74EE61E57AB0100574F8E351C9AFD",
        },
        "policy_package_sha256": "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC",
        "contract_bundle_sha256": "B642E704B92A8A76E0D15D02C20B8CC006C4AD2FEE90324FEEBD35114DF92262",
        "catalog_bundle_sha256": "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4",
        "runtime_manifest_sha256": "6961EEECEEB33459002A40A52AA76AB0243871439D3FDF10B9F1F4927AB6D6E0",
        "platforms": ["windows-x86_64"],
        "signature_key_id": "development-fixture-key",
        "release_state": "verified",
        "revocation_state": "active",
    }
    evaluation = {
        "document_type": "evaluation_profile_v1",
        "schema_version": 1,
        "profile_id": "csp-wp2-marnie-shadow-v1",
        "profile_version": "1.0.0",
        "visibility": "public_qualification",
        "evaluator_id": "ptcgdap-csp-wp2-shadow-evaluator",
        "evaluator_build_sha256": sha({"algorithm": "csp_wp2_evaluator_v1"}),
        "engine_sha256": "BA63D5F176C90F3C91F787F3AC91753A087997F43A8A09FBE7C0AECA80352675",
        "rules_sha256": "9D2FAA7BD522785580D8243B03E683690E500A8583236D10CAA90500C3AB1B2E",
        "card_catalog_sha256": "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4",
        "host_contract_sha256": "B642E704B92A8A76E0D15D02C20B8CC006C4AD2FEE90324FEEBD35114DF92262",
        "opponents": [
            {
                "participant_kind": "platform_baseline",
                "baseline_id": "rules-only-575720",
                "baseline_version": "1.0.0",
                "baseline_sha256": "46ACA42E3AE833802356A2E5CFA1F54DA80041F5EECBA586EBCBDB158C33506E",
            }
        ],
        "seat_policy": "paired_swap",
        "seed_policy": {"capability": "paired_seed_commitment_v1", "disclosure": "commitment_only"},
        "games_per_pair": 2,
        "limits": {"match_time_ms": 600000, "decision_time_ms": 5000, "memory_mib": 1024},
        "outcome_policy": {
            "draws_allowed": True,
            "invalid_output": "verified_loss_and_fault",
            "policy_error": "verified_loss_and_fault",
            "timeout": "verified_loss_and_fault",
            "dirty": "exclude_from_rank_show_separately",
        },
        "aggregation": {
            "version": "win_rate_ci_integer_v1",
            "minimum_publish_games": 20,
            "confidence_level_basis_points": 9500,
        },
        "replay_policy": {"visibility_profile": "public_at_event_time_v1", "sampling": "all_shadow_matches"},
    }
    algorithm = {
        "domain": "csp_wp2_materializer_v1",
        "sort": "match_id_ascending",
        "point_estimate": "floor(wins*10000/valid)",
        "below_minimum_interval": [0, 10000],
        "wilson": {"z_scaled": 19600, "scale": 10000, "integer_sqrt": "floor"},
    }
    return {
        "document_type": "competitive_strategy_evaluator_profile_v1",
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "authority_mode": "shadow_test_only",
        "production_authority": False,
        "grants": [],
        "evaluator": {
            "evaluator_id": "ptcgdap-csp-wp2-shadow-evaluator",
            "key_id": "csp-wp2-rfc8032-fixture-key",
            "algorithm": "ed25519",
            "public_key_hex": "D75A980182B10AB7D54BFED3C964073A0EE172F3DAA62325AF021A68F707511A",
        },
        "candidate_release": candidate,
        "evaluation_profile": evaluation,
        "runtime_report_contract": {
            "source": "official_evaluator_runtime",
            "terminal_required": True,
            "replay_contract_acceptance_required": True,
            "historical_import_allowed": False,
            "client_self_report_allowed": False,
        },
        "fault_policy": {
            "forced_loss_faults": ["invalid_output", "policy_error", "timeout"],
            "dirty_exclusion_faults": ["engine_rejection", "fallback"],
            "runtime_dirty_reasons_excluded": True,
            "faults_visible_in_summary": True,
        },
        "aggregation_contract": {
            "version": "win_rate_ci_integer_v1",
            "point_estimate": "wins_divided_by_valid",
            "draw_value": "zero_wins",
            "confidence_interval": "wilson_95_integer_fixed_point",
            "below_minimum_interval": "zero_to_ten_thousand",
        },
        "materializer_build_sha256": sha(algorithm),
    }


def vectors(profile_value: dict) -> dict:
    owner = CspEvaluatorOwner.from_documents(ROOT, profile_value)
    zero = {key: 0 for key in owner.fault_keys()}

    def record(match_id: str, target: int, outcome: str, winner: int | None, faults: dict | None = None) -> dict:
        replay = build_replay_fixture(owner, match_id, target)
        evidence = build_unsigned_evidence(
            owner,
            replay,
            reported_outcome=outcome,
            winner_seat=winner,
            fault_counts=faults,
        )
        return owner.issue_record(evidence, PRIVATE_KEY, replay["frames"])

    records = [
        record("wp2-match-001", 0, "seat_0_win", 0),
        record("wp2-match-002", 1, "seat_1_win", 1),
        record("wp2-match-003", 0, "seat_0_win", 0, dict(zero, invalid_output=1)),
        record("wp2-match-004", 1, "draw", None),
        record("wp2-match-005", 0, "seat_0_win", 0, dict(zero, fallback=1)),
    ]
    expected = owner.materialize(records)
    rejection_cases = []
    bad_result = copy.deepcopy(records[0])
    bad_result["result"]["verification"]["signature"] = "00" * 64
    rejection_cases.append({"id": "tampered_result_signature", "error_code": "result_signature_invalid", "record": bad_result})
    bad_evidence = copy.deepcopy(records[0])
    bad_evidence["evidence"]["runtime_report"]["decision_count"] += 1
    rejection_cases.append({"id": "tampered_evidence", "error_code": "evidence_signature_invalid", "record": bad_evidence})
    bad_profile = copy.deepcopy(records[0])
    bad_profile["evidence"]["evaluation_profile_sha256"] = "A" * 64
    rejection_cases.append({"id": "wrong_profile", "error_code": "evaluation_profile_mismatch", "record": bad_profile})
    bad_engine = copy.deepcopy(records[0])
    bad_engine["evidence"]["match_envelope"]["engine_sha256"] = "A" * 64
    rejection_cases.append({"id": "engine_drift", "error_code": "match_profile_mismatch", "record": bad_engine})
    bad_release = copy.deepcopy(records[0])
    bad_release["evidence"]["match_envelope"]["participants"][0]["archive_sha256"] = "B" * 64
    rejection_cases.append({"id": "release_drift", "error_code": "strategy_release_mismatch", "record": bad_release})
    community = copy.deepcopy(records[0])
    community["evidence"]["match_envelope"]["lane"] = "community_challenge"
    rejection_cases.append({"id": "community_lane", "error_code": "match_lane_invalid", "record": community})
    self_report = copy.deepcopy(records[0])
    self_report["evidence"]["runtime_report"]["source"] = "client_self_report"
    rejection_cases.append({"id": "client_self_report", "error_code": "evaluation_source_invalid", "record": self_report})
    confidence_cases = []
    for wins, valid in ((0, 0), (2, 4), (0, 20), (10, 20), (20, 20), (50, 100)):
        confidence_cases.append(
            {"wins": wins, "valid": valid, "expected": owner.confidence_interval_audit(wins, valid)}
        )
    return {
        "document_type": "competitive_strategy_evaluator_conformance_vectors_v1",
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "records": records,
        "expected_summary": expected,
        "rejection_cases": rejection_cases,
        "confidence_interval_cases": confidence_cases,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    profile_value = profile()
    vectors_value = vectors(profile_value)
    profile_path = ROOT / "contracts/ptcgdap/competitive_strategy_evaluator_profile.json"
    vectors_path = ROOT / "contracts/ptcgdap/competitive_strategy_evaluator_conformance_vectors.json"
    bundle = {
        "document_type": "competitive_strategy_evaluator_bundle_v1",
        "schema_version": 1,
        "bundle_id": "ptcgdap-competitive-strategy-evaluator-csp-wp2-v1",
        "digest_mode": "canonical_json_v1",
        "artifact_set_policy": "exact_ids_paths_hashes_no_duplicates",
        "artifacts": [
            {"artifact_id": "profile", "path": profile_path.relative_to(ROOT).as_posix(), "canonical_sha256": sha(profile_value)},
            {"artifact_id": "vectors", "path": vectors_path.relative_to(ROOT).as_posix(), "canonical_sha256": sha(vectors_value)},
        ],
    }
    outputs = {
        profile_path: profile_value,
        vectors_path: vectors_value,
        ROOT / "contracts/ptcgdap/competitive_strategy_evaluator_bundle.json": bundle,
    }
    if args.check:
        mismatches = [
            path.relative_to(ROOT).as_posix()
            for path, value in outputs.items()
            if not path.is_file() or path.read_text(encoding="utf-8") != rendered_json(value)
        ]
        if mismatches:
            raise SystemExit("generated contract mismatch: %s" % ", ".join(mismatches))
    else:
        for path, value in outputs.items():
            write_json(path, value)
    print(sha(bundle))


if __name__ == "__main__":
    main()
