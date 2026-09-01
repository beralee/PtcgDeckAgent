from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE_PATH = ROOT / "artifacts/ptcgdap/p4_wp2/work_package.json"
FINAL_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/p4_wp2/manifest.json"
PARENT_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/p4_wp1/manifest.json"
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/strategic_trace_v2.py"
GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/public/StrategicTraceV2.gd"
DEVELOPMENT_POLICY = ROOT / "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd"
EXPECTED_PARENT_RAW = "2ABDDD7DBC35C8579BAA33BF95AB8A4A9C6FA4EFDD6423E47A6EAFD8B1618C9A"
EXPECTED_PARENT_CANONICAL = "E72AC8A3B0011157675F69DC395E7DBD5FA16904C2276ED95AC502134F3C54C8"
EXPECTED_BUNDLE_CANONICAL = "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4"
EXPECTED_SOURCE_LOCK_CANONICAL = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_P4_WP1_BUNDLE = "AACFA7E2E7F914180A2B7A5C4D92D6514ACC5F4622FC95B57DC225673893F98F"
EXPECTED_OWNER_PATHS = {
    "contracts/ptcgdap/strategic_trace_v2.schema.json",
    "contracts/ptcgdap/strategic_trace_v2_profile.json",
    "contracts/ptcgdap/strategic_trace_v2_conformance_vectors.json",
    "contracts/ptcgdap/strategic_trace_v2_bundle.json",
    "scripts/ai/ptcgdap/strategic_trace_v2.py",
    "scripts/ai/ptcgdap/public/StrategicTraceV2.gd",
    "tools/ptcgdap/build_strategic_trace_v2_contract.py",
    "tests/ptcgdap/test_strategic_trace_v2_contract_builder.py",
    "tests/ptcgdap/test_strategic_trace_v2.py",
    "tests/ptcgdap/test_strategic_trace_v2_properties.py",
    "tests/ptcgdap/test_p4_wp2_boundaries.py",
    "tests/ptcgdap/test_p4_wp2_parent_snapshot.py",
    "tests/ptcgdap/godot/test_strategic_trace_v2.gd",
}


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def canonical(path: Path) -> str:
    return sha(canonical_json_v1_bytes(load_json_strict(path)))


