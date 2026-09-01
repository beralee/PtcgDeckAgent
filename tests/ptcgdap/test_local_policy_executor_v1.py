from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
PARENT_MANIFEST = ROOT / "data/ptcgdap/marnie_windows_policy_package_v1.json"
PARENT_CANONICAL_SHA256 = "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC"
SCHEMA = ROOT / "contracts/ptcgdap/local_policy_executor_v1.schema.json"
PROFILE = ROOT / "contracts/ptcgdap/local_policy_executor_v1_profile.json"
MANIFEST = ROOT / "data/ptcgdap/marnie_windows_local_policy_executor_v1.json"
BUNDLE = ROOT / "contracts/ptcgdap/local_policy_executor_v1_bundle.json"
BUILDER = ROOT / "tools/ptcgdap/build_local_policy_executor_v1.py"
EXECUTOR = ROOT / "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutor.gd"
VERIFIER = ROOT / "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutorManifest.gd"
OWNER = ROOT / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLocalExecutorBattleOwner.gd"
FACTORY = ROOT / "scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd"
GODOT_TEST = ROOT / "tests/ptcgdap/godot/test_local_policy_executor.gd"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class LocalPolicyExecutorV1Tests(unittest.TestCase):
    def test_contract_runtime_builder_owner_and_godot_suite_exist(self) -> None:
        for path in (SCHEMA, PROFILE, MANIFEST, BUNDLE, BUILDER, EXECUTOR, VERIFIER, OWNER, GODOT_TEST):
            self.assertTrue(path.is_file(), path.relative_to(ROOT).as_posix())

    def test_parent_manifest_remains_the_exact_d051_immutable_byte_owner(self) -> None:
        self.assertEqual(
            PARENT_CANONICAL_SHA256,
            sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))),
        )

    def test_schema_manifest_profile_and_bundle_close_the_runtime_resource_set(self) -> None:
        schema = load_json_strict(SCHEMA)
        profile = load_json_strict(PROFILE)
        manifest = load_json_strict(MANIFEST)
        bundle = load_json_strict(BUNDLE)
        Draft202012Validator.check_schema(schema)
        errors = sorted(Draft202012Validator(schema).iter_errors(manifest), key=lambda item: list(item.path))
        self.assertEqual([], errors)
        self.assertEqual("local_policy_executor_v1", manifest["document_type"])
        self.assertEqual("ptcgdap-local-policy-executor-v1", manifest["executor_id"])
        self.assertEqual(PARENT_CANONICAL_SHA256, manifest["parent_policy_package"]["canonical_sha256"])
        self.assertEqual("none", manifest["model"]["learned_model"])
        self.assertEqual("none", manifest["model"]["backend"])
        self.assertEqual("deterministic_same_window", manifest["fallback"]["mode"])
        self.assertFalse(manifest["fallback"]["classic_raw_state"])
        self.assertFalse(manifest["fallback"]["remote"])
        self.assertEqual(0, manifest["fallback"]["unexpected_fallback_expected"])
        paths = [row["path"] for row in manifest["resources"]]
        self.assertEqual(len(paths), len(set(paths)))
        self.assertEqual(sorted(paths), paths)
        for required in (
            "contracts/ptcgdap/cabt_contract_bundle.json",
            "contracts/ptcgdap/card_id_catalog_bundle.json",
            "policy/adapter.json",
            "policy/config.json",
            "policy/policy_ir.json",
            "policy/weights.bin",
        ):
            self.assertIn(required, paths)
        artifacts = {row["path"]: row for row in bundle["artifacts"]}
        for path in (SCHEMA, PROFILE, MANIFEST):
            relative = path.relative_to(ROOT).as_posix()
            self.assertEqual(sha(canonical_json_v1_bytes(load_json_strict(path))), artifacts[relative]["canonical_sha256"])
        self.assertEqual(profile["executor_id"], manifest["executor_id"])

    def test_builder_is_reproducible_and_factory_uses_the_new_owner(self) -> None:
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--check"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        factory = FACTORY.read_text(encoding="utf-8")
        self.assertIn("PtcgDAPAuthorLocalExecutorBattleOwner.gd", factory)
        self.assertNotIn(
            'const AuthorDevelopmentOwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")',
            factory,
        )

    def test_policy_boundary_has_no_engine_remote_or_process_escape(self) -> None:
        executor = EXECUTOR.read_text(encoding="utf-8")
        verifier = VERIFIER.read_text(encoding="utf-8")
        for forbidden in (
            "GameState",
            "GameStateMachine",
            "BattleScene",
            "CardInstance",
            "PokemonSlot",
            "HTTPRequest",
            "HTTPClient",
            "TCPServer",
            "PacketPeer",
            "OS.execute",
            "OS.create_process",
        ):
            self.assertNotIn(forbidden, executor)
            self.assertNotIn(forbidden, verifier)
        self.assertIn("RestrictedBaseGraphExecutor.gd", executor)
        self.assertIn("current_window_indexes_only", verifier)

    def test_runtime_constants_pin_the_builder_owned_source_hashes(self) -> None:
        manifest = load_json_strict(MANIFEST)
        verifier = VERIFIER.read_text(encoding="utf-8")
        constants = {
            match.group(1): match.group(2)
            for match in re.finditer(r'const ([A-Z_]+_SHA256) := "([0-9A-F]{64})"', verifier)
        }
        roles = {row["role"]: row for row in manifest["implementation"]}
        expected = {
            "ENGINE_ACTION_EXECUTOR_SHA256": "engine_action_executor",
            "INHERITED_POLICY_BASE_SHA256": "inherited_policy_base",
            "LOCAL_POLICY_EXECUTOR_SHA256": "local_policy_executor",
            "MATCH_OWNER_SHA256": "match_owner",
            "PUBLIC_DECK_ADAPTER_SHA256": "public_deck_adapter",
            "RESTRICTED_BASE_EXECUTOR_SHA256": "restricted_base_executor",
            "STRATEGIC_TRACE_COMPILER_SHA256": "strategic_trace_compiler",
        }
        for constant, role in expected.items():
            self.assertEqual(roles[role]["raw_sha256"], constants.get(constant), constant)

    def test_runtime_integer_coercion_rejects_near_integral_floats(self) -> None:
        verifier = VERIFIER.read_text(encoding="utf-8")
        self.assertNotIn("is_equal_approx(float(value), floor(float(value)))", verifier)
        self.assertIn("is_finite(float(value))", verifier)
        self.assertIn("float(value) == floor(float(value))", verifier)


if __name__ == "__main__":
    unittest.main()
