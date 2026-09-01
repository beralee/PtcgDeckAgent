from __future__ import annotations

import hashlib
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_author_strategy_release_contract import build_artifacts


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"


class AuthorStrategyReleaseContractBuilderTests(unittest.TestCase):
    def test_builder_reproduces_release_contract_and_fixed_product_inputs(self) -> None:
        artifacts = build_artifacts()
        self.assertEqual(
            {
                "contracts/ptcgdap/author_strategy_release.schema.json",
                "contracts/ptcgdap/author_strategy_release_profile.json",
                "contracts/ptcgdap/author_strategy_release_conformance_vectors.json",
                "contracts/ptcgdap/author_strategy_release_bundle.json",
                "data/ptcgdap/author_strategy_release_trust_store.json",
                "data/ptcgdap/author_strategy_release_approvals.json",
                "data/ptcgdap/author_strategy_device_canary_approvals.json",
                "data/ptcgdap/author_strategy_prompt_conformance_approvals.json",
                "data/ptcgdap/author_strategy_device_acceptance_profile.json",
            },
            set(artifacts),
        )
        for relative, document in artifacts.items():
            self.assertEqual(document, load_json_strict(ROOT / relative), relative)

    def test_bundle_binds_as_wp5_and_every_release_authority(self) -> None:
        bundle = load_json_strict(CONTRACT_ROOT / "author_strategy_release_bundle.json")
        self.assertEqual("ptcgdap-author-strategy-release-as-wp6-v1", bundle["bundle_id"])
        self.assertEqual(
            "5CDC360999A23A2CADCAC6E7FA8D81549566DFABE37B2DB4F813C0C5189C3E16",
            bundle["parent_author_live_seam_bundle_canonical_sha256"],
        )
        self.assertEqual(
            "4E2693E9143C3326C131DE9C64917632129408870C1AF897199DBA8841FA4428",
            bundle["as_wp5_manifest_canonical_sha256"],
        )
        for entry in bundle["artifacts"]:
            value = load_json_strict(ROOT / entry["path"])
            actual = hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()
            self.assertEqual(entry["canonical_sha256"], actual)

    def test_prompt_conformance_approval_schema_binds_report_package_and_official_source(self) -> None:
        schema = load_json_strict(
            CONTRACT_ROOT / "author_strategy_release.schema.json"
        )
        validator = Draft202012Validator(schema)
        identity = {
            "package_id": "author.strategy",
            "package_version": "1.0.0",
            "archive_sha256": "A" * 64,
            "manifest_sha256": "B" * 64,
            "policy_ir_sha256": "C" * 64,
            "deck_manifest_sha256": "D" * 64,
        }
        record = {
            **identity,
            "platform": "windows",
            "prompt_conformance_report_sha256": "E" * 64,
            "official_source_lock_sha256": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
            "evidence_class": "official_cabt_w0_w7_package_conformance",
            "prompt_coverage": [f"W{index}" for index in range(8)],
            "status": "active",
        }
        store = {
            "document_type": "author_strategy_prompt_conformance_approvals_v1",
            "schema_version": 1,
            "approval_status": "approved",
            "records": [record],
        }
        validator.validate(store)
        missing_hash = {**store, "records": [{
            key: value
            for key, value in record.items()
            if key != "prompt_conformance_report_sha256"
        }]}
        self.assertTrue(list(validator.iter_errors(missing_hash)))
        wrong_source = {**store, "records": [{
            **record,
            "official_source_lock_sha256": "0" * 64,
        }]}
        self.assertTrue(list(validator.iter_errors(wrong_source)))

    def test_current_release_inputs_approve_product_trust_and_windows_profile_but_not_package_or_a5(self) -> None:
        profile = load_json_strict(CONTRACT_ROOT / "author_strategy_release_profile.json")
        trust = load_json_strict(ROOT / profile["trust_store"]["path"])
        approvals = load_json_strict(ROOT / profile["release_approvals"]["path"])
        canary = load_json_strict(ROOT / profile["device_canary_approvals"]["path"])
        prompt_conformance = load_json_strict(
            ROOT / profile["prompt_conformance_approvals"]["path"]
        )
        device = load_json_strict(ROOT / profile["device_acceptance"]["profile_path"])
        self.assertEqual("approved", trust["approval_status"])
        self.assertEqual(
            [{
                "key_id": "ptcgdap.product.release.ed25519.v1",
                "algorithm": "ed25519",
                "public_key_base64": "vdpuqrowRq72ecivA+cpZfvg7deqCpX9Gq9KS292DAA=",
                "scope": "production_release",
                "execution_trusted": True,
                "status": "active",
            }],
            trust["keys"],
        )
        self.assertEqual("unprovisioned", approvals["approval_status"])
        self.assertEqual([], approvals["records"])
        self.assertEqual("unprovisioned", canary["approval_status"])
        self.assertEqual([], canary["records"])
        self.assertEqual("unprovisioned", prompt_conformance["approval_status"])
        self.assertEqual([], prompt_conformance["records"])
        self.assertFalse(profile["prompt_conformance_approvals"]["caller_overrides"])
        self.assertTrue(
            profile["prompt_conformance_approvals"]["exact_package_identity_required"]
        )
        self.assertFalse(profile["device_canary_approvals"]["ordinary_player_start"])
        self.assertEqual(
            "--ptcgdap-production-device-canary",
            profile["device_canary_approvals"]["activation_arg"],
        )
        self.assertEqual("approved", device["approval_status"])
        self.assertFalse(device["formal_a5_eligible"])
        self.assertFalse(device["measurement_method"]["airplane_or_os_block_required"])
        self.assertTrue(profile["device_acceptance"]["candidate_thresholds_are_claims"])
        self.assertEqual([{"platform": "windows", "architecture": "x86_64"}], profile["supported_targets"])
        self.assertEqual("android", profile["deferred_targets"][0]["platform"])
        self.assertEqual(["windows"], profile["release_prerequisites"]["required_platforms"])
        self.assertEqual({"windows": False}, profile["release_prerequisites"]["offline_full_match_by_platform"])
        self.assertEqual({"windows"}, set(device["platforms"]))
        self.assertEqual(
            {
                "max_cold_start_msec": 10_000,
                "max_catalog_scan_msec": 1_000,
                "max_match_load_msec": 6_000,
                "max_decision_p95_msec": 250,
                "max_peak_memory_mib": 1_024,
                "max_package_mib": 750,
                "max_thermal_status": None,
                "max_battery_drain_percent_per_hour": None,
            },
            device["platforms"]["windows"],
        )
        self.assertFalse(profile["current_release_state"]["production_ready"])
        self.assertEqual("BattleSetup remains disabled", profile["current_release_state"]["player_start_gate"])

    def test_windows_export_inventory_covers_local_uid_contract_and_runtime_owner_chain(self) -> None:
        profile = load_json_strict(CONTRACT_ROOT / "author_strategy_release_profile.json")
        required = set(profile["required_export_paths"])
        self.assertTrue(
            {
                "contracts/ptcgdap/local_uid_public_context.schema.json",
                "contracts/ptcgdap/local_uid_public_context_profile.json",
                "contracts/ptcgdap/local_uid_public_context_conformance_vectors.json",
                "contracts/ptcgdap/local_uid_public_context_bundle.json",
                "scripts/ai/ptcgdap/public/PublicDeckAdapter.gd",
                "scripts/ai/ptcgdap/host/godot/AuthorStrategyShadowPrompt.gd",
                "scripts/ai/ptcgdap/host/godot/AuthorStrategyLivePromptSource.gd",
                "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd",
                "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLiveSeam.gd",
            }.issubset(required)
        )


if __name__ == "__main__":
    unittest.main()
