from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "contracts/ptcgdap/device_manifest_v1.schema.json"
PROFILE = ROOT / "contracts/ptcgdap/device_manifest_v1_profile.json"
MANIFEST = ROOT / "data/ptcgdap/marnie_windows_device_manifest_v1.json"
BUNDLE = ROOT / "contracts/ptcgdap/device_manifest_v1_bundle.json"
BUILDER = ROOT / "tools/ptcgdap/build_device_manifest_v1.py"
RUNTIME = ROOT / "scripts/ai/ptcgdap/runtime/local/DeviceManifest.gd"
GODOT_TEST = ROOT / "tests/ptcgdap/godot/test_device_manifest.gd"
ACCEPTANCE_PROFILE = ROOT / "data/ptcgdap/author_strategy_device_acceptance_profile.json"
LOCAL_EXECUTOR_MANIFEST = ROOT / "data/ptcgdap/marnie_windows_local_policy_executor_v1.json"
ROLLBACK_MANIFEST = ROOT / "data/ptcgdap/marnie_windows_policy_package_v1.json"

LOCAL_EXECUTOR_CANONICAL = "0B8FB2A551429CBAFFF7DD0B9DFACEC3FFF76AA867A8B1BC666F540875489BA7"
ROLLBACK_CANONICAL = "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC"


def canonical_sha(path: Path) -> str:
    return hashlib.sha256(
        canonical_json_v1_bytes(load_json_strict(path))
    ).hexdigest().upper()


class DeviceManifestV1Tests(unittest.TestCase):
    def test_contract_builder_runtime_and_godot_suite_exist(self) -> None:
        for path in (SCHEMA, PROFILE, MANIFEST, BUNDLE, BUILDER, RUNTIME, GODOT_TEST):
            self.assertTrue(path.is_file(), path.relative_to(ROOT).as_posix())

    def test_schema_manifest_profile_and_bundle_are_reproducible(self) -> None:
        schema = load_json_strict(SCHEMA)
        manifest = load_json_strict(MANIFEST)
        profile = load_json_strict(PROFILE)
        bundle = load_json_strict(BUNDLE)
        Draft202012Validator.check_schema(schema)
        errors = sorted(
            Draft202012Validator(schema).iter_errors(manifest),
            key=lambda item: list(item.path),
        )
        self.assertEqual([], errors)
        self.assertEqual("device_manifest_v1", manifest["document_type"])
        self.assertEqual("ptcgdap-marnie-windows-device-v1", manifest["manifest_id"])
        artifacts = {row["path"]: row for row in bundle["artifacts"]}
        for path in (SCHEMA, PROFILE, MANIFEST):
            relative = path.relative_to(ROOT).as_posix()
            self.assertEqual(canonical_sha(path), artifacts[relative]["canonical_sha256"])
        self.assertEqual(profile["manifest_id"], manifest["manifest_id"])

    def test_only_windows_x86_64_is_declared_and_android_is_not_claimed(self) -> None:
        manifest = load_json_strict(MANIFEST)
        self.assertEqual(
            [
                {
                    "os": "windows",
                    "architecture": "x86_64",
                    "abi": "windows-x86_64",
                    "host": "godot",
                    "minimum_runtime_version": "4.6.1",
                    "runtime_build": "4.6.1.stable.official.14d19694e",
                    "portable_baseline": "gdscript",
                }
            ],
            manifest["target_platforms"],
        )
        self.assertFalse(manifest["release_status"]["android_claimed"])
        self.assertEqual("android", manifest["deferred_targets"][0]["os"])
        self.assertEqual("arm64-v8a", manifest["deferred_targets"][0]["architecture"])

    def test_no_model_execution_and_signature_boundaries_are_explicit(self) -> None:
        manifest = load_json_strict(MANIFEST)
        self.assertEqual("none", manifest["inference_backend"]["kind"])
        self.assertIsNone(manifest["inference_backend"]["implementation_hash"])
        self.assertEqual([], manifest["model_artifacts"])
        self.assertEqual("device_local", manifest["execution"]["location"])
        self.assertEqual("denied", manifest["execution"]["aligned_ai_network"])
        self.assertEqual("denied", manifest["execution"]["external_compute"])
        self.assertFalse(manifest["execution"]["system_python"])
        self.assertEqual("unprovisioned", manifest["package_integrity"]["production_signature_status"])
        self.assertIsNone(manifest["package_integrity"]["signing_key_id"])
        self.assertFalse(manifest["release_status"]["production_ready"])
        self.assertFalse(manifest["release_status"]["a5_claimed"])

    def test_profile_resource_limits_and_parent_manifests_are_exactly_pinned(self) -> None:
        manifest = load_json_strict(MANIFEST)
        acceptance = load_json_strict(ACCEPTANCE_PROFILE)
        self.assertEqual(canonical_sha(ACCEPTANCE_PROFILE), manifest["device_acceptance_profile"]["canonical_sha256"])
        self.assertEqual(acceptance["profile_id"], manifest["device_acceptance_profile"]["profile_id"])
        self.assertEqual("approved", manifest["device_acceptance_profile"]["approval_status"])
        self.assertFalse(manifest["device_acceptance_profile"]["formal_a5_eligible"])
        self.assertTrue(manifest["release_status"]["device_profile_approved"])
        self.assertTrue(manifest["resource_profile"]["acceptance_claim"])
        self.assertFalse(manifest["release_status"]["os_network_isolation_proven"])
        self.assertFalse(manifest["release_status"]["a5_claimed"])
        self.assertEqual(acceptance["platforms"]["windows"], manifest["resource_profile"]["limits"])
        self.assertFalse(manifest["resource_profile"]["candidate_override_allowed"])
        self.assertEqual(LOCAL_EXECUTOR_CANONICAL, canonical_sha(LOCAL_EXECUTOR_MANIFEST))
        self.assertEqual(LOCAL_EXECUTOR_CANONICAL, manifest["local_policy_executor"]["canonical_sha256"])
        self.assertEqual(ROLLBACK_CANONICAL, canonical_sha(ROLLBACK_MANIFEST))
        rollback = manifest["fallback"]["rollback_manifest"]
        self.assertEqual(ROLLBACK_CANONICAL, rollback["canonical_sha256"])
        self.assertTrue(manifest["fallback"]["new_matches_only"])
        self.assertFalse(manifest["fallback"]["match_hot_swap"])

    def test_builder_check_and_static_runtime_boundaries(self) -> None:
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--check"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        runtime = RUNTIME.read_text(encoding="utf-8")
        for forbidden in (
            "HTTPRequest", "HTTPClient", "TCPServer", "PacketPeer",
            "OS.execute", "OS.create_process", "GameState", "BattleScene",
        ):
            self.assertNotIn(forbidden, runtime)
        self.assertIn("LocalPolicyExecutorManifest.gd", runtime)
        self.assertIn("author_strategy_device_acceptance_profile.json", runtime)


if __name__ == "__main__":
    unittest.main()
