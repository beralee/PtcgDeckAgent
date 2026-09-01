from __future__ import annotations

import copy
import json
from pathlib import Path
import unittest

import jsonschema

from scripts.ai.ptcgdap.turn_program_planner import (
    DEFAULT_VALUE_MODEL,
    TurnProgramJournal,
    TurnProgramShadowPlanner,
)
from scripts.ai.ptcgdap.competitive_policy_v2 import (
    CompetitivePolicyV2Compiler,
    CompetitivePolicyV2Runtime,
)


def _frame(*, turn: int = 5, observation: str = "A", window: str = "B") -> dict[str, object]:
    return {
        "schema_version": 2,
        "profile_id": "ptcgdap-competitive-public-frame-v2",
        "sequence": turn,
        "seat": 0,
        "prompt_kind": "main",
        "source": {
            "public_observation_hash": observation * 64,
            "window_id": window * 64,
        },
        "public_state": {
            "turn_number": turn,
            "phase": "MAIN",
            "self": {
                "hand": [],
                "active": [],
                "bench": [],
                "discard": [],
                "deck_count": 24,
                "prizes_remaining": 4,
            },
            "opponent": {
                "hand_count": 6,
                "active": [],
                "bench": [],
                "discard": [],
                "deck_count": 28,
                "prizes_remaining": 4,
            },
        },
        "select_semantics": {
            "min_count": 1,
            "max_count": 1,
            "select_type_raw": 1,
            "select_context_raw": 0,
        },
        "options": [],
    }


def _step(
    step_id: str,
    transaction_id: str,
    *,
    depends_on: list[str] | None = None,
    terminal_kind: str = "none",
) -> dict[str, object]:
    return {
        "step_id": step_id,
        "transaction_id": transaction_id,
        "method_id": f"{transaction_id}-method",
        "depends_on": list(depends_on or []),
        "terminal_kind": terminal_kind,
    }


def _outcome(**updates: int) -> dict[str, int]:
    value = {
        "final_prize_knockout": 0,
        "prize_gain_milli": 0,
        "board_development_milli": 0,
        "attack_pressure_milli": 0,
        "next_turn_continuity_milli": 0,
        "hand_quality_milli": 0,
        "disruption_milli": 0,
        "resource_preservation_milli": 0,
        "risk_milli": 0,
        "unresolved_debt_milli": 0,
    }
    value.update(updates)
    return value


def _program(
    program_id: str,
    steps: list[dict[str, object]],
    outcome: dict[str, int],
    *,
    goal_id: str = "complete-marnie-board",
    route_id: str | None = None,
) -> dict[str, object]:
    return {
        "program_id": program_id,
        "goal_id": goal_id,
        "route_id": route_id or program_id,
        "deadline_turns": 0,
        "semantic_steps": steps,
        "public_outcome": outcome,
    }


def _proof(program: dict[str, object], *, admissible: bool = True, vetoed: bool = False) -> dict[str, object]:
    steps = program["semantic_steps"]
    assert isinstance(steps, list) and steps
    return {
        "program_id": program["program_id"],
        "admissible": admissible,
        "current_step_id": steps[0]["step_id"],
        "current_step_executable": True,
        "mandatory_preserved": True,
        "terminal_preserved": True,
        "base_vetoed": vetoed,
    }


def _request(frame: dict[str, object], programs: list[dict[str, object]]) -> dict[str, object]:
    return {
        "schema_version": 1,
        "profile_id": "ptcgdap-turn-program-request-v1",
        "source": copy.deepcopy(frame["source"]),
        "value_model": copy.deepcopy(DEFAULT_VALUE_MODEL),
        "programs": copy.deepcopy(programs),
        "base_proofs": [_proof(program) for program in programs],
    }


def _marnie_programs() -> list[dict[str, object]]:
    premature_attack = _program(
        "premature-attack",
        [_step("attack-now", "attack", terminal_kind="attack")],
        _outcome(
            attack_pressure_milli=800,
            risk_milli=250,
            unresolved_debt_milli=900,
        ),
    )
    full_turn = _program(
        "complete-board-then-attack",
        [
            _step("evolve-two", "tm-evolution"),
            _step("fill-marnie-board", "punk-up", depends_on=["evolve-two"]),
            _step("move-damage", "munkidori", depends_on=["fill-marnie-board"]),
            _step("disrupt-hand", "iono", depends_on=["move-damage"]),
            _step(
                "attack-after-debt",
                "attack",
                depends_on=["disrupt-hand"],
                terminal_kind="attack",
            ),
        ],
        _outcome(
            board_development_milli=950,
            attack_pressure_milli=800,
            next_turn_continuity_milli=900,
            hand_quality_milli=500,
            disruption_milli=700,
            resource_preservation_milli=650,
            risk_milli=150,
            unresolved_debt_milli=0,
        ),
    )
    optional_churn = _program(
        "optional-churn-then-attack",
        [
            _step("draw-more", "optional-draw"),
            _step("attack-after-churn", "attack", depends_on=["draw-more"], terminal_kind="attack"),
        ],
        _outcome(
            board_development_milli=100,
            attack_pressure_milli=800,
            hand_quality_milli=300,
            risk_milli=500,
            unresolved_debt_milli=700,
        ),
    )
    return [premature_attack, full_turn, optional_churn]


