from __future__ import annotations

from pathlib import Path
import json
import sys
import unittest

from scripts.ai.ptcgdap.a3_differential import GodotHeadlessEngineAdapter


ROOT = Path(__file__).resolve().parents[2]
GODOT = Path(r"D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe")


def command() -> list[str]:
    return [
        sys.executable,
        str(ROOT / "tools/ptcgdap/godot_a3_jsonline_bridge.py"),
        "--godot-exe", str(GODOT),
        "--project-root", str(ROOT),
    ]


def mapped_marnie_semantic_deck() -> list[dict[str, object]]:
    """Legal local deck using only source-locked corresponding printings.

    Private-only copies from the product deck are replaced by its mapped Basic
    Darkness Energy.  This is reachability authority, not an official deck-ID
    or 60/60 deck-equality claim.
    """
    rows = [
        ("CSV10C", "146", 3), ("CSV10C", "147", 2),
        ("CSV10C", "148", 2), ("CSV8C", "094", 3),
        ("CSV9.5C", "043", 2), ("CSV7C", "059", 2),
        ("CSV9.5C", "004", 1), ("CSV10C", "007", 1),
        ("CSVH1aC", "023", 2), ("CSV7C", "177", 2),
        ("CSVH1C", "045", 2), ("CSV8C", "183", 2),
        ("CSVH1C", "035", 1), ("CSV1C", "112", 1),
        ("CSV2C", "113", 1), ("CSV8C", "176", 1),
        ("CSV7C", "185", 1), ("CSV10C", "216", 3),
        ("CSVE1C", "DAR", 28),
    ]
    return [
        {"set_code": set_code, "card_index": card_index, "count": count}
        for set_code, card_index, count in rows
    ]


