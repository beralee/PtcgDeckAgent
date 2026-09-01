from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p4_wp4/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p4_wp4/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p4_wp3/manifest.json"
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/public_deck_adapter.py"
GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/public/PublicDeckAdapter.gd"
PARENT_RAW = "9F941CEDC4A721C55EBF9F42B2528D9916A29A44B33BDDE31616A603FBBCB2AC"
PARENT_CANONICAL = "2B7672E1BF4A448111A1A03BE10AA6BBFED0C16A97BA7CAF8AAB8A90244A2D8C"
PARENT_BUNDLE = "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class P4Wp4BoundaryTests(unittest.TestCase):
    def test_governance_parent_status_cursor_and_alignment_are_closed(self) -> None:
        work = load_json_strict(WORK_PACKAGE)
        if FINAL_MANIFEST.is_file():
            self.assertEqual(("shadow", "completed"), (work["status"], work["implementation_state"]))
            self.assertEqual("allowed", work["next_permitted_work"]["status"])
        else:
            self.assertEqual(("planned", "not_started"), (work["status"], work["implementation_state"]))
            self.assertEqual("proposed_only_after_p4_wp4_exit", work["next_permitted_work"]["status"])
        self.assertEqual("P4-WP5", work["next_permitted_work"]["work_package"])
        self.assertEqual({"A0":"partial / not claimed","A1":"not evaluated","A2":"not evaluated","A3":"not evaluated","A4":"not evaluated","A5":"not evaluated"}, work["alignment_claim"])
        self.assertEqual(PARENT_RAW, sha(PARENT_MANIFEST.read_bytes()))
        self.assertEqual(PARENT_CANONICAL, sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))))
        self.assertEqual(PARENT_BUNDLE, work["entry_evidence"]["parent_bundle_canonical_sha256"])
        self.assertEqual(SOURCE_LOCK, work["entry_evidence"]["source_lock_canonical_sha256"])

    def test_contract_closes_public_predicates_and_proposal_authority(self) -> None:
        profile = load_json_strict(CONTRACT_ROOT / "public_deck_adapter_profile.json")
        bundle = load_json_strict(CONTRACT_ROOT / "public_deck_adapter_bundle.json")
        self.assertEqual(PARENT_BUNDLE, profile["parent_bundle_canonical_sha256"])
        self.assertEqual(PARENT_BUNDLE, bundle["parent_bundle_canonical_sha256"])
        self.assertEqual(7, len(profile["adapter_contract"]["goal_stages"]))
        self.assertEqual(3, len(profile["adapter_contract"]["operators"]))
        self.assertEqual(7, len(profile["adapter_contract"]["predicate_fields"]))
        self.assertEqual("same_base_tier_ordering_hint_only", profile["adapter_contract"]["proposal_authority"])
        self.assertTrue(profile["result_contract"]["proposal_may_not_filter_legality_or_forced_indexes"])
        self.assertFalse(profile["result_contract"]["serialized_result_is_execution_authority"])

    def test_runtime_dependency_boundary_has_no_engine_private_or_dynamic_code(self) -> None:
        python_text = PYTHON_RUNTIME.read_text(encoding="utf-8")
        godot_text = GODOT_RUNTIME.read_text(encoding="utf-8") if GODOT_RUNTIME.is_file() else ""
        tree = ast.parse(python_text)
        imported = {
            alias.name.split(".")[0]
            for node in ast.walk(tree)
            if isinstance(node, ast.Import)
            for alias in node.names
        }
        imported.update(
            (node.module or "").split(".")[0]
            for node in ast.walk(tree)
            if isinstance(node, ast.ImportFrom) and node.level == 0
        )
        self.assertTrue(imported <= {"__future__", "copy", "dataclasses", "hashlib", "pathlib", "re", "types", "typing"}, imported)
        forbidden = (
            "GameState", "GameStateMachine", "BattleScene", "CardInstance", "PokemonSlot", "AIOpponent",
            "HeadlessMatchBridge", "search_begin_input", "token_free_callback_hash", "raw_private_hash",
            "display_name", "localized_name", "get_instance_id", "ObjectID", "HTTPClient", "OS.execute",
            "subprocess", "random", "eval(", "exec(", "D:\\ai\\code\\ptcgabc",
        )
        for token in forbidden:
            self.assertNotIn(token, python_text)
            self.assertNotIn(token, godot_text)

    def test_no_live_consumer_or_autoload_references_adapter_owner(self) -> None:
        owner_paths = {
            PYTHON_RUNTIME.resolve(),
            GODOT_RUNTIME.resolve(),
            (ROOT / "scripts/ai/ptcgdap/public_base_policy.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/PublicBasePolicy.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/marnie_public_base.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarniePublicBase.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/author_strategy_match_host.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/host/godot/AuthorStrategyShadowPrompt.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd").resolve(),
            # D053's manifest names the sealed adapter only as an exact
            # implementation identity; it is not a second proposal owner.
            (ROOT / "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutorManifest.gd").resolve(),
        }
        needles = ("PublicDeckAdapterCompiler", "PublicDeckAdapterProposer", "public_deck_adapter.py", "public/PublicDeckAdapter.gd")
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
        development = (
            ROOT / "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd"
        ).read_text(encoding="utf-8")
        self.assertIn("PublicDeckAdapter", development)
        for forbidden in ("GameState", "BattleScene", "CardInstance", "HTTPClient", "OS.execute"):
            self.assertNotIn(forbidden, development)

    def test_authoritative_docs_keep_adapter_offline_and_next_exact(self) -> None:
        combined = "\n".join(
            (ROOT / path).read_text(encoding="utf-8")
            for path in (
                "docs/ptcgdap/README.md",
                "docs/ptcgdap/01-official-cabt-contract.md",
                "docs/ptcgdap/03-target-architecture.md",
                "docs/ptcgdap/04-migration-roadmap.md",
                "docs/ptcgdap/05-validation-promotion-and-rollback.md",
                "docs/ptcgdap/06-first-vertical-slice.md",
                "docs/ptcgdap/07-decisions-risks-and-open-questions.md",
                "docs/ptcgdap/STATUS.md",
                "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
            )
        )
        self.assertIn("P4-WP4", combined)
        self.assertIn("P4-WP5", combined if FINAL_MANIFEST.is_file() else (ROOT / "artifacts/ptcgdap/p4_wp4/work_package.json").read_text(encoding="utf-8"))
        self.assertIn("A0 partial / not claimed", combined)
        self.assertIn("A5", combined)


if __name__ == "__main__":
    unittest.main()