class TurnProgramPlannerTest(unittest.TestCase):
    def test_runtime_package_hash_identity_is_a_valid_journal_scope(self) -> None:
        frame = _frame()
        request = _request(frame, [
            _program(
                "finish",
                [_step("attack", "finish", terminal_kind="attack")],
                _outcome(attack_pressure_milli=500),
            )
        ])
        journal = TurnProgramJournal(
            "runtime-scope", 0, "dev.marnie@5.15.0#" + "A" * 64
        )
        result = journal.advance(frame, request)
        self.assertTrue(result["accepted"], result)

    def test_competitive_policy_shadow_audit_cannot_change_live_selection(self) -> None:
        from tests.ptcgdap.test_turn_transaction_planner import (
            GRIMMSNARL,
            IONO,
            TM_EVOLUTION,
            _document as transaction_document,
            _frame as transaction_frame,
            _option as transaction_option,
        )

        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            transaction_document(),
            allowed_card_uids={GRIMMSNARL, IONO, TM_EVOLUTION},
        )
        self.assertTrue(compiled.accepted, compiled.error_code)
        assert compiled.policy is not None
        frame = transaction_frame(
            [
                transaction_option(0, "attack"),
                transaction_option(1, "play_trainer", card_uid=IONO),
            ],
            turn=3,
        )
        request = _request(frame, _marnie_programs())

        baseline = CompetitivePolicyV2Runtime.decide(compiled.policy, frame)
        shadowed = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            frame,
            turn_program_request=request,
            turn_program_journal=TurnProgramJournal(
                "match-shadow", 0, "dev.marnie@5.15.0"
            ),
        )

        self.assertTrue(baseline.accepted, baseline.error_code)
        self.assertTrue(shadowed.accepted, shadowed.error_code)
        self.assertEqual(baseline.selected_indexes, shadowed.selected_indexes)
        self.assertNotIn("turn_program_shadow", baseline.audit)
        self.assertEqual(
            "complete-board-then-attack",
            shadowed.audit["turn_program_shadow"]["selected_program_id"],
        )
        self.assertFalse(shadowed.audit["turn_program_shadow"]["authoritative"])

        invalid_request = copy.deepcopy(request)
        invalid_request["source"]["window_id"] = "F" * 64
        invalid_shadow = CompetitivePolicyV2Runtime.decide(
            compiled.policy,
            frame,
            turn_program_request=invalid_request,
        )
        self.assertTrue(invalid_shadow.accepted, invalid_shadow.error_code)
        self.assertEqual(baseline.selected_indexes, invalid_shadow.selected_indexes)
        self.assertFalse(invalid_shadow.audit["turn_program_shadow"]["accepted"])
        self.assertEqual(
            "turn_program_source_mismatch",
            invalid_shadow.audit["turn_program_shadow"]["error_code"],
        )

    def test_language_neutral_conformance_vectors(self) -> None:
        vectors_path = (
            Path(__file__).resolve().parents[2]
            / "contracts"
            / "ptcgdap"
            / "turn_program_v1_conformance_vectors.json"
        )
        vectors = json.loads(vectors_path.read_text(encoding="utf-8"))
        schema = json.loads(
            (vectors_path.parent / "turn_program_v1.schema.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual("ptcgdap-turn-program-conformance-v1", vectors["profile_id"])
        for case in vectors["cases"]:
            with self.subTest(case_id=case["case_id"]):
                jsonschema.Draft202012Validator(schema).validate(case["request"])
                result = TurnProgramShadowPlanner.evaluate(case["frame"], case["request"])
                expected = case["expected"]
                for key, value in expected.items():
                    self.assertEqual(value, result[key], result)

    def test_full_turn_program_beats_premature_attack_and_optional_churn(self) -> None:
        frame = _frame()
        result = TurnProgramShadowPlanner.evaluate(frame, _request(frame, _marnie_programs()))

        self.assertTrue(result["accepted"], result)
        self.assertEqual("complete-board-then-attack", result["selected_program_id"])
        self.assertEqual(
            [
                "complete-board-then-attack",
                "premature-attack",
                "optional-churn-then-attack",
            ],
            result["ranked_program_ids"],
        )
        self.assertEqual("evolve-two", result["selected_current_step_id"])

    def test_final_prize_knockout_is_a_hard_terminal_exception(self) -> None:
        frame = _frame()
        programs = _marnie_programs()
        final_attack = _program(
            "take-final-prize-now",
            [_step("final-attack", "attack", terminal_kind="attack")],
            _outcome(
                final_prize_knockout=1,
                prize_gain_milli=1000,
                attack_pressure_milli=1000,
                risk_milli=900,
                unresolved_debt_milli=900,
            ),
            goal_id="close-out-prizes",
        )
        programs.append(final_attack)

        result = TurnProgramShadowPlanner.evaluate(frame, _request(frame, programs))

        self.assertTrue(result["accepted"], result)
        self.assertEqual("take-final-prize-now", result["selected_program_id"])
        self.assertEqual("final-attack", result["selected_current_step_id"])

    def test_base_proof_filters_high_value_but_vetoed_program(self) -> None:
        frame = _frame()
        programs = _marnie_programs()
        request = _request(frame, programs)
        request["base_proofs"][1]["base_vetoed"] = True

        result = TurnProgramShadowPlanner.evaluate(frame, request)

        self.assertTrue(result["accepted"], result)
        self.assertEqual("premature-attack", result["selected_program_id"])
        rejected = {row["program_id"]: row for row in result["candidate_audit"]}
        self.assertEqual("base_vetoed", rejected["complete-board-then-attack"]["status"])

    def test_source_binding_and_private_information_fail_closed(self) -> None:
        frame = _frame()
        request = _request(frame, _marnie_programs())
        request["source"]["window_id"] = "C" * 64
        mismatch = TurnProgramShadowPlanner.evaluate(frame, request)
        self.assertFalse(mismatch["accepted"])
        self.assertEqual("turn_program_source_mismatch", mismatch["error_code"])

        private_frame = copy.deepcopy(frame)
        private_frame["public_state"]["opponent"]["deck_order"] = [101, 102]
        private_result = TurnProgramShadowPlanner.evaluate(
            private_frame, _request(frame, _marnie_programs())
        )
        self.assertFalse(private_result["accepted"])
        self.assertEqual("private_turn_program_input", private_result["error_code"])

    def test_invalid_dependency_graph_and_unproven_step_fail_closed(self) -> None:
        frame = _frame()
        programs = _marnie_programs()
        programs[1]["semantic_steps"][0]["depends_on"] = ["attack-after-debt"]
        invalid = TurnProgramShadowPlanner.evaluate(frame, _request(frame, programs))
        self.assertFalse(invalid["accepted"])
        self.assertEqual("invalid_turn_program", invalid["error_code"])

        programs = _marnie_programs()
        request = _request(frame, programs)
        request["base_proofs"][1]["current_step_id"] = "attack-after-debt"
        unproven = TurnProgramShadowPlanner.evaluate(frame, request)
        self.assertFalse(unproven["accepted"])
        self.assertEqual("invalid_turn_program_base_proof", unproven["error_code"])

    def test_journal_replans_from_fresh_values_and_persists_only_semantic_identity(self) -> None:
        first_frame = _frame()
        journal = TurnProgramJournal("match-1", 0, "dev.marnie@5.15.0")
        first = journal.advance(first_frame, _request(first_frame, _marnie_programs()))
        self.assertEqual("complete-board-then-attack", first["selected_program_id"])

        second_frame = _frame(turn=5, observation="C", window="D")
        programs = _marnie_programs()
        programs[0]["public_outcome"] = _outcome(
            prize_gain_milli=2000,
            attack_pressure_milli=1000,
            unresolved_debt_milli=0,
        )
        second = journal.advance(second_frame, _request(second_frame, programs))
        self.assertEqual("premature-attack", second["selected_program_id"])

        snapshot = journal.snapshot()
        snapshot_text = json.dumps(snapshot, ensure_ascii=False, sort_keys=True)
        for forbidden in ("index", "score", "proof", "binding", "window", "observation_hash"):
            self.assertNotIn(forbidden, snapshot_text)
        self.assertEqual("premature-attack", snapshot["state"]["program_id"])

    def test_result_is_shadow_only_and_cannot_execute_an_option(self) -> None:
        frame = _frame()
        result = TurnProgramShadowPlanner.evaluate(frame, _request(frame, _marnie_programs()))

        self.assertTrue(result["accepted"], result)
        self.assertEqual("shadow", result["mode"])
        self.assertFalse(result["authoritative"])
        self.assertTrue(result["public_only"])
        self.assertTrue(result["reobserve_before_execution"])
        self.assertFalse(result["stale_plan_has_authority"])
        self.assertNotIn("selected_indexes", result)
        self.assertNotIn("option_index", json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    unittest.main()
