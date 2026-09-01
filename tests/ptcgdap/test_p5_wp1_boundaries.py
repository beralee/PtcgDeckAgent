from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import re
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p5_wp1/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p5_wp1/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p4_wp6/manifest.json"
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
DATA_ROOT = ROOT / "data/ptcgdap/marnie_vertical_slice"
PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/marnie_vertical_slice.py"
GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/public/MarnieVerticalSlice.gd"
PARENT_RAW = "95FEAAC3956C3CBDC72EF68AEF8289A60F65F5FDDA7FD0038BC86374B607FE39"
PARENT_CANONICAL = "93B0F8170124AE5DD184FBD1BD17BBEC60C805A6EFC9D348C1B5ADAF5AD3369E"
PARENT_BUNDLE = "0D82BDE31BD0FA0C44527880D9D6451C2733702913708532C512F3BFF81D8BF9"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
CURRENT_BUNDLE = "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


class P5Wp1BoundaryTests(unittest.TestCase):
    def test_governance_parent_status_cursor_and_alignment_are_closed(self) -> None:
        work = load_json_strict(WORK_PACKAGE)
        if FINAL_MANIFEST.is_file():
            self.assertEqual(("shadow", "completed"), (work["status"], work["implementation_state"]))
            self.assertEqual("allowed", work["next_permitted_work"]["status"])
        else:
            self.assertEqual(("planned", "tests_first"), (work["status"], work["implementation_state"]))
            self.assertEqual("proposed_only_after_p5_wp1_exit", work["next_permitted_work"]["status"])
        self.assertEqual("P5-WP2", work["next_permitted_work"]["work_package"])
        self.assertEqual(
            {"A0":"partial / not claimed","A1":"not evaluated","A2":"not evaluated","A3":"not evaluated","A4":"not evaluated","A5":"not evaluated"},
            work["alignment_claim"],
        )
        self.assertEqual(PARENT_RAW, sha(PARENT_MANIFEST.read_bytes()))
        self.assertEqual(PARENT_CANONICAL, sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))))
        self.assertEqual(PARENT_BUNDLE, work["entry_evidence"]["parent_bundle_canonical_sha256"])
        self.assertEqual(SOURCE_LOCK, work["entry_evidence"]["source_lock_canonical_sha256"])

    def test_bundle_source_and_exact_deck_counts_are_closed(self) -> None:
        bundle = load_json_strict(CONTRACT_ROOT / "marnie_vertical_slice_bundle.json")
        source = load_json_strict(CONTRACT_ROOT / "marnie_vertical_slice_source_manifest.json")
        official = load_json_strict(DATA_ROOT / "official_deck_manifest_v1.json")
        local = load_json_strict(DATA_ROOT / "local_deck_manifest_v1.json")
        diff = load_json_strict(DATA_ROOT / "deck_identity_diff_v1.json")
        self.assertEqual(CURRENT_BUNDLE, sha(canonical_json_v1_bytes(bundle)))
        self.assertEqual(9, len(bundle["artifacts"]))
        self.assertEqual(14, len(source["inputs"]))
        self.assertEqual((60, 19, True), (official["card_count"], official["unique_card_id_count"], official["cabt_exportable"]))
        self.assertEqual((60, 28, False), (local["card_count"], local["unique_printing_count"], local["cabt_exportable"]))
        self.assertEqual((34, 26, 15, 45), (
            diff["official"]["bridged_card_count"], diff["official"]["unmapped_card_count"],
            diff["local"]["bridged_card_count"], diff["local"]["unbridged_card_count"],
        ))
        self.assertFalse(diff["same_deck"])
        self.assertFalse(diff["cabt_exportable"])

    def test_runtime_dependency_boundary_has_no_engine_live_network_process_rng_or_oracle(self) -> None:
        python_text = PYTHON_RUNTIME.read_text(encoding="utf-8")
        godot_text = GODOT_RUNTIME.read_text(encoding="utf-8")
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
        self.assertTrue(imported <= {"__future__", "copy", "pathlib", "re", "types", "typing"}, imported)
        forbidden = (
            "GameState", "GameStateMachine", "BattleScene", "CardInstance", "PokemonSlot", "AIOpponent",
            "HeadlessMatchBridge", "ShadowWholeMatchHarness", "HTTPClient", "HTTPRequest", "OS.execute",
            "subprocess", "random", "datetime", "perf_counter", "monotonic", "time.time", "Time.get_ticks",
            "eval(", "exec(", "D:\\ai\\code\\ptcgabc", "search_begin_input", "token_free_callback_hash",
            "raw_private_hash", "CardDatabase", "CardImplementationStatus", "agent(", "selected_indexes",
        )
        for token in forbidden:
            self.assertNotIn(token, python_text)
            self.assertNotIn(token, godot_text)
        resource_pattern = re.compile(r'(?:preload|load)\("(res://[^"]+)"\)')
        for resource_path in resource_pattern.findall(godot_text):
            self.assertTrue(resource_path.startswith("res://scripts/ai/ptcgdap/"), resource_path)

    def test_no_live_consumer_or_autoload_references_fixture_owner(self) -> None:
        owner_paths = {
            PYTHON_RUNTIME.resolve(),
            GODOT_RUNTIME.resolve(),
            (ROOT / "scripts/ai/ptcgdap/marnie_trajectory_replay.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarnieTrajectoryReplay.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/marnie_capability_policy.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarnieCapabilityPolicy.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/marnie_identity_projection.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarnieIdentityProjection.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/marnie_public_base.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarniePublicBase.gd").resolve(),
        }
        needles = (
            "MarnieVerticalSlice", "marnie_vertical_slice.py", "public/MarnieVerticalSlice.gd",
        )
        matches: list[str] = []
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

    def test_public_trajectory_contains_no_private_or_execution_authority(self) -> None:
        trajectory = load_json_strict(DATA_ROOT / "w0_w7_public_trajectory_v1.json")
        serialized = canonical_json_v1_bytes(trajectory).decode("utf-8")
        self.assertEqual(13, len(trajectory["frames"]))
        self.assertEqual(set(f"W{index}" for index in range(8)), {frame["window_family"] for frame in trajectory["frames"]})
        for token in (
            "search_begin_input", "raw_private_hash", "token_free_callback_hash", "container_path",
            "selected_indexes", "policy_output", "PRIVATE_MUTATION_SENTINEL", "LiveVideoPath", "TeamNames",
        ):
            self.assertNotIn(token, serialized)
        self.assertTrue(all(frame["source_action_authority"] == "not_policy_golden" for frame in trajectory["frames"]))

    def test_w2_mismatch_and_unsupported_identity_are_explicitly_fail_closed(self) -> None:
        trajectory = load_json_strict(DATA_ROOT / "w0_w7_public_trajectory_v1.json")
        capabilities = load_json_strict(DATA_ROOT / "capability_inventory_v1.json")
        w2 = next(frame for frame in trajectory["frames"] if frame["frame_id"] == "w2_setup_bench")
        self.assertEqual({"status": "rejected", "issue_code": "own_active_concealed"}, w2["current_firewall"])
        self.assertEqual("policy_allowed", w2["window"]["decision_state"])
        self.assertEqual("unsupported_by_official_payload_no_synthesis", capabilities["ability_numeric_identity"])
        self.assertTrue(all(not row["portable_ready"] for row in capabilities["capabilities"]))

    def test_authoritative_docs_keep_p5_wp1_offline_and_next_exact(self) -> None:
        combined = "\n".join(
            (ROOT / path).read_text(encoding="utf-8")
            for path in (
                "docs/ptcgdap/README.md", "docs/ptcgdap/01-official-cabt-contract.md",
                "docs/ptcgdap/03-target-architecture.md", "docs/ptcgdap/04-migration-roadmap.md",
                "docs/ptcgdap/05-validation-promotion-and-rollback.md", "docs/ptcgdap/06-first-vertical-slice.md",
                "docs/ptcgdap/07-decisions-risks-and-open-questions.md", "docs/ptcgdap/STATUS.md",
                "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
            )
        )
        source = combined if FINAL_MANIFEST.is_file() else WORK_PACKAGE.read_text(encoding="utf-8")
        self.assertIn("P5-WP1", source)
        self.assertIn("P5-WP2", source)
        self.assertIn("A0 partial / not claimed", combined)
        self.assertIn("A5", combined)


if __name__ == "__main__":
    unittest.main()
