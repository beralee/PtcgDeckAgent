from __future__ import annotations

import unittest
from types import SimpleNamespace

from scripts.ai.ptcgdap.a3_differential import (
    A3DifferentialError,
    Checkpoint,
    LockstepDifferentialDriver,
    OfficialCabtEngineAdapter,
    TranscriptEngineAdapter,
    compare_operation_inputs,
    parity_observation_hash,
)
from scripts.ai.ptcgdap.a3_entity_relation import SemanticEntityRelation
from scripts.ai.ptcgdap.a3_operation_contract import (
    A3OperationContractError,
    operation_input_projection,
)
def checkpoint(
    ordinal: int,
    *,
    option_order: tuple[int, ...] = (3, 7),
    damage: int = 0,
    terminal: bool = False,
    serial: int | None = None,
    logs: tuple[dict, ...] = (),
    random_event_cursor: int = 0,
) -> dict:
    options = [
        {"type": value, "index": index, **({"cardId": 41000, "serial": serial} if serial is not None else {})}
        for index, value in enumerate(option_order)
    ]
    from scripts.ai.ptcgdap.a3_differential import _hash
    return {
        "source_lane": "test_fixture",
        "kind": "TERMINAL" if terminal else "SELECTION",
        "transition_ordinal": ordinal,
        "callback_ordinal": ordinal,
        "acting_seat": None if terminal else ordinal % 2,
        "raw_actor_observation": None if terminal else {},
        "raw_observation_hash": parity_observation_hash(None if terminal else {}),
        "window_handle": None if terminal else f"window-{ordinal}",
        "window_generation": None if terminal else ordinal + 1,
        "select": None if terminal else {"type": 1, "context": 25, "minCount": 1, "maxCount": 1},
        "ordered_options": [] if terminal else options,
        "option_fingerprints": [] if terminal else [_hash(option) for option in options],
        "incremental_logs": list(logs),
        "public_snapshot": {"damage": damage, "terminal": terminal},
        "random_event_cursor": random_event_cursor,
        "diagnostic_capability_mask": [],
    }


def operation_checkpoint(
    source_lane: str,
    raw: dict,
    option: dict,
    *,
    acting_seat: int = 0,
    select_type: int = 1,
    context: int = 25,
) -> Checkpoint:
    from scripts.ai.ptcgdap.a3_differential import _hash
    select = {
        "type": select_type, "context": context,
        "minCount": 1, "maxCount": 1, "option": [option],
        "remainDamageCounter": 0, "remainEnergyCost": 0,
    }
    observation = {**raw, "select": select}
    return Checkpoint.parse({
        "source_lane": source_lane,
        "kind": "SELECTION", "transition_ordinal": 0, "callback_ordinal": 0,
        "acting_seat": acting_seat, "raw_actor_observation": observation,
        "raw_observation_hash": parity_observation_hash(observation),
        "window_handle": f"{source_lane}-window", "window_generation": 1,
        "select": select, "ordered_options": [option],
        "option_fingerprints": [_hash(option)], "incremental_logs": [],
        "public_snapshot": {}, "random_event_cursor": 0,
        "diagnostic_capability_mask": [],
    })


