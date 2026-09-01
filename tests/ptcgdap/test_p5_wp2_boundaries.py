from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import re
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p5_wp2/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p5_wp2/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p5_wp1/manifest.json"
PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/marnie_trajectory_replay.py"
GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/public/MarnieTrajectoryReplay.gd"
REPLAY = ROOT / "data/ptcgdap/marnie_vertical_slice/w0_w7_firewall_replay_v1.json"
CURRENT_BUNDLE = "E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F"
PARENT_RAW = "F87F642406C649425D248607B9F9B6AFEC9E3430D2184269B08B7F9A093FAD34"
PARENT_CANONICAL = "673E47F897028AC4BA322818047290BBE5D5FC28E304918F32A73410A520F944"
PARENT_FIXTURE = "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"
BASE_FIREWALL = "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


class P5Wp2BoundaryTests(unittest.TestCase):
    def test_governance_parent_cursor_and_alignment_are_exact(self) -> None:
        work = load_json_strict(WORK_PACKAGE)
        if FINAL_MANIFEST.is_file():
            self.assertEqual(("shadow", "completed"), (work["status"], work["implementation_state"]))
            self.assertEqual("allowed", work["next_permitted_work"]["status"])
        else:
            self.assertEqual(("planned", "tests_first"), (work["status"], work["implementation_state"]))
            self.assertEqual("proposed_only_after_p5_wp2_exit", work["next_permitted_work"]["status"])
        self.assertEqual("P5-WP3", work["next_permitted_work"]["work_package"])
        self.assertEqual(
            {"A0":"partial / not claimed","A1":"not evaluated","A2":"not evaluated","A3":"not evaluated","A4":"not evaluated","A5":"not evaluated"},
            work["alignment_claim"],
        )
        self.assertEqual(PARENT_RAW, sha(PARENT_MANIFEST.read_bytes()))
        self.assertEqual(PARENT_CANONICAL, sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))))
        self.assertEqual(PARENT_FIXTURE, work["entry_evidence"]["parent_fixture_bundle_canonical_sha256"])
        self.assertEqual(BASE_FIREWALL, work["entry_evidence"]["unchanged_p2_firewall_bundle_canonical_sha256"])

    def test_bundle_overlay_and_replay_scope_are_exact_and_non_authoritative(self) -> None:
        bundle = load_json_strict(ROOT / "contracts/ptcgdap/marnie_trajectory_replay_bundle.json")
        replay = load_json_strict(REPLAY)
        self.assertEqual(CURRENT_BUNDLE, sha(canonical_json_v1_bytes(bundle)))
        self.assertEqual(4, len(bundle["artifacts"]))
        self.assertEqual(13, len(replay["frames"]))
        self.assertFalse(replay["production_actions_are_policy_goldens"])
        self.assertFalse(replay["execution_authority"])
        w2 = replay["frames"][2]
        self.assertEqual(("w2_setup_bench", "setup_bench_concealment_v1", [None]), (w2["frame_id"], w2["compatibility_rule"], w2["own_active"]))

    def test_runtime_dependencies_have_no_live_engine_network_process_rng_or_oracle(self) -> None:
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
        self.assertTrue(imported <= {"__future__","copy","hashlib","json","pathlib","re","struct","types","typing"}, imported)
        forbidden = (
            "GameState", "GameStateMachine", "BattleScene", "CardInstance", "PokemonSlot", "AIOpponent",
            "HeadlessMatchBridge", "HTTPClient", "HTTPRequest", "OS.execute", "subprocess", "random",
            "datetime", "perf_counter", "monotonic", "time.time", "Time.get_ticks", "eval(", "exec(",
            "D:\\ai\\code\\ptcgabc", "raw_private_hash", "token_free_callback_hash", "selected_indexes",
        )
        for token in forbidden:
            self.assertNotIn(token, python_text)
            self.assertNotIn(token, godot_text)
        for resource in re.findall(r'(?:preload|load)\("(res://[^"]+)"\)', godot_text):
            self.assertTrue(resource.startswith("res://scripts/ai/ptcgdap/"), resource)

    def test_no_live_consumer_or_autoload_references_replay_owner(self) -> None:
        owners = {
            PYTHON_RUNTIME.resolve(), GODOT_RUNTIME.resolve(),
            (ROOT / "scripts/ai/ptcgdap/marnie_capability_policy.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarnieCapabilityPolicy.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/marnie_identity_projection.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarnieIdentityProjection.gd").resolve(),
        }
        needles = ("MarnieTrajectoryReplay", "marnie_trajectory_replay.py", "public/MarnieTrajectoryReplay.gd")
        matches: list[str] = []
        for base in (ROOT / "scripts", ROOT / "scenes"):
            if not base.exists():
                continue
            for path in base.rglob("*"):
                if not path.is_file() or path.suffix.lower() not in {".py",".gd",".tscn",".tres"} or path.resolve() in owners:
                    continue
                text = path.read_text(encoding="utf-8", errors="replace")
                if any(needle in text for needle in needles):
                    matches.append(path.relative_to(ROOT).as_posix())
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertFalse(matches, matches)
        self.assertFalse(any(needle in project for needle in needles))

    def test_serialized_replay_contains_no_private_or_execution_payload(self) -> None:
        serialized = canonical_json_v1_bytes(load_json_strict(REPLAY)).decode("utf-8")
        for token in (
            "search_begin_input", "raw_private_hash", "token_free_callback_hash", "container_path",
            "selected_indexes", "policy_output", "PRIVATE_MUTATION_SENTINEL", "LiveVideoPath", "TeamNames",
        ):
            self.assertNotIn(token, serialized)


if __name__ == "__main__":
    unittest.main()
