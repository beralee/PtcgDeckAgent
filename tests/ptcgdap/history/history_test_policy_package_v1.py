from __future__ import annotations

import copy
import hashlib
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "contracts/ptcgdap/policy_package_v1.schema.json"
PROFILE = ROOT / "contracts/ptcgdap/policy_package_v1_profile.json"
BUNDLE = ROOT / "contracts/ptcgdap/policy_package_v1_bundle.json"
MANIFEST = ROOT / "data/ptcgdap/marnie_windows_policy_package_v1.json"
CANDIDATE = ROOT / "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"
EXPECTED_CANDIDATE_SHA256 = "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class PolicyPackageV1Tests(unittest.TestCase):
    def test_contract_runtime_and_generated_documents_exist(self) -> None:
        paths = (
            SCHEMA,
            PROFILE,
            BUNDLE,
            MANIFEST,
            ROOT / "tools/ptcgdap/build_policy_package_v1.py",
            ROOT / "scripts/ai/ptcgdap/policy_package.py",
            ROOT / "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd",
        )
        self.assertEqual([], [path.relative_to(ROOT).as_posix() for path in paths if not path.is_file()])

    def test_schema_accepts_the_exact_generated_manifest_and_bundle_pins_all_documents(self) -> None:
        schema = load_json_strict(SCHEMA)
        manifest = load_json_strict(MANIFEST)
        Draft202012Validator.check_schema(schema)
        self.assertEqual([], list(Draft202012Validator(schema).iter_errors(manifest)))
        bundle = load_json_strict(BUNDLE)
        self.assertEqual("ptcgdap-policy-package-v1-d051", bundle["bundle_id"])
        self.assertEqual({"schema", "profile", "manifest"}, {entry["id"] for entry in bundle["artifacts"]})
        for entry in bundle["artifacts"]:
            document = load_json_strict(ROOT / entry["path"])
            self.assertEqual(entry["canonical_sha256"], sha256_bytes(canonical_json_v1_bytes(document)))

    def test_first_windows_manifest_is_honest_about_no_learned_model_and_keeps_candidate_bytes(self) -> None:
        manifest = load_json_strict(MANIFEST)
        self.assertEqual(EXPECTED_CANDIDATE_SHA256, sha256_bytes(CANDIDATE.read_bytes()))
        self.assertEqual(EXPECTED_CANDIDATE_SHA256, manifest["author_package"]["archive_sha256"])
        self.assertEqual("none", manifest["model"]["learned_model"])
        self.assertEqual("none", manifest["model"]["backend"])
        self.assertIsNone(manifest["model"]["artifact_path"])
        self.assertIsNone(manifest["model"]["artifact_sha256"])
        self.assertEqual("unused_non_model_payload", manifest["author_package"]["weights"]["status"])
        self.assertEqual("device_local", manifest["target"]["execution_location"])
        self.assertEqual("windows", manifest["target"]["platform"])
        self.assertEqual("x86_64", manifest["target"]["architecture"])
        self.assertEqual(
            {
                "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd",
                "scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd",
                "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd",
                "scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd",
            },
            {
                manifest["executor"]["host_adapter_path"],
                manifest["executor"]["base_executor_path"],
                manifest["executor"]["match_owner_path"],
                manifest["executor"]["engine_action_executor_path"],
            },
        )
        self.assertFalse(manifest["capabilities"]["network_ingress"])
        self.assertFalse(manifest["capabilities"]["network_egress"])
        self.assertFalse(manifest["capabilities"]["system_python"])
        self.assertFalse(manifest["capabilities"]["external_process"])

    def test_python_verifier_recomputes_archive_members_executor_parents_and_rollback(self) -> None:
        from scripts.ai.ptcgdap.policy_package import PolicyPackageVerifier

        verifier = PolicyPackageVerifier(ROOT)
        accepted = verifier.verify()
        self.assertTrue(accepted["accepted"], accepted)
        self.assertEqual("none", accepted["learned_model"])
        self.assertEqual(EXPECTED_CANDIDATE_SHA256, accepted["archive_sha256"])

        manifest = load_json_strict(MANIFEST)
        mutations = (
            ("archive", ("author_package", "archive_sha256"), "A" * 64, "policy_package_archive_mismatch"),
            ("member", ("author_package", "policy_ir_sha256"), "B" * 64, "policy_package_member_mismatch"),
            ("executor", ("executor", "base_executor_sha256"), "C" * 64, "policy_package_executor_mismatch"),
            ("model", ("model", "learned_model"), "declared", "policy_package_model_mismatch"),
            ("parent", ("parents", "source_lock_canonical_sha256"), "D" * 64, "policy_package_parent_mismatch"),
            ("rollback", ("rollback", "target_canonical_sha256"), "E" * 64, "policy_package_rollback_mismatch"),
        )
        for name, path, value, error_code in mutations:
            with self.subTest(name=name):
                changed = copy.deepcopy(manifest)
                changed[path[0]][path[1]] = value
                rejected = verifier.verify(changed)
                self.assertFalse(rejected["accepted"], rejected)
                self.assertEqual(error_code, rejected["error_code"])

    def test_d051_release_parent_remains_sealed_across_d057_profile_approval(self) -> None:
        from scripts.ai.ptcgdap.policy_package import PolicyPackageVerifier

        manifest = load_json_strict(MANIFEST)
        current_release = load_json_strict(ROOT / "contracts/ptcgdap/author_strategy_release_bundle.json")
        current_release_canonical = hashlib.sha256(
            canonical_json_v1_bytes(current_release)
        ).hexdigest().upper()
        self.assertEqual(
            "8C023680073C8CD0B7A423B07B840629812B2043305EA16411765A44F7F4D1EB",
            manifest["parents"]["author_release_bundle_canonical_sha256"],
        )
        self.assertNotEqual(
            current_release_canonical,
            manifest["parents"]["author_release_bundle_canonical_sha256"],
        )
        self.assertTrue(PolicyPackageVerifier(ROOT).verify(manifest)["accepted"])

    def test_python_verifier_fails_closed_when_owned_dependency_is_missing(self) -> None:
        from scripts.ai.ptcgdap.policy_package import PolicyPackageVerifier

        verifier = PolicyPackageVerifier(ROOT)
        manifest = load_json_strict(MANIFEST)
        with patch(
            "scripts.ai.ptcgdap.policy_package._canonical_sha",
            side_effect=OSError("missing contract"),
        ):
            rejected_contract = verifier.verify(manifest)
        self.assertEqual(
            {"accepted": False, "error_code": "policy_package_contract_mismatch"},
            rejected_contract,
        )

        with patch.object(
            PolicyPackageVerifier,
            "_expected_executor",
            side_effect=OSError("missing executor"),
        ):
            rejected_executor = verifier.verify(manifest)
        self.assertEqual(
            {"accepted": False, "error_code": "policy_package_executor_mismatch"},
            rejected_executor,
        )

    def test_gdscript_verifier_is_local_only_and_builder_is_reproducible(self) -> None:
        gdscript = (ROOT / "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd").read_text(encoding="utf-8")
        for forbidden in ("HTTPClient", "HTTPRequest", "TCPServer", "StreamPeerTCP", "OS.execute("):
            self.assertNotIn(forbidden, gdscript)
        result = subprocess.run(
            [sys.executable, "tools/ptcgdap/build_policy_package_v1.py", "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
