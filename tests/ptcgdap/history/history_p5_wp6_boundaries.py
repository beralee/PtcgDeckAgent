from __future__ import annotations

import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK = load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp6/work_package.json")
MANIFEST_PATH = ROOT / "artifacts/ptcgdap/p5_wp6/manifest.json"
EXPECTED_PARENT_MANIFEST_RAW = "F6EB27CC3CEB47B6FFA416137AC59BC0556C772A841CEB0C091656332776C256"
EXPECTED_PARENT_MANIFEST_CANONICAL = "04C37054F6F277BE0EC82DFE748D7479A54493D2200943E908B595B82D9EDC3C"
EXPECTED_BUNDLE = "67EBA6348277001692942FD58E8D1B9D50C54F0FFC783D8802BA3CCB45691105"
PARENT_BUNDLES = WORK["entry_evidence"]
P4_CACHE_FILES = [
    "scripts/ai/ptcgdap/public/StrategicContextV18.gd",
    "scripts/ai/ptcgdap/public/StrategicTraceV2.gd",
    "scripts/ai/ptcgdap/public/PublicDeckAdapter.gd",
    "scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd",
    "scripts/ai/ptcgdap/public/PublicBasePolicy.gd",
]


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def canonical(path: str) -> str:
    return sha(canonical_json_v1_bytes(load_json_strict(ROOT / path)))


