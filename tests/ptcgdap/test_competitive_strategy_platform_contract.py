from __future__ import annotations

import copy
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from scripts.ai.ptcgdap.competitive_strategy_platform import (
    CspContractError,
    CspContractOwner,
    CspContractSet,
    frame_hash,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
SCHEMA = CONTRACT_ROOT / "competitive_strategy_platform.schema.json"
PROFILE = CONTRACT_ROOT / "competitive_strategy_platform_profile.json"
THREAT_MODEL = CONTRACT_ROOT / "competitive_strategy_platform_threat_model.json"
VECTORS = CONTRACT_ROOT / "competitive_strategy_platform_conformance_vectors.json"
BUNDLE = CONTRACT_ROOT / "competitive_strategy_platform_bundle.json"
BUILDER = ROOT / "tools/ptcgdap/build_competitive_strategy_platform_contract.py"
GDSCRIPT_OWNER = ROOT / "scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd"
GODOT_TEST = ROOT / "tests/ptcgdap/godot/test_competitive_strategy_platform_contract.gd"


def sha(char: str) -> str:
    return char * 64


def release_ref() -> dict:
    return {
        "document_type": "strategy_release_ref_v1",
        "schema_version": 1,
        "strategy_id": "org.ptcgdap.marnie",
        "release_version": "0.1.0",
        "author_id": "ptcgdap",
        "package_id": "org.ptcgdap.marnie.package",
        "archive_sha256": sha("A"),
        "manifest_canonical_sha256": sha("B"),
        "deck_identity": {
            "domain": "godot_local_card_uid_v1",
            "deck_id": "800018501",
            "deck_sha256": sha("C"),
        },
        "policy_package_sha256": sha("D"),
        "contract_bundle_sha256": sha("E"),
        "catalog_bundle_sha256": sha("F"),
        "runtime_manifest_sha256": sha("0"),
        "platforms": ["windows-x86_64"],
        "signature_key_id": "development-fixture-key",
        "release_state": "verified",
        "revocation_state": "active",
    }


def baseline_ref() -> dict:
    return {
        "participant_kind": "platform_baseline",
        "baseline_id": "rules-only-575720",
        "baseline_version": "1.0.0",
        "baseline_sha256": sha("1"),
    }


def release_participant() -> dict:
    value = release_ref()
    return {
        "participant_kind": "strategy_release",
        "strategy_id": value["strategy_id"],
        "release_version": value["release_version"],
        "package_id": value["package_id"],
        "archive_sha256": value["archive_sha256"],
        "manifest_canonical_sha256": value["manifest_canonical_sha256"],
        "deck_identity": copy.deepcopy(value["deck_identity"]),
        "policy_package_sha256": value["policy_package_sha256"],
    }


def evaluation_profile() -> dict:
    return {
        "document_type": "evaluation_profile_v1",
        "schema_version": 1,
        "profile_id": "csp-dev-marnie-v1",
        "profile_version": "1.0.0",
        "visibility": "public_qualification",
        "evaluator_id": "ptcgdap-internal-shadow-evaluator",
        "evaluator_build_sha256": sha("2"),
        "engine_sha256": sha("3"),
        "rules_sha256": sha("4"),
        "card_catalog_sha256": sha("5"),
        "host_contract_sha256": sha("6"),
        "opponents": [baseline_ref()],
        "seat_policy": "paired_swap",
        "seed_policy": {
            "capability": "deterministic_seed_v1",
            "disclosure": "commitment_only",
        },
        "games_per_pair": 2,
        "limits": {
            "match_time_ms": 600000,
            "decision_time_ms": 5000,
            "memory_mib": 1024,
        },
        "outcome_policy": {
            "draws_allowed": True,
            "invalid_output": "verified_loss_and_fault",
            "policy_error": "verified_loss_and_fault",
            "timeout": "verified_loss_and_fault",
            "dirty": "exclude_from_rank_show_separately",
        },
        "aggregation": {
            "version": "win_rate_ci_v1",
            "minimum_publish_games": 20,
            "confidence_level_basis_points": 9500,
        },
        "replay_policy": {
            "visibility_profile": "public_at_event_time_v1",
            "sampling": "all_shadow_matches",
        },
    }


def match_envelope() -> dict:
    return {
        "document_type": "match_envelope_v1",
        "schema_version": 1,
        "match_id": "csp-match-000001",
        "lane": "official_evaluation",
        "evaluator_id": "ptcgdap-internal-shadow-evaluator",
        "participants": [release_participant(), baseline_ref()],
        "engine_sha256": sha("3"),
        "rules_sha256": sha("4"),
        "card_catalog_sha256": sha("5"),
        "host_contract_sha256": sha("6"),
        "runtime_manifest_sha256": sha("0"),
        "evaluation_profile_id": "csp-dev-marnie-v1",
        "evaluation_profile_sha256": sha("7"),
        "seat_assignment": [0, 1],
        "seed_commitment": {
            "capability": "deterministic_seed_v1",
            "commitment_sha256": sha("8"),
            "disclosure": "withheld",
        },
        "replay_visibility_profile": "public_at_event_time_v1",
        "started_at_utc": "2026-08-18T00:00:00Z",
    }


def replay_frames() -> list[dict]:
    first = {
        "document_type": "replay_frame_v1",
        "schema_version": 1,
        "match_id": "csp-match-000001",
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
    second = {
        "document_type": "replay_frame_v1",
        "schema_version": 1,
        "match_id": "csp-match-000001",
        "ordinal": 1,
        "turn_number": 1,
        "phase": "main",
        "acting_seat": 0,
        "event_kind": "turn_started",
        "public_state": {
            "zone_counts": [
                {"seat": 0, "hand_count": 8, "deck_count": 45, "prize_count": 6},
                {"seat": 1, "hand_count": 7, "deck_count": 46, "prize_count": 6},
            ],
            "board": [],
            "public_cards": [],
        },
        "decision_trace_sha256": sha("9"),
        "previous_frame_sha256": frame_hash(first),
    }
    return [first, second]


def replay_manifest(frames: list[dict]) -> dict:
    return {
        "document_type": "replay_manifest_v1",
        "schema_version": 1,
        "replay_id": "csp-replay-000001",
        "match_id": "csp-match-000001",
        "match_envelope_sha256": sha("A"),
        "visibility_profile": "public_at_event_time_v1",
        "frame_count": len(frames),
        "first_frame_sha256": frame_hash(frames[0]),
        "frame_chain_root_sha256": frame_hash(frames[-1]),
        "card_asset_catalog_sha256": sha("B"),
        "event_dictionary_sha256": sha("C"),
        "complete": True,
    }


def verified_result() -> dict:
    return {
        "document_type": "verified_match_result_v1",
        "schema_version": 1,
        "match_id": "csp-match-000001",
        "match_envelope_sha256": sha("A"),
        "trust_lane": "official_verified",
        "outcome": "seat_0_win",
        "winner_seat": 0,
        "turn_count": 12,
        "decision_count": 42,
        "fault_counts": {
            "invalid_output": 0,
            "policy_error": 0,
            "timeout": 0,
            "engine_rejection": 0,
            "fallback": 0,
        },
        "dirty": False,
        "dirty_reasons": [],
        "replay_manifest_sha256": sha("D"),
        "evidence_sha256": sha("E"),
        "verification": {
            "evaluator_id": "ptcgdap-internal-shadow-evaluator",
            "key_id": "shadow-evaluator-fixture-key",
            "signature": "fixture-signature-not-production",
        },
    }


def evaluation_summary() -> dict:
    return {
        "document_type": "evaluation_summary_v1",
        "schema_version": 1,
        "strategy_release": {
            "strategy_id": "org.ptcgdap.marnie",
            "release_version": "0.1.0",
            "archive_sha256": sha("A"),
        },
        "evaluation_profile_id": "csp-dev-marnie-v1",
        "evaluation_profile_sha256": sha("7"),
        "aggregation_version": "win_rate_ci_v1",
        "input_match_ids": ["csp-match-000001"],
        "counts": {"wins": 1, "losses": 0, "draws": 0, "valid": 1, "dirty": 0},
        "fault_counts": {
            "invalid_output": 0,
            "policy_error": 0,
            "timeout": 0,
            "engine_rejection": 0,
            "fallback": 0,
        },
        "win_rate_basis_points": 10000,
        "confidence_interval_basis_points": {"low": 0, "high": 10000},
        "seat_breakdown": [
            {"seat": 0, "wins": 1, "losses": 0, "draws": 0},
            {"seat": 1, "wins": 0, "losses": 0, "draws": 0},
        ],
        "matchup_breakdown": [],
        "materializer_build_sha256": sha("F"),
    }


class CompetitiveStrategyPlatformContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contracts = CspContractSet.load_trusted(ROOT)
        cls.owner = CspContractOwner(cls.contracts)

    def test_contract_artifacts_builder_and_cross_runtime_owner_exist(self) -> None:
        for path in (
            SCHEMA,
            PROFILE,
            THREAT_MODEL,
            VECTORS,
            BUNDLE,
            BUILDER,
            GDSCRIPT_OWNER,
            GODOT_TEST,
        ):
            self.assertTrue(path.is_file(), path.relative_to(ROOT).as_posix())

    def test_trusted_bundle_binds_every_contract_artifact(self) -> None:
        bundle = load_json_strict(BUNDLE)
        expected_paths = {
            path.relative_to(ROOT).as_posix()
            for path in (SCHEMA, PROFILE, THREAT_MODEL, VECTORS)
        }
        self.assertEqual(
            expected_paths,
            {entry["path"] for entry in bundle["artifacts"]},
        )
        for entry in bundle["artifacts"]:
            path = ROOT / entry["path"]
            digest = hashlib.sha256(
                canonical_json_v1_bytes(load_json_strict(path))
            ).hexdigest().upper()
            self.assertEqual(digest, entry["canonical_sha256"])

    def test_contract_builder_check_is_clean(self) -> None:
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_tampered_bundle_and_artifact_fail_the_trust_boundary(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            copied = root / "contracts/ptcgdap"
            shutil.copytree(CONTRACT_ROOT, copied)

            bundle_path = copied / BUNDLE.name
            original_bundle = bundle_path.read_text(encoding="utf-8")
            bundle_path.write_text(
                original_bundle.replace(
                    "ptcgdap-competitive-strategy-platform-csp-wp0-v1",
                    "ptcgdap-competitive-strategy-platform-csp-wp0-v2",
                ),
                encoding="utf-8",
            )
            self.assert_error(
                "contract_bundle_trust_anchor_mismatch",
                lambda: CspContractSet.load_trusted(root),
            )

            bundle_path.write_text(original_bundle, encoding="utf-8")
            profile_path = copied / PROFILE.name
            profile_path.write_text(
                profile_path.read_text(encoding="utf-8").replace(
                    "windows-x86_64", "windows-amd64"
                ),
                encoding="utf-8",
            )
            self.assert_error(
                "contract_artifact_hash_mismatch",
                lambda: CspContractSet.load_trusted(root),
            )

    def test_owner_snapshot_is_not_weakened_by_mutating_loaded_contracts(self) -> None:
        contracts = CspContractSet.load_trusted(ROOT)
        owner = CspContractOwner(contracts)
        contracts.profile["allowed_platforms"].append("untrusted-platform")
        value = release_ref()
        value["platforms"] = ["untrusted-platform"]
        self.assert_error("release_platform_invalid", lambda: owner.validate_document(value))

    def test_platform_owner_is_additive_and_has_no_core_or_ui_dependency(self) -> None:
        source = GDSCRIPT_OWNER.read_text(encoding="utf-8")
        forbidden_dependencies = (
            "res://scenes/",
            "res://scripts/ui/",
            "GameState",
            "GameStateMachine",
            "BattleScene",
        )
        for dependency in forbidden_dependencies:
            with self.subTest(dependency=dependency):
                self.assertNotIn(dependency, source)

    def test_all_declared_document_types_validate(self) -> None:
        documents = [
            release_ref(),
            evaluation_profile(),
            match_envelope(),
            *replay_frames(),
            replay_manifest(replay_frames()),
            verified_result(),
            evaluation_summary(),
        ]
        for document in documents:
            with self.subTest(document_type=document["document_type"]):
                validated = self.owner.validate_document(document)
                self.assertEqual(document["document_type"], validated.document_type)
                self.assertEqual(64, len(validated.canonical_sha256))
                audit = validated.to_public_audit()
                self.assertFalse(audit["authoritative"])
                self.assertEqual([], audit["grants"])

    def test_replay_chain_is_verified_without_engine_authority(self) -> None:
        frames = replay_frames()
        original_frames = copy.deepcopy(frames)
        result = self.owner.validate_replay(replay_manifest(frames), frames)
        self.assertEqual(2, result.frame_count)
        self.assertEqual(frame_hash(frames[-1]), result.frame_chain_root_sha256)
        audit = result.to_public_audit()
        self.assertFalse(audit["authoritative"])
        self.assertFalse(audit["engine_invoked"])
        self.assertEqual([], audit["grants"])
        self.assertEqual(original_frames, frames)

    def test_unknown_field_fails_closed(self) -> None:
        value = match_envelope()
        value["friendly_name"] = "must not be accepted"
        self.assert_error("unknown_field", lambda: self.owner.validate_document(value))

    def test_cyclic_in_memory_input_fails_closed(self) -> None:
        value = match_envelope()
        value["cycle"] = value
        self.assert_error("document_invalid", lambda: self.owner.validate_document(value))

    def test_private_replay_keys_fail_closed_at_any_depth(self) -> None:
        forbidden = (
            "hand",
            "deck",
            "prizes",
            "deck_order",
            "search_begin_input",
            "private_rng_state",
            "private_replay_snapshot",
            "instance_id",
            "game_state",
            "action_ticket",
            "callback",
        )
        for key in forbidden:
            frames = replay_frames()
            frames[0]["public_state"][key] = ["PRIVATE_SENTINEL"]
            with self.subTest(key=key):
                self.assert_error(
                    "private_field_forbidden",
                    lambda frames=frames: self.owner.validate_replay(
                        replay_manifest(frames), frames
                    ),
                )

    def test_replay_reorder_duplicate_and_tamper_fail_closed(self) -> None:
        frames = replay_frames()
        cases = []
        cases.append(list(reversed(copy.deepcopy(frames))))
        cases.append([copy.deepcopy(frames[0]), copy.deepcopy(frames[0])])
        tampered = copy.deepcopy(frames)
        tampered[1]["turn_number"] = 99
        cases.append(tampered)
        for case in cases:
            with self.subTest(case=case):
                self.assert_error(
                    "replay_chain_invalid",
                    lambda case=case: self.owner.validate_replay(
                        replay_manifest(frames), case
                    ),
                )

    def test_incomplete_replay_cannot_claim_complete(self) -> None:
        frames = replay_frames()
        manifest = replay_manifest(frames)
        manifest["frame_count"] = 3
        self.assert_error(
            "replay_chain_invalid",
            lambda: self.owner.validate_replay(manifest, frames),
        )

    def test_official_result_requires_evaluator_verification(self) -> None:
        value = verified_result()
        del value["verification"]
        self.assert_error("official_verification_required", lambda: self.owner.validate_document(value))

    def test_community_result_cannot_carry_official_verification(self) -> None:
        value = verified_result()
        value["trust_lane"] = "community_challenge"
        self.assert_error("lane_authority_mismatch", lambda: self.owner.validate_document(value))

    def test_dirty_result_cannot_be_official_verified(self) -> None:
        value = verified_result()
        value["dirty"] = True
        value["dirty_reasons"] = ["engine_identity_drift"]
        self.assert_error("lane_authority_mismatch", lambda: self.owner.validate_document(value))

    def test_summary_requires_sorted_unique_inputs_and_balanced_counts(self) -> None:
        duplicate = evaluation_summary()
        duplicate["input_match_ids"] = ["csp-match-000001", "csp-match-000001"]
        self.assert_error("summary_inputs_invalid", lambda: self.owner.validate_document(duplicate))
        unbalanced = evaluation_summary()
        unbalanced["counts"]["wins"] = 2
        self.assert_error("summary_counts_invalid", lambda: self.owner.validate_document(unbalanced))

    def test_match_envelope_requires_exact_two_seats(self) -> None:
        value = match_envelope()
        value["participants"] = [release_participant()]
        self.assert_error("match_participants_invalid", lambda: self.owner.validate_document(value))

    def test_profile_and_envelope_identity_drift_is_detectable(self) -> None:
        envelope = match_envelope()
        profile = evaluation_profile()
        self.owner.validate_match_against_profile(envelope, profile)
        envelope["engine_sha256"] = sha("9")
        self.assert_error(
            "evaluation_profile_mismatch",
            lambda: self.owner.validate_match_against_profile(envelope, profile),
        )

    def test_shared_vectors_cover_success_and_rejection(self) -> None:
        vectors = load_json_strict(VECTORS)
        self.assertGreaterEqual(len(vectors["success_cases"]), 8)
        self.assertGreaterEqual(len(vectors["rejection_cases"]), 16)
        for case in vectors["success_cases"]:
            with self.subTest(case=case["id"]):
                result = self.owner.run_vector(case)
                self.assertEqual(case["expected"], result)
        for case in vectors["rejection_cases"]:
            with self.subTest(case=case["id"]):
                self.assert_error(
                    case["error_code"],
                    lambda case=case: self.owner.run_vector(case),
                )

    def assert_error(self, code: str, callback) -> None:
        with self.assertRaises(CspContractError) as caught:
            callback()
        self.assertEqual(code, caught.exception.code)


if __name__ == "__main__":
    unittest.main()
