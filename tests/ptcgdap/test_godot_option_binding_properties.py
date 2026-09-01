from __future__ import annotations

import copy
from enum import IntEnum
import itertools
import json
import unittest

from scripts.ai.ptcgdap.godot_option_binding import GodotOptionBinding
from tests.ptcgdap.test_godot_option_binding import HostRef, VECTORS, build_window, context, materialize


class IntegerSubtype(IntEnum):
    ZERO = 0


class StringSubtype(str):
    pass


class GodotOptionBindingPropertyTests(unittest.TestCase):
    def test_order_permutations_preserve_position_and_exact_command_identity(self) -> None:
        fixture = copy.deepcopy(VECTORS["fixture"])
        representative_orders = list(itertools.islice(itertools.permutations(range(5)), 24))
        for order in representative_orders:
            with self.subTest(order=order):
                refs = {}
                source_spec = copy.deepcopy(fixture["source"])
                window_spec = copy.deepcopy(fixture["window"])
                source_spec["select"]["option"] = [source_spec["select"]["option"][index] for index in order]
                source_spec["option_card_refs"] = [source_spec["option_card_refs"][index] for index in order]
                window_spec["select"]["option"] = [window_spec["select"]["option"][index] for index in order]
                source = materialize(source_spec, refs)
                window = build_window(window_spec)
                commands = [HostRef() for _ in order]
                private_refs = [[HostRef()] if index % 2 == 0 else [] for index in order]
                from scripts.ai.ptcgdap.engine_decision_port import EngineDecisionPort

                port = EngineDecisionPort(fixture["match_generation"])
                snapshot = port.publish(
                    source, fixture["decision_generation"], fixture["chooser_player_index"]
                ).snapshot
                owner = GodotOptionBinding()
                result = owner.bind(
                    port=port, snapshot=snapshot, current_source=source, window=window,
                    callback_binding_hash=fixture["callback_binding_hash"],
                    private_commands=commands, private_object_refs=private_refs,
                )
                self.assertTrue(result.accepted, result.error_code)
                self.assertEqual(
                    result.binding.to_audit_dict()["option_fingerprints"],
                    list(window.option_fingerprints),
                )
                for index, command in enumerate(commands):
                    resolution = owner.resolve(
                        binding=result.binding, port=port, snapshot=snapshot,
                        current_source=source, window=window,
                        callback_binding_hash=fixture["callback_binding_hash"],
                        option_index=index,
                    )
                    self.assertTrue(resolution.accepted, resolution.error_code)
                    self.assertIs(resolution.private_engine_command, command)
                    self.assertEqual(
                        resolution.to_public_dict()["audit"]["fingerprint_hash"],
                        window.option_fingerprints[index],
                    )

    def test_exact_type_and_reference_limits_fail_closed_without_echo(self) -> None:
        fixture, refs, source, window, commands, private_refs, port, snapshot = context()
        owner = GodotOptionBinding()
        cases = [
            ("callback_subclass", StringSubtype(fixture["callback_binding_hash"]), commands, private_refs, "invalid_callback_binding_hash"),
            ("outer_refs_tuple", fixture["callback_binding_hash"], commands, tuple(private_refs), "invalid_private_object_refs"),
            ("inner_refs_tuple", fixture["callback_binding_hash"], commands, [tuple(), *private_refs[1:]], "invalid_private_object_refs"),
            ("too_many_per_option", fixture["callback_binding_hash"], commands, [[HostRef() for _ in range(17)], *private_refs[1:]], "invalid_private_object_refs"),
        ]
        for case_id, callback_hash, candidate_commands, candidate_refs, expected in cases:
            with self.subTest(case=case_id):
                result = owner.bind(
                    port=port, snapshot=snapshot, current_source=source, window=window,
                    callback_binding_hash=callback_hash,
                    private_commands=candidate_commands, private_object_refs=candidate_refs,
                )
                self.assertEqual(result.error_code, expected)
                self.assertNotIn("HostRef", json.dumps(result.to_public_dict()))

    def test_integer_subtype_and_stale_equivalent_context_never_authorize(self) -> None:
        fixture, refs, source, window, commands, private_refs, port, snapshot = context()
        owner = GodotOptionBinding()
        bound = owner.bind(
            port=port, snapshot=snapshot, current_source=source, window=window,
            callback_binding_hash=fixture["callback_binding_hash"],
            private_commands=commands, private_object_refs=private_refs,
        )
        self.assertTrue(bound.accepted)
        result = owner.resolve(
            binding=bound.binding, port=port, snapshot=snapshot, current_source=source,
            window=window, callback_binding_hash=fixture["callback_binding_hash"],
            option_index=IntegerSubtype.ZERO,
        )
        self.assertEqual(result.error_code, "option_index_invalid")
        equivalent_window = build_window(fixture["window"])
        self.assertIsNot(equivalent_window, window)
        result = owner.resolve(
            binding=bound.binding, port=port, snapshot=snapshot, current_source=source,
            window=equivalent_window, callback_binding_hash=fixture["callback_binding_hash"],
            option_index=0,
        )
        self.assertEqual(result.error_code, "window_mismatch")


if __name__ == "__main__":
    unittest.main()