class P5Wp6BoundaryTests(unittest.TestCase):
    def test_work_package_scope_alignment_and_cursor_are_exact(self) -> None:
        expected_status = "shadow" if MANIFEST_PATH.is_file() else "planned"
        expected_state = "completed" if MANIFEST_PATH.is_file() else "not_started"
        self.assertEqual(expected_status, WORK["status"])
        self.assertEqual(expected_state, WORK["implementation_state"])
        self.assertEqual("shadow, offline-only public Base/macro orchestration audit", WORK["shadow_or_live"])
        self.assertEqual("partial / not claimed", WORK["alignment_claim"]["A0"])
        self.assertEqual({"not evaluated"}, {WORK["alignment_claim"][f"A{index}"] for index in range(1, 6)})
        self.assertEqual("P5-WP7", WORK["next_permitted_work"]["work_package"])
        self.assertFalse(WORK["next_permitted_work"]["status"] == "allowed" and not MANIFEST_PATH.is_file())

    def test_parent_manifest_and_all_parent_contract_hashes_are_unchanged(self) -> None:
        parent_path = ROOT / "artifacts/ptcgdap/p5_wp5/manifest.json"
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, sha(parent_path.read_bytes()))
        self.assertEqual(EXPECTED_PARENT_MANIFEST_CANONICAL, canonical("artifacts/ptcgdap/p5_wp5/manifest.json"))
        expected = {
            "contracts/ptcgdap/marnie_prompt_broker_bundle.json": PARENT_BUNDLES["parent_prompt_broker_bundle_canonical_sha256"],
            "contracts/ptcgdap/marnie_trajectory_replay_bundle.json": PARENT_BUNDLES["parent_trajectory_bundle_canonical_sha256"],
            "contracts/ptcgdap/public_base_policy_bundle.json": PARENT_BUNDLES["public_base_policy_bundle_canonical_sha256"],
            "contracts/ptcgdap/public_deck_adapter_bundle.json": PARENT_BUNDLES["public_deck_adapter_bundle_canonical_sha256"],
            "contracts/ptcgdap/restricted_base_graph_executor_bundle.json": PARENT_BUNDLES["restricted_base_graph_bundle_canonical_sha256"],
            "contracts/ptcgdap/strategic_context_v18_bundle.json": PARENT_BUNDLES["strategic_context_bundle_canonical_sha256"],
            "contracts/ptcgdap/strategic_trace_v2_bundle.json": PARENT_BUNDLES["strategic_trace_bundle_canonical_sha256"],
            "contracts/ptcgdap/cabt_public_firewall_bundle.json": PARENT_BUNDLES["public_firewall_bundle_canonical_sha256"],
        }
        for path, digest in expected.items():
            with self.subTest(path=path):
                self.assertEqual(digest, canonical(path))
        self.assertEqual(EXPECTED_BUNDLE, canonical("contracts/ptcgdap/marnie_public_base_bundle.json"))

    def test_owner_dependencies_are_public_pure_and_have_no_live_consumer(self) -> None:
        python_owner = (ROOT / "scripts/ai/ptcgdap/marnie_public_base.py").read_text(encoding="utf-8")
        godot_owner = (ROOT / "scripts/ai/ptcgdap/public/MarniePublicBase.gd").read_text(encoding="utf-8")
        for token in ("GameState", "GameStateMachine", "BattleScene", "CardInstance", "PokemonSlot", "AIOpponent", "DeckStrategy", "_pending_choice", "_dialog_data"):
            self.assertNotIn(token, python_owner)
            self.assertNotIn(token, godot_owner)
        for token in ("subprocess", "socket", "requests", "urllib", "http://", "https://", "D:\\ai\\code\\ptcgabc"):
            self.assertNotIn(token, python_owner)
            self.assertNotIn(token, godot_owner)
        owner_paths = {
            (ROOT / "scripts/ai/ptcgdap/marnie_public_base.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarniePublicBase.gd").resolve(),
        }
        offline_p5_wp7_consumers = {
            (ROOT / "scripts/ai/ptcgdap/marnie_portable_policy.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarniePortablePolicy.gd").resolve(),
        }
        for base in (ROOT / "scripts", ROOT / "scenes"):
            if not base.exists():
                continue
            for path in base.rglob("*"):
                if (
                    path.suffix.lower() not in {".py", ".gd", ".tscn", ".tres"}
                    or path.resolve() in owner_paths
                    or path.resolve() in offline_p5_wp7_consumers
                ):
                    continue
                self.assertNotIn("MarniePublicBase", path.read_text(encoding="utf-8", errors="ignore"), str(path))
        self.assertTrue(all(path.is_file() for path in offline_p5_wp7_consumers))
        self.assertNotIn("MarniePublicBase", (ROOT / "project.godot").read_text(encoding="utf-8"))

    def test_default_contract_cache_is_scoped_and_tamper_roots_stay_uncached(self) -> None:
        for relative in P4_CACHE_FILES:
            text = (ROOT / relative).read_text(encoding="utf-8")
            self.assertIn("static var _DEFAULT_CONTRACT_CACHE", text, relative)
            self.assertIn("if root == DEFAULT_ROOT and bool(_DEFAULT_CONTRACT_CACHE.get(\"ok\", false))", text, relative)
            self.assertIn("if root == DEFAULT_ROOT:", text, relative)
            self.assertNotIn("user://", text[text.index("static func _load_contracts"):text.index("static func _load_bytes")], relative)
        contract_set = (ROOT / "scripts/ai/ptcgdap/cabt/CabtContractSet.gd").read_text(encoding="utf-8")
        self.assertIn("_TRUSTED_INSTANCE_REGISTRY", contract_set)
        self.assertIn('entry.get("selection_profile") != _selection_profile', contract_set)
        self.assertNotIn("_canonical_json_value_sha256(\n\t\t\truntime_documents", contract_set)

    def test_macro_catalog_numeric_scope_and_evidence_classes_are_closed(self) -> None:
        profile = load_json_strict(ROOT / "contracts/ptcgdap/marnie_public_base_profile.json")
        self.assertEqual(6, len(profile["macro_catalog"]))
        self.assertEqual(
            {"marnie.engine.poffin_primary", "marnie.engine.spikemuth_tutor", "marnie.engine.evolve_grimmsnarl", "marnie.energy.punk_up", "marnie.prize.shadow_bullet", "marnie.recover.night_stretcher"},
            {item["macro_id"] for item in profile["macro_catalog"]},
        )
        self.assertEqual(13, sum(item["evidence_class"] == "source_locked_production_frame" for item in profile["case_catalog"]))
        self.assertEqual(3, sum(item["evidence_class"] == "offline_seeded_extension" for item in profile["case_catalog"]))
        serialized = canonical_json_v1_bytes(profile["macro_catalog"])
        for token in (b"name", b"text", b"image", b"CardData", b"instance_id"):
            self.assertNotIn(token, serialized)

    def test_snapshot_covers_every_modified_parent_runtime(self) -> None:
        primary = load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp6/parent_snapshot/manifest.json")
        supplemental = load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp6/supplemental_parent_snapshot/manifest.json")
        restore = {entry["original_path"] for entry in [*primary["files"], *supplemental["files"]]}
        self.assertEqual(set(WORK["files_allowed"]["existing_runtime_optimizations"]), restore & set(WORK["files_allowed"]["existing_runtime_optimizations"]))
        self.assertFalse({entry["original_path"] for entry in primary["files"]} & {entry["original_path"] for entry in supplemental["files"]})


if __name__ == "__main__":
    unittest.main()
