from __future__ import annotations

import hashlib
from pathlib import Path
import re
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p4_wp3/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p4_wp3/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p4_wp2/manifest.json"
PARENT_BUNDLE = ROOT / "contracts/ptcgdap/strategic_trace_v2_bundle.json"
SOURCE_LOCK = ROOT / "docs/ptcgdap/SOURCE_LOCK.json"
EXECUTOR_BUNDLE = ROOT / "contracts/ptcgdap/restricted_base_graph_executor_bundle.json"
EXPECTED_PARENT_RAW = "D801B6CA249DCBD073E8DA748E0F8F5BA33C7EE54B815528EA7F4AF64EFA6992"
EXPECTED_PARENT_CANONICAL = "B87153325F0482C6BA1657331E5C03F92D4FC4B138FEE2A6EF402B6211EC5007"
EXPECTED_PARENT_BUNDLE = "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4"
EXPECTED_EXECUTOR_BUNDLE = "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389"
EXPECTED_SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
OWNERS = {
    "scripts/ai/ptcgdap/restricted_base_graph_executor.py",
    "scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd",
    "tools/ptcgdap/build_restricted_base_graph_executor_contract.py",
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


class P4Wp3BoundaryTests(unittest.TestCase):
    def test_governance_parent_status_cursor_and_alignment_are_closed(self) -> None:
        work = load_json_strict(WORK_PACKAGE)
        self.assertTrue(work["work_package"].startswith("P4-WP3:"))
        self.assertEqual("P4-WP4", work["next_permitted_work"]["work_package"])
        self.assertEqual(EXPECTED_PARENT_RAW, work["entry_evidence"]["parent_manifest_raw_sha256"])
        self.assertEqual(EXPECTED_PARENT_CANONICAL, work["entry_evidence"]["parent_manifest_canonical_sha256"])
        self.assertTrue(work["contracts_changed"])
        self.assertEqual("partial / not claimed", work["alignment_claim"]["A0"])
        self.assertTrue(all(work["alignment_claim"][key] == "not evaluated" for key in ("A1", "A2", "A3", "A4", "A5")))
        self.assertIn("offline", work["shadow_or_live"])
        if FINAL_MANIFEST.is_file():
            self.assertEqual(("shadow", "completed"), (work["status"], work["implementation_state"]))
            self.assertEqual("shadow", load_json_strict(FINAL_MANIFEST)["status"])
            self.assertEqual("allowed", work["next_permitted_work"]["status"])
        else:
            self.assertEqual(("planned", "not_started"), (work["status"], work["implementation_state"]))
            self.assertEqual("proposed_only_after_p4_wp3_exit", work["next_permitted_work"]["status"])

    def test_parent_bundle_source_lock_and_manifest_remain_exact(self) -> None:
        self.assertEqual(EXPECTED_PARENT_RAW, sha(PARENT_MANIFEST.read_bytes()))
        self.assertEqual(EXPECTED_PARENT_CANONICAL, sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))))
        self.assertEqual(EXPECTED_PARENT_BUNDLE, sha(canonical_json_v1_bytes(load_json_strict(PARENT_BUNDLE))))
        self.assertEqual(EXPECTED_SOURCE_LOCK, sha(canonical_json_v1_bytes(load_json_strict(SOURCE_LOCK))))
        self.assertEqual(EXPECTED_EXECUTOR_BUNDLE, sha(canonical_json_v1_bytes(load_json_strict(EXECUTOR_BUNDLE))))

    def test_executor_sources_have_no_engine_private_dynamic_or_external_dependency(self) -> None:
        forbidden = re.compile(
            r"\b(?:AIOpponent|HeadlessMatchBridge|GameStateMachine|GameState|BattleScene|CardInstance|PokemonSlot|DeckStrategy|"
            r"subprocess|requests|urllib|socket|random|time\.time|eval|exec|__import__)\b|"
            r"D:[/\\]ai[/\\]code[/\\]ptcgabc|scripts/engine|scripts/ui|_pending_choice|_dialog_data",
            re.IGNORECASE,
        )
        for relative in OWNERS:
            text = (ROOT / relative).read_text(encoding="utf-8")
            self.assertIsNone(forbidden.search(text), relative)
        runtime = (ROOT / "scripts/ai/ptcgdap/restricted_base_graph_executor.py").read_text(encoding="utf-8")
        godot = (ROOT / "scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd").read_text(encoding="utf-8")
        for token in ("search_begin_input", "token_free_callback_hash"):
            self.assertNotIn(token, runtime)
            self.assertNotIn(token, godot)
        for token in ("callable", "module", "class_path", "code_path", "network"):
            self.assertNotIn(f'"{token}"', runtime)
            self.assertNotIn(f'"{token}"', godot)

    def test_no_live_consumer_or_project_autoload_exists(self) -> None:
        needles = ("RestrictedBaseGraphExecutor", "restricted_base_graph_executor")
        allowed = {
            *OWNERS,
            "tests/ptcgdap/test_restricted_base_graph_executor_contract_builder.py",
            "tests/ptcgdap/test_restricted_base_graph_executor.py",
            "tests/ptcgdap/test_restricted_base_graph_executor_properties.py",
            "tests/ptcgdap/test_p4_wp3_boundaries.py",
            "tests/ptcgdap/godot/test_restricted_base_graph_executor.gd",
            "scripts/ai/ptcgdap/public_base_policy.py",
            "scripts/ai/ptcgdap/public/PublicBasePolicy.gd",
            "scripts/ai/ptcgdap/marnie_public_base.py",
            "scripts/ai/ptcgdap/public/MarniePublicBase.gd",
            "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd",
            # D051 verifies the immutable outer product manifest and pins the
            # executor identities; it does not import or execute the Base
            # Graph.  Treating an integrity witness as a live consumer would
            # reject the accepted no-model Windows runtime packaging lane.
            "scripts/ai/ptcgdap/policy_package.py",
            "scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd",
            # D053 is the accepted successor live executor. The manifest only
            # pins identities; the executor inherits the sealed D051 Base/IR
            # implementation and remains inside the public policy boundary.
            "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutor.gd",
            "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutorManifest.gd",
        }
        for base in (ROOT / "scripts", ROOT / "scenes"):
            if not base.exists():
                continue
            for path in base.rglob("*"):
                if not path.is_file() or path.suffix.lower() not in {".py", ".gd", ".tscn", ".tres"}:
                    continue
                relative = path.relative_to(ROOT).as_posix()
                if relative in allowed:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                self.assertFalse(any(needle in text for needle in needles), relative)
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertFalse(any(needle in project for needle in needles))
        development = (
            ROOT / "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd"
        ).read_text(encoding="utf-8")
        self.assertIn("RestrictedBaseGraphExecutor", development)
        for forbidden in ("GameState", "BattleScene", "CardInstance", "HTTPClient", "OS.execute"):
            self.assertNotIn(forbidden, development)

    def test_contract_closes_base_and_adapter_authority(self) -> None:
        profile = load_json_strict(ROOT / "contracts/ptcgdap/restricted_base_graph_executor_profile.json")
        self.assertEqual(["terminal", "mandatory", "legal_frontier"], profile["execution_contract"]["selection_precedence"])
        self.assertEqual("same_tier_ordering_hint_only", profile["execution_contract"]["adapter_authority"])
        self.assertTrue(profile["execution_contract"]["base_veto_cannot_remove_forced_indexes"])
        self.assertFalse(profile["result_contract"]["serialized_result_is_execution_authority"])
        self.assertFalse(profile["scope"]["adapter_implementation"])
        self.assertFalse(profile["scope"]["policy"])
        self.assertFalse(profile["scope"]["live_owner"])

    def test_authoritative_docs_keep_executor_offline_and_next_exact(self) -> None:
        docs = {
            path.name: path.read_text(encoding="utf-8")
            for path in (ROOT / "docs/ptcgdap").glob("*.md")
        }
        combined = "\n".join(docs.values())
        self.assertIn("P4-WP3", combined)
        self.assertIn("A0 partial / not claimed", combined)
        self.assertNotIn("P4-WP3 已完成", combined if not FINAL_MANIFEST.is_file() else "")


if __name__ == "__main__":
    unittest.main()