@unittest.skipUnless(GODOT.is_file(), "local Godot runtime unavailable")
class GodotA3JsonLineBridgeTests(unittest.TestCase):
    def test_punk_up_exact_quantity_reobserves_each_assignment_target(self) -> None:
        deck = mapped_marnie_semantic_deck()
        adapter = GodotHeadlessEngineAdapter(command(), cwd=ROOT)
        priority = (
            "use_ability", "use_stadium_effect", "play_trainer",
            "play_basic_to_bench", "evolve", "attach_energy",
            "attach_tool", "play_stadium", "retreat", "attack",
            "granted_attack", "end_turn",
        )
        try:
            checkpoint = adapter.start({
                "private_deck0_entries": deck,
                "private_deck1_entries": deck,
                "seed": 84033,
                "force_first": 0,
            })
            source_checkpoint = None
            activation_checkpoint = None
            previous_context = None
            for _ in range(96):
                context = checkpoint.select["context"]
                kinds = [option.get("kind") for option in checkpoint.ordered_options]
                if context == 22 and checkpoint.select["maxCount"] == 5:
                    self.assertEqual(previous_context, 43)
                    source_checkpoint = checkpoint
                    break
                if context == 43:
                    activation_checkpoint = checkpoint
                    self.assertEqual(checkpoint.select["type"], 9)
                    self.assertEqual(
                        [option["option_type_raw"] for option in checkpoint.ordered_options],
                        [1, 2],
                    )
                    indexes = [0]
                elif context in (41, 1):
                    indexes = [0]
                elif context == 2:
                    indexes = list(range(min(
                        checkpoint.select["maxCount"], len(kinds),
                    )))
                elif context == 0:
                    indexes = next(
                        ([kinds.index(kind)] for kind in priority if kind in kinds),
                        list(range(checkpoint.select["minCount"])),
                    )
                else:
                    indexes = [0] if kinds and checkpoint.select["maxCount"] > 0 else []
                adapter.commit(checkpoint.window_handle or "", indexes)
                previous_context = context
                checkpoint = adapter.next_checkpoint()
            self.assertIsNotNone(activation_checkpoint)
            self.assertIsNotNone(source_checkpoint)
            assert source_checkpoint is not None
            self.assertEqual(source_checkpoint.select["type"], 1)
            self.assertEqual(source_checkpoint.select["context"], 22)
            self.assertEqual(
                {option["kind"] for option in source_checkpoint.ordered_options},
                {"assignment_source"},
            )

            selected_sources = [0, 1, 2]
            adapter.commit(source_checkpoint.window_handle or "", selected_sources)
            target_handles: list[str] = []
            for selected_target in (0, 1, 1):
                checkpoint = adapter.next_checkpoint()
                self.assertEqual(checkpoint.select["type"], 1)
                self.assertEqual(checkpoint.select["context"], 21)
                self.assertEqual(checkpoint.select["minCount"], 1)
                self.assertEqual(checkpoint.select["maxCount"], 1)
                self.assertTrue(all(
                    option.get("kind") == "assignment_target"
                    for option in checkpoint.ordered_options
                ))
                self.assertGreater(len(checkpoint.ordered_options), selected_target)
                target_handles.append(checkpoint.window_handle or "")
                adapter.commit(checkpoint.window_handle or "", [selected_target])

            self.assertEqual(len(set(target_handles)), 3)
            checkpoint = adapter.next_checkpoint()
            self.assertEqual(checkpoint.select["type"], 0)
            self.assertEqual(checkpoint.select["context"], 0)
        finally:
            adapter.dispose()

    def test_real_decision_owner_publishes_commits_reobserves_and_exposes_rng_events(self) -> None:
        adapter = GodotHeadlessEngineAdapter(command(), cwd=ROOT)
        try:
            first = adapter.start({
                "private_deck0_id": 800018501,
                "private_deck1_id": 575720,
                "seed": 83721,
                "force_first": 0,
            })
            self.assertEqual(first.kind, "SELECTION")
            self.assertEqual(first.source_lane, "godot_private")
            self.assertEqual(first.acting_seat, 0)
            self.assertEqual(
                {key: first.select[key] for key in ("type", "context", "minCount", "maxCount")},
                {"type": 9, "context": 41, "minCount": 1, "maxCount": 1},
            )
            self.assertEqual([option["option_type_raw"] for option in first.ordered_options], [1, 2])
            self.assertEqual(
                first.raw_actor_observation["profile"],
                "ptcgdap_private_current_window_v1",
            )
            indexes = [0]
            witness = adapter.commit(first.window_handle or "", indexes)
            self.assertEqual(witness["indexes"], indexes)
            second = adapter.next_checkpoint()
            self.assertGreater(second.callback_ordinal, first.callback_ordinal)
            self.assertGreaterEqual(second.transition_ordinal, 1)
            self.assertNotEqual(second.window_handle, first.window_handle)
            events = adapter.random_events_since(0)
            self.assertTrue(events)
            for event in events:
                self.assertEqual(len(event["source_context_fingerprint"]), 64)
                self.assertEqual(len(event["pre_state_hash"]), 64)
            self.assertEqual(
                adapter.semantic_snapshot("actor_public", "R2A"),
                second.public_snapshot,
            )
        finally:
            adapter.dispose()

    def test_same_seed_and_private_decks_self_replay_first_checkpoint_exactly(self) -> None:
        values = []
        for _ in range(2):
            adapter = GodotHeadlessEngineAdapter(command(), cwd=ROOT)
            try:
                checkpoint = adapter.start({
                    "private_deck0_id": 800018501,
                    "private_deck1_id": 575720,
                    "seed": 83991,
                    "force_first": 0,
                })
                values.append((
                    checkpoint.raw_observation_hash,
                    checkpoint.option_fingerprints,
                    checkpoint.public_snapshot,
                ))
            finally:
                adapter.dispose()
        self.assertEqual(values[0], values[1])

    def test_ephemeral_private_id_deck_reaches_single_corresponding_card_setup_window(self) -> None:
        deck = [
            {"set_code": "CSV10C", "card_index": "146", "count": 1},
            {"set_code": "CSVE1C", "card_index": "DAR", "count": 59},
        ]
        adapter = GodotHeadlessEngineAdapter(command(), cwd=ROOT)
        try:
            checkpoint = adapter.start({
                "private_deck0_entries": deck,
                "private_deck1_entries": deck,
                "seed": 84011,
                "force_first": 0,
            })
            for _ in range(256):
                if checkpoint.select["context"] == 1:
                    break
                indexes = [0]
                if checkpoint.select["context"] == 38:
                    indexes = [next(
                        index for index, option in enumerate(checkpoint.ordered_options)
                        if option.get("option_number") == 0
                    )]
                adapter.commit(checkpoint.window_handle or "", indexes)
                checkpoint = adapter.next_checkpoint()
            else:
                self.fail("setup-active checkpoint not reached")
            self.assertEqual(len(checkpoint.ordered_options), 1)
            self.assertEqual(checkpoint.ordered_options[0]["card_uid"], "CSV10C_146")
            self.assertIsInstance(checkpoint.ordered_options[0]["card_serial"], int)
        finally:
            adapter.dispose()

    def test_optional_setup_bench_waits_for_empty_commit_before_first_main_window(self) -> None:
        adapter = GodotHeadlessEngineAdapter(command(), cwd=ROOT)
        try:
            checkpoint = adapter.start({
                "private_deck0_id": 800018501,
                "private_deck1_id": 800018501,
                "seed": 84033,
                "force_first": 0,
            })
            setup_active_seats: list[int] = []
            setup_bench_seats: list[int] = []
            observed_logs: list[dict] = []
            for _ in range(12):
                observed_logs.extend(checkpoint.incremental_logs)
                context = checkpoint.select["context"]
                if context == 0:
                    break
                if context == 41:
                    indexes = [0]
                elif context == 1:
                    setup_active_seats.append(checkpoint.acting_seat)
                    indexes = [0]
                elif context == 2:
                    setup_bench_seats.append(checkpoint.acting_seat)
                    indexes = []
                else:
                    self.fail(f"unexpected pre-main context: {context}")
                witness = adapter.commit(checkpoint.window_handle or "", indexes)
                self.assertEqual(witness["indexes"], indexes)
                checkpoint = adapter.next_checkpoint()
            else:
                self.fail("first main checkpoint not reached")

            self.assertEqual(setup_active_seats, [0, 1])
            self.assertIn(0, setup_bench_seats)
            self.assertEqual(checkpoint.acting_seat, 0)
            self.assertEqual(checkpoint.select["type"], 0)
            current = checkpoint.public_snapshot["current"]
            self.assertEqual(current["turn_number"], 1)
            self.assertEqual(current["phase"], "MAIN")
            self.assertFalse(any(log.get("event") == "turn_end" for log in observed_logs))
        finally:
            adapter.dispose()

    def test_main_action_reobserve_does_not_silently_fallback_to_end_turn(self) -> None:
        adapter = GodotHeadlessEngineAdapter(command(), cwd=ROOT)
        try:
            checkpoint = adapter.start({
                "private_deck0_id": 800018501,
                "private_deck1_id": 800018501,
                "seed": 84033,
                "force_first": 0,
            })
            for _ in range(12):
                if checkpoint.select["context"] == 0:
                    break
                context = checkpoint.select["context"]
                indexes = [0] if context in (41, 1) else []
                adapter.commit(checkpoint.window_handle or "", indexes)
                checkpoint = adapter.next_checkpoint()
            else:
                self.fail("first main checkpoint not reached")

            end_index = next(
                index for index, option in enumerate(checkpoint.ordered_options)
                if option.get("kind") == "end_turn"
            )
            adapter.commit(checkpoint.window_handle or "", [end_index])
            checkpoint = adapter.next_checkpoint()
            self.assertEqual(checkpoint.acting_seat, 1)
            self.assertEqual(checkpoint.public_snapshot["current"]["turn_number"], 2)

            energy_index = next(
                index for index, option in enumerate(checkpoint.ordered_options)
                if option.get("kind") == "attach_energy"
            )
            adapter.commit(checkpoint.window_handle or "", [energy_index])
            checkpoint = adapter.next_checkpoint()
            self.assertEqual(checkpoint.acting_seat, 1)
            self.assertEqual(checkpoint.public_snapshot["current"]["turn_number"], 2)

            tool_index = next(
                index for index, option in enumerate(checkpoint.ordered_options)
                if option.get("kind") == "attach_tool"
            )
            adapter.commit(checkpoint.window_handle or "", [tool_index])
            checkpoint = adapter.next_checkpoint()
            self.assertEqual(checkpoint.acting_seat, 1)
            self.assertEqual(checkpoint.public_snapshot["current"]["turn_number"], 2)
            granted = [
                option for option in checkpoint.ordered_options
                if option.get("kind") == "granted_attack"
            ]
            self.assertTrue(granted)
            self.assertEqual(granted[0]["option_type_raw"], 13)
            self.assertEqual(granted[0]["source_uid"], "CSV5C_119")
            self.assertEqual(granted[0]["attack_index"], 0)
            self.assertFalse(any(
                log.get("event") == "turn_end" and log.get("player_index") == 1
                for log in checkpoint.incremental_logs
            ))
        finally:
            adapter.dispose()

    def test_ephemeral_private_id_deck_fails_closed_on_non_sixty_card_total(self) -> None:
        adapter = GodotHeadlessEngineAdapter(command(), cwd=ROOT)
        bad_deck = [
            {"set_code": "CSV10C", "card_index": "146", "count": 1},
            {"set_code": "CSVE1C", "card_index": "DAR", "count": 58},
        ]
        try:
            with self.assertRaisesRegex(Exception, "godot_a3_bridge_deck_unavailable"):
                adapter.start({
                    "private_deck0_entries": bad_deck,
                    "private_deck1_entries": bad_deck,
                    "seed": 84012,
                    "force_first": 0,
                })
        finally:
            adapter.dispose()

    def test_public_checkpoint_never_emits_opponent_hidden_card_or_action_payload_ids(self) -> None:
        own_deck = [
            {"set_code": "CSV10C", "card_index": "146", "count": 1},
            {"set_code": "CSVE1C", "card_index": "DAR", "count": 59},
        ]
        opponent_sentinel_uid = "CSV10C_007"
        opponent_energy_sentinel_uid = "CSVE1C_GRA"
        opponent_deck = [
            {"set_code": "CSV10C", "card_index": "007", "count": 1},
            {"set_code": "CSVE1C", "card_index": "GRA", "count": 59},
        ]
        adapter = GodotHeadlessEngineAdapter(command(), cwd=ROOT)
        try:
            checkpoint = adapter.start({
                "private_deck0_entries": own_deck,
                "private_deck1_entries": opponent_deck,
                "seed": 84013,
                "force_first": 0,
            })
            for _ in range(256):
                if checkpoint.acting_seat == 0 and checkpoint.select["context"] != 41:
                    break
                indexes = [1] if checkpoint.select["context"] == 41 else [0]
                if checkpoint.select["context"] == 38:
                    indexes = [next(
                        index for index, option in enumerate(checkpoint.ordered_options)
                        if option.get("option_number") == 0
                    )]
                adapter.commit(checkpoint.window_handle or "", indexes)
                checkpoint = adapter.next_checkpoint()
            else:
                self.fail("seat-zero public checkpoint not reached")
            serialized = json.dumps({
                "raw": checkpoint.raw_actor_observation,
                "logs": checkpoint.incremental_logs,
                "snapshot": checkpoint.public_snapshot,
            }, ensure_ascii=False, sort_keys=True)
            self.assertNotIn(opponent_sentinel_uid, serialized)
            self.assertNotIn(opponent_energy_sentinel_uid, serialized)
            for forbidden in (
                "card_instance_ids", "card_names", "deck_order",
                "face_down_prize", "search_begin_input_value",
            ):
                self.assertNotIn(forbidden, serialized)
        finally:
            adapter.dispose()


if __name__ == "__main__":
    unittest.main()