class P4Wp2BoundaryTests(unittest.TestCase):
    def test_governance_scope_parent_status_and_cursor_are_closed(self) -> None:
        work = load_json_strict(WORK_PACKAGE_PATH)
        self.assertEqual(work["entry_evidence"]["parent_manifest_raw_sha256"], EXPECTED_PARENT_RAW)
        self.assertEqual(work["entry_evidence"]["parent_manifest_canonical_sha256"], EXPECTED_PARENT_CANONICAL)
        self.assertEqual(work["entry_evidence"]["parent_bundle_canonical_sha256"], EXPECTED_P4_WP1_BUNDLE)
        self.assertEqual(work["entry_evidence"]["parent_candidate_entry_count"], 729)
        self.assertEqual(work["entry_evidence"]["parent_candidate_canonical_sha256"], "9BED8F78D7D9135A5CC04974AE7479A5E16876875FBEA237DDD00C58C29A6C60")
        self.assertTrue(work["contracts_changed"])
        self.assertEqual(work["shadow_or_live"], "shadow, offline-only trace and IR contract core")
        self.assertEqual(work["alignment_claim"]["A0"], "partial / not claimed")
        self.assertTrue(all(work["alignment_claim"][level] == "not evaluated" for level in ("A1", "A2", "A3", "A4", "A5")))
        owner_paths = set().union(
            work["files_allowed"]["contracts"],
            work["files_allowed"]["implementation"],
            work["files_allowed"]["tests"],
        )
        self.assertEqual(EXPECTED_OWNER_PATHS, owner_paths)
        if FINAL_MANIFEST_PATH.exists():
            self.assertEqual(("shadow", "completed"), (work["status"], work["implementation_state"]))
            self.assertEqual("shadow", load_json_strict(FINAL_MANIFEST_PATH)["status"])
            self.assertEqual("allowed", work["next_permitted_work"]["status"])
        else:
            self.assertEqual(("planned", "not_started"), (work["status"], work["implementation_state"]))
            self.assertEqual("proposed_only_after_p4_wp2_exit", work["next_permitted_work"]["status"])

    def test_parent_bundle_source_lock_and_manifest_remain_exact(self) -> None:
        self.assertEqual(EXPECTED_PARENT_RAW, sha(PARENT_MANIFEST_PATH.read_bytes()))
        self.assertEqual(EXPECTED_PARENT_CANONICAL, canonical(PARENT_MANIFEST_PATH))
        self.assertEqual(EXPECTED_P4_WP1_BUNDLE, canonical(CONTRACT_ROOT / "strategic_context_v18_bundle.json"))
        self.assertEqual(EXPECTED_SOURCE_LOCK_CANONICAL, canonical(ROOT / "docs/ptcgdap/SOURCE_LOCK.json"))

    def test_bundle_is_exact_subordinate_and_has_no_self_cycle(self) -> None:
        path = CONTRACT_ROOT / "strategic_trace_v2_bundle.json"
        bundle = load_json_strict(path)
        self.assertEqual(EXPECTED_BUNDLE_CANONICAL, canonical(path))
        self.assertEqual(EXPECTED_P4_WP1_BUNDLE, bundle["parent_strategic_context_bundle_canonical_sha256"])
        self.assertEqual(EXPECTED_SOURCE_LOCK_CANONICAL, bundle["source_lock_canonical_sha256"])
        expected = {
            "schema": "strategic_trace_v2.schema.json",
            "profile": "strategic_trace_v2_profile.json",
            "vectors": "strategic_trace_v2_conformance_vectors.json",
        }
        self.assertEqual(list(expected), [entry["id"] for entry in bundle["artifacts"]])
        for entry in bundle["artifacts"]:
            self.assertEqual(f"contracts/ptcgdap/{expected[entry['id']]}", entry["path"])
            self.assertEqual(canonical(CONTRACT_ROOT / expected[entry["id"]]), entry["canonical_sha256"])
        self.assertNotIn(EXPECTED_BUNDLE_CANONICAL, canonical_json_v1_bytes(bundle).decode("utf-8"))

    def test_runtime_dependencies_are_public_pure_and_nonexecuting(self) -> None:
        python_text = PYTHON_RUNTIME.read_text(encoding="utf-8")
        godot_text = GODOT_RUNTIME.read_text(encoding="utf-8")
        tree = ast.parse(python_text)
        imported: set[str] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imported.update(alias.name for alias in node.names)
            elif isinstance(node, ast.ImportFrom):
                imported.add(node.module or "")
        allowed_roots = {"__future__", "copy", "dataclasses", "hashlib", "pathlib", "re", "types", "typing"}
        allowed_relative = {"cabt_tree_hash", "source_lock", "strategic_context_v18"}
        self.assertTrue(all(name.split(".")[0] in allowed_roots or name in allowed_relative or name == "" for name in imported), imported)
        forbidden = (
            "GameState",
            "GameStateMachine",
            "BattleScene",
            "CardInstance",
            "PokemonSlot",
            "AIOpponent",
            "HeadlessMatchBridge",
            "DeckStrategy",
            "ptcgabc",
            "subprocess",
            "socket",
            "requests",
            "urllib",
            "random",
            "exec(",
            "eval(",
            "OS.execute",
            "HTTPClient",
            "FileAccess.WRITE",
        )
        for token in forbidden:
            self.assertNotIn(token, python_text)
            self.assertNotIn(token, godot_text)
        dangerous_calls = {
            node.func.id
            for node in ast.walk(tree)
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in {"exec", "eval", "compile", "__import__"}
        }
        self.assertFalse(dangerous_calls, dangerous_calls)

    def test_no_live_consumer_or_autoload_references_new_owner(self) -> None:
        owner_paths = {
            PYTHON_RUNTIME.resolve(),
            GODOT_RUNTIME.resolve(),
            (ROOT / "scripts/ai/ptcgdap/restricted_base_graph_executor.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public_base_policy.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/PublicBasePolicy.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/marnie_public_base.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarniePublicBase.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/author_strategy_match_host.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd").resolve(),
            DEVELOPMENT_POLICY.resolve(),
            # D053's verifier is an exact hash/resource witness. It names the
            # sealed trace implementation but never imports or executes it.
            (ROOT / "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutorManifest.gd").resolve(),
        }
        needles = ("StrategicTraceV2", "RestrictedBaseGraphIR", "strategic_trace_v2.py", "public/StrategicTraceV2.gd")
        matches = []
        for base in (ROOT / "scripts", ROOT / "scenes"):
            if not base.exists():
                continue
            for path in base.rglob("*"):
                if not path.is_file() or path.suffix.lower() not in {".py", ".gd", ".tscn", ".tres"} or path.resolve() in owner_paths:
                    continue
                text = path.read_text(encoding="utf-8", errors="replace")
                if any(needle in text for needle in needles):
                    matches.append(path.relative_to(ROOT).as_posix())
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertFalse(matches, matches)
        self.assertFalse(any(needle in project for needle in needles))
        development = DEVELOPMENT_POLICY.read_text(encoding="utf-8")
        self.assertIn("public/StrategicTraceV2.gd", development)
        self.assertIn("public/RestrictedBaseGraphExecutor.gd", development)
        for forbidden in ("GameState", "BattleScene", "CardInstance", "HTTPClient", "OS.execute"):
            self.assertNotIn(forbidden, development)

    def test_contract_closes_operator_owner_config_and_trace_authority(self) -> None:
        profile = load_json_strict(CONTRACT_ROOT / "strategic_trace_v2_profile.json")
        vectors = load_json_strict(CONTRACT_ROOT / "strategic_trace_v2_conformance_vectors.json")
        self.assertEqual(6, len(profile["ir_contract"]["base_operators_in_required_order"]))
        self.assertEqual(3, len(profile["ir_contract"]["adapter_operators"]))
        self.assertEqual(4, len(profile["ir_contract"]["required_capabilities"]))
        self.assertFalse(profile["ir_contract"]["serialized_result_is_execution_authority"])
        self.assertFalse(profile["trace_contract"]["serialized_result_is_execution_authority"])
        self.assertFalse(profile["scope"]["ir_executor"])
        self.assertFalse(profile["scope"]["adapter"])
        self.assertFalse(profile["scope"]["policy"])
        self.assertEqual((2, 7, 2, 7), tuple(len(vectors[key]) for key in ("ir_cases", "ir_rejections", "trace_cases", "trace_rejections")))
        text = str(vectors["trace_cases"])
        for sentinel in vectors["private_sentinels"]:
            self.assertNotIn(sentinel, text)

    def test_architecture_cursor_does_not_overclaim_execution_or_alignment(self) -> None:
        paths = (
            ROOT / "docs/ptcgdap/README.md",
            ROOT / "docs/ptcgdap/STATUS.md",
            ROOT / "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
            ROOT / "docs/ptcgdap/04-migration-roadmap.md",
        )
        docs = {path.name: path.read_text(encoding="utf-8") for path in paths}
        joined = "\n".join(docs.values())
        if FINAL_MANIFEST_PATH.exists():
            self.assertIn("P4-WP3", docs["STATUS.md"])
            self.assertIn(EXPECTED_BUNDLE_CANONICAL, joined)
        else:
            self.assertIn("P4-WP2", docs["STATUS.md"])
        for prohibited in ("A0 complete", "A1 passed", "A2 passed", "A3 passed", "A4 passed", "A5 passed", "P4 complete"):
            self.assertNotIn(prohibited, joined)


if __name__ == "__main__":
    unittest.main()