class A3DifferentialTests(unittest.TestCase):
    def test_face_down_prize_position_matches_without_hidden_card_identity(self) -> None:
        private = operation_checkpoint(
            "godot_private",
            {"current": {}},
            {
                "option_type_raw": 3,
                "card_uid": None,
                "card_serial": None,
                "option_area_raw": 6,
                "option_area_index": 4,
                "option_player_index": 0,
            },
            select_type=1,
            context=7,
        )
        official = operation_checkpoint(
            "official_native",
            {
                "current": {
                    "players": [
                        {"prize": [None] * 6},
                        {"prize": [None] * 6},
                    ],
                },
            },
            {"type": 3, "area": 6, "index": 4, "playerIndex": 0},
            select_type=1,
            context=7,
        )
        self.assertIsNone(compare_operation_inputs(
            private, official, relation=SemanticEntityRelation(),
        ))

    def test_operation_contract_rejects_invalid_header_and_non_numeric_official_identity(self) -> None:
        from scripts.ai.ptcgdap.a3_differential import _hash

        def parsed(*, source_lane: str, header: dict, option: dict, raw_current: dict) -> Checkpoint:
            select = {
                **header, "option": [option], "deck": None,
                "contextCard": None, "effect": None,
            }
            raw = {
                "current": raw_current, "select": select, "logs": [],
                "search_begin_input": None,
            }
            if source_lane == "godot_private":
                raw["profile"] = "ptcgdap_private_current_window_v1"
            return Checkpoint.parse({
                "source_lane": source_lane,
                "kind": "SELECTION", "transition_ordinal": 0, "callback_ordinal": 0,
                "acting_seat": 0, "raw_actor_observation": raw,
                "raw_observation_hash": parity_observation_hash(raw),
                "window_handle": source_lane, "window_generation": 1,
                "select": select, "ordered_options": [option],
                "option_fingerprints": [_hash(option)], "incremental_logs": [],
                "public_snapshot": {}, "random_event_cursor": 0,
                "diagnostic_capability_mask": [],
            })

        valid_header = {
            "type": 1, "context": 1, "minCount": 1, "maxCount": 1,
            "remainDamageCounter": 0, "remainEnergyCost": 0,
        }
        private_option = {
            "option_type_raw": 3, "card_uid": "P_BASIC_A", "card_serial": 1,
        }
        invalid_header = {**valid_header, "remainEnergyCost": -1}
        with self.assertRaisesRegex(A3OperationContractError, "select_header_invalid"):
            operation_input_projection(parsed(
                source_lane="godot_private", header=invalid_header,
                option=private_option, raw_current={},
            ))

        official_option = {"type": 3, "area": 2, "index": 0, "playerIndex": 0}
        official_current = {
            "players": [
                {"hand": [{"id": "42", "serial": 1}]},
                {"hand": None},
            ],
        }
        with self.assertRaisesRegex(A3OperationContractError, "entity_unavailable"):
            operation_input_projection(parsed(
                source_lane="official_native", header=valid_header,
                option=official_option, raw_current=official_current,
            ))


    def test_operation_lane_is_adapter_provenance_not_self_reported_profile(self) -> None:
        official = operation_checkpoint(
            "official_native",
            {
                "profile": "ptcgdap_private_current_window_v1",
                "current": {"result": -1, "players": [
                    {"hand": [], "discard": [], "active": [], "bench": []},
                    {"hand": None, "discard": [], "active": [], "bench": []},
                ]},
            },
            {"type": 1}, select_type=9, context=41,
        )
        private = operation_checkpoint(
            "godot_private", {"current": {}},
            {"option_type_raw": 1}, select_type=9, context=41,
        )
        self.assertIsNone(compare_operation_inputs(
            private, official, relation=SemanticEntityRelation(),
        ))

    def test_wrong_lane_shape_and_legacy_active_wrapper_fail_closed(self) -> None:
        wrong_lane = operation_checkpoint(
            "godot_private", {"current": {}},
            {"type": 3, "area": 2, "index": 0, "playerIndex": 0},
        )
        official_wrapper = operation_checkpoint(
            "official_native",
            {"current": {
                "result": -1,
                "players": [
                    {"hand": [], "discard": [], "active": [{"stack": [{"id": 42001, "serial": 9001}]}], "bench": []},
                    {"hand": None, "discard": [], "active": [], "bench": []},
                ],
            }},
            {"type": 3, "area": 4, "index": 0, "playerIndex": 0},
        )
        divergence = compare_operation_inputs(
            wrong_lane, official_wrapper, relation=SemanticEntityRelation(),
        )
        self.assertEqual(divergence.classification, "entity_lineage_diff")

    def test_operation_failure_hash_does_not_depend_on_private_search_token(self) -> None:
        def invalid(token: str) -> Checkpoint:
            return operation_checkpoint(
                "official_native",
                {
                    "current": {"result": -1, "players": [
                        {"hand": [{"id": 42001, "serial": 9001}], "discard": [], "active": [], "bench": []},
                        {"hand": None, "discard": [], "active": [], "bench": []},
                    ]},
                    "search_begin_input": token,
                },
                {"type": 3, "area": 2, "index": 0, "playerIndex": 0},
            )
        left = invalid("PRIVATE_TOKEN_ALPHA")
        right = invalid("PRIVATE_TOKEN_BETA")
        divergence = compare_operation_inputs(
            left, right, relation=SemanticEntityRelation(),
        )
        self.assertEqual(divergence.classification, "entity_lineage_diff")
        self.assertEqual(divergence.left_hash, divergence.right_hash)

    def test_all_native_option_families_project_to_the_same_private_id_contract(self) -> None:
        from scripts.ai.ptcgdap.a3_differential import _hash

        relation = SemanticEntityRelation()
        relation.bind_card_identity(
            semantic_card_id="fixture:basic-a", left_card_id="P_BASIC_A",
            right_card_ids=(42001,), evidence_kind="exact_corresponding_printing",
            evidence_hash="A" * 64,
        )
        relation.bind_card_identity(
            semantic_card_id="fixture:stage-a", left_card_id="P_STAGE_A",
            right_card_ids=(42002,), evidence_kind="exact_corresponding_printing",
            evidence_hash="B" * 64,
        )
        relation.bind_card_identity(
            semantic_card_id="fixture:energy-a", left_card_id="P_ENERGY_A",
            right_card_ids=(42003,), evidence_kind="reviewed_equivalent_print",
            evidence_hash="C" * 64,
        )
        relation.bind_card_identity(
            semantic_card_id="fixture:tool-a", left_card_id="P_TOOL_A",
            right_card_ids=(42004,), evidence_kind="exact_corresponding_printing",
            evidence_hash="F" * 64,
        )
        for kwargs in (
            dict(semantic_card_id="fixture:basic-a", left_card_id="P_BASIC_A", official_card_id=42001, deck_occurrence=0, left_serial=101, right_serial=9001),
            dict(semantic_card_id="fixture:basic-a", left_card_id="P_BASIC_A", official_card_id=42001, deck_occurrence=1, left_serial=104, right_serial=9004),
            dict(semantic_card_id="fixture:stage-a", left_card_id="P_STAGE_A", official_card_id=42002, deck_occurrence=0, left_serial=103, right_serial=9003),
            dict(semantic_card_id="fixture:energy-a", left_card_id="P_ENERGY_A", official_card_id=42003, deck_occurrence=0, left_serial=102, right_serial=9002),
            dict(semantic_card_id="fixture:energy-a", left_card_id="P_ENERGY_A", official_card_id=42003, deck_occurrence=1, left_serial=105, right_serial=9005),
            dict(semantic_card_id="fixture:tool-a", left_card_id="P_TOOL_A", official_card_id=42004, deck_occurrence=0, left_serial=106, right_serial=9006),
        ):
            relation.bind_deck_occurrence(source_deck_hash="D" * 64, **kwargs)
        relation.bind_attack_identity(
            semantic_attack_id="fixture:basic-a:attack:0",
            left_attack_id="P_BASIC_A:attack:0", right_attack_ids=(43001,),
            owner_semantic_card_id="fixture:basic-a", evidence_hash="E" * 64,
        )

        official_current = {
            "yourIndex": 0, "result": -1,
            "players": [
                {
                    "hand": [
                        {"id": 42003, "serial": 9002},
                        {"id": 42001, "serial": 9001},
                        {"id": 42002, "serial": 9003},
                    ],
                    "discard": [{"id": 42001, "serial": 9004}],
                    "active": [{
                        "id": 42001, "serial": 9001,
                        "tools": [{"id": 42004, "serial": 9006}],
                        "energyCards": [{"id": 42003, "serial": 9005}],
                        "energies": [7],
                    }],
                    "bench": [],
                },
                {"hand": None, "discard": [], "active": [], "bench": []},
            ],
        }

        def pair(private_option, official_option, select_type, context):
            header = {
                "type": select_type, "context": context,
                "minCount": 1, "maxCount": 1,
                "remainDamageCounter": 0, "remainEnergyCost": 0,
            }
            checkpoints = []
            for private, option, current in (
                (True, private_option, {}),
                (False, official_option, official_current),
            ):
                select = {**header, "option": [option], "deck": None, "contextCard": None, "effect": None}
                raw = {
                    **({"profile": "ptcgdap_private_current_window_v1"} if private else {}),
                    "current": current, "select": select, "logs": [],
                    "search_begin_input": None,
                }
                checkpoints.append(Checkpoint.parse({
                    "source_lane": "godot_private" if private else "official_native",
                    "kind": "SELECTION", "transition_ordinal": 0, "callback_ordinal": 0,
                    "acting_seat": 0, "raw_actor_observation": raw,
                    "raw_observation_hash": parity_observation_hash(raw),
                    "window_handle": "private" if private else "official",
                    "window_generation": 1, "select": select,
                    "ordered_options": [option], "option_fingerprints": [_hash(option)],
                    "incremental_logs": [], "public_snapshot": {},
                    "random_event_cursor": 0, "diagnostic_capability_mask": [],
                }))
            return checkpoints

        vectors = (
            ({"option_type_raw": 0, "option_number": 2}, {"type": 0, "number": 2}, 8, 38),
            ({"option_type_raw": 1}, {"type": 1}, 9, 41),
            ({"option_type_raw": 2}, {"type": 2}, 9, 41),
            ({"option_type_raw": 3, "card_uid": "P_BASIC_A", "card_serial": 101}, {"type": 3, "area": 2, "index": 1, "playerIndex": 0}, 1, 1),
            ({"option_type_raw": 4, "card_uid": "P_TOOL_A", "card_serial": 106}, {"type": 4, "area": 4, "index": 0, "playerIndex": 0, "toolIndex": 0}, 2, 27),
            ({"option_type_raw": 5, "card_uid": "P_ENERGY_A", "card_serial": 105}, {"type": 5, "area": 4, "index": 0, "playerIndex": 0, "energyIndex": 0}, 2, 26),
            ({"option_type_raw": 6, "source_uid": "P_BASIC_A", "source_serial": 101, "energy_type_raw": 7, "energy_count": 1}, {"type": 6, "area": 4, "index": 0, "playerIndex": 0, "energyIndex": 0, "count": 1}, 4, 30),
            ({"option_type_raw": 7, "card_uid": "P_BASIC_A", "card_serial": 101}, {"type": 7, "index": 1}, 0, 0),
            ({"option_type_raw": 8, "card_uid": "P_ENERGY_A", "card_serial": 102, "target_uid": "P_BASIC_A", "target_serial": 101}, {"type": 8, "area": 2, "index": 0, "inPlayArea": 4, "inPlayIndex": 0}, 0, 0),
            ({"option_type_raw": 9, "card_uid": "P_STAGE_A", "card_serial": 103, "target_uid": "P_BASIC_A", "target_serial": 101}, {"type": 9, "area": 2, "index": 2, "inPlayArea": 4, "inPlayIndex": 0}, 7, 37),
            ({"option_type_raw": 10, "source_uid": "P_BASIC_A", "source_serial": 101}, {"type": 10, "area": 4, "index": 0}, 0, 0),
            ({"option_type_raw": 11, "card_uid": "P_BASIC_A", "card_serial": 104}, {"type": 11, "area": 3, "index": 0}, 0, 0),
            ({"option_type_raw": 12}, {"type": 12}, 0, 0),
            ({"option_type_raw": 13, "source_uid": "P_BASIC_A", "attack_index": 0}, {"type": 13, "attackId": 43001}, 6, 35),
            ({"option_type_raw": 14}, {"type": 14}, 0, 0),
            ({"option_type_raw": 15, "card_uid": "P_BASIC_A", "card_serial": 104}, {"type": 15, "cardId": 42001, "serial": 9004}, 5, 34),
            ({"option_type_raw": 16, "special_condition_type": 4}, {"type": 16, "specialConditionType": 4}, 10, 47),
        )
        for ordinal, vector in enumerate(vectors):
            with self.subTest(option_type=vector[1]["type"]):
                private_checkpoint, official_checkpoint = pair(*vector)
                self.assertIsNone(compare_operation_inputs(
                    private_checkpoint, official_checkpoint,
                    relation=relation, phase=f"vector_{ordinal}",
                ))

    def test_private_id_corresponding_card_operation_input_matches_official_window(self) -> None:
        from scripts.ai.ptcgdap.a3_differential import _hash

        private_option = {
            "index": 0, "kind": "setup_active", "option_type_raw": 3,
            "card_uid": "P_BASIC_B", "card_serial": 101,
        }
        official_option = {"type": 3, "area": 2, "index": 0, "playerIndex": 0}
        header = {
            "type": 1, "context": 1, "minCount": 1, "maxCount": 1,
            "remainDamageCounter": 0, "remainEnergyCost": 0,
        }
        private_raw = {
            "profile": "ptcgdap_private_current_window_v1",
            "current": {}, "select": {**header, "option": [private_option]},
            "logs": [], "search_begin_input": None,
        }
        official_raw = {
            "current": {
                "yourIndex": 0, "result": -1,
                "players": [
                    {"hand": [{"id": 42005, "serial": 9001}]},
                    {"hand": None},
                ],
            },
            "select": {**header, "option": [official_option]},
            "logs": [], "search_begin_input": None,
        }
        private_checkpoint = Checkpoint.parse({
            "source_lane": "godot_private",
            "kind": "SELECTION", "transition_ordinal": 0, "callback_ordinal": 0,
            "acting_seat": 0, "raw_actor_observation": private_raw,
            "raw_observation_hash": parity_observation_hash(private_raw),
            "window_handle": "private-window", "window_generation": 1,
            "select": {**header, "option": [private_option]},
            "ordered_options": [private_option],
            "option_fingerprints": [_hash(private_option)],
            "incremental_logs": [], "public_snapshot": {},
            "random_event_cursor": 0, "diagnostic_capability_mask": [],
        })
        official_checkpoint = Checkpoint.parse({
            "source_lane": "official_native",
            "kind": "SELECTION", "transition_ordinal": 0, "callback_ordinal": 0,
            "acting_seat": 0, "raw_actor_observation": official_raw,
            "raw_observation_hash": parity_observation_hash(official_raw),
            "window_handle": "official-window", "window_generation": 1,
            "select": {**header, "option": [official_option]},
            "ordered_options": [official_option],
            "option_fingerprints": [_hash(official_option)],
            "incremental_logs": [], "public_snapshot": {},
            "random_event_cursor": 0, "diagnostic_capability_mask": [],
        })
        relation = SemanticEntityRelation()
        relation.bind_card_identity(
            semantic_card_id="fixture:basic-b",
            left_card_id="P_BASIC_B",
            right_card_ids=(42005,),
            evidence_kind="exact_corresponding_printing",
            evidence_hash="A" * 64,
        )
        relation.bind_deck_occurrence(
            semantic_card_id="fixture:basic-b",
            left_card_id="P_BASIC_B",
            official_card_id=42005,
            deck_occurrence=0,
            left_serial=101,
            right_serial=9001,
            source_deck_hash="D" * 64,
        )
        self.assertIsNone(compare_operation_inputs(
            private_checkpoint, official_checkpoint, relation=relation
        ))

    def test_equal_frontier_commits_once_and_reaches_next_checkpoint(self) -> None:
        transcript = [checkpoint(0), checkpoint(1, terminal=True)]
        driver = LockstepDifferentialDriver(TranscriptEngineAdapter("left", transcript), TranscriptEngineAdapter("right", transcript))
        left, right = driver.start({})
        result = driver.commit_exact(left, right, [0])
        self.assertIsNotNone(result)
        self.assertIsNone(driver.first_divergence)

    def test_option_reorder_canary_stops_before_commit(self) -> None:
        left_adapter = TranscriptEngineAdapter("left", [checkpoint(0)])
        right_adapter = TranscriptEngineAdapter("right", [checkpoint(0, option_order=(7, 3))])
        driver = LockstepDifferentialDriver(left_adapter, right_adapter)
        left, right = driver.start({})
        self.assertEqual(driver.first_divergence.classification, "option_order_diff")
        with self.assertRaisesRegex(A3DifferentialError, "parity_commit_after_divergence_forbidden"):
            driver.commit_exact(left, right, [0])
        self.assertEqual(left_adapter._commits, [])
        self.assertEqual(right_adapter._commits, [])

    def test_wire_select_option_reorder_is_not_misclassified_as_contract_shape(self) -> None:
        left = checkpoint(0)
        right = checkpoint(0, option_order=(7, 3))
        left["select"] = {**left["select"], "option": left["ordered_options"]}
        right["select"] = {**right["select"], "option": right["ordered_options"]}
        driver = LockstepDifferentialDriver(
            TranscriptEngineAdapter("left", [left]),
            TranscriptEngineAdapter("right", [right]),
        )
        driver.start({})
        self.assertEqual(driver.first_divergence.classification, "option_order_diff")
        self.assertEqual(driver.first_divergence.path, "/semantic_option_fingerprints")

    def test_malformed_commit_witness_fails_closed_before_next_checkpoint(self) -> None:
        class MalformedWitnessAdapter(TranscriptEngineAdapter):
            def commit(self, window_handle: str, indexes: list[int]) -> dict:
                super().commit(window_handle, indexes)
                return {"accepted": True, "indexes": indexes, "selection_count": 99}

        transcript = [checkpoint(0), checkpoint(1, terminal=True)]
        driver = LockstepDifferentialDriver(
            MalformedWitnessAdapter("left", transcript),
            TranscriptEngineAdapter("right", transcript),
        )
        left, right = driver.start({})
        self.assertIsNone(driver.commit_exact(left, right, [0]))
        self.assertEqual(driver.first_divergence.classification, "binding_or_execution_diff")
        self.assertEqual(driver.first_divergence.phase, "commit")
        self.assertEqual(driver.first_divergence.path, "/transition_witness")

    def test_current_window_cardinality_duplicates_and_bounds_fail_before_commit(self) -> None:
        for indexes in ([], [0, 0], [2], [True]):
            with self.subTest(indexes=indexes):
                transcript = [checkpoint(0), checkpoint(1, terminal=True)]
                left_adapter = TranscriptEngineAdapter("left", transcript)
                right_adapter = TranscriptEngineAdapter("right", transcript)
                driver = LockstepDifferentialDriver(left_adapter, right_adapter)
                left, right = driver.start({})
                with self.assertRaisesRegex(A3DifferentialError, "parity_indexes_invalid"):
                    driver.commit_exact(left, right, indexes)
                self.assertEqual(left_adapter._commits, [])
                self.assertEqual(right_adapter._commits, [])

    def test_wire_select_option_must_equal_ordered_frontier(self) -> None:
        invalid = checkpoint(0)
        invalid["select"] = {
            **invalid["select"],
            "option": list(reversed(invalid["ordered_options"])),
        }
        with self.assertRaisesRegex(A3DifferentialError, "parity_checkpoint_invalid"):
            Checkpoint.parse(invalid)

    def test_damage_mutation_canary_is_classified_at_first_difference(self) -> None:
        driver = LockstepDifferentialDriver(
            TranscriptEngineAdapter("left", [checkpoint(0, damage=0)]),
            TranscriptEngineAdapter("right", [checkpoint(0, damage=10)]),
        )
        driver.start({})
        self.assertEqual(driver.first_divergence.classification, "damage_diff")
        self.assertEqual(driver.first_divergence.phase, "before_action")

    def test_log_mutation_canary_is_classified(self) -> None:
        driver = LockstepDifferentialDriver(
            TranscriptEngineAdapter("left", [checkpoint(0)]),
            TranscriptEngineAdapter("right", [checkpoint(0, logs=({"type": 7},))]),
        )
        driver.start({})
        self.assertEqual(driver.first_divergence.classification, "log_diff")

    def test_rng_cursor_mutation_canary_is_classified(self) -> None:
        driver = LockstepDifferentialDriver(
            TranscriptEngineAdapter("left", [checkpoint(0)]),
            TranscriptEngineAdapter("right", [checkpoint(0, random_event_cursor=1)]),
        )
        driver.start({})
        self.assertEqual(driver.first_divergence.classification, "random_schedule_diff")

    def test_terminal_mutation_canary_is_classified(self) -> None:
        driver = LockstepDifferentialDriver(
            TranscriptEngineAdapter("left", [checkpoint(0)]),
            TranscriptEngineAdapter("right", [checkpoint(0, terminal=True)]),
        )
        driver.start({})
        self.assertEqual(driver.first_divergence.classification, "terminal_diff")

    def test_serial_domains_compare_through_entity_relation(self) -> None:
        relation = SemanticEntityRelation()
        relation.bind_deck_occurrence(
            official_card_id=41000,
            deck_occurrence=0,
            left_serial=101,
            right_serial=9001,
            source_deck_hash="D" * 64,
        )
        driver = LockstepDifferentialDriver(
            TranscriptEngineAdapter("left", [checkpoint(0, serial=101)]),
            TranscriptEngineAdapter("right", [checkpoint(0, serial=9001)]),
            entity_relation=relation,
        )
        driver.start({})
        self.assertIsNone(driver.first_divergence)

    def test_private_identity_bridge_covers_input_option_log_and_state(self) -> None:
        from scripts.ai.ptcgdap.a3_differential import _hash

        relation = SemanticEntityRelation()
        relation.bind_card_identity(
            semantic_card_id="fixture:basic-b",
            left_card_id="P_BASIC_B",
            right_card_ids=(42005,),
            evidence_kind="exact_corresponding_printing",
            evidence_hash="A" * 64,
        )
        relation.bind_deck_occurrence(
            semantic_card_id="fixture:basic-b",
            left_card_id="P_BASIC_B",
            official_card_id=42005,
            deck_occurrence=0,
            left_serial=101,
            right_serial=9001,
            source_deck_hash="D" * 64,
        )
        left = checkpoint(0, serial=101, logs=({"type": 7, "cardId": "P_BASIC_B"},))
        right = checkpoint(0, serial=9001, logs=({"type": 7, "cardId": 42005},))
        for option in left["ordered_options"]:
            option["cardId"] = "P_BASIC_B"
        for option in right["ordered_options"]:
            option["cardId"] = 42005
        left["option_fingerprints"] = [_hash(option) for option in left["ordered_options"]]
        right["option_fingerprints"] = [_hash(option) for option in right["ordered_options"]]
        left["raw_actor_observation"] = {"current": {"cardId": "P_BASIC_B"}}
        right["raw_actor_observation"] = {"current": {"cardId": 42005}}
        left["raw_observation_hash"] = parity_observation_hash(left["raw_actor_observation"])
        right["raw_observation_hash"] = parity_observation_hash(right["raw_actor_observation"])
        left["public_snapshot"] = {"active": {"cardId": "P_BASIC_B"}, "damage": 0}
        right["public_snapshot"] = {"active": {"cardId": 42005}, "damage": 0}
        driver = LockstepDifferentialDriver(
            TranscriptEngineAdapter("left", [left]),
            TranscriptEngineAdapter("right", [right]),
            entity_relation=relation,
        )
        driver.start({})
        self.assertIsNone(driver.first_divergence)

    def test_unbridged_observation_identity_fails_closed_before_action(self) -> None:
        from scripts.ai.ptcgdap.a3_differential import _hash

        left = checkpoint(0)
        right = checkpoint(0)
        left["ordered_options"][0]["cardId"] = "P_BASIC_B"
        right["ordered_options"][0]["cardId"] = 42005
        left["option_fingerprints"] = [_hash(option) for option in left["ordered_options"]]
        right["option_fingerprints"] = [_hash(option) for option in right["ordered_options"]]
        driver = LockstepDifferentialDriver(
            TranscriptEngineAdapter("left", [left]),
            TranscriptEngineAdapter("right", [right]),
            entity_relation=SemanticEntityRelation(),
        )
        driver.start({})
        self.assertEqual(driver.first_divergence.classification, "entity_lineage_diff")

    def test_unbound_serial_mutation_canary_is_classified(self) -> None:
        relation = SemanticEntityRelation()
        relation.bind_deck_occurrence(
            official_card_id=41000,
            deck_occurrence=0,
            left_serial=101,
            right_serial=9001,
            source_deck_hash="D" * 64,
        )
        driver = LockstepDifferentialDriver(
            TranscriptEngineAdapter("left", [checkpoint(0, serial=102)]),
            TranscriptEngineAdapter("right", [checkpoint(0, serial=9001)]),
            entity_relation=relation,
        )
        driver.start({})
        self.assertEqual(driver.first_divergence.classification, "entity_lineage_diff")

    def test_public_report_cannot_promote_without_w0_and_closed_scope(self) -> None:
        transcript = [checkpoint(0)]
        driver = LockstepDifferentialDriver(TranscriptEngineAdapter("left", transcript), TranscriptEngineAdapter("right", transcript))
        driver.start({})
        report = driver.public_report({
            "scope_sha256": "A" * 64,
            "identity_effect_closure_status": "open",
            "oracle_provenance": {"official_runtime_authorized": False, "maximum_claim": "seeded-development-oracle"},
            "unsupported": ["official"],
        })
        self.assertFalse(report["a3_promoted"])
        self.assertEqual(report["maximum_claim"], "seeded-development-oracle")

    def test_single_differential_report_never_owns_a3_promotion(self) -> None:
        transcript = [checkpoint(0)]
        driver = LockstepDifferentialDriver(
            TranscriptEngineAdapter("left", transcript),
            TranscriptEngineAdapter("right", transcript),
        )
        driver.start({})
        report = driver.public_report({
            "scope_sha256": "A" * 64,
            "identity_effect_closure_status": "closed",
            "oracle_provenance": {
                "official_runtime_authorized": True,
                "maximum_claim": "official_a3",
            },
            "unsupported": [],
        })
        self.assertEqual(report["status"], "aligned")
        self.assertFalse(report["a3_promoted"])
        self.assertEqual(report["promotion_authority"], "qualification_owner_only")

    def test_official_adapter_is_constructed_only_with_explicit_rights(self) -> None:
        denied = SimpleNamespace(
            accepted=False,
            mode="clean_room",
            operation="oracle",
            claims={},
        )
        with self.assertRaisesRegex(A3DifferentialError, "authority_official_oracle_unavailable"):
            OfficialCabtEngineAdapter(["unused"], denied)

    def test_checkpoint_shape_and_lifecycle_fields_fail_closed(self) -> None:
        invalid = checkpoint(0)
        invalid["random_event_cursor"] = -1
        with self.assertRaisesRegex(A3DifferentialError, "parity_checkpoint_invalid"):
            Checkpoint.parse(invalid)

    def test_opaque_search_token_value_is_not_part_of_parity_hash(self) -> None:
        first = {"select": {}, "search_begin_input": "private-token-one"}
        second = {"select": {}, "search_begin_input": "private-token-two"}
        self.assertEqual(parity_observation_hash(first), parity_observation_hash(second))
        invalid = checkpoint(0)
        invalid["raw_observation_hash"] = "A" * 64
        with self.assertRaisesRegex(A3DifferentialError, "parity_raw_observation_hash_invalid"):
            Checkpoint.parse(invalid)
        invalid = checkpoint(0, terminal=True)
        invalid["acting_seat"] = 0
        with self.assertRaisesRegex(A3DifferentialError, "parity_checkpoint_invalid"):
            Checkpoint.parse(invalid)


if __name__ == "__main__":
    unittest.main()
