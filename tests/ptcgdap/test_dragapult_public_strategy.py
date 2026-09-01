from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.dragapult_public_strategy import (
    DragapultPublicStrategy,
    DragapultPublicStrategyError,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tools.ptcgdap.build_dragapult_python_strategy_contract import (
    ARTIFACT_PATHS,
    CARD_ID_DOMAIN,
    DECK_ID,
    OPPONENT_DECK_ID,
    PROFILE_ID,
    build_documents,
)


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DECK = ROOT / "data/bundled_user/decks/800018499.json"
OPPONENT_DECK = ROOT / "data/bundled_user/decks/575720.json"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def option(
    index: int,
    kind: str,
    *,
    card_uid: str | None = None,
    source_uid: str | None = None,
    target_uid: str | None = None,
    target_remaining_hp: int | None = None,
    target_prize_value: int | None = None,
    attached_energy_count: int | None = None,
    attack_index: int | None = None,
    tags: list[str] | None = None,
) -> dict[str, object]:
    return {
        "index": index,
        "kind": kind,
        "card_uid": card_uid,
        "source_uid": source_uid,
        "target_uid": target_uid,
        "target_remaining_hp": target_remaining_hp,
        "target_prize_value": target_prize_value,
        "attached_energy_count": attached_energy_count,
        "attack_index": attack_index,
        "tags": [] if tags is None else tags,
    }


def frame(prompt_kind: str, options: list[dict[str, object]], *, sequence: int = 1) -> dict[str, object]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "strategy_id": "ptcgdap.dragapult.18.0.python-public-v1",
        "card_id_domain": CARD_ID_DOMAIN,
        "sequence": sequence,
        "seat": 0,
        "prompt_kind": prompt_kind,
        "source": {
            "public_observation_hash": "A" * 64,
            "window_id": "B" * 64,
        },
        "public_state": {
            "turn_number": 2,
            "phase": "MAIN",
            "self": {
                "hand": [
                    {"serial": 7, "local_card_uid": "CSV8C_158"},
                    {"serial": 8, "local_card_uid": "CSV1C_127"},
                ],
                "active": [{"serial": 1, "local_card_uid": "CSV8C_157", "remaining_hp": 70, "attached_energy_count": 0}],
                "bench": [],
                "discard": [],
                "deck_count": 45,
                "prizes_remaining": 6,
            },
            "opponent": {
                "hand_count": 7,
                "active": [{"serial": 61, "local_card_uid": "CS6aC_057", "remaining_hp": 220, "attached_energy_count": 1}],
                "bench": [],
                "discard": [],
                "deck_count": 46,
                "prizes_remaining": 6,
            },
        },
        "select_semantics": {"min_count": 1, "max_count": 1},
        "options": options,
    }


class DragapultPublicStrategyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.strategy = DragapultPublicStrategy.load_default()

    def test_contract_builder_is_reproducible_and_source_locked(self) -> None:
        documents = build_documents()
        bundle = documents["bundle"]
        self.assertEqual(PROFILE_ID, bundle["profile_id"])
        self.assertEqual({"schema", "profile", "vectors", "deck_manifest", "policy", "opponent"}, {row["id"] for row in bundle["artifacts"]})
        for row in bundle["artifacts"]:
            path = ROOT / row["path"]
            self.assertEqual(row["canonical_sha256"], sha(canonical_json_v1_bytes(load_json_strict(path))))
        completed = subprocess.run(
            [sys.executable, "tools/ptcgdap/build_dragapult_python_strategy_contract.py", "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, completed.returncode, completed.stdout + completed.stderr)

    def test_exact_local_dragapult_identity_and_current_rules_opponent_are_locked(self) -> None:
        deck = load_json_strict(ROOT / ARTIFACT_PATHS["deck_manifest"])
        opponent = load_json_strict(ROOT / ARTIFACT_PATHS["opponent"])
        self.assertEqual(DECK_ID, deck["source_deck_id"])
        self.assertEqual(CARD_ID_DOMAIN, deck["card_id_domain"])
        self.assertFalse(deck["cabt_exportable"])
        self.assertEqual(60, deck["card_count"])
        self.assertEqual(24, deck["unique_card_count"])
        self.assertEqual(sha(SOURCE_DECK.read_bytes()), deck["source_deck_raw_sha256"])
        self.assertEqual(60, sum(row["count"] for row in deck["cards"]))
        uids = [row["local_card_uid"] for row in deck["cards"]]
        self.assertEqual(sorted(uids, key=str.encode), uids)
        self.assertEqual(24, len(set(uids)))
        self.assertIn("CSV8C_157", uids)
        self.assertIn("CSV8C_158", uids)
        self.assertIn("CSV8C_159", uids)
        self.assertNotIn("official_card_id", json.dumps(deck, sort_keys=True))
        self.assertEqual(OPPONENT_DECK_ID, opponent["deck_id"])
        self.assertEqual(sha(OPPONENT_DECK.read_bytes()), opponent["deck_raw_sha256"])
        self.assertEqual("rules_only", opponent["decision_runtime_mode"])
        self.assertGreaterEqual(len(opponent["runtime_artifacts"]), 6)

    def test_setup_main_search_attack_prize_send_out_and_terminal_windows(self) -> None:
        cases = {
            "setup_active": (
                [option(0, "setup_active", card_uid="CSV9.5C_004"), option(1, "setup_active", card_uid="CSV8C_157")],
                [1],
            ),
            "setup_bench": (
                [option(0, "setup_bench", card_uid="CSV8C_094"), option(1, "setup_bench", card_uid="CSV8C_157"), option(2, "end")],
                [1],
            ),
            "main": (
                [option(0, "end_turn"), option(1, "evolve", card_uid="CSV8C_159", target_uid="CSV8C_158"), option(2, "play_trainer", card_uid="CSV1C_121")],
                [1],
            ),
            "search": (
                [option(0, "search", card_uid="CSV8C_094"), option(1, "search", card_uid="CSV8C_159"), option(2, "search", card_uid="CSV3C_123")],
                [1],
            ),
            "evolve": (
                [option(0, "evolve", card_uid="CSV8C_158", target_uid="CSV8C_157"), option(1, "evolve", card_uid="CSV8C_159", target_uid="CSV8C_158")],
                [1],
            ),
            "attach": (
                [option(0, "attach_energy", card_uid="CSVE1C_PSY", target_uid="CSV8C_094"), option(1, "attach_energy", card_uid="CSVE1C_FIR", target_uid="CSV8C_159")],
                [1],
            ),
            "attack": (
                [option(0, "attack", source_uid="CSV8C_159", attack_index=0), option(1, "attack", source_uid="CSV8C_159", attack_index=1, tags=["phantom_dive"])],
                [1],
            ),
            "attack_target": (
                [option(0, "attack_target", target_uid="CS6aC_057", target_remaining_hp=220, target_prize_value=2), option(1, "attack_target", target_uid="CSV8C_135", target_remaining_hp=40, target_prize_value=1)],
                [1],
            ),
            "effect_target": (
                [option(0, "effect_target", target_uid="CS6aC_057", target_remaining_hp=220, target_prize_value=2), option(1, "effect_target", target_uid="CSV8C_135", target_remaining_hp=30, target_prize_value=1, tags=["spread_knockout"])],
                [1],
            ),
            "take_prize": (
                [option(0, "take_prize"), option(1, "take_prize"), option(2, "take_prize")],
                [0],
            ),
            "send_out": (
                [option(0, "send_out", card_uid="CSV8C_158", attached_energy_count=1), option(1, "send_out", card_uid="CSV8C_159", attached_energy_count=2)],
                [1],
            ),
            "terminal": (
                [option(0, "end")],
                [0],
            ),
        }
        for prompt_kind, (options, expected) in cases.items():
            with self.subTest(prompt_kind=prompt_kind):
                self.assertEqual(expected, self.strategy.select(frame(prompt_kind, options)))

    def test_optional_window_can_return_empty_but_required_window_cannot(self) -> None:
        value = frame("setup_bench", [option(0, "end")])
        value["select_semantics"] = {"min_count": 0, "max_count": 1}
        self.assertEqual([], self.strategy.select(value))
        value["select_semantics"] = {"min_count": 1, "max_count": 1}
        self.assertEqual([0], self.strategy.select(value))

    def test_private_unknown_stale_and_malformed_inputs_fail_closed(self) -> None:
        base = frame("main", [option(0, "end_turn"), option(1, "play_trainer", card_uid="CSV7C_177")])
        cases: list[tuple[str, dict[str, object], str]] = []
        private = copy.deepcopy(base)
        private["private_state"] = {"deck_order": [1, 2, 3]}
        cases.append(("private", private, "invalid_public_frame"))
        hidden = copy.deepcopy(base)
        hidden["public_state"]["opponent"]["hand"] = [{"local_card_uid": "PRIVATE"}]
        cases.append(("opponent_hand", hidden, "invalid_public_frame"))
        unknown_uid = copy.deepcopy(base)
        unknown_uid["options"][1]["card_uid"] = "CSV999C_999"
        cases.append(("unknown_uid", unknown_uid, "unknown_local_card_uid"))
        wrong_own_domain = copy.deepcopy(base)
        wrong_own_domain["public_state"]["self"]["hand"][0]["local_card_uid"] = "CS6aC_057"
        cases.append(("opponent_uid_in_own_zone", wrong_own_domain, "wrong_local_card_uid_domain"))
        wrong_opponent_domain = copy.deepcopy(base)
        wrong_opponent_domain["public_state"]["opponent"]["active"][0]["local_card_uid"] = "CSV8C_157"
        cases.append(("own_uid_in_opponent_zone", wrong_opponent_domain, "wrong_local_card_uid_domain"))
        bool_index = copy.deepcopy(base)
        bool_index["options"][0]["index"] = True
        cases.append(("bool_index", bool_index, "invalid_public_frame"))
        duplicate = copy.deepcopy(base)
        duplicate["options"][1]["index"] = 0
        cases.append(("duplicate_index", duplicate, "invalid_public_frame"))
        for case_id, value, expected in cases:
            with self.subTest(case=case_id):
                with self.assertRaises(DragapultPublicStrategyError) as captured:
                    self.strategy.select(value)
                self.assertEqual(expected, captured.exception.code)

    def test_no_old_index_or_score_authority_survives_a_fresh_window(self) -> None:
        first = frame("search", [option(0, "search", card_uid="CSV8C_094"), option(1, "search", card_uid="CSV8C_159")], sequence=1)
        second = frame("search", [option(0, "search", card_uid="CSV8C_159"), option(1, "search", card_uid="CSV8C_094")], sequence=2)
        second["source"] = {"public_observation_hash": "C" * 64, "window_id": "D" * 64}
        self.assertEqual([1], self.strategy.select(first))
        self.assertEqual([0], self.strategy.select(second))
        self.assertEqual([0], self.strategy.select(second))

    def test_file_ipc_cli_binds_request_and_current_window(self) -> None:
        request_path = ROOT / "artifacts/ptcgdap/.tmp_dragapult_strategy_request.json"
        response_path = ROOT / "artifacts/ptcgdap/.tmp_dragapult_strategy_response.json"
        request_path.parent.mkdir(parents=True, exist_ok=True)
        request = {
            "schema_version": 1,
            "request_id": "godot-window-7",
            "frame": frame(
                "main",
                [
                    option(0, "end_turn"),
                    option(1, "evolve", card_uid="CSV8C_159", target_uid="CSV8C_158"),
                ],
                sequence=7,
            ),
        }
        try:
            request_path.write_text(json.dumps(request), encoding="utf-8")
            response_path.unlink(missing_ok=True)
            completed = subprocess.run(
                [
                    sys.executable,
                    "tools/ptcgdap/run_dragapult_public_strategy.py",
                    "--request",
                    str(request_path),
                    "--response",
                    str(response_path),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )
            self.assertEqual(0, completed.returncode, completed.stdout + completed.stderr)
            response = load_json_strict(response_path)
            self.assertEqual(
                {
                    "schema_version": 1,
                    "request_id": "godot-window-7",
                    "public_observation_hash": "A" * 64,
                    "window_id": "B" * 64,
                    "selected_indexes": [1],
                    "ok": True,
                    "error_code": "",
                },
                response,
            )
        finally:
            request_path.unlink(missing_ok=True)
            response_path.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
