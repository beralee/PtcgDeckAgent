from __future__ import annotations

from pathlib import Path
import unittest

from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageLoader
from scripts.ai.ptcgdap.author_strategy_release import AuthorStrategyReleaseGate


ROOT = Path(__file__).resolve().parents[2]


class AuthorStrategyReleaseGateTests(unittest.TestCase):
    def test_fixed_product_trust_loads_but_player_release_remains_closed(self) -> None:
        gate = AuthorStrategyReleaseGate(ROOT)
        report = gate.audit_snapshot()
        self.assertTrue(report["contract_ok"])
        self.assertEqual("approved", report["production_trust_status"])
        self.assertEqual("approved", report["device_profile_status"])
        self.assertEqual("unprovisioned", report["release_approval_status"])
        self.assertEqual(0, report["approved_package_count"])
        self.assertEqual("unprovisioned", report["device_canary_approval_status"])
        self.assertEqual(0, report["approved_device_canary_count"])
        self.assertEqual("unprovisioned", report["prompt_conformance_approval_status"])
        self.assertEqual(0, report["approved_prompt_conformance_count"])
        self.assertEqual(1, report["active_production_key_count"])
        self.assertTrue(report["production_trust_ready"])
        self.assertFalse(report["production_ready"])
        self.assertEqual("", report["production_trust_error_code"])
        self.assertEqual("release_prompt_conformance_unapproved", report["error_code"])
        self.assertFalse(report["player_start_allowed"])
        self.assertEqual(["windows"], report["release_target_platforms"])
        self.assertEqual(["android"], report["deferred_platforms"])

    def test_test_fixture_signature_cannot_be_promoted_to_release(self) -> None:
        gate = AuthorStrategyReleaseGate(ROOT)
        decision = gate.evaluate_package({
            "signature_status": "test_fixture_trusted",
            "signature_key_id": "ptcgdap-as-wp1-test-fixture-ed25519-v1",
            "signature_scope": "test_fixture_only",
            "execution_trusted": False,
        })
        self.assertFalse(decision["accepted"])
        self.assertEqual("release_package_not_execution_trusted", decision["error_code"])

    def test_caller_cannot_override_product_trust_or_device_profile(self) -> None:
        with self.assertRaises(TypeError):
            AuthorStrategyReleaseGate(ROOT, trusted_public_key="caller")
        with self.assertRaises(TypeError):
            AuthorStrategyReleaseGate(ROOT, device_profile={"approval_status": "approved"})

    def test_release_requires_all_independent_gates_not_only_a_signature(self) -> None:
        gate = AuthorStrategyReleaseGate(ROOT)
        decision = gate.evaluate_release_candidate({
            "package_execution_trusted": True,
            "package_scope": "production_release",
            "exact_deck_mapping": True,
            "prompt_coverage": ["W0", "W1", "W2", "W3", "W4", "W5", "W6", "W7"],
            "offline_full_match_by_platform": {"windows": False},
            "rollback_verified": True,
            "a5_evidence_approved": True,
        })
        self.assertFalse(decision["accepted"])
        self.assertEqual("release_package_not_execution_trusted", decision["error_code"])
        self.assertFalse(decision["player_start_allowed"])

    def test_package_loader_consumes_the_fixed_release_trust_owner_without_promoting_test_key(self) -> None:
        loader = AuthorStrategyPackageLoader()
        report = loader.contract_report()
        self.assertEqual("approved", report["production_trust_status"])
        self.assertEqual(1, report["active_production_key_count"])
        self.assertFalse(report["test_fixture_key_execution_trusted"])
        handle = loader.load_path(
            ROOT / "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"
        )
        self.assertEqual("test_fixture_trusted", handle.signature_status)
        self.assertEqual("test_fixture_only", handle.signature_scope)
        self.assertEqual("ptcgdap-as-wp1-test-fixture-ed25519-v1", handle.signature_key_id)
        self.assertFalse(handle.execution_trusted)

    def test_ready_requires_exact_product_key_and_exact_approved_package_identity(self) -> None:
        gate = AuthorStrategyReleaseGate(ROOT)
        gate._trust = {
            "approval_status": "approved",
            "keys": [{
                "key_id": "product.release.test",
                "algorithm": "ed25519",
                "scope": "production_release",
                "execution_trusted": True,
                "status": "active",
            }],
        }
        gate._device = {"approval_status": "approved", "formal_a5_eligible": True}
        identity = {
            "package_id": "author.strategy",
            "package_version": "1.0.0",
            "archive_sha256": "A" * 64,
            "manifest_sha256": "B" * 64,
            "policy_ir_sha256": "C" * 64,
            "deck_manifest_sha256": "D" * 64,
        }
        prompt_report_sha256 = "F" * 64
        gate._prompt_conformance_approvals = {
            "approval_status": "approved",
            "records": [{
                **identity,
                "platform": "windows",
                "prompt_conformance_report_sha256": prompt_report_sha256,
                "official_source_lock_sha256": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
                "evidence_class": "official_cabt_w0_w7_package_conformance",
                "prompt_coverage": [f"W{index}" for index in range(8)],
                "status": "active",
            }],
        }
        gate._approvals = {
            "approval_status": "approved",
            "records": [{
                **identity,
                "prompt_coverage": [f"W{index}" for index in range(8)],
                "prompt_conformance_report_sha256": prompt_report_sha256,
                "device_report_sha256_by_platform": {"windows": "E" * 64},
                "rollback_report_sha256": "1" * 64,
                "a5_evidence_sha256": "2" * 64,
            }],
        }
        metadata = {
            **identity,
            "signature_key_id": "product.release.test",
            "signature_scope": "production_release",
            "execution_trusted": True,
        }
        accepted = gate.evaluate_package(metadata)
        self.assertTrue(accepted["accepted"], accepted)
        installed = gate.evaluate_installed_package(metadata)
        self.assertTrue(installed["accepted"], installed)
        self.assertTrue(installed["player_start_allowed"])
        self.assertEqual(
            "fixed_product_release_approval", installed["authority_source"]
        )
        drifted = gate.evaluate_package({**metadata, "archive_sha256": "9" * 64})
        self.assertFalse(drifted["accepted"])
        self.assertEqual("release_package_not_approved", drifted["error_code"])
        wrong_key = gate.evaluate_package({**metadata, "signature_key_id": "other"})
        self.assertFalse(wrong_key["accepted"])
        self.assertEqual("release_package_scope_invalid", wrong_key["error_code"])
        installed_drift = gate.evaluate_installed_package(
            {**metadata, "archive_sha256": "9" * 64}
        )
        self.assertFalse(installed_drift["accepted"])
        self.assertFalse(installed_drift["player_start_allowed"])

        evidence = gate._approvals["records"][0]
        candidate = {
            "package_metadata": metadata,
            "package_execution_trusted": True,
            "package_scope": "production_release",
            "exact_deck_mapping": True,
            "prompt_coverage": [f"W{index}" for index in range(8)],
            "prompt_conformance_report_sha256": prompt_report_sha256,
            "offline_full_match_by_platform": {"windows": False},
            "rollback_verified": True,
            "a5_evidence_approved": True,
            "device_report_sha256_by_platform": evidence["device_report_sha256_by_platform"],
            "rollback_report_sha256": evidence["rollback_report_sha256"],
            "a5_evidence_sha256": evidence["a5_evidence_sha256"],
        }
        released = gate.evaluate_release_candidate(candidate)
        self.assertTrue(released["accepted"], released)
        self.assertTrue(released["player_start_allowed"])
        mismatched = gate.evaluate_release_candidate({**candidate, "device_report_sha256_by_platform": {}})
        self.assertFalse(mismatched["accepted"])
        self.assertEqual("release_device_evidence_incomplete", mismatched["error_code"])
        cross_scope = gate.evaluate_release_candidate({
            **candidate,
            "offline_full_match_by_platform": {"windows": True, "android": True},
            "device_report_sha256_by_platform": {
                "windows": evidence["device_report_sha256_by_platform"]["windows"],
                "android": "F" * 64,
            },
        })
        self.assertFalse(cross_scope["accepted"])
        self.assertEqual("release_device_evidence_incomplete", cross_scope["error_code"])
        prompt_drift = gate.evaluate_release_candidate({
            **candidate,
            "prompt_conformance_report_sha256": "0" * 64,
        })
        self.assertFalse(prompt_drift["accepted"])
        self.assertEqual(
            "release_prompt_conformance_unapproved", prompt_drift["error_code"]
        )
        gate._prompt_conformance_approvals = {
            "approval_status": "approved",
            "records": [],
        }
        bare_claim = gate.evaluate_package(metadata)
        self.assertFalse(bare_claim["accepted"])
        self.assertEqual(
            "release_prompt_conformance_unapproved", bare_claim["error_code"]
        )

    def test_device_canary_uses_separate_exact_approval_without_future_evidence_hashes(self) -> None:
        gate = AuthorStrategyReleaseGate(ROOT)
        gate._trust = {
            "approval_status": "approved",
            "keys": [{
                "key_id": "product.release.test",
                "algorithm": "ed25519",
                "scope": "production_release",
                "execution_trusted": True,
                "status": "active",
            }],
        }
        gate._device = {"approval_status": "approved", "formal_a5_eligible": True}
        identity = {
            "package_id": "author.strategy",
            "package_version": "1.0.0",
            "archive_sha256": "A" * 64,
            "manifest_sha256": "B" * 64,
            "policy_ir_sha256": "C" * 64,
            "deck_manifest_sha256": "D" * 64,
        }
        prompt_report_sha256 = "F" * 64
        gate._prompt_conformance_approvals = {
            "approval_status": "approved",
            "records": [{
                **identity,
                "platform": "windows",
                "prompt_conformance_report_sha256": prompt_report_sha256,
                "official_source_lock_sha256": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
                "evidence_class": "official_cabt_w0_w7_package_conformance",
                "prompt_coverage": [f"W{index}" for index in range(8)],
                "status": "active",
            }],
        }
        gate._canary_approvals = {
            "approval_status": "approved",
            "records": [{
                **identity,
                "signature_key_id": "product.release.test",
                "platform": "windows",
                "prompt_coverage": [f"W{index}" for index in range(8)],
                "prompt_conformance_report_sha256": prompt_report_sha256,
                "status": "active",
            }],
        }
        gate._approvals = {"approval_status": "unprovisioned", "records": []}
        metadata = {
            **identity,
            "signature_key_id": "product.release.test",
            "signature_scope": "production_release",
            "execution_trusted": True,
        }

        canary = gate.evaluate_device_canary_package(metadata, "windows")
        ordinary = gate.evaluate_package(metadata)
        drifted = gate.evaluate_device_canary_package(
            {**metadata, "archive_sha256": "9" * 64}, "windows"
        )
        wrong_platform = gate.evaluate_device_canary_package(metadata, "android")

        self.assertTrue(canary["accepted"], canary)
        self.assertTrue(canary["device_canary_allowed"])
        self.assertFalse(canary["player_start_allowed"])
        self.assertEqual(
            "fixed_product_device_canary_approval", canary["authority_source"]
        )
        self.assertNotIn("device_report_sha256_by_platform", canary["approval"])
        self.assertFalse(ordinary["accepted"])
        self.assertEqual("release_package_not_approved", ordinary["error_code"])
        self.assertFalse(drifted["accepted"])
        self.assertEqual("device_canary_not_approved", drifted["error_code"])
        self.assertFalse(wrong_platform["accepted"])
        self.assertEqual("device_canary_platform_invalid", wrong_platform["error_code"])

        gate._prompt_conformance_approvals = {
            "approval_status": "approved",
            "records": [],
        }
        bare_claim = gate.evaluate_device_canary_package(metadata, "windows")
        self.assertFalse(bare_claim["accepted"])
        self.assertEqual(
            "release_prompt_conformance_unapproved", bare_claim["error_code"]
        )

    def test_wrong_scope_key_with_colliding_id_cannot_authorize_release(self) -> None:
        gate = AuthorStrategyReleaseGate(ROOT)
        gate._trust = {
            "approval_status": "approved",
            "keys": [
                {
                    "key_id": "collision",
                    "algorithm": "ed25519",
                    "scope": "production_release",
                    "execution_trusted": True,
                    "status": "active",
                },
                {
                    "key_id": "collision",
                    "algorithm": "rsa",
                    "scope": "development",
                    "execution_trusted": True,
                    "status": "active",
                },
            ],
        }
        gate._device = {"approval_status": "approved", "formal_a5_eligible": True}
        gate._approvals = {"approval_status": "approved", "records": []}
        report = gate.audit_snapshot()
        self.assertEqual(1, report["active_production_key_count"])


if __name__ == "__main__":
    unittest.main()
